function cli_color(action, varargin)
% CLI_COLOR Color theory for ml CLI
%   CLI: ml color convert   --r 255 --g 128 --b 0 --to hsl
%         ml color complement --hex "#FF8000"
%         ml color palette   --base "#3B82F6" --scheme analogous --count 5
%         ml color contrast  --bg "#FFFFFF" --fg "#000000"
%         ml color blend     --c1 "#FF0000" --c2 "#0000FF" --ratio 0.5
%         ml color name      --hex "#FF8000"
%
%   Options:
%     --r --g --b N     RGB values (0-255)
%     --h --s --l       HSL values (H 0-360, S/L 0-1 or 0-100)
%     --h --s --v       HSV values
%     --hex STR         hex color "#RRGGBB"
%     --to TARGET       hsl|hsv|cmyk
%     --base HEX        base color for palette
%     --scheme NAME     analogous|complementary|triadic|tetradic|monochromatic
%     --count N         palette size (default 5)
%     --bg HEX          background color
%     --fg HEX          foreground color
%     --c1 --c2 HEX     colors to blend
%     --ratio VAL       blend ratio (0-1, 0.5 = equal)
%     --format json|table|csv

    if nargin < 1, error('ml color <action> [options]'); end

    opts = struct('format','json','r',0,'g',0,'b',0,'h',0,'s',0,'l',0,'v',0, ...
                  'hex','','to','hsl','base','#3B82F6','scheme','analogous', ...
                  'count',5,'bg','#FFFFFF','fg','#000000', ...
                  'c1','#FF0000','c2','#0000FF','ratio',0.5);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--r',       opts.r = round(parse_num(varargin{i+1})); i=i+2;
            case '--g',       opts.g = round(parse_num(varargin{i+1})); i=i+2;
            case '--b',       opts.b = round(parse_num(varargin{i+1})); i=i+2;
            case '--h',       opts.h = parse_num(varargin{i+1}); i=i+2;
            case '--s',       opts.s = parse_num(varargin{i+1}); i=i+2;
            case '--l',       opts.l = parse_num(varargin{i+1}); i=i+2;
            case '--v',       opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--hex',     opts.hex = varargin{i+1}; i=i+2;
            case '--to',      opts.to = lower(varargin{i+1}); i=i+2;
            case '--base',    opts.base = varargin{i+1}; i=i+2;
            case '--scheme',  opts.scheme = lower(varargin{i+1}); i=i+2;
            case '--count',   opts.count = round(parse_num(varargin{i+1})); i=i+2;
            case '--bg',      opts.bg = varargin{i+1}; i=i+2;
            case '--fg',      opts.fg = varargin{i+1}; i=i+2;
            case '--c1',      opts.c1 = varargin{i+1}; i=i+2;
            case '--c2',      opts.c2 = varargin{i+1}; i=i+2;
            case '--ratio',   opts.ratio = parse_num(varargin{i+1}); i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'convert',    out = act_convert(opts);
            case 'complement', out = act_complement(opts);
            case 'palette',    out = act_palette(opts);
            case 'contrast',   out = act_contrast(opts);
            case 'blend',      out = act_blend(opts);
            case 'name',       out = act_name(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_convert(opts)
    % Accept RGB or hex, convert to target
    if ~isempty(opts.hex)
        [r, g, b] = hex2rgb(opts.hex);
    else
        r = opts.r; g = opts.g; b = opts.b;
    end
    hex = rgb2hex(r, g, b);
    out = struct();
    out.action = 'convert';
    out.input = struct('r',r,'g',g,'b',b,'hex',hex);
    switch opts.to
        case 'hsl'
            [h, s, l] = rgb2hsl(r, g, b);
            out.hsl = struct('h',h,'s',s,'l',l);
        case 'hsv'
            [h, s, v] = rgb2hsv_impl(r, g, b);
            out.hsv = struct('h',h,'s',s,'v',v);
        case 'cmyk'
            [c, m, y, k] = rgb2cmyk(r, g, b);
            out.cmyk = struct('c',c,'m',m,'y',y,'k',k);
        otherwise
            error('unknown target: %s (hsl|hsv|cmyk)', opts.to);
    end
end

function out = act_complement(opts)
    [r, g, b] = hex2rgb(opts.hex);
    cr = 255 - r;
    cg = 255 - g;
    cb = 255 - b;
    hex = rgb2hex(cr, cg, cb);
    [h, s, l] = rgb2hsl(r, g, b);
    [ch, cs, cl] = rgb2hsl(cr, cg, cb);
    out = struct();
    out.action = 'complement';
    out.original = struct('r',r,'g',g,'b',b,'hex',opts.hex);
    out.complement = struct('r',cr,'g',cg,'b',cb,'hex',hex);
    out.hueShift = mod(ch - h, 360);
end

function out = act_palette(opts)
    [r, g, b] = hex2rgb(opts.base);
    [h, s, l] = rgb2hsl(r, g, b);
    scheme = opts.scheme;
    n = opts.count;
    colors = {};
    switch scheme
        case 'analogous'
            for k = 0:n-1
                hk = mod(h + (k - floor(n/2))*30, 360);
                [rk, gk, bk] = hsl2rgb(hk, s, l);
                colors{k+1} = rgb2hex(rk, gk, bk);
            end
        case 'complementary'
            colors{1} = opts.base;
            [cr, cg, cb] = hsl2rgb(mod(h+180, 360), s, l);
            colors{2} = rgb2hex(cr, cg, cb);
            if n > 2
                for k = 2:n-1
                    hk = mod(h + k*360/(n-1), 360);
                    [rk, gk, bk] = hsl2rgb(hk, s, l);
                    colors{k+1} = rgb2hex(rk, gk, bk);
                end
            end
        case 'triadic'
            for k = 0:2
                hk = mod(h + k*120, 360);
                [rk, gk, bk] = hsl2rgb(hk, s, l);
                colors{k+1} = rgb2hex(rk, gk, bk);
            end
        case 'tetradic'
            for k = 0:3
                hk = mod(h + k*90, 360);
                [rk, gk, bk] = hsl2rgb(hk, s, l);
                colors{k+1} = rgb2hex(rk, gk, bk);
            end
        case 'monochromatic'
            for k = 0:n-1
                lk = max(0, min(1, l + (k - floor(n/2)) * 0.15));
                [rk, gk, bk] = hsl2rgb(h, s, lk);
                colors{k+1} = rgb2hex(rk, gk, bk);
            end
        otherwise
            error('unknown scheme: %s (analogous|complementary|triadic|tetradic|monochromatic)', scheme);
    end
    out = struct();
    out.action = 'palette';
    out.base = opts.base;
    out.scheme = scheme;
    out.colors = colors;
end

function out = act_contrast(opts)
    [br, bg, bb] = hex2rgb(opts.bg);
    [fr, fg, fb] = hex2rgb(opts.fg);
    % Relative luminance (WCAG 2.0)
    Lb = relative_luminance(br, bg, bb);
    Lf = relative_luminance(fr, fg, fb);
    % Contrast ratio
    if Lb > Lf
        ratio = (Lb + 0.05) / (Lf + 0.05);
    else
        ratio = (Lf + 0.05) / (Lb + 0.05);
    end
    wcagAA = ratio >= 4.5;
    wcagAAA = ratio >= 7;
    out = struct();
    out.action = 'contrast';
    out.background = opts.bg;
    out.foreground = opts.fg;
    out.contrastRatio = ratio;
    out.WCAG_AA_pass = wcagAA;
    out.WCAG_AAA_pass = wcagAAA;
end

function out = act_blend(opts)
    [r1, g1, b1] = hex2rgb(opts.c1);
    [r2, g2, b2] = hex2rgb(opts.c2);
    t = opts.ratio;
    r = round(r1 + t*(r2 - r1));
    g = round(g1 + t*(g2 - g1));
    b = round(b1 + t*(b2 - b1));
    out = struct();
    out.action = 'blend';
    out.color1 = opts.c1;
    out.color2 = opts.c2;
    out.ratio = t;
    out.result = rgb2hex(r, g, b);
    out.rgb = struct('r',r,'g',g,'b',b);
end

function out = act_name(opts)
    % Simple naming based on RGB thresholds
    [r, g, b] = hex2rgb(opts.hex);
    names = color_name(r, g, b);
    out = struct();
    out.action = 'name';
    out.hex = opts.hex;
    out.rgb = struct('r',r,'g',g,'b',b);
    out.names = names;
    out.bestMatch = names{1};
end

% =================== Color conversion ===================
function hex = rgb2hex(r, g, b)
    hex = sprintf('#%02X%02X%02X', max(0,min(255,round(r))), ...
                  max(0,min(255,round(g))), max(0,min(255,round(b))));
end

function [r, g, b] = hex2rgb(hex)
    hex = strtrim(regexprep(hex, '#', ''));
    if numel(hex) ~= 6
        error('hex color must be 6 digits');
    end
    r = hex2dec(hex(1:2));
    g = hex2dec(hex(3:4));
    b = hex2dec(hex(5:6));
end

function [h, s, l] = rgb2hsl(r, g, b)
    rn = r/255; gn = g/255; bn = b/255;
    mx = max([rn, gn, bn]);
    mn = min([rn, gn, bn]);
    l = (mx + mn) / 2;
    if mx == mn
        h = 0; s = 0;
    else
        d = mx - mn;
        if l > 0.5
            s = d / (2 - mx - mn);
        else
            s = d / (mx + mn);
        end
        if mx == rn
            h = mod((gn - bn)/d, 6);
        elseif mx == gn
            h = (bn - rn)/d + 2;
        else
            h = (rn - gn)/d + 4;
        end
        h = mod(h*60, 360);
    end
end

function [r, g, b] = hsl2rgb(h, s, l)
    h = mod(h, 360);
    s = max(0, min(1, s));
    l = max(0, min(1, l));
    if s == 0
        r = l; g = l; b = l;
    else
        if l < 0.5
            q = l * (1 + s);
        else
            q = l + s - l * s;
        end
        p = 2*l - q;
        r = hue2rgb(p, q, h/360 + 1/3);
        g = hue2rgb(p, q, h/360);
        b = hue2rgb(p, q, h/360 - 1/3);
    end
    r = round(r * 255);
    g = round(g * 255);
    b = round(b * 255);
end

function v = hue2rgb(p, q, t)
    if t < 0, t = t + 1; end
    if t > 1, t = t - 1; end
    if t < 1/6, v = p + (q-p)*6*t;
    elseif t < 1/2, v = q;
    elseif t < 2/3, v = p + (q-p)*(2/3 - t)*6;
    else, v = p; end
end

function [h, s, v] = rgb2hsv_impl(r, g, b)
    rn = r/255; gn = g/255; bn = b/255;
    mx = max([rn, gn, bn]);
    mn = min([rn, gn, bn]);
    v = mx;
    d = mx - mn;
    if mx == 0
        s = 0;
    else
        s = d / mx;
    end
    if d == 0
        h = 0;
    else
        if mx == rn
            h = mod((gn - bn)/d, 6) * 60;
        elseif mx == gn
            h = ((bn - rn)/d + 2) * 60;
        else
            h = ((rn - gn)/d + 4) * 60;
        end
    end
end

function [c, m, y, k] = rgb2cmyk(r, g, b)
    rn = r/255; gn = g/255; bn = b/255;
    k = 1 - max([rn, gn, bn]);
    if k == 1
        c = 0; m = 0; y = 0;
    else
        c = (1 - rn - k) / (1 - k);
        m = (1 - gn - k) / (1 - k);
        y = (1 - bn - k) / (1 - k);
    end
end

function L = relative_luminance(r, g, b)
    function v = linearize(c)
        s = c / 255;
        if s <= 0.03928
            v = s / 12.92;
        else
            v = ((s + 0.055) / 1.055)^2.4;
        end
    end
    L = 0.2126*linearize(r) + 0.7152*linearize(g) + 0.0722*linearize(b);
end

function names = color_name(r, g, b)
    % Named color matching via distance to known colors
    palette = struct( ...
        'red',       [255,0,0], 'green', [0,128,0], 'blue', [0,0,255], ...
        'yellow',    [255,255,0], 'cyan', [0,255,255], 'magenta', [255,0,255], ...
        'white',     [255,255,255], 'black', [0,0,0], 'gray', [128,128,128], ...
        'orange',    [255,165,0], 'pink', [255,192,203], 'purple', [128,0,128], ...
        'brown',     [165,42,42], 'navy', [0,0,128], 'teal', [0,128,128], ...
        'maroon',    [128,0,0], 'olive', [128,128,0], 'silver', [192,192,192], ...
        'lime',      [0,255,0], 'coral', [255,127,80], 'indigo', [75,0,130]);
    fns = fieldnames(palette);
    best = '';
    bestDist = inf;
    dists = zeros(numel(fns), 1);
    for k = 1:numel(fns)
        col = palette.(fns{k});
        dists(k) = sqrt((r-col(1))^2 + (g-col(2))^2 + (b-col(3))^2);
        if dists(k) < bestDist
            bestDist = dists(k);
            best = fns{k};
        end
    end
    % Return top 3 matches sorted
    [~, idx] = sort(dists);
    names = cell(min(3, numel(fns)), 1);
    for k = 1:min(3, numel(fns))
        names{k} = fns{idx(k)};
    end
end

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
