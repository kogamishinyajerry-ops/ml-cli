function cli_dnn(action, varargin)
% CLI_DNN Deep learning inference for ml CLI
%   CLI: ml dnn list                      list pretrained networks
%         ml dnn predict --net resnet18 --image img.jpg
%         ml dnn predict --net googlenet --image cat.png --top 5
%         ml dnn layers --net resnet18    inspect layer dimensions
%         ml dnn import --onnx model.onnx --save mynet.mat
%         ml dnn classify --net resnet18 --features "f1,f2,..."  (tabular)
%
%   Options:
%     --net NAME       pretrained: resnet18/50, googlenet, squeezenet,
%                      vgg16/19, mobilenetv2, inceptionv3, alexnet
%     --image PATH     image file for prediction
%     --top N          top-N class predictions (default 5)
%     --onnx PATH      ONNX model file to import
%     --save PATH      save imported model to .mat
%     --features "..." comma-list of numeric features for tabular models
%     --format json|table|csv

    if nargin < 1, error('ml dnn <action> [options]'); end

    opts = struct('format','json','top',5);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--net',       opts.net = varargin{i+1}; i=i+2;
            case '--image',     opts.image = varargin{i+1}; i=i+2;
            case '--top',       opts.top = round(parse_num(varargin{i+1})); i=i+2;
            case '--onnx',      opts.onnx = varargin{i+1}; i=i+2;
            case '--save',      opts.save = varargin{i+1}; i=i+2;
            case '--features',  opts.features = parse_vec(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    if ~exist('dlnetwork','class')
        error('Deep Learning Toolbox not available');
    end

    try
        switch lower(action)
            case 'list',     out = act_list();
            case 'predict',  out = act_predict(opts);
            case 'layers',   out = act_layers(opts);
            case 'import',   out = act_import(opts);
            case 'classify', out = act_classify(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_list()
    % Supported pretrained networks in Deep Learning Toolbox
    names = {'resnet18','resnet50','resnet101','googlenet','squeezenet', ...
             'vgg16','vgg19','mobilenetv2','inceptionv3','inceptionresnetv2', ...
             'alexnet','densenet201','efficientnetb0','shufflenet'};
    sizes = [44.7 98 167.1 26.7 4.8 515 548 13.5 23.8 55.9 227 69 20 9.2];
    tasks = repmat({'imageClassification'}, 1, numel(names));
    % Filter to ones actually available (support package installed)
    available = false(1, numel(names));
    for k = 1:numel(names)
        available(k) = check_support(names{k});
    end
    out = struct();
    out.network = names;
    out.sizeMB = sizes;
    out.task = tasks;
    out.supportPackageInstalled = available;
    out.numAvailable = sum(available);
end

function tf = check_support(name)
    tf = false;
    try
        switch name
            case 'alexnet',        tf = ~isempty(which('alexnet'));
            case 'resnet18',       tf = exist('nnet.cnn.pretrained.Resnet18', 'dir') == 7;
            otherwise
                % Try checking via the support package file
                tf = ~isempty(which(name));
        end
    catch
        tf = false;
    end
end

function out = act_predict(opts)
    if ~isfield(opts,'net'), error('predict requires --net NAME'); end
    if ~isfield(opts,'image'), error('predict requires --image PATH'); end
    img = imread(opts.image);
    net = load_pretrained(opts.net);
    inputSize = net.Layers(1).InputSize;
    img = preprocess_image(img, inputSize, opts.net);
    % Try classify with labels (works if support pkg installed)
    labels = {};
    scores = [];
    pretrainedUsed = false;
    try
        [labels, scores] = classify(net, img);
        pretrainedUsed = true;
    catch ME
        % Untrained network: skip prediction, report layer info instead
        warning('network has no pretrained weights — prediction skipped: %s', ME.message);
        out = struct();
        out.network = opts.net;
        out.imageFile = opts.image;
        out.pretrainedWeightsAvailable = false;
        out.errorMessage = 'Pretrained weights support package not installed. Install via MATLAB Add-Ons.';
        out.numLayers = numel(net.Layers);
        out.inputSize = net.Layers(1).InputSize;
        return;
    end
    if ~isempty(scores)
        [scores_sorted, idx] = sort(scores, 'descend');
    else
        scores_sorted = [];
        idx = 1:numel(labels);
    end
    topN = min(opts.top, numel(idx));
    out = struct();
    out.network = opts.net;
    out.imageFile = opts.image;
    out.inputSize = inputSize;
    out.numClasses = numel(labels);
    out.pretrainedWeightsUsed = pretrainedUsed;
    out.topPredictions = cell(topN, 1);
    out.topScores = zeros(topN, 1);
    for k = 1:topN
        if ~isempty(labels)
            out.topPredictions{k} = char(labels(idx(k)));
        else
            out.topPredictions{k} = sprintf('class_%d', idx(k)-1);
        end
        out.topScores(k) = scores_sorted(k);
    end
    out.topN = topN;
end

function out = act_layers(opts)
    if ~isfield(opts,'net'), error('layers requires --net NAME'); end
    net = load_pretrained(opts.net);
    L = net.Layers;
    names = cell(numel(L), 1);
    types = cell(numel(L), 1);
    sizes = cell(numel(L), 1);
    for k = 1:numel(L)
        names{k} = L(k).Name;
        types{k} = class(L(k));
        try
            if isprop(L(k), 'InputSize')
                sizes{k} = mat2str(L(k).InputSize);
            elseif isprop(L(k), 'OutputSize')
                sizes{k} = mat2str(L(k).OutputSize);
            elseif isprop(L(k), 'NumFilters')
                sizes{k} = sprintf('%d filters', L(k).NumFilters);
            else
                sizes{k} = '-';
            end
        catch
            sizes{k} = '-';
        end
    end
    out = struct();
    out.network = opts.net;
    out.numLayers = numel(L);
    out.layerNames = names;
    out.layerTypes = types;
    out.layerSizes = sizes;
end

function out = act_import(opts)
    if ~isfield(opts,'onnx'), error('import requires --onnx PATH'); end
    if ~license('test','Deep_Learning_Toolbox_Converter_for_ONNX_Model_Format')
        error('ONNX support package required (Deep Learning Toolbox Converter for ONNX Model Format)');
    end
    net = importNetworkFromONNX(opts.onnx);
    info = struct();
    info.numLayers = numel(net.Layers);
    info.inputSize = net.Layers(1).InputSize;
    if ~isfield(opts,'save')
        [~, name, ~] = fileparts(opts.onnx);
        opts.save = fullfile(tempdir, [name '.mat']);
    end
    save(opts.save, 'net');
    out = struct();
    out.action = 'import';
    out.onnxFile = opts.onnx;
    out.numLayers = numel(net.Layers);
    out.savedTo = opts.save;
end

function out = act_classify(opts)
    if ~isfield(opts,'features'), error('classify requires --features "f1,f2,..."'); end
    if ~isfield(opts,'net'), error('classify requires --net NAME'); end
    % Load a pretrained tabular classifier (if available)
    % Otherwise train on-the-fly is out of scope; require a saved model
    error('tabular classify requires a saved model: use fitcensemble or load saved .mat');
end

% =================== Helpers ===================
function net = load_pretrained(name)
    % Try with pretrained weights; fall back to untrained if support pkg missing
    try
        net = eval(sprintf('%s()', lower(name)));
    catch
        try
            net = eval(sprintf('%s(''Weights'',''none'')', lower(name)));
            warning('pretrained weights support package not installed for %s — using untrained', name);
        catch ME
            error('failed to load network %s: %s', name, ME.message);
        end
    end
end

function img = preprocess_image(img, inputSize, netName)
    % Resize to network's input size
    if numel(inputSize) == 3
        % HxWxC
        h = inputSize(1); w = inputSize(2);
    elseif numel(inputSize) == 4
        % HxWxCxN (batch) — just take first
        h = inputSize(1); w = inputSize(2);
    else
        h = 224; w = 224;
    end
    img = imresize(img, [h w]);
    % Some networks need RGB swap or normalization
    % For simplicity use the network's own preprocessing when possible
    if size(img,3) == 1
        img = cat(3, img, img, img);  % grayscale → RGB
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
