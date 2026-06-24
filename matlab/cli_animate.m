function cli_animate(action, varargin)
% CLI_ANIMATE Animation / video generation for ml CLI
%   CLI: ml animate func  --expr "sin(x-0.5*t)" --xrange "[0 10]" --trange "[0 20]" --frames 30 --out out.gif
%         ml animate param --expr "sin(p*x)"    --xrange "[0 6]"  --prange "[0.5 3]" --frames 20 --out out.gif
%         ml animate trace --xexpr "cos(t)" --yexpr "sin(t)" --trange "[0 2*pi]" --frames 40 --out trail.mp4
%
%   Options:
%     --frames N       number of frames (default 30)
%     --fps N          frames per second (default 10)
%     --out PATH       output file (.gif or .mp4); default output.gif
%     --title STR      plot title

    if nargin < 1, error('ml animate <action> [options]'); end

    opts = struct('frames',30, 'fps',10, 'out','output.gif', 'title','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--expr',   opts.expr = varargin{i+1}; i=i+2;
            case '--xexpr',  opts.xexpr = varargin{i+1}; i=i+2;
            case '--yexpr',  opts.yexpr = varargin{i+1}; i=i+2;
            case '--xrange', opts.xrange = parse_vec(varargin{i+1}); i=i+2;
            case '--trange', opts.trange = parse_vec(varargin{i+1}); i=i+2;
            case '--prange', opts.prange = parse_vec(varargin{i+1}); i=i+2;
            case '--frames', opts.frames = round(parse_num(varargin{i+1})); i=i+2;
            case '--fps',    opts.fps = round(parse_num(varargin{i+1})); i=i+2;
            case '--out',    opts.out = varargin{i+1}; i=i+2;
            case '--title',  opts.title = varargin{i+1}; i=i+2;
            otherwise,       i=i+1;
        end
    end

    [~, ~, ext] = fileparts(opts.out);
    isGif = strcmpi(ext, '.gif');

    try
        fig = figure('Visible','off');
        switch lower(action)
            case 'func',  frames = make_func(opts);
            case 'param', frames = make_param(opts);
            case 'trace', frames = make_trace(opts);
            otherwise,    error('unknown action: %s', action);
        end
        close(fig);

        if isGif
            write_gif(opts.out, frames, opts.fps);
        else
            write_mp4(opts.out, frames, opts.fps);
        end

        info = struct();
        info.action = action;
        info.outputFile = opts.out;
        info.numFrames = numel(frames);
        info.fps = opts.fps;
        info.durationSec = numel(frames) / opts.fps;
        info.format = ext;
        jsonify(info);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Frame generators ===================
function frames = make_func(opts)
    % animate y = f(x, t)
    validate(opts, {'expr','xrange','trange'});
    x = linspace(opts.xrange(1), opts.xrange(2), 200);
    tList = linspace(opts.trange(1), opts.trange(2), opts.frames);
    expr = opts.expr;
    frames = cell(1, opts.frames);
    for k = 1:opts.frames
        t = tList(k);
        y = eval(expr);
        plot_frame(opts.title, sprintf('t = %.3g', t), x, y, opts.xrange);
        frames{k} = capture_frame();
    end
end

function frames = make_param(opts)
    validate(opts, {'expr','xrange','prange'});
    x = linspace(opts.xrange(1), opts.xrange(2), 200);
    pList = linspace(opts.prange(1), opts.prange(2), opts.frames);
    expr = opts.expr;
    frames = cell(1, opts.frames);
    for k = 1:opts.frames
        p = pList(k);
        y = eval(expr);
        plot_frame(opts.title, sprintf('p = %.3g', p), x, y, opts.xrange);
        frames{k} = capture_frame();
    end
end

function frames = make_trace(opts)
    validate(opts, {'xexpr','yexpr','trange'});
    tList = linspace(opts.trange(1), opts.trange(2), opts.frames);
    xexpr = opts.xexpr; yexpr = opts.yexpr;
    xTrail = zeros(1, opts.frames);
    yTrail = zeros(1, opts.frames);
    for k = 1:opts.frames
        t = tList(k);
        xTrail(k) = eval(xexpr);
        yTrail(k) = eval(yexpr);
    end
    frames = cell(1, opts.frames);
    for k = 1:opts.frames
        plot(xTrail(1:k), yTrail(1:k), 'b-', 'LineWidth', 2);
        hold on; plot(xTrail(k), yTrail(k), 'ro', 'MarkerFaceColor','r'); hold off;
        title(opts.title); xlabel('x'); ylabel('y');
        axis([min(xTrail)-0.5 max(xTrail)+0.5 min(yTrail)-0.5 max(yTrail)+0.5]);
        grid on;
        frames{k} = capture_frame();
    end
end

function plot_frame(titleStr, subStr, x, y, xrange)
    plot(x, y, 'b-', 'LineWidth', 2);
    if ~isempty(titleStr), title(titleStr); end
    xlabel('x'); ylabel('y');
    xlim(xrange);
    grid on;
    text(0.02, 0.95, subStr, 'Units','normalized', 'VerticalAlignment','top');
end

% =================== Frame capture ===================
function f = capture_frame()
    drawnow;
    frame = getframe(gcf);
    [f.img, f.map] = frame2im(frame);
end

% =================== Writers ===================
function write_gif(path, frames, fps)
    delay = 1.0 / fps;
    for k = 1:numel(frames)
        img = frames{k}.img;
        map = frames{k}.map;
        if isempty(map)
            [imgInd, map] = rgb2ind(img, 256);
        else
            imgInd = img;
        end
        if k == 1
            imwrite(imgInd, map, path, 'Loopcount', inf, 'DelayTime', delay);
        else
            imwrite(imgInd, map, path, 'WriteMode','append', 'DelayTime', delay);
        end
    end
end

function write_mp4(path, frames, fps)
    v = VideoWriter(path, 'MPEG-4');
    v.FrameRate = fps;
    open(v);
    for k = 1:numel(frames)
        img = frames{k}.img;
        writeVideo(v, im2frame(img));
    end
    close(v);
end

% =================== Helpers ===================
function validate(opts, required)
    for k = 1:numel(required)
        if ~isfield(opts, required{k})
            error('missing --%s for this action', required{k});
        end
    end
end

function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
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
