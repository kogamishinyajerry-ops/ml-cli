function cli_lidar(action, varargin)
% CLI_LIDAR Lidar point cloud processing for ml CLI
%   CLI: ml lidar info       <cloud.las|pcd|mat>
%         ml lidar downsample <cloud> --grid 0.1
%         ml lidar segment    <cloud> --threshold 0.3
%         ml lidar cluster    <cloud> --dist 0.5
%         ml lidar fit        <cloud> --shape plane --maxdist 0.05
%         ml lidar view       <cloud> [--out plot.png]
%
%   Options:
%     --grid m        voxel grid size for downsampling
%     --threshold m   ground segmentation threshold
%     --dist m        euclidean cluster distance
%     --minpoints N   min points per cluster
%     --shape NAME    plane|sphere|cylinder
%     --maxdist m     max fit distance
%     --maxtrials N   RANSAC trials
%     --out PATH      save plot
%     --format json|table|csv

    if nargin < 1, error('ml lidar <action> [options]'); end

    opts = struct('format','json','grid',0.1,'threshold',0.3, ...
                  'dist',0.5,'minpoints',10,'shape','plane', ...
                  'maxdist',0.05,'maxtrials',1000,'file','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--grid',        opts.grid = parse_num(varargin{i+1}); i=i+2;
            case '--threshold',   opts.threshold = parse_num(varargin{i+1}); i=i+2;
            case '--dist',        opts.dist = parse_num(varargin{i+1}); i=i+2;
            case '--minpoints',   opts.minpoints = round(parse_num(varargin{i+1})); i=i+2;
            case '--shape',       opts.shape = varargin{i+1}; i=i+2;
            case '--maxdist',     opts.maxdist = parse_num(varargin{i+1}); i=i+2;
            case '--maxtrials',   opts.maxtrials = round(parse_num(varargin{i+1})); i=i+2;
            case '--out',         opts.out = varargin{i+1}; i=i+2;
            case '--format',      opts.format = varargin{i+1}; i=i+2;
            otherwise,            opts.file = tok; i=i+1;
        end
    end

    if ~exist('pcread','file')
        error('Lidar Toolbox not available');
    end

    try
        switch lower(action)
            case 'info',        out = act_info(opts);
            case 'downsample',  out = act_downsample(opts);
            case 'segment',     out = act_segment(opts);
            case 'cluster',     out = act_cluster(opts);
            case 'fit',         out = act_fit(opts);
            case 'view',        out = act_view(opts);
            otherwise,          error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Read point cloud ===================
function ptCloud = read_cloud(opts)
    if isempty(opts.file), error('lidar file required'); end
    ptCloud = pcread(opts.file);
end

% =================== Actions ===================
function out = act_info(opts)
    ptCloud = read_cloud(opts);
    out = struct();
    out.fileName = opts.file;
    out.numPoints = ptCloud.Count;
    out.hasColor = ~isempty(ptCloud.Color);
    out.hasIntensity = ~isempty(ptCloud.Intensity);
    loc = ptCloud.Location;
    out.xRange = [min(loc(:,1)), max(loc(:,1))];
    out.yRange = [min(loc(:,2)), max(loc(:,2))];
    out.zRange = [min(loc(:,3)), max(loc(:,3))];
    out.centroid = mean(loc, 1);
    out.bbox_size = [range(loc(:,1)), range(loc(:,2)), range(loc(:,3))];
end

function out = act_downsample(opts)
    ptCloud = read_cloud(opts);
    ptCloud_ds = pcdownsample(ptCloud, 'gridAverage', opts.grid);
    out = struct();
    out.fileName = opts.file;
    out.method = 'gridAverage';
    out.gridSize = opts.grid;
    out.inputPoints = ptCloud.Count;
    out.outputPoints = ptCloud_ds.Count;
    out.reductionRatio = ptCloud_ds.Count / ptCloud.Count;
end

function out = act_segment(opts)
    ptCloud = read_cloud(opts);
    loc = ptCloud.Location;
    % Try Lidar Toolbox ground segmentation (requires organized cloud)
    usedLidarTB = false;
    isOrganized = ~isempty(ptCloud.Location) && any(size(ptCloud.Location) > 1) && ndims(ptCloud.Location) == 3;
    if exist('segmentGroundFromLidarData','file') == 2 && isOrganized
        try
            groundIdx = segmentGroundFromLidarData(ptCloud);
            groundPtCloud = pointCloud(loc(groundIdx,:));
            nonGroundPtCloud = pointCloud(loc(setdiff(1:size(loc,1), groundIdx),:));
            usedLidarTB = true;
        catch
            usedLidarTB = false;
        end
    end
    if ~usedLidarTB
        % Fallback: height-based segmentation
        z = loc(:,3);
        zGround = quantile(z, 0.3);
        groundMask = z < zGround + opts.threshold;
        groundPtCloud = pointCloud(loc(groundMask,:));
        nonGroundPtCloud = pointCloud(loc(~groundMask,:));
    end
    out = struct();
    out.fileName = opts.file;
    out.threshold = opts.threshold;
    out.totalPoints = double(ptCloud.Count);
    out.groundPoints = groundPtCloud.Count;
    out.nonGroundPoints = nonGroundPtCloud.Count;
    out.groundFraction = groundPtCloud.Count / double(ptCloud.Count);
    out.method = ternary(usedLidarTB, 'segmentGroundFromLidarData', 'height-based fallback');
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function out = act_cluster(opts)
    ptCloud = read_cloud(opts);
    % Ensure points are finite (remove NaN/Inf)
    loc = ptCloud.Location;
    validMask = all(isfinite(loc), 2);
    ptCloud = select(ptCloud, find(validMask));
    labels = pcsegdist(ptCloud, opts.dist, 'NumClusterPoints', opts.minpoints);
    numClusters = double(max(labels));
    clusterSizes = zeros(numClusters, 1);
    for k = 1:numClusters
        clusterSizes(k) = sum(double(labels) == k);
    end
    [clusterSizes, idx] = sort(clusterSizes, 'descend');
    out = struct();
    out.fileName = opts.file;
    out.distanceThreshold = opts.dist;
    out.numClusters = numClusters;
    out.clusterSizes = clusterSizes;
    out.largestCluster = idx(1);
    out.largestClusterSize = clusterSizes(1);
end

function out = act_fit(opts)
    ptCloud = read_cloud(opts);
    loc = ptCloud.Location;
    validMask = all(isfinite(loc), 2);
    ptCloud = select(ptCloud, find(validMask));
    shape = lower(opts.shape);
    sampleSize = min(ptCloud.Count, 10000);
    idx = randperm(ptCloud.Count, sampleSize);
    ptCloud_sample = select(ptCloud, idx);
    out = struct();
    out.fileName = opts.file;
    out.shape = shape;
    out.numInputPoints = ptCloud.Count;
    out.sampledPoints = sampleSize;
    switch shape
        case 'plane'
            [model, inlierIdx, rmse] = pcfitplane(ptCloud_sample, opts.maxdist, ...
                'MaxNumTrials', opts.maxtrials);
            if isempty(model)
                out.fitSuccess = false;
            else
                out.fitSuccess = true;
                out.normal = model.Parameters;
                out.numInliers = numel(inlierIdx);
                out.inlierFraction = numel(inlierIdx) / sampleSize;
                out.rmse = rmse;
            end
        case 'sphere'
            [model, inlierIdx, rmse] = pcfitsphere(ptCloud_sample, opts.maxdist, ...
                'MaxNumTrials', opts.maxtrials);
            if isempty(model)
                out.fitSuccess = false;
            else
                out.fitSuccess = true;
                out.center = model.Center;
                out.radius = model.Radius;
                out.numInliers = numel(inlierIdx);
                out.rmse = rmse;
            end
        case 'cylinder'
            [model, inlierIdx, rmse] = pcfitcylinder(ptCloud_sample, opts.maxdist, ...
                'MaxNumTrials', opts.maxtrials);
            if isempty(model)
                out.fitSuccess = false;
            else
                out.fitSuccess = true;
                out.direction = model.Direction;
                out.center = model.Center;
                out.radius = model.Radius;
                out.numInliers = numel(inlierIdx);
                out.rmse = rmse;
            end
        otherwise
            error('unknown shape: %s (try plane|sphere|cylinder)', shape);
    end
end

function out = act_view(opts)
    ptCloud = read_cloud(opts);
    out = struct();
    out.fileName = opts.file;
    out.numPoints = ptCloud.Count;
    if isfield(opts,'out')
        fig = figure('Visible','off');
        pcshow(ptCloud);
        exportgraphics(fig, opts.out); close(fig);
        out.plotFile = opts.out;
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
