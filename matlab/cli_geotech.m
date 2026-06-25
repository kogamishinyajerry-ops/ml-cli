function cli_geotech(action, varargin)
% CLI_GEOTECH Geotechnical engineering for ml CLI
%   CLI: ml geotech bearing   --B 1.5 --Df 1 --c 20 --phi 30 --gamma 18
%         ml geotech settlement --H 5 --Cc 0.3 --e0 0.8 --sigma0 100 --dsigma 50
%         ml geotech slope     --H 10 --phi 35 --c 15 --gamma 20 --beta 30
%         ml geotech earth_pressure --H 5 --phi 30 --gamma 18 --type active
%         ml geotech pile      --L 10 --D 0.5 --Nq 20 --Ngamma 100 --gamma 18
%         ml geotech spt       --N 15 --depth 5 --soil clay
%
%   Options:
%     --B M --Df M --c KPA --phi DEG --gamma KN/M3   bearing capacity
%     --H M --Cc --e0 --sigma0 --dsigma KPA          settlement
%     --beta DEG                                       slope angle
%     --type NAME       active|passive|at_rest         earth pressure type
%     --L M --D M --Nq --Ngamma                       pile parameters
%     --N N --depth M --soil NAME                      SPT correction
%     --format json|table|csv

    if nargin < 1, error('ml geotech <action> [options]'); end

    opts = struct('format','json','B',1.5,'Df',1,'c',20,'phi',30,'gamma',18, ...
                  'H',5,'Cc',0.3,'e0',0.8,'sigma0',100,'dsigma',50, ...
                  'beta',30,'type','active','L',10,'D',0.5,'Nq',20, ...
                  'Ngamma',100,'N',15,'depth',5,'soil','clay','Fs',2.5);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--B',      opts.B = parse_num(varargin{i+1}); i=i+2;
            case '--Df',     opts.Df = parse_num(varargin{i+1}); i=i+2;
            case '--c',      opts.c = parse_num(varargin{i+1}); i=i+2;
            case '--phi',    opts.phi = parse_num(varargin{i+1}); i=i+2;
            case '--gamma',  opts.gamma = parse_num(varargin{i+1}); i=i+2;
            case '--H',      opts.H = parse_num(varargin{i+1}); i=i+2;
            case '--Cc',     opts.Cc = parse_num(varargin{i+1}); i=i+2;
            case '--e0',     opts.e0 = parse_num(varargin{i+1}); i=i+2;
            case '--sigma0', opts.sigma0 = parse_num(varargin{i+1}); i=i+2;
            case '--dsigma', opts.dsigma = parse_num(varargin{i+1}); i=i+2;
            case '--beta',   opts.beta = parse_num(varargin{i+1}); i=i+2;
            case '--type',   opts.type = lower(varargin{i+1}); i=i+2;
            case '--L',      opts.L = parse_num(varargin{i+1}); i=i+2;
            case '--D',      opts.D = parse_num(varargin{i+1}); i=i+2;
            case '--Nq',     opts.Nq = parse_num(varargin{i+1}); i=i+2;
            case '--Ngamma',opts.Ngamma = parse_num(varargin{i+1}); i=i+2;
            case '--N',      opts.N = parse_num(varargin{i+1}); i=i+2;
            case '--depth',  opts.depth = parse_num(varargin{i+1}); i=i+2;
            case '--soil',   opts.soil = lower(varargin{i+1}); i=i+2;
            case '--Fs',     opts.Fs = parse_num(varargin{i+1}); i=i+2;
            case '--format', opts.format = varargin{i+1}; i=i+2;
            otherwise,       i=i+1;
        end
    end

    try
        switch lower(action)
            case 'bearing',      out = act_bearing(opts);
            case 'settlement',   out = act_settlement(opts);
            case 'slope',        out = act_slope(opts);
            case 'earth_pressure',out = act_earth_pressure(opts);
            case 'pile',         out = act_pile(opts);
            case 'spt',          out = act_spt(opts);
            otherwise,           error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_bearing(opts)
    B = opts.B; Df = opts.Df; c = opts.c;
    phi = deg2rad(opts.phi); gamma = opts.gamma;
    % Terzaghi bearing capacity factors
    Nq = exp(pi*tan(phi)) * tan(pi/4 + phi/2)^2;
    Nc = (Nq - 1) * cot(phi);
    if abs(phi) < 1e-10, Nc = 5.14; Nq = 1.0; end
    Ngamma = 2 * (Nq + 1) * tan(phi);
    % Terzaghi: q_ult = c*Nc + q*Nq + 0.5*gamma*B*Ngamma
    q_surcharge = gamma * Df;
    q_ult = c*Nc + q_surcharge*Nq + 0.5*gamma*B*Ngamma;
    q_allow = q_ult / opts.Fs;
    out = struct();
    out.action = 'bearing';
    out.method = 'Terzaghi (strip footing)';
    out.B = B; out.Df = Df;
    out.Nc = Nc; out.Nq = Nq; out.Ngamma = Ngamma;
    out.ultBearing_kPa = q_ult;
    out.allowableBearing_kPa = q_allow;
    out.safetyFactor = opts.Fs;
end

