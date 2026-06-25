function cli_traffic(action, varargin)
% CLI_TRAFFIC Traffic engineering for ml CLI
%   CLI: ml traffic flow     --q 1500 --v 80 --k 20
%         ml traffic signal  --cycle 90 --flows "[400,300,200]" --sat 1800
%         ml traffic los      --v 80 --vFree 100 --type freeway
%         ml traffic greenshields --vFree 100 --kJam 120 --k 30
%         ml traffic capacity --lanes 3 --vFree 100 --type basic
%         ml traffic queue    --arrival 800 --departure 1000 --t 15
%
%   Options:
%     --q VEH/H         flow rate
%     --v KM/H          speed
%     --k VEH/KM        density
%     --cycle S          cycle length
%     --flows VEC        approach flows
%     --sat VEH/H        saturation flow
%     --vFree KM/H      free-flow speed
%     --type NAME        freeway|multilane|arterial|urban
%     --kJam VEH/KM     jam density
%     --lanes N          number of lanes
%     --arrival VEH/H   arrival rate
%     --departure VEH/H  departure rate

    if nargin < 1, error('ml traffic <action> [options]'); end

    opts = struct('format','json','q',1500,'v',80,'k',20, ...
                  'cycle',90,'flows','','sat',1800, ...
                  'vFree',100,'type','freeway', ...
                  'kJam',120,'lanes',3, ...
                  'arrival',800,'departure',1000,'t',15);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--q',        opts.q = parse_num(varargin{i+1}); i=i+2;
            case '--v',        opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--k',        opts.k = parse_num(varargin{i+1}); i=i+2;
            case '--cycle',    opts.cycle = parse_num(varargin{i+1}); i=i+2;
            case '--flows',    opts.flows = varargin{i+1}; i=i+2;
            case '--sat',      opts.sat = parse_num(varargin{i+1}); i=i+2;
            case '--vFree',    opts.vFree = parse_num(varargin{i+1}); i=i+2;
            case '--type',     opts.type = lower(varargin{i+1}); i=i+2;
            case '--kJam',     opts.kJam = parse_num(varargin{i+1}); i=i+2;
            case '--lanes',    opts.lanes = parse_num(varargin{i+1}); i=i+2;
            case '--arrival',  opts.arrival = parse_num(varargin{i+1}); i=i+2;
            case '--departure',opts.departure = parse_num(varargin{i+1}); i=i+2;
            case '--t',        opts.t = parse_num(varargin{i+1}); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'flow',        out = act_flow(opts);
            case 'signal',      out = act_signal(opts);
            case 'los',         out = act_los(opts);
            case 'greenshields',out = act_greenshields(opts);
            case 'capacity',    out = act_capacity(opts);
            case 'queue',       out = act_queue(opts);
            otherwise,          error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_flow(opts)
    q = opts.q; v = opts.v; k = opts.k;
    % Fundamental relationship: q = k * v
    q_calc = k * v;
    v_calc = 0;
    k_calc = 0;
    if v > 0, k_calc = q / v; end
    if k > 0, v_calc = q / k; end
    % Density at capacity (approximate)
    k_cap = 30;  % veh/km typical
    headway = 3600 / max(q, 1);  % s between vehicles
    gap = v / 3.6 * headway - 5;  % m (5m vehicle length)
    out = struct();
    out.action = 'flow';
    out.formula = 'q = k * v (veh/hr = veh/km × km/hr)';
    out.flow_veh_per_hr = q;
    out.speed_kmh = v;
    out.density_veh_per_km = k;
    out.computedDensity = k_calc;
    out.computedSpeed = v_calc;
    out.headway_s = headway;
    out.gap_m = gap;
end

