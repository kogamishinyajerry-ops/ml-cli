function result = image_info(filepath)
% IMAGE_INFO Get image metadata
%   CLI: ml image file.png --info --json
    info = imfinfo(filepath);
    img = imread(filepath);
    [h, w, c] = size(img);

    result = struct();
    result.filename = filepath;
    result.width = w;
    result.height = h;
    result.channels = c;
    result.format = info.Format;
    result.file_size_bytes = info.FileSize;
    if isfield(info, 'BitDepth'), result.bit_depth = info.BitDepth; end
    if isfield(info, 'ColorType'), result.color_type = info.ColorType; end
end
