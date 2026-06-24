function cli_fuzzy(action, varargin)
% CLI_FUZZY Fuzzy inference system analysis for ml CLI
%   CLI: ml fuzzy newtip    --name "tipper"
%         ml fuzzy addmf    --name "..." --var service --range "[0 10]" --mf poor:gaussmf:[1.5 0]
%         ml fuzzy addrule  --name "..." --rules "1,1,1,1,1; 2,2,3,1,1"
%         ml fuzzy eval     --name "..." --inputs "0.3,0.7"
%         ml fuzzy info     --name "..."
%         ml fuzzy surface  --name "..." --out surface.png
%
%   Options:
%     --name NAME      FIS name (or .fis file path)
%     --var NAME       variable name
%     --range "[a b]"  universe of discourse
%     --mf SPEC        membership function: "name:type:params"
%     --rules MATRIX   rule matrix (rows separated by ;)
%     --inputs "v1,v2" input values for evaluation
%     --out PATH       output file for plots
%     --format json|table|csv

    if nargin < 1, error('ml fuzzy <action> [options]'); end

    opts = struct('format','json');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--name',    opts.name = varargin{i+1}; i=i+2;
            case '--var',     opts.var = varargin{i+1}; i=i+2;
            case '--range',   opts.range = parse_vec(varargin{i+1}); i=i+2;
            case '--mf',      opts.mf = varargin{i+1}; i=i+2;
            case '--type',    opts.type = varargin{i+1}; i=i+2;
            case '--rules',   opts.rules = varargin{i+1}; i=i+2;
            case '--inputs',  opts.inputs = parse_vec(varargin{i+1}); i=i+2;
            case '--out',     opts.out = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    if ~license('test','Fuzzy_Toolbox')
        error('Fuzzy Logic Toolbox license required');
    end

    try
        switch lower(action)
            case 'newfis',  out = act_newfis(opts);
            case 'addvar',  out = act_addvar(opts);
            case 'addmf',   out = act_addmf(opts);
            case 'addrule', out = act_addrule(opts);
            case 'eval',    out = act_eval(opts);
            case 'info',    out = act_info(opts);
            case 'surface', out = act_surface(opts);
            otherwise,      error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% FIS state is persisted in a temp .mat file keyed by --name.
% To keep CLI stateless across invocations we use a session file.
function fis = load_or_new_fis(opts)
    fname = fis_cache_path(opts);
    if exist(fname, 'file')
        L = load(fname, 'fis');
        fis = L.fis;
    else
        if isfield(opts,'name')
            fis = mamfis('Name', opts.name);
        else
            fis = mamfis('Name', 'fuzzy_cli');
        end
    end
end

function save_fis(fis, opts)
    fname = fis_cache_path(opts);
    save(fname, 'fis');
end

function p = fis_cache_path(opts)
    name = 'default';
    if isfield(opts,'name'), name = opts.name; end
    % sanitize
    name = regexprep(name, '[^A-Za-z0-9_]', '_');
    p = fullfile(tempdir, sprintf('ml_fuzzy_%s.mat', name));
end

% =================== Actions ===================
function out = act_newfis(opts)
    fis = mamfis('Name', opts.name);
    save_fis(fis, opts);
    out = struct();
    out.action = 'newfis';
    out.name = fis.Name;
    out.type = 'mamdani';
    out.numInputs = numel(fis.Inputs);
    out.numOutputs = numel(fis.Outputs);
    out.numRules = numel(fis.Rules);
    out.cacheFile = fis_cache_path(opts);
end

function out = act_addvar(opts)
    if ~isfield(opts,'var'), error('addvar needs --var'); end
    if ~isfield(opts,'range'), error('addvar needs --range "[a b]"'); end
    if ~isfield(opts,'type'), error('addvar needs --type input|output'); end
    fis = load_or_new_fis(opts);
    if strcmpi(opts.type, 'input')
        fis = addInput(fis, opts.range, 'Name', opts.var);
    else
        fis = addOutput(fis, opts.range, 'Name', opts.var);
    end
    save_fis(fis, opts);
    out = struct();
    out.action = 'addvar';
    out.name = opts.var;
    out.type = opts.type;
    out.range = opts.range;
    out.numInputs = numel(fis.Inputs);
    out.numOutputs = numel(fis.Outputs);
end

function out = act_addmf(opts)
    if ~isfield(opts,'var'), error('addmf needs --var'); end
    if ~isfield(opts,'mf'),  error('addmf needs --mf "name:type:[params]"'); end
    fis = load_or_new_fis(opts);
    % parse mf spec: "poor:gaussmf:[1.5 0]"
    parts = strsplit(opts.mf, ':');
    if numel(parts) < 3, error('mf spec must be name:type:[params]'); end
    mfName = strtrim(parts{1});
    mfType = strtrim(parts{2});
    params = parse_vec(strtrim(parts{3}));
    fis = addMF(fis, opts.var, mfType, params, 'Name', mfName);
    save_fis(fis, opts);
    out = struct();
    out.action = 'addmf';
    out.variable = opts.var;
    out.mfName = mfName;
    out.mfType = mfType;
    out.params = params;
end

