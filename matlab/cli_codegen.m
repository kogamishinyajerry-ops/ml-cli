function cli_codegen(action, varargin)
% CLI_CODEGEN Code generation CLI for MATLAB Coder
%   CLI: ml codegen analyze  --file fn.m --args "1"
%         ml codegen generate --file fn.m --args "1" --out build/
%         ml codegen build    --file fn.m --args "1" --out build/
%         ml codegen verify   --file fn.m --args "1" --out build/
%
%   Options:
%     --file PATH        input .m file
%     --out PATH         output directory (default: codegen_out/)
%     --args SPEC        input types: "1" scalar, "1,2.5" two scalars,
%                        "matrix(3,3),1" matrix + scalar
%     --lang c|cpp       output language (default c)
%     --format json|table|csv

    if nargin < 1, error('ml codegen <action> [options]'); end

    opts = struct('format','json','lang','c','out','codegen_out');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--file',    opts.file = varargin{i+1}; i=i+2;
            case '--out',     opts.out = varargin{i+1}; i=i+2;
            case '--args',    opts.argsSpec = varargin{i+1}; i=i+2;
            case '--lang',    opts.lang = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    if ~license('test','MATLAB_Coder')
        error('MATLAB Coder license required');
    end

    try
        switch lower(action)
            case 'analyze',   out = act_analyze(opts);
            case 'generate',  out = act_generate(opts);
            case 'build',     out = act_build(opts);
            case 'verify',    out = act_verify(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_analyze(opts)
    f = resolve_file(opts);
    addpath(fileparts(f));
    [~, name, ~] = fileparts(f);
    argTypes = build_args(opts);
    screeningCmd = sprintf('coder.screener(''%s'')', name);
    screeningMsgs = evalc(screeningCmd);
    out = struct();
    out.file = f;
    out.entryPoint = name;
    out.argsDescription = format_args(argTypes);
    out.screeningReport = strtrim(screeningMsgs);
    out.numArgs = numel(argTypes);
end

function [msgs, buildOK, errDetail] = run_codegen(cmd_str, argsCell, cfg)
    % Workaround: codegen -d <outdir> hits ninja path bug on Apple Silicon.
    % Strip -d / -o, build in CWD, caller moves files afterward.
    buildOK = true;
    errDetail = '';
    assignin('base', 'cgArgs__', argsCell);
    assignin('base', 'cgCfg__', cfg);
    cmdStr = strrep(cmd_str, 'argsCell', 'cgArgs__');
    cmdStr = regexprep(cmdStr, ' cfg([,\\)])', ' cgCfg__$1');
    % Remove -d and -o flags
    cmdStr = regexprep(cmdStr, ', ''-d'', ''[^'']+'',?', '');
    cmdStr = regexprep(cmdStr, ', ''-o'', ''[^'']+'',?', '');
    cmdStr = regexprep(cmdStr, ',\\s*$', '');
    tmpScript = [tempname '.m'];
    fid = fopen(tmpScript, 'w');
    fprintf(fid, 'cgArgs__ = evalin(''base'', ''cgArgs__'');\n');
    fprintf(fid, 'cgCfg__ = evalin(''base'', ''cgCfg__'');\n');
    fprintf(fid, 'try\n');
    fprintf(fid, '  msgs__ = evalc(''%s'');\n', strrep(cmdStr, '''', ''''''));
    fprintf(fid, '  assignin(''base'', ''cgMsgs__'', msgs__);\n');
    fprintf(fid, '  assignin(''base'', ''cgOK__'', 1);\n');
    fprintf(fid, 'catch ME\n');
    fprintf(fid, '  assignin(''base'', ''cgMsgs__'', ME.message);\n');
    fprintf(fid, '  assignin(''base'', ''cgOK__'', 0);\n');
    fprintf(fid, 'end\n');
    fclose(fid);
    run(tmpScript);
    msgs = evalin('base', 'cgMsgs__');
    buildOK = logical(evalin('base', 'cgOK__'));
    if ~buildOK, errDetail = msgs; end
    delete(tmpScript);
end

function tf = compiler_configured()
    tf = false;
    try
        cfg = mex.getCompilerConfigurations;
        tf = ~isempty(cfg);
    catch
        tf = false;
    end
end

function out = act_generate(opts)
    f = resolve_file(opts);
    addpath(fileparts(f));
    [~, name, ~] = fileparts(f);
    outDir = opts.out;
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    cfg = coder.config('lib');
    cfg.GenerateReport = true;
    if strcmpi(opts.lang, 'cpp'), cfg.TargetLang = 'C++'; else, cfg.TargetLang = 'C'; end
    argTypes = build_args(opts);
    argsCell = {argTypes{:}};
    cmd = sprintf('codegen(''%s'', ''-args'', argsCell, ''-config'', cfg, ''-d'', ''%s'')', name, outDir);
    [msgs, buildOK, errDetail] = run_codegen(cmd, argsCell, cfg);
    out = struct();
    out.action = 'generate';
    out.file = f;
    out.entryPoint = name;
    out.outputDir = outDir;
    out.language = upper(opts.lang);
    out.codegenMessages = strtrim(msgs);
    out.buildOK = buildOK;
    out.compilerConfigured = compiler_configured();
    if ~out.compilerConfigured && ~buildOK
        out.note = 'No C compiler configured. Install Xcode CLT: xcode-select --install';
    end
    files = list_generated(outDir);
    out.generatedFiles = files;
    out.numFiles = numel(files);
end

function out = act_build(opts)
    f = resolve_file(opts);
    addpath(fileparts(f));
    [~, name, ~] = fileparts(f);
    outDir = opts.out;
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    cfg = coder.config('mex');
    cfg.GenerateReport = true;
    argTypes = build_args(opts);
    argsCell = {argTypes{:}};
    % Build in CWD (workaround for -d bug), then move MEX to outDir
    cmd = sprintf('codegen(''%s'', ''-args'', argsCell, ''-config'', cfg)', name);
    workDir = pwd;
    [msgs, buildOK] = run_codegen(cmd, argsCell, cfg);
    % MEX file is placed in codegen's build subdir, not CWD. Find it.
    mexFound = '';
    candidatePaths = { ...
        fullfile(workDir, [name '_mex.', mexext]), ...
        fullfile(workDir, 'codegen', 'mex', name, [name '_mex.', mexext]), ...
        fullfile(tempdir, [name '_mex.', mexext]) };
    for k = 1:numel(candidatePaths)
        if exist(candidatePaths{k}, 'file')
            mexFound = candidatePaths{k};
            break;
        end
    end
    % Also search codegen/ folder for any _mex.mexext
    if isempty(mexFound)
        cgRoot = fullfile(workDir, 'codegen');
        if exist(cgRoot, 'dir')
            hits = dir(fullfile(cgRoot, ['**' filesep '*' name '_mex.' mexext]));
            if ~isempty(hits), mexFound = fullfile(hits(1).folder, hits(1).name); end
        end
    end
    if ~isempty(mexFound)
        copyfile(mexFound, fullfile(outDir, [name '_mex.', mexext]));
    end
    out = struct();
    out.action = 'build';
    out.file = f;
    out.mexName = name;
    out.outputDir = outDir;
    out.codegenMessages = strtrim(msgs);
    out.buildOK = buildOK;
    fullMex = fullfile(outDir, [name '_mex.', mexext]);
    out.mexExists = exist(fullMex, 'file') == 3;
    out.mexPath = fullMex;
    out.compilerConfigured = compiler_configured();
    if ~out.compilerConfigured && ~buildOK
        out.note = 'No C compiler. Install Xcode CLT: xcode-select --install';
    end
end

function out = act_verify(opts)
    f = resolve_file(opts);
    addpath(fileparts(f));
    [~, name, ~] = fileparts(f);
    outDir = opts.out;
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    cfg = coder.config('mex');
    cfg.GenerateReport = false;
    argTypes = build_args(opts);
    argsCell = {argTypes{:}};
    mexOutName = fullfile(outDir, name);
    cmd = sprintf('codegen(''%s'', ''-args'', argsCell, ''-config'', cfg, ''-o'', ''%s'', ''-d'', ''%s'')', ...
        name, mexOutName, outDir);
    [msgs, buildOK] = run_codegen(cmd, argsCell, cfg);
    out = struct();
    out.action = 'verify';
    out.file = f;
    out.outputDir = outDir;
    out.buildSucceeded = buildOK;
    if ~buildOK
        out.codegenMessages = strtrim(msgs);
        out.compilerConfigured = compiler_configured();
        if ~out.compilerConfigured
            out.note = 'MEX build failed (likely no C compiler). Install Xcode CLT: xcode-select --install';
        end
        return;
    end
    addpath(outDir);
    testInputs = build_test_inputs(opts);
    out.numTestCases = numel(testInputs);
    mlResults = cell(numel(testInputs), 1);
    mexResults = cell(numel(testInputs), 1);
    maxDiff = zeros(numel(testInputs), 1);
    for k = 1:numel(testInputs)
        argsStr = inputs_to_call_str(testInputs{k});
        mlRes = evalin('base', sprintf('%s(%s)', name, argsStr));
        mexRes = evalin('base', sprintf('%s_mex(%s)', name, argsStr));
        mlResults{k} = mlRes;
        mexResults{k} = mexRes;
        if isnumeric(mlRes) && isnumeric(mexRes)
            maxDiff(k) = max(abs(double(mlRes(:)) - double(mexRes(:))));
        end
    end
    out.maxDiffPerTestCase = maxDiff;
    out.toleranceMet = all(maxDiff < 1e-10);
    out.meanMaxDiff = mean(maxDiff);
    out.mlResults = mlResults;
    out.mexResults = mexResults;
end

% =================== Argument types ===================
function argTypes = build_args(opts)
    if ~isfield(opts, 'argsSpec')
        argTypes = {};
        return;
    end
    specs = parse_arg_list(opts.argsSpec);
    argTypes = cell(1, numel(specs));
    for k = 1:numel(specs)
        s = specs{k};
        if strcmp(s, 'scalar') || strcmp(s, '1')
            argTypes{k} = coder.typeof(0);
        elseif startsWith(s, 'matrix(')
            inner = s(8:end-1);
            dims = str2double(strsplit(inner, ','));
            argTypes{k} = coder.typeof(zeros(dims(1), dims(2)));
        elseif startsWith(s, 'vector(')
            inner = s(8:end-1);
            n = str2double(inner);
            argTypes{k} = coder.typeof(zeros(1, n));
        else
            argTypes{k} = coder.typeof(0);
        end
    end
end

function inputs = build_test_inputs(opts)
    if ~isfield(opts, 'argsSpec'), inputs = {0}; return; end
    specs = parse_arg_list(opts.argsSpec);
    inputs = cell(1, numel(specs));
    for k = 1:numel(specs)
        s = specs{k};
        if strcmp(s, 'scalar') || strcmp(s, '1')
            inputs{k} = 1.5;
        elseif startsWith(s, 'matrix(')
            inner = s(8:end-1);
            dims = str2double(strsplit(inner, ','));
            inputs{k} = rand(dims(1), dims(2));
        elseif startsWith(s, 'vector(')
            inner = s(8:end-1);
            n = str2double(inner);
            inputs{k} = 1:n;
        else
            inputs{k} = 1.5;
        end
    end
end

function specs = parse_arg_list(s)
    specs = {};
    depth = 0; start = 1;
    for k = 1:numel(s)
        c = s(k);
        if c == '(', depth = depth + 1;
        elseif c == ')', depth = depth - 1;
        elseif c == ',' && depth == 0
            specs{end+1} = strtrim(s(start:k-1)); %#ok<AGROW>
            start = k + 1;
        end
    end
    if start <= numel(s)
        specs{end+1} = strtrim(s(start:end));
    end
end

function s = encode_args(argTypes)
    % Returns ", args{1}, args{2}, ..." style string
    if isempty(argTypes), s = ''; return; end
    parts = cell(1, numel(argTypes));
    for k = 1:numel(argTypes)
        parts{k} = sprintf('args{%d}', k);
    end
    s = [', ' strjoin(parts, ', ')];
end

function s = inputs_to_call_str(inputs)
    parts = cell(1, numel(inputs));
    for k = 1:numel(inputs)
        v = inputs{k};
        if isnumeric(v)
            parts{k} = mat2str(v);
        else
            parts{k} = sprintf('"%s"', v);
        end
    end
    s = strjoin(parts, ', ');
end

function desc = format_args(argTypes)
    if isempty(argTypes), desc = ''; return; end
    parts = cell(1, numel(argTypes));
    for k = 1:numel(argTypes)
        try
            parts{k} = sprintf('arg%d: %s', k, argTypes{k}.ClassString);
        catch
            parts{k} = sprintf('arg%d: <type>', k);
        end
    end
    desc = strjoin(parts, '; ');
end

function f = resolve_file(opts)
    if ~isfield(opts,'file'), error('need --file PATH.m'); end
    f = opts.file;
    if ~exist(f, 'file'), error('file not found: %s', f); end
end

function files = list_generated(dirPath)
    files = {};
    try
        d = dir(dirPath);
        for k = 1:numel(d)
            if ~d(k).isdir
                files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
            end
        end
        % Look into html/ subfolder for report
        htmlDir = fullfile(dirPath, 'html');
        if exist(htmlDir, 'dir')
            dh = dir(htmlDir);
            for k = 1:numel(dh)
                if ~dh(k).isdir
                    files{end+1} = fullfile(dh(k).folder, dh(k).name); %#ok<AGROW>
                end
            end
        end
    catch
    end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
