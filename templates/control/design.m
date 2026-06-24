%% {{NAME}} — Control System Design Template
% 自动生成 by ml template control
% 日期: {{DATE}}

clear; clc; close all;

%% 1. System definition
% Transfer function or state-space model
s = tf('s');
G = 1 / (s^2 + 2*s + 10);  % Example system

% State-space
[A, B, C, D] = tf2ss([1], [1 2 10]);
sys_ss = ss(A, B, C, D);

fprintf('System Analysis:\n');
fprintf('  Poles: '); disp(pole(G));
fprintf('  Zeros: '); disp(zero(G));

%% 2. Open-loop analysis
figure('Name', 'Open-Loop Analysis', 'Position', [100 100 1000 600]);

subplot(2, 2, 1);
step(G); title('Step Response'); grid on;

subplot(2, 2, 2);
impulse(G); title('Impulse Response'); grid on;

subplot(2, 2, 3);
bode(G); grid on;

subplot(2, 2, 4);
nyquist(G); grid on;

saveas(gcf, 'open_loop_analysis.png'); close(gcf);

%% 3. Controller design
% PID control
[C, info] = pidtune(G, 'PIDF');
fprintf('\nPID Controller:\n');
fprintf('  Kp = %.4f, Ki = %.4f, Kd = %.4f, N = %.4f\n', ...
    C.Kp, C.Ki, C.Kd, C.Tf);

% Closed-loop
sys_cl = feedback(C * G, 1);

figure('Name', 'Closed-Loop Analysis', 'Position', [100 100 1000 600]);

subplot(2, 2, 1);
step(sys_cl); title('Closed-Loop Step'); hold on;
stepinfo_cl = stepinfo(sys_cl);
grid on;

subplot(2, 2, 2);
margin(C * G); grid on;

subplot(2, 2, 3);
% Disturbance rejection
G_d = feedback(G, C);
step(G_d); title('Disturbance Response'); grid on;

subplot(2, 2, 4);
% Sensitivity
S = feedback(1, C * G);
bodemag(S, G_d); grid on; legend('Sensitivity', 'Disturbance');

saveas(gcf, 'closed_loop_analysis.png'); close(gcf);

fprintf('\nPerformance:\n');
fprintf('  Rise Time:  %.3f s\n', stepinfo_cl.RiseTime);
fprintf('  Overshoot:  %.1f%%\n', stepinfo_cl.Overshoot);
fprintf('  Settling:   %.3f s\n', stepinfo_cl.SettlingTime);
fprintf('  GM: %.1f dB, PM: %.1f deg\n', info.GM, info.PM);

%% 4. LQR design
Q = diag([10, 0.1, 1, 0.1]);
R = 1;
K = lqr(sys_ss, Q, R);
fprintf('\nLQR Gain: '); disp(K);

fprintf('\nDesign complete.\n');
