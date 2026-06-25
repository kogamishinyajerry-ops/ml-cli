function cli_seismic(action, varargin)
% CLI_SEISMIC Earthquake engineering for ml CLI
%   CLI: ml seismic spectrum  --Sds 1.0 --Sd1 0.6 --T 0.5 --R 8
%         ml seismic base_shear --W 5000 --Sds 1.0 --R 8 --I 1.0
%         ml seismic pga       --Mw 6.5 --distance 20 --soil rock
%         ml seismic soil      --Vs30 200 --N60 10
%         ml seismic liquefaction --N60 8 --depth 5 --Mw 6.5 --PGA 0.3
%         ml seismic drift     --storyHeight 3 --displacement 0.05
%
%   Options:
%     --Sds/Sd1 G      spectral acceleration at short/1s period
%     --T SEC           structural period
%     --R FLOAT         response modification factor
%     --W KN            seismic weight
%     --I FLOAT         importance factor
%     --Mw FLOAT        moment magnitude
%     --distance KM     epicentral distance
%     --soil NAME       rock|dense|stiff|soft
%     --Vs30 M/S        shear wave velocity (30m avg)
%     --N60 N           SPT N-value (60% energy)
%     --PGA G           peak ground acceleration
%     --storyHeight M   story height
%     --displacement M   story displacement
%     --format json|table|csv

    if nargin < 1, error('ml seismic <action> [options]'); end

    opts = struct('format','json','Sds',1.0,'Sd1',0.6,'T',0.5,'R',8, ...
                  'W',5000,'I',1.0,'Mw',6.5,'distance',20,'soil','rock', ...
                  'Vs30',200,'N60',10,'PGA',0.3,'depth',5, ...
                  'storyHeight',3,'displacement',0.05);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--Sds',         opts.Sds = parse_num(varargin{i+1}); i=i+2;
            case '--Sd1',         opts.Sd1 = parse_num(varargin{i+1}); i=i+2;
            case '--T',           opts.T = parse_num(varargin{i+1}); i=i+2;
            case '--R',           opts.R = parse_num(varargin{i+1}); i=i+2;
            case '--W',           opts.W = parse_num(varargin{i+1}); i=i+2;
            case '--I',           opts.I = parse_num(varargin{i+1}); i=i+2;
            case '--Mw',          opts.Mw = parse_num(varargin{i+1}); i=i+2;
            case '--distance',    opts.distance = parse_num(varargin{i+1}); i=i+2;
            case '--soil',        opts.soil = lower(varargin{i+1}); i=i+2;
            case '--Vs30',        opts.Vs30 = parse_num(varargin{i+1}); i=i+2;
            case '--N60',         opts.N60 = parse_num(varargin{i+1}); i=i+2;
            case '--PGA',         opts.PGA = parse_num(varargin{i+1}); i=i+2;
            case '--depth',       opts.depth = parse_num(varargin{i+1}); i=i+2;
            case '--storyHeight', opts.storyHeight = parse_num(varargin{i+1}); i=i+2;
            case '--displacement',opts.displacement = parse_num(varargin{i+1}); i=i+2;
            case '--format',      opts.format = varargin{i+1}; i=i+2;
            otherwise,            i=i+1;
        end
    end

    try
        switch lower(action)
            case 'spectrum',     out = act_spectrum(opts);
            case 'base_shear',   out = act_base_shear(opts);
            case 'pga',          out = act_pga(opts);
            case 'soil',         out = act_soil(opts);
            case 'liquefaction', out = act_liquefaction(opts);
            case 'drift',        out = act_drift(opts);
            otherwise,           error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_spectrum(opts)
    Sds = opts.Sds; Sd1 = opts.Sd1;
    T = opts.T; R = opts.R; I = opts.I;
    % ASCE 7-16 design spectrum
    Ts = Sd1 / Sds;
    T0 = 0.2 * Ts;
    % Compute Sa at period T
    if T < T0
        Sa = Sds * (0.4 + 0.6*T/T0);
    elseif T <= Ts
        Sa = Sds;
    else
        Sa = max(0.044*Sds*I, min(Sd1/T, Sds));
    end
    % Reduced spectrum: Sa/R * I
    Sa_design = Sa / R * I;
    % Sample spectrum at multiple periods
    T_range = [0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2, 3, 4];
    Sa_range = zeros(size(T_range));
    for i = 1:numel(T_range)
        t = T_range(i);
        if t < T0
            Sa_range(i) = Sds * (0.4 + 0.6*t/T0);
        elseif t <= Ts
            Sa_range(i) = Sds;
        else
            Sa_range(i) = max(0.044*Sds*I, min(Sd1/t, Sds));
        end
    end
    out = struct();
    out.action = 'spectrum';
    out.method = 'ASCE 7-16';
    out.Sds = Sds; out.Sd1 = Sd1; out.T0 = T0; out.Ts = Ts;
    out.period_T = T;
    out.Sa_elastic = Sa;
    out.Sa_design = Sa_design;
    out.spectrum = struct('T', T_range, 'Sa', Sa_range);
end

