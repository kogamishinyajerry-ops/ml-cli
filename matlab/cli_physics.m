function cli_physics(action, varargin)
% CLI_PHYSICS Physics calculations for ml CLI
%   CLI: ml physics constants --name c
%         ml physics kinematics --v0 0 --a 9.8 --t 3 --solve d
%         ml physics projectile --v0 50 --angle 45
%         ml physics energy --m 2 --v 10 --h 5
%         ml physics waves --f 440 --lambda 0.78 --solve v
%         ml physics thermo --m 1 --c 4186 --dt 80
%         ml physics circuit --v 12 --r "[10 20 30]" --type series
%
%   Options:
%     --name N      constant name (c|h|G|k_B|e|m_e|m_p|N_A|sigma|g|R|all)
%     --v0 --a --t --d  kinematics variables
%     --angle DEG    projectile launch angle
%     --h0 --g       initial height, gravity
%     --m --v --h    mass, velocity, height for energy
%     --f --lambda --medium  wave parameters
%     --source_v --observer_v  doppler velocities
%     --c --dt --latent  specific heat, temp change, latent heat
%     --radiation --emissivity --area --t --t_env  Stefan-Boltzmann
%     --v --r --type  circuit voltage, resistor array, series|parallel
%     --solve NAME   variable to solve for
%     --format json|table|csv

    if nargin < 1, error('ml physics <action> [options]'); end

    opts = struct('format','json','name','c','v0',0,'a',9.81,'t',1,'d',0,'solve','d', ...
                  'angle',45,'h0',0,'g',9.81, ...
                  'm',1,'v',0,'h',0, ...
                  'f',440,'lambda',0.78,'medium','air', ...
                  'source_v',0,'observer_v',0,'v_sound',343, ...
                  'c',4186,'dt',10,'latent',0,'mass',1, ...
                  'radiation',false,'emissivity',0.9,'area',1,'temp',300,'t_env',293, ...
                  'volts',12,'r','','type','series');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--name',       opts.name = lower(varargin{i+1}); i=i+2;
            case '--v0',         opts.v0 = parse_num(varargin{i+1}); i=i+2;
            case '--a',          opts.a = parse_num(varargin{i+1}); i=i+2;
            case '--t',          opts.t = parse_num(varargin{i+1}); i=i+2;
            case '--d',          opts.d = parse_num(varargin{i+1}); i=i+2;
            case '--solve',      opts.solve = lower(varargin{i+1}); i=i+2;
            case '--angle',      opts.angle = parse_num(varargin{i+1}); i=i+2;
            case '--h0',         opts.h0 = parse_num(varargin{i+1}); i=i+2;
            case '--g',          opts.g = parse_num(varargin{i+1}); i=i+2;
            case '--m',          opts.m = parse_num(varargin{i+1}); i=i+2;
            case '--v',          opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--h',          opts.h = parse_num(varargin{i+1}); i=i+2;
            case '--f',          opts.f = parse_num(varargin{i+1}); i=i+2;
            case '--lambda',     opts.lambda = parse_num(varargin{i+1}); i=i+2;
            case '--medium',     opts.medium = lower(varargin{i+1}); i=i+2;
            case '--source_v',   opts.source_v = parse_num(varargin{i+1}); i=i+2;
            case '--observer_v', opts.observer_v = parse_num(varargin{i+1}); i=i+2;
            case '--v_sound',    opts.v_sound = parse_num(varargin{i+1}); i=i+2;
            case '--c',          opts.c = parse_num(varargin{i+1}); i=i+2;
            case '--dt',         opts.dt = parse_num(varargin{i+1}); i=i+2;
            case '--latent',     opts.latent = parse_num(varargin{i+1}); i=i+2;
            case '--mass',       opts.mass = parse_num(varargin{i+1}); i=i+2;
            case '--radiation',  opts.radiation = true; i=i+1;
            case '--emissivity', opts.emissivity = parse_num(varargin{i+1}); i=i+2;
            case '--area',       opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--temp',       opts.temp = parse_num(varargin{i+1}); i=i+2;
            case '--t_env',      opts.t_env = parse_num(varargin{i+1}); i=i+2;
            case '--volts',      opts.volts = parse_num(varargin{i+1}); i=i+2;
            case '--r',          opts.r = varargin{i+1}; i=i+2;
            case '--type',       opts.type = lower(varargin{i+1}); i=i+2;
            case '--format',     opts.format = varargin{i+1}; i=i+2;
            otherwise,           i=i+1;
        end
    end

    try
        switch lower(action)
            case 'constants',  out = act_constants(opts);
            case 'kinematics', out = act_kinematics(opts);
            case 'projectile', out = act_projectile(opts);
            case 'energy',     out = act_energy(opts);
            case 'waves',      out = act_waves(opts);
            case 'thermo',     out = act_thermo(opts);
            case 'circuit',    out = act_circuit(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_constants(opts)
    name = opts.name;
    consts = constants_table();
    if strcmp(name, 'all')
        out = struct();
        out.action = 'constants';
        out.list = consts;
    else
        if ~isfield(consts, name)
            error('unknown constant: %s', name);
        end
        out = struct();
        out.action = 'constants';
        out.name = name;
        out.value = consts.(name).value;
        out.units = consts.(name).units;
        out.description = consts.(name).description;
    end
end

function out = act_kinematics(opts)
    solve = opts.solve;
    v0 = opts.v0; a = opts.a; t = opts.t; d = opts.d;
    switch solve
        case 'd'
            val = v0*t + 0.5*a*t^2;
            unit = 'm';
            eq = 'd = v0*t + 0.5*a*t^2';
        case 'v'
            val = v0 + a*t;
            unit = 'm/s';
            eq = 'v = v0 + a*t';
        case 't'
            if abs(a) < 1e-10, error('a=0, cannot solve for t'); end
            val = (sqrt(v0^2 + 2*a*d) - v0) / a;
            unit = 's';
            eq = 'v^2 = v0^2 + 2*a*d, t = (v-v0)/a';
        otherwise
            error('solve must be d|v|t');
    end
    out = struct();
    out.action = 'kinematics';
    out.equation = eq;
    out.solved = solve;
    out.value = val;
    out.units = unit;
    out.given = struct('v0',v0,'a',a,'t',t,'d',d);
end

function out = act_projectile(opts)
    v0 = opts.v0;
    angle = opts.angle;
    h0 = opts.h0;
    g = opts.g;
    theta = deg2rad(angle);
    vx = v0 * cos(theta);
    vy0 = v0 * sin(theta);
    % Time of flight (assuming landing at h0)
    tFlight = 2 * vy0 / g;
    % Max height (above h0)
    hMax = h0 + vy0^2 / (2*g);
    % Range
    range = vx * tFlight;
    % Trajectory samples
    tSamples = linspace(0, tFlight, 20);
    xSamples = vx * tSamples;
    ySamples = h0 + vy0 * tSamples - 0.5 * g * tSamples.^2;
    out = struct();
    out.action = 'projectile';
    out.v0 = v0;
    out.angle_deg = angle;
    out.g = g;
    out.vx = vx;
    out.vy0 = vy0;
    out.timeOfFlight = tFlight;
    out.maxHeight = hMax;
    out.range = range;
    out.trajectory_t = tSamples;
    out.trajectory_x = xSamples;
    out.trajectory_y = ySamples;
end

function out = act_energy(opts)
    m = opts.m; v = opts.v; h = opts.h;
    g = 9.81;
    KE = 0.5 * m * v^2;
    PE = m * g * h;
    ME = KE + PE;
    out = struct();
    out.action = 'energy';
    out.m = m; out.v = v; out.h = h;
    out.kineticEnergy_J = KE;
    out.potentialEnergy_J = PE;
    out.mechanicalEnergy_J = ME;
end

function out = act_waves(opts)
    f = opts.f;
    lambda = opts.lambda;
    solve = opts.solve;
    switch solve
        case 'v'
            val = f * lambda;
            unit = 'm/s';
            given = struct('f_Hz',f,'lambda_m',lambda);
        case 'f'
            if lambda == 0, error('lambda cannot be 0'); end
            val = opts.v_sound / lambda;
            unit = 'Hz';
            given = struct('v_m_s',opts.v_sound,'lambda_m',lambda);
        case 'lambda'
            if f == 0, error('f cannot be 0'); end
            val = opts.v_sound / f;
            unit = 'm';
            given = struct('v_m_s',opts.v_sound,'f_Hz',f);
        otherwise
            error('solve must be v|f|lambda');
    end
    out = struct();
    out.action = 'waves';
    out.equation = 'v = f * lambda';
    out.solved = solve;
    out.value = val;
    out.units = unit;
    out.given = given;
    % Doppler effect if source/observer moving
    if opts.source_v ~= 0 || opts.observer_v ~= 0
        vs = opts.source_v;
        vo = opts.observer_v;
        c = opts.v_sound;
        if solve ~= 'f'
            fObserved = f * (c + vo) / (c - vs);
            out.doppler = struct();
            out.doppler.sourceFreq = f;
            out.doppler.observedFreq = fObserved;
            out.doppler.sourceV = vs;
            out.doppler.observerV = vo;
            out.doppler.waveSpeed = c;
        end
    end
end

function out = act_thermo(opts)
    m = opts.mass;
    c = opts.c;
    dt = opts.dt;
    Q = m * c * dt;
    out = struct();
    out.action = 'thermo';
    out.equation = 'Q = m * c * dt';
    out.mass_kg = m;
    out.specificHeat_J_per_kgK = c;
    out.deltaTemp_K = dt;
    out.heat_J = Q;
    if opts.latent > 0
        Qlatent = m * opts.latent;
        out.latentHeat_J = Qlatent;
        out.totalHeat_J = Q + Qlatent;
    end
    if opts.radiation
        sigma = 5.670374e-8;
        P = opts.emissivity * sigma * opts.area * (opts.temp^4 - opts.t_env^4);
        out.radiatedPower_W = P;
        out.emissivity = opts.emissivity;
        out.area_m2 = opts.area;
        out.temp_K = opts.temp;
        out.tEnv_K = opts.t_env;
    end
end

function out = act_circuit(opts)
    V = opts.volts;
    R = parse_vec(opts.r);
    type = opts.type;
    switch type
        case 'series'
            Rtotal = sum(R);
        case 'parallel'
            Rtotal = 1 / sum(1 ./ R);
        otherwise
            error('unknown type: %s (series|parallel)', type);
    end
    I = V / Rtotal;
    P = V * I;
    if strcmp(type, 'series')
        vDrop = I * R;
    else
        vDrop = V * ones(size(R));  % all same V across each
    end
    out = struct();
    out.action = 'circuit';
    out.voltage = V;
    out.resistors = R;
    out.type = type;
    out.totalResistance = Rtotal;
    out.current = I;
    out.power = P;
    out.voltageDrops = vDrop;
end

% =================== Constants table ===================
function c = constants_table()
    c = struct();
    c.c       = struct('value', 299792458, 'units','m/s', 'description','speed of light in vacuum');
    c.h       = struct('value', 6.62607015e-34, 'units','J*s', 'description','Planck constant');
    c.G       = struct('value', 6.674e-11, 'units','N*m^2/kg^2', 'description','gravitational constant');
    c.k_B     = struct('value', 1.380649e-23, 'units','J/K', 'description','Boltzmann constant');
    c.e       = struct('value', 1.602176634e-19, 'units','C', 'description','elementary charge');
    c.m_e     = struct('value', 9.1093837e-31, 'units','kg', 'description','electron mass');
    c.m_p     = struct('value', 1.6726219e-27, 'units','kg', 'description','proton mass');
    c.N_A     = struct('value', 6.02214076e23, 'units','/mol', 'description','Avogadro number');
    c.epsilon_0 = struct('value', 8.8541878128e-12, 'units','F/m', 'description','vacuum permittivity');
    c.mu_0    = struct('value', 1.25663706212e-6, 'units','H/m', 'description','vacuum permeability');
    c.sigma   = struct('value', 5.670374e-8, 'units','W/(m^2*K^4)', 'description','Stefan-Boltzmann constant');
    c.g       = struct('value', 9.80665, 'units','m/s^2', 'description','standard gravity');
    c.R       = struct('value', 8.314, 'units','J/(mol*K)', 'description','gas constant');
    c.k_e     = struct('value', 8.9875517873681764e9, 'units','N*m^2/C^2', 'description','Coulomb constant');
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

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
