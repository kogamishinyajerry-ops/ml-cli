function cli_concrete(action, varargin)
% CLI_CONCRETE Concrete mix design for ml CLI
%   CLI: ml concrete mix     --fc 30 --slump 100 --aggSize 20
%         ml concrete strength --fc 30 --age 28 --cement typeI
%         ml concrete wc_ratio --fc 30 --cement typeI
%         ml concrete volume  --length 5 --width 3 --height 0.2
%         ml concrete rebar   --section rect --b 0.3 --h 0.5 --cover 0.04
%         ml concrete crack   --width 0.3 --steel 0.001 --Es 200e9
%
%   Options:
%     --fc MPa         concrete compressive strength (28-day)
%     --slump MM       target slump
%     --aggSize MM     maximum aggregate size
%     --cement NAME    typeI|typeII|typeIII|typeIV|typeV
%     --age DAYS        concrete age
%     --length/--width/--height M   pour dimensions
%     --section NAME   rect|circle|t
%     --b/--h/--cover M  section dimensions and cover
%     --steel M2       steel area
%     --Es GPa         steel elastic modulus
%     --format json|table|csv

    if nargin < 1, error('ml concrete <action> [options]'); end

    opts = struct('format','json','fc',30,'slump',100,'aggSize',20,'cement','typeI', ...
                  'age',28,'length',5,'width',3,'height',0.2, ...
                  'section','rect','b',0.3,'h_val',0.5,'cover',0.04, ...
                  'steel',0.001,'Es',200);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--fc',       opts.fc = parse_num(varargin{i+1}); i=i+2;
            case '--slump',    opts.slump = parse_num(varargin{i+1}); i=i+2;
            case '--aggSize',  opts.aggSize = parse_num(varargin{i+1}); i=i+2;
            case '--cement',   opts.cement = lower(varargin{i+1}); i=i+2;
            case '--age',      opts.age = parse_num(varargin{i+1}); i=i+2;
            case '--length',   opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--width',    opts.width = parse_num(varargin{i+1}); i=i+2;
            case '--height',   opts.height = parse_num(varargin{i+1}); i=i+2;
            case '--section',  opts.section = lower(varargin{i+1}); i=i+2;
            case '--b',        opts.b = parse_num(varargin{i+1}); i=i+2;
            case '--h',        opts.h_val = parse_num(varargin{i+1}); i=i+2;
            case '--cover',    opts.cover = parse_num(varargin{i+1}); i=i+2;
            case '--steel',    opts.steel = parse_num(varargin{i+1}); i=i+2;
            case '--Es',       opts.Es = parse_num(varargin{i+1}); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'mix',      out = act_mix(opts);
            case 'strength', out = act_strength(opts);
            case 'wc_ratio', out = act_wc_ratio(opts);
            case 'volume',   out = act_volume(opts);
            case 'rebar',    out = act_rebar(opts);
            case 'crack',    out = act_crack(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_mix(opts)
    fc = opts.fc;
    slump = opts.slump;
    Dmax = opts.aggSize;
    % ACI 211.1 simplified mix design
    % Step 1: w/c ratio from strength
    if fc <= 20, wc = 0.65;
    elseif fc <= 25, wc = 0.58;
    elseif fc <= 30, wc = 0.50;
    elseif fc <= 35, wc = 0.45;
    elseif fc <= 40, wc = 0.40;
    else, wc = 0.35; end
    % Step 2: water content (based on slump and agg size)
    if Dmax <= 10
        water = 205;
    elseif Dmax <= 20
        water = 185;
    elseif Dmax <= 40
        water = 170;
    else
        water = 160;
    end
    if slump > 50, water = water + 10; end
    if slump > 100, water = water + 5; end
    % Step 3: cement content = water / w/c
    cement = water / wc;
    % Step 4: coarse aggregate (fraction of dry-rodded)
    aggFraction = 0.68;
    coarseAgg = 1650 * aggFraction;  % kg/m³
    % Step 5: fine aggregate (by absolute volume method)
    volWater = water / 1000;
    volCement = cement / 3150;
    volCoarse = coarseAgg / 2600;
    volAir = 0.02;
    volFine = 1 - volWater - volCement - volCoarse - volAir;
    fineAgg = volFine * 2600;
    out = struct();
    out.action = 'mix';
    out.method = 'ACI 211.1 simplified';
    out.targetFc_MPa = fc;
    out.slump_mm = slump;
    out.maxAggregate_mm = Dmax;
    out.wcRatio = wc;
    out.water_kg_per_m3 = water;
    out.cement_kg_per_m3 = cement;
    out.fineAggregate_kg_per_m3 = fineAgg;
    out.coarseAggregate_kg_per_m3 = coarseAgg;
    out.totalDensity_kg_per_m3 = water + cement + fineAgg + coarseAgg;
end

function out = act_strength(opts)
    fc28 = opts.fc;
    age = opts.age;
    cement = opts.cement;
    % Strength gain with age (Eurocode 2 simplified)
    beta_cc = exp(0.25 * (1 - sqrt(28 / age)));
    fc_t = beta_cc * fc28;
    % Cement type factor
    cementFactor = struct('typei', 1.0, 'typeii', 0.9, 'typeiii', 1.15, ...
                          'typeiv', 0.7, 'typev', 0.85);
    if isfield(cementFactor, cement)
        cf = cementFactor.(cement);
    else
        cf = 1.0;
    end
    fc_t = fc_t * cf;
    out = struct();
    out.action = 'strength';
    out.fc28 = fc28; out.age_days = age; out.cement = cement;
    out.fc_at_age_MPa = fc_t;
    out.ratio = fc_t / fc28;
    out.formula = 'βcc(t) = exp(0.25*(1-sqrt(28/t))), Eurocode 2';
end

function out = act_wc_ratio(opts)
    fc = opts.fc;
    cement = opts.cement;
    % Abrams' law: fc = k1 / k2^(w/c), simplified inverse
    if strcmp(cement, 'typeii')
        k1 = 90; k2 = 4.0;
    elseif strcmp(cement, 'typeiii')
        k1 = 120; k2 = 4.2;
    else
        k1 = 100; k2 = 4.0;
    end
    wc = log(k1 / fc) / log(k2);
    wc = max(0.3, min(0.7, wc));
    out = struct();
    out.action = 'wc_ratio';
    out.targetFc_MPa = fc;
    out.cementType = cement;
    out.wcRatio = wc;
    out.abramsK1 = k1; out.abramsK2 = k2;
end

function out = act_volume(opts)
    L = opts.length; W = opts.width; H = opts.height;
    V = L * W * H;
    waste = 0.05;  % 5% waste factor
    VwithWaste = V * (1 + waste);
    out = struct();
    out.action = 'volume';
    out.dimensions = struct('length',L,'width',W,'height',H);
    out.volume_m3 = V;
    out.volumeWithWaste_m3 = VwithWaste;
    out.wasteFactor_pct = waste*100;
end

function out = act_rebar(opts)
    b = opts.b; h = opts.h_val; cover = opts.cover;
    d = h - cover;  % effective depth
    switch opts.section
        case 'rect'
            A_gross = b * h;
            d_effective = d;
            clearSpacing = (b - 2*cover) / 3;
        case 'circle'
            r = b/2;
            A_gross = pi * r^2;
            d_effective = 0.8 * h;
            clearSpacing = r * 0.6;
        otherwise
            A_gross = b * h;
            d_effective = d;
            clearSpacing = 0;
    end
    out = struct();
    out.action = 'rebar';
    out.section = opts.section;
    out.width_m = b; out.totalHeight_m = h;
    out.cover_m = cover;
    out.effectiveDepth_m = d_effective;
    out.grossArea_m2 = A_gross;
    out.clearSpacing_m = clearSpacing;
end

function out = act_crack(opts)
    w = opts.width;
    As = opts.steel;
    Es = opts.Es * 1e9;  % GPa → Pa
    % Crack width estimate (Gergely-Lutz simplified)
    fs = 0.6 * 500e6;  % service load steel stress
    dc = 0.04;  % concrete cover to centroid of tension steel
    A = 2 * dc * w / 3;  % effective tension area per bar
    crackWidth = 0.076 * 0.6 * fs * (dc * A)^(1/3) * 1e-3;
    % Simplified: w_crack = 3 * eps_s * h_crack
    wc_max = 0.3;  % mm (typical limit)
    out = struct();
    out.action = 'crack';
    out.sectionWidth_m = w;
    out.steelArea_m2 = As;
    out.steelEs_GPa = opts.Es;
    out.estimatedCrackWidth_mm = crackWidth;
    out.limit_mm = wc_max;
    out.acceptable = crackWidth < wc_max;
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
