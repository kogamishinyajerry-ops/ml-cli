function cli_fire(action, varargin)
% CLI_FIRE Fire safety engineering for ml CLI
%   CLI: ml fire heat_release --area 100 --hrrpua 500 --growth fast
%         ml fire smoke      --HRR 2000 --fuel wood
%         ml fire egress     --density 0.5 --width 1.2 --nPeople 200
%         ml fire flashover  --area 25 --venting 2 --compartment h 2.5
%         ml fire sprinkler  --RTI 100 --temp 68 --distance 3
%         ml fire frr        --structure steel --failureTemp 550 --HRR 5000
%
%   Options:
%     --area M2          fire area
%     --hrrpua KW/M2     HRR per unit area
%     --growth NAME      slow|medium|fast|ultra_fast
%     --HRR KW           heat release rate
%     --fuel NAME        wood|plastic|gasoline|paper|cotton
%     --density P/M2     occupant density
%     --width M          exit width
%     --nPeople N        number of occupants
%     --venting M2       venting area
%     --compartment H M  compartment height
%     --RTI M·S^1/2      Response Time Index
%     --temp C           activation temperature
%     --distance M       sprinkler spacing
%     --structure NAME   steel|concrete|timber
%     --failureTemp C    structural failure temperature

    if nargin < 1, error('ml fire <action> [options]'); end

    opts = struct('format','json','area',100,'hrrpua',500,'growth','fast', ...
                  'HRR',2000,'fuel','wood', ...
                  'density',0.5,'width',1.2,'nPeople',200, ...
                  'venting',2,'compartmentHeight',2.5, ...
                  'RTI',100,'temp_act',68,'dist',3, ...
                  'structure','steel','failureTemp',550,'HRR_fire',5000);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--area',       opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--hrrpua',     opts.hrrpua = parse_num(varargin{i+1}); i=i+2;
            case '--growth',     opts.growth = lower(varargin{i+1}); i=i+2;
            case '--HRR',        opts.HRR = parse_num(varargin{i+1}); i=i+2;
            case '--fuel',       opts.fuel = lower(varargin{i+1}); i=i+2;
            case '--density',    opts.density = parse_num(varargin{i+1}); i=i+2;
            case '--width',      opts.width = parse_num(varargin{i+1}); i=i+2;
            case '--nPeople',    opts.nPeople = round(parse_num(varargin{i+1})); i=i+2;
            case '--venting',    opts.venting = parse_num(varargin{i+1}); i=i+2;
            case '--compartment',opts.compartmentHeight = parse_num(varargin{i+1}); i=i+2;
            case '--RTI',        opts.RTI = parse_num(varargin{i+1}); i=i+2;
            case '--temp',       opts.temp_act = parse_num(varargin{i+1}); i=i+2;
            case '--distance',   opts.dist = parse_num(varargin{i+1}); i=i+2;
            case '--structure',  opts.structure = lower(varargin{i+1}); i=i+2;
            case '--failureTemp',opts.failureTemp = parse_num(varargin{i+1}); i=i+2;
            case '--HRR_fire',   opts.HRR_fire = parse_num(varargin{i+1}); i=i+2;
            case '--format',     opts.format = varargin{i+1}; i=i+2;
            otherwise,           i=i+1;
        end
    end

    try
        switch lower(action)
            case 'heat_release', out = act_heat_release(opts);
            case 'smoke',        out = act_smoke(opts);
            case 'egress',       out = act_egress(opts);
            case 'flashover',    out = act_flashover(opts);
            case 'sprinkler',    out = act_sprinkler(opts);
            case 'frr',          out = act_frr(opts);
            otherwise,           error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_heat_release(opts)
    A = opts.area; q = opts.hrrpua;
    growth = opts.growth;
    % t-squared fire: Q = alpha*t^2, alpha = growth rate
    alphaMap = struct('slow', 0.00293, 'medium', 0.01172, ...
                      'fast', 0.0469, 'ultra_fast', 0.1876);
    if isfield(alphaMap, growth)
        alpha = alphaMap.(growth);
    else
        alpha = 0.0469;
    end
    Q_max = A * q;  % kW
    t_growth = sqrt(Q_max / alpha);  % s
    out = struct();
    out.action = 'heat_release';
    out.fireArea_m2 = A;
    out.HRRpua_kW_per_m2 = q;
    out.growthRate = growth;
    out.alpha_kW_per_s2 = alpha;
    out.peakHRR_kW = Q_max;
    out.growthTime_s = t_growth;
    out.growthTime_min = t_growth / 60;
