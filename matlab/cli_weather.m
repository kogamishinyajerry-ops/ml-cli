function cli_weather(action, varargin)
% CLI_WEATHER Meteorology for ml CLI
%   CLI: ml weather dew_point   --temp 25 --rh 60
%         ml weather wind_chill --temp -5 --wind 30
%         ml weather heat_index --temp 33 --rh 70
%         ml weather humidity   --temp 20 --dew 12 --solve sh|rh|dew|ah
%         ml weather pressure   --elevation 500 --temp 15
%         ml weather wind_power --speed 10 --diameter 80 --rho 1.225
%
%   Options:
%     --temp C         air temperature
%     --rh PCT         relative humidity (%)
%     --wind KMH       wind speed
%     --dew C          dew point temperature
%     --solve NAME     sh|rh|dew|ah (specific humidity/relative humidity/dew point/absolute humidity)
%     --elevation M    elevation above sea level
%     --speed M/S      wind speed (for power)
%     --diameter M     turbine diameter
%     --rho KG/M3      air density
%     --format json|table|csv

    if nargin < 1, error('ml weather <action> [options]'); end

    opts = struct('format','json','temp',25,'rh',60,'wind',30,'dew',12, ...
                  'solve','sh','elevation',500,'speed',10,'diameter',80,'rho',1.225);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--temp',      opts.temp = parse_num(varargin{i+1}); i=i+2;
            case '--rh',        opts.rh = parse_num(varargin{i+1}); i=i+2;
            case '--wind',      opts.wind = parse_num(varargin{i+1}); i=i+2;
            case '--dew',       opts.dew = parse_num(varargin{i+1}); i=i+2;
            case '--solve',     opts.solve = lower(varargin{i+1}); i=i+2;
            case '--elevation', opts.elevation = parse_num(varargin{i+1}); i=i+2;
            case '--speed',     opts.speed = parse_num(varargin{i+1}); i=i+2;
            case '--diameter',  opts.diameter = parse_num(varargin{i+1}); i=i+2;
            case '--rho',       opts.rho = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'dew_point',  out = act_dew_point(opts);
            case 'wind_chill', out = act_wind_chill(opts);
            case 'heat_index', out = act_heat_index(opts);
            case 'humidity',   out = act_humidity(opts);
            case 'pressure',   out = act_pressure(opts);
            case 'wind_power', out = act_wind_power(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_dew_point(opts)
    T = opts.temp;
    RH = opts.rh;
    % Magnus formula (over water)
    a = 17.27; b = 237.7;  % constants
    gamma = a * T / (b + T) + log(RH/100);
    Td = b * gamma / (a - gamma);
    out = struct();
    out.action = 'dew_point';
    out.temp_C = T;
    out.rh_pct = RH;
    out.dewPoint_C = Td;
    % Frost point if below 0
    if Td < 0
        a_f = 22.587; b_f = 273.86;
        gamma_f = a_f * T / (b_f + T) + log(RH/100);
        Tf = b_f * gamma_f / (a_f - gamma_f);
        out.frostPoint_C = Tf;
    end
end

function out = act_wind_chill(opts)
    T = opts.temp;
    V = opts.wind;  % km/h
    % JAG/TI wind chill formula (Canada/US, 2001)
    if T > 10 || V < 4.8
        out = struct();
        out.action = 'wind_chill';
        out.temp_C = T;
        out.wind_kmh = V;
        out.windChill_C = T;
        out.valid = false;
        out.note = 'WC formula valid for T≤10°C and V≥4.8 km/h';
        return;
    end
    wc = 13.12 + 0.6215*T - 11.37*V^0.16 + 0.3965*T*V^0.16;
    % Frostbite time estimate
    if wc < -10
        ft_min = 30;
    elseif wc < -20
        ft_min = 10;
    elseif wc < -30
        ft_min = 5;
    elseif wc < -40
        ft_min = 2;
    elseif wc < -50
        ft_min = 1;
    else
        ft_min = Inf;
    end
    out = struct();
    out.action = 'wind_chill';
    out.temp_C = T;
    out.wind_kmh = V;
    out.windChill_C = wc;
    out.valid = true;
    out.frostbiteMin = ft_min;
end

function out = act_heat_index(opts)
    T = opts.temp;  % °C
    RH = opts.rh;
    Tf = T * 9/5 + 32;  % convert to °F for formula
    % Rothfusz regression (NOAA/NWS)
    if Tf < 80 || RH < 40
        out = struct();
        out.action = 'heat_index';
        out.temp_C = T;
        out.rh_pct = RH;
        out.heatIndex_C = T;
        out.valid = false;
        out.note = 'HI formula valid for T≥27°C and RH≥40%';
        return;
    end
    HI_F = -42.379 + 2.04901523*Tf + 10.14333127*RH ...
           - 0.22475541*Tf*RH - 6.83783e-3*Tf^2 ...
           - 5.481717e-2*RH^2 + 1.22874e-3*Tf^2*RH ...
           + 8.5282e-4*Tf*RH^2 - 1.99e-6*Tf^2*RH^2;
    % Rothfusz adjustment for low RH
    if RH < 13 && Tf >= 80 && Tf <= 112
        adj = (13 - RH)/4 * sqrt((17 - abs(Tf - 95))/17);
        HI_F = HI_F - adj;
    end
    HI_C = (HI_F - 32) * 5/9;
    % Risk category
    if HI_C < 27, risk = 'no risk';
    elseif HI_C < 32, risk = 'caution';
    elseif HI_C < 41, risk = 'extreme caution';
    elseif HI_C < 54, risk = 'danger';
    else, risk = 'extreme danger'; end
    out = struct();
    out.action = 'heat_index';
    out.temp_C = T;
    out.rh_pct = RH;
    out.heatIndex_C = HI_C;
    out.valid = true;
    out.riskCategory = risk;
end

function out = act_humidity(opts)
    T = opts.temp;
    Td = opts.dew;
    solve = opts.solve;
    % Saturation vapor pressure (Magnus)
    es = 6.112 * exp(17.67 * T / (T + 243.5));  % hPa
    es_dew = 6.112 * exp(17.67 * Td / (Td + 243.5));
    RH = 100 * es_dew / es;
    % Specific humidity: q = 0.622 * e / (P - 0.378*e), P=1013.25 hPa
    e = es * RH / 100;
    P = 1013.25;
    SH = 0.622 * e / (P - 0.378 * e);  % kg/kg
    % Absolute humidity: ρ_v = e*100 / (Rv*T), Rv=461.5 J/(kg·K)
    AH = e * 100 / (461.5 * (T + 273.15));  % kg/m³
    out = struct();
    out.action = 'humidity';
    out.temp_C = T;
    out.dewPoint_C = Td;
    out.saturationVaporPressure_hPa = es;
    out.relativeHumidity_pct = RH;
    out.specificHumidity_kg_per_kg = SH;
    out.absoluteHumidity_kg_per_m3 = AH;
end

function out = act_pressure(opts)
    H = opts.elevation;
    T = opts.temp + 273.15;
    P0 = 101325;
    g = 9.80665;
    M = 0.0289644;
    R = 8.314;
    % Barometric formula: P = P0 * exp(-g*M*H/(R*T))
    P = P0 * exp(-g * M * H / (R * T));
    out = struct();
    out.action = 'pressure';
    out.elevation_m = H;
    out.temp_K = T;
    out.sealevelPressure_Pa = P0;
    out.pressure_Pa = P;
    out.pressure_hPa = P / 100;
    out.pressure_atm = P / 101325;
end

function out = act_wind_power(opts)
    v = opts.speed;
    D = opts.diameter;
    rho = opts.rho;
    A = pi * D^2 / 4;
    % Betz limit: max 59.3% of kinetic energy flux
    P_kinetic = 0.5 * rho * A * v^3;
    P_betz = P_kinetic * 0.593;
    % Practical: ~35% efficiency
    P_practical = P_kinetic * 0.35;
    out = struct();
    out.action = 'wind_power';
    out.speed_m_s = v;
    out.diameter_m = D;
    out.sweptArea_m2 = A;
    out.kineticPower_MW = P_kinetic / 1e6;
    out.betzLimit_MW = P_betz / 1e6;
    out.estimatedPower_MW = P_practical / 1e6;
end

% =================== Helpers ===================
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