function out = act_settlement(opts)
    H = opts.H; Cc = opts.Cc; e0 = opts.e0;
    sigma0 = opts.sigma0; dsigma = opts.dsigma;
    % Consolidation settlement: S = H*Cc/(1+e0)*log10((σ0+Δσ)/σ0)
    S = H * Cc / (1 + e0) * log10((sigma0 + dsigma) / sigma0);
    % Compression index ratio
    if dsigma > sigma0
        condition = 'normally consolidated';
    else
        condition = 'overconsolidated (recompression)';
        Cr = Cc / 5;
        S = H * Cr / (1 + e0) * log10((sigma0 + dsigma) / sigma0);
    end
    out = struct();
    out.action = 'settlement';
    out.H_m = H; out.Cc = Cc; out.e0 = e0;
    out.initialStress_kPa = sigma0;
    out.stressIncrease_kPa = dsigma;
    out.settlement_m = S;
    out.settlement_mm = S * 1000;
    out.condition = condition;
end

function out = act_slope(opts)
    H = opts.H; phi = deg2rad(opts.phi);
    c = opts.c; gamma = opts.gamma; beta = deg2rad(opts.beta);
    % Infinite slope analysis with seepage
    Fs_dry = tand(phi) / tan(beta);
    if c > 0
        Fs_dry = Fs_dry + c / (gamma * H * cos(beta)^2 * tan(beta));
    end
    % With seepage (fully saturated)
    gammasat = gamma + 2;
    Fs_seepage = (gamma/gammasat) * (tand(phi)/tan(beta));
    % Taylor stability number: Ns = gamma*H/c
    Ns = gamma * H / c;
    stable = Fs_dry > 1.5;
    out = struct();
    out.action = 'slope';
    out.height_m = H; out.slopeAngle_deg = opts.beta;
    out.phi_deg = opts.phi; out.cohesion_kPa = c;
    out.factorOfSafety_dry = Fs_dry;
    out.factorOfSafety_seepage = Fs_seepage;
    out.taylorStabilityNumber = Ns;
    out.stable = stable;
end

function out = act_earth_pressure(opts)
    H = opts.H; phi = deg2rad(opts.phi);
    gamma = opts.gamma;
    switch opts.type
        case 'active'
            Ka = tan(pi/4 - phi/2)^2;
            Pa = 0.5 * gamma * H^2 * Ka;
            y = H/3;
            kind = 'active (wall moves away)';
        case 'passive'
            Kp = tan(pi/4 + phi/2)^2;
            Pa = 0.5 * gamma * H^2 * Kp;
            y = H/3;
            kind = 'passive (wall moves into soil)';
        case 'at_rest'
            K0 = 1 - sin(phi);
            Pa = 0.5 * gamma * H^2 * K0;
            y = H/3;
            kind = 'at-rest (no movement)';
        otherwise
            error('type must be active|passive|at_rest');
    end
    out = struct();
    out.action = 'earth_pressure';
    out.wallHeight_m = H;
    out.phi_deg = opts.phi;
    out.coefficient = struct(Kind, ka_or_kp(opts.type));
    out.force_kN = Pa;
    out.resultantDepth_m = y;
    out.type = kind;
end

function out = act_pile(opts)
    L = opts.L; D = opts.D;
    Nq = opts.Nq; Ngamma = opts.Ngamma; gamma = opts.gamma;
    % End bearing: qp = σv'*Nq at pile tip
    sigma_v = gamma * L;
    Qp = sigma_v * Nq * (pi * D^2 / 4);
    % Skin friction: Qs = perimeter * L * f_s (simplified)
    f_s = 0.01 * sigma_v;  % rough estimate
    Qs = pi * D * L * f_s;
    Qu = Qp + Qs;
    Qallow = Qu / opts.Fs;
    out = struct();
    out.action = 'pile';
    out.length_m = L; out.diameter_m = D;
    out.endBearing_kN = Qp;
    out.skinFriction_kN = Qs;
    out.ultCapacity_kN = Qu;
    out.allowableCapacity_kN = Qallow;
    out.safetyFactor = opts.Fs;
end

function out = act_spt(opts)
    N = opts.N; depth = opts.depth; soil = opts.soil;
    % Overburden correction: N60 = N * (95.76 / σv')^0.5
    sigma_v = 18 * depth;  % approximate
    Cn = min(2.0, sqrt(95.76 / sigma_v));
    N60 = Cn * N * 0.6;  % energy ratio correction for 60%
    % Soil classification
    switch soil
        case 'clay'
            if N60 < 4, consistency = 'very soft';
            elseif N60 < 8, consistency = 'soft';
            elseif N60 < 15, consistency = 'medium';
            elseif N60 < 30, consistency = 'stiff';
            else, consistency = 'hard'; end
        case 'sand'
            if N60 < 4, density = 'very loose';
            elseif N60 < 10, density = 'loose';
            elseif N60 < 30, density = 'medium';
            elseif N60 < 50, density = 'dense';
            else, density = 'very dense'; end
        otherwise
            consistency = 'see N60 value';
    end
    out = struct();
    out.action = 'spt';
    out.N_field = N; out.depth_m = depth;
    out.soilType = soil;
    out.N60 = N60;
    out.overburdenCorrection = Cn;
    if exist('consistency','var'), out.consistency = consistency; end
    if exist('density','var'), out.density = density; end
end

% =================== Helpers ===================
function k = ka_or_kp(type)
    if strcmp(type,'active'), k = 'Ka';
    elseif strcmp(type,'passive'), k = 'Kp';
    else, k = 'K0'; end
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
