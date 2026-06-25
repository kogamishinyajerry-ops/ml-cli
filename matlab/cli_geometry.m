function cli_geometry(action, varargin)
% CLI_GEOMETRY 2D/3D geometry for ml CLI
%   CLI: ml geometry area      --shape polygon --vertices "[0,0;4,0;4,3]"
%         ml geometry volume    --shape sphere --r 2
%         ml geometry centroid  --vertices "[0,0;4,0;4,3;0,3]"
%         ml geometry distance  --p1 "[1,2]" --p2 "[4,6]"
%         ml geometry hull      --points "[0,0;1,0;1,1;0.5,0.5;0,2]"
%         ml geometry intersect --s1 "[0,0;4,4]" --s2 "[0,4;4,0]"
%
%   Options:
%     --shape NAME    polygon|circle|triangle|ellipse for area; sphere|cylinder|cone|cube|pyramid for volume
%     --vertices MAT   polygon vertex coordinates
%     --points MAT     point cloud
%     --p1 --p2 --p   point coordinates
%     --line MAT       line segment [x1,y1; x2,y2]
%     --s1 --s2 MAT    segment for intersection
%     --r --h --a --b  radius, height, semi-axes
%     --format json|table|csv

    if nargin < 1, error('ml geometry <action> [options]'); end

    opts = struct('format','json','shape','polygon','vertices','','points','', ...
                  'p1','','p2','','p','','line','','s1','','s2','', ...
                  'r',1,'h',2,'a',1,'b',1,'c',1);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--shape',     opts.shape = lower(varargin{i+1}); i=i+2;
            case '--vertices',  opts.vertices = varargin{i+1}; i=i+2;
            case '--points',    opts.points = varargin{i+1}; i=i+2;
            case '--p1',        opts.p1 = varargin{i+1}; i=i+2;
            case '--p2',        opts.p2 = varargin{i+1}; i=i+2;
            case '--p',         opts.p = varargin{i+1}; i=i+2;
            case '--line',      opts.line = varargin{i+1}; i=i+2;
            case '--s1',        opts.s1 = varargin{i+1}; i=i+2;
            case '--s2',        opts.s2 = varargin{i+1}; i=i+2;
            case '--r',         opts.r = parse_num(varargin{i+1}); i=i+2;
            case '--h',         opts.h = parse_num(varargin{i+1}); i=i+2;
            case '--a',         opts.a = parse_num(varargin{i+1}); i=i+2;
            case '--b',         opts.b = parse_num(varargin{i+1}); i=i+2;
            case '--c',         opts.c = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'area',      out = act_area(opts);
            case 'volume',    out = act_volume(opts);
            case 'centroid',  out = act_centroid(opts);
            case 'distance',  out = act_distance(opts);
            case 'hull',      out = act_hull(opts);
            case 'intersect', out = act_intersect(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_area(opts)
    shape = opts.shape;
    switch shape
        case 'polygon'
            verts = parse_vec2d(opts.vertices);
            A = polygon_area(verts);
            out = struct('action','area','shape','polygon','n',size(verts,1),'area',A);
        case 'circle'
            r = opts.r;
            out = struct('action','area','shape','circle','radius',r,'area',pi*r^2);
        case 'triangle'
            % Heron's formula from 3 vertices
            verts = parse_vec2d(opts.vertices);
            if size(verts,1) ~= 3, error('triangle needs 3 vertices'); end
            a = norm(verts(2,:)-verts(1,:));
            b = norm(verts(3,:)-verts(2,:));
            c_len = norm(verts(1,:)-verts(3,:));
            s = (a+b+c_len)/2;
            A = sqrt(max(0, s*(s-a)*(s-b)*(s-c_len)));
            out = struct('action','area','shape','triangle','sides',[a,b,c_len],'area',A);
        case 'ellipse'
            out = struct('action','area','shape','ellipse','a',opts.a,'b',opts.b,'area',pi*opts.a*opts.b);
        otherwise
            error('unknown shape: %s', shape);
    end
end

function out = act_volume(opts)
    shape = opts.shape;
    r = opts.r; h = opts.h;
    switch shape
        case 'sphere'
            V = 4/3*pi*r^3;
        case 'cylinder'
            V = pi*r^2*h;
        case 'cone'
            V = pi*r^2*h/3;
        case 'cube'
            V = opts.a^3;
        case 'pyramid'
            V = opts.a * opts.b * h / 3;
        otherwise
            error('unknown shape: %s', shape);
    end
    out = struct();
    out.action = 'volume';
    out.shape = shape;
    out.volume = V;
    if ismember(shape, {'sphere','cylinder','cone'}), out.radius = r; end
    if ismember(shape, {'cylinder','cone','pyramid'}), out.height = h; end
end

function out = act_centroid(opts)
    verts = parse_vec2d(opts.vertices);
    n = size(verts,1);
    if n < 3, error('need at least 3 vertices'); end
    % Shoelace for signed area * 2
    sumCx = 0; sumCy = 0;
    for i = 1:n
        j = mod(i, n) + 1;
        xi = verts(i,1); yi = verts(i,2);
        xj = verts(j,1); yj = verts(j,2);
        cross = xi*yj - xj*yi;
        sumCx = sumCx + (xi+xj)*cross;
        sumCy = sumCy + (yi+yj)*cross;
    end
    A = polygon_area(verts);
    Cx = sumCx / (6*A);
    Cy = sumCy / (6*A);
    out = struct();
    out.action = 'centroid';
    out.n = n;
    out.centroid = [Cx, Cy];
    out.area = A;
end

function out = act_distance(opts)
    p1 = parse_vec2d(opts.p1);
    p2 = parse_vec2d(opts.p2);
    if ~isempty(p1) && ~isempty(p2)
        % Point-to-point
        d = norm(p2(1,:) - p1(1,:));
        kind = 'point-to-point';
    elseif ~isempty(opts.p) && ~isempty(opts.line)
        % Point-to-line
        p = parse_vec2d(opts.p);
        line = parse_vec2d(opts.line);
        if size(line,1) ~= 2, error('line needs 2 points'); end
        a = line(1,:); b = line(2,:);
        d = abs(cross_2d(b-a, p(1,:)-a)) / norm(b-a);
        kind = 'point-to-line';
    else
        error('need --p1/--p2 or --p/--line');
    end
    out = struct();
    out.action = 'distance';
    out.type = kind;
    out.distance = d;
end

function out = act_hull(opts)
    pts = parse_vec2d(opts.points);
    n = size(pts, 1);
    if n < 3, error('need at least 3 points'); end
    % Graham scan
    % Find lowest point (smallest y, then smallest x)
    [~, start] = min(pts(:,2) + pts(:,1)*1e-6);
    % Sort by polar angle relative to start
    p0 = pts(start, :);
    angles = atan2(pts(:,2)-p0(2), pts(:,1)-p0(1));
    [~, idx] = sort(angles);
    % Remove duplicates
    stack = [1, 2];
    for k = 3:n
        while numel(stack) >= 2
            p1 = pts(idx(stack(end-1)), :);
            p2 = pts(idx(stack(end)), :);
            p3 = pts(idx(k), :);
            if cross_2d(p2-p1, p3-p1) <= 0
                stack(end) = [];
            else
                break;
            end
        end
        stack(end+1) = k;
    end
    hullVerts = pts(idx(stack), :);
    out = struct();
    out.action = 'hull';
    out.method = 'Graham scan';
    out.n_input = n;
    out.n_hull = size(hullVerts,1);
    out.hullVertices = hullVerts;
end

function out = act_intersect(opts)
    s1 = parse_vec2d(opts.s1);
    s2 = parse_vec2d(opts.s2);
    if size(s1,1) ~= 2 || size(s2,1) ~= 2
        error('each segment needs 2 points');
    end
    % Line segment intersection via param equation
    p = s1(1,:); r = s1(2,:) - p;
    q = s2(1,:); s = s2(2,:) - q;
    rs = cross_2d(r, s);
    if abs(rs) < 1e-12
        % Parallel or colinear
        out = struct('action','intersect','type','segments','intersecting',false, ...
                     'reason','parallel or colinear','nPoints',0);
        return;
    end
    t = cross_2d(q-p, s) / rs;
    u = cross_2d(q-p, r) / rs;
    if t >= 0 && t <= 1 && u >= 0 && u <= 1
        ip = p + t*r;
        out = struct('action','intersect','type','segments','intersecting',true, ...
                     'point', ip, 't', t, 'u', u);
    else
        out = struct('action','intersect','type','segments','intersecting',false, ...
                     'reason','intersection outside segments','t',t,'u',u);
    end
end

% =================== Helpers ===================
function verts = parse_vec2d(s)
    if isempty(s) || (ischar(s) && strcmp(s,''))
        verts = [];
        return;
    end
    if ischar(s) || isstring(s)
        s = regexprep(s, '[\[\]{};, ]+', ' ');
        v = sscanf(s, '%f');
        if mod(numel(v), 2) ~= 0
            error('vertices must have even number of coordinates');
        end
        verts = reshape(v, 2, [])';
    else
        verts = s;
    end
end

function A = polygon_area(verts)
    n = size(verts, 1);
    sumArea = 0;
    for i = 1:n
        j = mod(i, n) + 1;
        sumArea = sumArea + verts(i,1)*verts(j,2) - verts(j,1)*verts(i,2);
    end
    A = abs(sumArea) / 2;
end

function c = cross_2d(a, b)
    % 2D cross product = z-component of 3D cross
    c = a(1)*b(2) - a(2)*b(1);
end

function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
