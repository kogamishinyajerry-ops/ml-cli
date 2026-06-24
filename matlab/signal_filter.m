function result = signal_filter(filepath, cutoff_freq)
% SIGNAL_FILTER Low-pass filter audio and return filtered signal
%   CLI: ml signal file.wav --filter 1000 --json
    [y, fs] = audioread(filepath);
    if size(y, 2) > 1, y = mean(y, 2); end

    [b, a] = butter(4, cutoff_freq/(fs/2), 'low');
    y_filtered = filter(b, a, y);

    result = struct();
    result.filter_type = 'lowpass';
    result.cutoff_hz = cutoff_freq;
    result.sample_rate = fs;
    result.original_length = length(y);
    result.filtered_length = length(y_filtered);
    result.attenuation_db = 20*log10(rms(y_filtered)/rms(y));
end

function r = rms(x)
    r = sqrt(mean(x.^2));
end
