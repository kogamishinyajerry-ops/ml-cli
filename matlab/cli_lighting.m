function cli_lighting(action, varargin)
% CLI_LIGHTING Lighting design for ml CLI
%   CLI: ml lighting lumen     --area 100 --lux 500 --LLF 0.8 --lor 0.7
%         ml lighting point     --I 1000 --h 3 --d 2 --theta 30
%         ml lighting daylight  --window 5 --room 50 --trans 0.7 --ext 10000
%         ml lighting glare     --L_s 5000 --L_b 200 --omega 0.01 --p 2
%         ml lighting layout    --area 100 --fixtures 12 --rows 3
%         ml lighting energy    --power 36 --hours 3000 --n 12
%
%   Options:
%     --area M2         room area
%     --lux LX          target illuminance
%     --LLF             light loss factor
%     --lor             light output ratio
%     --I CD            luminous intensity (cd)
%     --h/--d M         mounting height / horizontal distance
%     --theta DEG       angle from nadir
%     --window M2       window area
%     --room M2         room floor area
%     --trans           window transmittance
%     --ext LX          external illuminance
%     --L_s/L_b CD/M2   source/background luminance
%     --omega SR        solid angle of source
%     --p FLOAT         position index
%     --fixtures N      number of luminaires
%     --rows N          number of rows
%     --power W         power per luminaire
%     --hours H          annual operating hours

    if nargin < 1, error('ml lighting <action> [options]'); end

    opts = struct('format','json','area',100,'lux',500,'LLF',0.8,'lor',0.7, ...
                  'I',1000,'h_lite',3,'d',2,'theta',30, ...
                  'window',5,'room',50,'trans',0.7,'ext',10000, ...
                  'L_s',5000,'L_b',200,'omega_val',0.01,'p_val',2, ...
                  'fixtures',12,'rows',3, ...
                  'power',36,'hours',3000,'n',12);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--area',    opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--lux',     opts.lux = parse_num(varargin{i+1}); i=i+2;
            case '--LLF',     opts.LLF = parse_num(varargin{i+1}); i=i+2;
            case '--lor',     opts.lor = parse_num(varargin{i+1}); i=i+2;
            case '--I',       opts.I = parse_num(varargin{i+1}); i=i+2;
            case '--h',       opts.h_lite = parse_num(varargin{i+1}); i=i+2;
            case '--d',       opts.d = parse_num(varargin{i+1}); i=i+2;
            case '--theta',   opts.theta = parse_num(varargin{i+1}); i=i+2;
            case '--window',  opts.window = parse_num(varargin{i+1}); i=i+2;
            case '--room',    opts.room = parse_num(varargin{i+1}); i=i+2;
            case '--trans',   opts.trans = parse_num(varargin{i+1}); i=i+2;
            case '--ext',     opts.ext = parse_num(varargin{i+1}); i=i+2;
            case '--L_s',     opts.L_s = parse_num(varargin{i+1}); i=i+2;
            case '--L_b',     opts.L_b = parse_num(varargin{i+1}); i=i+2;
            case '--omega',   opts.omega_val = parse_num(varargin{i+1}); i=i+2;
            case '--p',       opts.p_val = parse_num(varargin{i+1}); i=i+2;
            case '--fixtures',opts.fixtures = round(parse_num(varargin{i+1})); i=i+2;
            case '--rows',    opts.rows = round(parse_num(varargin{i+1})); i=i+2;
            case '--power',   opts.power = parse_num(varargin{i+1}); i=i+2;
            case '--hours',   opts.hours = parse_num(varargin{i+1}); i=i+2;
            case '--n',       opts.n = round(parse_num(varargin{i+1})); i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'lumen',    out = act_lumen(opts);
            case 'point',    out = act_point(opts);
            case 'daylight', out = act_daylight(opts);
            case 'glare',    out = act_glare(opts);
            case 'layout',   out = act_layout(opts);
            case 'energy',   out = act_energy(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_lumen(opts)
    A = opts.area; E = opts.lux;
    LLF = opts.LLF; LOR = opts.lor;
    % Total lumens: Φ = E*A / (UF*LLF), UF ≈ 0.5 for typical rooms
    UF = 0.5;  % utilization factor
    lumens = E * A / (UF * LLF * LOR);
    % Luminaires needed (assume 4000 lm per 36W LED)
    lm_per_fixture = 4000;
    n = ceil(lumens / lm_per_fixture);
    out = struct();
    out.action = 'lumen';
    out.method = 'Lumen method (CIBSE)';
    out.area_m2 = A; out.targetIlluminance_lx = E;
    out.utilizationFactor = UF; out.LLF = LLF; out.LOR = LOR;
    out.totalLumens_lm = lumens;
    out.fixturesRecommended = n;
end

function out = act_point(opts)
    I = opts.I; h = opts.h_lite; d = opts.d;
    theta_deg = opts.theta;
    % Point-by-point: E = I*cos³θ / h² (at nadir d=0, θ=0)
    % General: E = I*cosθ / r² where r = h/cosθ
    dist = sqrt(h^2 + d^2);
    cos_theta = h / dist;
    E_h = I * cos_theta^3 / h^2;  % horizontal illuminance
    E_v = I * cos_theta^2 * d / (h * h^2);  % vertical component
    % At specific angle
    theta = deg2rad(theta_deg);
    E_at_angle = I * cos(theta)^3 / h^2;
    out = struct();
    out.action = 'point';
    out.intensity_cd = I; out.mountingHeight_m = h;
    out.horizDistance_m = d;
    out.E_horizontal_lx = E_h;
    out.E_atAngle_lx = E_at_angle;
end

function out = act_daylight(opts)
    A_win = opts.window; A_room = opts.room;
    tau = opts.trans; E_ext = opts.ext;
    % Daylight factor: DF = (window/room) * transmittance * (sky angle) * 100
    skyAngle = 0.5;  % typical unobstructed
    DF = (A_win / A_room) * tau * skyAngle * 100;
    % Internal illuminance = DF * external / 100
    E_int = DF * E_ext / 100;
    out = struct();
    out.action = 'daylight';
    out.windowArea_m2 = A_win;
    out.roomArea_m2 = A_room;
    out.daylightFactor_pct = DF;
    out.internalIlluminance_lx = E_int;
end

function out = act_glare(opts)
    Ls = opts.L_s; Lb = opts.L_b;
    omega = opts.omega_val; p = opts.p_val;
    % UGR: UGR = 8*log10(0.25/Lb * sum(Ls²*omega/p²))
    UGR = 8 * log10(0.25 / max(Lb, 0.1) * (Ls^2 * omega / p^2));
    if UGR < 13, rating = 'negligible';
    elseif UGR < 16, rating = 'just perceptible';
    elseif UGR < 19, rating = 'acceptable';
    elseif UGR < 22, rating = 'just uncomfortable';
    elseif UGR < 28, rating = 'uncomfortable';
    else, rating = 'intolerable'; end
    out = struct();
    out.action = 'glare';
    out.method = 'Unified Glare Rating (CIE 117)';
    out.L_source = Ls; out.L_background = Lb;
    out.solidAngle_sr = omega; out.positionIndex = p;
    out.UGR = UGR;
    out.rating = rating;
end

function out = act_layout(opts)
    A = opts.area; n = opts.fixtures; rows = opts.rows;
    cols = ceil(n / rows);
    spacing = sqrt(A / (rows * cols));
    % Uniformity check: spacing/height ratio should be < 1.5
    out = struct();
    out.action = 'layout';
    out.area_m2 = A; out.fixtures = n;
    out.rows = rows; out.columns = cols;
    out.spacing_m = spacing;
    out.uniformity = spacing;
end

function out = act_energy(opts)
    P = opts.power; hrs = opts.hours; n = opts.n;
    totalP = n * P;  % W
    annualKWh = totalP * hrs / 1000;
    out = struct();
    out.action = 'energy';
    out.nLuminaires = n;
    out.powerPerLuminaire_W = P;
    out.annualHours = hrs;
    out.annualEnergy_kWh = annualKWh;
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end
function print_output(out, fmt)
    switch lower(fmt), case 'json', jsonify(out); case 'table', to_table(out); case 'csv', to_csv(out); otherwise, jsonify(out); end
end
