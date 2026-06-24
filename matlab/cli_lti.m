function cli_lti(action, varargin)
% CLI_LTI Linear Time-Invariant system analysis for ml CLI
%   CLI: ml lti info    --tf "[1] / [1 0.5 1]"
%         ml lti poles  --tf "[1] / [1 0.5 1]"
%         ml lti step   --tf "[1] / [1 0.5 1]" --tfinal 30
%         ml lti bode   --tf "[1] / [1 0.5 1]" --wmin 0.01 --wmax 10 --npts 100
%         ml lti nyquist --tf "[1] / [1 0.5 1]"
%         ml lti margin --tf "[1] / [1 2 5 1]"
%         ml lti roots  --tf "[1] / [1 3 3 1]"
%
%   System spec:
%     --tf "num / den"   transfer function (e.g. "[1 2] / [1 3 5]")
%     --zpk "z:[1,2] p:[-1,-2] k:3"   zeros/poles/gain
%
%   Options:
%     --tfinal T        final time for step/impulse
%     --n N             number of points
%     --wmin W --wmax W --npts N   frequency grid
%     --w w1,w2,...     explicit frequency list (rad/s)
%     --plot FILE.png   render plot to file (headless)
%     --format json|table|csv   output format (default json)

    if nargin < 1, error('ml lti <action> [--tf spec] [options]'); end

    opts = struct('format','json','plot','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--tf',      opts.sys_spec = varargin{i+1}; opts.sys_type = 'tf'; i=i+2;
            case '--zpk',     opts.sys_spec = varargin{i+1}; opts.sys_type = 'zpk'; i=i+2;
            case '--tfinal',  opts.tfinal = parse_num(varargin{i+1}); i=i+2;
            case '--n',       opts.n = parse_num(varargin{i+1}); i=i+2;
            case '--wmin',    opts.wmin = parse_num(varargin{i+1}); i=i+2;
            case '--wmax',    opts.wmax = parse_num(varargin{i+1}); i=i+2;
            case '--npts',    opts.npts = parse_num(varargin{i+1}); i=i+2;
            case '--w',       opts.wlist = parse_vec(varargin{i+1}); i=i+2;
            case '--plot',    opts.plot = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        sys = build_sys(opts);
        switch lower(action)
            case 'info',    out = act_info(sys);
            case 'poles',   out = act_poles(sys);
            case 'step',    out = act_step(sys, opts);
            case 'bode',    out = act_bode(sys, opts);
            case 'nyquist', out = act_nyquist(sys, opts);
            case 'margin',  out = act_margin(sys);
            case 'roots',   out = act_roots(sys);
            otherwise,      error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== System construction ===================
function sys = build_sys(opts)
    if ~isfield(opts,'sys_spec'), error('system spec required: --tf "num/den" or --zpk'); end
    spec = opts.sys_spec;
    switch opts.sys_type
        case 'tf'
            sys = parse_tf(spec);
        case 'zpk'
            sys = parse_zpk(spec);
        otherwise
            error('unknown sys_type: %s', opts.sys_type);
    end
end

function sys = parse_tf(spec)
    % format: "[1 2] / [1 3 5]"  or "[1 2]/[1 3 5]"
    parts = regexp(spec, '/', 'split');
    if numel(parts) ~= 2, error('tf spec must be "num / den", got: %s', spec); end
    num = parse_bracket_vec(strtrim(parts{1}));
    den = parse_bracket_vec(strtrim(parts{2}));
    if isempty(num) || isempty(den), error('num or den empty'); end
    sys = tf(num, den);
end

function sys = parse_zpk(spec)
    % format: "z:[1,2] p:[-1,-2] k:3"
    z = []; p = []; k = 1;
    zMatch = regexp(spec, 'z:\s*\[([^\]]*)\]', 'tokens');
    if ~isempty(zMatch), z = parse_vec(zMatch{1}{1}); end
    pMatch = regexp(spec, 'p:\s*\[([^\]]*)\]', 'tokens');
    if ~isempty(pMatch), p = parse_vec(pMatch{1}{1}); end
    kMatch = regexp(spec, 'k:\s*([-\d.eE+]+)', 'tokens');
    if ~isempty(kMatch), k = str2double(kMatch{1}{1}); end
    sys = zpk(z, p, k);
end

% =================== Actions ===================
function s = act_info(sys)
    p = pole(sys);
    z = zero(sys);
    stable = all(real(p) < 0);
    s = struct();
    s.type = class(sys);
    s.ioDelay = sys.IODelay;
    s.ts = sys.Ts;
    s.sampling = ternary(sys.Ts==0, 'continuous', sprintf('discrete Ts=%.4g', sys.Ts));
    s.numPoles = numel(p);
    s.numZeros = numel(z);
    s.order = max(numel(p), numel(z));
    s.isStable = stable;
    s.dcgain = dcgain(sys);
end

function s = act_poles(sys)
    [wn, zeta, pv] = damp(sys);
    z = zero(sys);
    s = struct();
    s.poles = pv;
    s.naturalFreq = wn;
    s.dampingRatio = zeta;
    s.dampedFreq = sqrt(wn.^2 - (zeta.*wn).^2);
    s.real = real(pv);
    s.imag = imag(pv);
    s.zeros = z;
end

function s = act_step(sys, opts)
    if isfield(opts,'tfinal')
        tfinal = opts.tfinal;
    else
        tfinal = [];
    end
    [y, t] = step(sys, tfinal);
    info = stepinfo(y, t, y(end));
    s = struct();
    s.tfinal = t(end);
    s.npoints = numel(t);
    s.peakValue = info.Peak;
    s.peakTime = info.PeakTime;
    s.settlingTime = info.SettlingTime;
    s.riseTime = info.RiseTime;
    s.overshoot_pct = info.Overshoot;
    s.steadyState = y(end);
    s.dcGain = dcgain(sys);
    if strcmp(opts.plot,'') == 0
        fig = figure('Visible','off');
        step(sys, tfinal);
        exportgraphics(fig, opts.plot);
        close(fig);
    end
end

function s = act_bode(sys, opts)
    w = build_freq(opts);
    [mag, phase, wout] = bode(sys, w);
    mag = squeeze(mag); phase = squeeze(phase);
    s = struct();
    s.freq_radps = wout(:)';
    s.magnitude_db = 20*log10(mag(:));
    s.phase_deg = phase(:);
    % SISO margins
    try
        [Gm, Pm, Wcg, Wcp] = margin(sys);
        s.gainMargin_abs = Gm;
        s.gainMargin_dB = 20*log10(Gm);
        s.phaseMargin_deg = Pm;
        s.wGainCrossover = Wcp;
        s.wPhaseCrossover = Wcg;
    catch
    end
    if strcmp(opts.plot,'') == 0
        fig = figure('Visible','off');
        bode(sys, w);
        exportgraphics(fig, opts.plot);
        close(fig);
    end
end

function s = act_nyquist(sys, opts)
    w = build_freq(opts);
    [re, im, wout] = nyquist(sys, w);
    re = squeeze(re); im = squeeze(im);
    s = struct();
    s.freq_radps = wout(:)';
    s.real_part = re(:);
    s.imag_part = im(:);
    if strcmp(opts.plot,'') == 0
        fig = figure('Visible','off');
        nyquist(sys, w);
        exportgraphics(fig, opts.plot);
        close(fig);
    end
end

function s = act_margin(sys)
    [Gm, Pm, Wcg, Wcp] = margin(sys);
    s = struct();
    s.gainMargin_abs = Gm;
    s.gainMargin_dB = 20*log10(Gm);
    s.phaseMargin_deg = Pm;
    s.wGainCrossover_radps = Wcp;
    s.wPhaseCrossover_radps = Wcg;
end

function s = act_roots(sys)
    [num, den] = tfdata(sys, 'v');
    r = roots(den);
    s = struct();
    s.characteristicRoots = r;
    s.dampingRatio = [];
    s.naturalFreq = [];
    try
        [wn, zeta, pv] = damp(sys);
        s.dampingRatio = zeta;
        s.naturalFreq = wn;
        s.dampedFreq = sqrt(wn.^2 - (zeta.*wn).^2);
    catch
    end
end

% =================== Helpers ===================
function w = build_freq(opts)
    if isfield(opts,'wlist')
        w = opts.wlist;
    elseif isfield(opts,'wmin') && isfield(opts,'wmax')
        n = 100; if isfield(opts,'npts'), n = opts.npts; end
        w = logspace(log10(opts.wmin), log10(opts.wmax), n);
    else
        w = logspace(-2, 2, 100);
    end
end

function v = parse_bracket_vec(s)
    % s like "[1 2 3]" or "[1,2,3]"
    inner = regexp(s, '\[([^\]]*)\]', 'tokens');
    if isempty(inner), error('expected [v1 v2 ...], got: %s', s); end
    v = parse_vec(inner{1}{1});
end

function v = parse_vec(s)
    s = strtrim(s);
    s = strrep(s, ',', ' ');
    parts = strsplit(s, ' ');
    parts = parts(~cellfun(@(x) isempty(x) || ~any(str2double_or_nan(x) ~= -1e308), parts));
    nums = [];
    for k = 1:numel(parts)
        d = str2double_or_nan(parts{k});
        if d ~= -1e308, nums(end+1) = d; end %#ok<AGROW>
    end
    v = nums;
end

function d = str2double_or_nan(s)
    d = str2double(s);
    if isnan(d), d = -1e308; end
end

function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
