function cli_wavelet(action, varargin)
% CLI_WAVELET Wavelet analysis for ml CLI
%   CLI: ml wavelet dwt    --signal "1,2,3,4,..." --wavelet db4 --level 3
%         ml wavelet denoise --signal "..." --wavelet db4 --threshold 0.5
%         ml wavelet families
%         ml wavelet info --wavelet db4
%         ml wavelet cwt --signal "..." --wavelet morl --scales "1,2,3,5,8"
%
%   Options:
%     --signal "x1,x2,..."   input signal (comma-list)
%     --wavelet NAME         wavelet family (db4, sym3, haar, morl, mexh)
%     --level N              decomposition level
%     --threshold V          denoising threshold
%     --mode MODE            boundary handling (sym, per, zpd, sp0)
%     --format json|table|csv

    if nargin < 1, error('ml wavelet <action> [options]'); end

    opts = struct('format','json','wavelet','db4','level',3,'threshold',0.5,'mode','sym');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--signal',    opts.signal = varargin{i+1}; i=i+2;
            case '--wavelet',   opts.wavelet = varargin{i+1}; i=i+2;
            case '--level',     opts.level = round(parse_num(varargin{i+1})); i=i+2;
            case '--threshold', opts.threshold = parse_num(varargin{i+1}); i=i+2;
            case '--mode',      opts.mode = varargin{i+1}; i=i+2;
            case '--scales',    opts.scales = parse_vec(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    if ~license('test','Wavelet_Toolbox')
        error('Wavelet Toolbox license required');
    end

    try
        switch lower(action)
            case 'dwt',       out = act_dwt(opts);
            case 'denoise',   out = act_denoise(opts);
            case 'families',  out = act_families();
            case 'info',      out = act_info(opts);
            case 'cwt',       out = act_cwt(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_dwt(opts)
    s = get_signal(opts);
    wname = opts.wavelet;
    L = opts.level;
    [c, l] = wavedec(s, L, wname);
    % Extract approx + detail coeffs at each level
    approx = appcoef(c, l, wname);
    details = cell(1, L);
    for k = 1:L
        details{k} = detcoef(c, l, k);
    end
    out = struct();
    out.wavelet = wname;
    out.level = L;
    out.mode = evalc('dwtmode(''status'')');
    out.signalLength = numel(s);
    out.approximation = approx;
    out.details = details;
    out.energyOriginal = sum(s.^2);
    out.energyApprox = sum(approx.^2);
    detailEnergy = 0;
    for k = 1:L, detailEnergy = detailEnergy + sum(details{k}.^2); end
    out.energyDetails = detailEnergy;
    out.energyRatio = sum(approx.^2) / sum(s.^2);
end

function out = act_denoise(opts)
    s = get_signal(opts);
    wname = opts.wavelet;
    L = opts.level;
    thr = opts.threshold;
    % Universal threshold: sigma * sqrt(2*ln(N))
    if thr < 0
        cTmp = wavedec(s, L, wname);
        sigma = median(abs(cTmp)) / 0.6745;
        thr = sigma * sqrt(2*log(numel(s)));
        opts.threshold = thr;
    end
    [xs, ~, ~] = wdenoise(s, L, 'Wavelet', wname, ...
        'DenoisingMethod','UniversalThreshold');
    % Also do manual hard-threshold for comparison
    xd = wthresh(s, 'h', thr);
    out = struct();
    out.wavelet = wname;
    out.level = L;
    out.threshold = thr;
    out.method = 'universal threshold (hard)';
    out.signalLength = numel(s);
    out.original = s;
    out.denoised = xd;
    out.smoothed = xs;
    out.noiseRemoved = s - xd;
    out.rmse = sqrt(mean((s - xd).^2));
    out.snr_dB = 10*log10(sum(s.^2) / sum((s - xd).^2 + eps));
end

function out = act_families()
    families = {'haar','db','sym','coif','bior','rbio','dmey','mexh','morl','cgau','shan','fbsp','cmor'};
    descriptions = struct();
    descriptions.haar = 'Daubechies order 1 (Haar)';
    descriptions.db   = 'Daubechies';
    descriptions.sym  = 'Symlets';
    descriptions.coif = 'Coiflets';
    descriptions.bior = 'Biorthogonal';
    descriptions.rbio = 'Reverse biorthogonal';
    descriptions.dmey = 'Discrete Meyer';
    descriptions.mexh = 'Mexican hat';
    descriptions.morl = 'Morlet';
    descriptions.cgau = 'Complex Gaussian';
    descriptions.shan = 'Shannon';
    descriptions.fbsp = 'Frequency B-spline';
    descriptions.cmor = 'Complex Morlet';
    members = cell(1, numel(families));
    for k = 1:numel(families)
        fn = families{k};
        try
            if ismember(fn, {'mexh','morl','cgau','shan','fbsp','cmor'})
                [~, ~, ~] = wavefun(fn, 1);
                members{k} = fn;  % single member
            else
                % list orders 1..10 for orthogonal, check which exist
                orders = [];
                for n = 1:10
                    try
                        [~, ~, ~] = wavefun([fn num2str(n)], 1);
                        orders(end+1) = n; %#ok<AGROW>
                    catch
                    end
                end
                members{k} = orders;
            end
        catch
            members{k} = [];
        end
    end
    out = struct();
    out.family = families;
    out.description = cellfun(@describe_family, families, 'UniformOutput', false);
    out.orders = members;
end

function d = describe_family(f)
    switch f
        case 'haar', d='Daubechies order 1 (Haar)';
        case 'db',   d='Daubechies';
        case 'sym',  d='Symlets';
        case 'coif', d='Coiflets';
        case 'bior', d='Biorthogonal';
        case 'rbio', d='Reverse biorthogonal';
        case 'dmey', d='Discrete Meyer';
        case 'mexh', d='Mexican hat';
        case 'morl', d='Morlet';
        case 'cgau', d='Complex Gaussian';
        case 'shan', d='Shannon';
        case 'fbsp', d='Frequency B-spline';
        case 'cmor', d='Complex Morlet';
        otherwise,   d='Unknown';
    end
end

function out = act_info(opts)
    wname = opts.wavelet;
    [phi, psi, xval] = wavefun(wname, 10);
    % waveinfo needs family short name (e.g. 'db' not 'db4'); extract letters
    famName = regexprep(wname, '\d.*$', '');
    infoStr = '';
    try, infoStr = evalc(sprintf('waveinfo(''%s'')', famName)); catch, end
    out = struct();
    out.wavelet = wname;
    out.family = famName;
    out.infoText = strtrim(infoStr);
    out.supportLength = numel(xval);
    out.scalingFunction = phi;
    out.waveletFunction = psi;
    % Orthogonal?
    try
        ortho = 'yes';
        [Lo_D,Hi_D,Lo_R,Hi_R] = orthfilt(phi); %#ok<ASGLU>
    catch
        ortho = 'no';
    end
    out.orthogonal = ortho;
end

function out = act_cwt(opts)
    s = get_signal(opts);
    wname = opts.wavelet;
    if ~isfield(opts,'scales')
        scales = 1:32;
    else
        scales = opts.scales;
    end
    coef = cwt(s, scales, wname);
    out = struct();
    out.wavelet = wname;
    out.numScales = numel(scales);
    out.scales = scales;
    out.signalLength = numel(s);
    out.coefficients = coef;
    out.maxMagnitude = max(abs(coef(:)));
end

% =================== Helpers ===================
function s = get_signal(opts)
    if ~isfield(opts,'signal'), error('need --signal "x1,x2,..."'); end
    s = parse_vec(opts.signal);
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
