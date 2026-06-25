function cli_reliability(action, varargin)
% CLI_RELIABILITY Reliability engineering for ml CLI
%   CLI: ml reliability weibull  --shape 2 --scale 1000 --time 500
%         ml reliability bathtub  --infant 1.2 --useful 0.8 --wear 3.0 --time 400
%         ml reliability mtbf     --failures 3 --operatingHours 10000
%         ml reliability parallel --lambda 0.001 --n 3
%         ml reliability series   --lambda "[0.001,0.002,0.0005]"
%         ml reliability rbd      --structure "series,[series,a,b],parallel,c"
%
%   Options:
%     --shape BETA        Weibull shape parameter
%     --scale ETA         Weibull scale parameter
%     --time HOURS        operating time
%     --infant BETA       infant mortality shape
%     --useful BETA       constant failure rate shape
%     --wear BETA         wear-out shape
%     --failures N        number of failures
%     --operatingHours H  total operating hours
%     --lambda RATE       failure rate (per hour)
%     --n COUNT           number of components
%     --structure STR     RBD structure string
%     --format json|table|csv

    if nargin < 1, error('ml reliability <action> [options]'); end

    opts = struct('format','json','shape',2,'scale',1000,'time',500, ...
                  'infant',1.2,'useful',0.8,'wear',3.0, ...
                  'failures',3,'operatingHours',10000,'lambda',0.001, ...
                  'n',3,'lambdas','','structure','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--shape',   opts.shape = parse_num(varargin{i+1}); i=i+2;
            case '--scale',   opts.scale = parse_num(varargin{i+1}); i=i+2;
            case '--time',    opts.time = parse_num(varargin{i+1}); i=i+2;
            case '--infant',  opts.infant = parse_num(varargin{i+1}); i=i+2;
            case '--useful',  opts.useful = parse_num(varargin{i+1}); i=i+2;
            case '--wear',    opts.wear = parse_num(varargin{i+1}); i=i+2;
            case '--failures',opts.failures = parse_num(varargin{i+1}); i=i+2;
            case '--operatingHours', opts.operatingHours = parse_num(varargin{i+1}); i=i+2;
            case '--lambda',  opts.lambda = parse_num(varargin{i+1}); i=i+2;
            case '--n',       opts.n = round(parse_num(varargin{i+1})); i=i+2;
            case '--lambdas', opts.lambdas = varargin{i+1}; i=i+2;
            case '--structure',opts.structure = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'weibull',  out = act_weibull(opts);
            case 'bathtub',  out = act_bathtub(opts);
            case 'mtbf',     out = act_mtbf(opts);
            case 'parallel', out = act_parallel(opts);
            case 'series',   out = act_series(opts);
            case 'rbd',      out = act_rbd(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_weibull(opts)
    beta = opts.shape;
    eta = opts.scale;
    t = opts.time;
    % 2-parameter Weibull: R(t) = exp(-(t/eta)^beta)
    R = exp(-(t/eta)^beta);
    % Failure probability: F(t) = 1 - R(t)
    F = 1 - R;
    % Failure rate: h(t) = (beta/eta)*(t/eta)^(beta-1)
    h = (beta/eta) * (t/eta)^(beta - 1);
    % Mean Time To Failure: MTTF = eta * Gamma(1 + 1/beta)
    mttf = eta * gamma(1 + 1/beta);
    % B10 life
    b10 = eta * (-log(0.9))^(1/beta);
    out = struct();
    out.action = 'weibull';
    out.shape = beta; out.scale = eta; out.time = t;
    out.reliability = R;
    out.failureProbability = F;
    out.hazardRate = h;
    out.mttf = mttf;
    out.b10Life = b10;
end

function out = act_bathtub(opts)
    t = opts.time;
    % Simplified bathtub: 3 Weibull segments
    beta1 = opts.infant; beta2 = opts.useful; beta3 = opts.wear;
    eta1 = 200; eta2 = 10000; eta3 = 5000;
    h1 = (beta1/eta1) * (t/eta1)^(beta1-1);
    h2 = (beta2/eta2) * (t/eta2)^(beta2-1);
    h3 = (beta3/eta3) * (t/eta3)^(beta3-1);
    h_total = h1 + h2 + h3;
    if t < 200
        region = 'infant mortality';
    elseif t < 10000
        region = 'useful life';
    else
        region = 'wear-out';
    end
    out = struct();
    out.action = 'bathtub';
    out.time = t;
    out.h_infant = h1;
    out.h_useful = h2;
    out.h_wear = h3;
    out.h_total = h_total;
    out.region = region;
end

function out = act_mtbf(opts)
    nf = opts.failures;
    T = opts.operatingHours;
    if nf == 0
        mtbf = T;  % conservative estimate
        lambda = 1 / mtbf;
    else
        lambda = nf / T;
        mtbf = T / nf;
    end
    % Confidence interval (χ², 90%)
    if nf > 0
        chi2_lower = chi2inv(0.05, 2*nf);
        chi2_upper = chi2inv(0.95, 2*nf + 2);
        mtbf_lower = 2*T / chi2_upper;
        mtbf_upper = 2*T / chi2_lower;
    else
        mtbf_lower = NaN; mtbf_upper = NaN;
    end
    % Availability (assume MTTR = 24h)
    mttr = 24;
    availability = mtbf / (mtbf + mttr);
    out = struct();
    out.action = 'mtbf';
    out.failures = nf;
    out.operatingHours = T;
    out.mtbf_hours = mtbf;
    out.failureRate_per_hour = lambda;
    out.confidence90pct = struct('lower', mtbf_lower, 'upper', mtbf_upper);
    out.availability = availability;
    out.mttr_assumed_hours = mttr;
end

function out = act_parallel(opts)
    lambda = opts.lambda;
    n = opts.n;
    % Identical parallel: R_sys = 1 - prod(1 - R_i)
    % MTBF_parallel = (1/λ) * (1 + 1/2 + ... + 1/n)
    mtbf = (1/lambda) * sum(1 ./ (1:n));
    % Reliability at 1000h
    t = 1000;
    R = 1 - (1 - exp(-lambda*t))^n;
    out = struct();
    out.action = 'parallel';
    out.components = n;
    out.lambda = lambda;
    out.mtbf_hours = mtbf;
    out.reliability_1000h = R;
    out.improvementFactor = mtbf / (1/lambda);
end

function out = act_series(opts)
    lambdas = parse_vec(opts.lambdas);
    % Series system: λ_sys = sum(λ_i), MTBF = 1/λ_sys
    lambda_sys = sum(lambdas);
    mtbf = 1 / lambda_sys;
    % Weakest link identification
    [maxLambda, idx] = max(lambdas);
    out = struct();
    out.action = 'series';
    out.components = numel(lambdas);
    out.lambdas = lambdas;
    out.totalLambda = lambda_sys;
    out.mtbf_hours = mtbf;
    out.weakestLink = struct('index', idx, 'lambda', maxLambda);
end

function out = act_rbd(opts)
    % Simple RBD parser: "series,A,B" or "parallel,A,B" or "series,[parallel,A,B],C"
    s = opts.structure;
    [R_sys, details] = parse_rbd(s, []);
    out = struct();
    out.action = 'rbd';
    out.structure = s;
    out.systemReliability = R_sys;
    out.details = details;
end

% =================== RBD Parser (simplified) ===================
function [R, d] = parse_rbd(s, params)
    % Parse structure string into reliability tree
    % Assumes each component has reliability from params(component_name)
    % For now: return basic parse tree
    s = strtrim(s);
    d = struct('type', '', 'children', []);
    if contains(s, 'series')
        d.type = 'series';
        inner = extract_between(s, 'series,', '');
    elseif contains(s, 'parallel')
        d.type = 'parallel';
        inner = extract_between(s, 'parallel,', '');
    else
        % Single component
        d.type = 'leaf';
        d.name = s;
        R = 0.9;  % default, would be looked up from params
    end
end

function inner = extract_between(s, prefix, suffix)
    s = strrep(s, prefix, '');
    inner = s;
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
