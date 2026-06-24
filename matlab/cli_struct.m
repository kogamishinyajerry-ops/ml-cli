function cli_struct(action, varargin)
% CLI_STRUCT Structural mechanics analysis for ml CLI
%   CLI: ml struct beam    --length 5 --load 10 --type simply
%         ml struct column --height 3 --E 200e9 --I 1e-4 --P 1000
%         ml struct torsion--length 2 --G 80e9 --J 1e-5 --T 100
%         ml struct stress --Fx 1000 --A 0.01 --My 50 --I 1e-4 --y 0.05
%         ml struct modal  --E 200e9 --I 1e-4 --rho 7850 --A 0.01 --length 5 --modes 3
%         ml struct truss  --nodes "[0 0; 1 0; 0.5 1]" --members "[1 2; 2 3; 1 3]" --forces "[0 -100]" --fixity "[1 0 0 1 0 0]"
%
%   Options:
%     --length m       beam/column length
%     --load N/m       distributed load (for beam)
%     --type NAME      simply|cantilever|fixed
%     --E Pa           Young's modulus
%     --I m^4          area moment of inertia
%     --A m^2          cross-section area
%     --height m       column height
%     --P N            axial load
%     --G Pa           shear modulus
%     --J m^4          polar moment of inertia
%     --T Nm           applied torque
%     --Fx N           axial force
%     --My Nm          bending moment
%     --y m            distance from neutral axis
%     --rho kg/m^3     density
%     --modes N        number of modes to compute
%     --nodes MAT      node coordinates
%     --members MAT    member connectivity
%     --forces MAT     nodal forces
%     --fixity MAT     boundary conditions
%     --format json|table|csv

    if nargin < 1, error('ml struct <action> [options]'); end

    opts = struct('format','json','length',5,'load',10,'type','simply', ...
                  'E',200e9,'I',1e-4,'A',0.01,'height',3,'P',1000, ...
                  'G',80e9,'J',1e-5,'T',100,'Fx',0,'My',0,'y',0.05, ...
                  'rho',7850,'modes',3, ...
                  'nodes','','members','','forces','','fixity','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--length',   opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--load',     opts.load = parse_num(varargin{i+1}); i=i+2;
            case '--type',     opts.type = lower(varargin{i+1}); i=i+2;
            case '--E',        opts.E = parse_num(varargin{i+1}); i=i+2;
            case '--I',        opts.I = parse_num(varargin{i+1}); i=i+2;
            case '--A',        opts.A = parse_num(varargin{i+1}); i=i+2;
            case '--height',   opts.height = parse_num(varargin{i+1}); i=i+2;
            case '--P',        opts.P = parse_num(varargin{i+1}); i=i+2;
            case '--G',        opts.G = parse_num(varargin{i+1}); i=i+2;
            case '--J',        opts.J = parse_num(varargin{i+1}); i=i+2;
            case '--T',        opts.T = parse_num(varargin{i+1}); i=i+2;
            case '--Fx',       opts.Fx = parse_num(varargin{i+1}); i=i+2;
            case '--My',       opts.My = parse_num(varargin{i+1}); i=i+2;
            case '--y',        opts.y = parse_num(varargin{i+1}); i=i+2;
            case '--rho',      opts.rho = parse_num(varargin{i+1}); i=i+2;
            case '--modes',    opts.modes = round(parse_num(varargin{i+1})); i=i+2;
            case '--nodes',    opts.nodes = varargin{i+1}; i=i+2;
            case '--members',  opts.members = varargin{i+1}; i=i+2;
            case '--forces',   opts.forces = varargin{i+1}; i=i+2;
            case '--fixity',   opts.fixity = varargin{i+1}; i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'beam',     out = act_beam(opts);
            case 'column',   out = act_column(opts);
            case 'torsion',  out = act_torsion(opts);
            case 'stress',   out = act_stress(opts);
            case 'modal',    out = act_modal(opts);
            case 'truss',    out = act_truss(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_beam(opts)
    L = opts.length;
    w = opts.load;
    E = opts.E;
    Inertia = opts.I;
    type = opts.type;
    % Max deflection and moment formulas (standard cases)
    switch type
        case 'simply'
            % Simply supported, uniform load
            delta_max = 5*w*L^4 / (384*E*Inertia);
            M_max = w*L^2 / 8;
            V_max = w*L / 2;
            sigma_max = M_max * (opts.y) / Inertia;
            reactionType = 'simply supported (pinned-pinned)';
        case 'cantilever'
            % Cantilever (fixed-free), uniform load
            delta_max = w*L^4 / (8*E*Inertia);
            M_max = w*L^2 / 2;
            V_max = w*L;
            sigma_max = M_max * opts.y / Inertia;
            reactionType = 'cantilever (fixed-free)';
        case 'fixed'
            % Fixed-fixed, uniform load
            delta_max = w*L^4 / (384*E*Inertia);   % same as simply with factor 1/384 vs 5/384
            delta_max = w*L^4 / (384*E*Inertia) * 1;  % min deflection
            M_max = w*L^2 / 12;   % end moment
            V_max = w*L / 2;
            sigma_max = M_max * opts.y / Inertia;
            reactionType = 'fixed-fixed';
        otherwise
            error('unknown beam type: %s (try simply|cantilever|fixed)', type);
    end
    out = struct();
    out.type = reactionType;
    out.length_m = L;
    out.load_N_per_m = w;
    out.E_Pa = E;
    out.I_m4 = Inertia;
    out.maxDeflection_m = delta_max;
    out.maxMoment_Nm = M_max;
    out.maxShear_N = V_max;
    out.maxStress_Pa = sigma_max;
    out.maxStress_MPa = sigma_max / 1e6;
end

function out = act_column(opts)
    % Euler buckling
    L = opts.height;
    E = opts.E;
    Inertia = opts.I;
    P = opts.P;
    % Effective length factor K (default pinned-pinned = 1)
    K = 1.0;
    Le = K * L;
    P_cr = pi^2 * E * Inertia / Le^2;
    % Slenderness ratio
    r = sqrt(Inertia / opts.A);   % radius of gyration
    slenderness = Le / r;
    % Factor of safety
    fs = P_cr / P;
    out = struct();
    out.length_m = L;
    out.E_Pa = E;
    out.I_m4 = Inertia;
    out.A_m2 = opts.A;
    out.effectiveLength_m = Le;
    out.K_factor = K;
    out.criticalLoad_N = P_cr;
    out.appliedLoad_N = P;
    out.factorOfSafety = fs;
    out.slendernessRatio = slenderness;
    out.bucklingMode = ternary_str(slenderness > 100, 'elastic (Euler)', 'inelastic');
end

function out = act_torsion(opts)
    L = opts.length;
    G = opts.G;
    J = opts.J;
    T = opts.T;
    % Torsion angle: theta = T*L / (G*J)
    theta = T * L / (G * J);
    % Max shear stress: tau = T*r / J, assume r = (J/pi)^(1/4) for solid circular
    r = (4*J/pi)^(1/4);   % approximate for solid circular
    tau_max = T * r / J;
    out = struct();
    out.length_m = L;
    out.G_Pa = G;
    out.J_m4 = J;
    out.appliedTorque_Nm = T;
    out.twistAngle_rad = theta;
    out.twistAngle_deg = rad2deg(theta);
    out.assumedRadius_m = r;
    out.maxShearStress_Pa = tau_max;
    out.maxShearStress_MPa = tau_max / 1e6;
end

function out = act_stress(opts)
    % Combined stress state
    Fx = opts.Fx;
    A = opts.A;
    My = opts.My;
    Inertia = opts.I;
    y = opts.y;
    sigma_axial = Fx / A;
    sigma_bending = My * y / Inertia;
    sigma_total = sigma_axial + sigma_bending;
    out = struct();
    out.axialForce_N = Fx;
    out.area_m2 = A;
    out.bendingMoment_Nm = My;
    out.distanceFromNeutralAxis_m = y;
    out.momentOfInertia_m4 = Inertia;
    out.axialStress_Pa = sigma_axial;
    out.bendingStress_Pa = sigma_bending;
    out.totalStress_Pa = sigma_total;
    out.totalStress_MPa = sigma_total / 1e6;
end

function out = act_modal(opts)
    % Modal analysis of continuous beam (Euler-Bernoulli)
    L = opts.length;
    E = opts.E;
    Inertia = opts.I;
    rho = opts.rho;
    A = opts.A;
    % Linear mass density
    mu = rho * A;
    % Natural frequencies: omega_n = (beta_n*L)^2 * sqrt(E*I/(rho*A*L^4))
    % For simply supported: beta_n*L = n*pi
    nModes = opts.modes;
    freqs = zeros(nModes, 1);
    modeShapes = cell(nModes, 1);
    x = linspace(0, L, 50)';
    for n = 1:nModes
        beta_L = n * pi;   % simply supported
        omega_n = (beta_L)^2 * sqrt(E*Inertia / (mu * L^4));
        fn = omega_n / (2*pi);
        freqs(n) = fn;
        modeShapes{n} = sin(n*pi*x/L);   % unnormalized
    end
    out = struct();
    out.type = 'simply supported Euler-Bernoulli beam';
    out.length_m = L;
    out.E_Pa = E;
    out.I_m4 = Inertia;
    out.density = rho;
    out.area_m2 = A;
    out.linearMassDensity = mu;
    out.numModes = nModes;
    out.naturalFrequencies_Hz = freqs(:)';
    out.modeShapesX = x(:)';
    out.modeShapes = modeShapes;
end

function out = act_truss(opts)
    % 2D truss analysis via direct stiffness method
    if isempty(opts.nodes), error('--nodes required: [x1 y1; x2 y2; ...]'); end
    if isempty(opts.members), error('--members required: [n1 n2; ...]'); end
    nodes = parse_mat(opts.nodes);
    members = parse_mat(opts.members);
    nNodes = size(nodes, 1);
    nMembers = size(members, 1);
    nDOF = 2 * nNodes;
    % Global stiffness matrix
    K = zeros(nDOF, nDOF);
    E = opts.E;
    A = opts.A;
    member_info = struct();
    lengths = zeros(nMembers, 1);
    for m = 1:nMembers
        n1 = members(m, 1);
        n2 = members(m, 2);
        x1 = nodes(n1, 1); y1 = nodes(n1, 2);
        x2 = nodes(n2, 1); y2 = nodes(n2, 2);
        L = sqrt((x2-x1)^2 + (y2-y1)^2);
        lengths(m) = L;
        c = (x2-x1) / L;
        s = (y2-y1) / L;
        % Element stiffness in global coords
        k_local = E*A/L * [c^2, c*s, -c^2, -c*s;
                           c*s, s^2, -c*s, -s^2;
                           -c^2, -c*s, c^2, c*s;
                           -c*s, -s^2, c*s, s^2];
        % DOF mapping
        dofs = [2*n1-1, 2*n1, 2*n2-1, 2*n2];
        for i = 1:4
            for j = 1:4
                K(dofs(i), dofs(j)) = K(dofs(i), dofs(j)) + k_local(i, j);
            end
        end
    end
    % Force vector
    F = zeros(nDOF, 1);
    if ~isempty(opts.forces)
        forceData = parse_mat(opts.forces);
        for r = 1:size(forceData, 1)
            if r <= nNodes
                F(2*r - 1) = forceData(r, 1);
                F(2*r) = forceData(r, 2);
            end
        end
    end
    % Fixity (boundary conditions)
    fixedDOF = [];
    if ~isempty(opts.fixity)
        fixData = parse_mat(opts.fixity);
        for r = 1:size(fixData, 1)
            for c = 1:2
                if fixData(r, c) == 1
                    fixedDOF(end+1) = 2*r - (2 - c);   % 1 -> x, 2 -> y
                end
            end
        end
    end
    % Reduce system
    allDOF = 1:nDOF;
    freeDOF = setdiff(allDOF, fixedDOF);
    K_red = K(freeDOF, freeDOF);
    F_red = F(freeDOF);
    % Solve displacements
    U_red = K_red \ F_red;
    U = zeros(nDOF, 1);
    U(freeDOF) = U_red;
    % Reactions
    reactions = K(fixedDOF, :) * U;
    % Member forces
    memberForces = zeros(nMembers, 1);
    for m = 1:nMembers
        n1 = members(m, 1);
        n2 = members(m, 2);
        x1 = nodes(n1, 1); y1 = nodes(n1, 2);
        x2 = nodes(n2, 1); y2 = nodes(n2, 2);
        L = lengths(m);
        c = (x2-x1) / L;
        s = (y2-y1) / L;
        u_e = [U(2*n1-1); U(2*n1); U(2*n2-1); U(2*n2)];
        % Axial force = E*A/L * [c s -c -s] * u
        memberForces(m) = E*A/L * [c, s, -c, -s] * u_e;
    end
    out = struct();
    out.numNodes = nNodes;
    out.numMembers = nMembers;
    out.nodeCoordinates = nodes;
    out.memberLengths_m = lengths(:)';
    out.nodalDisplacements = U(:)';
    out.memberForces_N = memberForces(:)';
    out.reactions_N = reactions(:)';
    out.fixedDOFs = fixedDOF';
    out.appliedForces = F(freeDOF)';
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function M = parse_mat(s)
    if ischar(s) || isstring(s), M = eval(s); else, M = s; end
end

function s = ternary_str(cond, a, b)
    if cond, s = a; else, s = b; end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
