function cli_hydrology(action, varargin)
% CLI_HYDROLOGY Water resources engineering for ml CLI
%   CLI: ml hydrology rational   --C 0.6 --I 50 --A 10
%         ml hydrology scs        --CN 80 --P 100 --AMC II
%         ml hydrology hydrograph --A 100 --tc 2 --P 50
%         ml hydrology manning    --n 0.015 --R 1.2 --S 0.001
%         ml hydrology infiltration --K 10 --F0 20 --Fc 5 --t 60
%         ml hydrology weir       --H 0.5 --L 3 --Cd 0.62
%
%   Options:
%     --C FLOAT         runoff coefficient
%     --I MM/HR         rainfall intensity
%     --A HA|KM2        catchment area
%     --CN N            SCS curve number
%     --P MM            total precipitation
%     --AMC I|II|III     antecedent moisture condition
%     --tc HR            time of concentration
%     --n FLOAT          Manning's roughness coefficient
%     --R M              hydraulic radius
%     --S M/M            channel slope
%     --K MM/HR          hydraulic conductivity
%     --F0/--Fc MM/HR   initial/final infiltration rate
%     --t MIN            time
%     --H M              head over weir
%     --L M              weir length
%     --Cd FLOAT         discharge coefficient

    if nargin < 1, error('ml hydrology <action> [options]'); end

    opts = struct('format','json','C',0.6,'I',50,'A',10, ...
                  'CN',80,'P',100,'AMC','II','tc',2, ...
                  'n',0.015,'R_val',1.2,'S_slope',0.001, ...
                  'K',10,'F0',20,'Fc',5,'t',60, ...
                  'H',0.5,'L_len',3,'Cd',0.62);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--C',     opts.C = parse_num(varargin{i+1}); i=i+2;
            case '--I',     opts.I = parse_num(varargin{i+1}); i=i+2;
            case '--A',     opts.A = parse_num(varargin{i+1}); i=i+2;
            case '--CN',    opts.CN = parse_num(varargin{i+1}); i=i+2;
            case '--P',     opts.P = parse_num(varargin{i+1}); i=i+2;
            case '--AMC',   opts.AMC = upper(varargin{i+1}); i=i+2;
            case '--tc',    opts.tc = parse_num(varargin{i+1}); i=i+2;
            case '--n',     opts.n = parse_num(varargin{i+1}); i=i+2;
            case '--R',     opts.R_val = parse_num(varargin{i+1}); i=i+2;
            case '--S',     opts.S_slope = parse_num(varargin{i+1}); i=i+2;
            case '--K',     opts.K = parse_num(varargin{i+1}); i=i+2;
            case '--F0',    opts.F0 = parse_num(varargin{i+1}); i=i+2;
            case '--Fc',    opts.Fc = parse_num(varargin{i+1}); i=i+2;
            case '--t',     opts.t = parse_num(varargin{i+1}); i=i+2;
            case '--H',     opts.H = parse_num(varargin{i+1}); i=i+2;
            case '--L',     opts.L_len = parse_num(varargin{i+1}); i=i+2;
            case '--Cd',    opts.Cd = parse_num(varargin{i+1}); i=i+2;
            case '--format',opts.format = varargin{i+1}; i=i+2;
            otherwise,      i=i+1;
        end
    end

    try
        switch lower(action)
            case 'rational',    out = act_rational(opts);
            case 'scs',         out = act_scs(opts);
            case 'hydrograph',  out = act_hydrograph(opts);
            case 'manning',     out = act_manning(opts);
            case 'infiltration',out = act_infiltration(opts);
            case 'weir',        out = act_weir(opts);
            otherwise,          error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_rational(opts)
    C = opts.C; I = opts.I; A = opts.A;
    Q = C * I * A / 360;  % m³/s
    out = struct();
    out.action = 'rational';
    out.method = 'Q = CIA / 360';
    out.runoffCoefficient = C;
    out.rainfallIntensity_mm_per_hr = I;
    out.catchmentArea_ha = A;
    out.peakDischarge_m3_per_s = Q;
