function cli_ventilation(action, varargin)
% CLI_VENTILATION HVAC & ventilation for ml CLI
%   CLI: ml ventilation duct    --flow 0.5 --velocity 6
%         ml ventilation pressure_loss --length 10 --diameter 0.3 --flow 0.5 --roughness 0.0001
%         ml ventilation cooling --area 200 --occupants 50 --lighting 15 --equipment 20
%         ml ventilation fan     --flow 1.0 --pressure 250 --efficiency 0.7
%         ml ventilation air_change --volume 500 --ach 6
%         ml ventilation natural  --A 2 --h 3 --dT 10 --Cd 0.62
%
%   Options:
%     --flow M3/S      airflow rate
%     --velocity M/S   air velocity
%     --length M       duct length
%     --diameter M     duct diameter
%     --roughness M    duct wall roughness
%     --area M2        floor area
%     --occupants N    number of occupants
%     --lighting W/M2  lighting power density
%     --equipment W/M2  equipment power density
%     --pressure Pa    fan pressure
%     --efficiency     fan efficiency
%     --volume M3      room volume
%     --ach N           air changes per hour
%     --A M2           opening area
%     --h M            opening height
%     --dT K           temperature difference
%     --Cd             discharge coefficient
%     --format json|table|csv

    if nargin < 1, error('ml ventilation <action> [options]'); end

    opts = struct('format','json','flow',0.5,'velocity',6, ...
                  'length',10,'diameter',0.3,'roughness',0.0001, ...
                  'area',200,'occupants',50,'lighting',15,'equipment',20, ...
                  'pressure',250,'efficiency',0.7, ...
                  'volume',500,'ach',6, ...
                  'A',2,'h_val',3,'dT',10,'Cd',0.62);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--flow',      opts.flow = parse_num(varargin{i+1}); i=i+2;
            case '--velocity',  opts.velocity = parse_num(varargin{i+1}); i=i+2;
            case '--length',    opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--diameter',  opts.diameter = parse_num(varargin{i+1}); i=i+2;
            case '--roughness', opts.roughness = parse_num(varargin{i+1}); i=i+2;
            case '--area',      opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--occupants', opts.occupants = round(parse_num(varargin{i+1})); i=i+2;
            case '--lighting',  opts.lighting = parse_num(varargin{i+1}); i=i+2;
            case '--equipment', opts.equipment = parse_num(varargin{i+1}); i=i+2;
            case '--pressure',  opts.pressure = parse_num(varargin{i+1}); i=i+2;
            case '--efficiency',opts.efficiency = parse_num(varargin{i+1}); i=i+2;
            case '--volume',    opts.volume = parse_num(varargin{i+1}); i=i+2;
            case '--ach',       opts.ach = parse_num(varargin{i+1}); i=i+2;
            case '--A',         opts.A = parse_num(varargin{i+1}); i=i+2;
            case '--h',         opts.h_val = parse_num(varargin{i+1}); i=i+2;
            case '--dT',        opts.dT = parse_num(varargin{i+1}); i=i+2;
            case '--Cd',        opts.Cd = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'duct',         out = act_duct(opts);
            case 'pressure_loss',out = act_pressure_loss(opts);
            case 'cooling',      out = act_cooling(opts);
            case 'fan',          out = act_fan(opts);
            case 'air_change',   out = act_air_change(opts);
            case 'natural',      out = act_natural(opts);
            otherwise,           error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_duct(opts)
    Q = opts.flow; v = opts.velocity;
    % Circular duct: A = Q/v, D = sqrt(4*A/pi), rectangular equivalent
    A_duct = Q / v;
    D_eq = sqrt(4 * A_duct / pi);
    % Rectangular equivalent (1:1 aspect ratio)
    a = sqrt(A_duct);
    b = a;
    out = struct();
    out.action = 'duct';
    out.flow_m3_per_s = Q;
    out.velocity_m_per_s = v;
    out.crossSection_m2 = A_duct;
    out.diameter_m = D_eq;
    out.diameter_mm = D_eq * 1000;
    out.rectEquivalent = struct('width_m',a,'height_m',b);
