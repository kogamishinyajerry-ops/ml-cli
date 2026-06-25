function cli_welding(action, varargin)
% CLI_WELDING Welding engineering for ml CLI
%   CLI: ml welding heat_input --current 200 --voltage 25 --speed 5 --efficiency 0.8
%         ml welding cooling   --heatInput 800 --thickness 10 --temp 200 --preheat 150
%         ml welding ceq       --C 0.15 --Mn 1.2 --Cr 0.5 --Mo 0.2 --V 0.05 --Ni 0.3 --Cu 0.1
%         ml welding preheat   --Ceq 0.45 --thickness 25 --hydrogen low
%         ml welding distortion --length 500 --width 10 --heatInput 1000
%         ml welding strength  --metal steel --filler E70 --thickness 12
%
%   Options:
%     --current A       welding current
%     --voltage V       arc voltage
%     --speed MM/S      travel speed
%     --efficiency      arc efficiency (0-1)
%     --heatInput J/MM  heat input (alternative to current/voltage/speed)
%     --thickness MM     plate thickness
%     --temp C           interpass temperature
%     --preheat C        preheat temperature
%     --C/Mn/Cr/Mo/V/Ni/Cu   alloy percentages
%     --Ceq              carbon equivalent (override calculated)
%     --hydrogen NAME    low|medium|high

    if nargin < 1, error('ml welding <action> [options]'); end

    opts = struct('format','json','current',200,'voltage',25,'speed',5,'efficiency',0.8, ...
                  'heatInput',0,'thickness',10,'temp',200,'preheat',150, ...
                  'C',0.15,'Mn',1.2,'Cr',0.5,'Mo',0.2,'V',0.05,'Ni',0.3,'Cu',0.1, ...
                  'Ceq',0,'hydrogen','low','length',500,'width',10, ...
                  'metal','steel','filler','E70');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--current',    opts.current = parse_num(varargin{i+1}); i=i+2;
            case '--voltage',    opts.voltage = parse_num(varargin{i+1}); i=i+2;
            case '--speed',      opts.speed = parse_num(varargin{i+1}); i=i+2;
            case '--efficiency', opts.efficiency = parse_num(varargin{i+1}); i=i+2;
            case '--heatInput',  opts.heatInput = parse_num(varargin{i+1}); i=i+2;
            case '--thickness',  opts.thickness = parse_num(varargin{i+1}); i=i+2;
            case '--temp',       opts.temp = parse_num(varargin{i+1}); i=i+2;
            case '--preheat',    opts.preheat = parse_num(varargin{i+1}); i=i+2;
            case '--C',          opts.C = parse_num(varargin{i+1}); i=i+2;
            case '--Mn',         opts.Mn = parse_num(varargin{i+1}); i=i+2;
            case '--Cr',         opts.Cr = parse_num(varargin{i+1}); i=i+2;
            case '--Mo',         opts.Mo = parse_num(varargin{i+1}); i=i+2;
            case '--V',          opts.V = parse_num(varargin{i+1}); i=i+2;
            case '--Ni',         opts.Ni = parse_num(varargin{i+1}); i=i+2;
            case '--Cu',         opts.Cu = parse_num(varargin{i+1}); i=i+2;
            case '--Ceq',        opts.Ceq = parse_num(varargin{i+1}); i=i+2;
            case '--hydrogen',   opts.hydrogen = lower(varargin{i+1}); i=i+2;
            case '--length',     opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--width',      opts.width = parse_num(varargin{i+1}); i=i+2;
            case '--metal',      opts.metal = lower(varargin{i+1}); i=i+2;
            case '--filler',     opts.filler = upper(varargin{i+1}); i=i+2;
            case '--format',     opts.format = varargin{i+1}; i=i+2;
            otherwise,           i=i+1;
        end
    end

    try
        switch lower(action)
            case 'heat_input', out = act_heat_input(opts);
            case 'cooling',    out = act_cooling(opts);
            case 'ceq',        out = act_ceq(opts);
            case 'preheat',    out = act_preheat(opts);
            case 'distortion', out = act_distortion(opts);
            case 'strength',   out = act_strength(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_heat_input(opts)
    if opts.heatInput > 0
        HI = opts.heatInput;
    else
        HI = opts.voltage * opts.current * opts.efficiency / opts.speed;  % J/mm
    end
    % Heat input in kJ/mm
    HI_kJ = HI / 1000;
    out = struct();
    out.action = 'heat_input';
    out.current_A = opts.current; out.voltage_V = opts.voltage;
    out.travelSpeed_mm_s = opts.speed; out.arcEfficiency = opts.efficiency;
    out.heatInput_J_per_mm = HI;
    out.heatInput_kJ_per_mm = HI_kJ;
    out.formula = 'HI = V*I*η/v';
end

function out = act_cooling(opts)
    HI = opts.heatInput;
    if HI <= 0
        HI = opts.voltage * opts.current * opts.efficiency / opts.speed;
    end
    t = opts.thickness; T0 = opts.preheat; T = opts.temp;
    % Cooling rate (Rosenthal 2D): R = 2πk*ρc/h²*(T-T₀)³/(HI)²
    k = 0.025; rhoc = 5e-3;  % steel
    R = 2*pi*k*rhoc/t^2 * (T - T0)^3 / (HI/1000)^2 * 1e3;  % °C/s
    % t8/5 cooling time (800→500°C)
    t85 = (4300 - 4.3*T0) / (HI/1000) * 1e5 / 1e6;  % seconds
    % Critical cooling rate for martensite
    R_crit = 30;  % °C/s for typical steel
    martensite = R > R_crit;
    out = struct();
    out.action = 'cooling';
    out.heatInput_J_per_mm = HI;
    out.thickness_mm = t; out.preheat_C = T0;
    out.coolingRate_C_per_s = R;
    out.t85_coolingTime_s = t85;
    out.martensiteFormation = martensite;
end

function out = act_ceq(opts)
    % IIW Carbon Equivalent: CE = C + Mn/6 + (Cr+Mo+V)/5 + (Ni+Cu)/15
    CE = opts.C + opts.Mn/6 + (opts.Cr + opts.Mo + opts.V)/5 + (opts.Ni + opts.Cu)/15;
    if CE < 0.35, weldability = 'excellent (no preheat needed)';
    elseif CE < 0.45, weldability = 'good (low preheat recommended)';
    elseif CE < 0.55, weldability = 'fair (preheat ~150-250°C)';
    else, weldability = 'poor (high preheat + PWHT required)'; end
    out = struct();
    out.action = 'ceq';
    out.formula = 'IIW: CE = C + Mn/6 + (Cr+Mo+V)/5 + (Ni+Cu)/15';
    out.composition = struct('C',opts.C,'Mn',opts.Mn,'Cr',opts.Cr,'Mo',opts.Mo,'V',opts.V,'Ni',opts.Ni,'Cu',opts.Cu);
    out.CE = CE;
    out.weldability = weldability;
end

function out = act_preheat(opts)
    CE = opts.Ceq;
    if CE <= 0, CE = opts.C + opts.Mn/6 + (opts.Cr+opts.Mo+opts.V)/5 + (opts.Ni+opts.Cu)/15; end
    t = opts.thickness;
    % EN 1011-2 preheat temperature estimation
    Tp = 697 * CE + 160 * tanh(t/35) + 62 * opts.C^0.35 - 320;
    % Hydrogen scaling
    switch opts.hydrogen
        case 'low', hdScale = 0;
        case 'medium', hdScale = 50;
        case 'high', hdScale = 120;
        otherwise, hdScale = 0;
    end
    Tp = max(0, Tp + hdScale);
    Tp = min(400, Tp);  % cap at 400°C
    % Interpass recommendation
    T_interpass = min(250, Tp + 50);
    out = struct();
    out.action = 'preheat';
    out.method = 'EN 1011-2';
    out.CE = CE; out.thickness_mm = t; out.hydrogenLevel = opts.hydrogen;
    out.preheatTemp_C = Tp;
    out.interpassMax_C = T_interpass;
end

function out = act_distortion(opts)
    L = opts.length; W = opts.width;
    HI = opts.heatInput;
    if HI <= 0, HI = opts.voltage * opts.current * opts.efficiency / opts.speed; end
    % Angular distortion estimate (simplified)
    alpha = 12e-6;  % CTE for steel
    theta = 0.02 * alpha * HI / (W^2) * 1000;  % degrees
    % Longitudinal shrinkage
    shrinkage = 0.1 * L * alpha * HI / (W * 100) * 1000;  % mm
    out = struct();
    out.action = 'distortion';
    out.length_mm = L; out.width_mm = W;
    out.heatInput_J_per_mm = HI;
    out.angularDistortion_deg = theta;
    out.longitudinalShrinkage_mm = shrinkage;
end

function out = act_strength(opts)
    t = opts.thickness;
    filler = opts.filler;
    % Electrode tensile strength lookup
    fillerMap = struct('E60', 420, 'E70', 490, 'E80', 550, 'E90', 620, ...
                       'E100', 690, 'E110', 760, 'E120', 830);
    if isfield(fillerMap, filler), fu = fillerMap.(filler); else, fu = 490; end
    % Fillet weld strength (throat = 0.707*leg), assume leg = thickness/2
    throat = 0.707 * t / 2;
    Pw_per_mm = fu * throat / sqrt(3);  % N/mm per mm length
    out = struct();
    out.action = 'strength';
    out.fillerMetal = filler; out.fillerStrength_MPa = fu;
    out.weldThroat_mm = throat;
    out.weldStrength_N_per_mm = Pw_per_mm;
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
