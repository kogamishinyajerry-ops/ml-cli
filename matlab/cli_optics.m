function cli_optics(action, varargin)
% CLI_OPTICS Optics calculations for ml CLI
%   CLI: ml optics lens       --f 50 --u 200 --solve v
%         ml optics refraction --n1 1.0 --n2 1.5 --theta1 30
%         ml optics diffraction --lambda 500e-9 --slit 0.1e-3 --distance 1
%         ml optics na          --diameter 2e-3 --focal 10e-3
%         ml optics grating     --lines 600 --order 1 --lambda 500e-9
%         ml optics polarization --theta 45 --mode brewster --n1 1.0 --n2 1.5
%
%   Options:
%     --f MM            focal length
%     --u --v MM        object/image distance
%     --solve NAME      variable to solve for
%     --n1 --n2         refractive indices
%     --theta1 DEG      incident angle
%     --lambda M        wavelength
%     --slit M          slit width
%     --distance M      screen distance
%     --diameter M      lens diameter
%     --focal M         focal length
%     --lines PER_MM    grating lines
%     --order N         diffraction order
%     --theta DEG       polarization angle
%     --mode NAME       brewster|malus
%     --format json|table|csv

    if nargin < 1, error('ml optics <action> [options]'); end

    opts = struct('format','json','f',50,'u',0,'v',0,'solve','v', ...
                  'n1',1.0,'n2',1.5,'theta1',30,'lambda',500e-9, ...
                  'slit',0.1e-3,'distance',1,'diameter',2e-3,'focal',10e-3, ...
                  'lines',600,'order',1,'theta',45,'mode','brewster');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--f',       opts.f = parse_num(varargin{i+1}); i=i+2;
            case '--u',       opts.u = parse_num(varargin{i+1}); i=i+2;
            case '--v',       opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--solve',   opts.solve = lower(varargin{i+1}); i=i+2;
            case '--n1',      opts.n1 = parse_num(varargin{i+1}); i=i+2;
            case '--n2',      opts.n2 = parse_num(varargin{i+1}); i=i+2;
            case '--theta1',  opts.theta1 = parse_num(varargin{i+1}); i=i+2;
            case '--lambda',  opts.lambda = parse_num(varargin{i+1}); i=i+2;
            case '--slit',    opts.slit = parse_num(varargin{i+1}); i=i+2;
            case '--distance',opts.distance = parse_num(varargin{i+1}); i=i+2;
            case '--diameter',opts.diameter = parse_num(varargin{i+1}); i=i+2;
            case '--focal',   opts.focal = parse_num(varargin{i+1}); i=i+2;
            case '--lines',   opts.lines = parse_num(varargin{i+1}); i=i+2;
            case '--order',   opts.order = round(parse_num(varargin{i+1})); i=i+2;
            case '--theta',   opts.theta = parse_num(varargin{i+1}); i=i+2;
            case '--mode',    opts.mode = lower(varargin{i+1}); i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'lens',          out = act_lens(opts);
            case 'refraction',    out = act_refraction(opts);
            case 'diffraction',   out = act_diffraction(opts);
            case 'na',            out = act_na(opts);
            case 'grating',       out = act_grating(opts);
            case 'polarization',  out = act_polarization(opts);
            otherwise,            error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_lens(opts)
    solve = opts.solve;
    f = opts.f;
    switch solve
        case 'v'
            u = opts.u;
            v = 1 / (1/f - 1/u);
            M = -v / u;
        case 'u'
            v = opts.v;
            u = 1 / (1/f - 1/v);
            M = -v / u;
        case 'f'
            u = opts.u; v = opts.v;
            f = 1 / (1/u + 1/v);
            M = -v / u;
        case 'm'
            u = opts.u;
            M_requested = opts.v;
            v = -M_requested * u;
            f = 1 / (1/u + 1/v);
        otherwise
            error('solve must be v|u|f|m');
    end
    out = struct();
    out.action = 'lens';
    out.equation = '1/f = 1/u + 1/v';
    out.focalLength_mm = f;
    out.objectDistance_mm = u;
    out.imageDistance_mm = v;
    out.magnification = M;
    out.imageType = ternary_str(M < 0, 'inverted', 'upright');
end

