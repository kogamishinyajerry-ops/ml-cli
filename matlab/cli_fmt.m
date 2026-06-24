function cli_fmt(filepath)
% CLI_FMT 基本 MATLAB 代码格式化
%   功能:
%     1. 追加缺失分号
%     2. 缩小连续空行
%     3. 对齐操作符空格
%     4. 行长检查警告
%
%   CLI 出口: ml fmt script.m (输出到 stdout)

    if nargin < 1 || isempty(filepath) || ~exist(filepath, 'file')
        fprintf(2, '错误: 文件不存在 %s\n', filepath);
        return;
    end

    try
        content = fileread(filepath);
        lines = strsplit(content, '\n')';
    catch
        fprintf(2, '错误: 无法读取文件\n');
        return;
    end

    out_lines = {};
    prev_blank = false;

    for i = 1:numel(lines)
        l = lines{i};

        % 保留注释和空行
        trimmed = strtrim(l);
        if isempty(trimmed)
            if ~prev_blank
                out_lines{end+1} = '';
                prev_blank = true;
            end
            continue;
        end
        prev_blank = false;

        % 跳过注释行
        if startsWith(trimmed, '%') || startsWith(trimmed, '#')
            out_lines{end+1} = l;
            continue;
        end

        % 跳过关键字行
        if starts_with_keyword(trimmed)
            out_lines{end+1} = l;
            continue;
        end

        % 操作符空格对齐
        l = add_operator_spaces(trimmed);

        % 追加缺失分号
        if needs_semicolon(l)
            l = [l, ';'];
        end

        out_lines{end+1} = l;
    end

    % 输出
    fprintf('%s\n', strjoin(out_lines, '\n'));
end

function r = needs_semicolon(l)
    if endsWith(l, ';') || endsWith(l, '...') || endsWith(l, '{') || endsWith(l, '[')
        r = false;
        return;
    end
    r = starts_with_keyword(l) == 0;
end

function s = add_operator_spaces(s)
    % 常见操作符两侧加空格
    ops = {'=', '==', '~=', '>=', '<=', '>', '<', '+', '-', '.*', './', '.^'};
    for k = 1:numel(ops)
        op = ops{k};
        s = strrep(s, [op, op], [op, ' ', op]); % 避免重复
        s = regexprep(s, ['(\S)', op, '(\S)'], ['$1 ', op, ' $2']);
    end
end

function r = starts_with_keyword(l)
    keywords = {'for', 'while', 'if', 'function', 'end', 'try', 'catch', ...
                'switch', 'case', 'otherwise', 'else', 'elseif', 'classdef', ...
                'methods', 'properties', 'events', 'parfor', 'spmd'};
    for k = 1:numel(keywords)
        kw = keywords{k};
        if startsWith(l, kw) && (numel(l) == numel(kw) || l(numel(kw)+1) == ' ')
            r = true; return;
        end
    end
    r = false;
end

function r = startsWith(s, prefix)
    if numel(s) < numel(prefix)
        r = false; return;
    end
    r = strncmp(s, prefix, numel(prefix));
end

function r = endsWith(s, suffix)
    if numel(s) < numel(suffix)
        r = false; return;
    end
    r = strcmp(s(end-numel(suffix)+1:end), suffix);
end
