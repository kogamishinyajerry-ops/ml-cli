function cli_environ(action, varargin)
% CLI_ENVIRON Environmental science for ml CLI
%   CLI: ml environ carbon   --activity 100 --emissionFactor 0.5
%         ml environ energy   --building 1000 --kWh 15000 --fuel gas
%         ml environ water    --population 50000 --daily 150
%         ml environ emissions --fuel diesel --consumption 1000 --source mobile
%         ml environ gwp      --co2eq 5000 --component CO2
%         ml environ lca      --material steel --mass 1000
%
%   Options:
%     --activity VAL    activity level
%     --emissionFactor  kg CO2 per unit
%     --building M2     building area
%     --kWh AMOUNT      energy consumption
%     --fuel NAME       fuel type (gas|diesel|coal|electric|biomass)
%     --population N    population served
%     --daily LITERS    daily per capita water use
%     --consumption KG  fuel consumption
%     --source NAME     mobile|stationary|process
%     --co2eq KG        CO2 equivalent
%     --component NAME  CO2|CH4|N2O|SF6
%     --material NAME   building material
%     --mass KG         material mass
%     --format json|table|csv

    if nargin < 1, error('ml environ <action> [options]'); end

    opts = struct('format','json','activity',100,'emissionFactor',0.5, ...
                  'building',1000,'kWh',15000,'fuel','gas', ...
                  'population',50000,'daily',150, ...
                  'consumption',1000,'source','mobile', ...
                  'co2eq',5000,'component','CO2', ...
                  'material','steel','mass',1000);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--activity',   opts.activity = parse_num(varargin{i+1}); i=i+2;
            case '--emissionFactor',opts.emissionFactor = parse_num(varargin{i+1}); i=i+2;
            case '--building',   opts.building = parse_num(varargin{i+1}); i=i+2;
            case '--kWh',        opts.kWh = parse_num(varargin{i+1}); i=i+2;
            case '--fuel',       opts.fuel = lower(varargin{i+1}); i=i+2;
            case '--population', opts.population = parse_num(varargin{i+1}); i=i+2;
            case '--daily',      opts.daily = parse_num(varargin{i+1}); i=i+2;
            case '--consumption',opts.consumption = parse_num(varargin{i+1}); i=i+2;
            case '--source',     opts.source = lower(varargin{i+1}); i=i+2;
            case '--co2eq',      opts.co2eq = parse_num(varargin{i+1}); i=i+2;
            case '--component',  opts.component = upper(varargin{i+1}); i=i+2;
            case '--material',   opts.material = lower(varargin{i+1}); i=i+2;
            case '--mass',       opts.mass = parse_num(varargin{i+1}); i=i+2;
            case '--format',     opts.format = varargin{i+1}; i=i+2;
            otherwise,           i=i+1;
        end
    end

    try
        switch lower(action)
            case 'carbon',   out = act_carbon(opts);
            case 'energy',   out = act_energy(opts);
            case 'water',    out = act_water(opts);
            case 'emissions',out = act_emissions(opts);
            case 'gwp',      out = act_gwp(opts);
            case 'lca',      out = act_lca(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_carbon(opts)
    % Simple carbon footprint: activity × emission factor
    activity = opts.activity;
    ef = opts.emissionFactor;
    co2 = activity * ef;  % kg CO2
    % Tree equivalent (1 tree absorbs ~22 kg CO2/year)
    trees = co2 / 22;
    out = struct();
    out.action = 'carbon';
    out.method = 'activity × emission factor';
    out.activity = activity;
    out.emissionFactor_kgCO2 = ef;
    out.co2Equivalent_kg = co2;
    out.co2Equivalent_tonnes = co2/1000;
    out.treeEquivalent = trees;
end

function out = act_energy(opts)
    area = opts.building;
    kWh = opts.kWh;
    fuel = opts.fuel;
    % Energy Use Intensity (EUI)
    EUI = kWh / area;  % kWh/m²/yr
    % Emission factors by fuel (kg CO2/kWh)
    efMap = struct('gas', 0.185, 'diesel', 0.267, 'coal', 0.340, ...
                   'electric', 0.475, 'biomass', 0.018);
    if isfield(efMap, fuel)
        ef = efMap.(fuel);
    else
        ef = 0.475;  % default grid average
    end
    co2 = kWh * ef;  % kg CO2
    % Energy rating: A-EU based on EUI benchmark
    if EUI < 50, label = 'A+ (net-zero)';
    elseif EUI < 100, label = 'A (excellent)';
    elseif EUI < 150, label = 'B (good)';
    elseif EUI < 250, label = 'C (average)';
    elseif EUI < 350, label = 'D (poor)';
    else, label = 'E (inefficient)'; end
    out = struct();
    out.action = 'energy';
    out.buildingArea_m2 = area;
    out.annualEnergy_kWh = kWh;
    out.fuelSource = fuel;
    out.eui_kWh_per_m2 = EUI;
    out.energyLabel = label;
    out.co2Emissions_kg = co2;
end

function out = act_water(opts)
    pop = opts.population;
    daily = opts.daily;  % L/person/day
    annual = pop * daily * 365 / 1000;  % m³/year
    % Water footprint benchmarks
    % Grey water ~50% of total
    greyWater = annual * 0.5;
    out = struct();
    out.action = 'water';
    out.population = pop;
    out.dailyPerCapita_L = daily;
    out.annualDemand_m3 = annual;
    out.annualDemand_ML = annual / 1000;
    out.greyWater_m3 = greyWater;
    out.method = 'residential water demand estimate';
end

function out = act_emissions(opts)
    fuel = opts.fuel;
    consumption = opts.consumption;  % kg or L
    source = opts.source;
    % IPCC default emission factors (kg CO2 per unit)
    ef = struct();
    ef.gasoline = struct('co2', 2.31, 'ch4', 0.001, 'n2o', 0.001);   % per kg
    ef.diesel   = struct('co2', 2.68, 'ch4', 0.0005, 'n2o', 0.001);
    ef.natgas   = struct('co2', 2.75, 'ch4', 0.003, 'n2o', 0.0001);
    ef.coal     = struct('co2', 2.47, 'ch4', 0.001, 'n2o', 0.001);
    if isfield(ef, fuel)
        fact = ef.(fuel);
    else
        fact = struct('co2', 2.5, 'ch4', 0.001, 'n2o', 0.001);
    end
    co2 = consumption * fact.co2;
    ch4 = consumption * fact.ch4;
    n2o = consumption * fact.n2o;
    % GWP100: CH4=25, N2O=298
    co2e_total = co2 + ch4 * 25 + n2o * 298;
    out = struct();
    out.action = 'emissions';
    out.fuel = fuel;
    out.consumption_kg = consumption;
    out.source = source;
    out.co2_kg = co2;
    out.ch4_kg = ch4;
    out.n2o_kg = n2o;
    out.co2e_total_kg = co2e_total;
    out.method = 'IPCC Tier 1 (default emission factors)';
end

function out = act_gwp(opts)
    co2e = opts.co2eq;
    comp = opts.component;
    % GWP100 values (AR5)
    gwp = struct('CO2', 1, 'CH4', 28, 'N2O', 265, 'SF6', 23500, ...
                 'HFC134A', 1430, 'PFC14', 6630);
    if isfield(gwp, comp)
        value = gwp.(comp);
    else
        value = NaN;
    end
    out = struct();
    out.action = 'gwp';
    out.gwp100 = value;
    out.component = comp;
    out.co2e_kg = co2e;
    out.equivalentCO2_tonnes = co2e / 1000;
    if ~strcmp(comp, 'CO2') && ~isnan(value)
        out.componentMass_kg = co2e / value;
    end
end

function out = act_lca(opts)
    mat = opts.material;
    mass = opts.mass;
    % Embodied carbon (kg CO2e per kg material) — typical values
    ee = struct('steel', 2.0, 'concrete', 0.15, 'aluminum', 12.0, ...
                'glass', 1.5, 'wood', 0.3, 'plastic', 6.0, ...
                'brick', 0.25, 'copper', 5.0);
    if isfield(ee, mat)
        embodiedCO2 = mass * ee.(mat);
    else
        embodiedCO2 = mass * 2.0;  % default
    end
    % Transportation impact (assume 500 km truck, 0.1 kg CO2/tonne·km)
    transportCO2 = mass/1000 * 500 * 0.1;
    out = struct();
    out.action = 'lca';
    out.material = mat;
    out.mass_kg = mass;
    out.embodiedCO2_kg = embodiedCO2;
    out.transportCO2_kg = transportCO2;
    out.totalCO2_kg = embodiedCO2 + transportCO2;
    out.method = 'cradle-to-gate embodied carbon (typical values)';
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
