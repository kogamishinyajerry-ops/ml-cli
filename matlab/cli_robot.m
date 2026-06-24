function cli_robot(action, varargin)
% CLI_ROBOT Robotics analysis for ml CLI
%   CLI: ml robot dh       --dh "[0 pi/2 0 0; 1 0 0 pi/2]"
%         ml robot fk       --dh "..." --q "[0 pi/4 0]"
%         ml robot jacobian --dh "..." --q "[0 pi/4 0]"
%         ml robot ik       --dh "..." --target "[0.5 0.3 0.1 0 0 0]"
%         ml robot traj     --q0 "[0 0 0]" --q1 "[pi/2 pi/4 pi/3]" --steps 50 --method trapz
%         ml robot rpy      --rpy "[10 20 30]"
%         ml robot rpy      --rotm "[1 0 0; 0 0 -1; 0 1 0]"
%         ml robot rpy      --quat "[0.7071 0 0 0.7071]"
%
%   Options:
%     --dh MAT       DH params as rows [a alpha d theta] (standard DH)
%     --q VEC        joint configuration (rad)
%     --q0 VEC       start configuration
%     --q1 VEC       end configuration
%     --target VEC   6-vector [x y z r p y] for IK
%     --rpy VEC      roll-pitch-yaw degrees
%     --rotm MAT     3x3 rotation matrix
%     --quat VEC     quaternion [w x y z]
%     --steps N      trajectory steps (default 50)
%     --method NAME  trapz|quintic (default trapz)
%     --format json|table|csv

    if nargin < 1, error('ml robot <action> [options]'); end

    opts = struct('format','json','steps',50,'method','trapz','dh','', ...
                  'q','','q0','','q1','','target','', ...
                  'rpy','','rotm','','quat','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--dh',      opts.dh = varargin{i+1}; i=i+2;
            case '--q',       opts.q = varargin{i+1}; i=i+2;
            case '--q0',      opts.q0 = varargin{i+1}; i=i+2;
            case '--q1',      opts.q1 = varargin{i+1}; i=i+2;
            case '--target',  opts.target = varargin{i+1}; i=i+2;
            case '--rpy',     opts.rpy = varargin{i+1}; i=i+2;
            case '--rotm',    opts.rotm = varargin{i+1}; i=i+2;
            case '--quat',    opts.quat = varargin{i+1}; i=i+2;
            case '--steps',   opts.steps = round(parse_num(varargin{i+1})); i=i+2;
            case '--method',  opts.method = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'dh',       out = act_dh(opts);
            case 'fk',       out = act_fk(opts);
            case 'jacobian', out = act_jacobian(opts);
            case 'ik',       out = act_ik(opts);
            case 'traj',     out = act_traj(opts);
            case 'rpy',      out = act_rpy(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== DH matrix parsing ===================
function Dh = parse_dh(s)
    if ischar(s) || isstring(s)
        if isempty(s), error('--dh required'); end
        Dh = eval(s);
    else
        Dh = s;
    end
    if size(Dh,2) ~= 4, error('DH matrix must have 4 columns [a alpha d theta]'); end
end

function q = parse_vec(s)
    if ischar(s) || isstring(s)
        if isempty(s), error('vector required'); end
        q = eval(s);
    else
        q = s;
    end
    q = q(:);
end

% =================== Standard DH transform ===================
% T_i = Rotz(theta_i) * Transz(d_i) * Transx(a_i) * Rotx(alpha_i)
function T = dh_transform(a, alpha, d, theta)
    T = [cos(theta), -sin(theta)*cos(alpha),  sin(theta)*sin(alpha), a*cos(theta);
         sin(theta),  cos(theta)*cos(alpha), -cos(theta)*sin(alpha), a*sin(theta);
         0,           sin(alpha),             cos(alpha),            d;
         0,           0,                      0,                     1];
end

% =================== Build chain transforms ===================
function Ts = chain_transforms(Dh, q)
    n = size(Dh,1);
    if numel(q) ~= n, error('q length (%d) != #joints (%d)', numel(q), n); end
    Ts = cell(n+1,1);
    Ts{1} = eye(4);
    for k = 1:n
        a = Dh(k,1); alpha = Dh(k,2); d = Dh(k,3); theta = Dh(k,4) + q(k);
        Ts{k+1} = Ts{k} * dh_transform(a, alpha, d, theta);
    end
end

% =================== Actions ===================
function out = act_dh(opts)
    Dh = parse_dh(opts.dh);
    n = size(Dh,1);
    out = struct();
    out.numJoints = n;
    out.dh = Dh;
    out.linkLengths_a = Dh(:,1)';
    out.twistAngles_alpha = Dh(:,2)';
    out.offsets_d = Dh(:,3)';
    out.thetas = Dh(:,4)';
    % Home configuration
    Ts = chain_transforms(Dh, zeros(n,1));
    T_home = Ts{end};
    out.homePosition = T_home(1:3,4)';
end

function out = act_fk(opts)
    Dh = parse_dh(opts.dh);
    q = parse_vec(opts.q);
    Ts = chain_transforms(Dh, q);
    T = Ts{end};
    out = struct();
    out.configuration = q';
    out.endEffectorPos = T(1:3,4)';
    out.endEffectorRotm = T(1:3,1:3);
    [rpy, quat] = rotm_to_rpy_quat(T(1:3,1:3));
    out.endEffectorRPY_deg = rpy;
    out.endEffectorQuat = quat;
end

function out = act_jacobian(opts)
    Dh = parse_dh(opts.dh);
    q = parse_vec(opts.q);
    n = size(Dh,1);
    Ts = chain_transforms(Dh, q);
    T_ee = Ts{end};
    p_ee = T_ee(1:3,4);
    J = zeros(6, n);
    for k = 1:n
        T_k = Ts{k};
        z_k = T_k(1:3,3);
        p_k = T_k(1:3,4);
        J(1:3, k) = cross(z_k, p_ee - p_k);
        J(4:6, k) = z_k;
    end
    out = struct();
    out.configuration = q';
    out.jacobian = J;
    out.manipulability = sqrt(det(J*J'));
    out.rank = rank(J);
end

function out = act_ik(opts)
    Dh = parse_dh(opts.dh);
    target = parse_vec(opts.target);
    if numel(target) ~= 6, error('--target must be [x y z roll pitch yaw] in deg'); end
    % Build target homogeneous
    pos = target(1:3);
    rpy = deg2rad(target(4:6));
    R = eul2rotm([rpy(1), rpy(2), rpy(3)], 'ZYX');
    T_target = [R, pos; 0 0 0 1];
    n = size(Dh,1);
    % Newton iteration on damped least squares
    q = zeros(n,1);
    lambda = 0.1;
    maxIter = 200;
    tol = 1e-4;
    iter = 0;
    err_hist = zeros(maxIter,1);
    for it = 1:maxIter
        iter = it;
        Ts = chain_transforms(Dh, q);
        T_cur = Ts{end};
        p_err = T_target(1:3,4) - T_cur(1:3,4);
        R_err = T_target(1:3,1:3)' * T_cur(1:3,1:3);
        % axis-angle from R_err (cur -> target)
        omega = vex(R_err);
        e = [p_err; omega];
        err_hist(it) = norm(e);
        if norm(e) < tol, break; end
        % Compute Jacobian
        T_ee = T_cur;
        p_ee = T_ee(1:3,4);
        J = zeros(6, n);
        for k = 1:n
            T_k = Ts{k};
            z_k = T_k(1:3,3);
            p_k = T_k(1:3,4);
            J(1:3, k) = cross(z_k, p_ee - p_k);
            J(4:6, k) = z_k;
        end
        % Damped LS step
        dq = (J'*J + lambda^2*eye(n)) \ (J'*e);
        q = q + dq;
    end
    out = struct();
    out.solution = q';
    out.iterations = iter;
    out.finalError = err_hist(iter);
    out.converged = err_hist(iter) < tol;
    % Verify with FK
    Ts = chain_transforms(Dh, q);
    T_check = Ts{end};
    out.achievedPos = T_check(1:3,4)';
end

function out = act_traj(opts)
    q0 = parse_vec(opts.q0);
    q1 = parse_vec(opts.q1);
    n = numel(q0);
    if numel(q1) ~= n, error('q0/q1 size mismatch'); end
    steps = opts.steps;
    method = lower(opts.method);
    t = linspace(0, 1, steps)';
    Q = zeros(steps, n);
    for j = 1:n
        if strcmp(method, 'quintic')
            % 5th order: q(t) = q0 + (q1-q0)*(10t^3 - 15t^4 + 6t^5)
            Q(:,j) = q0(j) + (q1(j)-q0(j))*(10*t.^3 - 15*t.^4 + 6*t.^5);
        else
            % Trapezoidal: accel phase 0..0.25, cruise 0.25..0.75, decel 0.75..1
            s = trapezoid_profile(t);
            Q(:,j) = q0(j) + (q1(j)-q0(j))*s;
        end
    end
    out = struct();
    out.method = method;
    out.steps = steps;
    out.startConfig = q0';
    out.endConfig = q1';
    out.time = t';
    out.jointTrajectory = Q;
end

function out = act_rpy(opts)
    out = struct();
    if ~isempty(opts.rpy)
        rpy = deg2rad(parse_vec(opts.rpy)');
        R = eul2rotm([rpy(1), rpy(2), rpy(3)], 'ZYX');
        out.input = struct('type','rpy_deg','value',rad2deg(rpy));
        out.rotm = R;
        out.quat_wxyz = rotm2quat(R);
        [rpy2, ~] = rotm_to_rpy_quat(R);
        out.rpy_deg = rpy2;
    elseif ~isempty(opts.rotm)
        R = parse_mat(opts.rotm);
        out.input = struct('type','rotm');
        out.rotm = R;
        out.quat_wxyz = rotm2quat(R);
        [rpy, ~] = rotm_to_rpy_quat(R);
        out.rpy_deg = rpy;
    elseif ~isempty(opts.quat)
        q = parse_vec(opts.quat)';
        R = quat2rotm(q);
        out.input = struct('type','quat_wxyz');
        out.rotm = R;
        out.quat_wxyz = q;
        [rpy, ~] = rotm_to_rpy_quat(R);
        out.rpy_deg = rpy;
    else
        error('Specify --rpy, --rotm, or --quat');
    end
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function M = parse_mat(s)
    if ischar(s) || isstring(s), M = eval(s); else, M = s; end
end

function s = trapezoid_profile(t)
    s = zeros(size(t));
    for k = 1:numel(t)
        tk = t(k);
        if tk < 0.25
            s(k) = 2*tk^2;
        elseif tk < 0.75
            s(k) = tk - 0.125;
        else
            s(k) = 1 - 2*(1-tk)^2;
        end
    end
end

function w = vex(R)
    % skew-symmetric part of R -> axis-angle vector
    w = [R(3,2)-R(2,3);
         R(1,3)-R(3,1);
         R(2,1)-R(1,2)] / 2;
end

function [rpy_deg, quat_wxyz] = rotm_to_rpy_quat(R)
    eul = rotm2eul(R, 'ZYX');
    rpy_deg = rad2deg(eul);
    quat_wxyz = rotm2quat(R);
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
