function cli_ml(action, varargin)
% CLI_ML Machine learning for ml CLI
%   CLI: ml ml classify   <data.csv> --target label --method tree
%         ml ml regress   <data.csv> --target y --method svm
%         ml ml cluster   <data.csv> --k 3
%         ml ml pca       <data.csv> --components 2
%         ml ml split     <data.csv> --ratio 0.8
%         ml ml train     <data.csv> --target label --method forest --save model.mat
%         ml ml predict   model.mat <new.csv> --out preds.csv
%         ml ml cv        <data.csv> --target label --method knn --folds 5
%         ml ml features  <data.csv>                          # rank by importance
%
%   Options:
%     --target COL    target column name (or index)
%     --method NAME   tree|forest|svm|knn|nb|linear|logistic
%     --k N           cluster count for kmeans
%     --components N  PCA components
%     --ratio R       train/test split ratio (default 0.8)
%     --folds N       cross-validation folds (default 5)
%     --save PATH     save trained model
%     --out PATH      output file
%     --format json|table|csv

    if nargin < 1, error('ml ml <action> [options]'); end

    opts = struct('format','json','target','','method','tree', ...
                  'k',3,'components',2,'ratio',0.8,'folds',5, ...
                  'save','','out','','file','','file2','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--target',     opts.target = varargin{i+1}; i=i+2;
            case '--method',     opts.method = varargin{i+1}; i=i+2;
            case '--k',          opts.k = round(parse_num(varargin{i+1})); i=i+2;
            case '--components', opts.components = round(parse_num(varargin{i+1})); i=i+2;
            case '--ratio',      opts.ratio = parse_num(varargin{i+1}); i=i+2;
            case '--folds',      opts.folds = round(parse_num(varargin{i+1})); i=i+2;
            case '--save',       opts.save = varargin{i+1}; i=i+2;
            case '--out',        opts.out = varargin{i+1}; i=i+2;
            case '--format',     opts.format = varargin{i+1}; i=i+2;
            otherwise,            if isempty(opts.file), opts.file = tok; ...
                                  elseif isempty(opts.file2), opts.file2 = tok; end, i=i+1;
        end
    end

    try
        switch lower(action)
            case 'classify',  out = act_classify(opts);
            case 'regress',   out = act_regress(opts);
            case 'cluster',   out = act_cluster(opts);
            case 'pca',       out = act_pca(opts);
            case 'split',     out = act_split(opts);
            case 'train',     out = act_train(opts);
            case 'predict',   out = act_predict(opts);
            case 'cv',        out = act_cv(opts);
            case 'features',  out = act_features(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Load CSV with header ===================
function [X, y, colNames, targetIdx] = load_data(opts)
    if isempty(opts.file), error('data file required'); end
    [data, colNames] = read_csv_with_header(opts.file);
    if isempty(opts.target)
        targetIdx = size(data, 2);  % default: last column
    elseif isnumeric_str(opts.target)
        targetIdx = round(str2double(opts.target));
    else
        targetIdx = find(strcmpi(colNames, opts.target), 1);
        if isempty(targetIdx), error('target column not found: %s', opts.target); end
    end
    y = data(:, targetIdx);
    X = data(:, setdiff(1:size(data,2), targetIdx));
    featureNames = colNames(setdiff(1:size(data,2), targetIdx));
    colNames = featureNames;  % return only features
end

function [data, colNames] = read_csv_with_header(file)
    % Read header
    fid = fopen(file, 'r');
    if fid < 0, error('cannot open file: %s', file); end
    cleanup = onCleanup(@() fclose(fid));
    headerLine = fgetl(fid);
    fclose(fid);
    colNames = strsplit(strtrim(headerLine), ',');
    % Read data (skip header row)
    try
        data = readmatrix(file);
    catch
        data = csvread(file, 1, 0);
    end
    % Drop NaN rows from header parse if readmatrix included header
    if size(data, 1) > 1 && any(~isfinite(data(1, :)))
        data(1, :) = [];
    end
end

function tf = isnumeric_str(s)
    if isnumeric(s), tf = true; return; end
    tf = ~isnan(str2double(s));
end

% =================== Generic model builder ===================
function mdl = build_classifier(X, y, method)
    switch lower(method)
        case 'tree',     mdl = fitctree(X, y);
        case 'forest',   mdl = fitcensemble(X, y, 'Method', 'Bag');
        case 'svm',      mdl = fitcsvm(X, y);
        case 'knn',      mdl = fitcknn(X, y);
        case 'nb',       mdl = fitcnb(X, y);
        case 'logistic', mdl = fitclinear(X, y, 'Learner', 'logistic');
        otherwise,       error('unknown classifier method: %s', method);
    end
end

function mdl = build_regressor(X, y, method)
    switch lower(method)
        case 'tree',     mdl = fitrtree(X, y);
        case 'forest',   mdl = fitrensemble(X, y);
        case 'svm',      mdl = fitrsvm(X, y);
        case 'linear',   mdl = fitrlinear(X, y);
        case 'gp',       mdl = fitrgp(X, y);
        otherwise,       error('unknown regressor method: %s', method);
    end
end

% =================== Actions ===================
function out = act_classify(opts)
    [X, y, ~, ~] = load_data(opts);
    n = size(X, 1);
    splitIdx = round(opts.ratio * n);
    Xtr = X(1:splitIdx, :); ytr = y(1:splitIdx);
    Xte = X(splitIdx+1:end, :); yte = y(splitIdx+1:end);
    mdl = build_classifier(Xtr, ytr, opts.method);
    yhat = predict(mdl, Xte);
    acc = mean(yhat == yte);
    cm = confusionmat(yte, yhat);
    out = struct();
    out.method = opts.method;
    out.numFeatures = size(X, 2);
    out.numTrainSamples = size(Xtr, 1);
    out.numTestSamples = size(Xte, 1);
    out.accuracy = acc;
    out.classes = mdl.ClassNames;
    out.confusionMatrix = cm;
    if isfield(opts, 'save') && ~isempty(opts.save)
        save(opts.save, 'mdl');
        out.modelFile = opts.save;
    end
end

function out = act_regress(opts)
    [X, y, ~, ~] = load_data(opts);
    n = size(X, 1);
    splitIdx = round(opts.ratio * n);
    Xtr = X(1:splitIdx, :); ytr = y(1:splitIdx);
    Xte = X(splitIdx+1:end, :); yte = y(splitIdx+1:end);
    mdl = build_regressor(Xtr, ytr, opts.method);
    yhat = predict(mdl, Xte);
    rmse_val = sqrt(mean((yhat - yte).^2));
    mae_val = mean(abs(yhat - yte));
    r2 = 1 - sum((yte - yhat).^2) / sum((yte - mean(yte)).^2);
    out = struct();
    out.method = opts.method;
    out.numFeatures = size(X, 2);
    out.numTrainSamples = size(Xtr, 1);
    out.numTestSamples = size(Xte, 1);
    out.RMSE = rmse_val;
    out.MAE = mae_val;
    out.R2 = r2;
    if isfield(opts, 'save') && ~isempty(opts.save)
        save(opts.save, 'mdl');
        out.modelFile = opts.save;
    end
end

function out = act_cluster(opts)
    [X, ~, colNames, ~] = load_data_with_optional_target(opts);
    k = opts.k;
    idx = kmeans(X, k);
    % Silhouette (requires Statistics Toolbox)
    silh = silhouette(X, idx);
    out = struct();
    out.method = 'kmeans';
    out.k = k;
    out.numSamples = size(X, 1);
    out.clusterAssignments = idx';
    out.meanSilhouette = mean(silh(~isnan(silh)));
    % Cluster sizes
    sizes = zeros(k, 1);
    for c = 1:k, sizes(c) = sum(idx == c); end
    out.clusterSizes = sizes;
    % Centroids
    centroids = zeros(k, size(X, 2));
    for c = 1:k
        centroids(c, :) = mean(X(idx == c, :), 1);
    end
    out.centroids = centroids;
    if ~isempty(colNames)
        out.featureNames = colNames;
    end
end

function [X, y, colNames, targetIdx] = load_data_with_optional_target(opts)
    [data, colNames] = read_csv_with_header(opts.file);
    targetIdx = [];
    y = [];
    if ~isempty(opts.target)
        if isnumeric_str(opts.target)
            targetIdx = round(str2double(opts.target));
        else
            targetIdx = find(strcmpi(colNames, opts.target), 1);
        end
    end
    if ~isempty(targetIdx)
        y = data(:, targetIdx);
        X = data(:, setdiff(1:size(data,2), targetIdx));
        colNames = colNames(setdiff(1:size(data,2), targetIdx));
    else
        X = data;
    end
end

function out = act_pca(opts)
    [X, ~, colNames] = load_data_with_optional_target(opts);
    [coeff, score, latent, ~, explained, mu] = pca(X);
    k = opts.components;
    out = struct();
    out.numSamples = size(X, 1);
    out.numFeatures = size(X, 2);
    out.numComponents = k;
    out.explained = explained(1:k);
    out.cumulativeExplained = cumsum(explained(1:k));
    out.eigenvalues = latent(1:k);
    out.featureMeans = mu';
    out.coefficients = coeff(:, 1:k);
    out.scores = score(:, 1:k);
    if ~isempty(colNames), out.featureNames = colNames; end
end

function out = act_split(opts)
    [data, colNames] = read_csv_with_header(opts.file);
    n = size(data, 1);
    perm = randperm(n);
    splitIdx = round(opts.ratio * n);
    trainIdx = perm(1:splitIdx);
    testIdx = perm(splitIdx+1:end);
    % Write output files
    baseFile = opts.file;
    [pathPart, namePart, extPart] = fileparts(baseFile);
    trainFile = fullfile(pathPart, [namePart '_train' extPart]);
    testFile = fullfile(pathPart, [namePart '_test' extPart]);
    write_csv_with_header(trainFile, data(trainIdx, :), colNames);
    write_csv_with_header(testFile, data(testIdx, :), colNames);
    out = struct();
    out.inputFile = opts.file;
    out.ratio = opts.ratio;
    out.trainFile = trainFile;
    out.testFile = testFile;
    out.numTrainSamples = numel(trainIdx);
    out.numTestSamples = numel(testIdx);
end

function write_csv_with_header(file, data, colNames)
    fid = fopen(file, 'w');
    if fid < 0, error('cannot write: %s', file); end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(colNames, ','));
    for k = 1:size(data, 1)
        fprintf(fid, '%.10g%s\n', data(k, 1), ...
            strjoin(arrayfun(@(x) sprintf(',%.10g', x), data(k, 2:end), 'UniformOutput', false), ''));
    end
end

function out = act_train(opts)
    [X, y, colNames, ~] = load_data(opts);
    mdl = build_classifier(X, y, opts.method);
    resubAcc = mean(resubPredict(mdl) == y);
    out = struct();
    out.method = opts.method;
    out.numFeatures = size(X, 2);
    out.numSamples = size(X, 1);
    out.classes = mdl.ClassNames;
    out.resubstitutionAccuracy = resubAcc;
    if ~isempty(colNames), out.featureNames = colNames; end
    if isfield(opts, 'save') && ~isempty(opts.save)
        save(opts.save, 'mdl');
        out.modelFile = opts.save;
    else
        % Default save location
        defaultFile = '/tmp/ml_model.mat';
        save(defaultFile, 'mdl');
        out.modelFile = defaultFile;
    end
end

function out = act_predict(opts)
    if isempty(opts.file), error('model file required'); end
    if isempty(opts.file2), error('data file required (as second positional arg)'); end
    loaded = load(opts.file);
    if ~isfield(loaded, 'mdl'), error('model file has no mdl variable'); end
    mdl = loaded.mdl;
    [data, colNames] = read_csv_with_header(opts.file2);
    % Truncate to expected predictor count
    expectedPredictors = size(mdl.X, 2);
    if ~isempty(mdl) && isprop(mdl, 'PredictorNames') && ~isempty(mdl.PredictorNames)
        % Use predictor names if available
        selIdx = [];
        for pn = mdl.PredictorNames(:)'
            idx = find(strcmpi(colNames, char(pn)), 1);
            if ~isempty(idx), selIdx(end+1) = idx; end
        end
        if numel(selIdx) == expectedPredictors
            data = data(:, selIdx);
        end
    end
    if size(data, 2) > expectedPredictors
        data = data(:, 1:expectedPredictors);
    end
    yhat = predict(mdl, data);
    out = struct();
    out.modelFile = opts.file;
    out.dataFile = opts.file2;
    out.numSamples = size(data, 1);
    out.predictions = yhat(:)';
    if isfield(opts, 'out') && ~isempty(opts.out)
        predTable = [data, yhat(:)];
        predNames = {colNames{1:expectedPredictors}, 'prediction'};
        write_csv_with_header(opts.out, predTable, predNames);
        out.outputFile = opts.out;
    end
end

function out = act_cv(opts)
    [X, y, colNames, ~] = load_data(opts);
    % Build template model
    switch lower(opts.method)
        case 'tree',     template = templateTree('NumVariablesToSample', 'all');
        case 'forest',   template = templateTree();
        otherwise
            template = [];  % not all methods support templates
    end
    if ~isempty(template)
        cvmdl = crossval(build_classifier(X, y, opts.method), 'KFold', opts.folds);
    else
        cvmdl = crossval(build_classifier(X, y, opts.method), 'KFold', opts.folds);
    end
    losses = kfoldLoss(cvmdl, 'mode', 'individual');
    out = struct();
    out.method = opts.method;
    out.folds = opts.folds;
    out.foldLosses = losses;
    out.meanLoss = mean(losses);
    out.accuracy = 1 - mean(losses);
    out.numFeatures = size(X, 2);
    out.numSamples = size(X, 1);
    if ~isempty(colNames), out.featureNames = colNames; end
end

function out = act_features(opts)
    [X, y, colNames, ~] = load_data(opts);
    % Fit a tree to rank features
    mdl = fitctree(X, y);
    imp = predictorImportance(mdl);
    [sortedImp, sortedIdx] = sort(imp, 'descend');
    out = struct();
    out.numFeatures = size(X, 2);
    out.numSamples = size(X, 1);
    out.importance = imp;
    if ~isempty(colNames)
        out.featureNames = colNames;
        out.rankedFeatures = colNames(sortedIdx);
        out.rankedImportance = sortedImp;
    end
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
