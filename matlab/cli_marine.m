function cli_marine(action, varargin)
% CLI_MARINE Naval architecture for ml CLI
%   CLI: ml marine buoyancy   --L 50 --B 10 --T 3 --Cb 0.7
%         ml marine stability  --KB 1.5 --KG 4 --BM 2.5
%         ml marine resistance --L 100 --B 15 --T 5 --v 7 --Cb 0.65
%         ml marine propeller  --D 3 --n 2 --v_a 5 --w 0.2
%         ml marine trim       --L 80 --LCG 35 --LCB 38 --displacement 5000
%         ml marine heeling    --GM 0.8 --displacement 3000 --heelingMoment 5000
%
%   Options:
%     --L/B/T M         length/beam/draught
%     --Cb FLOAT        block coefficient
%     --KB/KG/BM M      vertical center of buoyancy/gravity/metacenter
%     --v M/S           ship speed (kn also accepted if small)
%     --D M             propeller diameter
%     --n RPS           propeller revolutions per second
%     --v_a M/S         advance velocity
%     --w FLOAT         wake fraction
%     --LCG/LCB M       LCG, LCB positions
%     --displacement T   displacement
%     --GM M             metacentric height
%     --heelingMoment T·M heeling moment

    if nargin < 1, error('ml marine <action> [options]'); end

    opts = struct('format','json','L',50,'B',10,'T',3,'Cb',0.7, ...
                  'KB',1.5,'KG',4,'BM',2.5, ...
                  'v',7,'D_prop',3,'n_rps',2,'v_a',5,'w',0.2, ...
                  'LCG',35,'LCB',38,'displacement',5000, ...
                  'GM',0.8,'heelingMoment',5000);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--L',      opts.L = parse_num(varargin{i+1}); i=i+2;
            case '--B',      opts.B = parse_num(varargin{i+1}); i=i+2;
            case '--T',      opts.T = parse_num(varargin{i+1}); i=i+2;
            case '--Cb',     opts.Cb = parse_num(varargin{i+1}); i=i+2;
            case '--KB',     opts.KB = parse_num(varargin{i+1}); i=i+2;
            case '--KG',     opts.KG = parse_num(varargin{i+1}); i=i+2;
            case '--BM',     opts.BM = parse_num(varargin{i+1}); i=i+2;
            case '--v',      opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--D',      opts.D_prop = parse_num(varargin{i+1}); i=i+2;
            case '--n',      opts.n_rps = parse_num(varargin{i+1}); i=i+2;
            case '--v_a',    opts.v_a = parse_num(varargin{i+1}); i=i+2;
            case '--w',      opts.w = parse_num(varargin{i+1}); i=i+2;
            case '--LCG',    opts.LCG = parse_num(varargin{i+1}); i=i+2;
            case '--LCB',    opts.LCB = parse_num(varargin{i+1}); i=i+2;
            case '--displacement',opts.displacement = parse_num(varargin{i+1}); i=i+2;
            case '--GM',     opts.GM = parse_num(varargin{i+1}); i=i+2;
            case '--heelingMoment',opts.heelingMoment = parse_num(varargin{i+1}); i=i+2;
            case '--format', opts.format = varargin{i+1}; i=i+2;
            otherwise,       i=i+1;
        end
    end

    try
        switch lower(action)
            case 'buoyancy',  out = act_buoyancy(opts);
            case 'stability', out = act_stability(opts);
            case 'resistance',out = act_resistance(opts);
            case 'propeller', out = act_propeller(opts);
            case 'trim',      out = act_trim(opts);
            case 'heeling',   out = act_heeling(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_buoyancy(opts)
    L = opts.L; B = opts.B; T = opts.T; Cb = opts.Cb;
    rho = 1025;  % seawater kg/m³
    V = L * B * T * Cb;  % displaced volume
    displacement = V * rho / 1000;  % tonnes
    out = struct();
    out.action = 'buoyancy';
    out.dimensions = struct('L',L,'B',B,'T',T);
    out.blockCoefficient = Cb;
    out.volume_m3 = V;
    out.displacement_tonnes = displacement;
end

function out = act_stability(opts)
    KB = opts.KB; KG = opts.KG; BM = opts.BM;
    GM = KB + BM - KG;
    stable = GM > 0.15;  % minimum GM for safety
    if GM < 0, status = 'unstable (negative GM)';
    elseif GM < 0.15, status = 'tender (low stability)';
    elseif GM < 1.0, status = 'satisfactory';
    else, status = 'stiff (high stability)'; end
    out = struct();
    out.action = 'stability';
    out.KB_m = KB; out.KG_m = KG; out.BM_m = BM;
    out.GM_m = GM;
    out.stable = stable;
    out.status = status;
end

function out = act_resistance(opts)
    L = opts.L; B = opts.B; T = opts.T;
    v = opts.v; Cb = opts.Cb;
    rho = 1025; g = 9.81; nu = 1.19e-6;
    % Holtrop-Mennen simplified
    V_displaced = L * B * T * Cb;
    S_wet = L * (2*T + B) * sqrt(Cb);  % wetted surface approx
    Re = v * L / nu;
    % ITTC-57 friction: Cf = 0.075/(log10(Re)-2)^2
    Cf = 0.075 / (log10(Re) - 2)^2;
    R_f = 0.5 * rho * S_wet * v^2 * Cf;  % N
    % Residual resistance (rough estimate)
    Fn = v / sqrt(g * L);
    C_res = 0.001 * (1 + 100*Fn^2);
    R_res = 0.5 * rho * S_wet * v^2 * C_res;
    R_total = R_f + R_res;
    P_effective = R_total * v / 1000;  % kW
    out = struct();
    out.action = 'resistance';
    out.speed_m_per_s = v; out.froudeNumber = Fn;
    out.Re = Re; out.frictionCoeff = Cf;
    out.frictionResistance_kN = R_f/1000;
    out.residualResistance_kN = R_res/1000;
    out.totalResistance_kN = R_total/1000;
    out.effectivePower_kW = P_effective;
end

function out = act_propeller(opts)
    D = opts.D_prop; n = opts.n_rps; v_a = opts.v_a; w = opts.w;
    % Advance coefficient: J = v_a/(n*D)
    J = v_a / (n * D);
    % Thrust from Wageningen B-series approximation
    % K_T ≈ 0.45 - 0.3*J (simplified)
    KT = max(0, 0.45 - 0.3 * J);
    KQ = 0.05 - 0.03 * J;
    rho = 1025;
    T = KT * rho * n^2 * D^4 / 1000;  % kN
    Q = KQ * rho * n^2 * D^5 / 1000;  % kN·m
    P_prop = 2 * pi * n * Q * 1000 / 1000;  % kW
    eta_o = J * KT / (2 * pi * KQ);  % open water efficiency
    out = struct();
    out.action = 'propeller';
    out.diameter_m = D; out.rps = n; out.advanceSpeed = v_a;
    out.advanceCoefficient = J;
    out.thrustCoeff = KT; out.torqueCoeff = KQ;
    out.thrust_kN = T; out.torque_kNm = Q;
    out.propellerPower_kW = P_prop;
    out.openWaterEfficiency = eta_o;
end

function out = act_trim(opts)
    L = opts.L; LCG = opts.LCG; LCB = opts.LCB;
    disp = opts.displacement;
    % Trim angle: tanθ = (LCG - LCB) * disp / (MCT)
    MCT = disp * L / 100;  % moment to change trim 1cm (approximate)
    trimMoment = (LCG - LCB) * disp * 9.81;
    trim_cm = trimMoment / MCT / 1000;
    trim_deg = atand(trim_cm / (L * 100));
    out = struct();
    out.action = 'trim';
    out.LCB_m = LCB; out.LCG_m = LCG;
    out.trimMoment_kNm = trimMoment / 1000;
    out.MCT_tonne_m_per_cm = MCT;
    out.trim_cm = trim_cm;
    out.trim_deg = trim_deg;
    out.trimType = ternary_str(LCG > LCB, 'bow down', 'stern down');
end

function out = act_heeling(opts)
    GM = opts.GM; disp = opts.displacement;
    HM = opts.heelingMoment;
    % Heeling angle: tanθ = HM / (Δ * GM * g)
    tan_theta = HM * 1000 / (disp * GM * 9.81);
    theta = atand(min(tan_theta, 1.5));  % cap at ~56°
    out = struct();
    out.action = 'heeling';
    out.heelingMoment_kNm = HM;
    out.displacement_tonnes = disp;
    out.GM_m = GM;
    out.heelingAngle_deg = theta;
end

function s = ternary_str(cond, a, b)
    if cond, s = a; else, s = b; end
end
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end
function print_output(out, fmt)
    switch lower(fmt), case 'json', jsonify(out); case 'table', to_table(out); case 'csv', to_csv(out); otherwise, jsonify(out); end
end
