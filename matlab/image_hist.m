function result = image_hist(filepath)
% IMAGE_HIST Compute image histogram
%   CLI: ml image file.png --hist --json
    img = imread(filepath);
    if size(img, 3) >= 3
        img_gray = rgb2gray(img);
    else
        img_gray = img;
    end

    [counts, edges] = histcounts(double(img_gray(:)), 256, 'BinLimits', [0 255]);
    centers = (edges(1:end-1) + edges(2:end)) / 2;

    result = struct();
    result.bins = centers;
    result.counts = counts;
    result.total_pixels = numel(img_gray);
    result.mean = mean(double(img_gray(:)));
    result.std = std(double(img_gray(:)));
end
