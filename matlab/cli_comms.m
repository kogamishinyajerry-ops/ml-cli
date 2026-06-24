function cli_comms(action, varargin)
% CLI_COMMS Digital communications analysis for ml CLI
%   CLI: ml comms modulate --scheme qam16 --bits "1010..."
%         ml comms demod   --scheme qam16 --rx <vector>
%         ml comms ber     --scheme psk8 --snr 0:10
%         ml comms eye     --scheme bpsk --nsamp 100
%         ml comms channel --snr 10 --type awgn --signal <vector>
%         ml comms spectrum --scheme qpsk --nsymb 100 --fs 1
%
%   Options:
%     --scheme NAME   bpsk|qpsk|psk8|psk16|qam16|qam64|qam256|fsk2|fsk4
%     --bits STR      bit string for modulation (e.g. "10101011")
%     --rx VEC        received symbol vector for demod
%     --snr dB        SNR in dB (scalar or vector for ber sweep)
%     --nsymb N       number of symbols for BER sim (default 1000)
%     --nsamp N       samples per symbol for eye/spectrum (default 100)
%     --type NAME     awgn|rayleigh (channel type)
%     --signal VEC    input signal for channel
%     --fs Hz         sample rate for spectrum (default 1)
%     --out PATH      save plot
%     --format json|table|csv

    if nargin < 1, error('ml comms <action> [options]'); end

    opts = struct('format','json','scheme','qam16','bits','','rx','', ...
                  'snr',10,'nsymb',1000,'nsamp',100, ...
                  'type','awgn','signal','','fs',1,'out','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--scheme',   opts.scheme = lower(varargin{i+1}); i=i+2;
            case '--bits',     opts.bits = varargin{i+1}; i=i+2;
            case '--rx',       opts.rx = varargin{i+1}; i=i+2;
            case '--snr',      opts.snr = parse_num(varargin{i+1}); i=i+2;
            case '--nsymb',    opts.nsymb = round(parse_num(varargin{i+1})); i=i+2;
            case '--nsamp',    opts.nsamp = round(parse_num(varargin{i+1})); i=i+2;
            case '--type',     opts.type = lower(varargin{i+1}); i=i+2;
            case '--signal',   opts.signal = varargin{i+1}; i=i+2;
            case '--fs',       opts.fs = parse_num(varargin{i+1}); i=i+2;
            case '--out',      opts.out = varargin{i+1}; i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    hasCommsTB = exist('qammod','file') == 2;

    try
        switch lower(action)
            case 'modulate',  out = act_modulate(opts, hasCommsTB);
            case 'demod',     out = act_demod(opts, hasCommsTB);
            case 'ber',       out = act_ber(opts, hasCommsTB);
            case 'eye',       out = act_eye(opts, hasCommsTB);
            case 'channel',   out = act_channel(opts, hasCommsTB);
            case 'spectrum',  out = act_spectrum(opts, hasCommsTB);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== M-ary helpers ===================
function [M, k] = scheme_M(opts)
    switch opts.scheme
        case 'bpsk',  M = 2;  k = 1;
        case 'qpsk',  M = 4;  k = 2;
        case 'psk8',  M = 8;  k = 3;
        case 'psk16', M = 16; k = 4;
        case 'qam16', M = 16; k = 4;
        case 'qam64', M = 64; k = 6;
        case 'qam256',M = 256;k = 8;
        case 'fsk2',  M = 2;  k = 1;
        case 'fsk4',  M = 4;  k = 2;
        otherwise,    error('unknown scheme: %s', opts.scheme);
    end
end

function bits = parse_bits(s)
    if ischar(s) || isstring(s)
        bits = sscanf(s, '%1d')';
    else
        bits = s(:)';
    end
    if any(bits ~= 0 & bits ~= 1)
        error('bits must be 0/1 string');
    end
end

function data = bits_to_data(bits, k)
    % Group bits into k-tuples → integers 0..M-1
    n = floor(numel(bits) / k);
    bits = bits(1:n*k);
    mat = reshape(bits, k, n)';
    data = bi2de_local(mat, 'left-msb');
end

function out_bits = data_to_bits(data, k)
    n = numel(data);
    mat = de2bi_local(data, k, 'left-msb');
    out_bits = reshape(mat', 1, n*k);
end

function d = bi2de_local(b, ~)
    % b: n×k matrix of bits, MSB first
    [n, k] = size(b);
    d = zeros(1, n);
    for j = 1:k
        d = d + b(:,j)' * 2^(k-j);
    end
end

function b = de2bi_local(d, k, ~)
    n = numel(d);
    b = zeros(n, k);
    for i = 1:n
        v = d(i);
        for j = 1:k
            b(i, j) = floor(v / 2^(k-j));
            v = v - b(i,j) * 2^(k-j);
        end
    end
end

% =================== Modulation core ===================
function y = modulate_core(data, scheme, M)
    switch scheme
        case 'bpsk'
            y = exp(1i * pi * data);   % 0 -> +1, 1 -> -1
        case {'qpsk','psk8','psk16'}
            y = exp(1i * 2*pi*data / M);
        case {'qam16','qam64','qam256'}
            y = qammod_local(data, M);
        case {'fsk2','fsk4'}
            % tones at freqs 0..M-1
            y = exp(1i * 2*pi * data);
    end
end

function r = data_range(M)
    switch M
        case 4,  r = [-1, 1];
        case 16, r = [-3, 3];
        case 64, r = [-7, 7];
        case 256,r = [-15, 15];
        otherwise, r = [-1, 1];
    end
end

function y = qammod_local(data, M)
    % Rectangular QAM
    k = round(log2(M));
    side = sqrt(M);
    if side ~= floor(side)
        % Non-square QAM (rare here) — fallback
        side = ceil(sqrt(M));
    end
    I_levels = -floor(side/2) : ceil(side/2)-1;
    Q_levels = -floor(side/2) : ceil(side/2)-1;
    % Map data -> (I, Q)
    I = zeros(size(data));
    Q = zeros(size(data));
    for n = 1:numel(data)
        d = data(n);
        i_idx = floor(d / side);
        q_idx = mod(d, side);
        I(n) = I_levels(i_idx + 1);
        Q(n) = Q_levels(q_idx + 1);
    end
    y = I + 1i * Q;
    % Normalize to unit average power
    avgPow = mean(abs(y).^2);
    y = y / sqrt(avgPow);
end

% =================== Demodulation core ===================
function data = demod_core(y, scheme, M)
    switch scheme
        case 'bpsk'
            data = double(real(y) < 0);
        case {'qpsk','psk8','psk16'}
            angles = mod(angle(y), 2*pi);
            data = round(angles / (2*pi/M));
            data = mod(data, M);
        case {'qam16','qam64','qam256'}
            data = qamdemod_local(y, M);
        case {'fsk2','fsk4'}
            data = round(angle(y) / (2*pi));
            data = mod(data, M);
    end
end

function data = qamdemod_local(y, M)
    side = round(sqrt(M));
    if side^2 ~= M, error('non-square QAM demod unsupported'); end
    I_levels = -floor(side/2) : ceil(side/2)-1;
    avgPow = mean(abs(y).^2);
    y = y * sqrt(side^2 - 1) / 3;  % approximate denormalize (rectangular)
    % Build reference constellation
    ref = qammod_local(0:M-1, M);
    data = zeros(size(y));
    for n = 1:numel(y)
        [~, idx] = min(abs(y(n) - ref));
        data(n) = idx - 1;
    end
end

% =================== Actions ===================
function out = act_modulate(opts, hasCommsTB)
    [M, k] = scheme_M(opts);
    bits = parse_bits(opts.bits);
    if numel(bits) < k, error('need at least %d bits for %s', k, opts.scheme); end
    data = bits_to_data(bits, k);
    if hasCommsTB && startsWith(opts.scheme, {'qpsk','psk','qam'})
        if strcmp(opts.scheme(1:3), 'qam')
            y = qammod(data, M, 'UnitAveragePower', true);
        else
            y = pskmod(data, M);
        end
    else
        y = modulate_core(data, opts.scheme, M);
    end
    out = struct();
    out.scheme = opts.scheme;
    out.M = M;
    out.bitsPerSymbol = k;
    out.inputBits = bits;
    out.inputData = data;
    out.symbols = y;
    out.averagePower = mean(abs(y).^2);
end

function out = act_demod(opts, hasCommsTB)
    [M, k] = scheme_M(opts);
    if isempty(opts.rx), error('--rx required (complex vector)'); end
    y = parse_vec_complex(opts.rx);
    if hasCommsTB && startsWith(opts.scheme, {'qpsk','psk','qam'})
        if strcmp(opts.scheme(1:3), 'qam')
            data = qamdemod(y, M, 'UnitAveragePower', true);
        else
            data = pskdemod(y, M);
        end
    else
        data = demod_core(y, opts.scheme, M);
    end
    bits = data_to_bits(data, k);
    out = struct();
    out.scheme = opts.scheme;
    out.M = M;
    out.demodulatedData = data;
    out.demodulatedBits = bits;
end

function out = act_ber(opts, hasCommsTB)
    [M, k] = scheme_M(opts);
    snr_vec = opts.snr;
    if numel(snr_vec) == 1
        snr_vec = snr_vec : snr_vec;  % single point
    end
    nsym = opts.nsymb;
    nbits_per_sym = k;
    ber = zeros(size(snr_vec));
    for s = 1:numel(snr_vec)
        snr_db = snr_vec(s);
        % Random bits
        bits = randi([0 1], 1, nsym * nbits_per_sym);
        data = bits_to_data(bits, k);
        % Modulate
        if hasCommsTB && startsWith(opts.scheme, {'qpsk','psk','qam'})
            if strcmp(opts.scheme(1:3), 'qam')
                tx = qammod(data, M, 'UnitAveragePower', true);
            else
                tx = pskmod(data, M);
            end
        else
            tx = modulate_core(data, opts.scheme, M);
        end
        % AWGN
        sigPower = mean(abs(tx).^2);
        noisePower = sigPower / (10^(snr_db/10));
        noise = sqrt(noisePower/2) * (randn(size(tx)) + 1i*randn(size(tx)));
        rx = tx + noise;
        % Demod
        if hasCommsTB && startsWith(opts.scheme, {'qpsk','psk','qam'})
            if strcmp(opts.scheme(1:3), 'qam')
                data_hat = qamdemod(rx, M, 'UnitAveragePower', true);
            else
                data_hat = pskdemod(rx, M);
            end
        else
            data_hat = demod_core(rx, opts.scheme, M);
        end
        bits_hat = data_to_bits(data_hat, k);
        % BER
        if hasCommsTB
            [~, ber(s)] = biterr(bits, bits_hat);
        else
            ber(s) = mean(bits ~= bits_hat);
        end
    end
    out = struct();
    out.scheme = opts.scheme;
    out.M = M;
    out.numSymbols = nsym;
    out.snr_dB = snr_vec;
    out.BER = ber;
    out.theoryFloor = 1/M;  % crude approximation
end

function out = act_eye(opts, hasCommsTB)
    [M, k] = scheme_M(opts);
    nsamp = opts.nsamp;
    % Generate random bits, modulate, oversample
    nsym = 50;
    bits = randi([0 1], 1, nsym * k);
    data = bits_to_data(bits, k);
    tx = modulate_core(data, opts.scheme, M);
    % Rectangular pulse shaping (each symbol repeated nsamp times)
    sig = repelem(tx, nsamp);
    t = (0:numel(sig)-1) / nsamp;
    out = struct();
    out.scheme = opts.scheme;
    out.nsamp = nsamp;
    out.time = t(1:nsamp*5);   % show first 5 symbols
    out.voltage_real = real(sig(1:nsamp*5));
    out.voltage_imag = imag(sig(1:nsamp*5));
end

function out = act_channel(opts, hasCommsTB)
    if isempty(opts.signal), error('--signal required'); end
    x = parse_vec_complex(opts.signal);
    snr_db = opts.snr;
    switch opts.type
        case 'awgn'
            if hasCommsTB
                y = awgn(x, snr_db, 'measured');
            else
                sigPower = mean(abs(x).^2);
                noisePower = sigPower / (10^(snr_db/10));
                noise = sqrt(noisePower/2) * (randn(size(x)) + 1i*randn(size(x)));
                y = x + noise;
            end
            channelInfo = 'AWGN';
        case 'rayleigh'
            h = (randn(size(x)) + 1i*randn(size(x))) / sqrt(2);
            if hasCommsTB
                y = awgn(h.*x, snr_db, 'measured');
            else
                sigPower = mean(abs(h.*x).^2);
                noisePower = sigPower / (10^(snr_db/10));
                noise = sqrt(noisePower/2) * (randn(size(x)) + 1i*randn(size(x)));
                y = h.*x + noise;
            end
            channelInfo = 'Rayleigh';
        otherwise
            error('unknown channel: %s', opts.type);
    end
    out = struct();
    out.channelType = channelInfo;
    out.snr_dB = snr_db;
    out.inputSignal = x;
    out.outputSignal = y;
    out.signalPowerIn = mean(abs(x).^2);
    out.signalPowerOut = mean(abs(y).^2);
end

function out = act_spectrum(opts, hasCommsTB)
    [M, k] = scheme_M(opts);
    nsymb = 100;
    bits = randi([0 1], 1, nsymb * k);
    data = bits_to_data(bits, k);
    tx = modulate_core(data, opts.scheme, M);
    % Rectangular pulse shape
    nsamp = opts.nsamp;
    sig = repelem(tx, nsamp);
    % PSD via FFT
    N = numel(sig);
    fx = fftshift(fft(sig) / N);
    psd = abs(fx).^2;
    f = (-N/2:N/2-1) / N * opts.fs;
    out = struct();
    out.scheme = opts.scheme;
    out.fs = opts.fs;
    out.numSamples = N;
    out.freq = f;
    out.psd = psd;
    out.peakFreq = f(find(psd == max(psd), 1));
    out.bandwidth_3dB = measure_bw(f, psd);
end

function bw = measure_bw(f, psd)
    pk = max(psd);
    threshold = pk / 2;
    above = psd >= threshold;
    if any(above)
        bw = f(find(above, 1, 'last')) - f(find(above, 1, 'first'));
    else
        bw = 0;
    end
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; return; end
    v = sscanf(s, '%f');
    if isempty(v) || any(~isfinite(v))
        v = str2double(s);
    end
    if numel(v) == 1, v = v(1); end
end

function v = parse_vec_complex(s)
    if ischar(s) || isstring(s)
        v = eval(s);
    else
        v = s;
    end
    v = v(:)';
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
