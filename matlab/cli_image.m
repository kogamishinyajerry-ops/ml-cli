function cli_image(action, varargin)
% CLI_IMAGE Image processing for ml CLI
%   CLI: ml image info       --file photo.jpg
%         ml image hist      --file photo.jpg --bins 32
%         ml image edge      --file photo.jpg --method canny --threshold 0.1
%         ml image filter    --file photo.jpg --filter gaussian --size 5
%         ml image segment   --file photo.jpg --k 3
%         ml image morph     --file binary.png --op erode --radius 2
%         ml image convert   --file photo.jpg --format png --out out.png
%
%   Options:
%     --file PATH        input image file
%     --out PATH         output file (default out.<ext>)
%     --method NAME      edge detection method (sobel|prewitt|canny|roberts)
%     --filter NAME      smoothing filter (gaussian|median|mean|unsharp)
%     --size N           kernel size (default 3)
%     --threshold VAL    threshold (0-1)
%     --bins N           histogram bins (default 32)
%     --k N              number of clusters for segmentation
%     --op NAME          morphological op (erode|dilate|open|close)
%     --radius N         structuring element radius
%     --format NAME      output format (png|jpg|tif|bmp)
%     --json             emit JSON metadata instead of saving file

    if nargin < 1, error('ml image <action> [options]'); end

    opts = struct('file','','out','','method','sobel','filter','gaussian', ...
                  'size',3,'threshold',0.1,'bins',32,'k',3,'op','erode', ...
                  'radius',1,'format','png','emit_json',false);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--file',      opts.file = varargin{i+1}; i=i+2;
            case '--out',       opts.out = varargin{i+1}; i=i+2;
            case '--method',    opts.method = lower(varargin{i+1}); i=i+2;
            case '--filter',    opts.filter = lower(varargin{i+1}); i=i+2;
            case '--size',      opts.size = round(parse_num(varargin{i+1})); i=i+2;
            case '--threshold', opts.threshold = parse_num(varargin{i+1}); i=i+2;
            case '--bins',      opts.bins = round(parse_num(varargin{i+1})); i=i+2;
            case '--k',         opts.k = round(parse_num(varargin{i+1})); i=i+2;
            case '--op',        opts.op = lower(varargin{i+1}); i=i+2;
            case '--radius',    opts.radius = round(parse_num(varargin{i+1})); i=i+2;
            case '--format',    opts.format = lower(varargin{i+1}); i=i+2;
            case '--json',      opts.emit_json = true; i=i+1;
            case '--format_out',opts.format = lower(varargin{i+1}); i=i+2;  % avoid clash
            otherwise,          i=i+1;
        end
    end

    if isempty(opts.file)
        error('--file required (use ml image <action> --file path)');
    end
    if ~exist(opts.file, 'file'), error('file not found: %s', opts.file); end

    try
        switch lower(action)
            case 'info',    out = act_info(opts);
            case 'hist',    out = act_hist(opts);
            case 'edge',    out = act_edge(opts);
            case 'filter',  out = act_filter(opts);
            case 'segment', out = act_segment(opts);
            case 'morph',   out = act_morph(opts);
            case 'convert', out = act_convert(opts);
            otherwise,      error('unknown action: %s', action);
        end
        jsonify(out);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_info(opts)
    info = imfinfo(opts.file);
    out = struct();
    out.action = 'info';
    out.file = opts.file;
    out.format = info.Format;
    out.width = info.Width;
    out.height = info.Height;
    out.bitDepth = info.BitDepth;
    out.colorType = info.ColorType;
    if isfield(info, 'FileSize'), out.fileSizeBytes = info.FileSize; end
    if isfield(info, 'FormatVersion'), out.formatVersion = info.FormatVersion; end
    % Compute basic stats from image data
    try
        [I, map] = imread(opts.file);
        if ~isempty(map)
            % indexed
            out.indexedColors = size(map, 1);
            I = ind2rgb(I, map);
        end
        if ndims(I) == 3
            out.meanIntensity = mean(I(:));
            out.channelMeans = squeeze(mean(mean(I, 1), 2));
        else
            out.meanIntensity = mean(I(:));
            out.channelMeans = out.meanIntensity;
        end
    catch
        % Skip stats if unreadable
    end
end

function out = act_hist(opts)
    I = read_image_gray(opts.file);
    % Scale to 0-1 if integer
    if max(I(:)) > 1, I = im2double(I); end
    [counts, centers] = imhist(I, opts.bins);
    out = struct();
    out.action = 'hist';
    out.bins = opts.bins;
    out.centers = centers(:)';
    out.counts = counts(:)';
    out.totalPixels = numel(I);
    out.meanIntensity = mean2(I);
    out.stdIntensity = std2(I);
