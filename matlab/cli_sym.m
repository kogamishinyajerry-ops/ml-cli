function result = cli_sym(op, expr, varargin)
% CLI_SYM Symbolic math operations for ml CLI
%   CLI: ml sym diff "x^2"
%         ml sym int "x^2" --at 0 1
%         ml sym solve "x^2-4=0"
%         ml sym simplify "sin(x)^2+cos(x)^2"
%         ml sym laplace "exp(-t)"
%         ml sym taylor "exp(x)" --order 5
%         ml sym limit "sin(x)/x" --at 0
%         ml sym expand "(x+1)^3"
%         ml sym factor "x^3-1"
%         ml sym latex "exp(-x^2)"
%         ml sym matrix "det [[a,b];[c,d]]"

    if nargin < 2, error('ml sym <op> <expression>'); end

    % Parse options
    opts = struct();
    i = 1;
    while i <= numel(varargin)
        switch varargin{i}
            case '--at',   opts.at = varargin{i+1}; i = i + 2;
            case '--order'
                if isnumeric(varargin{i+1})
                    opts.order = varargin{i+1};
                else
                    opts.order = str2double(varargin{i+1});
                end
                i = i + 2;
            case '--var',  opts.var = varargin{i+1}; i = i + 2;
            case '--point', opts.point = str2double(varargin{i+1}); i = i + 2;
            otherwise, i = i + 1;
        end
    end

    % Default variable: detect from expression or use 'x' (skip for matrix/eval ops)
    if ~isfield(opts, 'var') && ~ismember(lower(op), {'matrix', 'eval'})
        try
            v = symvar(str2sym(expr));
        catch
            v = [];
        end
        opts.var = 'x';
        if ~isempty(v), opts.var = char(v(1)); end
    end

    switch lower(op)
        case 'diff'
            result = sym_diff(expr, opts);
        case 'int'
            result = sym_int(expr, opts);
        case 'solve'
            result = sym_solve(expr, opts);
        case 'simplify'
            result = sym_simplify(expr);
        case 'expand'
            result = sym_expand(expr);
        case 'factor'
            result = sym_factor(expr);
        case 'laplace'
            result = sym_laplace(expr, opts);
        case 'limit'
            result = sym_limit(expr, opts);
        case 'taylor'
            result = sym_taylor(expr, opts);
        case 'latex'
            result = sym_latex(expr);
        case 'matrix'
            result = sym_matrix(expr, opts);
        case 'eval'
            result = sym_eval(expr);
        otherwise
            error('Unknown op: %s. Try: diff int solve simplify expand factor laplace taylor limit latex matrix eval', op);
    end
end

% ─── Individual operations ──────────────────────────────

function r = sym_diff(expr, opts)
    x = sym(opts.var);
    f = str2sym(expr);
    df = diff(f, x);
    r = struct('operation', 'diff', 'input', expr, 'output', char(df), 'variable', opts.var);
    if isfield(opts, 'order')
        dnf = diff(f, x, opts.order);
        r.higher_order = char(dnf);
    end
end

function r = sym_int(expr, opts)
    x = sym(opts.var);
    f = str2sym(expr);
    if isfield(opts, 'at') && numel(opts.at) >= 2
        F = int(f, x, opts.at(1), opts.at(end));
        definite = true;
    else
        F = int(f, x);
        definite = false;
    end
    r = struct('operation', 'int', 'input', expr, 'output', char(F), 'variable', opts.var, 'definite', definite);
end

function r = sym_solve(expr, opts)
    eqn = str2sym(expr);
    x = sym(opts.var);
    sol = solve(eqn, x);
    sol_str = cell(size(sol));
    for k = 1:numel(sol)
        sol_str{k} = char(sol(k));
    end
    r = struct('operation', 'solve', 'input', expr, 'variable', opts.var, 'solutions', {sol_str}, 'n_solutions', numel(sol));
end

function r = sym_simplify(expr)
    f = str2sym(expr);
    s = simplify(f);
    steps = simplify(f, 'Steps', 50);
    r = struct('operation', 'simplify', 'input', expr, 'output', char(s));
    if ~strcmp(char(s), char(steps)), r.further_simplified = char(steps); end
end

function r = sym_expand(expr)
    f = str2sym(expr);
    e = expand(f);
    r = struct('operation', 'expand', 'input', expr, 'output', char(e));
end

function r = sym_factor(expr)
    f = str2sym(expr);
    fac = factor(f);
    r = struct('operation', 'factor', 'input', expr, 'output', char(fac));
end

