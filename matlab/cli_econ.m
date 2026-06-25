function cli_econ(action, varargin)
% CLI_ECON Economics calculations for ml CLI
%   CLI: ml econ supply_demand --demand "10,-0.5" --supply "2,0.3" --solve equilibrium
%         ml econ elasticity --q1 100 --q2 80 --p1 10 --p2 12
%         ml econ breakeven --fixed 10000 --price 50 --variable 30
%         ml econ compound --principal 1000 --rate 0.05 --years 10
%         ml econ utility --bundle "[10,5]" --prices "[2,3]" --budget 100
%         ml econ cost --quantity 500 --fixed 10000 --variable 20
%
%   Options:
%     --demand STR     demand curve: "a,b" = Q = a + b*P
%     --supply STR     supply curve: "a,b" = Q = a + b*P
%     --solve NAME     equilibrium|price|quantity
%     --q1 --q2 --p1 --p2  quantities and prices for elasticity
%     --fixed FLOAT    fixed costs
%     --price FLOAT    unit price
%     --variable FLOAT variable cost per unit
%     --principal FLOAT initial investment
%     --rate FLOAT     annual interest rate (decimal)
%     --years N        time period (years)
%     --bundle VEC     consumption bundle
%     --prices VEC     price vector
%     --budget FLOAT   budget constraint
%     --quantity N     production quantity
%     --format json|table|csv

    if nargin < 1, error('ml econ <action> [options]'); end

    opts = struct('format','json','demand','','supply','','solve','equilibrium', ...
                  'q1',100,'q2',80,'p1',10,'p2',12, ...
                  'fixed',10000,'price',50,'variable',30, ...
                  'principal',1000,'rate',0.05,'years',10,'payments',12, ...
                  'bundle','','prices','','budget',100,'quantity',500);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--demand',    opts.demand = varargin{i+1}; i=i+2;
            case '--supply',    opts.supply = varargin{i+1}; i=i+2;
            case '--solve',     opts.solve = lower(varargin{i+1}); i=i+2;
            case '--q1',        opts.q1 = parse_num(varargin{i+1}); i=i+2;
            case '--q2',        opts.q2 = parse_num(varargin{i+1}); i=i+2;
            case '--p1',        opts.p1 = parse_num(varargin{i+1}); i=i+2;
            case '--p2',        opts.p2 = parse_num(varargin{i+1}); i=i+2;
            case '--fixed',     opts.fixed = parse_num(varargin{i+1}); i=i+2;
            case '--price',     opts.price = parse_num(varargin{i+1}); i=i+2;
            case '--variable',  opts.variable = parse_num(varargin{i+1}); i=i+2;
            case '--principal', opts.principal = parse_num(varargin{i+1}); i=i+2;
            case '--rate',      opts.rate = parse_num(varargin{i+1}); i=i+2;
            case '--years',     opts.years = parse_num(varargin{i+1}); i=i+2;
            case '--payments',  opts.payments = round(parse_num(varargin{i+1})); i=i+2;
            case '--bundle',    opts.bundle = varargin{i+1}; i=i+2;
            case '--prices',    opts.prices = varargin{i+1}; i=i+2;
            case '--budget',    opts.budget = parse_num(varargin{i+1}); i=i+2;
            case '--quantity',  opts.quantity = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'supply_demand', out = act_supply_demand(opts);
            case 'elasticity',    out = act_elasticity(opts);
            case 'breakeven',     out = act_breakeven(opts);
            case 'compound',      out = act_compound(opts);
            case 'utility',       out = act_utility(opts);
            case 'cost',          out = act_cost(opts);
            otherwise,            error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_supply_demand(opts)
    dem = parse_curve(opts.demand);
    sup = parse_curve(opts.supply);
    % Demand: Qd = d_a + d_b*P
    % Supply: Qs = s_a + s_b*P
    % Equilibrium: Qd = Qs → P* = (d_a - s_a) / (s_b - d_b)
    d_a = dem(1); d_b = dem(2);
    s_a = sup(1); s_b = sup(2);
    denom = s_b - d_b;
    if abs(denom) < 1e-12
        error('parallel supply/demand curves');
    end
    Peq = (d_a - s_a) / denom;
    Qeq = d_a + d_b * Peq;
    % Consumer surplus = area above price, below demand
    if d_b < 0
        cs = 0.5 * (d_a/d_b * d_a) - Peq*Qeq - 0.5*(d_a / (-d_b) - Peq)*Qeq;
        % Simpler: (Pmax - Peq)*Qeq/2
        Pmax = min(1e6, -d_a / d_b);
        cs = max(0, 0.5 * (Pmax - Peq) * Qeq);
    else
        cs = NaN;
    end
    % Producer surplus
    ps = max(0, 0.5 * Peq * Qeq);
    out = struct();
    out.action = 'supply_demand';
    out.equilibriumPrice = Peq;
    out.equilibriumQuantity = Qeq;
    out.consumerSurplus = cs;
    out.producerSurplus = ps;