end

function out = act_edge(opts)
    I = read_image_gray(opts.file);
    if max(I(:)) > 1, I = im2double(I); end
    method = opts.method;
    switch method
        case 'sobel'
            E = edge_sobel(I);
        case 'prewitt'
            E = edge_prewitt(I);
        case 'roberts'
            E = edge_roberts(I);
        case 'canny'
            % Approximated Canny: sobel + non-max suppression skipped, just threshold
            G = edge_sobel(I);
            E = G > opts.threshold;
        otherwise
            error('unknown method: %s (sobel|prewitt|roberts|canny)', method);
    end
    outFile = default_out(opts, ['_edge_' method '.png']);
    imwrite(uint8(E) * 255, outFile);
    out = struct();
    out.action = 'edge';
    out.method = method;
    out.threshold = opts.threshold;
    out.edgePixels = sum(E(:));
    out.edgeRatio = sum(E(:)) / numel(E);
    out.outputFile = outFile;
end

function out = act_filter(opts)
    I = read_image_gray(opts.file);
    if max(I(:)) > 1, I = im2double(I); end
    f = opts.filter;
    sz = opts.size;
    if mod(sz, 2) == 0, sz = sz + 1; end  % force odd
    switch f
        case 'gaussian'
            sigma = sz / 6;
            [X, Y] = meshgrid(linspace(-1, 1, sz), linspace(-1, 1, sz));
            h = exp(-(X.^2 + Y.^2) / (2*sigma^2));
            h = h / sum(h(:));
            J = imfilter_scalar(I, h);
        case 'mean'
            h = ones(sz) / sz^2;
            J = imfilter_scalar(I, h);
        case 'median'
            J = imfilter_median(I, sz);
        case 'unsharp'
            sigma = sz / 6;
            [X, Y] = meshgrid(linspace(-1, 1, sz), linspace(-1, 1, sz));
            g = exp(-(X.^2 + Y.^2) / (2*sigma^2));
            g = g / sum(g(:));
            blur = imfilter_scalar(I, g);
            J = I + 0.6 * (I - blur);
            J = max(0, min(1, J));
        otherwise
            error('unknown filter: %s (gaussian|mean|median|unsharp)', f);
    end
    outFile = default_out(opts, ['_filter_' f '.png']);
    imwrite(uint8(J * 255), outFile);
    out = struct();
    out.action = 'filter';
    out.filter = f;
    out.kernelSize = sz;
    out.outputFile = outFile;
end

function out = act_segment(opts)
    I = read_image_gray(opts.file);
    if max(I(:)) > 1, I = im2double(I); end
    k = opts.k;
    % Simple k-means on intensity (1D)
    [idx, centers] = kmeans_1d(double(I(:)), k);
    seg = reshape(idx, size(I));
    % Color-map segments - build RGB channels manually
    cmap = hsv(k);
    segImg = zeros(size(I,1), size(I,2), 3);
    for c = 1:3
        segImg(:,:,c) = reshape(cmap(seg(:), c), size(I));
    end
    outFile = default_out(opts, '_segment.png');
    imwrite(segImg, outFile);
    out = struct();
    out.action = 'segment';
    out.method = 'kmeans-1d-intensity';
    out.k = k;
    out.centers = centers;
    out.clusterSizes = arrayfun(@(j) sum(idx == j), 1:k);
    out.outputFile = outFile;
end

function out = act_morph(opts)
    I = read_image_gray(opts.file);
    % Binarize
    if max(I(:)) > 1
        I = I > 128;
    else
        I = I > 0.5;
    end
    r = opts.radius;
    se = ones(2*r+1);
    op = opts.op;
    switch op
        case 'erode', J = morph_erode(I, se);
        case 'dilate', J = morph_dilate(I, se);
        case 'open',  J = morph_erode(morph_dilate(I, se), se);
        case 'close', J = morph_dilate(morph_erode(I, se), se);
        otherwise, error('unknown op: %s (erode|dilate|open|close)', op);
    end
    outFile = default_out(opts, ['_morph_' op '.png']);
    imwrite(uint8(J) * 255, outFile);
    out = struct();
    out.action = 'morph';
    out.operation = op;
    out.radius = r;
    out.changedPixels = sum(J(:) ~= I(:));
    out.outputFile = outFile;
end

