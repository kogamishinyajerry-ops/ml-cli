%% {{NAME}} — Signal Filter Design Template
% 自动生成 by ml template filter
% 日期: {{DATE}}

clear; clc; close all;

%% 1. Create test signal
fs = 1000;                     % Sampling frequency [Hz]
T = 1;                          % Duration [s]
t = 0:1/fs:T-1/fs;
n = length(t);

% Composite signal: low-freq tone + high-freq noise
f_signal = 50;                  % Signal frequency [Hz]
f_noise = 300;                  % Noise frequency [Hz]
x = sin(2*pi*f_signal*t) + 0.3*sin(2*pi*f_noise*t) + 0.1*randn(1, n);

fprintf('Signal: fs=%d Hz, duration=%.1f s, samples=%d\n', fs, T, n);

%% 2. Frequency analysis
X = fft(x);
P2 = abs(X / n);
P1 = P2(1:floor(n/2)+1);
P1(2:end-1) = 2 * P1(2:end-1);
f = fs * (0:(n/2)) / n;

%% 3. Filter design
% Low-pass Butterworth filter
cutoff = 100;                   % Cutoff frequency [Hz]
order = 6;                      % Filter order
[b, a] = butter(order, cutoff/(fs/2), 'low');

% Apply filter
y = filtfilt(b, a, x);          % Zero-phase filtering

fprintf('Filter: Butterworth low-pass\n');
fprintf('  Order: %d\n', order);
fprintf('  Cutoff: %d Hz\n', cutoff);

%% 4. Compare before/after
Y = fft(y);
P2_y = abs(Y / n);
P1_y = P2_y(1:floor(n/2)+1);
P1_y(2:end-1) = 2 * P1_y(2:end-1);

figure('Name', 'Filter Results', 'Position', [100 100 1000 700]);

subplot(3, 1, 1);
plot(t(1:200), x(1:200), 'b-', 'DisplayName', 'Original');
hold on;
plot(t(1:200), y(1:200), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Filtered');
xlabel('Time [s]'); ylabel('Amplitude');
legend; grid on; title('Time Domain');

subplot(3, 1, 2);
plot(f(1:500), P1(1:500), 'b-', 'DisplayName', 'Original Spectrum');
hold on;
plot(f(1:500), P1_y(1:500), 'r-', 'DisplayName', 'Filtered Spectrum');
xline(cutoff, 'k--', 'Cutoff', 'LabelOrientation', 'horizontal');
xlabel('Frequency [Hz]'); ylabel('Magnitude');
legend; grid on; title('Frequency Domain');

subplot(3, 1, 3);
semilogy(f(1:500), P1_y(1:500), 'r-', 'LineWidth', 1);
xlabel('Frequency [Hz]'); ylabel('Log Magnitude');
grid on; title('Filtered Spectrum (Log Scale)');

saveas(gcf, 'filter_results.png'); close(gcf);

%% 5. Quantify results
noise_before = rms(x - sin(2*pi*f_signal*t));
noise_after  = rms(y - sin(2*pi*f_signal*t));
fprintf('\nResults:\n');
fprintf('  Noise before filter: %.4f\n', noise_before);
fprintf('  Noise after filter:  %.4f\n', noise_after);
fprintf('  Improvement:         %.1f dB\n', 20*log10(noise_before/noise_after));
fprintf('\nFiltering complete. Results saved to filter_results.png\n');