function out = act_refraction(opts)
    n1 = opts.n1;
    n2 = opts.n2;
    theta1_deg = opts.theta1;
    theta1 = deg2rad(theta1_deg);
    % Snell's law: n1*sin(t1) = n2*sin(t2)
    sin_t2 = n1 * sin(theta1) / n2;
    if abs(sin_t2) > 1
        theta_crit = asind(n2 / n1);
        out = struct();
        out.action = 'refraction';
        out.equation = 'n1*sin(θ1) = n2*sin(θ2)';
        out.n1 = n1; out.n2 = n2;
        out.theta1_deg = theta1_deg;
        out.totalInternalReflection = true;
        out.criticalAngle_deg = theta_crit;
        out.theta2_deg = NaN;
        return;
    end
    theta2_deg = asind(sin_t2);
    out = struct();
    out.action = 'refraction';
    out.equation = 'n1*sin(θ1) = n2*sin(θ2)';
    out.n1 = n1; out.n2 = n2;
    out.theta1_deg = theta1_deg;
    out.theta2_deg = theta2_deg;
    out.totalInternalReflection = false;
end

function out = act_diffraction(opts)
    lambda = opts.lambda;
    a = opts.slit;
    L = opts.distance;
    % Single-slit: a*sin(θ) = m*λ, m = ±1, ±2, ...
    % Angular position of first minimum: sin(θ) ≈ λ/a
    theta1_rad = asin(lambda / a);
    % Fringe spacing on screen: Δy ≈ λL / a
    fringeSpacing = lambda * L / a;
    % Rayleigh criterion angular resolution
    out = struct();
    out.action = 'diffraction';
    out.wavelength_m = lambda;
    out.slitWidth_m = a;
    out.screenDistance_m = L;
    out.firstMinimumAngle_rad = theta1_rad;
    out.firstMinimumAngle_deg = rad2deg(theta1_rad);
    out.fringeSpacing_m = fringeSpacing;
    out.centralMaxHalfWidth_m = fringeSpacing;
end

function out = act_na(opts)
    D = opts.diameter;
    f = opts.focal;
    % Numerical aperture: NA = n*sin(θ) ≈ n*(D/2)/f (paraxial)
    NA = (D/2) / f;
    % f-number: f/D
    fnum = f / D;
    % Airy disk diameter (1st zero): d = 1.22*λ/NA ≈ 2.44*λ*f/D
    airyDiameter = 2.44 * 550e-9 * fnum;
    out = struct();
    out.action = 'na';
    out.diameter_mm = D*1000;
    out.focalLength_mm = f*1000;
    out.fNumber = fnum;
    out.na = NA;
    out.airyDiskDiameter_m = airyDiameter;
    out.airyDiskDiameter_um = airyDiameter * 1e6;
end

function out = act_grating(opts)
    linesPerMM = opts.lines;
    m = opts.order;
    lambda = opts.lambda;
    % Grating equation: d*(sinθ_i + sinθ_m) = m*λ
    d = 1e-3 / linesPerMM;  % groove spacing (m)
    % Normal incidence (θ_i = 0): d*sinθ = m*λ
    if d > 0 && abs(m*lambda / d) <= 1
        theta = asind(m * lambda / d);
    else
        theta = NaN;
    end
    % Free spectral range (overlap condition)
    fsr = lambda / m;
    out = struct();
    out.action = 'grating';
    out.linesPerMM = linesPerMM;
    out.grooveSpacing_m = d;
    out.order = m;
    out.wavelength_m = lambda;
    out.diffractionAngle_deg = theta;
    out.freeSpectralRange_m = fsr;
    out.resolvingPower = m * linesPerMM * 1e3 * d;  % ≈ m*N where N = L/d
end

function out = act_polarization(opts)
    mode = opts.mode;
    theta = opts.theta;
    switch mode
        case 'brewster'
            n1 = opts.n1; n2 = opts.n2;
            thetaB = atand(n2 / n1);
            out = struct();
            out.action = 'polarization';
            out.mode = 'brewster';
            out.n1 = n1; out.n2 = n2;
            out.brewsterAngle_deg = thetaB;
            out.note = 'reflected wave is fully s-polarized';
        case 'malus'
            I0 = 1;
            I = I0 * cosd(theta)^2;
            out = struct();
            out.action = 'polarization';
            out.mode = 'malus';
            out.angle_deg = theta;
            out.I_over_I0 = I;
            out.intensityRatio = I;
            out.transmission = I * 100;
        otherwise
            error('unknown mode: %s (brewster|malus)', mode);
    end
end

% =================== Helpers ===================
function s = ternary_str(cond, a, b)
    if cond, s = a; else, s = b; end
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
