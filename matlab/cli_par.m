function result = cli_par(action, varargin)
% CLI_PAR Parallel Computing Toolbox operations for ml CLI
%   ml par --info        → show parallel pool status
%   ml par --bench       → benchmark parallel vs serial
%   ml par --workers N   → run expression with N workers
%   ml par --gpu         → show GPU info

    if nargin < 1, action = 'info'; end

    switch lower(action)
        case 'info'
            result = par_info();
        case 'bench'
            result = par_benchmark();
        case 'gpu'
            result = gpu_info();
        case 'workers'
            result = par_workers(varargin{:});
        otherwise
            error('Unknown action: %s. Use: info, bench, gpu, workers', action);
    end
end

function r = par_info()
    r = struct();
    r.max_workers = maxNumCompThreads;
    r.parallel_toolbox = license('test','Distrib_Computing_Toolbox');

    try
        pool = gcp('nocreate');
        if isempty(pool)
            r.pool_active = false;
            r.pool_workers = 0;
        else
            r.pool_active = true;
            r.pool_workers = pool.NumWorkers;
        end
    catch
        r.pool_active = false;
        r.pool_workers = 0;
    end

    r.computer = computer;
    r.arch = computer('arch');
    r.num_cores = feature('numcores');
end

function r = gpu_info()
    r = struct();
    r.available = false;
    try
        g = gpuDevice;
        r.available = true;
        r.name = g.Name;
        r.total_memory_gb = g.TotalMemory / 1e9;
        r.free_memory_gb = g.AvailableMemory / 1e9;
        r.compute_capability = g.ComputeCapability;
        r.multiprocessor_count = g.MultiprocessorCount;
    catch
    end
end

function r = par_benchmark()
    r = struct();
    n = 2000;

    % Matrix multiplication benchmark
    A = rand(n);
    B = rand(n);

    % Serial
    tic; C_serial = A * B; t_serial = toc;

    % Parallel (if available)
    t_parallel = NaN;
    r.parallel_available = false;
    try
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('local', min(4, maxNumCompThreads));
        end
        tic;
        spmd
            C_par = A * B;
        end
        t_parallel = toc;
        r.parallel_available = true;
        r.workers_used = pool.NumWorkers;
    catch
    end

    r.matrix_size = n;
    r.serial_time_ms = t_serial * 1000;
    r.parallel_time_ms = t_parallel * 1000;
    r.speedup = t_serial / t_parallel;
    r.efficiency = r.speedup / r.workers_used * 100;

    % FFT benchmark
    x = rand(1e6, 1);
    tic; fft(x); r.fft_serial_ms = toc * 1000;

    % GPU FFT (if available)
    r.gpu_fft_ms = NaN;
    try
        g = gpuDevice;
        x_gpu = gpuArray(x);
        tic; fft(x_gpu); r.gpu_fft_ms = toc * 1000;
    catch
    end
end

function r = par_workers(n_workers)
    r = struct();
    r.requested_workers = n_workers;
    try
        pool = gcp('nocreate');
        if ~isempty(pool), delete(pool); end
        pool = parpool('local', n_workers);
        r.pool_active = true;
        r.actual_workers = pool.NumWorkers;
        r.start_time = datestr(now);
    catch ME
        r.pool_active = false;
        r.error = ME.message;
    end
end
