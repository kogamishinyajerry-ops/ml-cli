function cli_vibration(action, varargin)
% CLI_VIBRATION Vibration analysis for ml CLI
%   CLI: ml vibration natural   --m 100 --k 10000 --c 50
%         ml vibration response  --m 1 --k 1000 --c 10 --F0 50 --omega 20
%         ml vibration isolation --freq 50 --fn 10 --damping 0.05
%         ml vibration sdof      --m 5 --k 20000 --F0 100 --omega 15 --c 30
%         ml vibration log_decrement --x1 10 --x2 5 --nCycles 3
%
%   Options:
%     --m KG            mass
%     --k N/M           stiffness
%     --c N·S/M         damping coefficient
%     --F0 N            force amplitude
%     --omega RAD/S     forcing frequency
%     --freq/--fn HZ    frequency (for isolation)
%     --damping ZETA    damping ratio
%     --x1/--x2         amplitudes for log decrement
%     --nCycles N       number of cycles
%     --format json|table|csv

    if nargin < 1, error('ml vibration <action> [options]'); end

    opts = struct('format','json','m',100,'k',10000,'c',50, ...
                  'F0',50,'omega',20, ...
                  'freq',50,'fn',10,'damping',0.05, ...
                  'x1',10,'x2',5,'nCycles',3);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--m',       opts.m = parse_num(varargin{i+1}); i=i+2;
            case '--k',       opts.k = parse_num(varargin{i+1}); i=i+2;
            case '--c',       opts.c = parse_num(varargin{i+1}); i=i+2;
            case '--F0',      opts.F0 = parse_num(varargin{i+1}); i=i+2;
            case '--omega',   opts.omega = parse_num(varargin{i+1}); i=i+2;
            case '--freq',    opts.freq = parse_num(varargin{i+1}); i=i+2;
            case '--fn',      opts.fn = parse_num(varargin{i+1}); i=i+2;
            case '--damping', opts.damping = parse_num(varargin{i+1}); i=i+2;
            case '--x1',      opts.x1 = parse_num(varargin{i+1}); i=i+2;
            case '--x2',      opts.x2 = parse_num(varargin{i+1}); i=i+2;
            case '--nCycles', opts.nCycles = round(parse_num(varargin{i+1})); i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    try
        switch lower(action)
            case 'natural',      out = act_natural(opts);
            case 'response',     out = act_response(opts);
            case 'isolation',    out = act_isolation(opts);
            case 'sdof',         out = act_sdof(opts);
            case 'log_decrement',out = act_log_decrement(opts);
            otherwise,           error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_natural(opts)
    m = opts.m; k = opts.k; c = opts.c;
    % Undamped natural frequency: ωn = sqrt(k/m)
    wn = sqrt(k / m);
    fn = wn / (2*pi);
    Tn = 1 / fn;
    % Damping ratio: ζ = c / (2*sqrt(m*k))
    zeta = c / (2 * sqrt(m * k));
    % Damped natural frequency: ωd = ωn * sqrt(1-ζ²)
    if zeta < 1
        wd = wn * sqrt(1 - zeta^2);
        fd = wd / (2*pi);
        delta = zeta;  % underdamped
        regime = 'underdamped';
    elseif abs(zeta - 1) < 1e-10
        wd = 0; fd = 0; delta = 1;
        regime = 'critically damped';
    else
        wd = 0; fd = 0; delta = zeta + sqrt(zeta^2 - 1);
        regime = 'overdamped';
    end
    out = struct();
    out.action = 'natural';
    out.mass_kg = m; out.stiffness_N_m = k; out.dampingCoeff = c;
    out.dampingRatio = zeta;
    out.wn_rad_s = wn; out.fn_Hz = fn; out.Tn_s = Tn;
    out.wd_rad_s = wd; out.fd_Hz = fd;
    out.regime = regime;
end

