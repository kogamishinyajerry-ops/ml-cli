function cli_corrosion(action, varargin)
% CLI_CORROSION Corrosion engineering for ml CLI
%   CLI: ml corrosion rate    --metal steel --environment marine --temp 25
%         ml corrosion galvanic --anode zinc --cathode steel --areaRatio 10
%         ml corrosion cp      --current 0.5 --area 10 --rho 15
%         ml corrosion coating --thickness 300 --defects 5 --area 50
%         ml corrosion life    --corrosionRate 0.1 --wallThick 10 --allowable 3
%         ml corrosion potential --ph 7 --temp 25 --metal iron
%
%   Options:
%     --metal NAME        steel|aluminum|copper|zinc|iron|stainless
%     --environment NAME  marine|industrial|rural|buried|atmospheric
%     --temp C            temperature
%     --anode/--cathode   galvanic couple metals
%     --areaRatio         cathode/anode area ratio
%     --current A         protection current
%     --area M2           surface area
%     --rho OHM_M         soil resistivity
%     --thickness UM      coating thickness
%     --defects N         number of coating defects
%     --corrosionRate MM/YR  corrosion rate
%     --wallThick MM      original wall thickness
%     --allowable MM      minimum allowable thickness
%     --ph                pH of environment
%     --format json|table|csv

    if nargin < 1, error('ml corrosion <action> [options]'); end

    opts = struct('format','json','metal','steel','environment','marine','temp',25, ...
                  'anode','zinc','cathode','steel','areaRatio',10, ...
                  'current',0.5,'area',10,'rho',15, ...
                  'thickness',300,'defects',5,'area_coat',50, ...
                  'corrosionRate',0.1,'wallThick',10,'allowable',3, ...
                  'ph',7);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--metal',       opts.metal = lower(varargin{i+1}); i=i+2;
            case '--environment', opts.environment = lower(varargin{i+1}); i=i+2;
            case '--temp',        opts.temp = parse_num(varargin{i+1}); i=i+2;
            case '--anode',       opts.anode = lower(varargin{i+1}); i=i+2;
            case '--cathode',     opts.cathode = lower(varargin{i+1}); i=i+2;
            case '--areaRatio',   opts.areaRatio = parse_num(varargin{i+1}); i=i+2;
            case '--current',     opts.current = parse_num(varargin{i+1}); i=i+2;
            case '--area',        opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--rho',         opts.rho = parse_num(varargin{i+1}); i=i+2;
            case '--thickness',   opts.thickness = parse_num(varargin{i+1}); i=i+2;
            case '--defects',     opts.defects = round(parse_num(varargin{i+1})); i=i+2;
            case '--area_coat',   opts.area_coat = parse_num(varargin{i+1}); i=i+2;
            case '--corrosionRate',opts.corrosionRate = parse_num(varargin{i+1}); i=i+2;
            case '--wallThick',   opts.wallThick = parse_num(varargin{i+1}); i=i+2;
            case '--allowable',   opts.allowable = parse_num(varargin{i+1}); i=i+2;
            case '--ph',          opts.ph = parse_num(varargin{i+1}); i=i+2;
            case '--format',      opts.format = varargin{i+1}; i=i+2;
            otherwise,            i=i+1;
        end
    end

    try
        switch lower(action)
            case 'rate',      out = act_rate(opts);
            case 'galvanic',  out = act_galvanic(opts);
            case 'cp',        out = act_cp(opts);
            case 'coating',   out = act_coating(opts);
            case 'life',      out = act_life(opts);
            case 'potential', out = act_potential(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_rate(opts)
    metal = opts.metal;
    env = opts.environment;
    T = opts.temp;
    % Base corrosion rates (mm/year) for carbon steel
    baseRate = struct('rural', 0.03, 'urban', 0.06, 'industrial', 0.08, ...
                      'marine', 0.12, 'buried', 0.05, 'atmospheric', 0.04);
    metalFactor = struct('steel', 1.0, 'aluminum', 0.3, 'copper', 0.15, ...
                         'zinc', 0.4, 'iron', 1.1, 'stainless', 0.02);
    if isfield(baseRate, env), br = baseRate.(env); else, br = 0.05; end
    if isfield(metalFactor, metal), mf = metalFactor.(metal); else, mf = 1.0; end
    % Temperature adjustment (Arrhenius-like)
    tempFactor = exp(0.02 * (T - 20));
    rate = br * mf * tempFactor;
    out = struct();
    out.action = 'rate';
    out.metal = metal; out.environment = env; out.temp_C = T;
    out.corrosionRate_mm_per_year = rate;
    out.rateCategory = ternary_str(rate<0.05,'low',ternary_str(rate<0.1,'moderate',ternary_str(rate<0.2,'high','severe')));
end

function out = act_galvanic(opts)
    anode = opts.anode; cathode = opts.cathode; ratio = opts.areaRatio;
    % Galvanic series potentials (V vs SCE, approximate)
    potentials = struct('magnesium', -1.6, 'zinc', -1.05, 'aluminum', -0.8, ...
                        'steel', -0.6, 'iron', -0.55, 'stainless', -0.1, ...
                        'copper', -0.15, 'nickel', -0.1, 'titanium', 0.0, ...
                        'silver', 0.1, 'gold', 0.2, 'graphite', 0.3);
    a_pot = get_potential(potentials, anode);
    c_pot = get_potential(potentials, cathode);
    cellVoltage = c_pot - a_pot;
    % Anodic index: higher = faster corrosion of anode
    anodicIndex = cellVoltage * ratio;
    if anodicIndex > 0.5
        severity = 'severe galvanic corrosion';
    elseif anodicIndex > 0.2
        severity = 'significant';
    elseif anodicIndex > 0.1
        severity = 'moderate';
    else
        severity = 'low risk';
    end
    out = struct();
    out.action = 'galvanic';
    out.anode = anode; out.cathode = cathode;
    out.anodePotential_V = a_pot;
    out.cathodePotential_V = c_pot;
    out.cellVoltage_V = cellVoltage;
    out.areaRatio = ratio;
    out.anodicIndex = anodicIndex;
    out.severity = severity;
end

function out = act_cp(opts)
    I = opts.current;
    A = opts.area;
    rho = opts.rho;
    % Current density
    J = I / A;  % A/m²
    % Anode consumption (zinc: 11 kg/A·yr)
    anodeConsumption = I * 11 * 1;  % kg/year
    % Voltage drop (simplified Dwight's equation for groundbed)
    L = 1.5; D = 0.1;
    R_anode = rho / (2*pi*L) * (log(4*L/D) - 1);
    V_req = I * R_anode;
    out = struct();
    out.action = 'cp';
    out.protectionCurrent_A = I;
    out.surfaceArea_m2 = A;
    out.currentDensity_A_per_m2 = J;
    out.soilResistivity_ohm_m = rho;
    out.anodeConsumption_kg_per_year = anodeConsumption;
    out.groundbedResistance_ohm = R_anode;
    out.requiredVoltage_V = V_req;
end

function out = act_coating(opts)
    t = opts.thickness;
    n = opts.defects;
    area = opts.area_coat;
    if area <= 0, area = 1; end
    % Defect density
    defectDensity = n / area;  % defects/m²
    % Coating breakdown factor with age
    age = 10;  % assumed years
    f_c = 0.01 + 0.005 * age;  % breakdown factor
    effectiveArea = area * f_c;
    % Holiday detection
    holidayLimit = 1;  % 1 defect per 100 m² is typical limit
    acceptable = defectDensity < holidayLimit;
    out = struct();
    out.action = 'coating';
    out.thickness_um = t;
    out.defects = n;
    out.area_m2 = area;
    out.defectDensity_per_m2 = defectDensity;
    out.coatingBreakdownFactor = f_c;
    out.effectiveBareArea_m2 = effectiveArea;
    out.acceptable = acceptable;
end

function out = act_life(opts)
    cr = opts.corrosionRate;
    t0 = opts.wallThick;
    t_min = opts.allowable;
    life = (t0 - t_min) / cr;  % years
    out = struct();
    out.action = 'life';
    out.corrosionRate_mm_per_yr = cr;
    out.originalThickness_mm = t0;
    out.minAllowable_mm = t_min;
    out.corrosionAllowance_mm = t0 - t_min;
    out.remainingLife_years = life;
end

function out = act_potential(opts)
    pH = opts.ph;
    temp = opts.temp + 273.15;
    metal = opts.metal;
    % Pourbaix (potential-pH) simplified
    % Nernst equation for Fe ↔ Fe²⁺ + 2e⁻: E = E° + RT/(2F)*ln([Fe²⁺])
    R = 8.314; F = 96485;
    switch metal
        case 'iron'
            E0 = -0.44;  % V vs SHE
            E = E0 + R*temp/(2*F) * log(1e-6);
            % Pourbaix regions
            if pH < 5
                region = 'corrosion active (acidic)';
                immunity = false;
            elseif pH < 9
                region = 'corrosion possible (neutral)';
                immunity = false;
            else
                region = 'passivation favorable (alkaline)';
                immunity = true;
            end
        case 'aluminum'
            E = -1.66;
            if pH < 4, region = 'corrosion (acidic)';
            elseif pH > 9, region = 'corrosion (alkaline)';
            else, region = 'passive (neutral)'; end
            immunity = (pH > 4 && pH < 9);
        otherwise
            E = -0.5; region = 'see Pourbaix diagram'; immunity = false;
    end
    out = struct();
    out.action = 'potential';
    out.metal = metal; out.pH = pH; out.temp_C = temp - 273.15;
    out.potential_V_she = E;
    out.pourbaixRegion = region;
    out.immune = immunity;
end

% =================== Helpers ===================
function p = get_potential(potMap, metal)
    if isfield(potMap, metal), p = potMap.(metal); else, p = -0.5; end
end

function s = ternary_str(cond, a, b)
    if cond, s = a; else, s = b; end
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
