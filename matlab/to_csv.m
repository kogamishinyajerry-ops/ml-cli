function to_csv(data, varargin)
% TO_CSV 将 MATLAB 数据转为 CSV 并打印到 stdout
%   支持: double(矩阵), table, struct array
%   CLI 出口: ml eval "..." --csv

    try
        s = data_to_csv(data);
        fprintf('%s\n', s);
    catch ME
        fprintf(2, 'to_csv error: %s\n', ME.message);
    end
end

function s = data_to_csv(v)
    switch class(v)
        case 'double'
            if isvector(v)
                s = strjoin(arrayfun(@(x) sprintf('%.15g', x), v, 'UniformOutput', false), ',');
            else
                lines = cell(size(v, 1), 1);
                for i = 1:size(v, 1)
                    lines{i} = strjoin(arrayfun(@(x) sprintf('%.15g', x), v(i,:), 'UniformOutput', false), ',');
                end
                s = strjoin(lines, '\n');
            end
        case 'table'
            varnames = v.Properties.VariableNames;
            header = strjoin(varnames, ',');
            lines = {header};
            for i = 1:height(v)
                row = cell(1, numel(varnames));
                for j = 1:numel(varnames)
                    val = v{i, j};
                    if isnumeric(val) && isscalar(val)
                        row{j} = sprintf('%.15g', val);
                    elseif ischar(val)
                        row{j} = ['"', strrep(val, '"', '""'), '"'];
                    elseif isstring(val)
                        row{j} = ['"', strrep(char(val), '"', '""'), '"'];
                    else
                        row{j} = ['"', mat2str(val), '"'];
                    end
                end
                lines{end+1} = strjoin(row, ',');
            end
            s = strjoin(lines, '\n');
        case 'struct'
            if numel(v) == 1
                fns = fieldnames(v);
                s = strjoin(fns, ',');
                s = [s, '\n'];
                vals = cell(1, numel(fns));
                for j = 1:numel(fns)
                    val = v.(fns{j});
                    if isnumeric(val) && isscalar(val)
                        vals{j} = sprintf('%.15g', val);
                    elseif ischar(val)
                        vals{j} = ['"', strrep(val, '"', '""'), '"'];
                    else
                        vals{j} = ['"', mat2str(val), '"'];
                    end
                end
                s = [s, strjoin(vals, ',')];
            else
                fns = fieldnames(v);
                s = strjoin(fns, ',');
                s = [s, '\n'];
                for i = 1:numel(v)
                    vals = cell(1, numel(fns));
                    for j = 1:numel(fns)
                        val = v(i).(fns{j});
                        if isnumeric(val) && isscalar(val)
                            vals{j} = sprintf('%.15g', val);
                        elseif ischar(val)
                            vals{j} = ['"', strrep(val, '"', '""'), '"'];
                        else
                            vals{j} = ['"', mat2str(val), '"'];
                        end
                    end
                    s = [s, strjoin(vals, ',')];
                    if i < numel(v), s = [s, '\n']; end
                end
            end
        otherwise
            s = mat2str(v);
    end
end
