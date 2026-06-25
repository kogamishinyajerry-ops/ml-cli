function cli_pavement(action, varargin)
% CLI_PAVEMENT Pavement design for ml CLI
%   CLI: ml pavement aashto  --W18 5e6 --R 85 --S0 0.45 --Mr 5000 --dpsi 1.5
%         ml pavement esal   --axleLoad 80 --n 1000 --SN 5
%         ml pavement fatigue --strain 200e-6 --E 3000 --nCycles 1e6
%         ml pavement rutting --strain 400e-6 --E 3000 --nCycles 1e6
%         ml pavement layer   --SN 5 --a1 0.44 --a2 0.14 --a3 0.08 --m2 1.0 --m3 1.0
%         ml pavement cost    --area 10000 --thickness "[0.15,0.2,0.1]" --unitCost "[50,40,30]"
%
%   Options:
%     --W18 MILLIONS   design ESALs
%     --R PCT          reliability
%     --S0 FLOAT       overall standard deviation
%     --Mr MPa         subgrade resilient modulus
%     --dpsi FLOAT     serviceability loss
%     --axleLoad KN    axle load
%     --n COUNT        number of axle passes
%     --SN FLOAT       structural number
%     --strain         tensile strain at bottom of asphalt
%     --E MPa          material modulus
%     --nCycles        number of load cycles
%     --a1/--a2/--a3   layer coefficients
%     --m2/--m3        drainage coefficients
%     --area M2        pavement area
%     --thickness VEC  layer thicknesses
%     --unitCost VEC   unit costs per m³

    if nargin < 1, error('ml pavement <action> [options]'); end

    opts = struct('format','json','W18',5,'R',85,'S0',0.45,'Mr',5000,'dpsi',1.5, ...
                  'axleLoad',80,'n',1000,'SN',5, ...
                  'strain',200e-6,'E',3000,'nCycles',1e6, ...
                  'a1',0.44,'a2',0.14,'a3',0.08,'m2',1.0,'m3',1.0, ...
                  'area',10000,'thickness','','unitCost','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--W18',       opts.W18 = parse_num(varargin{i+1}); i=i+2;
            case '--R',         opts.R = parse_num(varargin{i+1}); i=i+2;
            case '--S0',        opts.S0 = parse_num(varargin{i+1}); i=i+2;
            case '--Mr',        opts.Mr = parse_num(varargin{i+1}); i=i+2;
            case '--dpsi',      opts.dpsi = parse_num(varargin{i+1}); i=i+2;
            case '--axleLoad',  opts.axleLoad = parse_num(varargin{i+1}); i=i+2;
            case '--n',         opts.n = parse_num(varargin{i+1}); i=i+2;
            case '--SN',        opts.SN = parse_num(varargin{i+1}); i=i+2;
            case '--strain',    opts.strain = parse_num(varargin{i+1}); i=i+2;
            case '--E',         opts.E = parse_num(varargin{i+1}); i=i+2;
            case '--nCycles',   opts.nCycles = parse_num(varargin{i+1}); i=i+2;
            case '--a1',        opts.a1 = parse_num(varargin{i+1}); i=i+2;
            case '--a2',        opts.a2 = parse_num(varargin{i+1}); i=i+2;
            case '--a3',        opts.a3 = parse_num(varargin{i+1}); i=i+2;
            case '--m2',        opts.m2 = parse_num(varargin{i+1}); i=i+2;
            case '--m3',        opts.m3 = parse_num(varargin{i+1}); i=i+2;
            case '--area',      opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--thickness', opts.thickness = varargin{i+1}; i=i+2;
            case '--unitCost',  opts.unitCost = varargin{i+1}; i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'aashto', out = act_aashto(opts);
            case 'esal',  out = act_esal(opts);
            case 'fatigue',out = act_fatigue(opts);
            case 'rutting',out = act_rutting(opts);
            case 'layer',  out = act_layer(opts);
            case 'cost',   out = act_cost(opts);
            otherwise,     error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_aashto(opts)
    W18 = opts.W18; R = opts.R; S0 = opts.S0;
    Mr = opts.Mr; dpsi = opts.dpsi;
    % AASHTO 1993 flexible pavement design equation (simplified)
    % log10(W18) = ZR*S0 + 9.36*log10(SN+1) - 0.2 + log10(dpsi/(4.2-1.5))/(0.4 + 1094/(SN+1)^5.19) + 2.32*log10(Mr) - 8.07
    % Solve for SN iteratively
    ZR = norminv((100-R)/100);  % ZR from reliability (lower tail)
    if isnan(ZR) || ZR > 3, ZR = -1.037; end  % default for R=85
    % Newton-Raphson solve for SN
    SN = 4.0;  % initial guess
    for iter = 1:50
        f = ZR*S0 + 9.36*log10(SN+1) - 0.2 ...
            + log10(dpsi/(4.2-1.5)) / (0.4 + 1094/(SN+1)^5.19) ...
            + 2.32*log10(Mr) - 8.07 - log10(W18);
        % Finite difference derivative
        h = 0.01;
        f_h = ZR*S0 + 9.36*log10(SN+1+h) - 0.2 ...
              + log10(dpsi/(4.2-1.5)) / (0.4 + 1094/(SN+1+h)^5.19) ...
              + 2.32*log10(Mr) - 8.07 - log10(W18);
        deriv = (f_h - f) / h;
        if abs(deriv) < 1e-12, break; end
        SN_new = SN - f/deriv;
        if abs(SN_new - SN) < 0.001, SN = SN_new; break; end
        SN = SN_new;
    end
    SN = max(1, min(8, SN));
    out = struct();
    out.action = 'aashto';
    out.method = 'AASHTO 1993 flexible pavement';
    out.W18_millions = W18;
    out.reliability_pct = R; out.S0 = S0;
    out.Mr_psi = Mr; out.deltaPSI = dpsi;
    out.structuralNumber = SN;
    out.ZR = ZR;
end

function out = act_esal(opts)
    axle = opts.axleLoad;  % kN
    n = opts.n;
    SN = opts.SN;
    % ESAL factor: ESAL = (axle/80)^4 (4th power law)
    LEF = (axle / 80)^4;
    ESALs = n * LEF;
    out = struct();
    out.action = 'esal';
    out.axleLoad_kN = axle;
    out.axlePasses = n;
    out.loadEquivalencyFactor = LEF;
    out.ESALs = ESALs;
end

function out = act_fatigue(opts)
    e = opts.strain;
    E = opts.E * 1e6;  % MPa → Pa
    N = opts.nCycles;
    % Asphalt Institute fatigue equation: Nf = 0.0796*e^(-3.291)*E^(-0.854)
    Nf = 0.0796 * e^(-3.291) * E^(-0.854);
    % Damage ratio
    damage = N / Nf;
    remaining_cycles = Nf - N;
    out = struct();
    out.action = 'fatigue';
    out.method = 'Asphalt Institute';
    out.tensileStrain = e;
    out.modulus_MPa = opts.E;
    out.cyclesToFailure = Nf;
    out.appliedCycles = N;
    out.damageRatio = damage;
    out.remainingCycles = remaining_cycles;
end

function out = act_rutting(opts)
    e = opts.strain;
    E = opts.E * 1e6;
    N = opts.nCycles;
    % Rutting: Nf = 1.365e-9 * e^(-4.477)
    Nf = 1.365e-9 * e^(-4.477);
    damage = N / Nf;
    out = struct();
    out.action = 'rutting';
    out.method = 'Asphalt Institute (rutting)';
    out.verticalStrain = e;
    out.modulus_MPa = opts.E;
    out.cyclesToFailure = Nf;
    out.appliedCycles = N;
    out.damageRatio = damage;
end

function out = act_layer(opts)
    SN = opts.SN;
    a1 = opts.a1; a2 = opts.a2; a3 = opts.a3;
    m2 = opts.m2; m3 = opts.m3;
    % SN = a1*D1 + a2*D2*m2 + a3*D3*m3
    % Solve for D1, D2, D3 given target SN (equal thickness assumption)
    coeff_sum = a1 + a2*m2 + a3*m3;
    D_total = SN / coeff_sum;
    D1 = D_total / 3;
    D2 = D_total / 3;
    D3 = D_total / 3;
    out = struct();
    out.action = 'layer';
    out.method = 'AASHTO layer coefficient method';
    out.SN_target = SN;
    out.layerCoefficients = struct('a1',a1,'a2',a2,'a3',a3);
    out.drainageCoefficients = struct('m2',m2,'m3',m3);
    out.thicknesses_mm = struct('D1', D1*25.4, 'D2', D2*25.4, 'D3', D3*25.4);
end

function out = act_cost(opts)
    area = opts.area;
    t = parse_vec(opts.thickness);
    uc = parse_vec(opts.unitCost);
    % Material cost per layer
    costs = zeros(1, min(numel(t), numel(uc)));
    for k = 1:min(numel(t), numel(uc))
        costs(k) = area * t(k) * uc(k);
    end
    totalCost = sum(costs);
    out = struct();
    out.action = 'cost';
    out.area_m2 = area;
    out.layerThickness_m = t;
    out.unitCost_per_m3 = uc;
    out.layerCosts = costs;
    out.totalCost = totalCost;
end

% =================== Helpers ===================
function v = parse_vec(s)
    if ischar(s) || isstring(s)
        s = regexprep(s, '[\[\]{},]', ' ');
        v = sscanf(s, '%f');
        v = v(:)';
    elseif isvector(s)
        v = s(:)';
    else
        v = s(:)';
    end
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
