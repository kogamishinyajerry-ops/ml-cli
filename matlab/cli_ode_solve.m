function result = cli_ode_solve(mode, tspan, y0, params)
% CLI_ODE_SOLVE ODE 求解器
%   CLI: ml solve --vanderpol 0 20 2 0
%         ml solve --lorenz 0 50 1 1 1 10 28 8/3
%   mode: 'vanderpol', 'lorenz', 'lotka', 'doublependulum'

    if nargin < 3, error('Need mode, tspan, y0'); end

    switch lower(mode)
        case 'vanderpol'
            % Van der Pol oscillator: y'' - mu*(1-y^2)*y' + y = 0
            mu = params(1);
            odefun = @(t, y) [y(2); mu*(1-y(1)^2)*y(2) - y(1)];
            desc = 'Van der Pol oscillator';

        case 'lorenz'
            % Lorenz attractor: dx/dt = sigma*(y-x), dy/dt = x*(rho-z)-y, dz/dt = x*y - beta*z
            sigma = params(1); rho = params(2); beta = params(3);
            odefun = @(t, y) [sigma*(y(2)-y(1)); y(1)*(rho-y(3))-y(2); y(1)*y(2)-beta*y(3)];
            desc = 'Lorenz attractor';

        case 'lotka'
            % Lotka-Volterra predator-prey
            alpha = params(1); beta = params(2); gamma = params(3); delta = params(4);
            odefun = @(t, y) [alpha*y(1) - beta*y(1)*y(2); delta*y(1)*y(2) - gamma*y(2)];
            desc = 'Lotka-Volterra model';

        case 'doublependulum'
            % Double pendulum
            m1 = params(1); m2 = params(2); L1 = params(3); L2 = params(4); g = 9.81;
            odefun = @(t, y) double_pendulum(t, y, m1, m2, L1, L2, g);
            desc = 'Double pendulum';

        otherwise
            error('Unknown mode: %s. Use: vanderpol, lorenz, lotka, doublependulum', mode);
    end

    opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-9);
    [t, y] = ode45(odefun, tspan, y0, opts);

    result = struct();
    result.mode = mode;
    result.description = desc;
    result.tspan = tspan;
    result.y0 = y0;
    result.n_steps = length(t);
    result.t_final = t(end);
    result.y_final = y(end, :)';
    result.t = t;
    result.y = y;
end

function dydt = double_pendulum(~, y, m1, m2, L1, L2, g)
    % State: [theta1, theta2, omega1, omega2]
    th1 = y(1); th2 = y(2); om1 = y(3); om2 = y(4);
    dth = th1 - th2;

    denom = 2*m1 + m2 - m2*cos(2*dth);
    dydt = zeros(4, 1);
    dydt(1) = om1;
    dydt(2) = om2;
    dydt(3) = (-g*(2*m1+m2)*sin(th1) - m2*g*sin(th1-2*th2) ...
               - 2*sin(dth)*m2*(om2^2*L2 + om1^2*L1*cos(dth))) ...
              / (L1 * denom);
    dydt(4) = (2*sin(dth)*(om1^2*L1*(m1+m2) + g*(m1+m2)*cos(th1) ...
               + om2^2*L2*m2*cos(dth))) / (L2 * denom);
end
