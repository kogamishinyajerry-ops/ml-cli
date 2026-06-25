function cli_nuclear(action, varargin)
% CLI_NUCLEAR Nuclear physics & radiological engineering for ml CLI
%   CLI: ml nuclear decay     --N0 1e6 --T_half 10 --t 30
%         ml nuclear chain     --T1 10 --T2 50 --t 20
%         ml nuclear shielding --thickness 0.05 --rho 11350 --E_gamma 1.0 --material lead
%         ml nuclear activity  --mass 0.001 --T_half 432 --isotope Co60
%         ml nuclear criticality --mass 50 --rho 19.1 --enrichment 5 --shape sphere
%         ml nuclear dose      --activity 1e9 --distance 1 --isotope Cs137 --time 1
%
%   Options:
%     --N0             initial number of atoms
%     --T_half S/D     half-life (seconds or days)
%     --t S/D          elapsed time
%     --T1/T2          parent/daughter half-life
%     --thickness M    shield thickness
%     --rho KG/M3      material density
%     --E_gamma MEV    gamma energy
%     --material NAME  lead|concrete|steel|water|tungsten
%     --mass G         mass of radioactive material
%     --isotope NAME   Co60|Cs137|I131|Am241|U235|Pu239|Sr90
%     --activity BQ    source activity
%     --distance M     distance from source
%     --time H         exposure time

    if nargin < 1, error('ml nuclear <action> [options]'); end

    opts = struct('format','json','N0',1e6,'T_half',10,'t',30, ...
                  'T1',10,'T2',50, ...
                  'thickness',0.05,'rho',11350,'E_gamma',1.0,'material','lead', ...
                  'mass',0.001,'isotope','Co60', ...
                  'activity',1e9,'distance',1,'time',1, ...
                  'enrichment',5,'shape','sphere');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--N0',       opts.N0 = parse_num(varargin{i+1}); i=i+2;
            case '--T_half',   opts.T_half = parse_num(varargin{i+1}); i=i+2;
            case '--t',        opts.t = parse_num(varargin{i+1}); i=i+2;
            case '--T1',       opts.T1 = parse_num(varargin{i+1}); i=i+2;
            case '--T2',       opts.T2 = parse_num(varargin{i+1}); i=i+2;
            case '--thickness',opts.thickness = parse_num(varargin{i+1}); i=i+2;
            case '--rho',      opts.rho = parse_num(varargin{i+1}); i=i+2;
            case '--E_gamma',  opts.E_gamma = parse_num(varargin{i+1}); i=i+2;
            case '--material', opts.material = lower(varargin{i+1}); i=i+2;
            case '--mass',     opts.mass = parse_num(varargin{i+1}); i=i+2;
            case '--isotope',  opts.isotope = upper(varargin{i+1}); i=i+2;
            case '--activity', opts.activity = parse_num(varargin{i+1}); i=i+2;
            case '--distance', opts.distance = parse_num(varargin{i+1}); i=i+2;
            case '--time',     opts.time = parse_num(varargin{i+1}); i=i+2;
            case '--enrichment',opts.enrichment = parse_num(varargin{i+1}); i=i+2;
            case '--shape',    opts.shape = lower(varargin{i+1}); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'decay',       out = act_decay(opts);
            case 'chain',       out = act_chain(opts);
            case 'shielding',   out = act_shielding(opts);
            case 'activity',    out = act_activity(opts);
            case 'criticality', out = act_criticality(opts);
            case 'dose',        out = act_dose(opts);
            otherwise,          error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_decay(opts)
    N0 = opts.N0; Th = opts.T_half; t = opts.t;
    lambda = log(2) / Th;
    N = N0 * exp(-lambda * t);
    A = lambda * N;
    out = struct();
    out.action = 'decay';
    out.N0 = N0; out.halfLife = Th; out.elapsedTime = t;
    out.decayConstant = lambda;
    out.N_remaining = N;
    out.activity_Bq = A;
    out.decayFraction = 1 - N/N0;
end

function out = act_chain(opts)
    T1 = opts.T1; T2 = opts.T2; t = opts.t;
    l1 = log(2)/T1; l2 = log(2)/T2;
    % Bateman equation: N2(t) = l1/(l2-l1)*N1(0)*(e^(-l1*t)-e^(-l2*t))
    % Normalize N1(0)=1
    if abs(l2 - l1) > 1e-12
        N2 = (l1/(l2 - l1)) * (exp(-l1*t) - exp(-l2*t));
    else
        N2 = l1 * t * exp(-l1*t);  % secular equilibrium
    end
    % Time of max daughter activity
    t_max = log(l2/l1) / (l2 - l1);
    out = struct();
    out.action = 'chain';
    out.parentHalfLife = T1; out.daughterHalfLife = T2;
    out.N2_at_time_t = N2;
    out.t_max_daughter = t_max;
    out.equilibriumType = ternary_str(l2 > l1, 'transient', ...
                           ternary_str(abs(l2-l1)<1e-6, 'secular', 'no equilibrium'));
