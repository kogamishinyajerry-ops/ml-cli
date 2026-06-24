function result = signal_psd(filepath)
% SIGNAL_PSD Power Spectral Density (Welch method)
%   CLI: ml signal file.wav --psd --json
    try
        [y, fs] = audioread(filepath);
    catch
        error('Cannot read file: %s', filepath);
    end

    if size(y, 2) > 1, y = mean(y, 2); end

    % Welch PSD
    [pxx, f] = pwelch(y, hamming(256), 128, 512, fs);

    n_show = min(length(f), 500);
    result = struct();
    result.frequency = f(1:n_show)';
    result.power = pxx(1:n_show)';
    result.sample_rate = fs;
    result.total_power = sum(pxx) * (f(2)-f(1));
end