function out = act_convert(opts)
    I = imread(opts.file);
    [~, map] = imread(opts.file);
    if ~isempty(map)
        [I, map] = imread(opts.file);
        if ~isempty(map)
            rgb = ind2rgb(I, map);
            I = uint8(rgb * 255);
        end
    end
    if isempty(opts.out)
        [~, name, ~] = fileparts(opts.file);
        outFile = sprintf('%s.%s', name, opts.format);
    else
        outFile = opts.out;
    end
    imwrite(I, outFile, opts.format);
    out = struct();
    out.action = 'convert';
    out.input = opts.file;
    out.output = outFile;
    out.format = opts.format;
end

% =================== Image utilities ===================
function I = read_image_gray(file)
    [I, map] = imread(file);
    if ~isempty(map)
        I = ind2rgb(I, map);
        I = uint8(I * 255);
    end
    if ndims(I) == 3
        % RGB to gray (Rec. 601 luma)
        I = uint8(0.299*double(I(:,:,1)) + 0.587*double(I(:,:,2)) + 0.114*double(I(:,:,3)));
    end
end

function J = imfilter_scalar(I, h)
    % 2D convolution with zero padding
    [m, n] = size(I);
    [kh, kw] = size(h);
    ph = (kh - 1) / 2; pw = (kw - 1) / 2;
    padded = padarray(I, [ph pw], 0);
    J = zeros(size(I));
    h_flip = rot90(h, 2);  % convolution
    for i = 1:m
        for j = 1:n
            J(i, j) = sum(sum(padded(i:i+kh-1, j:j+kw-1) .* h_flip));
        end
    end
end

function J = imfilter_median(I, sz)
    [m, n] = size(I);
    ph = (sz - 1) / 2;
    padded = padarray(I, [ph ph], 0);
    J = zeros(size(I));
    for i = 1:m
        for j = 1:n
            block = padded(i:i+sz-1, j:j+sz-1);
            J(i, j) = median(block(:));
        end
    end
end

function E = edge_sobel(I)
    sx = [-1 0 1; -2 0 2; -1 0 1];
    sy = sx';
    Gx = imfilter_scalar(I, sx);
    Gy = imfilter_scalar(I, sy);
    E = sqrt(Gx.^2 + Gy.^2);
    E = E / max(E(:));  % normalize
end

function E = edge_prewitt(I)
    sx = [-1 0 1; -1 0 1; -1 0 1];
    sy = sx';
    Gx = imfilter_scalar(I, sx);
    Gy = imfilter_scalar(I, sy);
    E = sqrt(Gx.^2 + Gy.^2);
    E = E / max(E(:));
end

function E = edge_roberts(I)
    [m, n] = size(I);
    Gx = zeros(size(I));
    Gy = zeros(size(I));
    Gx(1:m-1, 1:n-1) = I(1:m-1, 1:n-1) - I(2:m, 2:n);
    Gy(1:m-1, 1:n-1) = I(1:m-1, 2:n) - I(2:m, 1:n-1);
    E = sqrt(Gx.^2 + Gy.^2);
    E = E / max(E(:));
end

function [idx, centers] = kmeans_1d(x, k)
    % Initialize centers at percentiles
    x = x(:);
    centers = quantile(x, linspace(0, 1, k+2));
    centers = centers(2:k+1);
    centers = centers(:)';   % ensure row
    for iter = 1:50
        d = abs(x - centers);   % broadcast N×1 vs 1×k → N×k
        [~, idx] = min(d, [], 2);
        idx = idx(:);
        newCenters = centers;
        for j = 1:k
            members = x(idx == j);
            if ~isempty(members)
                newCenters(j) = mean(members);
            end
        end
        if max(abs(newCenters - centers)) < 1e-6
            centers = newCenters;
            break;
        end
        centers = newCenters;
    end
end

function J = morph_erode(I, se)
    [m, n] = size(I);
    [kh, kw] = size(se);
    ph = (kh-1)/2; pw = (kw-1)/2;
    padded = padarray(I, [ph pw], 1);
    J = true(size(I));
    for i = 1:m
        for j = 1:n
            block = padded(i:i+kh-1, j:j+kw-1);
            J(i, j) = all(block(se == 1) == 1);
        end
    end
end

function J = morph_dilate(I, se)
    [m, n] = size(I);
    [kh, kw] = size(se);
    ph = (kh-1)/2; pw = (kw-1)/2;
    padded = padarray(I, [ph pw], 0);
    J = false(size(I));
    for i = 1:m
        for j = 1:n
            block = padded(i:i+kh-1, j:j+kw-1);
            J(i, j) = any(block(se == 1) == 1);
        end
    end
end

function outFile = default_out(opts, suffix)
    if ~isempty(opts.out)
        outFile = opts.out;
    else
        [path, name, ext] = fileparts(opts.file);
        outFile = fullfile(path, [name suffix]);
    end
end

function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end