end

function out = act_scs(opts)
    CN = opts.CN; P = opts.P;
    % SCS Curve Number method: S = 25.4*(1000/CN - 10), Q = (P-0.2S)^2/(P+0.8S)
    S_val = 25.4 * (1000/CN - 10);  % mm
    if P <= 0.2*S_val
        Q = 0;
    else
        Q = (P - 0.2*S_val)^2 / (P + 0.8*S_val);
    end
    % AMC adjustment
    switch opts.AMC
        case 'I',   CN_adj = CN / (2.334 - 0.01334*CN);
        case 'III', CN_adj = CN / (0.4036 + 0.0059*CN);
        otherwise,  CN_adj = CN;
    end
    out = struct();
    out.action = 'scs';
    out.method = 'SCS Curve Number';
    out.CN = CN; out.precipitation_mm = P;
    out.storage_mm = S_val;
    out.runoff_mm = Q;
    out.runoffRatio = Q / max(P, 0.1);
    out.AMC = opts.AMC;
end

function out = act_hydrograph(opts)
    A = opts.A; tc = opts.tc; P = opts.P;
    % SCS unit hydrograph: tp = 0.6*tc, qp = 0.208*A/tp
    tp = 0.6 * tc;  % hours
    qp = 0.208 * A / tp;  % m³/s per mm of runoff
    % Time base: Tb = 2.67*tp
    Tb = 2.67 * tp;
    % Sample hydrograph ordinates
    npts = 10;
    t_hydro = linspace(0, Tb, npts);
    q_hydro = zeros(1, npts);
    for i = 1:npts
        t_val = t_hydro(i);
        if t_val <= tp
            q_hydro(i) = qp * (t_val/tp);
        else
            q_hydro(i) = qp * exp(-(t_val - tp) / (tp*0.5));
        end
    end
    out = struct();
    out.action = 'hydrograph';
    out.catchmentArea_km2 = A;
    out.timeOfConc_hr = tc;
    out.peakTime_hr = tp; out.timeBase_hr = Tb;
    out.peakFlow_per_mm = qp;
    out.hydrograph = struct('t_hr', t_hydro, 'q_m3_per_s', q_hydro);
end

function out = act_manning(opts)
    n = opts.n; R = opts.R_val; S = opts.S_slope;
    % Manning's equation: V = (1/n)*R^(2/3)*S^(1/2), Q = V*A
    V = (1/n) * R^(2/3) * S^(1/2);  % m/s
    out = struct();
    out.action = 'manning';
    out.roughness_n = n; out.hydraulicRadius_m = R; out.slope = S;
    out.velocity_m_per_s = V;
end

function out = act_infiltration(opts)
    K = opts.K; F0 = opts.F0; Fc = opts.Fc; t = opts.t;
    % Horton's equation: f(t) = Fc + (F0 - Fc)*exp(-K*t)
    t_hr = t / 60;
    f_t = Fc + (F0 - Fc) * exp(-K * t_hr);
    % Cumulative infiltration
    F_cum = Fc * t_hr + (F0 - Fc)/K * (1 - exp(-K*t_hr));
    out = struct();
    out.action = 'infiltration';
    out.method = 'Horton';
    out.K_per_hr = K; out.f0_mm_hr = F0; out.fc_mm_hr = Fc;
    out.time_min = t;
    out.infiltrationRate = f_t;
    out.cumulativeInfiltration_mm = F_cum;
end

function out = act_weir(opts)
    H = opts.H; L = opts.L_len; Cd = opts.Cd;
    % Sharp-crested weir: Q = Cd * 2/3 * sqrt(2*g) * L * H^(3/2)
    g = 9.81;
    Q = Cd * (2/3) * sqrt(2*g) * L * H^(3/2);
    out = struct();
    out.action = 'weir';
    out.head_m = H; out.length_m = L; out.Cd = Cd;
    out.discharge_m3_per_s = Q;
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