function out = act_base_shear(opts)
    W = opts.W; Sds = opts.Sds;
    R = opts.R; I = opts.I;
    % ASCE 7-16 equivalent lateral force
    Cs = Sds / (R / I);
    Cs_max = 0.05;  % limit
    Cs = min(Cs, Cs_max);
    % Cs_max from Sd1
    if opts.Sd1 > 0
        Cs = min(Cs, opts.Sd1 / (opts.T * R/I));
    end
    V = Cs * W;
    out = struct();
    out.action = 'base_shear';
    out.method = 'ASCE 7-16 ELF';
    out.seismicWeight_kN = W;
    out.Cs = Cs;
    out.baseShear_kN = V;
    out.baseShearRatio = V / W;
end

function out = act_pga(opts)
    Mw = opts.Mw; Rkm = opts.distance;
    soil = opts.soil;
    % Ground motion prediction equation (simplified Boore-Atkinson 2008)
    % log10(PGA) = c0 - log(R) + c1*(Mw-6)
    switch soil
        case 'rock', c0 = -0.5; c1 = 0.5;
        case 'dense', c0 = -0.2; c1 = 0.55;
        case 'stiff', c0 = 0.0; c1 = 0.6;
        case 'soft', c0 = 0.3; c1 = 0.65;
        otherwise, c0 = -0.3; c1 = 0.55;
    end
    logPGA = c0 + log10(10/max(1,Rkm)) + c1*(Mw - 6);
    PGA = 10^logPGA;
    % Site amplification
    siteAmp = get_site_amp(soil);
    PGA_amplified = PGA * siteAmp;
    out = struct();
    out.action = 'pga';
    out.magnitude = Mw; out.distance_km = Rkm; out.soil = soil;
    out.pga_g = PGA; out.pga_amplified_g = PGA_amplified;
    out.log10Pga = logPGA; out.siteAmplification = siteAmp;
    out.method = 'simplified Boore-Atkinson GMPE';
end

function out = act_soil(opts)
    Vs30 = opts.Vs30; N60 = opts.N60;
    % NEHRP site classification
    if Vs30 > 1500
        siteClass = 'A (hard rock)';
    elseif Vs30 > 760
        siteClass = 'B (rock)';
    elseif Vs30 > 360
        siteClass = 'C (very dense soil/soft rock)';
    elseif Vs30 > 180
        siteClass = 'D (stiff soil)';
    else
        siteClass = 'E (soft clay soil)';
    end
    % Vs30 from N60 (correlation for sand)
    if N60 > 0
        Vs30_estimated = 97 * N60^0.314;
    else
        Vs30_estimated = Vs30;
    end
    out = struct();
    out.action = 'soil';
    out.Vs30 = Vs30; out.N60 = N60;
    out.siteClass = siteClass;
    out.Vs30_estimated = Vs30_estimated;
    out.method = 'NEHRP provisions';
end

function out = act_liquefaction(opts)
    N = opts.N60; depth = opts.depth;
    Mw = opts.Mw; PGA = opts.PGA;
    % Simplified Seed-Idriss method
    % CSR = 0.65 * (amax/g) * (σv/σv') * rd
    sigma_v = depth * 18;  % total stress
    sigma_v_eff = depth * 8;  % effective stress (simplified)
    rd = 1 - 0.00765 * depth;
    CSR = 0.65 * PGA * sigma_v / sigma_v_eff * rd;
    % CRR from N60 corrected for overburden
    CN = min(1.7, (100/sigma_v_eff)^0.5);
    N1_60 = N * CN;
    % CRR formula
    if N1_60 < 30
        CRR = 1 / (34 - N1_60) + N1_60/135 + 50/(10*N1_60+45)^2 - 1/200;
    else
        CRR = 2;  % non-liquefiable
    end
    CRR = max(0.05, min(0.5, CRR));
    % MSF correction
    MSF = 10^2.24 / Mw^2.56;
    CRR_adjusted = CRR * MSF;
    % Factor of safety
    Fs = CRR_adjusted / max(CSR, 0.01);
    safe = Fs > 1.2;
    out = struct();
    out.action = 'liquefaction';
    out.method = 'Seed-Idriss simplified';
    out.depth_m = depth; out.N1_60 = N1_60;
    out.CSR = CSR; out.CRR = CRR; out.CRR_adjusted = CRR_adjusted;
    out.factorOfSafety = Fs;
    out.liquefactionRisk = not(safe);
end

function out = act_drift(opts)
    h = opts.storyHeight;
    delta = opts.displacement;
    drift = delta / h;
    % ASCE 7 limit: 0.02 for Risk Category II
    limit = 0.02;
    acceptable = drift <= limit;
    out = struct();
    out.action = 'drift';
    out.storyHeight_m = h;
    out.displacement_m = delta;
    out.driftRatio = drift;
    out.limit = limit;
    out.acceptable = acceptable;
end

% =================== Helpers ===================
function amp = get_site_amp(soil)
    switch soil
        case 'rock', amp = 1.0;
        case 'dense', amp = 1.2;
        case 'stiff', amp = 1.5;
        case 'soft', amp = 2.0;
        otherwise, amp = 1.3;
    end
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
