function result = signal_fft(filepath)
% SIGNAL_FFT FFT spectrum analysis of audio file
%   CLI: ml signal file.wav --fft --json
    try
        [y, fs] = audioread(filepath);
        if size(y, 2) > 1, y = mean(y, 2); end
        N = length(y);
        Y = fft(y);
        P2 = abs(Y / N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2 * P1(2:end-1);
        f = fs * (0:(N/2)) / N;
        n_show = min(length(f), 1000);
        result = struct();
        result.frequency = f(1:n_show)';
        result.magnitude = P1(1:n_show)';
        result.sample_rate = fs;
        result.duration = N / fs;
        result.peak_freq = f(find(P1 == max(P1), 1));
    catch ME
        rethrow(ME);
    end
end
