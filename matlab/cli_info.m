function cli_info(fmt)
% CLI_INFO 入口: ml info [--json|--table]
%   本函数作为主入口,调用同文件内的本地函数
%   使用方式: ml info --json / ml info --table / ml info

    if nargin < 1, fmt = 'text'; end

    switch fmt
        case 'json'
            cli_info_json_impl();
        case 'table'
            cli_info_table_impl();
        otherwise
            cli_info_text_impl();
    end
end

% ─── 内部实现 ──────────────────────────────────

function cli_info_text_impl()
    fprintf('MATLAB Version:     %s\n', version);
    fprintf('Release:            %s\n', version('-release'));
    fprintf('Computer:           %s\n', computer);
    fprintf('Architecture:       %s\n', computer('arch'));
    fprintf('Max Threads:        %d\n', maxNumCompThreads);
    fprintf('\n');
    v = ver;
    fprintf('Toolboxes (%d installed):\n', numel(v));
    for i = 1:numel(v)
        tag = tern(strncmp(v(i).Name, 'MATLAB', 6), 'CORE', 'TOOL');
        fprintf('  [%s] %s v%s\n', tag, v(i).Name, v(i).Version);
    end
end

function cli_info_json_impl()
    info = struct();
    info.version = version;
    info.release = version('-release');
    info.computer = computer;
    info.arch = computer('arch');
    info.max_threads = maxNumCompThreads;
    v = ver;
    tbs = cell(numel(v), 1);
    for i = 1:numel(v)
        tbs{i} = struct('name', v(i).Name, 'version', v(i).Version);
    end
    info.toolboxes = {tbs};
    info.matlab_root = matlabroot;
    jsonify(info);
end

function cli_info_table_impl()
    info = struct();
    info.version = version;
    info.release = version('-release');
    info.computer = computer;
    info.arch = computer('arch');
    info.max_threads = maxNumCompThreads;
    info.matlab_root = matlabroot;
    to_table(info);
end

function r = tern(cond, a, b)
    if cond, r = a; else, r = b; end
end