end

function out = act_shielding(opts)
    x = opts.thickness; rho = opts.rho;
    E = opts.E_gamma;
    mat = opts.material;
    % Mass attenuation coefficients (μ/ρ) cm²/g → convert to μ (1/m)
    muRhoMap = struct('lead', 0.07, 'concrete', 0.062, ...
                      'steel', 0.053, 'water', 0.07, 'tungsten', 0.04);
    % Energy correction ~ 1/E^(0.5) simplified
    if isfield(muRhoMap, mat), mu_rho = muRhoMap.(mat); else, mu_rho = 0.06; end
    mu = mu_rho * rho / 10;  % 1/cm → 1/m (converted from cm²/g to m⁻¹)
    % Linear attenuation
    I_over_I0 = exp(-mu * x);
    % Half-value layer: HVL = ln(2)/mu
    HVL = log(2) / mu;
    % Tenth-value layer: TVL = ln(10)/mu  
    TVL = log(10) / mu;
    out = struct();
    out.action = 'shielding';
    out.material = mat; out.thickness_m = x;
    out.attenuationCoeff_per_m = mu;
    out.transmission = I_over_I0;
    out.attenuation_pct = (1-I_over_I0)*100;
    out.HVL_m = HVL; out.TVL_m = TVL;
end

function out = act_activity(opts)
    mass = opts.mass; Th = opts.T_half; iso = opts.isotope;
    % Molar mass lookup (g/mol)
    mmMap = struct('CO60', 60, 'CS137', 137, 'I131', 131, ...
                   'AM241', 241, 'U235', 235, 'PU239', 239, 'SR90', 90);
    if isfield(mmMap, iso), M_mol = mmMap.(iso); else, M_mol = 100; end
    NA = 6.022e23;
    N = mass * NA / M_mol;
    lambda = log(2) / (Th * 3600*24);  % convert days to seconds
    A = lambda * N;
    out = struct();
    out.action = 'activity';
    out.isotope = iso; out.mass_g = mass;
    out.halfLife_days = Th;
    out.nAtoms = N;
    out.activity_Bq = A;
    out.activity_GBq = A / 1e9;
end

function out = act_criticality(opts)
    m = opts.mass; rho = opts.rho; e = opts.enrichment; shape = opts.shape;
    % Critical mass for bare U235 sphere: ~52kg at 100% enrichment
    m_crit_bare = 52 / (e/100);  % corrected for enrichment
    % Density correction
    V = m / rho;
    if strcmp(shape, 'sphere')
        % Simplistic: critical mass ∝ 1/ρ²
        m_crit = m_crit_bare * (19.1/rho)^2;
        r = (3*V / (4*pi))^(1/3);
        r_crit = (3*(m_crit/rho) / (4*pi))^(1/3);
    else
        m_crit = m_crit_bare * (19.1/rho)^2 * 1.3;  % 30% penalty for non-sphere
        r_crit = 0;
        r = 0;
    end
    critical = m > m_crit;
    keff_est = (m / m_crit)^0.67;
    out = struct();
    out.action = 'criticality';
    out.mass_kg = m; out.density_kg_m3 = rho;
    out.enrichment_pct = e; out.shape = shape;
    out.criticalMass_kg = m_crit;
    out.kEffective_estimate = min(keff_est, 1.5);
    out.critical = critical;
    out.method = 'simplified bare sphere model';
end

function out = act_dose(opts)
    A = opts.activity; d = opts.distance; t = opts.time;
    iso = opts.isotope;
    % Dose rate constant (μSv·m²/GBq·h) approximate
    gammaConstMap = struct('CO60', 0.35, 'CS137', 0.09, 'I131', 0.07, ...
                           'AM241', 0.015, 'SR90', 0.002);
    if isfield(gammaConstMap, iso), G = gammaConstMap.(iso); else, G = 0.1; end
    % Dose rate: H = G * A / d²
    A_GBq = A / 1e9;
    doseRate = G * A_GBq / d^2;  % μSv/h
    totalDose = doseRate * t;  % μSv
    out = struct();
    out.action = 'dose';
    out.isotope = iso; out.activity_Bq = A;
    out.distance_m = d; out.time_h = t;
    out.doseRate_uSv_per_h = doseRate;
    out.totalDose_uSv = totalDose;
    out.totalDose_mSv = totalDose / 1000;
end

function s = ternary_str(cond, a, b)
    if cond, s = a; else, s = b; end
end
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end
function print_output(out, fmt)
    switch lower(fmt), case 'json', jsonify(out); case 'table', to_table(out); case 'csv', to_csv(out); otherwise, jsonify(out); end
end
