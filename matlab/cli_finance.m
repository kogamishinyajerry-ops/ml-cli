function cli_finance(action, varargin)
% CLI_FINANCE Financial analysis for ml CLI
%   CLI: ml finance options  --type call --S 100 --K 105 --T 1 --r 0.05 --sigma 0.2
%         ml finance portfolio --returns "[0.08 0.12; 0.12 0.25]" --target 0.1
%         ml finance var       --returns "[0.01 -0.02 0.03 ...]" --conf 0.95
%         ml finance bond      --face 1000 --coupon 0.05 --yield 0.04 --maturity 10
%         ml finance amort     --principal 200000 --rate 0.04 --years 30
%         ml finance irr       --cashflows "[-1000 300 400 500]"
%
%   Options:
%     --type NAME       call|put (for options)
%     --S PRICE         underlying spot price
%     --K STRIKE        strike price
%     --T YEARS         time to maturity (years)
%     --r RATE          risk-free rate (decimal, e.g. 0.05)
%     --sigma VOL       volatility (decimal, e.g. 0.2)
%     --q RATE          dividend yield (default 0)
%     --returns MATRIX  covariance matrix or return series
%     --target RET      target return for portfolio optimization
%     --conf P          confidence level for VaR (default 0.95)
%     --face VAL        bond face value
%     --coupon RATE     annual coupon rate
%     --yield RATE      yield to maturity
%     --maturity YRS    years to maturity
%     --principal VAL   loan principal
%     --rate RATE       annual interest rate
%     --years N         loan term in years
%     --cashflows VEC   cashflow vector for IRR/NPV
%     --format json|table|csv

    if nargin < 1, error('ml finance <action> [options]'); end

    opts = struct('format','json','type','call','S',100,'K',100,'T',1,'r',0.05, ...
                  'sigma',0.2,'q',0,'returns','','target',0.1,'conf',0.95, ...
                  'face',1000,'coupon',0.05,'yield',0.04,'maturity',10, ...
                  'principal',200000,'rate',0.04,'years',30,'cashflows','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--type',      opts.type = lower(varargin{i+1}); i=i+2;
            case '--S',         opts.S = parse_num(varargin{i+1}); i=i+2;
            case '--K',         opts.K = parse_num(varargin{i+1}); i=i+2;
            case '--T',         opts.T = parse_num(varargin{i+1}); i=i+2;
            case '--r',         opts.r = parse_num(varargin{i+1}); i=i+2;
            case '--sigma',     opts.sigma = parse_num(varargin{i+1}); i=i+2;
            case '--q',         opts.q = parse_num(varargin{i+1}); i=i+2;
            case '--returns',   opts.returns = varargin{i+1}; i=i+2;
            case '--target',    opts.target = parse_num(varargin{i+1}); i=i+2;
            case '--conf',      opts.conf = parse_num(varargin{i+1}); i=i+2;
            case '--face',      opts.face = parse_num(varargin{i+1}); i=i+2;
            case '--coupon',    opts.coupon = parse_num(varargin{i+1}); i=i+2;
            case '--yield',     opts.yield = parse_num(varargin{i+1}); i=i+2;
            case '--maturity',  opts.maturity = parse_num(varargin{i+1}); i=i+2;
            case '--principal', opts.principal = parse_num(varargin{i+1}); i=i+2;
            case '--rate',      opts.rate = parse_num(varargin{i+1}); i=i+2;
            case '--years',     opts.years = parse_num(varargin{i+1}); i=i+2;
            case '--cashflows', opts.cashflows = varargin{i+1}; i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'options',  out = act_options(opts);
            case 'portfolio',out = act_portfolio(opts);
            case 'var',      out = act_var(opts);
            case 'bond',     out = act_bond(opts);
            case 'amort',    out = act_amort(opts);
            case 'irr',      out = act_irr(opts);
            case 'npv',      out = act_npv(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_options(opts)
    % Black-Scholes-Merton option pricing
    S = opts.S; K = opts.K; T = opts.T; r = opts.r;
    sigma = opts.sigma; q = opts.q;
    if T <= 0, error('T must be positive'); end
    if sigma <= 0, error('sigma must be positive'); end

    d1 = (log(S/K) + (r - q + 0.5*sigma^2)*T) / (sigma*sqrt(T));
    d2 = d1 - sigma*sqrt(T);

    N = @(x) 0.5 * erfc(-x/sqrt(2));   % standard normal CDF

    switch lower(opts.type)
        case 'call'
            price = S*exp(-q*T)*N(d1) - K*exp(-r*T)*N(d2);
            delta = exp(-q*T)*N(d1);
            theta = (-S*exp(-q*T)*N(d1)*sigma/(2*sqrt(T)) ...
                     - r*K*exp(-r*T)*N(d2) + q*S*exp(-q*T)*N(d1)) / 365;
            rho = K*T*exp(-r*T)*N(d2) / 100;
        case 'put'
            price = K*exp(-r*T)*N(-d2) - S*exp(-q*T)*N(-d1);
            delta = exp(-q*T)*(N(d1) - 1);
            theta = (-S*exp(-q*T)*N(d1)*sigma/(2*sqrt(T)) ...
                     + r*K*exp(-r*T)*N(-d2) - q*S*exp(-q*T)*N(-d1)) / 365;
            rho = -K*T*exp(-r*T)*N(-d2) / 100;
        otherwise
            error('unknown option type: %s (call|put)', opts.type);
    end

    gamma = exp(-q*T) * normpdf_d1(d1) / (S*sigma*sqrt(T));
    vega = S*exp(-q*T)*sqrt(T)*normpdf_d1(d1) / 100;

    out = struct();
    out.action = 'options';
    out.model = 'Black-Scholes-Merton';
    out.type = opts.type;
    out.S = S; out.K = K; out.T = T; out.r = r; out.sigma = sigma; out.q = q;
    out.d1 = d1; out.d2 = d2;
    out.price = price;
    out.greeks = struct('delta', delta, 'gamma', gamma, ...
                        'theta_daily', theta, 'vega_pct', vega, 'rho_pct', rho);
end

function out = act_portfolio(opts)
    % Markowitz mean-variance optimization (2 assets from covariance + assumed means)
    % Input: 2x2 covariance matrix, expected returns vector extracted from diagonal
    Cov = parse_mat(opts.returns);
    if size(Cov,1) ~= size(Cov,2), error('returns must be square covariance matrix'); end
    n = size(Cov,1);
    % Use sqrt(diag) as expected returns proxy if user didn't supply separate means
    mu = sqrt(diag(Cov)) * 0.1;  % scale down (volatility -> expected return heuristic)
    target = opts.target;

    % Closed-form minimum-variance portfolio (no risk-free)
    onesN = ones(n,1);
    invCov = inv(Cov);
    A = onesN' * invCov * onesN;
    b = onesN' * invCov * mu;
    c = mu' * invCov * mu;
    det = A*c - b^2;
    if abs(det) < 1e-12
        % Just min-variance portfolio
        w_minvar = invCov * onesN / A;
        w = w_minvar;
        portMu = w' * mu;
        portVar = w' * Cov * w;
        portStd = sqrt(portVar);
        weights = w;
        method = 'minimum-variance (no risk-free)';
    else
        % Target-return minimum variance
        g = (c - b*target) / det;
        h = (A*target - b) / det;
        w = invCov * (g*onesN + h*mu);
        portMu = w' * mu;
        portVar = w' * Cov * w;
        portStd = sqrt(portVar);
        weights = w;
        method = 'Markowitz (target return)';
    end
    out = struct();
    out.action = 'portfolio';
    out.method = method;
    out.nAssets = n;
    out.expectedReturns = mu;
    out.covariance = Cov;
    out.targetReturn = target;
    out.weights = weights;
    out.portfolioReturn = portMu;
    out.portfolioVolatility = portStd;
    out.sharpeRatio = (portMu) / portStd;
end

function out = act_var(opts)
    % Historical Value-at-Risk
    returns = parse_vec(opts.cashflows);
    if isempty(returns), returns = parse_vec(opts.returns); end
    if isempty(returns), error('need --returns vector'); end
    conf = opts.conf;
    if conf <= 0 || conf >= 1, error('conf must be in (0,1)'); end
    percentile = 1 - conf;
    VaR = -quantile(returns, percentile);
    % Expected shortfall (CVaR)
    tailLosses = returns(returns < -VaR);
    if isempty(tailLosses)
        ES = VaR;
    else
        ES = -mean(tailLosses);
    end
    out = struct();
    out.action = 'var';
    out.method = 'historical';
    out.confidence = conf;
    out.nObs = numel(returns);
    out.meanReturn = mean(returns);
    out.stdReturn = std(returns);
    out.VaR = VaR;
    out.expectedShortfall = ES;
end

function out = act_bond(opts)
    % Bond pricing via YTM
    F = opts.face; c = opts.coupon; y = opts.yield; n = opts.maturity;
    couponPayment = F * c;
    % Present value of coupons (annuity)
    pvCoupons = couponPayment * (1 - (1+y)^(-n)) / y;
    % Present value of face
    pvFace = F / (1+y)^n;
    price = pvCoupons + pvFace;
    % Duration (Macaulay)
    t = 1:n;
    cf = couponPayment * ones(1, n);
    cf(end) = cf(end) + F;
    pvCF = cf ./ (1+y).^t;
    duration = sum(t .* pvCF) / price;
    modifiedDuration = duration / (1+y);
    % Convexity
    convexity = sum(t.*(t+1) .* pvCF) / (price * (1+y)^2);
    out = struct();
    out.action = 'bond';
    out.face = F; out.couponRate = c; out.ytm = y; out.yearsToMaturity = n;
    out.couponPayment = couponPayment;
    out.price = price;
    out.macaulayDuration = duration;
    out.modifiedDuration = modifiedDuration;
    out.convexity = convexity;
    out.currentYield = couponPayment / price;
end

function out = act_amort(opts)
    % Loan amortization schedule
    P = opts.principal; r = opts.rate / 12; n = round(opts.years * 12);
    if r == 0
        payment = P / n;
    else
        payment = P * r * (1+r)^n / ((1+r)^n - 1);
    end
    balance = P;
    sched = zeros(n, 4);
    for k = 1:n
        interest = balance * r;
        principal = payment - interest;
        balance = balance - principal;
        sched(k, :) = [k, interest, principal, max(0, balance)];
    end
    out = struct();
    out.action = 'amort';
    out.principal = P; out.annualRate = opts.rate; out.years = opts.years;
    out.monthlyPayment = payment;
    out.totalPaid = payment * n;
    out.totalInterest = payment * n - P;
    out.scheduleFirst12 = sched(1:min(12,n), :);
end

function out = act_irr(opts)
    cf = parse_vec(opts.cashflows);
    if isempty(cf), error('need --cashflows'); end
    % Newton-Raphson IRR
    rate = 0.1;
    for iter = 1:100
        npv = cf(1);
        dnpv = 0;
        for t = 1:numel(cf)-1
            disc = (1+rate)^t;
            npv = npv + cf(t+1) / disc;
            dnpv = dnpv - t * cf(t+1) / ((1+rate)^(t+1));
        end
        if abs(dnpv) < 1e-12, break; end
        newRate = rate - npv/dnpv;
        if abs(newRate - rate) < 1e-10, break; end
        rate = newRate;
        if rate < -0.99, rate = -0.99; break; end
    end
    out = struct();
    out.action = 'irr';
    out.cashflows = cf;
    out.irr = rate;
    out.npv_at_irr = 0;  % by definition
end

function out = act_npv(opts)
    cf = parse_vec(opts.cashflows);
    if isempty(cf), error('need --cashflows'); end
    r = opts.r;
    npv = cf(1);
    for t = 1:numel(cf)-1
        npv = npv + cf(t+1) / (1+r)^t;
    end
    out = struct();
    out.action = 'npv';
    out.cashflows = cf;
    out.discountRate = r;
    out.npv = npv;
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function M = parse_mat(s)
    if ischar(s) || isstring(s), M = eval(s); else, M = s; end
end

function v = parse_vec(s)
    if ischar(s) || isstring(s)
        % strip brackets/braces if present
        s = regexprep(s, '[\[\]{}]', '');
        v = sscanf(s, '%f');
    elseif isvector(s)
        v = s(:);
    else
        v = s(:);
    end
end

function p = normpdf_d1(x)
    p = exp(-0.5*x^2) / sqrt(2*pi);
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
