function cli_sim(action, varargin)
% CLI_SIM Simulink batch operations for ml CLI
%   CLI: ml sim load    --model vdp
%         ml sim params  --model vdp
%         ml sim run     --model vdp --tfinal 30
%         ml sim outs    --model vdp                  list logged outputs
%         ml sim linearize --model vdp --in 1 --out 1
%         ml sim sweep   --model vdp --param Mu --values "0.5,1,2" --tfinal 20
%         ml sim close   --model vdp
%
%   Options:
%     --model NAME     .slx file name (without extension) or path
%     --tfinal T       simulation end time
%     --param NAME     parameter name for sweep
%     --values "v1,v2,..."  parameter values for sweep
%     --in N --out N   input/output indices for linearization
%     --saveout PATH   save outputs to .mat
%     --format json|table|csv

    if nargin < 1, error('ml sim <action> [options]'); end

    opts = struct('format','json');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--model',    opts.model = varargin{i+1}; i=i+2;
            case '--tfinal',   opts.tfinal = parse_num(varargin{i+1}); i=i+2;
            case '--param',    opts.paramName = varargin{i+1}; i=i+2;
            case '--values',   opts.values = parse_vec(varargin{i+1}); i=i+2;
            case '--in',       opts.inIdx = parse_num(varargin{i+1}); i=i+2;
            case '--out',      opts.outIdx = parse_num(varargin{i+1}); i=i+2;
            case '--saveout',  opts.saveout = varargin{i+1}; i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    if ~license('test','Simulink')
        error('Simulink license required');
    end

    try
        switch lower(action)
            case 'load',      out = act_load(opts);
            case 'params',    out = act_params(opts);
            case 'run',       out = act_run(opts);
            case 'outs',      out = act_outs(opts);
            case 'linearize', out = act_linearize(opts);
            case 'sweep',     out = act_sweep(opts);
            case 'close',     out = act_close(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_load(opts)
    model = resolve_model(opts);
    load_system(model);
    out = struct();
    out.model = bdroot;
    out.loaded = bdIsLoaded(model);
    out.version = get_param(model, 'BlockDiagramType');
    out.solver = get_param(model, 'Solver');
    out.stopTime = get_param(model, 'StopTime');
end

function out = act_params(opts)
    model = resolve_model(opts);
    load_system(model);
    p = get_param(model, 'ObjectParameters');
    % Filter tunable parameters from workspace
    wsVars = evalin('base', 'who');
    tunable = {};
    for k = 1:numel(wsVars)
        v = evalin('base', wsVars{k});
        if isnumeric(v) && isscalar(v)
            tunable{end+1} = wsVars{k}; %#ok<AGROW>
        end
    end
    out = struct();
    out.model = model;
    out.workspaceVariables = tunable;
    out.modelParameters = fieldnames(p);
end

function out = act_run(opts)
    model = resolve_model(opts);
    load_system(model);
    if isfield(opts,'tfinal')
        set_param(model, 'StopTime', num2str(opts.tfinal));
    end
    simOut = sim(model, 'ReturnWorkspaceOutputs', 'on');
    whoNames = simOut.who;
    out = struct();
    out.model = model;
    if isprop(simOut,'tout')
        out.simulationTime = simOut.tout;
        out.numTimePoints = numel(simOut.tout);
    elseif ~isempty(whoNames) && isprop(simOut.(whoNames{1}), 'tout')
        out.simulationTime = simOut.(whoNames{1}).tout;
        out.numTimePoints = numel(simOut.(whoNames{1}).tout);
    end
    out.workspaceOutputs = whoNames;
    if isfield(opts,'saveout')
        save(opts.saveout, 'simOut');
        out.savedTo = opts.saveout;
    end
end

function out = act_outs(opts)
    model = resolve_model(opts);
    load_system(model);
    % Find To Workspace and Scope blocks
    blks = find_system(model, 'Type', 'Block');
    outBlocks = {};
    for k = 1:numel(blks)
        bType = get_param(blks{k}, 'BlockType');
        if ismember(bType, {'ToWorkspace','Scope','ToFile','Outport'})
            outBlocks{end+1} = struct('path', blks{k}, 'type', bType); %#ok<AGROW>
        end
    end
    out = struct();
    out.model = model;
    out.outputBlocks = outBlocks;
end

function out = act_linearize(opts)
    model = resolve_model(opts);
    load_system(model);
    if ~license('test','Simulink_Control_Design')
        error('Simulink Control Design license required for linearize');
    end
    % linearize(model) auto-detects root Inport/Outport blocks
    linsys = linearize(model);
    out = struct();
    out.model = model;
    [num, den] = tfdata(linsys, 'v');
    out.tfNum = num;
    out.tfDen = den;
    out.poles = pole(linsys);
    out.zeros = zero(linsys);
    out.dcGain = dcgain(linsys);
    out.isStable = all(real(pole(linsys)) < 0);
end

function out = act_sweep(opts)
    model = resolve_model(opts);
    load_system(model);
    if ~isfield(opts,'paramName'), error('sweep requires --param NAME'); end
    if ~isfield(opts,'values'), error('sweep requires --values "v1,v2,..."'); end
    if ~isfield(opts,'tfinal'), opts.tfinal = 10; end
    set_param(model, 'StopTime', num2str(opts.tfinal));
    results = cell(numel(opts.values), 1);
    finalValues = zeros(numel(opts.values), 1);
    for k = 1:numel(opts.values)
        % Assign parameter in base workspace then run
        assignin('base', opts.paramName, opts.values(k));
        simOut = sim(model, 'ReturnWorkspaceOutputs', 'on');
        tout = simOut.tout;
        % Get the first non-tout output
        names = simOut.who;
        if ~isempty(names)
            lastSig = simOut.(names{end});
            if isstruct(lastSig) && isfield(lastSig, 'signals')
                vals = lastSig.signals.values;
                finalValues(k) = vals(end);
            elseif isnumeric(lastSig)
                finalValues(k) = lastSig(end);
            end
        end
        results{k} = struct('paramValue', opts.values(k), 'finalOutput', finalValues(k), 'tfinal', tout(end));
    end
    out = struct();
    out.model = model;
    out.paramName = opts.paramName;
    out.tfinal = opts.tfinal;
    out.results = results;
    out.finalValues = finalValues;
end

function out = act_close(opts)
    model = resolve_model(opts);
    if bdIsLoaded(model)
        close_system(model, 0);
        closed = true;
    else
        closed = false;
    end
    out = struct();
    out.model = model;
    out.closed = closed;
end

% =================== Helpers ===================
function model = resolve_model(opts)
    if ~isfield(opts,'model'), error('need --model NAME'); end
    model = opts.model;
    % Strip .slx if present
    if endsWith(model, '.slx') || endsWith(model, '.mdl')
        [~, model, ~] = fileparts(model);
    end
end

function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function v = parse_vec(s)
    if isnumeric(s), v = s; return; end
    s = strtrim(strrep(s, ',', ' '));
    parts = strsplit(s, ' ');
    parts = parts(~cellfun(@isempty, parts));
    v = str2double(parts);
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
