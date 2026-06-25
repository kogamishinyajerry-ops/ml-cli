function cli_fluid(action, varargin)
% CLI_FLUID Fluid dynamics for ml CLI
%   CLI: ml fluid reynolds --velocity 2 --length 0.1 --nu 1e-6
%         ml fluid bernoulli --p1 101325 --v1 5 --z1 0 --z2 10 --solve p2
%         ml fluid pipe_flow --diameter 0.05 --length 100 --flow 0.001 --roughness 0.0001
%         ml fluid drag --velocity 30 --area 2.5 --rho 1.225 --cd 0.3
%         ml fluid head_loss --velocity 2 --diameter 0.1 --length 50 --friction 0.02
%         ml fluid pump --flow 0.01 --head 20 --rho 1000 --efficiency 0.75
%
%   Options:
%     --velocity M/S   flow velocity
%     --length M        characteristic length
%     --nu M2/S         kinematic viscosity
%     --p1 Pa           pressure at point 1
%     --v1 M/S          velocity at point 1
%     --z1 / --z2 M     elevations
%     --solve NAME      variable to solve for
%     --diameter M       pipe diameter
%     --flow M3/S       flow rate
%     --roughness M     pipe wall roughness
%     --rho KG/M3       fluid density (default 1000 water)
%     --cd              drag coefficient
%     --area M2         reference area
%     --friction F      Darcy friction factor (default from Colebrook)
%     --head M          pump head
%     --efficiency      pump efficiency (0-1)
%     --format json|table|csv

    if nargin < 1, error('ml fluid <action> [options]'); end

    opts = struct('format','json','velocity',2,'length',0.1,'nu',1e-6, ...
                  'p1',101325,'v1',5,'z1',0,'z2',0,'solve','p2','v2',0,'p2_val',101325, ...
                  'diameter',0.05,'flow',0.001,'roughness',0.0001, ...
                  'rho',1000,'cd',0.3,'area',2.5,'friction',0, ...
                  'head',20,'efficiency',0.75);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--velocity',   opts.velocity = parse_num(varargin{i+1}); i=i+2;
            case '--length',     opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--nu',         opts.nu = parse_num(varargin{i+1}); i=i+2;
            case '--p1',         opts.p1 = parse_num(varargin{i+1}); i=i+2;
            case '--v1',         opts.v1 = parse_num(varargin{i+1}); i=i+2;
            case '--z1',         opts.z1 = parse_num(varargin{i+1}); i=i+2;
            case '--z2',         opts.z2 = parse_num(varargin{i+1}); i=i+2;
            case '--v2',         opts.v2 = parse_num(varargin{i+1}); i=i+2;
            case '--p2',         opts.p2_val = parse_num(varargin{i+1}); i=i+2;
            case '--solve',      opts.solve = lower(varargin{i+1}); i=i+2;
            case '--diameter',   opts.diameter = parse_num(varargin{i+1}); i=i+2;
            case '--flow',       opts.flow = parse_num(varargin{i+1}); i=i+2;
            case '--roughness',  opts.roughness = parse_num(varargin{i+1}); i=i+2;
            case '--rho',        opts.rho = parse_num(varargin{i+1}); i=i+2;
            case '--cd',         opts.cd = parse_num(varargin{i+1}); i=i+2;
            case '--area',       opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--friction',   opts.friction = parse_num(varargin{i+1}); i=i+2;
            case '--head',       opts.head = parse_num(varargin{i+1}); i=i+2;
            case '--efficiency', opts.efficiency = parse_num(varargin{i+1}); i=i+2;
            case '--format',     opts.format = varargin{i+1}; i=i+2;
            otherwise,           i=i+1;
        end
    end

    try
        switch lower(action)
            case 'reynolds',  out = act_reynolds(opts);
            case 'bernoulli', out = act_bernoulli(opts);
            case 'pipe_flow', out = act_pipe_flow(opts);
            case 'drag',      out = act_drag(opts);
            case 'head_loss', out = act_head_loss(opts);
            case 'pump',      out = act_pump(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_reynolds(opts)
    v = opts.velocity;
    L = opts.length;
    nu = opts.nu;
    Re = v * L / nu;
    if Re < 2300
        regime = 'laminar';
    elseif Re < 4000
        regime = 'transitional';
    else
        regime = 'turbulent';
    end
    out = struct();
    out.action = 'reynolds';
    out.velocity = v;
    out.charLength = L;
    out.viscosity_nu = nu;
    out.reynolds = Re;
    out.regime = regime;
end

function out = act_bernoulli(opts)
    rho = opts.rho;
    g = 9.81;
    p1 = opts.p1; v1 = opts.v1; z1 = opts.z1;
    z2 = opts.z2;
    solve = opts.solve;
    % Bernoulli: p1 + 1/2*rho*v1^2 + rho*g*z1 = p2 + 1/2*rho*v2^2 + rho*g*z2
    C = p1 + 0.5*rho*v1^2 + rho*g*z1;
    switch solve
        case 'p2'
            v2 = opts.v2;
            val = C - 0.5*rho*v2^2 - rho*g*z2;
            unit = 'Pa';
        case 'v2'
            p2 = opts.p2_val;
            val = sqrt(max(0, 2*(C - p2 - rho*g*z2) / rho));
            unit = 'm/s';
        case 'z2'
            p2 = opts.p2_val;
            v2 = opts.v2;
            val = (C - p2 - 0.5*rho*v2^2) / (rho * g);
            unit = 'm';
        otherwise
            error('solve must be p2|v2|z2');
    end
    out = struct();
    out.action = 'bernoulli';
    out.equation = 'p + 1/2*rho*v^2 + rho*g*z = const';
    out.solved = solve;
    out.value = val;
    out.units = unit;
    out.totalHead_m = C / (rho * g);
end

function out = act_pipe_flow(opts)
    D = opts.diameter;
    L = opts.length;
    Q = opts.flow;
    rho = opts.rho;
    eps = opts.roughness;
    A = pi * D^2 / 4;
    v = Q / A;
    % If friction not given, compute via Colebrook-White
    if opts.friction <= 0
        Re = v * D / opts.nu;
        % Colebrook-White: 1/sqrt(f) = -2*log10(eps/(3.7*D) + 2.51/(Re*sqrt(f)))
        f = 0.02;  % initial guess
        for iter = 1:50
            relRough = eps / (3.7 * D);
            term2 = 2.51 / (Re * sqrt(max(f, 1e-12)));
            f_new = 1 / (-2*log10(relRough + term2))^2;
            if abs(f_new - f) < 1e-8, break; end
            f = f_new;
        end
    else
        f = opts.friction;
    end
    % Head loss: Darcy-Weisbach
    hf = f * L * v^2 / (2 * 9.81 * D);
    dP = rho * 9.81 * hf;  % pressure drop
    out = struct();
    out.action = 'pipe_flow';
    out.diameter = D;
    out.length = L;
    out.flowRate = Q;
    out.velocity = v;
    out.reynolds = v * D / opts.nu;
    out.frictionFactor = f;
    out.headLoss_m = hf;
    out.pressureDrop_Pa = dP;
end

function out = act_drag(opts)
    v = opts.velocity;
    A = opts.area;
    rho = opts.rho;
    Cd = opts.cd;
    Fd = 0.5 * rho * Cd * A * v^2;
    out = struct();
    out.action = 'drag';
    out.velocity = v;
    out.area = A;
    out.fluidDensity = rho;
    out.dragCoefficient = Cd;
    out.dragForce_N = Fd;
    out.dragPower_W = Fd * v;
end

function out = act_head_loss(opts)
    v = opts.velocity;
    D = opts.diameter;
    L = opts.length;
    f = opts.friction;
    g = 9.81;
    hf = f * L * v^2 / (2 * g * D);
    % Minor loss coefficient K
    % Standard entrance/exit losses
    hl_entrance = 0.5 * v^2 / (2*g);    % square-edged entrance
    hl_exit = 1.0 * v^2 / (2*g);
    hf_total = hf + hl_entrance + hl_exit;
    out = struct();
    out.action = 'head_loss';
    out.equation = 'Darcy-Weisbach: hf = f*L*v^2/(2g*D)';
    out.frictionFactor = f;
    out.majorLoss_m = hf;
    out.entranceLoss_m = hl_entrance;
    out.exitLoss_m = hl_exit;
    out.totalHeadLoss_m = hf_total;
end

function out = act_pump(opts)
    Q = opts.flow;
    H = opts.head;
    rho = opts.rho;
    eta = opts.efficiency;
    g = 9.81;
    P_hydraulic = rho * g * Q * H;
    P_shaft = P_hydraulic / eta;
    out = struct();
    out.action = 'pump';
    out.flow_m3_s = Q;
    out.head_m = H;
    out.efficiency = eta;
    out.hydraulicPower_W = P_hydraulic;
    out.shaftPower_W = P_shaft;
    out.hydraulicPower_kW = P_hydraulic / 1000;
    out.shaftPower_kW = P_shaft / 1000;
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
