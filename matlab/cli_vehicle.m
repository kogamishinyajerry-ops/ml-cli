function cli_vehicle(action, varargin)
% CLI_VEHICLE Vehicle dynamics analysis for ml CLI
%   CLI: ml vehicle info    --mass 1500 --a 1.2 --b 1.5 --Iz 2500
%         ml vehicle pacejka --slip 5 --D 1 --C 1.65 --B 10 --E 0.97
%         ml vehicle steer   --v 20 --delta 0.05 --tfinal 5
%         ml vehicle lanechange --v 20 --tfinal 10
%         ml vehicle straight --v 30
%         ml vehicle road     --radius 50 --v 15 --a 1.2 --b 1.5
%
%   Options:
%     --mass kg       vehicle mass (default 1500)
%     --a m           CG to front axle (default 1.2)
%     --b m           CG to rear axle (default 1.5)
%     --Iz kg*m^2     yaw moment of inertia (default 2500)
%     --Caf N/rad     front cornering stiffness (default 60000)
%     --Car N/rad     rear cornering stiffness (default 60000)
%     --v m/s         longitudinal speed
%     --delta rad     steering wheel angle (front)
%     --slip deg      tire slip angle (for pacejka)
%     --D peak        Pacejka peak factor (default 1)
%     --C shape       Pacejka shape factor (default 1.65)
%     --B stiffness   Pacejka stiffness factor (default 10)
%     --E curvature   Pacejka curvature factor (default 0.97)
%     --tfinal s      simulation duration
%     --radius m      road radius
%     --format json|table|csv

    if nargin < 1, error('ml vehicle <action> [options]'); end

    opts = struct('format','json','mass',1500,'a',1.2,'b',1.5,'Iz',2500, ...
                  'Caf',60000,'Car',60000,'v',20,'delta',0.05, ...
                  'slip',5,'D',1,'C',1.65,'B',10,'E',0.97, ...
                  'tfinal',5,'radius',50);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--mass',    opts.mass = parse_num(varargin{i+1}); i=i+2;
            case '--a',       opts.a = parse_num(varargin{i+1}); i=i+2;
            case '--b',       opts.b = parse_num(varargin{i+1}); i=i+2;
            case '--Iz',      opts.Iz = parse_num(varargin{i+1}); i=i+2;
            case '--Caf',     opts.Caf = parse_num(varargin{i+1}); i=i+2;
            case '--Car',     opts.Car = parse_num(varargin{i+1}); i=i+2;
            case '--v',       opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--delta',   opts.delta = parse_num(varargin{i+1}); i=i+2;
            case '--slip',    opts.slip = parse_num(varargin{i+1}); i=i+2;
            case '--D',       opts.D = parse_num(varargin{i+1}); i=i+2;
            case '--C',       opts.C = parse_num(varargin{i+1}); i=i+2;
            case '--B',       opts.B = parse_num(varargin{i+1}); i=i+2;
            case '--E',       opts.E = parse_num(varargin{i+1}); i=i+2;
            case '--tfinal',  opts.tfinal = parse_num(varargin{i+1}); i=i+2;
            case '--radius',  opts.radius = parse_num(varargin{i+1}); i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'info',        out = act_info(opts);
            case 'pacejka',     out = act_pacejka(opts);
            case 'steer',       out = act_steer(opts);
            case 'lanechange',  out = act_lanechange(opts);
            case 'straight',    out = act_straight(opts);
            case 'road',        out = act_road(opts);
            otherwise,          error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Bicycle model A,B matrices (2-DOF lateral) ===================
% State x = [beta; r] (sideslip angle, yaw rate), input u = delta_f
function [A, B] = bicycle_AB(opts)
    m = opts.mass; V = opts.v;
    a = opts.a; b = opts.b; Iz = opts.Iz;
    Caf = opts.Caf; Car = opts.Car;
    L = a + b;
    % Standard linear bicycle model (single-track)
    A = [-(Caf+Car)/(m*V),            -1 - (a*Caf - b*Car)/(m*V^2);
         -(a*Caf - b*Car)/Iz,         -(a^2*Caf + b^2*Car)/(Iz*V)];
    B = [Caf/(m*V); a*Caf/Iz];
end

% =================== Actions ===================
function out = act_info(opts)
    L = opts.a + opts.b;
    out = struct();
    out.mass_kg = opts.mass;
    out.wheelbase_m = L;
    out.cgToFrontAxle_m = opts.a;
    out.cgToRearAxle_m = opts.b;
    out.yawInertia_kgm2 = opts.Iz;
    out.frontCorneringStiffness = opts.Caf;
    out.rearCorneringStiffness = opts.Car;
    % Understeer gradient K_us = m*(b*Car - a*Caf) / (L*Caf*Car)
    out.understeerGradient = opts.mass*(opts.b*opts.Car - opts.a*opts.Caf) / (L*opts.Caf*opts.Car);
    % Critical speed (for oversteer vehicles) sqrt( (a*Caf*L) / (m*b) ) if b*Car < a*Caf
    if opts.b*opts.Car < opts.a*opts.Caf
        out.characteristicSpeed = sqrt(opts.a*opts.Caf*L / (opts.mass*opts.b));  % oversteer
        out.stability = 'oversteer';
    else
        out.characteristicSpeed = sqrt(opts.b*opts.Car*L / (opts.mass*opts.a));  % understeer
        out.stability = 'understeer';
    end
