%% {{NAME}} — System Identification Template
% 自动生成 by ml template sysid
% 日期: {{DATE}}
% 用法: 输入输出数据 → 估计传递函数/状态空间模型

clear; clc; close all;

%% 1. Generate or load I/O data
fs = 100;                             % Sample rate [Hz]
Tfinal = 20;                          % Duration [s]
t = (0:1/fs:Tfinal-1/fs)';

% Example: 2nd-order system G(s) = 1/(s^2 + 0.5s + 10)
sys_true = tf(1, [1 0.5 10]);

% Generate input (PRBS — pseudo-random binary)
u = idinput(length(t), 'prbs', [0 1/50], [-1 1]);

% Simulate output with noise
y = lsim(sys_true, u, t) + 0.05*randn(size(t));

fprintf('Data: %d samples @ %d Hz\n', length(t), fs);
fprintf('Input range: [%.2f, %.2f]\n', min(u), max(u));

%% 2. Create iddata object
data = iddata(y, u, 1/fs);
fprintf('Created iddata: %d samples\n', length(data));

%% 3. Split into estimation and validation
N = length(data);
data_est = data(1:floor(0.7*N));     % 70% for estimation
data_val = data(floor(0.7*N)+1:end); % 30% for validation

%% 4. Estimate models
% ARX model
na = 2; nb = 2; nk = 1;
model_arx = arx(data_est, [na nb nk]);

% State-space (n4sid)
try
    model_ss = n4sid(data_est, 2);
catch
    model_ss = ssest(data_est, 2);
end

% Transfer function
try
    model_tf = tfest(data_est, 2);
catch
    model_tf = model_arx;
end

%% 5. Compare models
figure('Name', 'Model Comparison', 'Position', [100 100 900 600]);

subplot(2,1,1);
compare(data_val, model_arx, model_ss, model_tf);
title('Model Output Comparison'); grid on;

subplot(2,1,2);
resid(data_val, model_ss);
title('Residual Analysis');

saveas(gcf, 'sysid_results.png'); close(gcf);

%% 6. Validate
% Compute fit percentage
[y_val, fit_arx] = compare(data_val, model_arx);
[~, fit_ss] = compare(data_val, model_ss);
[~, fit_tf] = compare(data_val, model_tf);

fprintf('\nModel Fit Percentage:\n');
fprintf('  ARX:        %.1f%%\n', fit_arx);
fprintf('  State-Space: %.1f%%\n', fit_ss);
fprintf('  Transfer Fn: %.1f%%\n', fit_tf);

%% 7. Display best model
[best_fit, idx] = max([fit_arx, fit_ss, fit_tf]);
models = {'ARX', 'State-Space', 'Transfer Function'};
fprintf('\nBest model: %s (%.1f%% fit)\n', models{idx}, best_fit);
if idx == 2, fprintf('\n'); present(model_ss); end
if idx == 3, fprintf('\n'); present(model_tf); end

fprintf('\nSystem identification complete.\n');
