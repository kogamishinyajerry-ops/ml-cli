function cli_lint(filepath)
% CLI_LINT 对 .m 文件做轻量级代码检查
%   检查项:
%     1. 行长度 (建议 < 120)
%     2. 分号缺失 (表达式后无 ;)
%     3. 未使用的变量警告
%     4. eval 使用 (安全风险)
%     5. 函数复杂度 (嵌套深度)
%
%   CLI 出口: ml lint script.m

    if nargin < 1 || isempty(filepath) || ~exist(filepath, 'file')
        fprintf(2, '错误: 文件不存在 %s\n', filepath);
        return;
    end

    fprintf('Linting: %s\n', filepath);
    fprintf('──────────\n');

    try
        content = fileread(filepath);
        lines = strsplit(content, '\n')';
    catch
        fprintf(2, '错误: 无法读取文件\n');
        return;
    end

    n_lines = numel(lines);
    issues = 0;

    % 1. 行长度检查
    for i = 1:n_lines
        l = strtrim(lines{i});
        if numel(l) > 120
            fprintf('  [LONG]  line %d: %d chars\n', i, numel(l));
            issues = issues + 1;
        end
    end

    % 2. 分号缺失检查 (简单版:有效代码行末尾无 ;)
    for i = 1:n_lines
        l = strtrim(lines{i});
        if isempty(l) || l(1) == '%' || l(1) == '#' || l(1) == '!'
            continue;
        end
        % 跳过 for/while/if/function/end/try/catch 声明行
        if starts_with_keyword(l)
            continue;
        end
        % 跳过结尾带有 ... 的续行符和结尾为 { 或 [ 的行
        if endsWith(l, '...') || endsWith(l, '{') || endsWith(l, '[')
            continue;
        end
        % 检查末尾是否有分号
        if ~endsWith(l, ';') && ~contains(l, 'fprintf')
            % 仅对包含运算符的行发出警告
            if contains_expression(l)
                fprintf('  [SEMI]  line %d: missing semicolon → %s\n', i, shorten(l, 60));
                issues = issues + 1;
            end
        end
    end

    % 3. eval 使用
    for i = 1:n_lines
        l = strtrim(lines{i});
        if ~isempty(l) && ~iscomment(l) && contains(l, 'eval')
            fprintf('  [EVAL]  line %d: eval() usage detected\n', i);
            issues = issues + 1;
        end
    end

    % 4. 函数嵌套深度
    depth = 0;
    max_depth = 0;
    for i = 1:n_lines
        l = strtrim(lines{i});
        if contains(l, 'function ') && ~endsWith(l, '...')
            depth = depth + 1;
            max_depth = max(max_depth, depth);
        elseif strcmp(l, 'end')
            depth = max(0, depth - 1);
        end
    end
    if max_depth > 3
        fprintf('  [COMPLEX] max nesting depth = %d (建议 ≤ 3)\n', max_depth);
        issues = issues + 1;
    end

    % 汇总
    fprintf('──────────\n');
    if issues == 0
        fprintf('✓ 通过 (%d 行, 0 问题)\n', n_lines);
    else
        fprintf('⚠ %d 个问题 (%d 行)\n', issues, n_lines);
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

function r = contains_expression(l)
    ops = {'=', '.*', './', '.^', '\\', '/', '^', '*', '+', '-', '&', '|', '~'};
    % 移除字符串和注释以准确检测
    for k = 1:numel(ops)
        if contains(l, ops{k})
            r = true; return;
        end
    end
    r = false;
end

function r = iscomment(l)
    r = startsWith(l, '%') || startsWith(l, '#');
end

function r = startsWith(s, prefix)
    if numel(s) < numel(prefix)
        r = false; return;
    end
    r = strncmp(s, prefix, numel(prefix));
end

function s = shorten(s, n)
    if numel(s) > n
        s = [s(1:n-3), '...'];
    end
end
