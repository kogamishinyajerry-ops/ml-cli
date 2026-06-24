function cli_map(action, varargin)
% CLI_MAP Geographic visualization and distance calculations
%   CLI: ml map distance --lat1 40.7128 --lon1 -74.0060 --lat2 34.0522 --lon2 -118.2437
%         ml map geocode --address "New York"     (offline: parse built-in city DB)
%         ml map points   --lats "[40.7 34.0]" --lons "[-74 -118]" --labels "[NYC LA]"
%         ml map greatcircle --lat1 51.5 --lon1 -0.1 --lat2 35.7 --lon2 139.7
%         ml map timezone --lat 40.7 --lon -74.0
%         ml map bearing  --lat1 0 --lon1 0 --lat2 1 --lon2 1
%
%   Options:
%     --lat1 --lon1   point 1 coordinates (decimal degrees)
%     --lat2 --lon2   point 2 coordinates
%     --lats VEC      vector of latitudes
%     --lons VEC      vector of longitudes
%     --labels CELL   cell array of labels
%     --address STR   address string
%     --units KM|MI   distance units (default KM)
%     --format json|table|csv

    if nargin < 1, error('ml map <action> [options]'); end

    opts = struct('format','json','lat1',0,'lon1',0,'lat2',0,'lon2',0, ...
                  'lat',0,'lon',0, ...
                  'lats','','lons','','labels','','address','','units','KM');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--lat1',    opts.lat1 = parse_num(varargin{i+1}); i=i+2;
            case '--lon1',    opts.lon1 = parse_num(varargin{i+1}); i=i+2;
            case '--lat2',    opts.lat2 = parse_num(varargin{i+1}); i=i+2;
            case '--lon2',    opts.lon2 = parse_num(varargin{i+1}); i=i+2;
            case '--lat',     opts.lat = parse_num(varargin{i+1}); i=i+2;
            case '--lon',     opts.lon = parse_num(varargin{i+1}); i=i+2;
            case '--lats',    opts.lats = varargin{i+1}; i=i+2;
            case '--lons',    opts.lons = varargin{i+1}; i=i+2;
            case '--labels',  opts.labels = varargin{i+1}; i=i+2;
            case '--address', opts.address = varargin{i+1}; i=i+2;
            case '--units',   opts.units = upper(varargin{i+1}); i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'distance',   out = act_distance(opts);
            case 'greatcircle',out = act_greatcircle(opts);
            case 'bearing',    out = act_bearing(opts);
            case 'points',     out = act_points(opts);
            case 'geocode',    out = act_geocode(opts);
            case 'timezone',   out = act_timezone(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_distance(opts)
    % Haversine formula
    R_earth_km = 6371.0;
    lat1 = deg2rad(opts.lat1); lat2 = deg2rad(opts.lat2);
    lon1 = deg2rad(opts.lon1); lon2 = deg2rad(opts.lon2);
    dlat = lat2 - lat1; dlon = lon2 - lon1;
    a = sin(dlat/2)^2 + cos(lat1)*cos(lat2)*sin(dlon/2)^2;
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    d_km = R_earth_km * c;
    if strcmp(opts.units, 'MI')
        d = d_km * 0.621371;
        unitStr = 'miles';
    else
        d = d_km;
        unitStr = 'kilometers';
    end
    out = struct();
    out.action = 'distance';
    out.method = 'haversine';
    out.point1 = struct('lat', opts.lat1, 'lon', opts.lon1);
    out.point2 = struct('lat', opts.lat2, 'lon', opts.lon2);
    out.distance = d;
    out.units = unitStr;
end

function out = act_greatcircle(opts)
    % Great-circle path waypoints
    lat1 = deg2rad(opts.lat1); lon1 = deg2rad(opts.lon1);
    lat2 = deg2rad(opts.lat2); lon2 = deg2rad(opts.lon2);
    d = 2 * asin(sqrt(sin((lat2-lat1)/2)^2 + cos(lat1)*cos(lat2)*sin((lon2-lon1)/2)^2));
    nWp = 12;
    frac = linspace(0, 1, nWp)';
    % Spherical interpolation
    A = sin((1-frac)*d) / sin(d);
    B = sin(frac*d) / sin(d);
    x = A.*cos(lat1).*cos(lon1) + B.*cos(lat2).*cos(lon2);
    y = A.*cos(lat1).*sin(lon1) + B.*cos(lat2).*sin(lon2);
    z = A.*sin(lat1) + B.*sin(lat2);
    lat = atan2(z, sqrt(x.^2 + y.^2));
    lon = atan2(y, x);
    waypoints = [rad2deg(lat), rad2deg(lon)];
    out = struct();
    out.action = 'greatcircle';
    out.point1 = struct('lat', opts.lat1, 'lon', opts.lon1);
    out.point2 = struct('lat', opts.lat2, 'lon', opts.lon2);
    out.angularDistance_rad = d;
    out.distance_km = d * 6371.0;
    out.waypoints = waypoints;
end

function out = act_bearing(opts)
    lat1 = deg2rad(opts.lat1); lat2 = deg2rad(opts.lat2);
    lon1 = deg2rad(opts.lon1); lon2 = deg2rad(opts.lon2);
    dLon = lon2 - lon1;
    y = sin(dLon) * cos(lat2);
    x = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon);
    bearing = mod(atan2(y, x) * 180/pi, 360);
    out = struct();
    out.action = 'bearing';
    out.point1 = struct('lat', opts.lat1, 'lon', opts.lon1);
    out.point2 = struct('lat', opts.lat2, 'lon', opts.lon2);
    out.initialBearing_deg = bearing;
    out.cardinal = bearing_to_cardinal(bearing);