function out = act_response(opts)
    m = opts.m; k = opts.k; c = opts.c;
    F0 = opts.F0; omega = opts.omega;
    wn = sqrt(k/m); zeta = c/(2*sqrt(m*k));
    r = omega / wn;  % frequency ratio
    % Steady-state amplitude: X = (F0/k) / sqrt((1-r^2)^2 + (2*zeta*r)^2)
    X_static = F0 / k;
    denom = sqrt((1 - r^2)^2 + (2*zeta*r)^2);
    X = X_static / max(denom, 1e-12);
    % Phase angle: φ = atan2(2*zeta*r, 1-r^2)
    phi = atan2(2*zeta*r, 1 - r^2);
    % Magnification factor: H = X/X_static
    M = 1 / denom;
    % Resonance info
    if zeta < 0.707
        r_peak = sqrt(1 - 2*zeta^2);
        M_peak = 1 / (2*zeta*sqrt(1-zeta^2));
        omega_peak = r_peak * wn;
    else
        r_peak = 0; M_peak = 1; omega_peak = 0;
    end
    out = struct();
    out.action = 'response';
    out.wn = wn; out.zeta = zeta;
    out.frequencyRatio = r;
    out.staticDeflection = X_static;
    out.amplitude = X;
    out.magnificationFactor = M;
    out.phaseAngle_rad = phi;
    out.phaseAngle_deg = rad2deg(phi);
    out.peakResponse = struct('r_peak', r_peak, 'M_peak', M_peak, 'omega_peak', omega_peak);
end

function out = act_isolation(opts)
    f = opts.freq; fn = opts.fn; zeta = opts.damping;
    r = f / fn;
    % Transmissibility: T = sqrt(1+(2ζr)^2) / sqrt((1-r²)^2 + (2ζr)^2)
    T = sqrt(1 + (2*zeta*r)^2) / sqrt((1 - r^2)^2 + (2*zeta*r)^2);
    % Isolation efficiency: η = (1 - T) * 100
    efficiency = (1 - T) * 100;
    out = struct();
    out.action = 'isolation';
    out.forcingFreq_Hz = f;
    out.naturalFreq_Hz = fn;
    out.frequencyRatio = r;
    out.dampingRatio = zeta;
    out.transmissibility = T;
    out.isolationEfficiency_pct = efficiency;
    out.effectiveRegion = r > sqrt(2);
end

function out = act_sdof(opts)
    % Complete SDOF forced vibration summary
    m = opts.m; k = opts.k; c = opts.c;
    F0 = opts.F0; omega = opts.omega;
    wn = sqrt(k/m); zeta = c/(2*sqrt(m*k)); r = omega/wn;
    % Displacement amplitude
    Xst = F0/k;
    X = Xst / sqrt((1-r^2)^2 + (2*zeta*r)^2);
    % Velocity amplitude
    V = omega * X;
    % Acceleration amplitude
    A = omega^2 * X;
    % Force transmitted to base
    Ft = F0 * sqrt(1 + (2*zeta*r)^2) / sqrt((1-r^2)^2 + (2*zeta*r)^2);
    % Quality factor
    if zeta > 0, Qfactor = 1/(2*zeta); else, Qfactor = Inf; end
    out = struct();
    out.action = 'sdof';
    out.system = struct('m',m,'k',k,'c',c,'wn',wn,'zeta',zeta);
    out.excitation = struct('F0',F0,'omega',omega,'r',r);
    out.response = struct('displacement',X,'velocity',V,'acceleration',A);
    out.forceTransmitted = Ft;
    out.qualityFactor = Qfactor;
end

function out = act_log_decrement(opts)
    x1 = opts.x1; x2 = opts.x2; n = opts.nCycles;
    % Log decrement: δ = (1/n)*ln(x1/x2)
    delta = (1/n) * log(x1 / x2);
    zeta = delta / sqrt(4*pi^2 + delta^2);
    % Approximate damping ratio (light damping): ζ ≈ δ/(2π)
    zeta_approx = delta / (2*pi);
    out = struct();
    out.action = 'log_decrement';
    out.x1 = x1; out.x2 = x2; out.nCycles = n;
    out.delta = delta;
    out.zeta = zeta;
    out.zeta_approx = zeta_approx;
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
