function jsonify(data, varargin)
% JSONIFY 将 MATLAB 数据转为规范 JSON 并打印到 stdout
%   支持: double(标量/向量/矩阵), cell, struct, table, string, char
%   用法:
%     jsonify(result)                        % 压缩 JSON
%     jsonify(x, 'format', 'pretty')         % 美化 JSON
%     jsonify(table_data, 'rows', true)      % table 按行输出
%
%   CLI 出口: ml eval "..." --json

    p = inputParser;
    p.addParameter('format', 'compact', @(x) ismember(x, {'compact','pretty'}));
    p.addParameter('rows', false, @islogical);
    p.parse(varargin{:});
    opts = p.Results;

    try
        s = value_to_json(data, opts);
        fprintf('%s\n', s);
    catch ME
        fprintf(2, 'jsonify error: %s\n', ME.message);
    end
end

function s = value_to_json(v, opts)
    switch class(v)
        case 'double'
            s = matrix_to_json(v);
        case 'single'
            s = matrix_to_json(double(v));
        case 'int8'
            s = num2str(v);
        case 'int16'
            s = num2str(v);
        case 'int32'
            s = num2str(v);
        case 'int64'
            s = num2str(v);
        case 'char'
            s = ['"', escape_str(v), '"'];
        case 'string'
            if isscalar(v)
                s = ['"', escape_str(char(v)), '"'];
            else
                s = cell_to_json(cellstr(v));
            end
        case 'cell'
            s = cell_to_json(v);
        case 'struct'
            s = struct_to_json(v, opts);
        case 'table'
            s = table_to_json(v, opts);
        case 'logical'
            if v, s = 'true'; else, s = 'false'; end
        case 'categorical'
            if isscalar(v)
                s = ['"', escape_str(char(v)), '"'];
            else
                s = cell_to_json(cellstr(v));
            end
        otherwise
            s = ['"<', class(v), '>"'];
    end
end

function s = matrix_to_json(v)
    if isscalar(v)
        if isfinite(v)
            s = sprintf('%.15g', v);
        elseif isnan(v)
            s = 'null';
        elseif isinf(v) && v > 0
            s = '1e308';
        else
            s = '-1e308';
        end
    elseif isvector(v)
        s = '[';
        for i = 1:numel(v)
            if i > 1, s = [s, ',']; end
            if isfinite(v(i))
                s = [s, sprintf('%.15g', v(i))];
            else
                s = [s, 'null'];
            end
        end
        s = [s, ']'];
    else
        % 矩阵按行输出
        s = '[';
        for i = 1:size(v, 1)
            if i > 1, s = [s, ',']; end
            s = [s, '['];
            for j = 1:size(v, 2)
                if j > 1, s = [s, ',']; end
                if isfinite(v(i,j))
                    s = [s, sprintf('%.15g', v(i,j))];
                else
                    s = [s, 'null'];
                end
            end
            s = [s, ']'];
        end
        s = [s, ']'];
    end
end

function s = cell_to_json(v)
    s = '[';
    for i = 1:numel(v)
        if i > 1, s = [s, ',']; end
        s = [s, value_to_json(v{i}, struct())];
    end
    s = [s, ']'];
end

function s = struct_to_json(v, opts)
    fns = fieldnames(v);
    if numel(v) == 1
        s = '{';
        first = true;
        for i = 1:numel(fns)
            fn = fns{i};
            val = v.(fn);
            if ~first, s = [s, ',']; end
            first = false;
            s = [s, '"', fn, '":', value_to_json(val, opts)];
        end
        s = [s, '}'];
    else
        % struct 数组
        s = '[';
        for j = 1:numel(v)
            if j > 1, s = [s, ',']; end
            s = [s, '{'];
            first = true;
            for i = 1:numel(fns)
                fn = fns{i};
                val = v(j).(fn);
                if ~first, s = [s, ',']; end
                first = false;
                s = [s, '"', fn, '":', value_to_json(val, opts)];
            end
            s = [s, '}'];
        end
        s = [s, ']'];
    end
end

function s = table_to_json(v, opts)
    s = '[';
    varnames = v.Properties.VariableNames;
    for row = 1:height(v)
        if row > 1, s = [s, ',']; end
        s = [s, '{'];
        for col = 1:numel(varnames)
            if col > 1, s = [s, ',']; end
            s = [s, '"', varnames{col}, '":', ...
                 value_to_json(v{row, col}, opts)];
        end
        s = [s, '}'];
    end
    s = [s, ']'];
end

function s = escape_str(s)
    s = strrep(s, '\', '\\');
    s = strrep(s, '"', '\"');
    s = strrep(s, sprintf('\n'), '\n');
    s = strrep(s, sprintf('\r'), '\r');
    s = strrep(s, sprintf('\t'), '\t');
end
