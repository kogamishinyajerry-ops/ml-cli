#!/bin/bash
# =============================================================================
# Full Demo: Motor Vibration Analysis
# 全程 ml CLI 操作:创建数据→加载→分析→建模仿真→可视化→报告
# =============================================================================

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$PATH"
export PROJECT="/tmp/ml_demo_project"
rm -rf "$PROJECT"
mkdir -p "$PROJECT"/{data,results}

echo "╔══════════════════════════════════════╗"
echo "║  Motor Vibration Analysis Pipeline   ║"
echo "║  Pure CLI — No MATLAB IDE           ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ═══ 1. Generate synthetic vibration data ═══
echo "━━━ Step 1: Generate Data ━━━"
cat << 'GEN' | ml eval
fs=1000; t=0:1/fs:5-1/fs; N=length(t);
f0=50; f_harm=150; f_noise=300;
x=sin(2*pi*f0*t)+0.3*sin(2*pi*f_harm*t)+0.05*randn(1,N);
data=[t' x'];
writematrix(data,'/tmp/ml_demo_project/data/vibration.csv');
fprintf('Generated: %d samples at %d Hz\n',N,fs);
fprintf('Freq: %d + %d Hz harmonics\n',f0,f_harm);
GEN
echo ""

# ═══ 2. Statistical analysis ═══
echo "━━━ Step 2: Statistical Analysis ━━━"
ml stats "$PROJECT/data/vibration.csv" --json 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
c = d['columns'][1]  # vibration column
print(f'  Samples: {c[\"count\"]}')
print(f'  Mean:    {c[\"mean\"]:.4f}')
print(f'  RMS:     {c[\"std\"]:.4f}')
print(f'  Range:   [{c[\"min\"]:.4f}, {c[\"max\"]:.4f}]')
print(f'  Skew:    {c[\"skewness\"]:.4f}')
" 2>/dev/null
echo ""

# ═══ 3. FFT Spectrum ═══
echo "━━━ Step 3: Frequency Analysis ━━━"
cat << 'FFT' | ml eval
data = readmatrix('/tmp/ml_demo_project/data/vibration.csv');
x = data(:,2); fs = 1000; N = length(x);
X = fft(x); P2 = abs(X/N); P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2*P1(2:end-1);
f = fs*(0:(N/2))/N;
[peaks, locs] = findpeaks(P1(1:500), 'SortStr','descend','NPeaks',3);
fprintf('Top 3 frequency peaks:\n');
for k = 1:min(3,numel(locs))
    fprintf('  %.1f Hz  (%.4f)\n', f(locs(k)), peaks(k));
end
FFT
echo ""

# ═══ 4. Filter Design ═══
echo "━━━ Step 4: Low-Pass Filter ━━━"
cat << 'FILTER' | ml eval
data = readmatrix('/tmp/ml_demo_project/data/vibration.csv');
x = data(:,2); fs = 1000; cutoff = 80;
[b,a] = butter(4, cutoff/(fs/2), 'low');
y = filtfilt(b, a, x);
% Compute improvement
noise_removed = rms(x-y);
fprintf('Filter: 4th-order Butterworth @ %d Hz\n', cutoff);
fprintf('Attenuation: %.1f dB\n', 20*log10(rms(y)/rms(x)));
writematrix([data(:,1) y'], '/tmp/ml_demo_project/data/filtered.csv');
fprintf('Saved filtered data\n');
FILTER
echo ""

# ═══ 5. System Modeling ═══
echo "━━━ Step 5: Second-Order System Fit ━━━"
cat << 'MODEL' | ml eval
data = readmatrix('/tmp/ml_demo_project/data/filtered.csv');
x = data(:,2); fs = 1000; t = data(:,1);

% Fit damped sinusoid: A*exp(-alpha*t)*sin(2*pi*f*t)
f0 = 50;
% Simple estimation
[peaks_val, ~] = findpeaks(x, 'MinPeakHeight', 0.5);
if length(peaks_val) > 5
    log_peaks = log(peaks_val(1:min(10,end)));
    t_indices = (0:length(log_peaks)-1)';
    % Linear fit to estimate damping
    alpha = -mean(diff(log_peaks)) * fs / (mean(diff(t_indices)));
    fprintf('Estimated system:\n');
    fprintf('  Natural freq: %.0f Hz\n', f0);
    fprintf('  Damping ratio: %.4f\n', alpha/(2*pi*f0));
    fprintf('  Time constant: %.3f s\n', 1/alpha);
end
MODEL
echo ""

# ═══ 6. Visualization ═══
echo "━━━ Step 6: Generate Plots ━━━"
cat << 'VIS' | ml eval
data = readmatrix('/tmp/ml_demo_project/data/vibration.csv');
filtered = readmatrix('/tmp/ml_demo_project/data/filtered.csv');

figure('Position',[100 100 1200 800]);

subplot(2,2,1);
plot(data(1:500,1), data(1:500,2), 'b-', 'LineWidth', 0.5); hold on;
plot(filtered(1:500,1), filtered(1:500,2), 'r-', 'LineWidth', 1.5);
xlabel('Time [s]'); ylabel('Amplitude'); legend('Raw','Filtered');
title('Vibration Signal (first 500 samples)'); grid on;

subplot(2,2,2);
x = data(:,2); N = length(x);
X = fft(x); P2 = abs(X/N);
P1 = P2(1:floor(N/2)+1); P1(2:end-1) = 2*P1(2:end-1);
f = 1000*(0:(N/2))/N;
plot(f(1:250), P1(1:250), 'b-', 'LineWidth', 1);
xlabel('Frequency [Hz]'); ylabel('Magnitude');
title('FFT Spectrum'); grid on;

subplot(2,2,3);
histogram(x, 50, 'FaceColor', 'b', 'EdgeColor', 'none');
xlabel('Amplitude'); ylabel('Count');
title('Amplitude Distribution'); grid on;

subplot(2,2,4);
autocorr(x, 200);
title('Autocorrelation'); grid on;

saveas(gcf, '/tmp/ml_demo_project/results/analysis_report.png');
close(gcf);
fprintf('Saved: analysis_report.png\n');
VIS
echo ""

# ═══ 7. Final Summary ═══
echo "━━━ Step 7: Summary Report ━━━"
cat << 'RPT' > "$PROJECT/results/report.txt"
Motor Vibration Analysis Report
================================
Generated: dt
Samples: N at Fs Hz
================================
Pipeline: Data Gen → Stats → FFT → Filter → Model → Plot
All steps executed via ml CLI (no MATLAB IDE)

Output files:
  data/vibration.csv    — raw data
  data/filtered.csv     — filtered signal
  results/analysis_report.png — visualization
RPT

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Pipeline Complete                   ║"
echo "║  6 steps, 100% CLI, 0 GUI            ║"
echo "║  Output: $PROJECT/results/           ║"
echo "╚══════════════════════════════════════╝"
