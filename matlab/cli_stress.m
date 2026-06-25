function cli_stress(action, varargin)
% CLI_STRESS Stress analysis for ml CLI
%   CLI: ml stress principal    --sx 100 --sy 50 --tau 25
%         ml stress von_mises   --s1 200 --s2 100 --s3 50
%         ml stress mohr        --sx 100 --sy -50 --tau 40
%         ml stress concentration --nominal 50 --Kt 2.5
%         ml stress fatigue     --Su 600 --Se 250 --sigma_a 150 --sigma_m 100
%         ml stress failure     --material steel --sx 100 --sy 50 --tau 30
%
%   Options:
%     --sx/--sy/--tau MPa   plane stress state (σx, σy, τxy)
%     --s1/--s2/--s3 MPa     principal stresses
%     --nominal MPa          nominal stress
%     --Kt FLOAT             stress concentration factor
%     --Su MPa               ultimate tensile strength
%     --Se MPa               endurance limit
%     --sigma_a MPa          alternating stress amplitude
%     --sigma_m MPa          mean stress
%     --material NAME        steel|aluminum|titanium|cast_iron
%     --syield MPa           yield strength (overrides material default)
%     --format json|table|csv

    if nargin < 1, error('ml stress <action> [options]'); end

    opts = struct('format','json','sx',100,'sy',50,'tau',25, ...
                  's1',200,'s2',100,'s3',50, ...
                  'nominal',50,'Kt',2.5, 'Su',600,'Se',250, ...
                  'sigma_a',150,'sigma_m',100,'material','steel','syield',0);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--sx',        opts.sx = parse_num(varargin{i+1}); i=i+2;
            case '--sy',        opts.sy = parse_num(varargin{i+1}); i=i+2;
            case '--tau',       opts.tau = parse_num(varargin{i+1}); i=i+2;
            case '--s1',        opts.s1 = parse_num(varargin{i+1}); i=i+2;
            case '--s2',        opts.s2 = parse_num(varargin{i+1}); i=i+2;
            case '--s3',        opts.s3 = parse_num(varargin{i+1}); i=i+2;
            case '--nominal',   opts.nominal = parse_num(varargin{i+1}); i=i+2;
            case '--Kt',        opts.Kt = parse_num(varargin{i+1}); i=i+2;
            case '--Su',        opts.Su = parse_num(varargin{i+1}); i=i+2;
            case '--Se',        opts.Se = parse_num(varargin{i+1}); i=i+2;
            case '--sigma_a',   opts.sigma_a = parse_num(varargin{i+1}); i=i+2;
            case '--sigma_m',   opts.sigma_m = parse_num(varargin{i+1}); i=i+2;
            case '--material',  opts.material = lower(varargin{i+1}); i=i+2;
            case '--syield',    opts.syield = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'principal',     out = act_principal(opts);
            case 'von_mises',     out = act_von_mises(opts);
            case 'mohr',          out = act_mohr(opts);
            case 'concentration', out = act_concentration(opts);
            case 'fatigue',       out = act_fatigue(opts);
            case 'failure',       out = act_failure(opts);
            otherwise,            error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_principal(opts)
    sx = opts.sx; sy = opts.sy; txy = opts.tau;
    % Principal stresses: σ1,2 = (sx+sy)/2 ± sqrt(((sx-sy)/2)^2 + txy^2)
    avg = (sx + sy)/2;
    R = sqrt(((sx - sy)/2)^2 + txy^2);
    s1 = avg + R;
    s2 = avg - R;
    s3 = 0;  % plane stress assumption
    % Principal angles: tan(2θp) = 2*txy/(sx-sy)
    if abs(sx - sy) > 1e-12
        theta_p1 = 0.5 * atan2d(2*txy, sx-sy);
    else
        theta_p1 = 45 * sign(txy);
    end
    theta_p2 = theta_p1 + 90;
    % Max shear: τmax = R
    tau_max = R;
    % Von Mises from principal
    von_mises = sqrt(s1^2 - s1*s2 + s2^2);
    % Tresca
    tresca = max(abs(s1-s2), max(abs(s2-s3), abs(s3-s1)));
    out = struct();
    out.action = 'principal';
    out.given = struct('sx',sx,'sy',sy,'txy',txy);
    out.s1 = struct('value', s1, 'angle_deg', theta_p1);
    out.s2 = struct('value', s2, 'angle_deg', theta_p2);
    out.s3 = 0;
    out.tau_max = tau_max;
    out.vonMises = von_mises;
    out.tresca = tresca;
end

