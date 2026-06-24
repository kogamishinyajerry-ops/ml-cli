function cli_audio(action, varargin)
% CLI_AUDIO Audio analysis for ml CLI
%   CLI: ml audio info       <file.wav>
%         ml audio spectrogram <file.wav> --nfft 512
%         ml audio pitch     <file.wav> --fmin 80 --fmax 400
%         ml audio formant   <file.wav> --numformants 3
%         ml audio noise     <file.wav> --method wiener
%         ml audio synth     --freq 440 --dur 1 --type sine --fs 44100
%
%   Options:
%     --nfft N        FFT length (default 512)
%     --window N      window length (default nfft)
%     --overlap N     overlap (default nfft/2)
%     --fmin Hz       min pitch (default 80)
%     --fmax Hz       max pitch (default 400)
%     --method NAME   wiener|spectral (default wiener)
%     --numformants N formant count (default 3)
%     --order N       LPC order (default 10)
%     --freq Hz       synth frequency (default 440)
%     --dur S         duration in seconds (default 1)
%     --fs Hz         sample rate (default 44100)
%     --type NAME     sine|chirp|square|saw (default sine)
%     --f1 Hz         chirp start (default 100)
%     --f2 Hz         chirp end (default 2000)
%     --out PATH      output file
%     --format json|table|csv

    if nargin < 1, error('ml audio <action> [options]'); end

    opts = struct('format','json','nfft',512,'window',512,'overlap',256, ...
                  'fmin',80,'fmax',400,'method','wiener', ...
                  'numformants',3,'order',10, ...
                  'freq',440,'dur',1,'fs',44100,'type','sine', ...
                  'f1',100,'f2',2000,'file','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--nfft',        opts.nfft = round(parse_num(varargin{i+1})); i=i+2;
            case '--window',      opts.window = round(parse_num(varargin{i+1})); i=i+2;
            case '--overlap',     opts.overlap = round(parse_num(varargin{i+1})); i=i+2;
            case '--fmin',        opts.fmin = parse_num(varargin{i+1}); i=i+2;
            case '--fmax',        opts.fmax = parse_num(varargin{i+1}); i=i+2;
            case '--method',      opts.method = varargin{i+1}; i=i+2;
            case '--numformants', opts.numformants = round(parse_num(varargin{i+1})); i=i+2;
            case '--order',       opts.order = round(parse_num(varargin{i+1})); i=i+2;
            case '--freq',        opts.freq = parse_num(varargin{i+1}); i=i+2;
            case '--dur',         opts.dur = parse_num(varargin{i+1}); i=i+2;
            case '--fs',          opts.fs = parse_num(varargin{i+1}); i=i+2;
            case '--type',        opts.type = varargin{i+1}; i=i+2;
            case '--f1',          opts.f1 = parse_num(varargin{i+1}); i=i+2;
            case '--f2',          opts.f2 = parse_num(varargin{i+1}); i=i+2;
            case '--out',         opts.out = varargin{i+1}; i=i+2;
            case '--format',      opts.format = varargin{i+1}; i=i+2;
            otherwise,            opts.file = tok; i=i+1;
        end
    end

    try
        switch lower(action)
            case 'info',        out = act_info(opts);
            case 'spectrogram', out = act_spectrogram(opts);
            case 'pitch',       out = act_pitch(opts);
            case 'formant',     out = act_formant(opts);
            case 'noise',       out = act_noise(opts);
            case 'synth',       out = act_synth(opts);
            otherwise,          error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Read audio file ===================
function [x, fs] = read_audio(opts)
    if isempty(opts.file), error('audio file required'); end
    [x, fs] = audioread(opts.file);
    if size(x,2) > 1, x = mean(x, 2); end  % to mono
end

% =================== Actions ===================
function out = act_info(opts)
    info = audioinfo(opts.file);
    out = struct();
    out.fileName = info.Filename;
    out.sampleRate_Hz = info.SampleRate;
    out.numChannels = info.NumChannels;
    out.numSamples = info.TotalSamples;
    out.duration_s = info.Duration;
    out.bitsPerSample = info.BitsPerSample;
    out.compressionMethod = info.CompressionMethod;
end

function out = act_spectrogram(opts)
    [x, fs] = read_audio(opts);
    nfft = opts.nfft;
    win = opts.window;
    noverlap = opts.overlap;
    if win == nfft
        win = hamming(nfft);
    else
        win = hamming(win);
    end
    [S, F, T] = spectrogram(x, win, noverlap, nfft, fs);
    P = 20*log10(abs(S) + eps);
    out = struct();
    out.fileName = opts.file;
    out.nfft = nfft;
    out.numFrames = numel(T);
    out.freq_Hz = F';
    out.time_s = T';
    out.power_dB = P;
    out.peakFreq_Hz = F(find(mean(P,2)==max(mean(P,2)),1));
    out.spectralCentroid_Hz = sum(F.*mean(P,2)') / sum(mean(P,2)');
end

function out = act_pitch(opts)
    [x, fs] = read_audio(opts);
    if exist('pitch','file') == 2
        % Audio Toolbox pitch()
        f0 = pitch(x, fs, 'Range', [opts.fmin, opts.fmax]);
    else
        % Autocorrelation fallback
        f0 = pitch_autocorr(x, fs, opts.fmin, opts.fmax);
    end
    out = struct();
    out.fileName = opts.file;
    out.f0_Hz = f0;
    out.meanF0_Hz = mean(f0(isfinite(f0)));
    out.medianF0_Hz = median(f0(isfinite(f0)));
    out.fmin = opts.fmin;
    out.fmax = opts.fmax;
    out.numFrames = numel(f0);
end

function out = act_formant(opts)
    [x, fs] = read_audio(opts);
    % LPC-based formant estimation
    order = opts.order;
    frameLen = round(0.03 * fs);  % 30 ms
    overlap = round(0.02 * fs);
    hop = frameLen - overlap;
    numFrames = max(1, floor((numel(x) - overlap) / hop));
    formants = zeros(numFrames, opts.numformants);
    for k = 1:numFrames
        idx_start = (k-1)*hop + 1;
        idx_end = min(idx_start + frameLen - 1, numel(x));
        frame = x(idx_start:idx_end);
        frame = frame .* hamming(numel(frame));
        if numel(frame) <= order, continue; end
        [a, g] = lpc(frame, order);
        r = roots(a);
        r = r(imag(r) > 0);
        freqs = atan2(imag(r), real(r)) * fs / (2*pi);
        bw = -log(abs(r)) * fs / pi;
        % Keep reasonable formants
        mask = (freqs > 90) & (freqs < fs/2 - 500) & (bw < 400);
        freqs = freqs(mask);
        bw = bw(mask);
        [freqs, idx] = sort(freqs);
        bw = bw(idx);
        for j = 1:min(opts.numformants, numel(freqs))
            formants(k, j) = freqs(j);
        end
    end
    out = struct();
    out.fileName = opts.file;
    out.numFormants = opts.numformants;
    out.numFrames = numFrames;
    out.formantFreqs_Hz = formants;
    out.meanFormants_Hz = mean(formants, 1);
end

function out = act_noise(opts)
    [x, fs] = read_audio(opts);
    method = lower(opts.method);
    switch method
        case 'wiener'
            % spectral Wiener filtering vialowpass smoothing
            frameLen = round(0.02 * fs);
            y = zeros(size(x));
            win = hamming(frameLen);
            for k = 1:frameLen/2:numel(x)-frameLen
                idx = k:min(k+frameLen-1, numel(x));
                frame = x(idx) .* win(1:numel(idx));
                X = fft(frame, frameLen);
                mag = abs(X);
                % Estimate noise floor from min across time (crude)
                noise_floor = min(mag) * 0.5;
                gain = max(0, 1 - (noise_floor ./ (mag + eps)));
                Y = X .* gain;
                frame_clean = real(ifft(Y, frameLen));
                y(idx) = y(idx) + frame_clean(1:numel(idx));
            end
        case 'spectral'
            % Simple spectral subtraction
            frameLen = round(0.02 * fs);
            y = zeros(size(x));
            win = hamming(frameLen);
            % Noise estimate from first 100ms
            noiseLen = min(round(0.1*fs), numel(x));
            noiseFrame = x(1:noiseLen) .* hamming(noiseLen);
            N = abs(fft(noiseFrame, frameLen));
            for k = 1:frameLen/2:numel(x)-frameLen
                idx = k:min(k+frameLen-1, numel(x));
                frame = x(idx) .* win(1:numel(idx));
                X = fft(frame, frameLen);
                mag = abs(X);
                phase = angle(X);
                mag_clean = max(0, mag - 0.5*N(1:numel(mag)));
                Y = mag_clean .* exp(1i*phase);
                frame_clean = real(ifft(Y, frameLen));
                y(idx) = y(idx) + frame_clean(1:numel(idx));
            end
        otherwise
            error('unknown method: %s (try wiener|spectral)', method);
    end
    % SNR estimate
    sig_power = mean(x.^2);
    noise_est = mean((x-y).^2);
    snr = 10*log10(sig_power / (noise_est + eps));
    out = struct();
    out.fileName = opts.file;
    out.method = method;
    out.inputPower = sig_power;
    out.residualNoise = noise_est;
    out.estimatedSNR_dB = snr;
    if isfield(opts, 'out')
        audiowrite(opts.out, y, fs);
        out.outputFile = opts.out;
    end
end

function out = act_synth(opts)
    fs = opts.fs;
    dur = opts.dur;
    t = (0:1/fs:dur)';
    type = lower(opts.type);
    switch type
        case 'sine'
            x = sin(2*pi*opts.freq*t);
        case 'square'
            x = square(2*pi*opts.freq*t);
        case 'saw'
            x = 2*(opts.freq*t - floor(0.5 + opts.freq*t));
        case 'chirp'
            x = chirp(t, opts.f1, dur, opts.f2);
        otherwise
            error('unknown synth type: %s (try sine|square|saw|chirp)', type);
    end
    % Normalize
    x = x / max(abs(x)) * 0.9;
    out = struct();
    out.type = type;
    out.frequency_Hz = opts.freq;
    out.duration_s = dur;
    out.sampleRate_Hz = fs;
    out.numSamples = numel(x);
    out.rms = rms(x);
    if isfield(opts, 'out')
        audiowrite(opts.out, x, fs);
        out.outputFile = opts.out;
    end
end

% =================== Pitch autocorrelation fallback ===================
function f0 = pitch_autocorr(x, fs, fmin, fmax)
    frameLen = round(0.04 * fs);
    hop = round(0.02 * fs);
    lagMin = round(fs / fmax);
    lagMax = round(fs / fmin);
    numFrames = floor((numel(x) - frameLen) / hop) + 1;
    f0 = zeros(numFrames, 1);
    for k = 1:numFrames
        idx = (k-1)*hop + (1:frameLen);
        frame = x(idx) .* hamming(frameLen);
        ac = xcorr(frame, lagMax);
        % ac is centered at lagMax+1
        seg = ac(lagMax+1+lagMin : lagMax+1+lagMax);
        [pk, loc] = max(seg);
        lag = lagMin + loc - 1;
        if pk > 0.3 * ac(lagMax+1)
            f0(k) = fs / lag;
        else
            f0(k) = NaN;
        end
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