function out = act_signal(opts)
    cycle = opts.cycle;
    flows = parse_vec(opts.flows);
    sat = opts.sat;
    % Webster's method for optimum cycle time:
    % C_opt = (1.5*L + 5) / (1 - Y)
    L_per_stage = 4;  % lost time per stage
    n_stages = max(1, numel(flows));
    L = n_stages * L_per_stage;
    y = flows / sat;  % flow ratios
    Y = sum(y);
    C_opt = round((1.5*L + 5) / max(1 - Y, 0.05));
    C_opt = max(30, min(120, C_opt));
    % Green split: gi = (C - L) * yi / Y
    greenTimes = (C_opt - L) * y / max(Y, 0.01);
    out = struct();
    out.action = 'signal';
    out.method = 'Websters method';
    out.cycle_s = cycle; out.optimumCycle_s = C_opt;
    out.flowRatios = y; out.Y = Y;
    out.greenTimes_s = greenTimes;
    out.lostTime_s = L;
end

function out = act_los(opts)
    v = opts.v; vf = opts.vFree; type = opts.type;
    v_ratio = v / vf;
    % Density = q / v (estimate from speed)
    k_est = 1500 / max(v, 1);  % assume flow at capacity-ish
    % LOS thresholds (HCM 2016, density in pc/km/ln)
    thresholds = struct('freeway', [7, 11, 16, 22, 28], ...
                        'multilane', [7, 11, 16, 22, 28], ...
                        'arterial', [15, 25, 35, 45, 55]);
    if isfield(thresholds, type), th = thresholds.(type); else, th = [7, 11, 16, 22, 28]; end
    losLetters = {'A', 'B', 'C', 'D', 'E', 'F'};
    losIdx = find(k_est <= th, 1);
    if isempty(losIdx), losIdx = 6; end
    out = struct();
    out.action = 'los';
    out.speed_kmh = v; out.freeFlowSpeed = vf;
    out.v_ratio = v_ratio;
    out.estimatedDensity = k_est;
    out.LOS = losLetters{losIdx};
    out.roadType = type;
end

function out = act_greenshields(opts)
    vf = opts.vFree; kj = opts.kJam; k = opts.k;
    % Greenshields: v = vf * (1 - k/kj), q = v * k
    v = vf * (1 - k / kj);
    q = v * k;
    % Capacity: at k = kj/2, qmax = vf*kj/4
    k_opt = kj / 2;
    q_max = vf * kj / 4;
    v_opt = vf / 2;
    out = struct();
    out.action = 'greenshields';
    out.model = 'v = vf*(1 - k/kj)';
    out.vFree = vf; out.kJam = kj;
    out.density = k;
    out.speed = v;
    out.flow = q;
    out.capacity = q_max;
    out.optimumDensity = k_opt;
    out.optimumSpeed = v_opt;
    out.state = ternary_str(k < k_opt, 'uncongested', 'congested');
end

function out = act_capacity(opts)
    lanes = opts.lanes; vf = opts.vFree; type = opts.type;
    % Base capacity per lane (HCM)
    capMap = struct('freeway', 2400, 'multilane', 2200, ...
                    'arterial', 1900, 'urban', 1600);
    if isfield(capMap, type), cap_per = capMap.(type); else, cap_per = 2000; end
    C = lanes * cap_per;
    out = struct();
    out.action = 'capacity';
    out.lanes = lanes; out.roadType = type;
    out.capacityPerLane_veh_per_hr = cap_per;
    out.totalCapacity_veh_per_hr = C;
end

function out = act_queue(opts)
    arr = opts.arrival; dep = opts.departure; t = opts.t;
    % Deterministic queue: Q(t) = max(0, (arr-dep)*t)
    Q = max(0, (arr - dep));  % veh/hour
    q_length = Q * t / 60;  % vehicles at time t minutes
    delay_per_veh = 0;
    if arr > dep && dep > 0
        delay_per_veh = (arr-dep)*t^2 / (2*dep) * 60;  % seconds
    end
    out = struct();
    out.action = 'queue';
    out.arrivalRate_veh_per_hr = arr;
    out.departureRate_veh_per_hr = dep;
    out.time_min = t;
    out.queueLength_veh = q_length;
    out.avgDelay_s = delay_per_veh;
end

function v = parse_vec(s)
    if ischar(s) || isstring(s)
        s = regexprep(s, '[\[\]{},]', ' ');
        v = sscanf(s, '%f'); v = v(:)';
    elseif isvector(s), v = s(:)';
    else, v = s(:)'; end
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
