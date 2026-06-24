function cli_cv(action, varargin)
% CLI_CV Computer vision operations for ml CLI
%   CLI: ml cv features --image img.jpg --method surf [--plot out.png]
%         ml cv match   --image1 a.jpg --image2 b.jpg
%         ml cv track   --image1 a.jpg --image2 b.jpg
%         ml cv stereo  --image1 left.png --image2 right.png
%         ml cv detect  --image img.jpg
%
%   Options:
%     --image PATH      input image
%     --image1 PATH     first image (for match/track/stereo)
%     --image2 PATH     second image
%     --method NAME     surf|orb|brisk|harris (default surf)
%     --plot PATH       save visualization to file
%     --format json|table|csv

    if nargin < 1, error('ml cv <action> [options]'); end

    opts = struct('format','json','method','surf');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--image',    opts.image = varargin{i+1}; i=i+2;
            case '--image1',   opts.image1 = varargin{i+1}; i=i+2;
            case '--image2',   opts.image2 = varargin{i+1}; i=i+2;
            case '--method',   opts.method = varargin{i+1}; i=i+2;
            case '--plot',     opts.plot = varargin{i+1}; i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    if ~exist('detectSURFFeatures','file')
        error('Computer Vision Toolbox not available');
    end

    try
        switch lower(action)
            case 'features',  out = act_features(opts);
            case 'match',     out = act_match(opts);
            case 'track',     out = act_track(opts);
            case 'stereo',    out = act_stereo(opts);
            case 'detect',    out = act_detect(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_features(opts)
    if ~isfield(opts,'image'), error('features needs --image PATH'); end
    img = imread(opts.image);
    if size(img,3) == 3, gray = rgb2gray(img); else gray = img; end
    method = lower(opts.method);
    switch method
        case 'surf',   pts = detectSURFFeatures(gray);
        case 'orb',    pts = detectORBFeatures(gray);
        case 'brisk',  pts = detectBRISKFeatures(gray);
        case 'harris', pts = detectHarrisFeatures(gray);
        case 'fast',   pts = detectFastFeatures(gray);
        case 'kaze',   pts = detectKAZEFeatures(gray);
        case 'min_eig',pts = detectMinEigenFeatures(gray);
        otherwise,     error('unknown method: %s (try surf/orb/brisk/harris)', method);
    end
    n = get_count(pts);
    out = struct();
    out.method = method;
    out.imageSize = [size(gray,1) size(gray,2)];
    out.numKeypoints = n;
    if n > 0
        out.keypoints = table(pts.Location, pts.Scale, pts.Metric, ...
            'VariableNames', {'location','scale','metric'});
        strongest10 = sort(pts.Metric,'descend');
        out.topMetric = strongest10(1:min(10,n));
        out.meanMetric = mean(pts.Metric);
        % Extract descriptors for stats
        try
            switch method
                case 'surf',  [f, vp] = extractFeatures(gray, pts, 'Method','SURF');
                otherwise,    [f, vp] = extractFeatures(gray, pts);
            end
            out.descriptorSize = size(f, 2);
            out.numValidDescriptors = size(f, 1);
        catch
        end
    end
    if isfield(opts,'plot')
        fig = figure('Visible','off');
        imshow(img); hold on; plot(pts); title(sprintf('%s: %d keypoints', method, n));
        exportgraphics(fig, opts.plot); close(fig);
        out.plotFile = opts.plot;
    end
end

function out = act_match(opts)
    if ~isfield(opts,'image1') || ~isfield(opts,'image2')
        error('match needs --image1 and --image2');
    end
    I1 = imread(opts.image1); I2 = imread(opts.image2);
    if size(I1,3)==3, G1 = rgb2gray(I1); else G1 = I1; end
    if size(I2,3)==3, G2 = rgb2gray(I2); else G2 = I2; end
    pts1 = detectSURFFeatures(G1);
    pts2 = detectSURFFeatures(G2);
    [F1, vpts1] = extractFeatures(G1, pts1, 'Method','SURF');
    [F2, vpts2] = extractFeatures(G2, pts2, 'Method','SURF');
    [pairs, ratio] = matchFeatures(F1, F2);
    out = struct();
    out.numKeyPoints1 = get_count(pts1);
    out.numKeyPoints2 = get_count(pts2);
    out.numMatches = size(pairs,1);
    out.meanMatchRatio = mean(ratio);
    if size(pairs,1) >= 4
        try
            tform = estgeotform2d(pts1.Location(pairs(:,1),:), ...
                                  pts2.Location(pairs(:,2),:), 'affine');
            out.homography = tform.A;
            out.inlierRatio = numel(tform.Inliers)/size(pairs,1);
            out.tformType = 'affine';
        catch
            try
                [H, inlierIdx] = estimateGeometricTransform2D( ...
                    pts1.Location(pairs(:,1),:), pts2.Location(pairs(:,2),:), 'affine');
                out.homography = H;
                out.inlierRatio = sum(inlierIdx)/size(pairs,1);
            catch
            end
        end
    end
end

function out = act_track(opts)
    if ~isfield(opts,'image1') || ~isfield(opts,'image2')
        error('track needs --image1 and --image2');
    end
    I1 = imread(opts.image1); I2 = imread(opts.image2);
    if size(I1,3)==3, G1 = rgb2gray(I1); else G1 = I1; end
    if size(I2,3)==3, G2 = rgb2gray(I2); else G2 = I2; end
    pts = detectSURFFeatures(G1);
    if get_count(pts) == 0, error('no features detected in image1'); end
    if get_count(pts) > 200, pts = selectStrongest(pts, 200); end
    points1 = pts.Location;
    tracker = vision.PointTracker('MaxBidirectionalError', 2);
    initialize(tracker, points1, G1);
    [points2, visibility, ~] = step(tracker, G2);
    release(tracker);
    nTracked = sum(visibility);
    if nTracked > 0
        disp_ = points2(visibility,:) - points1(visibility,:);
        distances = sqrt(sum(disp_.^2, 2));
        meanDisp = mean(distances);
        maxDisp = max(distances);
    else
        meanDisp = 0; maxDisp = 0;
    end
    out = struct();
    out.numSeedPoints = size(points1,1);
    out.numTracked = nTracked;
    out.trackingRate = nTracked / size(points1,1);
    out.meanDisplacement = meanDisp;
    out.maxDisplacement = maxDisp;
end

function out = act_stereo(opts)
    if ~isfield(opts,'image1') || ~isfield(opts,'image2')
        error('stereo needs --image1 (left) and --image2 (right)');
    end
    I1 = imread(opts.image1); I2 = imread(opts.image2);
    if size(I1,3)==3, L = rgb2gray(I1); else L = I1; end
    if size(I2,3)==3, R = rgb2gray(I2); else R = I2; end
    if ~isstrprop(opts.image1, 'digit') && size(L,1) ~= size(R,1)
        % rectify assumption
        L = imresize(L, [size(R,1) NaN]);
    end
    try
        disparityMap = disparitySGM(L, R);
    catch
        try
            disparityMap = disparityBM(L, R);
        catch ME
            error('stereo failed: %s', ME.message);
        end
    end
    valid = disparityMap > 0 & disparityMap < 256;
    out = struct();
    out.imageSize = [size(L,1) size(L,2)];
    out.method = 'SGM/BM';
    if any(valid(:))
        vals = disparityMap(valid);
        out.meanDisparity = mean(vals);
        out.medianDisparity = median(vals);
        out.maxDisparity = max(vals);
        out.minDisparity = min(vals);
    else
        out.meanDisparity = 0;
    end
    out.numValidPixels = sum(valid(:));
    out.validPixelRatio = sum(valid(:))/numel(valid);
    if isfield(opts,'plot')
        fig = figure('Visible','off');
        imshow(disparityMap, []); colormap jet; colorbar;
        title('Disparity map');
        exportgraphics(fig, opts.plot); close(fig);
        out.plotFile = opts.plot;
    end
end

function out = act_detect(opts)
    if ~isfield(opts,'image'), error('detect needs --image PATH'); end
    img = imread(opts.image);
    % Try YOLO first, fall back to ACF people detector
    detected = false;
    try
        detector = yolov4ObjectDetector('coco');
        [bboxes, scores, labels] = detect(detector, img);
        detected = true;
        method = 'YOLOv4';
    catch
        % Fall back to ACF people detector
        try
            detector = peopleDetectorACF;
            [bboxes, scores] = detect(detector, img);
            labels = repmat({'person'}, size(bboxes,1), 1);
            detected = true;
            method = 'ACF-people';
        catch ME2
            out = struct();
            out.image = opts.image;
            out.detected = false;
            out.errorMessage = 'No pretrained detector available. Install YOLO/ACF support package.';
            out.note = ME2.message;
            return;
        end
    end
    out = struct();
    out.image = opts.image;
    out.method = method;
    out.numDetections = size(bboxes,1);
    if size(bboxes,1) > 0
        out.boundingBoxes = num2cell(bboxes, 2);
        out.scores = scores(:);
        out.labels = cellstr(labels);
    end
    if isfield(opts,'plot') && size(bboxes,1) > 0
        fig = figure('Visible','off');
        detectedImg = insertObjectAnnotation(img, 'rectangle', bboxes, cellstr(labels));
        imshow(detectedImg);
        exportgraphics(fig, opts.plot); close(fig);
        out.plotFile = opts.plot;
    end
end

% =================== Helpers ===================
function n = get_count(pts)
    try
        if isprop(pts,'Count'), n = pts.Count; else, n = numel(pts); end
    catch
        n = numel(pts);
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