end

function out = act_pressure_loss(opts)
    L = opts.length; D = opts.diameter; Q = opts.flow;
    eps = opts.roughness;
    % Air properties at 20°C
    rho = 1.2; nu = 1.5e-5;
    A_duct = pi * D^2 / 4; v = Q / A_duct;
    Re = v * D / nu;
    % Colebrook friction factor
    f = 0.02;
    for iter = 1:50
        term1 = eps / (3.7 * D);
        term2 = 2.51 / (Re * sqrt(max(f, 1e-12)));
        f_new = 1 / (-2*log10(term1 + term2))^2;
        if abs(f_new - f) < 1e-8, break; end
        f = f_new;
    end
    % Darcy-Weisbach: ΔP = f * (L/D) * (ρ*v²/2)
    dP = f * (L/D) * (0.5 * rho * v^2);
    out = struct();
    out.action = 'pressure_loss';
    out.length_m = L; out.diameter_m = D;
    out.flow = Q; out.velocity = v;
    out.Re = Re; out.frictionFactor = f;
    out.pressureDrop_Pa = dP;
end

function out = act_cooling(opts)
    area = opts.area; occ = opts.occupants;
    ltg = opts.lighting; equip = opts.equipment;
    % Cooling load calculation (simplified)
    % Occupants: 100W sensible + 40W latent per person
    Q_occ_sens = occ * 100;
    Q_occ_lat = occ * 40;
    % Lighting: 1.0 factor (all converted to heat)
    Q_ltg = area * ltg;
    % Equipment: ~0.5 factor
    Q_equip = area * equip * 0.5;
    % Envelope: ~50 W/m² simplified
    Q_env = area * 50;
    % Total sensible + latent
    Q_sensible = Q_occ_sens + Q_ltg + Q_equip + Q_env;
    Q_latent = Q_occ_lat;
    Q_total = Q_sensible + Q_latent;
    % Tons of refrigeration (1 TR = 3.517 kW = 12,000 BTU/h)
    TR = Q_total / 3517;
    out = struct();
    out.action = 'cooling';
    out.floorArea_m2 = area;
    out.occupants = occ;
    out.loads = struct('occupants_sensible',Q_occ_sens,'occupants_latent',Q_occ_lat, ...
                       'lighting',Q_ltg,'equipment',Q_equip,'envelope',Q_env);
    out.totalSensible_W = Q_sensible;
    out.totalLatent_W = Q_latent;
    out.totalCooling_W = Q_total;
    out.tonsOfRefrigeration = TR;
    out.SHR = Q_sensible / max(Q_total, 1);
end

function out = act_fan(opts)
    Q = opts.flow;
    dP = opts.pressure;
    eta = opts.efficiency;
    % Fan power: P = Q*ΔP/η
    P_fan = Q * dP / eta;  % W
    out = struct();
    out.action = 'fan';
    out.flow_m3_per_s = Q;
    out.pressureRise_Pa = dP;
    out.efficiency = eta;
    out.fanPower_W = P_fan;
    out.fanPower_kW = P_fan / 1000;
end

function out = act_air_change(opts)
    V = opts.volume;
    ACH = opts.ach;
    Q = V * ACH / 3600;  % m³/s
    out = struct();
    out.action = 'air_change';
    out.roomVolume_m3 = V;
    out.airChangesPerHour = ACH;
    out.airflow_m3_per_s = Q;
end

function out = act_natural(opts)
    A = opts.A; h = opts.h_val; dT = opts.dT; Cd = opts.Cd;
    g = 9.81; T_amb = 293.15;
    % Buoyancy-driven natural ventilation: Q = Cd*A*sqrt(2*g*h*(dT/T_amb))
    Q = Cd * A * sqrt(2 * g * h * (dT / T_amb));
    out = struct();
    out.action = 'natural';
    out.openingArea_m2 = A;
    out.height_m = h;
    out.temperatureDifference_K = dT;
    out.Cd = Cd;
    out.airflow_m3_per_s = Q;
    out.airflow_L_per_s = Q * 1000;
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