function r = sym_laplace(expr, opts)
    t = sym(opts.var);
    s = sym('s');
    f = str2sym(expr);
    L = laplace(f, t, s);
    r = struct('operation', 'laplace', 'input', expr, 'variable', opts.var, 'output', char(L), 'domain', 's');
end

function r = sym_limit(expr, opts)
    x = sym(opts.var);
    f = str2sym(expr);
    if isfield(opts, 'at')
        L = limit(f, x, opts.at);
    else
        L = limit(f, x, 0);
    end
    r = struct('operation', 'limit', 'input', expr, 'variable', opts.var, 'at', opts.at, 'output', char(L));
end

function r = sym_taylor(expr, opts)
    x = sym(opts.var);         % 先创建符号变量
    f = str2sym(expr);         % 再解析表达式(引用已存在的 x)
    order_val = 5;
    if isfield(opts, 'order') && ~isempty(opts.order)
        order_val = round(abs(double(opts.order(1))));
        if order_val < 1, order_val = 1; end
        if order_val > 20, order_val = 20; end
    end
    T = taylor(f, x, 'Order', order_val + 1);
    r = struct('operation', 'taylor', 'input', expr, 'variable', opts.var, 'order', order_val, 'output', char(T));
end

function r = sym_latex(expr)
    f = str2sym(expr);
    L = latex(f);
    r = struct('operation', 'latex', 'input', expr, 'output', L);
end

function r = sym_eval(expr)
    f = str2sym(expr);
    v = double(f);
    r = struct('operation', 'eval', 'input', expr, 'numeric', v);
end

function r = sym_matrix(expr, opts)
    parts = strsplit(strtrim(expr));
    matrix_op = parts{1};
    matrix_str = strjoin(parts(2:end));

    % Convert [[a,b];[c,d]] → [a b; c d]
    matrix_str = strrep(matrix_str, '[[', '[');
    matrix_str = strrep(matrix_str, ']]', ']');
    matrix_str = strrep(matrix_str, ',', ' ');     % commas → spaces
    matrix_str = strrep(matrix_str, '];[', ';');   % merge inner row boundaries
    matrix_str = strrep(matrix_str, '][', ';');    % alternate inner boundary

    % Strip outer brackets to get clean row-content
    matrix_core = regexprep(matrix_str, '^\[|\]$', '');
    if isempty(matrix_core)
        error('Cannot parse matrix: empty after cleanup');
    end

    % Detect variables, create syms (or use eval for numeric-only)
    tokens = regexp(matrix_core, '[a-zA-Z_][a-zA-Z_0-9]*', 'match');
    known = {'det','inv','eig','rank','trace','charpoly','sin','cos','exp','log','sqrt','abs','sign','diff','int','i','j','pi','inf'};

    if isempty(tokens) || all(cellfun(@(t)~isnan(str2double(t)), tokens))
        % Pure numeric — use eval to create double matrix
        M = eval(['[', matrix_core, '];']);
    else
        % Symbolic — create vars first
        var_names = unique(tokens);
        var_names = setdiff(var_names, known);
        for k = 1:numel(var_names)
            eval([var_names{k}, ' = sym(''', var_names{k}, ''');']);
        end
        M = eval(['[', matrix_core, '];']);
    end

    switch matrix_op
        case 'det'
            out = det(M);
            out_str = fmt_result(out);
        case 'inv'
            out = inv(M);
            out_str = fmt_result(out);
        case 'eig'
            out_val = eig(M);
            if isnumeric(out_val)
                out_str = strjoin(cellstr(num2str(out_val(:),'%.4f')), ', ');
            else
                out_str = char(join(string(out_val), ', '));
            end
        case 'rank'
            out = rank(M);
            out_str = num2str(out);
        case 'trace'
            out = trace(M);
            out_str = fmt_result(out);
        case 'charpoly'
            x = sym('x');
            out = charpoly(M, x);
            out_str = char(out);
        otherwise
            error('Unknown matrix op: %s', matrix_op);
    end
    r = struct('operation', ['matrix_' matrix_op], 'input', matrix_str, 'output', out_str);
end

% ─── Helper ────────────────────────────────────────────────
function s = fmt_result(val)
    if isnumeric(val)
        if isscalar(val)
            s = num2str(val, '%.8g');
        elseif ismatrix(val) && size(val,1) <= 4 && size(val,2) <= 4
            rows = cell(size(val,1), 1);
            for r = 1:size(val,1)
                rows{r} = strjoin(cellstr(num2str(val(r,:),'%.4f')), ', ');
            end
            s = ['[' strjoin(rows, '; ') ']'];
        else
            s = mat2str(val, 4);
        end
    else
        s = char(val);
    end
end
