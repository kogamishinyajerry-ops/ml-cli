function result = cli_optimize(problem)
% CLI_OPTIMIZE 通用优化求解器
%   CLI: ml optimize "2*(x-1)^2 + (y-3)^2" --x0 0,0
%         ml optimize --rosenbrock --x0 -1,2
%   返回: struct with x_opt, fval, exitflag, iterations

    if nargin < 1, problem = 'default'; end

    switch lower(problem)
        case 'rosenbrock'
            obj = @(x) 100*(x(2)-x(1)^2)^2 + (1-x(1))^2;
            x0 = [-1.2; 1.0];
            method = 'fminunc';
        case 'himmelblau'
            obj = @(x) (x(1)^2+x(2)-11)^2 + (x(1)+x(2)^2-7)^2;
            x0 = [0; 0];
            method = 'fminunc';
        case 'beale'
            obj = @(x) (1.5-x(1)*(1-x(2)))^2 + (2.25-x(1)*(1-x(2)^2))^2 ...
                     + (2.625-x(1)*(1-x(2)^3))^2;
            x0 = [1; 1];
            method = 'fminunc';
        case 'default'
            obj = @(x) (1-x(1))^2 + 100*(x(2)-x(1)^2)^2;
            x0 = [-1.2; 1.0];
            method = 'fminunc';
        otherwise
            error('Unknown problem: %s. Use: rosenbrock, himmelblau, beale, or default', problem);
    end

    options = optimoptions(method, 'Display', 'off', 'Algorithm', 'quasi-newton');
    [x_opt, fval, exitflag, output] = fminunc(obj, x0, options);

    result = struct();
    result.method = method;
    result.problem = problem;
    result.x_opt = x_opt';
    result.fval = fval;
    result.exitflag = exitflag;
    result.iterations = output.iterations;
    result.func_count = output.funcCount;
    result.first_order_opt = output.firstorderopt;
end
