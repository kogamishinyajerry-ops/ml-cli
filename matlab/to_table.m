function to_table(data, varargin)
% TO_TABLE 将 MATLAB 数据转为 Markdown 表格并打印到 stdout
%   支持: double(矩阵), table, struct array
%   用法:
%     to_table(result)                       % 自动格式化
%     to_table(x, 'precision', 4)            % 指定小数位
%     to_table(table, 'all', true)           % 显示所有行
%
%   CLI 出口: ml eval "..." --table

    p = inputParser;
    p.addParameter('precision', 6, @isnumeric);
    p.addParameter('all', false, @islogical);
    p.parse(varargin{:});
    opts = p.Results;

    try
        s = data_to_md(data, opts);
        fprintf('%s\n', s);
    catch ME
        fprintf(2, 'to_table error: %s\n', ME.message);
    end
end

function s = data_to_md(v, opts)
    switch class(v)
        case 'double'
            s = matrix_to_md(v, opts);
        case 'table'
            s = table_to_md(v, opts);
        case 'struct'
            s = struct_to_md(v, opts);
        case 'cell'
            s = cell_to_md(v, opts);
        otherwise
            s = sprintf('| Value |\n|-------|\n| %s |\n', mat2str(v));
    end
end

function s = matrix_to_md(v, opts)
    if isvector(v)
        if iscolumn(v), v = v'; end
        % 向量作为单行
        header = '';
        sep = '';
        row = '|';
        for j = 1:numel(v)
            header = [header, sprintf('| c%d ', j)];
            sep = [sep, '|------'];
            row = [row, sprintf(' %.*g |', opts.precision, v(j))];
        end
        header = [header, '|'];
        sep = [sep, '|'];
        s = sprintf('%s\n%s\n%s\n', header, sep, row);
    else
        % 矩阵: 行号 + 列
        header = '| row \\ col |';
        sep = '|----------|';
        for j = 1:size(v, 2)
            header = [header, sprintf(' c%d |', j)];
            sep = [sep, '-------|'];
        end
        lines = {header, sep};
        for i = 1:size(v, 1)
            row = sprintf('| %d |', i);
            for j = 1:size(v, 2)
                row = [row, sprintf(' %.*g |', opts.precision, v(i,j))];
            end
            lines{end+1} = row;
        end
        s = strjoin(lines, '\n');
    end
end

function s = table_to_md(v, opts)
    varnames = v.Properties.VariableNames;
    n_cols = numel(varnames);
    n_rows = height(v);

    % header
    header = '|';
    sep = '|';
    for j = 1:n_cols
        header = [header, sprintf(' %s |', varnames{j})];
        sep = [sep, '-------|'];
    end

    lines = {header, sep};

    % rows (限制显示前 20 行)
    show_rows = min(n_rows, tern(opts.all, n_rows, 20));
    for i = 1:show_rows
        row = '|';
        for j = 1:n_cols
            val = v{i, j};
            if isnumeric(val) && isscalar(val)
                row = [row, sprintf(' %.*g |', opts.precision, val)];
            elseif isstring(val) || ischar(val)
                row = [row, sprintf(' %s |', char(val))];
            elseif iscategorical(val)
                row = [row, sprintf(' %s |', char(val))];
            else
                row = [row, sprintf(' %s |', mat2str(val, 3))];
            end
        end
        lines{end+1} = row;
    end

    if show_rows < n_rows
        lines{end+1} = sprintf('| ... (%d more rows) |', n_rows - show_rows);
    end

    s = strjoin(lines, '\n');
end

function s = struct_to_md(v, opts)
    fns = fieldnames(v);
    header = '| Field | Value |';
    sep = '|-------|-------|';
    lines = {header, sep};
    for i = 1:numel(fns)
        fn = fns{i};
        val = v.(fn);
        if isnumeric(val) && isscalar(val)
            valstr = sprintf('%.*g', opts.precision, val);
        elseif ischar(val)
            valstr = val;
        elseif isstring(val)
            valstr = char(val);
        else
            valstr = mat2str(val, 3);
        end
        lines{end+1} = sprintf('| %s | %s |', fn, valstr);
    end
    s = strjoin(lines, '\n');
end

function s = cell_to_md(v, opts)
    header = '| Index | Value |';
    sep = '|-------|-------|';
    lines = {header, sep};
    show = min(numel(v), tern(opts.all, numel(v), 20));
    for i = 1:show
        val = v{i};
        if isnumeric(val) && isscalar(val)
            valstr = sprintf('%.*g', opts.precision, val);
        elseif ischar(val)
            valstr = val;
        elseif isstring(val)
            valstr = char(val);
        else
            valstr = mat2str(val, 3);
        end
        lines{end+1} = sprintf('| %d | %s |', i, valstr);
    end
    s = strjoin(lines, '\n');
end

function r = tern(cond, a, b)
    if cond, r = a; else, r = b; end
end
