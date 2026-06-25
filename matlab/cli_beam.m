function cli_beam(action, varargin)
% CLI_BEAM Beam analysis for ml CLI
%   CLI: ml beam deflection --length 5 --load 10000 --type simply --loadType point --loadPos 2.5
%         ml beam moment    --length 5 --load 10000 --type simply --loadType point --loadPos 2.5
%         ml beam shear     --length 5 --load 10000 --type simply --loadType udl
%         ml beam section   --b 0.1 --h 0.2 --E 200e9
%         ml beam reactions  --length 5 --load 10000 --type simply --loadType point --loadPos 2.5
%         ml beam slope      --length 5 --load 10000 --type cantilever --loadType point --loadPos 5
%
%   Options:
%     --length M        beam length
%     --load N/N_M      load magnitude (N for point, N/m for distributed)
%     --type NAME       simply|cantilever|fixed|propped
%     --loadType NAME   point|udl|triangular|moment
%     --loadPos M       load position from left (m)
%     --loadPos2 M      end position for distributed loads
%     --b --h M         section width/height
%     --E Pa            Young's modulus
%     --I M4            moment of inertia (overrides b×h)
%     --x M             specific position to evaluate
%     --npts N          number of sample points (default 20)
%     --format json|table|csv

    if nargin < 1, error('ml beam <action> [options]'); end

    opts = struct('format','json','length',5,'load',10000,'type','simply', ...
                  'loadType','point','loadPos',2.5,'loadPos2',0, ...
                  'b',0.1,'h',0.2,'E',200e9,'I',0,'x',0,'npts',20);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--length',   opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--load',     opts.load = parse_num(varargin{i+1}); i=i+2;
            case '--type',     opts.type = lower(varargin{i+1}); i=i+2;
            case '--loadType', opts.loadType = lower(varargin{i+1}); i=i+2;
            case '--loadPos',  opts.loadPos = parse_num(varargin{i+1}); i=i+2;
            case '--loadPos2', opts.loadPos2 = parse_num(varargin{i+1}); i=i+2;
            case '--b',        opts.b = parse_num(varargin{i+1}); i=i+2;
            case '--h',        opts.h = parse_num(varargin{i+1}); i=i+2;
            case '--E',        opts.E = parse_num(varargin{i+1}); i=i+2;
            case '--I',        opts.I = parse_num(varargin{i+1}); i=i+2;
            case '--x',        opts.x = parse_num(varargin{i+1}); i=i+2;
            case '--npts',     opts.npts = round(parse_num(varargin{i+1})); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'deflection', out = act_deflection(opts);
            case 'moment',     out = act_moment(opts);
            case 'shear',      out = act_shear(opts);
            case 'section',    out = act_section(opts);
            case 'reactions',  out = act_reactions(opts);
            case 'slope',      out = act_slope(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_deflection(opts)
    L = opts.length;
    P = get_load(opts);
    supp = opts.type;
    loadType = opts.loadType;
    [sections, EI] = get_section(opts);
    npts = opts.npts;
    x = linspace(0, L, npts);
    [delta, M, V] = beam_solve(L, P, supp, loadType, opts, x, EI);
    maxDef = max(abs(delta));
    maxDefPos = x(find(abs(delta) == maxDef, 1));
    out = struct();
    out.action = 'deflection';
    out.length = L; out.support = supp; out.loadType = loadType;
    out.maxDeflection_m = maxDef;
    out.maxDeflectionPos_m = maxDefPos;
    out.maxDeflection_ratio = L / maxDef;
    out.EI = EI;
    out.curve = struct('x', x, 'deflection', delta);
end

function out = act_moment(opts)
    L = opts.length;
    P = get_load(opts);
    supp = opts.type;
    loadType = opts.loadType;
    [sections, EI] = get_section(opts);
    npts = opts.npts;
    x = linspace(0, L, npts);
    [delta, M, V] = beam_solve(L, P, supp, loadType, opts, x, EI);
    [Mmax, maxIdx] = max(abs(M));
    out = struct();
    out.action = 'moment';
    out.length = L; out.support = supp; out.loadType = loadType;
    out.maxMoment_Nm = M(maxIdx);
    out.maxMomentPos_m = x(maxIdx);
    out.diagram = struct('x', x, 'moment', M);
end

function out = act_shear(opts)
    L = opts.length;
    P = get_load(opts);
    supp = opts.type;
    loadType = opts.loadType;
    [sections, EI] = get_section(opts);
    npts = opts.npts;
    x = linspace(0, L, npts);
    [delta, M, V] = beam_solve(L, P, supp, loadType, opts, x, EI);
    [Vmax, maxIdx] = max(abs(V));
    out = struct();
    out.action = 'shear';
    out.length = L; out.support = supp; out.loadType = loadType;
    out.maxShear_N = V(maxIdx);
    out.maxShearPos_m = x(maxIdx);
    out.diagram = struct('x', x, 'shear', V);
end

function out = act_section(opts)
    b = opts.b;
    h = opts.h;
    E = opts.E;
    if opts.I > 0
        I = opts.I;
    else
        I = b * h^3 / 12;
    end
    A = b * h;
    S = b * h^2 / 6;  % section modulus
    y_max = h / 2;
    % Neutral axis position
    y_na = h / 2;
    r_gyration = sqrt(I / A);
    out = struct();
    out.action = 'section';
    out.width_m = b; out.height_m = h;
    out.area_m2 = A;
    out.I_m4 = I;
    out.S_m3 = S; out.sectionModulus = S;
    out.yNeutralAxis_m = y_na;
    out.radiusGyration_m = r_gyration;
    out.E_Pa = E;
    out.EI = E * I;
end

function out = act_reactions(opts)
    L = opts.length;
    P = get_load(opts);
    supp = opts.type;
    loadType = opts.loadType;
    [Ra, Rb, Ma] = beam_reactions(L, P, supp, loadType, opts);
    out = struct();
    out.action = 'reactions';
    out.length = L; out.support = supp;
    out.Ra_N = Ra; out.Rb_N = Rb;
    if ~isnan(Ma), out.Ma_Nm = Ma; end
    % Equilibrium check
    check = 0;
    if strcmp(loadType, 'point')
        check = Ra + Rb - P;
    elseif strcmp(loadType, 'udl')
        check = Ra + Rb - P*L;
    end
    out.equilibriumCheck = abs(check) < 1e-6;
end

function out = act_slope(opts)
    L = opts.length;
    P = get_load(opts);
    supp = opts.type;
    loadType = opts.loadType;
    [sections, EI] = get_section(opts);
    npts = opts.npts;
    x = linspace(0, L, npts);
    [delta, M, V] = beam_solve(L, P, supp, loadType, opts, x, EI);
    % Slope by finite difference of deflection
    slope = zeros(1, npts);
    dx = L/(npts-1);
    slope(2:end-1) = (delta(3:end) - delta(1:end-2)) / (2*dx);
    slope(1) = (delta(2) - delta(1)) / dx;
    slope(end) = (delta(end) - delta(end-1)) / dx;
    slope_deg = atand(slope);
    [maxSlope, idx] = max(abs(slope_deg));
    out = struct();
    out.action = 'slope';
    out.length = L; out.support = supp;
    out.maxSlope_deg = slope_deg(idx);
    out.maxSlopePos_m = x(idx);
    out.EI = EI;
    out.curve = struct('x', x, 'slope_deg', slope_deg);
end

% =================== Beam solver ===================
function [delta, M, V] = beam_solve(L, P, supp, loadType, opts, x, EI)
    n = numel(x);
    M = zeros(1, n);
    V = zeros(1, n);
    [Ra, Rb, Ma] = beam_reactions(L, P, supp, loadType, opts);
    for i = 1:n
        xi = x(i);
        % Shear and moment at xi using section method
        if strcmp(loadType, 'point')
            s = opts.loadPos;
            V(i) = Ra;
            if xi >= s, V(i) = V(i) - P; end
            M(i) = Ra * xi;
            if xi >= s
                M(i) = M(i) - P * (xi - s);
            end
        elseif strcmp(loadType, 'udl')
            V(i) = Ra - P * xi;
            M(i) = Ra * xi - 0.5 * P * xi^2;
        elseif strcmp(loadType, 'triangular')
            w_max = P;
            w_xi = w_max * (xi / L);
            V(i) = Ra - 0.5 * w_xi * xi;
            M(i) = Ra * xi - w_xi * xi^2 / 6;
        end
        % Support moments
        if strcmp(supp, 'cantilever') && xi < 1e-10
            M(i) = -get_M_fixed(L, P, loadType, opts);
        end
        if strcmp(supp, 'fixed') && (xi < 1e-10 || xi > L - 1e-10)
            M(i) = -abs(M(i));  % end restraint
        end
    end
    % Deflection by double integration (numerical)
    % Use M/EI → integrate twice
    phi = zeros(1, n);
    delta = zeros(1, n);
    dx = L / (n - 1);
    % Trapezoidal integration of M/EI
    mEI = M / EI;
    for i = 2:n
        phi(i) = phi(i-1) + 0.5 * (mEI(i) + mEI(i-1)) * dx;
    end
    % Adjust for boundary conditions
    if strcmp(supp, 'simply')
        phi = phi - phi(1);  % slope adjust (approximate zero slope at ends average)
        for i = 2:n
            delta(i) = delta(i-1) + 0.5 * (phi(i) + phi(i-1)) * dx;
        end
        % Ensure zero at both ends
        if abs(delta(end)) > 1e-12
            correction = delta(end) * x / L;
            delta = delta - correction;
        end
    elseif strcmp(supp, 'cantilever')
        for i = 2:n
            delta(i) = delta(i-1) + 0.5 * (phi(i) + phi(i-1)) * dx;
        end
    elseif strcmp(supp, 'fixed')
        for i = 2:n
            delta(i) = delta(i-1) + 0.5 * (phi(i) + phi(i-1)) * dx;
        end
    end
end

function [Ra, Rb, Ma] = beam_reactions(L, P, supp, loadType, opts)
    Ra = 0; Rb = 0; Ma = NaN;
    switch supp
        case 'simply'
            if strcmp(loadType, 'point')
                s = opts.loadPos;
                Rb = P * s / L;
                Ra = P - Rb;
            elseif strcmp(loadType, 'udl')
                Ra = P * L / 2;
                Rb = Ra;
            elseif strcmp(loadType, 'triangular')
                Ra = P * L / 3;
                Rb = P * L / 6;
            end
        case 'cantilever'
            if strcmp(loadType, 'point')
                s = opts.loadPos;
                Ra = P;
                Ma = -P * s;
            elseif strcmp(loadType, 'udl')
                Ra = P * L;
                Ma = -0.5 * P * L^2;
            end
            Rb = 0;
        case 'fixed'
            if strcmp(loadType, 'point')
                s = opts.loadPos;
                Ra = P * (L-s)^2 * (L+2*s) / L^3;
                Rb = P * s^2 * (3*L - 2*s) / L^3;
                Ma = -P * s * (L-s)^2 / L^2;
            elseif strcmp(loadType, 'udl')
                Ra = P * L / 2;
                Rb = Ra;
                Ma = -P * L^2 / 12;
            end
        case 'propped'
            if strcmp(loadType, 'point')
                s = opts.loadPos;
                Rb = P * s^2 * (3*L - s) / (2*L^3);
                Ra = P - Rb;
                Ma = -P * s * (L^2 - s^2) / (2*L^2);
            elseif strcmp(loadType, 'udl')
                Rb = 3 * P * L / 8;
                Ra = 5 * P * L / 8;
                Ma = -P * L^2 / 8;
            end
        otherwise
            error('unknown support: %s', supp);
    end
end

function Mf = get_M_fixed(L, P, loadType, opts)
    if strcmp(loadType, 'point')
        s = opts.loadPos;
        Mf = P * s * (L-s)^2 / L^2;
    elseif strcmp(loadType, 'udl')
        Mf = P * L^2 / 12;
    else
        Mf = 0;
    end
end

function P = get_load(opts)
    P = opts.load;
end

function [sections, EI] = get_section(opts)
    if opts.I > 0
        I = opts.I;
    else
        I = opts.b * opts.h^3 / 12;
    end
    EI = opts.E * I;
    sections = struct('b', opts.b, 'h', opts.h, 'I', I, 'E', opts.E);
end

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
