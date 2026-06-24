%% {{NAME}} — Mathematical Modeling Template
% 自动生成 by ml template modeling
% 日期: {{DATE}}
% 用途: 物理/工程系统的数学模型构建

clear; clc; close all;

%% 1. Define system equations
% State-space representation: dx/dt = A*x + B*u, y = C*x
% Example: 2DOF mass-spring-damper system
%
% m1*x1'' + c1*x1' + k1*x1 + k2*(x1-x2) = u
% m2*x2'' + c2*x2' + k2*(x2-x1) = 0

m1 = 10;  m2 = 5;                  % Masses [kg]
c1 = 2;   c2 = 1;                   % Damping [N·s/m]
k1 = 100; k2 = 50;                  % Stiffness [N/m]

% State: [x1, x2, x1_dot, x2_dot]
A = [0,                   0,                   1,  0;
     0,                   0,                   0,  1;
     -(k1+k2)/m1,        k2/m1,             -c1/m1, 0;
     k2/m2,              -k2/m2,             0,    -c2/m2];

B = [0; 0; 1/m1; 0];
C = [1 0 0 0; 0 1 0 0];           % Output: displacements
D = [0; 0];

sys = ss(A, B, C, D);
fprintf('System: 2DOF mass-spring-damper\n');
fprintf('  States: %d\n', size(A, 1));
fprintf('  Inputs: %d\n', size(B, 2));

%% 2. Modal analysis
[eig_vec, eig_val] = eig(A);
omega_n = abs(imag(diag(eig_val)));
zeta = -real(diag(eig_val)) ./ omega_n;

fprintf('\nModal Analysis:\n');
for k = 1:length(omega_n)
    fprintf('  Mode %d: ω_n = %.2f rad/s, ζ = %.3f\n', k, omega_n(k), zeta(k));
end

%% 3. Frequency response
figure('Name', 'System Response', 'Position', [100 100 1000 700]);

subplot(2,2,1);
bode(sys(1,1)); title('Bode: Input → x1'); grid on;

subplot(2,2,2);
impulse(sys(1,1), 10); title('Impulse Response'); grid on;

subplot(2,2,3);
step(sys(1,1), 10); title('Step Response'); grid on;

subplot(2,2,4);
sigma(sys); title('Singular Values'); grid on;

saveas(gcf, 'model_analysis.png'); close(gcf);

%% 4. Time-domain simulation
t = linspace(0, 20, 1000);
u = sin(2*pi*0.5*t);              % Sinusoidal input
y = lsim(sys, u, t, [0; 0; 0; 0]);

figure('Name', 'Time Simulation', 'Position', [100 100 800 500]);

subplot(2,1,1);
plot(t, u, 'k--', t, y(:,1), 'b-', t, y(:,2), 'r-', 'LineWidth', 1.5);
xlabel('Time [s]'); ylabel('Displacement [m]');
legend('Input u', 'x_1', 'x_2'); grid on;
title('Forced Response to Sinusoidal Input');

subplot(2,1,2);
% Phase portrait
plot(y(:,1), y(:,2), 'k-', 'LineWidth', 1);
xlabel('x_1'); ylabel('x_2'); grid on;
title('Phase Portrait');

saveas(gcf, 'model_simulation.png'); close(gcf);

%% 5. Stability assessment
poles = pole(sys);
stable = all(real(poles) < 0);

if stable
    fprintf('\nStability: STABLE\n');
else
    fprintf('\nStability: UNSTABLE\n');
end
fprintf('Poles: '); disp(poles);

fprintf('\nModeling complete. Results saved to model_*.png\n');