end

function out = act_pacejka(opts)
    alpha = deg2rad(opts.slip);
    % Magic Formula: Fy = D*sin(C*atan(B*alpha - E*(B*alpha - atan(B*alpha))))
    Balpha = opts.B * alpha;
    Fy = opts.D * sin(opts.C * atan(Balpha - opts.E*(Balpha - atan(Balpha))));
    out = struct();
    out.slipAngle_deg = opts.slip;
    out.B = opts.B; out.C = opts.C; out.D = opts.D; out.E = opts.E;
    out.tireForce_normalized = Fy;
    out.peakForce = opts.D;
    out.slipAtPeak_deg = rad2deg(atan(opts.C^-1 * (1 + opts.E)) / opts.B);
    % Sweep for full curve
    alpha_sweep = deg2rad(-20:1:20);
    Balpha_sweep = opts.B * alpha_sweep;
    Fy_sweep = opts.D * sin(opts.C * atan(Balpha_sweep - opts.E*(Balpha_sweep - atan(Balpha_sweep))));
    out.slipSweep_deg = -20:20;
    out.forceCurve = Fy_sweep;
end

function out = act_steer(opts)
    [A, B] = bicycle_AB(opts);
    t = linspace(0, opts.tfinal, max(50, round(opts.tfinal*20)));
    u_step = opts.delta * ones(size(t));
    sys = ss(A, B, eye(2), zeros(2,1));
    [y, t_out, x] = lsim(sys, u_step, t, [0; 0]);
    out = struct();
    out.speed_ms = opts.v;
    out.steerAngle_rad = opts.delta;
    out.duration_s = opts.tfinal;
    out.time = t_out';
    out.beta_rad = x(:,1)';
    out.yawRate_rads = x(:,2)';
    out.lateralAccel_ms2 = x(:,2)' .* opts.v;  % approx ay ≈ V*r + beta_dot*V
    out.peakYawRate = max(abs(x(:,2)));
    out.steadyStateYawRate = x(end,2);
    out.steadyStateBeta = x(end,1);
    % Damping ratio of the lateral mode
    eigVals = eig(A);
    out.eigenvalues = eigVals;
    wn = abs(eigVals);
    zeta = -real(eigVals) ./ wn;
    out.naturalFreq = wn;
    out.dampingRatio = zeta;
end

function out = act_lanechange(opts)
    [A, B] = bicycle_AB(opts);
    t = linspace(0, opts.tfinal, max(100, round(opts.tfinal*30)));
    % Sine-with-dwell steer: δ(t) = δ_peak * sin(2π*t/T) * (t < T_dwell)
    T_period = opts.tfinal/2;
    T_dwell = T_period/2;
    delta_peak = 0.05;  % ~3 deg
    delta_t = delta_peak * sin(2*pi*t/T_period);
    % Apply dwell (hold peak briefly)
    dwellMask = (t > T_period/4) & (t < T_period/4 + T_dwell);
    delta_t(dwellMask) = delta_peak;
    sys = ss(A, B, eye(2), 0);
    [y, t_out, x] = lsim(sys, delta_t, t);
    out = struct();
    out.maneuver = 'sine-with-dwell';
    out.speed_ms = opts.v;
    out.duration_s = opts.tfinal;
    out.time = t_out';
    out.steerInput_rad = delta_t';
    out.yawRate_rads = x(:,2)';
    out.beta_rad = x(:,1)';
    out.lateralAccel_ms2 = x(:,2)' .* opts.v;
    out.peakYawRate = max(abs(x(:,2)));
    out.peakLateralAccel = max(abs(x(:,2) .* opts.v));
end

function out = act_straight(opts)
    % Open-loop straight-line stability: eigenvalues at given V
    [A, ~] = bicycle_AB(opts);
    eigVals = eig(A);
    out = struct();
    out.speed_ms = opts.v;
    out.Amatrix = A;
    out.eigenvalues = eigVals;
    wn = abs(eigVals);
    zeta = -real(eigVals) ./ wn;
    out.naturalFreq_rads = wn;
    out.dampingRatio = zeta;
    out.stable = all(real(eigVals) < 0);
end

function out = act_road(opts)
    L = opts.a + opts.b;
    R = opts.radius;
    V = opts.v;
    % Steer angle for low-speed turn: δ ≈ L/R
    delta_low = L / R;
    % Understeer correction: δ = L/R + K_us * V²/R
    K_us = opts.mass * (opts.b*opts.Car - opts.a*opts.Caf) / (L*opts.Caf*opts.Car);
    delta_dyn = L/R + K_us * V^2/R;
    out = struct();
    out.radius_m = R;
    out.speed_ms = V;
    out.wheelbase_m = L;
    out.understeerGradient = K_us;
    out.kinematicSteer_rad = delta_low;
    out.dynamicSteer_rad = delta_dyn;
    out.steerCorrection_rad = delta_dyn - delta_low;
    out.lateralAccel_ms2 = V^2/R;
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