end

function out = act_points(opts)
    lats = parse_vec(opts.lats);
    lons = parse_vec(opts.lons);
    if numel(lats) ~= numel(lons)
        error('lats and lons must have same length');
    end
    if ~isempty(opts.labels)
        labels = eval(opts.labels);
    else
        labels = arrayfun(@(k) sprintf('pt%d', k), 1:numel(lats), 'UniformOutput', false);
    end
    % Compute centroid
    centroidLat = mean(lats);
    centroidLon = mean(lons);
    % Bounding box
    out = struct();
    out.action = 'points';
    out.count = numel(lats);
    out.latitudes = lats;
    out.longitudes = lons;
    out.labels = labels;
    out.centroid = struct('lat', centroidLat, 'lon', centroidLon);
    out.bbox = struct('minLat', min(lats), 'maxLat', max(lats), ...
                     'minLon', min(lons), 'maxLon', max(lons));
end

function out = act_geocode(opts)
    % Small built-in city DB (offline)
    cityNames = {'new york','los angeles','london','tokyo','paris', ...
                 'beijing','shanghai','sydney','moscow','berlin', ...
                 'singapore','dubai'};
    cityLats  = [40.7128, 34.0522, 51.5074, 35.6762, 48.8566, ...
                 39.9042, 31.2304, -33.8688, 55.7558, 52.5200, ...
                 1.3521, 25.2048];
    cityLons  = [-74.0060, -118.2437, -0.1278, 139.6503, 2.3522, ...
                 116.4074, 121.4737, 151.2093, 37.6173, 13.4050, ...
                 103.8198, 55.2708];
    q = lower(strtrim(opts.address));
    idx = find(strcmpi(cityNames, q), 1);
    out = struct();
    out.action = 'geocode';
    out.query = opts.address;
    if ~isempty(idx)
        out.matched = true;
        out.latitude = cityLats(idx);
        out.longitude = cityLons(idx);
        out.source = 'builtin-db';
    else
        out.matched = false;
        out.message = 'address not found in offline DB';
        out.knownCities = cityNames;
    end
end

function out = act_timezone(opts)
    % Rough timezone estimate from longitude (15° per hour)
    lon = opts.lon;
    tz_offset = round(lon / 15);
    if tz_offset >= 0
        tzStr = sprintf('UTC+%d', abs(tz_offset));
    else
        tzStr = sprintf('UTC-%d', abs(tz_offset));
    end
    % Rough hemisphere
    if opts.lat >= 0
        hemisphere = 'Northern';
    else
        hemisphere = 'Southern';
    end
    out = struct();
    out.action = 'timezone';
    out.latitude = opts.lat;
    out.longitude = lon;
    out.estimatedUTCOffset_hours = tz_offset;
    out.timezone = tzStr;
    out.hemisphere = hemisphere;
    out.note = 'approximate (longitude-based, ignores political boundaries)';
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function v = parse_vec(s)
    if ischar(s) || isstring(s)
        s = regexprep(s, '[\[\]{}]', '');
        v = sscanf(s, '%f');
    elseif isvector(s)
        v = s(:);
    else
        v = s(:);
    end
end

function c = bearing_to_cardinal(b)
    dirs = {'N','NNE','NE','ENE','E','ESE','SE','SSE', ...
            'S','SSW','SW','WSW','W','WNW','NW','NNW'};
    idx = mod(round(b/22.5), 16) + 1;
    c = dirs{idx};
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
