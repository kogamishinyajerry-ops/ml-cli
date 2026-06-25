function cli_acoustics(action, varargin)
% CLI_ACOUSTICS Acoustics calculations for ml CLI
%   CLI: ml acoustics spl       --pressure 0.02 --ref 2e-5
%         ml acoustics db        --value 2 --ref 1 --type amplitude
%         ml acoustics rt60      --volume 100 --area 150 --alpha 0.15
%         ml acoustics room_modes --lx 5 --ly 4 --lz 3 --nmax 3
%         ml acoustics absorption --freq 1000 --temp 20 --rh 50
%         ml acoustics transmission --freq 500 --mass 10
%
%   Options:
%     --pressure Pa   sound pressure
%     --ref Pa        reference pressure (default 2e-5)
%     --value N       value to convert to dB
%     --type NAME     power|amplitude
%     --to NAME       linear (reverse dB)
%     --volume m3     room volume
%     --area m2       absorption area
%     --alpha         average absorption coefficient
%     --method NAME   sabine|eyring
%     --lx/--ly/--lz  room dimensions
%     --nmax N        max mode index
%     --c M/S         speed of sound (default 343)
%     --freq Hz       frequency
%     --temp C        temperature
%     --rh PCT        relative humidity (%)
%     --mass KG/M2    surface mass (mass law)
%     --format json|table|csv

    if nargin < 1, error('ml acoustics <action> [options]'); end

    opts = struct('format','json','pressure',0.02,'ref',2e-5,'value',2, ...
                  'type','amplitude','to','','volume',100,'area',150, ...
                  'alpha',0.15,'method','sabine','lx',5,'ly',4,'lz',3, ...
                  'nmax',3,'c',343,'freq',1000,'temp',20,'rh',50, ...
                  'mass',10,'coincidence',2000,'atmpress',101325);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--pressure',  opts.pressure = parse_num(varargin{i+1}); i=i+2;
            case '--ref',       opts.ref = parse_num(varargin{i+1}); i=i+2;
            case '--value',     opts.value = parse_num(varargin{i+1}); i=i+2;
            case '--type',      opts.type = lower(varargin{i+1}); i=i+2;
            case '--to',        opts.to = lower(varargin{i+1}); i=i+2;
            case '--volume',    opts.volume = parse_num(varargin{i+1}); i=i+2;
            case '--area',      opts.area = parse_num(varargin{i+1}); i=i+2;
            case '--alpha',     opts.alpha = parse_num(varargin{i+1}); i=i+2;
            case '--method',    opts.method = lower(varargin{i+1}); i=i+2;
            case '--lx',        opts.lx = parse_num(varargin{i+1}); i=i+2;
            case '--ly',        opts.ly = parse_num(varargin{i+1}); i=i+2;
            case '--lz',        opts.lz = parse_num(varargin{i+1}); i=i+2;
            case '--nmax',      opts.nmax = round(parse_num(varargin{i+1})); i=i+2;
            case '--c',         opts.c = parse_num(varargin{i+1}); i=i+2;
            case '--freq',      opts.freq = parse_num(varargin{i+1}); i=i+2;
            case '--temp',      opts.temp = parse_num(varargin{i+1}); i=i+2;
            case '--rh',        opts.rh = parse_num(varargin{i+1}); i=i+2;
            case '--mass',      opts.mass = parse_num(varargin{i+1}); i=i+2;
            case '--coincidence',opts.coincidence = parse_num(varargin{i+1}); i=i+2;
            case '--atmpress',  opts.atmpress = parse_num(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'spl',          out = act_spl(opts);
            case 'db',           out = act_db(opts);
            case 'rt60',         out = act_rt60(opts);
            case 'room_modes',   out = act_room_modes(opts);
            case 'absorption',   out = act_absorption(opts);
            case 'transmission', out = act_transmission(opts);
            otherwise,           error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_spl(opts)
    P = opts.pressure;
    Pref = opts.ref;
    SPL = 20 * log10(max(P, 1e-20) / Pref);
    out = struct();
    out.action = 'spl';
    out.pressure_Pa = P;
    out.reference_Pa = Pref;
    out.spl_dB = SPL;
end

function out = act_db(opts)
    v = opts.value;
    ref = opts.ref;
    type = opts.type;
    switch type
        case 'power'
            dB = 10 * log10(max(v, 1e-20) / max(ref, 1e-20));
        case 'amplitude'
            dB = 20 * log10(max(v, 1e-20) / max(ref, 1e-20));
        otherwise
            error('type must be power|amplitude');
    end
    out = struct();
    out.action = 'db';
    out.value = v;
    out.reference = ref;
    out.type = type;
    out.dB = dB;
    if strcmp(opts.to, 'linear')
        switch type
            case 'power'
                out.linear = ref * 10^(v/10);
            case 'amplitude'
                out.linear = ref * 10^(v/20);
        end
    end
end

function out = act_rt60(opts)
    V = opts.volume;
    S = opts.area;
    alpha = opts.alpha;
    c = opts.c;
    method = opts.method;
    switch method
        case 'sabine'
            T60 = 0.161 * V / (S * alpha);
        case 'eyring'
            T60 = 0.161 * V / (-S * log(1 - alpha));
        otherwise
            error('method must be sabine|eyring');
    end
    % Total absorption
    A_sabine = S * alpha;
    % Schroeder frequency
    f_schroeder = 2000 * sqrt(T60 / V);
    out = struct();
    out.action = 'rt60';
    out.volume_m3 = V;
    out.surfaceArea_m2 = S;
    out.alpha = alpha;
    out.method = method;
    out.T60_s = T60;
    out.absorptionArea_m2 = A_sabine;
    out.schroederFreq_Hz = f_schroeder;
    out.speedOfSound = c;
end

function out = act_room_modes(opts)
    Lx = opts.lx; Ly = opts.ly; Lz = opts.lz;
    nmax = opts.nmax;
    c = opts.c;
    modes = [];
    for nx = 0:nmax
        for ny = 0:nmax
            for nz = 0:nmax
                if nx==0 && ny==0 && nz==0, continue; end
                f = (c/2) * sqrt((nx/Lx)^2 + (ny/Ly)^2 + (nz/Lz)^2);
                nonZeros = (nx>0) + (ny>0) + (nz>0);
                if nonZeros == 1
                    kind = 'axial';
                elseif nonZeros == 2
                    kind = 'tangential';
                else
                    kind = 'oblique';
                end
                modes(end+1, 1:5) = [f, nx, ny, nz, nonZeros];
            end
        end
    end
    % Sort by frequency, return first 20
    [~, idx] = sort(modes(:,1));
    modes = modes(idx(1:min(20, size(modes,1))), :);
    modeList = cell(size(modes,1), 1);
    for m = 1:size(modes,1)
        nzCnt = modes(m,5);
        if nzCnt==1, kind='axial'; elseif nzCnt==2, kind='tangential'; else, kind='oblique'; end
        modeList{m} = sprintf('f=%.1fHz (%d,%d,%d) %s', modes(m,1), ...
                              modes(m,2), modes(m,3), modes(m,4), kind);
    end
    out = struct();
    out.action = 'room_modes';
    out.dimensions = struct('Lx', Lx, 'Ly', Ly, 'Lz', Lz);
    out.speedOfSound = c;
    out.totalModes = size(modes,1);
    out.modeCounts = struct('axial',sum(modes(:,5)==1), ...
                            'tangential',sum(modes(:,5)==2), ...
                            'oblique',sum(modes(:,5)==3));
    out.modes = modeList;
end

function out = act_absorption(opts)
    f = opts.freq;
    T = opts.temp + 273.15;  % Kelvin
    rh = opts.rh;
    P0 = 101325;
    P = opts.atmpress;
    % ISO 9613-1 simplified air absorption
    % Saturation vapor pressure (Tetens)
    if T > 273.15
        psat = 610.78 * exp(17.27 * (T-273.15) / (T - 35.85));
    else
        psat = 610.78 * exp(21.875 * (T-273.15) / (T - 7.65));
    end
    h = rh * psat / P;  % molar concentration of water vapor (%)
    % Relaxation frequencies
    frO = (P/P0) * (24 + 4.04e4 * h * (0.02 + h) / (0.391 + h));
    frN = (P/P0) * (T/293.15)^(-0.5) * (9 + 280 * h * exp(-4.170*((T/293.15)^(-1/3)-1)));
    % Attenuation
    T0 = 293.15;
    alpha = f^2 * (1.84e-11 * (P0/P)^0.5 * (T/T0)^0.5 + ...
            (T/T0)^(-2.5) * (0.01275 * (exp(-2239.1/T)) * (frO/(f^2+frO^2)) + ...
                              0.1068 * (exp(-3352/T)) * (frN/(f^2+frN^2))));
    alpha_dB_km = alpha * 8.686 * 1000;  % nepers/m → dB/km
    out = struct();
    out.action = 'absorption';
    out.frequency_Hz = f;
    out.temp_C = T - 273.15;
    out.rh_pct = rh;
    out.psat_Pa = psat;
    out.frO_Hz = frO;
    out.frN_Hz = frN;
    out.alpha_dB_per_km = alpha_dB_km;
    out.alpha_dB_per_100m = alpha_dB_km / 10;
end

function out = act_transmission(opts)
    f = opts.freq;
    m = opts.mass;
    fc = opts.coincidence;
    % Mass law
    TL_mass = 20*log10(f*m) - 47;
    % Coincidence correction (simplified)
    if f > fc*0.5
        eta = 0.02 + 0.001 * (f/fc);
        TL = TL_mass - 10*log10(eta);
    else
        TL = TL_mass;
    end
    out = struct();
    out.action = 'transmission';
    out.frequency_Hz = f;
    out.mass_kg_per_m2 = m;
    out.massLaw_TL_dB = TL_mass;
    out.coincidenceFreq_Hz = fc;
    out.TL_dB = TL;
    out.method = 'single-leaf mass law';
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
