%% {{NAME}} — Differential Equation / Simulation Template
% 自动生成 by ml template simulation
% 日期: {{DATE}}

clear; clc; close all;

%% 1. Define ODE system
% dx/dt = f(t, x)
% Replace f with your ODE
function dx = myode(t, x)
    % Example: damped harmonic oscillator
    % x(1) = position, x(2) = velocity
    m = 1;    % mass
    c = 0.5;  % damping
    k = 10;   % stiffness

    dx = zeros(2, 1);
    dx(1) = x(2);
    dx(2) = (-c*x(2) - k*x(1)) / m;
end

%% 2. Set up simulation
tspan = [0 20];         % time span [start, end]
x0 = [1; 0];           % initial conditions [pos, vel]
opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-9);

%% 3. Run simulation
fprintf('Simulating damped oscillator...\n');
[t, x] = ode45(@myode, tspan, x0, opts);

%% 4. Analyze results
fprintf('Final state at t=%.1f:\n', t(end));
fprintf('  Position: %.4f\n', x(end, 1));
fprintf('  Velocity: %.4f\n', x(end, 2));

% Compute energy
m = 1; k = 10;
E = 0.5*m*x(:,2).^2 + 0.5*k*x(:,1).^2;
fprintf('  Initial energy: %.4f\n', E(1));
fprintf('  Final energy:   %.4f\n', E(end));

%% 5. Visualize
figure('Name', 'Simulation Results', 'Position', [100 100 900 700]);

subplot(3, 1, 1);
plot(t, x(:, 1), 'b-', 'LineWidth', 1.5); hold on;
plot(t, x(:, 2), 'r--', 'LineWidth', 1.5);
xlabel('Time [s]'); ylabel('State');
legend('Position', 'Velocity'); grid on;
title('State Trajectories');

subplot(3, 1, 2);
plot(x(:, 1), x(:, 2), 'k-', 'LineWidth', 1);
xlabel('Position'); ylabel('Velocity'); grid on;
title('Phase Portrait');

subplot(3, 1, 3);
plot(t, E, 'g-', 'LineWidth', 1.5);
xlabel('Time [s]'); ylabel('Energy [J]'); grid on;
title('Energy vs Time');

saveas(gcf, 'simulation_results.png');
close(gcf);
fprintf('\nSimulation complete. Results saved to simulation_results.png\n');
