function cli_power(action, varargin)
% CLI_POWER Power system analysis for ml CLI
%   CLI: ml power loadflow --buses 5 --line "[from to R X]" --load "[P Q]" --gen "[P V]"
%         ml power fault    --voltage 1.0 --impedance 0.1 --time 0.1
%         ml power line     --length 100 --R 0.1 --X 0.3 --V 220 --S "[10 5]"
%         ml power transformer --v1 220 --v2 22 --s_rated 100 --z_pct 5
%         ml power economic --cost "[10 20 30]" --pmin "[0 0 0]" --pmax "[50 80 100]" --demand 150
%
%   Options:
%     --buses N        bus count
%     --line MAT       line data [from to R X]
%     --load MAT       load per bus [P Q] (MW, MVAr)
%     --gen MAT        generator data [P V]
%     --voltage pu     base voltage (pu, default 1.0)
%     --impedance pu   fault impedance (pu)
%     --time s         fault duration
%     --length km      line length
%     --R ohm/km       resistance per km
%     --X ohm/km       reactance per km
%     --V kV           voltage level
%     --S MAT          power flow [P Q] (MW, MVAr)
%     --v1 kV          primary voltage
%     --v2 kV          secondary voltage
%     --s_rated MVA    rated apparent power
%     --z_pct VAL      impedance percent
%     --cost MAT       cost coefficients per generator
%     --pmin MAT       minimum generation per unit
%     --pmax MAT       maximum generation per unit
%     --demand MW      total load demand
%     --format json|table|csv

    if nargin < 1, error('ml power <action> [options]'); end

    opts = struct('format','json','buses',3,'line','','load','', ...
                  'gen','','voltage',1.0,'impedance',0.1,'time',0.1, ...
                  'length',100,'R',0.1,'X',0.3,'V',220,'S','', ...
                  'v1',220,'v2',22,'s_rated',100,'z_pct',5, ...
                  'cost','','pmin','','pmax','','demand',150);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--buses',     opts.buses = round(parse_num(varargin{i+1})); i=i+2;
            case '--line',      opts.line = varargin{i+1}; i=i+2;
            case '--load',      opts.load = varargin{i+1}; i=i+2;
            case '--gen',       opts.gen = varargin{i+1}; i=i+2;
            case '--voltage',   opts.voltage = parse_num(varargin{i+1}); i=i+2;
            case '--impedance', opts.impedance = parse_num(varargin{i+1}); i=i+2;
            case '--time',      opts.time = parse_num(varargin{i+1}); i=i+2;
            case '--length',    opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--R',         opts.R = parse_num(varargin{i+1}); i=i+2;
            case '--X',         opts.X = parse_num(varargin{i+1}); i=i+2;
            case '--V',         opts.V = parse_num(varargin{i+1}); i=i+2;
            case '--S',         opts.S = varargin{i+1}; i=i+2;
            case '--v1',        opts.v1 = parse_num(varargin{i+1}); i=i+2;
            case '--v2',        opts.v2 = parse_num(varargin{i+1}); i=i+2;
            case '--s_rated',   opts.s_rated = parse_num(varargin{i+1}); i=i+2;
            case '--z_pct',     opts.z_pct = parse_num(varargin{i+1}); i=i+2;
            case '--cost',      opts.cost = varargin{i+1}; i=i+2;
            case '--pmin',      opts.pmin = varargin{i+1}; i=i+2;
            case '--pmax',      opts.pmax = varargin{i+1}; i=i+2;
            case '--demand',    opts.demand = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'loadflow',   out = act_loadflow(opts);
            case 'fault',      out = act_fault(opts);
            case 'line',       out = act_line(opts);
            case 'transformer',out = act_transformer(opts);
            case 'economic',   out = act_economic(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Helpers for parsing matrices ===================
function M = parse_mat(s)
    if ischar(s) || isstring(s)
        if isempty(s), M = []; return; end
        M = eval(s);
    else
        M = s;
    end
end

% =================== Actions ===================
function out = act_loadflow(opts)
    % Simple DC load flow (linear approximation)
    % P = B * theta
    nBuses = opts.buses;
    if isempty(opts.line), error('--line required: [from to R X]'); end
    lineData = parse_mat(opts.line);
    nLines = size(lineData, 1);
    % Build susceptance matrix B
    B = zeros(nBuses, nBuses);
    for k = 1:nLines
        f = round(lineData(k, 1));
        t = round(lineData(k, 2));
        X = lineData(k, 4);
        if X == 0, X = 1e-6; end
        b = 1 / X;
        B(f, f) = B(f, f) + b;
        B(t, t) = B(t, t) + b;
        B(f, t) = B(f, t) - b;
        B(t, f) = B(t, f) - b;
    end
    % Power injections (P only for DC)
    P = zeros(nBuses, 1);
    if ~isempty(opts.load)
        loadData = parse_mat(opts.load);
        P = P - loadData(:, 1);   % loads consume P
    end
    if ~isempty(opts.gen)
        genData = parse_mat(opts.gen);
        % Slack bus = bus 1
        for g = 2:nBuses
            if g <= size(genData,1)
                P(g) = P(g) + genData(g, 1);
            end
        end
    end
    % Slack bus removal (bus 1)
    B_red = B(2:end, 2:end);
    P_red = P(2:end);
    % Solve for theta
    theta_red = B_red \ P_red;
    theta = [0; theta_red];   % bus 1 = reference
    % Slack bus power
    P_slack = sum(B(1,:) .* theta);
    % Line flows
    flows = zeros(nLines, 1);
    for k = 1:nLines
        f = round(lineData(k, 1));
        t = round(lineData(k, 2));
        X = lineData(k, 4);
        flows(k) = (theta(f) - theta(t)) / X;
    end
    out = struct();
    out.numBuses = nBuses;
    out.numLines = nLines;
    out.busAngles_rad = theta(:)';
    out.lineFlows_MW = flows(:)';
    out.slackGeneration_MW = P_slack;
    out.totalLoad_MW = -sum(P(P<0));
end

function n = nLinks_safe(n, ~)
    n = n;
end

function out = act_fault(opts)
    % Symmetrical three-phase fault analysis
    V_pre = opts.voltage;
    Z_f = opts.impedance;
    % Fault current = V_pre / (Z_source + Z_f), assume Z_source = j0.1
    Z_source = 1i * 0.1;
    I_fault_pu = V_pre / (Z_source + Z_f);
    % If base MVA = 100 and base V = 1 pu
    baseMVA = 100;
    I_fault_A = abs(I_fault_pu) * baseMVA / (1 * sqrt(3));   % at 1pu voltage, base current
    % DC offset decay
    t = linspace(0, opts.time, 100);
    X_over_R = 10;   % assumption
    dc_offset = exp(-2*pi*freq_over_R(X_over_R) .* t);
    I_asym = abs(I_fault_pu) * (1 + dc_offset);
    out = struct();
    out.preFaultVoltage_pu = V_pre;
    out.faultImpedance_pu = Z_f;
    out.symmetricalFaultCurrent_pu = abs(I_fault_pu);
    out.symmetricalFaultCurrent_A = abs(I_fault_A);
    out.baseMVA = baseMVA;
    out.XoverR = X_over_R;
    out.time = t';
    out.asymmetricalCurrent_pu = I_asym';
    out.peakAsymmetricalCurrent_pu = max(I_asym);
end

function f = freq_over_R(x_over_r)
    % approximate: 1/T = (omega * R) / X = (2pi*60) / (X/R)
    f = 2*pi*60 / x_over_r;
end

function out = act_line(opts)
    % Short/medium line model (nominal π)
    R = opts.R * opts.length;
    X = opts.X * opts.length;
    Z = R + 1i * X;
    V_base = opts.V * 1e3;   % V_phase (line-line to phase neutral × √3)
    if isempty(opts.S), error('--S required: [P Q]'); end
    S = parse_mat(opts.S);
    P = S(1) * 1e6;
    Q = S(2) * 1e6;
    S_complex = P + 1i * Q;
    % Receiving end phase voltage (line-line)
    V_R = opts.V * 1e3 / sqrt(3);
    I_R = conj(S_complex / (V_R * sqrt(3)));
    % Sending end voltage
    V_S = V_R + Z * I_R;
    % Regulation
    regulation = (abs(V_S) - abs(V_R)) / abs(V_R) * 100;
    % Losses
    loss = abs(I_R)^2 * R;
    % Efficiency
    P_out = real(V_R * conj(I_R));
    P_in = P_out + loss;
    efficiency = P_out / P_in * 100;
    out = struct();
    out.length_km = opts.length;
    out.resistance_ohm = R;
    out.reactance_ohm = X;
    out.lineVoltage_kV = opts.V;
    out.loadP_MW = S(1);
    out.loadQ_MVAr = S(2);
    out.receivingEndVoltage_kV = abs(V_R) * sqrt(3) / 1e3;
    out.sendingEndVoltage_kV = abs(V_S) * sqrt(3) / 1e3;
    out.regulation_pct = regulation;
    out.lineLosses_MW = loss / 1e6;
    out.efficiency_pct = efficiency;
end

function out = act_transformer(opts)
    % Transformer equivalent circuit
    v1 = opts.v1;
    v2 = opts.v2;
    S_rated = opts.s_rated;
    z_pct = opts.z_pct;
    % Per-unit impedance (assume X/R = 8)
    Z_pu = z_pct / 100;
    xr = 8;
    R_pu = Z_pu / sqrt(1 + xr^2);
    X_pu = R_pu * xr;
    % Base impedance
    Z_base = v1^2 / S_rated;
    R_ohm = R_pu * Z_base;
    X_ohm = X_pu * Z_base;
    % Turns ratio
    a = v1 / v2;
    % Full load current
    I_full = S_rated * 1e6 / (v1 * 1e3) / sqrt(3);
    % Copper loss at full load
    P_cu = 3 * I_full^2 * R_ohm;
    out = struct();
    out.v1_kV = v1;
    out.v2_kV = v2;
    out.ratedMVA = S_rated;
    out.impedance_pct = z_pct;
    out.turnsRatio = a;
    out.R_pu = R_pu;
    out.X_pu = X_pu;
    out.R_ohm_primary = R_ohm;
    out.X_ohm_primary = X_ohm;
    out.fullLoadCurrent_A = I_full;
    out.fullLoadCopperLoss_kW = P_cu / 1e3;
end

function out = act_economic(opts)
    % Economic dispatch (ignoring losses, equal incremental cost)
    if isempty(opts.cost), error('--cost required: cost coefficients per generator'); end
    cost = parse_mat(opts.cost);
    pmin = parse_mat(opts.pmin);
    pmax = parse_mat(opts.pmax);
    demand = opts.demand;
    nGen = numel(cost);
    % Quadratic cost: C_i(P_i) = a_i * P_i^2  (simple model)
    % dC/dP = 2*a_i*P_i = lambda (lambda = common incremental cost)
    % P_i = lambda / (2*a_i)
    % sum P_i = demand
    a = cost;
    % Unconstrained solution
    inv_sum = sum(1 ./ (2*a));
    lambda = demand / inv_sum;
    P = lambda ./ (2*a);
    % Apply limits (simple projection)
    for k = 1:nGen
        if P(k) < pmin(k), P(k) = pmin(k); end
        if P(k) > pmax(k), P(k) = pmax(k); end
    end
    % Re-dispatch if total != demand (simple greedy)
    diff = demand - sum(P);
    if abs(diff) > 0.01
        % Find generators not at limit
        for k = 1:nGen
            if diff > 0 && P(k) < pmax(k)
                add = min(diff, pmax(k) - P(k));
                P(k) = P(k) + add;
                diff = diff - add;
            elseif diff < 0 && P(k) > pmin(k)
                sub = min(-diff, P(k) - pmin(k));
                P(k) = P(k) - sub;
                diff = diff + sub;
            end
            if abs(diff) < 0.01, break; end
        end
    end
    % Total cost
    totalCost = sum(a .* P.^2);
    out = struct();
    out.numGenerators = nGen;
    out.demand_MW = demand;
    out.dispatch_MW = P(:)';
    out.lambda_incrementalCost = lambda;
    out.totalCost = totalCost;
    out.costCoefficients = a(:)';
    out.pmin = pmin(:)';
    out.pmax = pmax(:)';
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