end

function out = act_smoke(opts)
    HRR = opts.HRR;
    fuel = opts.fuel;
    % Smoke yield (kg smoke per kg fuel burned)
    yieldMap = struct('wood', 0.015, 'plastic', 0.1, 'gasoline', 0.05, ...
                      'paper', 0.01, 'cotton', 0.02);
    heatCombustionMap = struct('wood', 13, 'plastic', 25, 'gasoline', 44, ...
                               'paper', 15, 'cotton', 17);
    if isfield(yieldMap, fuel), y = yieldMap.(fuel); else, y = 0.03; end
    if isfield(heatCombustionMap, fuel), Hc = heatCombustionMap.(fuel); else, Hc = 15; end
    m_fuel = HRR / Hc;  % g/s fuel burning rate
    smokeRate = y * m_fuel;  % g/s smoke production
    out = struct();
    out.action = 'smoke';
    out.HRR_kW = HRR; out.fuel = fuel;
    out.heatOfCombustion_MJ_per_kg = Hc;
    out.smokeYield_kg_per_kg = y;
    out.smokeProductionRate_g_per_s = smokeRate;
end

function out = act_egress(opts)
    D = opts.density; W = opts.width; n = opts.nPeople;
    % Specific flow: Fs = (1 - 0.266*D) * 1.3 (persons/m·s at max density)
    Fs = max(0, (1 - 0.266*D)) * 1.3;
    % Flow through exit: Fc = Fs * We
    We = W - 0.3;  % effective width (boundary layer)
    Fc = Fs * We;  % persons/s
    % Evacuation time through this exit
    T_e = n / Fc;  % s
    out = struct();
    out.action = 'egress';
    out.occupantDensity_p_per_m2 = D;
    out.exitWidth_m = W; out.effectiveWidth_m = We;
    out.occupants = n;
    out.specificFlow = Fs;
    out.flow_per_s = Fc;
    out.evacuationTime_s = T_e;
    out.evacuationTime_min = T_e / 60;
end

function out = act_flashover(opts)
    A = opts.area; Av = opts.venting;
    H = opts.compartmentHeight;
    % Thomas flashover criterion: Q_fo = 7.8*A + 378*Av*sqrt(H)
    Q_fo = 7.8 * A + 378 * Av * sqrt(H);  % kW
    out = struct();
    out.action = 'flashover';
    out.method = 'Thomas criterion';
    out.compartmentArea_m2 = A;
    out.ventingArea_m2 = Av;
    out.compartmentHeight_m = H;
    out.flashoverHRR_kW = Q_fo;
end

function out = act_sprinkler(opts)
    RTI = opts.RTI; T_act = opts.temp_act; d = opts.dist;
    % Activation time for t-squared fire
    alpha = 0.0469;  % fast growth
    % DETACT-QS simplified
    % tau = RTI / sqrt(u), u = gas velocity (simplified)
    tau = RTI / sqrt(2.5);
    % Activation time approximation
    t_act_est = (RTI * log((500 - 20)/(500 - T_act))) / sqrt(2.5);
    out = struct();
    out.action = 'sprinkler';
    out.RTI = RTI; out.activationTemp_C = T_act;
    out.spacing_m = d;
    out.timeConstant_s = tau;
    out.estimatedActivationTime_s = t_act_est;
end

function out = act_frr(opts)
    structType = opts.structure;
    Tfail = opts.failureTemp;
    HRR = opts.HRR_fire;
    % Eurocode parametric fire: T_gas = 20 + 345*log10(8*t + 1)
    % Steel temperature rise (simplified lumped capacitance)
    t = 60;  % assess at 60 minutes
    T_gas = 20 + 345 * log10(8*t + 1);
    % Section factor Am/V = 100 for typical steel
    AmV = 100;
    rho_s = 7850; Cs = 600;  % steel properties
    dT = (T_gas - 20) * (AmV / (rho_s * Cs));
    Tsteel = min(T_gas, 20 + dT);
    Tsteel = 20 + 0.7*(T_gas - 20);  % simplified
    frr = 60;  % minutes (default)
    safe = Tsteel < Tfail;
    out = struct();
    out.action = 'frr';
    out.structureType = structType;
    out.failureTemp_C = Tfail;
    out.fireGasTemp_C = T_gas;
    out.estimatedSteelTemp_C = Tsteel;
    out.fireResistanceRating_min = frr;
    out.safe = safe;
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