end

function out = act_elasticity(opts)
    q1 = opts.q1; q2 = opts.q2;
    p1 = opts.p1; p2 = opts.p2;
    % Arc elasticity: (dQ/Qavg) / (dP/Pavg)
    dQ = q2 - q1; Qavg = (q1 + q2)/2;
    dP = p2 - p1; Pavg = (p1 + p2)/2;
    if abs(dP) < 1e-12 || abs(Qavg) < 1e-12
        e = Inf;
    else
        e = (dQ / Qavg) / (dP / Pavg);
    end
    if e < -1, kind = 'elastic';
    elseif e > -1 && e < 0, kind = 'inelastic';
    elseif e == -1, kind = 'unit elastic';
    elseif e > 0, kind = 'Giffen/Veblen (positive)';
    else, kind = 'unknown'; end
    out = struct();
    out.action = 'elasticity';
    out.method = 'arc elasticity';
    out.pctChangeQ = 100 * dQ / Qavg;
    out.pctChangeP = 100 * dP / Pavg;
    out.elasticity = e;
    out.type = kind;
end

function out = act_breakeven(opts)
    FC = opts.fixed;
    P = opts.price;
    VC = opts.variable;
    % Break-even quantity: FC / (P - VC) = FC / contribution margin
    cm = P - VC;
    if cm <= 0
        error('price must exceed variable cost (negative contribution margin)');
    end
    Qbe = FC / cm;
    TRbe = Qbe * P;
    out = struct();
    out.action = 'breakeven';
    out.fixedCost = FC;
    out.unitPrice = P;
    out.variableCost = VC;
    out.contributionMargin = cm;
    out.breakevenQuantity = Qbe;
    out.breakevenRevenue = TRbe;
end

function out = act_compound(opts)
    P = opts.principal;
    r = opts.rate;
    t = opts.years;
    n = opts.payments;  % compounding periods per year
    % Discrete compounding: FV = P*(1+r/n)^(n*t)
    FV = P * (1 + r/n)^(n * t);
    % Continuous compounding: FV = P*exp(r*t) (if n=0)
    FV_continuous = P * exp(r * t);
    totalInterest = FV - P;
    out = struct();
    out.action = 'compound';
    out.principal = P;
    out.annualRate = r;
    out.years = t;
    out.compoundingPeriodsPerYear = n;
    out.futureValue = FV;
    out.continuousFV = FV_continuous;
    out.totalInterest = totalInterest;
    out.effectiveRate = (1 + r/n)^n - 1;
end

function out = act_utility(opts)
    bundle = parse_vec(opts.bundle);
    prices = parse_vec(opts.prices);
    budget = opts.budget;
    % Total cost
    totalCost = sum(bundle .* prices);
    % Budget remaining
    remaining = budget - totalCost;
    % Utility: Cobb-Douglas U = prod(xi^ai) with equal weights
    U = prod(bundle .^ (1/numel(bundle)));
    % Budget constraint check
    feasible = totalCost <= budget;
    % Marginal utility per dollar: MU/P for each good
    muPerDollar = (1/numel(bundle)) * (U ./ bundle) ./ prices;
    out = struct();
    out.action = 'utility';
    out.bundle = bundle;
    out.prices = prices;
    out.budget = budget;
    out.totalCost = totalCost;
    out.remaining = remaining;
    out.feasible = feasible;
    out.utility = U;
    out.marginalUtilityPerDollar = muPerDollar;
end

function out = act_cost(opts)
    Q = opts.quantity;
    FC = opts.fixed;
    VC = opts.variable * Q;
    TC = FC + VC;
    AFC = FC / max(1, Q);
    AVC = opts.variable;    % constant variable cost per unit
    ATC = TC / max(1, Q);
    MC = opts.variable;     % constant marginal cost = VC/unit
    out = struct();
    out.action = 'cost';
    out.quantity = Q;
    out.fixedCost = FC;
    out.variableCost = VC;
    out.totalCost = TC;
    out.avgFixedCost = AFC;
    out.avgVariableCost = AVC;
    out.avgTotalCost = ATC;
    out.marginalCost = MC;
end

% =================== Helpers ===================
function c = parse_curve(s)
    if ischar(s) || isstring(s)
        s = regexprep(s, '[{},]', ' ');
        c = sscanf(s, '%f');
    else
        c = s(:)';
    end
    if numel(c) < 2, error('curve needs 2 parameters "a,b"'); end
    c = c(1:2);
end

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
