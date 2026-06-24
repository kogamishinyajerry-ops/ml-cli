function result = cli_stats(data_path)
% CLI_STATS 描述性统计分析
%   CLI: ml stats data.csv --json
%         ml stats data.csv --full (all stats)
%   返回: struct with n, mean, median, std, min, max, skew, kurt, quantiles

    if nargin < 1 || isempty(data_path)
        error('Need data file path');
    end

    try
        data = readmatrix(data_path);
    catch
        % Try with header
        try
            data = readmatrix(data_path, 'NumHeaderLines', 1);
        catch ME
            error('Cannot read file: %s', ME.message);
        end
    end

    [n_rows, n_cols] = size(data);
    result = struct();
    result.n = n_rows;
    result.n_cols = n_cols;
    result.columns = {};

    for c = 1:n_cols
        col = data(:, c);
        col = col(~isnan(col) & ~isinf(col));
        if isempty(col)
            result.columns{c} = struct('count', 0, 'mean', NaN, 'median', NaN);
            continue;
        end

        stats_c = struct();
        stats_c.count = numel(col);
        stats_c.mean = mean(col);
        stats_c.median = median(col);
        stats_c.std = std(col);
        stats_c.min = min(col);
        stats_c.max = max(col);
        stats_c.range = max(col) - min(col);
        stats_c.iqr = iqr(col);
        stats_c.var = var(col);
        stats_c.skewness = skewness(col);
        stats_c.kurtosis = kurtosis(col);
        stats_c.q25 = prctile(col, 25);
        stats_c.q75 = prctile(col, 75);
        stats_c.q90 = prctile(col, 90);

        result.columns{c} = stats_c;
    end

    % Correlation matrix (only if multiple columns and valid data)
    if n_cols > 1
        try
            valid_rows = all(~isnan(data) & ~isinf(data), 2);
            if sum(valid_rows) >= 3
                result.correlation = corrcoef(data(valid_rows, :));
            end
        catch
            % Skip if correlation fails
        end
    end
end