function out = act_addrule(opts)
    if ~isfield(opts,'rules'), error('addrule needs --rules "matrix rows"'); end
    fis = load_or_new_fis(opts);
    R = parse_rule_matrix(opts.rules);
    numIn = numel(fis.Inputs);
    numOut = numel(fis.Outputs);
    expectedCols = numIn + numOut + 2;
    if size(R,2) ~= expectedCols
        error('rule matrix cols=%d, expected %d (in=%d out=%d +weight +op)', ...
            size(R,2), expectedCols, numIn, numOut);
    end
    % Build text rule descriptions
    ruleTexts = cell(size(R,1),1);
    for k = 1:size(R,1)
        row = R(k,:);
        inMFs = row(1:numIn);
        outMFs = row(numIn+1:numIn+numOut);
        weight = row(numIn+numOut+1);
        opCode = row(numIn+numOut+2);
        connector = ' & '; if opCode == 2, connector = ' | '; end
        % antecedent
        ants = '';
        first = 1;
        for j = 1:numIn
            if inMFs(j) == 0, continue; end  % don't care
            inName = fis.Inputs(j).Name;
            mfName = fis.Inputs(j).MembershipFunctions(inMFs(j)).Name;
            if first, ants = sprintf('%s==%s', inName, mfName); first = 0;
            else, ants = [ants, connector, sprintf('%s==%s', inName, mfName)]; end
        end
        if isempty(ants), ants = '1==1'; end  % always true if all don't-care
        % consequent (use first nonzero output MF)
        conss = '';
        first = 1;
        for j = 1:numOut
            if outMFs(j) == 0, continue; end
            outName = fis.Outputs(j).Name;
            mfName = fis.Outputs(j).MembershipFunctions(outMFs(j)).Name;
            if first, conss = sprintf('%s=%s', outName, mfName); first = 0;
            else, conss = [conss, ', ', sprintf('%s=%s', outName, mfName)]; end
        end
        ruleTexts{k} = sprintf('%s => %s (%g)', ants, conss, weight);
    end
    for k = 1:numel(ruleTexts)
        fis = addRule(fis, ruleTexts{k});
    end
    save_fis(fis, opts);
    out = struct();
    out.action = 'addrule';
    out.numRulesAdded = size(R,1);
    out.totalRules = numel(fis.Rules);
    out.ruleDescriptions = ruleTexts;
end

function out = act_eval(opts)
    if ~isfield(opts,'inputs'), error('eval needs --inputs "v1,v2,..."'); end
    fis = load_or_new_fis(opts);
    if numel(opts.inputs) ~= numel(fis.Inputs)
        error('inputs count=%d, FIS has %d', numel(opts.inputs), numel(fis.Inputs));
    end
    [output, fuzzifiedIn, ruleOuts, aggOut] = evalfis(fis, opts.inputs); %#ok<ASGLU>
    out = struct();
    out.action = 'eval';
    out.inputs = opts.inputs;
    out.output = output;
    out.numOutputs = numel(output);
    out.inputNames = {fis.Inputs.Name};
    out.outputNames = {fis.Outputs.Name};
end

function out = act_info(opts)
    fis = load_or_new_fis(opts);
    out = struct();
    out.name = fis.Name;
    out.type = 'mamdani';
    out.andMethod = fis.AndMethod;
    out.orMethod = fis.OrMethod;
    out.impMethod = fis.ImpMethod;
    out.aggMethod = fis.AggMethod;
    out.defuzzMethod = fis.DefuzzMethod;
    out.numInputs = numel(fis.Inputs);
    out.numOutputs = numel(fis.Outputs);
    out.numRules = numel(fis.Rules);
    inInfo = struct('name',{},'range',{},'numMFs',{});
    for k = 1:numel(fis.Inputs)
        inInfo(k).name = fis.Inputs(k).Name;
        inInfo(k).range = fis.Inputs(k).Range;
        inInfo(k).numMFs = numel(fis.Inputs(k).MembershipFunctions);
    end
    out.inputs = inInfo;
    outInfo = struct('name',{},'range',{},'numMFs',{});
    for k = 1:numel(fis.Outputs)
        outInfo(k).name = fis.Outputs(k).Name;
        outInfo(k).range = fis.Outputs(k).Range;
        outInfo(k).numMFs = numel(fis.Outputs(k).MembershipFunctions);
    end
    out.outputs = outInfo;
end

function out = act_surface(opts)
    fis = load_or_new_fis(opts);
    if ~isfield(opts,'out'), opts.out = '/tmp/fuzzy_surface.png'; end
    fig = figure('Visible','off');
    gensurf(fis);
    exportgraphics(fig, opts.out);
    close(fig);
    out = struct();
    out.action = 'surface';
    out.outputFile = opts.out;
    out.numInputs = numel(fis.Inputs);
end

% =================== Helpers ===================
function idx = find_var(fis, name, kind)
    idx = 0;
    if strcmpi(kind, 'in')
        for k = 1:numel(fis.Inputs)
            if strcmpi(fis.Inputs(k).Name, name), idx = k; return; end
        end
    else
        for k = 1:numel(fis.Outputs)
            if strcmpi(fis.Outputs(k).Name, name), idx = k; return; end
        end
    end
    if idx == 0, error('variable not found: %s', name); end
end

function R = parse_rule_matrix(s)
    % "1,1,1,1,1; 2,2,3,1,1" → numeric matrix
    rows = strsplit(s, ';');
    R = [];
    for k = 1:numel(rows)
        r = parse_vec(strtrim(rows{k}));
        R = [R; r]; %#ok<AGROW>
    end
end

function v = parse_vec(s)
    if isnumeric(s), v = s; return; end
    s = strtrim(s);
    s = strrep(strrep(s, '[',''), ']','');
    s = strrep(s, ',', ' ');
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
