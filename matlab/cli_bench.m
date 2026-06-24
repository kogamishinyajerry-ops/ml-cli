function cli_bench(fmt)
% CLI_BENCH 运行 MATLAB 性能基准测试
%   CLI 出口: ml bench [--json|--table]
%   测试项:
%     1. 矩阵乘法 (1000x1000)
%     2. FFT (1M 点)
%     3. 线性求解 (1000x1000)
%     4. SVD (500x500)
%     5. 元素操作 (1M 元素)
%     6. 循环 (1M 迭代)

    if nargin < 1, fmt = 'text'; end

    results = [];
    fprintf('Running MATLAB CLI Benchmark...\n\n');

    function t = timeit_n(f, n)
        % 运行 n 次取平均值
        tt = zeros(n, 1);
        for k = 1:n
            tic;
            f();
            tt(k) = toc;
        end
        t = mean(tt) * 1000; % ms
    end

    % 1. 矩阵乘法
    A = rand(1000);
    t = timeit_n(@() A * A, 5);
    results.(genvarname('matrix_multiply_1k')) = t;

    % 2. FFT
    x = rand(1e6, 1);
    t = timeit_n(@() fft(x), 5);
    results.(genvarname('fft_1M')) = t;

    % 3. 线性求解
    A = rand(1000);
    b = rand(1000, 1);
    t = timeit_n(@() A \ b, 5);
    results.(genvarname('linear_solve_1k')) = t;

    % 4. SVD
    A = rand(500);
    t = timeit_n(@() svd(A), 3);
    results.(genvarname('svd_500')) = t;

    % 5. 元素操作
    x = rand(1e6, 1);
    t = timeit_n(@() sin(x).*cos(x) + exp(-x), 10);
    results.(genvarname('elem_ops_1M')) = t;

    % 6. 循环
    t = timeit_n(@() for_loop_bench(), 5);
    results.(genvarname('for_loop_1M')) = t;

    % 输出
    switch fmt
        case 'json'
            jsonify(results);
        case 'table'
            % Convert to table
            fns = fieldnames(results);
            test_name = fns;
            time_ms = zeros(numel(fns), 1);
            for i = 1:numel(fns)
                time_ms(i) = results.(fns{i});
            end
            T = table(test_name, time_ms);
            to_table(T);
        otherwise
            fns = fieldnames(results);
            fprintf('%-30s %8s\n', 'Test', 'Time (ms)');
            fprintf('%-30s %8s\n', '────', '────────');
            for i = 1:numel(fns)
                fprintf('%-30s %8.2f\n', fns{i}, results.(fns{i}));
            end
    end
end

function for_loop_bench()
    s = 0;
    for i = 1:1e6
        s = s + sqrt(i);
    end
end
