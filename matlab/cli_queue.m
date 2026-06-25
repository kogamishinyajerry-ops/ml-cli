function cli_queue(action, varargin)
% CLI_QUEUE Queueing theory for ml CLI
%   CLI: ml queue mm1      --lambda 5 --mu 6
%         ml queue mmc      --lambda 10 --mu 4 --c 3
%         ml queue little   --lambda 5 --w 0.5
%         ml queue prob     --lambda 3 --mu 4 --n 2
%         ml queue mg1      --lambda 3 --mu 5 --cv_sq 2
%
%   Options:
%     --lambda RATE   arrival rate (customers per time unit)
%     --mu RATE       service rate (per server)
%     --c COUNT       number of servers (default 1)
%     --w TIME        average waiting time (for Little's law)
%     --l COUNT       average number in system
%     --n COUNT       number of customers (for state probability)
%     --cv_sq VAL     squared coefficient of variation (for M/G/1)
%     --format json|table|csv

    if nargin < 1, error('ml queue <action> [options]'); end

    opts = struct('format','json','lambda',5,'mu',6,'c',1,'w',0,'l',0, ...
                  'n',0,'cv_sq',1);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--lambda', opts.lambda = parse_num(varargin{i+1}); i=i+2;
            case '--mu',     opts.mu = parse_num(varargin{i+1}); i=i+2;
            case '--c',      opts.c = round(parse_num(varargin{i+1})); i=i+2;
            case '--w',      opts.w = parse_num(varargin{i+1}); i=i+2;
            case '--l',      opts.l = parse_num(varargin{i+1}); i=i+2;
            case '--n',      opts.n = round(parse_num(varargin{i+1})); i=i+2;
            case '--cv_sq',  opts.cv_sq = parse_num(varargin{i+1}); i=i+2;
            case '--format', opts.format = varargin{i+1}; i=i+2;
            otherwise,       i=i+1;
        end
    end

    try
        switch lower(action)
            case 'mm1',   out = act_mm1(opts);
            case 'mmc',   out = act_mmc(opts);
            case 'little',out = act_little(opts);
            case 'prob',  out = act_prob(opts);
            case 'mg1',   out = act_mg1(opts);
            otherwise,    error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_mm1(opts)
    lambda = opts.lambda;
    mu = opts.mu;
    if mu <= 0, error('mu must be positive'); end
    rho = lambda / mu;
    if rho >= 1, error('system unstable: lambda (%g) >= mu (%g) [rho=%g]', lambda, mu, rho); end
    % Steady-state metrics
    L = rho / (1 - rho);           % avg customers in system
    Lq = rho^2 / (1 - rho);        % avg customers in queue
    W = 1 / (mu - lambda);          % avg time in system
    Wq = rho / (mu - lambda);       % avg time in queue
    p0 = 1 - rho;                  % probability of empty system
    out = struct();
    out.action = 'mm1';
    out.model = 'M/M/1';
    out.arrivalRate = lambda;
    out.serviceRate = mu;
    out.utilization = rho;
    out.P0 = p0;
    out.L_avgInSystem = L;
    out.Lq_avgInQueue = Lq;
    out.W_avgTimeInSystem = W;
    out.Wq_avgTimeInQueue = Wq;
end

function out = act_mmc(opts)
    lambda = opts.lambda;
    mu = opts.mu;
    c = opts.c;
    rho = lambda / (c * mu);
    if rho >= 1, error('system unstable: rho=%g >= 1', rho); end
    % Erlang-C formula: P(wait > 0)
    % First compute P0
    sumTerm = 0;
    for k = 0:c-1
        sumTerm = sumTerm + (c*rho)^k / factorial(k);
    end
    p0 = 1 / (sumTerm + (c*rho)^c / (factorial(c)*(1 - rho)));
    % Erlang-C = P(queue length > 0)
    erlangC = (c*rho)^c * p0 / (factorial(c)*(1 - rho));
    % Average queue length
    Lq = erlangC * rho / (1 - rho);
    % Average in system
    L = Lq + c * rho;
    % Wait times
    W = L / lambda;
    Wq = Lq / lambda;
    out = struct();
    out.action = 'mmc';
    out.model = sprintf('M/M/%d', c);
    out.arrivalRate = lambda;
    out.serviceRate = mu;
    out.servers = c;
    out.serverUtilization = rho;
    out.erlangC = erlangC;
    out.probWait = erlangC;
    out.P0 = p0;
    out.L_avgInSystem = L;
    out.Lq_avgInQueue = Lq;
    out.W_avgTimeInSystem = W;
    out.Wq_avgTimeInQueue = Wq;
end

function out = act_little(opts)
    % Little's Law: L = lambda * W
    lambda = opts.lambda;
    w = opts.w;
    l = opts.l;
    if w > 0 && l == 0
        % Given W, find L
        L = lambda * w;
        solved = 'L (from W)';
        val = L;
    elseif l > 0 && w == 0
        % Given L, find W
        W = l / lambda;
        solved = 'W (from L)';
        val = W;
    elseif l > 0 && w > 0
        % Verify Little's law
        residual = l - lambda * w;
        solved = 'verification';
        val = residual;
    else
        error('need --l or --w');
    end
    out = struct();
    out.action = 'little';
    out.law = 'L = lambda * W';
    out.solved = solved;
    out.value = val;
    out.L = l;
    out.lambda = lambda;
    out.W = w;
end

function out = act_prob(opts)
    % Steady-state probability of exactly n customers in system
    lambda = opts.lambda;
    mu = opts.mu;
    n = opts.n;
    if mu <= 0, error('mu must be positive'); end
    rho = lambda / mu;
    if rho >= 1 && n == 0
        pn = 0;
    else
        pn = (1 - rho) * rho^n;
    end
    % Cumulative: P(N <= n)
    pCum = 1 - rho^(n+1);
    out = struct();
    out.action = 'prob';
    out.model = 'M/M/1';
    out.rho = rho;
    out.n = n;
    out.P_n_customers = pn;
    out.P_at_most_n = min(1, pCum);
end

function out = act_mg1(opts)
    % M/G/1 queue (Pollaczek-Khinchine formula)
    lambda = opts.lambda;
    mu = opts.mu;
    cv2 = opts.cv_sq;
    rho = lambda / mu;
    if rho >= 1, error('system unstable: rho=%g >= 1', rho); end
    Wq = (lambda * (1/mu^2 + cv2/mu^2)) / (2 * (1 - rho));
    Lq = lambda * Wq;
    W = Wq + 1/mu;
    L = lambda * W;
    out = struct();
    out.action = 'mg1';
    out.model = 'M/G/1 (Pollaczek-Khinchine)';
    out.arrivalRate = lambda;
    out.serviceRate = mu;
    out.serviceTimeVar_Cv2 = cv2;
    out.utilization = rho;
    out.Wq_avgWait = Wq;
    out.Lq_avgQueue = Lq;
    out.W_avgTime = W;
    out.L_avgSystem = L;
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
