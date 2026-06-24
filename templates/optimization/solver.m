%% {{NAME}} — Optimization Template
% 自动生成 by ml template optimization
% 日期: {{DATE}}

clear; clc;

%% 1. Define optimization problem
% Objective function: f(x) = ...
function fval = objective(x)
    % Example: Rosenbrock function
    fval = 100*(x(2) - x(1)^2)^2 + (1 - x(1))^2;
end

% Constraints (optional)
function [c, ceq] = constraints(x)
    % c(x) <= 0  (inequality)
    % ceq(x) = 0  (equality)
    c = [];       % no inequality constraints
    ceq = [];     % no equality constraints
end

%% 2. Unconstrained optimization
fprintf('=== Unconstrained Optimization ===\n');
x0 = [-1.2; 1.0];  % initial guess

options = optimoptions('fminunc', ...
    'Display', 'iter', ...
    'Algorithm', 'quasi-newton', ...
    'OptimalityTolerance', 1e-9);

[x_opt, fval_opt, exitflag, output] = fminunc(@objective, x0, options);

fprintf('\nResults:\n');
fprintf('  x* = [%.6f, %.6f]\n', x_opt(1), x_opt(2));
fprintf('  f* = %.12f\n', fval_opt);
fprintf('  Iterations: %d\n', output.iterations);
fprintf('  Exit flag: %d\n', exitflag);

%% 3. Constrained optimization (if constraints exist)
fprintf('\n=== Constrained Optimization ===\n');
if isempty(which('constraints') == which('main'))
    fprintf('  No constraints defined. Skipping.\n');
else
    [x_con, fval_con] = fmincon(@objective, x0, [], [], [], [], ...
        [-5; -5], [5; 5], @constraints, options);
    fprintf('  Constrained x* = [%.6f, %.6f]\n', x_con(1), x_con(2));
    fprintf('  Constrained f* = %.12f\n', fval_con);
end

%% 4. Global optimization (for multimodal problems)
fprintf('\n=== Global Optimization ===\n');
if exist('MultiStart', 'class')
    problem = createOptimProblem('fminunc', 'x0', x0, 'objective', @objective);
    ms = MultiStart('Display', 'off');
    [x_global, fval_global] = run(ms, problem, 10);
    fprintf('  Global x* = [%.6f, %.6f]\n', x_global(1), x_global(2));
    fprintf('  Global f* = %.12f\n', fval_global);
else
    fprintf('  Global Optimization Toolbox not available.\n');
end

fprintf('\nOptimization complete.\n');
