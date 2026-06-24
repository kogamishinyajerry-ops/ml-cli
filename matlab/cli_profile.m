function result = cli_profile(script_path)
% CLI_PROFILE Run MATLAB profiler on a script
%   CLI: ml profile script.m --json
%   Returns timing breakdown for top functions

    if nargin < 1, error('Need script path'); end
    if ~exist(script_path, 'file'), error('File not found: %s', script_path); end

    % Reset and start profiling
    profile clear
    profile on

    try
        [script_dir, script_name] = fileparts(script_path);
        cd(script_dir);
        run(script_name);
    catch ME
        fprintf(2, 'Error during profiling: %s\n', ME.message);
    end

    profile off
    info = profile('info');

    % Extract top functions by time
    ft = info.FunctionTable;
    n_funcs = numel(ft);

    result = struct();
    result.script = script_path;
    result.total_calls = sum([ft.NumCalls]);

    if n_funcs > 0
        result.total_time = ft(1).TotalTime;
    else
        result.total_time = 0;
    end

    top_funcs = {};
    for k = 1:min(n_funcs, 20)
        f = struct();
        f.name = ft(k).FunctionName;
        fn = ft(k).FileName;
        if ~isempty(fn), f.file = strrep(fn, pwd, '.'); else, f.file = ''; end
        f.calls = ft(k).NumCalls;
        f.total_time = ft(k).TotalTime;
        if isfield(ft(k), 'SelfTime')
            f.self_time = ft(k).SelfTime;
        else
            f.self_time = ft(k).TotalTime;
        end
        top_funcs{end+1} = f;
    end
    result.top_functions = {top_funcs};
end
