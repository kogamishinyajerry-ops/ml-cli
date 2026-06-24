function cli_time(action, varargin)
% CLI_TIME Time-series analysis for ml CLI
%   CLI: ml time info      <series.csv>
%         ml time acf      <series.csv> --lags 20
%         ml time decomp   <series.csv> --period 12
%         ml time forecast <series.csv> --horizon 10 --method hw
%         ml time arima    <series.csv> --p 2 --d 1 --q 1
%         ml time outlier  <series.csv> --threshold 3
%
%   Options:
%     --lags N        max ACF lag
%     --period N      seasonal period for decomposition
%     --horizon N     forecast steps
%     --method NAME   hw|ma|ets (default hw = Holt-Winters)
%     --p N           AR order
%     --d N           differencing order
%     --q N           MA order
%     --threshold VAL outlier z-score threshold (default 3)
%     --format json|table|csv

    if nargin < 1, error('ml time <action> [options]'); end

    opts = struct('format','json','lags',20,'period',12,'horizon',10, ...
                  'method','hw','p',1,'d',1,'q',1,'threshold',3,'file','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--lags',      opts.lags = round(parse_num(varargin{i+1})); i=i+2;
            case '--period',    opts.period = round(parse_num(varargin{i+1})); i=i+2;
            case '--horizon',   opts.horizon = round(parse_num(varargin{i+1})); i=i+2;
            case '--method',    opts.method = lower(varargin{i+1}); i=i+2;
            case '--p',         opts.p = round(parse_num(varargin{i+1})); i=i+2;
            case '--d',         opts.d = round(parse_num(varargin{i+1})); i=i+2;
            case '--q',         opts.q = round(parse_num(varargin{i+1})); i=i+2;
            case '--threshold', opts.threshold = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          opts.file = tok; i=i+1;
        end
    end

    try
        switch lower(action)
            case 'info',     out = act_info(opts);
            case 'acf',      out = act_acf(opts);
            case 'decomp',   out = act_decomp(opts);
            case 'forecast', out = act_forecast(opts);
            case 'arima',    out = act_arima(opts);
            case 'outlier',  out = act_outlier(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Read series ===================
function y = read_series(opts)
    if isempty(opts.file), error('series file required'); end
    data = readmatrix(opts.file);
    % Drop header row if NaN
    if size(data,1) > 1 && any(~isfinite(data(1,:)))
        data(1,:) = [];
    end
    if size(data, 2) >= 2
        y = data(:, 2);   % second column is value (first is time index)
    else
        y = data(:, 1);
    end
    y = y(:);
end

% =================== Actions ===================
function out = act_info(opts)
    y = read_series(opts);
    out = struct();
    out.numSamples = numel(y);
    out.mean = mean(y);
    out.std = std(y);
    out.min = min(y);
    out.max = max(y);
    out.range = max(y) - min(y);
    % Trend via linear regression
    t = (1:numel(y))';
    coef = polyfit(t, y, 1);
    out.trendSlope = coef(1);
    out.trendIntercept = coef(2);
    % Stationarity test (ADF approximation via simple unit root)
    % First-difference variance ratio
    dy = diff(y);
    out.varianceRatio = var(dy) / var(y);
    out.likelyStationary = out.varianceRatio > 0.5;
end

function out = act_acf(opts)
    y = read_series(opts);
    n = numel(y);
    lags = 0:min(opts.lags, n-1);
    y_demeaned = y - mean(y);
    denom = sum(y_demeaned.^2);
    acf_vals = zeros(size(lags));
    for k = 1:numel(lags)
        lag = lags(k);
        if lag == 0
            acf_vals(k) = 1;
        else
            acf_vals(k) = sum(y_demeaned(1:end-lag) .* y_demeaned(lag+1:end)) / denom;
        end
    end
    % Confidence band
    confBand = 1.96 / sqrt(n);
    out = struct();
    out.numSamples = n;
    out.lags = lags;
    out.acf = acf_vals;
    out.confidenceBand = confBand;
    out.significantLags = lags(abs(acf_vals) > confBand);
end

function out = act_decomp(opts)
    y = read_series(opts);
    n = numel(y);
    p = opts.period;
    if p > n/2, error('period too large for series length'); end
    % Trend via centered moving average of length = period
    trendMovAvg = movmean(y, [floor(p/2), ceil(p/2)-1]);
    detrended = y - trendMovAvg;
    % Seasonal: average by phase
    seasonal = zeros(size(y));
    for phase = 1:p
        idx = phase:p:n;
        if ~isempty(idx)
            phase_mean = mean(detrended(idx(~isnan(detrended(idx)))));
            seasonal(idx) = phase_mean;
        end
    end
    % Center seasonal
    seasonal = seasonal - mean(seasonal);
    residual = y - trendMovAvg - seasonal;
    out = struct();
    out.numSamples = n;
    out.period = p;
    out.observed = y(:)';
    out.trend = trendMovAvg(:)';
    out.seasonal = seasonal(:)';
    out.residual = residual(:)';
    out.residualStd = std(residual(~isnan(residual)));
    out.seasonalStrength = var(seasonal) / (var(seasonal) + var(residual(~isnan(residual))) + eps);
end

function out = act_forecast(opts)
    y = read_series(opts);
    n = numel(y);
    h = opts.horizon;
    method = opts.method;
    switch method
        case 'ma'
            % Simple moving average forecast (last window)
            window = min(5, n);
            fc = mean(y(end-window+1:end)) * ones(1, h);
            methodInfo = sprintf('moving average (window=%d)', window);
        case 'ets'
            % Exponential smoothing
            alpha = 0.3;
            level = y(1);
            for t = 2:n
                level = alpha * y(t) + (1-alpha) * level;
            end
            fc = level * ones(1, h);
            methodInfo = 'simple exponential smoothing (alpha=0.3)';
        case 'hw'
            % Holt-Winters (additive)
            p = opts.period;
            if p > n/2, p = max(2, floor(n/4)); end
            alpha = 0.5; beta = 0.1; gamma = 0.1;
            % Init
            level = mean(y(1:p));
            trend = (mean(y(p+1:2*p)) - mean(y(1:p))) / p;
            seasonal = zeros(p, 1);
            for i = 1:p
                seasonal(i) = y(i) - level;
            end
            fc_history = zeros(n, 1);
            for t = 1:n
                phase = mod(t-1, p) + 1;
                if t > 2*p
                    new_level = alpha * (y(t) - seasonal(phase)) + (1-alpha) * (level + trend);
                    new_trend = beta * (new_level - level) + (1-beta) * trend;
                    seasonal(phase) = gamma * (y(t) - new_level) + (1-gamma) * seasonal(phase);
                    level = new_level;
                    trend = new_trend;
                end
                fc_history(t) = level + trend + seasonal(phase);
            end
            % Forecast
            fc = zeros(1, h);
            for k = 1:h
                phase = mod(n + k - 1, p) + 1;
                fc(k) = level + k*trend + seasonal(phase);
            end
            methodInfo = sprintf('Holt-Winters (alpha=%.2f, beta=%.2f, gamma=%.2f, period=%d)', ...
                alpha, beta, gamma, p);
        otherwise
            error('unknown method: %s (try ma|ets|hw)', method);
    end
    % In-sample RMSE (last 20%)
    testSize = max(1, floor(n*0.2));
    trainY = y(1:end-testSize);
    testY = y(end-testSize+1:end);
    % Use simple mean forecast for in-sample RMSE
    rmse_val = sqrt(mean((testY - mean(trainY)).^2));
    out = struct();
    out.numSamples = n;
    out.horizon = h;
    out.method = methodInfo;
    out.lastObserved = y(end);
    out.forecast = fc;
    out.forecastMean = mean(fc);
    out.inSampleRMSE = rmse_val;
end

function out = act_arima(opts)
    y = read_series(opts);
    n = numel(y);
    p = opts.p; d = opts.d; q = opts.q;
    % Difference
    yd = y;
    for k = 1:d
        yd = diff(yd);
    end
    nd = numel(yd);
    % Fit AR(p) via least squares on lagged values
    if p > 0
        X = zeros(nd - p, p);
        for k = 1:p
            X(:, k) = yd(p - k + 1:nd - k);
        end
        yv = yd(p+1:nd);
        ar_coef = X \ yv;
        resid = yv - X * ar_coef;
    else
        ar_coef = [];
        resid = yd;
    end
    % Estimate MA component via sample autocorrelation of residuals
    if q > 0
        acf_resid = xcorr(resid - mean(resid), q, 'biased');
        ma_acf = acf_resid(q+1:end) / acf_resid(q+1);
    else
        ma_acf = [];
    end
    sigma2 = var(resid);
    out = struct();
    out.numSamples = n;
    out.p = p; out.d = d; out.q = q;
    out.arCoefficients = ar_coef(:)';
    out.residualVariance = sigma2;
    out.aic = n*log(sigma2) + 2*(p+q+1);
    out.bic = n*log(sigma2) + log(n)*(p+q+1);
    out.maACF = ma_acf(:)';
end

function out = act_outlier(opts)
    y = read_series(opts);
    n = numel(y);
    mu = median(y);   % robust
    sigma = mad(y, 1) * 1.4826;   % normalized MAD
    z = (y - mu) / sigma;
    outlierIdx = find(abs(z) > opts.threshold);
    out = struct();
    out.numSamples = n;
    out.center = mu;
    out.scale = sigma;
    out.threshold = opts.threshold;
    out.numOutliers = numel(outlierIdx);
    out.outlierIndices = outlierIdx';
    out.outlierValues = y(outlierIdx)';
    out.outlierZScores = z(outlierIdx)';
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