function out = act_von_mises(opts)
    s1 = opts.s1; s2 = opts.s2; s3 = opts.s3;
    % von Mises: σv = sqrt(0.5*((s1-s2)^2 + (s2-s3)^2 + (s3-s1)^2))
    vm = sqrt(0.5 * ((s1-s2)^2 + (s2-s3)^2 + (s3-s1)^2));
    % Stress triaxiality
    p = (s1 + s2 + s3) / 3;  % hydrostatic
    tri = 0;
    if vm > 0, tri = p / vm; end
    out = struct();
    out.action = 'von_mises';
    out.s1 = s1; out.s2 = s2; out.s3 = s3;
    out.vonMisesStress = vm;
    out.hydrostaticPressure = p;
    out.triaxiality = tri;
end

function out = act_mohr(opts)
    sx = opts.sx; sy = opts.sy; txy = opts.tau;
    % Center and radius of Mohr's circle
    C = (sx + sy) / 2;
    R = sqrt(((sx - sy)/2)^2 + txy^2);
    s1 = C + R;
    s2 = C - R;
    tau_max = R;
    % Mohr's circle points at 15° intervals
    theta = linspace(0, 360, 24);
    sigma_n = C + R * cosd(2*theta);
    tau_n = R * sind(2*theta);
    out = struct();
    out.action = 'mohr';
    out.center = C;
    out.radius = R;
    out.principal1 = s1;
    out.principal2 = s2;
    out.tau_max = tau_max;
    out.mohrCircle = struct('sigma', sigma_n, 'tau', tau_n);
end

function out = act_concentration(opts)
    s_nom = opts.nominal;
    Kt = opts.Kt;
    s_max = Kt * s_nom;
    out = struct();
    out.action = 'concentration';
    out.nominalStress = s_nom;
    out.Kt = Kt;
    out.peakStress = s_max;
    out.stressIncrease_pct = (Kt - 1) * 100;
end

function out = act_fatigue(opts)
    Su = opts.Su;
    Se = opts.Se;
    sa = opts.sigma_a;
    sm = opts.sigma_m;
    % Modified Goodman: sa/Se + sm/Su = 1/n
    n_goodman = 1 / (sa/Se + sm/Su);
    % Soderberg: sa/Se + sm/Sy = 1/n
    Sy = Su * 0.7;  % approximate
    n_soderberg = 1 / (sa/Se + sm/Sy);
    % Gerber: n*sa/Se + (n*sm/Su)^2 = 1 → n = ?
    a = (sm/Su)^2;
    b = -sa/Se;
    c = 1;
    disc = b^2 - 4*a*c;
    if disc >= 0 && a > 0
        n_gerber = (-b + sqrt(disc)) / (2*a);
    else
        n_gerber = n_goodman;
    end
    % ASME-elliptic
    n_asme = 1 / sqrt((sa/Se)^2 + (sm/Sy)^2);
    out = struct();
    out.action = 'fatigue';
    out.model = 'Modified Goodman';
    out.Su = Su; out.Se = Se; out.Sy_approx = Sy;
    out.sigma_a = sa; out.sigma_m = sm;
    out.safetyFactor_goodman = n_goodman;
    out.safetyFactor_soderberg = n_soderberg;
    out.safetyFactor_gerber = n_gerber;
    out.safetyFactor_asme = n_asme;
    out.fatigueLife = ternary_str(n_goodman > 1, 'over 10^6 cycles', ...
                   ternary_str(n_goodman > 0.5, 'finite life', 'immediate failure'));
end

function out = act_failure(opts)
    mat = opts.material;
    sy = opts.syield;
    if sy <= 0
        % Default yield strengths (MPa)
        matProps = struct('steel', 250, 'aluminum', 276, ...
                          'titanium', 880, 'cast_iron', 200, 'brass', 200);
        if isfield(matProps, mat), sy = matProps.(mat); else, sy = 250; end
    end
    sx = opts.sx; sy_val = opts.sy; txy = opts.tau;
    % Von Mises equivalent
    vm = sqrt(sx^2 - sx*sy_val + sy_val^2 + 3*txy^2);
    % Safety factors
    n_vm = sy / vm;
    % Tresca (max shear theory)
    R = sqrt(((sx-sy_val)/2)^2 + txy^2);
    n_tresca = sy / (2*R);
    out = struct();
    out.action = 'failure';
    out.material = mat;
    out.yieldStrength_MPa = sy;
    out.stressState = struct('sx', sx, 'sy', sy_val, 'txy', txy);
    out.vonMises = vm;
    out.safetyFactor_vonMises = n_vm;
    out.safetyFactor_Tresca = n_tresca;
    out.yielding = n_vm < 1;
    out.utilization_pct = (vm / sy) * 100;
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
