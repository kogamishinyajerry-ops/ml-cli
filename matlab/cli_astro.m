function cli_astro(action, varargin)
% CLI_ASTRO Astronomy calculations for ml CLI
%   CLI: ml astro kepler   --a 1.5 --e 0.2 --nu 30
%         ml astro orbit   --a 7000e3 --e 0.01 --mu 3.986e14
%         ml astro magnitude --flux 1e-10 --reference 0
%         ml astro redshift --lambda_obs 656.5 --lambda_rest 656.3
%         ml astro radec    --ra "10h30m15s" --dec "+20d15m30s"
%         ml astro seasons  --lat 40 --lon 116 --date 2026-06-21
%         ml astro jd       --year 2026 --month 6 --day 21
%
%   Options:
%     --a SEMIMAJOR     semi-major axis (m or AU)
%     --e ECCENTRICITY  orbital eccentricity
%     --nu DEG           true anomaly (degrees)
%     --mu GRAVPARAM     gravitational parameter (m^3/s^2)
%     --body EARTH|MARS|VENUS|MOON|SUN|JUPITER|SATURN
%     --flux W/M2        observed flux
%     --reference MAG    reference magnitude
%     --lambda_obs NM    observed wavelength
%     --lambda_rest NM   rest wavelength
%     --ra STRING        right ascension
%     --dec STRING       declination
%     --lat DEG          observer latitude
%     --lon DEG          observer longitude
%     --date STRING      date YYYY-MM-DD
%     --year --month --day  date components
%     --format json|table|csv

    if nargin < 1, error('ml astro <action> [options]'); end

    opts = struct('format','json','a',1.0,'e',0,'nu',0,'mu',3.986e14, ...
                  'body','earth','flux',1e-10,'reference',0, ...
                  'lambda_obs',656.5,'lambda_rest',656.3, ...
                  'ra','','dec','','lat',40,'lon',116,'date','', ...
                  'year',2000,'month',1,'day',1);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--a',        opts.a = parse_num(varargin{i+1}); i=i+2;
            case '--e',        opts.e = parse_num(varargin{i+1}); i=i+2;
            case '--nu',       opts.nu = parse_num(varargin{i+1}); i=i+2;
            case '--mu',       opts.mu = parse_num(varargin{i+1}); i=i+2;
            case '--body',     opts.body = lower(varargin{i+1}); i=i+2;
            case '--flux',     opts.flux = parse_num(varargin{i+1}); i=i+2;
            case '--reference',opts.reference = parse_num(varargin{i+1}); i=i+2;
            case '--lambda_obs',opts.lambda_obs = parse_num(varargin{i+1}); i=i+2;
            case '--lambda_rest',opts.lambda_rest = parse_num(varargin{i+1}); i=i+2;
            case '--ra',       opts.ra = varargin{i+1}; i=i+2;
            case '--dec',      opts.dec = varargin{i+1}; i=i+2;
            case '--lat',      opts.lat = parse_num(varargin{i+1}); i=i+2;
            case '--lon',      opts.lon = parse_num(varargin{i+1}); i=i+2;
            case '--date',     opts.date = varargin{i+1}; i=i+2;
            case '--year',     opts.year = round(parse_num(varargin{i+1})); i=i+2;
            case '--month',    opts.month = round(parse_num(varargin{i+1})); i=i+2;
            case '--day',      opts.day = round(parse_num(varargin{i+1})); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end
    % Resolve body parameters
    if strcmpi(action, 'kepler') || strcmpi(action, 'orbit')
        bm = body_params(opts.body);
        if ~isempty(bm)
            opts.mu = bm.mu;
            opts.a = bm.a;
        end
    end

    try
        switch lower(action)
            case 'kepler',    out = act_kepler(opts);
            case 'orbit',     out = act_orbit(opts);
            case 'magnitude', out = act_magnitude(opts);
            case 'redshift',  out = act_redshift(opts);
            case 'radec',     out = act_radec(opts);
            case 'seasons',   out = act_seasons(opts);
            case 'jd',        out = act_jd(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_kepler(opts)
    % Kepler's equation: M = E - e*sin(E), M = nu for elliptic
    a = opts.a; e = opts.e;
    nu = deg2rad(opts.nu);
    % True anomaly → eccentric anomaly
    cosE = (e + cos(nu)) / (1 + e*cos(nu));
    E = acos(max(-1, min(1, cosE)));
    if nu > pi, E = 2*pi - E; end
    % Mean anomaly
    M = E - e*sin(E);
    % Radius
    r = a * (1 - e^2) / (1 + e*cos(nu));
    % Period
    T = 2*pi * sqrt(a^3 / opts.mu);
    % Orbital velocity (vis-viva)
    v = sqrt(opts.mu * (2/r - 1/a));
    out = struct();
    out.action = 'kepler';
    out.semiMajorAxis_m = a;
    out.eccentricity = e;
    out.trueAnomaly_deg = opts.nu;
    out.eccentricAnomaly_rad = E;
    out.meanAnomaly_rad = M;
    out.radius_m = r;
    out.velocity_m_s = v;
    out.period_s = T;
    out.period_hr = T / 3600;
    out.period_days = T / 86400;
end

function out = act_orbit(opts)
    % Keplerian orbital elements
    a = opts.a;
    e = opts.e;
    mu = opts.mu;
    % Computed quantities
    r_periapsis = a * (1 - e);
    r_apoapsis = a * (1 + e);
    T = 2*pi * sqrt(a^3 / mu);
    v_peri = sqrt(mu * (2/r_periapsis - 1/a));
    v_apo = sqrt(mu * (2/r_apoapsis - 1/a));
    n = sqrt(mu / a^3);  % mean motion
    % Specific orbital energy
    energy = -mu / (2*a);
    out = struct();
    out.action = 'orbit';
    out.semiMajorAxis_m = a;
    out.eccentricity = e;
    out.periapsis_m = r_periapsis;
    out.apoapsis_m = r_apoapsis;
    out.period_s = T;
    out.period_days = T / 86400;
    out.meanMotion_rad_s = n;
    out.velocity_periapsis = v_peri;
    out.velocity_apoapsis = v_apo;
    out.energy_per_kg = energy;
    out.gravParam = mu;
end

function out = act_magnitude(opts)
    % Apparent magnitude from flux: m = m_ref - 2.5*log10(F/F_ref)
    % Using reference at m_ref=0, F_ref=2.55e-8 W/m^2 (Vega)
    Fref = 2.55e-8;
    F = opts.flux;
    m = opts.reference - 2.5 * log10(max(F, 1e-50) / Fref);
    % Absolute magnitude if distance given (assume 10 pc)
    % Return apparent magnitude estimate
    out = struct();
    out.action = 'magnitude';
    out.flux_W_m2 = F;
    out.reference_flux = Fref;
    out.apparentMagnitude = m;
    % Signal-to-noise ratio for photon events (Poisson)
    if F > 0
        out.snr = sqrt(F / (6.626e-34 * 5e14 * 1.0));  % rough
    end
end

function out = act_redshift(opts)
    z = (opts.lambda_obs - opts.lambda_rest) / opts.lambda_rest;
    c = 299792458;  % m/s
    % Non-relativistic recessional velocity
    v = z * c;
    % Hubble law distance estimate (H0 = 70 km/s/Mpc)
    H0 = 70;  % km/s/Mpc
    d_Mpc = (v/1000) / H0;
    out = struct();
    out.action = 'redshift';
    out.lambda_observed_nm = opts.lambda_obs;
    out.lambda_rest_nm = opts.lambda_rest;
    out.redshift_z = z;
    out.recessionalVelocity_km_s = v/1000;
    out.hubbleDistance_Mpc = d_Mpc;
    out.hubbleDistance_Mly = d_Mpc * 3.262;
end

function out = act_radec(opts)
    % Parse RA "10h30m15s" and Dec "+20d15m30s"
    ra = parse_ra(opts.ra);
    dec = parse_dec(opts.dec);
    out = struct();
    out.action = 'radec';
    out.ra_input = opts.ra;
    out.dec_input = opts.dec;
    out.ra_hours = ra / 15;
    out.ra_degrees = ra;
    out.dec_degrees = dec;
    out.ra_radians = deg2rad(ra);
    out.dec_radians = deg2rad(dec);
end

function out = act_seasons(opts)
    lat = opts.lat;
    lon = opts.lon;
    % Get date from --date or --year/--month/--day
    if ~isempty(opts.date)
        d = datetime(opts.date);
        yyyy = year(d); mm = month(d); dd = day(d);
    else
        yyyy = opts.year; mm = opts.month; dd = opts.day;
    end
    % Day of year
    doy = day(datetime(yyyy, mm, dd), 'dayofyear');
    % Solar declination (simplified)
    decl = -23.44 * cosd(360/365 * (doy + 10));
    % Equation of time (minutes)
    B = 360/365 * (doy - 81);
    eot = 9.87*sind(2*B) - 7.53*cosd(B) - 1.5*sind(B);
    % Sunrise/sunset hour angle
    cosH = -tand(lat) * tand(decl);
    if abs(cosH) > 1
        if cosH > 1
            dayLength = 24; sunset_hr = 24; sunrise_hr = 0;
        else
            dayLength = 0; sunset_hr = 0; sunrise_hr = 0;
        end
    else
        H = acosd(cosH);
        T_transit = 12 + eot/60 - lon/15;
        sunrise_hr = T_transit - H/15;
        sunset_hr = T_transit + H/15;
        dayLength = 2 * H / 15;
    end
    % Season
    if doy < 60 || doy > 334, season = 'winter (NH)';
    elseif doy < 152, season = 'spring (NH)';
    elseif doy < 244, season = 'summer (NH)';
    else, season = 'autumn (NH)'; end

    out = struct();
    out.action = 'seasons';
    out.date = sprintf('%04d-%02d-%02d', yyyy, mm, dd);
    out.dayOfYear = doy;
    out.latitude = lat;
    out.longitude = lon;
    out.solarDeclination_deg = decl;
    out.equationOfTime_min = eot;
    out.sunrise_hr = sunrise_hr;
    out.sunset_hr = sunset_hr;
    out.dayLength_hr = dayLength;
    out.solarNoon_hr = T_transit;
    out.season = season;
end

function out = act_jd(opts)
    if ~isempty(opts.date)
        d = datetime(opts.date);
        yyyy = year(d); mm = month(d); dd = day(d);
    else
        yyyy = opts.year; mm = opts.month; dd = opts.day;
    end
    % Julian date (Gregorian calendar)
    a = floor((14 - mm) / 12);
    y = yyyy + 4800 - a;
    m = mm + 12*a - 3;
    JD = dd + floor((153*m + 2)/5) + 365*y ...
         + floor(y/4) - floor(y/100) + floor(y/400) - 32045 - 0.5;
    MJD = JD - 2400000.5;
    % Day of week
    wd = mod(floor(JD + 0.5), 7);
    wdays = {'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'};
    out = struct();
    out.action = 'jd';
    out.date = sprintf('%04d-%02d-%02d', yyyy, mm, dd);
    out.julianDate = JD;
    out.modifiedJulianDate = MJD;
    out.dayOfWeek_wd = mod(floor(JD+0.5), 7);
    out.dayOfWeek = wdays{wd+1};
end

% =================== Helpers ===================
function b = body_params(name)
    % Returns orbital parameters. For planets, mu is Sun's gravitational parameter.
    % For Moon, mu is Earth's. For Sun, mu is for galactic orbit (approx).
    b = struct('mu',[],'a',[],'mass',[],'radius',[]);
    sun_mu = 1.32712440018e20;
    switch lower(name)
        case 'earth'
            b.mu = sun_mu;
            b.a = 149597870700;
            b.mass = 5.972e24;
            b.radius = 6371e3;
        case 'mars'
            b.mu = sun_mu;
            b.a = 227939200000;
            b.mass = 6.417e23;
            b.radius = 3390e3;
        case 'venus'
            b.mu = sun_mu;
            b.a = 108208000000;
            b.mass = 4.867e24;
            b.radius = 6052e3;
        case 'moon'
            b.mu = 3.986004415e14;  % Earth's grav param for Moon orbit
            b.a = 384400000;
            b.mass = 7.342e22;
            b.radius = 1737e3;
        case 'jupiter'
            b.mu = sun_mu;
            b.a = 778570000000;
            b.mass = 1.898e27;
            b.radius = 69911e3;
        case 'saturn'
            b.mu = sun_mu;
            b.a = 1433530000000;
            b.mass = 5.683e26;
            b.radius = 58232e3;
        case 'sun'
            b.mu = sun_mu;
            b.mass = 1.989e30;
            b.radius = 695700e3;
        case 'earth_grav'
            b.mu = 3.986004415e14;
            b.a = 42164000;  % GEO
            b.mass = 5.972e24;
            b.radius = 6371e3;
        otherwise
            b = [];  % use user-supplied values
    end
end

function ra_deg = parse_ra(s)
    s = strtrim(s);
    % Parse "10h30m15s" or "10 30 15"
    s = regexprep(s, '[hms]', ' ');
    v = sscanf(s, '%f');
    if numel(v) >= 3
        ra_deg = 15*(v(1) + v(2)/60 + v(3)/3600);
    elseif numel(v) == 1
        ra_deg = v(1);
    else
        ra_deg = 0;
    end
end

function dec_deg = parse_dec(s)
    s = strtrim(s);
    % Parse "+20d15m30s" or "+20 15 30"
    sign = 1;
    if ~isempty(s) && s(1) == '-', sign = -1; s = s(2:end); end
    if ~isempty(s) && s(1) == '+', s = s(2:end); end
    s = regexprep(s, '[dms]', ' ');
    v = sscanf(s, '%f');
    if numel(v) >= 3
        dec_deg = sign * (abs(v(1)) + v(2)/60 + v(3)/3600);
    elseif numel(v) == 1
        dec_deg = sign * abs(v(1));
    else
        dec_deg = 0;
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
