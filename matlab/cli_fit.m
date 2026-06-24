function cli_fit(action, varargin)
% CLI_FIT Curve fitting and regression for ml CLI
%   CLI: ml fit poly   --degree 2 --xy "0,1,1,2,2,5"
%         ml fit exp    --xy "0,1,1,2.7,2,7.4"
%         ml fit power  --xy "1,1,2,4,3,9"
%         ml fit custom --model "a*sin(b*x)+c" --params "a,b,c" --start "1,1,0" --xy ...
%         ml fit interp --method spline --xy "0,0,1,1,2,4" --query "0.5,1.5"
%
%   Data input:
%     --xy "x1,y1,x2,y2,..."   interleaved
%     --x "x1,x2,..." --y "y1,y2,..."   separate
%
%   Options:
%     --predict "x1,x2,..."   values to evaluate fitted model at
%     --query "x1,x2,..."     interpolation query points
%     --format json|table|csv

    if nargin < 1, error('ml fit <action> [options]'); end

    opts = struct('format','json');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--xy',       opts.xy = varargin{i+1}; i=i+2;
            case '--x',        opts.x = varargin{i+1}; i=i+2;
            case '--y',        opts.y = varargin{i+1}; i=i+2;
            case '--degree',   opts.degree = parse_num(varargin{i+1}); i=i+2;
            case '--model',    opts.model = varargin{i+1}; i=i+2;
            case '--params',   opts.params = varargin{i+1}; i=i+2;
            case '--start',    opts.start = varargin{i+1}; i=i+2;
            case '--method',   opts.method = varargin{i+1}; i=i+2;
            case '--predict',  opts.predict = parse_vec(varargin{i+1}); i=i+2;
            case '--query',    opts.query = parse_vec(varargin{i+1}); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'poly',   out = act_poly(opts);
            case 'exp',    out = act_exp(opts);
            case 'power',  out = act_power(opts);
            case 'custom', out = act_custom(opts);
            case 'interp', out = act_interp(opts);
            otherwise,     error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Data parsing ===================
function [x, y] = get_xy(opts)
    if isfield(opts,'xy')
        d = parse_vec(opts.xy);
        if mod(numel(d),2) ~= 0, error('--xy must have even count (x1,y1,x2,y2,...)'); end
        x = d(1:2:end); y = d(2:2:end);
    elseif isfield(opts,'x') && isfield(opts,'y')
        x = parse_vec(opts.x); y = parse_vec(opts.y);
        if numel(x) ~= numel(y), error('--x and --y length mismatch'); end
    else
        error('need --xy "x1,y1,..." or --x and --y');
    end
end

% =================== Actions ===================
function out = act_poly(opts)
    if ~isfield(opts,'degree'), error('poly requires --degree'); end
    [x, y] = get_xy(opts);
    n = opts.degree;
    if n >= numel(x), warning('degree %d >= num points %d (underdetermined)', n, numel(x)); end
    p = polyfit(x, y, n);
    yhat = polyval(p, x);
    out = struct();
    out.action = 'poly';
    out.degree = n;
    out.coefficients = p;  % highest power first
    out.rSquared = r2(y, yhat);
    out.rmse = rmse(y, yhat);
    if isfield(opts,'predict')
        out.predictX = opts.predict;
        out.predictY = polyval(p, opts.predict);
    end
end

function out = act_exp(opts)
    % y = a*exp(b*x)
    [x, y] = get_xy(opts);
    if any(y <= 0), error('exp fit requires y > 0 (linearization uses log(y))'); end
    ly = log(y);
    p1 = polyfit(x, ly, 1);  % ly = b1*x + b0; a = exp(b0), b = b1
    a = exp(p1(2));
    b = p1(1);
    yhat = a * exp(b * x);
    out = struct();
    out.action = 'exp';
    out.model = 'a*exp(b*x)';
    out.a = a;
    out.b = b;
    out.rSquared = r2(y, yhat);
    out.rmse = rmse(y, yhat);
    if isfield(opts,'predict')
        out.predictX = opts.predict;
        out.predictY = a * exp(b * opts.predict);
    end
end

function out = act_power(opts)
    % y = a*x^b
    [x, y] = get_xy(opts);
    if any(x <= 0), error('power fit requires x > 0'); end
    if any(y <= 0), error('power fit requires y > 0'); end
    p1 = polyfit(log(x), log(y), 1);
    a = exp(p1(2));
    b = p1(1);
    yhat = a * x .^ b;
    out = struct();
    out.action = 'power';
    out.model = 'a*x^b';
    out.a = a;
    out.b = b;
    out.rSquared = r2(y, yhat);
    out.rmse = rmse(y, yhat);
    if isfield(opts,'predict')
        out.predictX = opts.predict;
        out.predictY = a * opts.predict .^ b;
    end
end

function out = act_custom(opts)
    if ~license('test','Curve_Fitting_Toolbox')
        error('Curve Fitting Toolbox license required for custom fit');
    end
    if ~isfield(opts,'model'), error('custom requires --model "expr"'); end
    if ~isfield(opts,'params'), error('custom requires --params "a,b,c"'); end
    [x, y] = get_xy(opts);
    params = strsplit(opts.params, ',');
    params = strtrim(params);
    startPt = [];
    if isfield(opts,'start'), startPt = parse_vec(opts.start); end
    ft = fittype(opts.model, 'coefficients', params, 'independent', 'x', 'dependent', 'y');
    if isempty(startPt)
        [fitObj, gof] = fit(x(:), y(:), ft);
    else
        [fitObj, gof] = fit(x(:), y(:), ft, 'StartPoint', startPt);
    end
    out = struct();
    out.action = 'custom';
    out.model = opts.model;
    coeffVals = coeffvalues(fitObj);
    for k = 1:numel(params)
        out.(params{k}) = coeffVals(k);
    end
    out.rSquared = gof.rsquare;
    out.rmse = gof.rmse;
    out.sse = gof.sse;
    if isfield(opts,'predict')
        out.predictX = opts.predict;
        out.predictY = fitObj(opts.predict);
    end
end

function out = act_interp(opts)
    if ~isfield(opts,'method'), opts.method = 'linear'; end
    [x, y] = get_xy(opts);
    if ~isfield(opts,'query'), error('interp requires --query "x1,x2,..."'); end
    [x, idx] = sort(x);
    y = y(idx);
    vq = interp1(x, y, opts.query, opts.method);
    out = struct();
    out.action = 'interp';
    out.method = opts.method;
    out.queryX = opts.query;
    out.queryY = vq;
end

% =================== Stats helpers ===================
function r = r2(y, yhat)
    sse = sum((y - yhat).^2);
    sst = sum((y - mean(y)).^2);
    if sst == 0, r = NaN; else, r = 1 - sse/sst; end
end

function r = rmse(y, yhat)
    r = sqrt(mean((y - yhat).^2));
end

% =================== Parsers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function v = parse_vec(s)
    if isnumeric(s), v = s; return; end
    s = strtrim(strrep(s, ',', ' '));
    parts = strsplit(s, ' ');
    parts = parts(~cellfun(@isempty, parts));
    v = str2double(parts);
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
