function cli_chem(action, varargin)
% CLI_CHEM Chemistry calculations for ml CLI
%   CLI: ml chem molar_mass --formula "H2O"
%         ml chem gas_law   --p 101325 --v 0.0224 --n 1 --solve t
%         ml chem ph        --conc 0.01 --solute hcl
%         ml chem dilution  --c1 1.0 --v1 0.1 --c2 0.1
%         ml chem reaction  --order 1 --k 0.05 --conc0 1.0 --time 10
%         ml chem balance   --reactants "C3H8+O2" --products "CO2+H2O"
%
%   Options:
%     --formula STR    chemical formula
%     --p --v --n --t  gas law variables (Pa, m³, mol, K)
%     --solve NAME     variable to solve for
%     --conc VAL       concentration (M)
%     --solute NAME    hcl|naoh|acetic
%     --c1 --v1 --c2 --v2  dilution variables
%     --order N        reaction order
%     --k RATE         rate constant
%     --conc0 VAL      initial concentration
%     --time T         time elapsed
%     --reactants --products  reaction strings
%     --format json|table|csv

    if nargin < 1, error('ml chem <action> [options]'); end

    opts = struct('format','json','formula','','p',101325,'v',0.0224,'n',1,'t',273.15, ...
                  'solve','t','conc',0.1,'solute','hcl', ...
                  'c1',1.0,'v1',0.1,'c2',0.1,'v2',0.1, ...
                  'order',1,'k',0.05,'conc0',1.0,'time',10, ...
                  'reactants','','products','');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--formula',   opts.formula = varargin{i+1}; i=i+2;
            case '--p',         opts.p = parse_num(varargin{i+1}); i=i+2;
            case '--v',         opts.v = parse_num(varargin{i+1}); i=i+2;
            case '--n',         opts.n = parse_num(varargin{i+1}); i=i+2;
            case '--t',         opts.t = parse_num(varargin{i+1}); i=i+2;
            case '--solve',     opts.solve = lower(varargin{i+1}); i=i+2;
            case '--conc',      opts.conc = parse_num(varargin{i+1}); i=i+2;
            case '--solute',    opts.solute = lower(varargin{i+1}); i=i+2;
            case '--c1',        opts.c1 = parse_num(varargin{i+1}); i=i+2;
            case '--v1',        opts.v1 = parse_num(varargin{i+1}); i=i+2;
            case '--c2',        opts.c2 = parse_num(varargin{i+1}); i=i+2;
            case '--v2',        opts.v2 = parse_num(varargin{i+1}); i=i+2;
            case '--order',     opts.order = round(parse_num(varargin{i+1})); i=i+2;
            case '--k',         opts.k = parse_num(varargin{i+1}); i=i+2;
            case '--conc0',     opts.conc0 = parse_num(varargin{i+1}); i=i+2;
            case '--time',      opts.time = parse_num(varargin{i+1}); i=i+2;
            case '--reactants', opts.reactants = varargin{i+1}; i=i+2;
            case '--products',  opts.products = varargin{i+1}; i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    try
        switch lower(action)
            case 'molar_mass', out = act_molar_mass(opts);
            case 'gas_law',    out = act_gas_law(opts);
            case 'ph',         out = act_ph(opts);
            case 'dilution',   out = act_dilution(opts);
            case 'reaction',   out = act_reaction(opts);
            case 'balance',    out = act_balance(opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_molar_mass(opts)
    formula = opts.formula;
    [mass, counts, atoms] = parse_formula(formula);
    out = struct();
    out.action = 'molar_mass';
    out.formula = formula;
    out.molarMass_g_per_mol = mass;
    out.elementCounts = counts;
    out.totalAtoms = atoms;
end

function out = act_gas_law(opts)
    R = 8.314;  % J/(mol·K)
    solve = opts.solve;
    switch solve
        case 'p'
            val = opts.n * R * opts.t / opts.v;
            unit = 'Pa';
        case 'v'
            val = opts.n * R * opts.t / opts.p;
            unit = 'm^3';
        case 'n'
            val = opts.p * opts.v / (R * opts.t);
            unit = 'mol';
        case 't'
            val = opts.p * opts.v / (opts.n * R);
            unit = 'K';
        otherwise
            error('solve must be p|v|n|t');
    end
    out = struct();
    out.action = 'gas_law';
    out.solved = solve;
    out.value = val;
    out.units = unit;
    out.given = struct('p_Pa',opts.p,'v_m3',opts.v,'n_mol',opts.n,'t_K',opts.t);
end

function out = act_ph(opts)
    C = opts.conc;
    solute = opts.solute;
    Kw = 1e-14;
    switch solute
        case {'hcl', 'naoh'}
            % Strong acid/base
            if strcmp(solute, 'hcl')
                hPlus = C;
                ohMinus = Kw / hPlus;
                pH = -log10(hPlus);
                kind = 'strong acid';
            else
                ohMinus = C;
                hPlus = Kw / ohMinus;
                pH = 14 + log10(C);
                kind = 'strong base';
            end
        case 'acetic'
            % Weak acid, Ka = 1.8e-5
            Ka = 1.8e-5;
            % Quadratic: x^2 + Ka*x - Ka*C = 0, x = [H+]
            hPlus = (-Ka + sqrt(Ka^2 + 4*Ka*C)) / 2;
            ohMinus = Kw / hPlus;
            pH = -log10(hPlus);
            kind = 'weak acid (Ka=1.8e-5)';
        otherwise
            error('unknown solute: %s (hcl|naoh|acetic)', solute);
    end
    out = struct();
    out.action = 'ph';
    out.solute = solute;
    out.type = kind;
    out.concentration_M = C;
    out.pH = pH;
    out.hPlus_M = hPlus;
    out.ohMinus_M = ohMinus;
end

function out = act_dilution(opts)
    solve = opts.solve;
    switch solve
        case 'v2'
            val = opts.c1 * opts.v1 / opts.c2;
            unit = 'L';
        case 'c2'
            val = opts.c1 * opts.v1 / opts.v2;
            unit = 'M';
        case 'c1'
            val = opts.c2 * opts.v2 / opts.v1;
            unit = 'M';
        case 'v1'
            val = opts.c2 * opts.v2 / opts.c1;
            unit = 'L';
        otherwise
            error('solve must be c1|v1|c2|v2');
    end
    out = struct();
    out.action = 'dilution';
    out.method = 'C1*V1 = C2*V2';
    out.solved = solve;
    out.value = val;
    out.units = unit;
end

function out = act_reaction(opts)
    order = opts.order;
    k = opts.k;
    C0 = opts.conc0;
    t = opts.time;
    switch order
        case 0
            Ct = max(0, C0 - k*t);
            halfLife = C0 / k;
            eqn = '[A](t) = [A]0 - k*t';
        case 1
            Ct = C0 * exp(-k*t);
            halfLife = log(2) / k;
            eqn = '[A](t) = [A]0 * exp(-k*t)';
        case 2
            Ct = C0 / (1 + k*C0*t);
            halfLife = 1 / (k*C0);
            eqn = '[A](t) = [A]0 / (1 + k*[A]0*t)';
        otherwise
            error('order must be 0, 1, or 2');
    end
    out = struct();
    out.action = 'reaction';
    out.order = order;
    out.rateConstant = k;
    out.initialConc = C0;
    out.time = t;
    out.equation = eqn;
    out.concentration_at_t = Ct;
    out.halfLife = halfLife;
end

function out = act_balance(opts)
    % Simple hydrocarbon combustion: C_x H_y + (x+y/4) O2 -> x CO2 + (y/2) H2O
    reactants = opts.reactants;
    products = opts.products;
    % Parse "CxHy" from reactants
    rParts = strsplit(reactants, '+');
    rParts = strtrim(rParts);
    fuel = '';
    for k = 1:numel(rParts)
        if ~strcmpi(strtrim(rParts{k}), 'O2')
            fuel = strtrim(rParts{k});
            break;
        end
    end
    if isempty(fuel)
        error('could not identify fuel in reactants');
    end
    [mass, counts, ~] = parse_formula(fuel);
    x = counts.C;
    y = counts.H;
    if x == 0 && y == 0
        error('fuel must contain C and/or H');
    end
    coeff_O2 = x + y/4;
    coeff_CO2 = x;
    coeff_H2O = y/2;
    balanced = sprintf('%s + %g*O2 -> %g*CO2 + %g*H2O', fuel, coeff_O2, coeff_CO2, coeff_H2O);
    out = struct();
    out.action = 'balance';
    out.fuel = fuel;
    out.equation = balanced;
    out.coefficients = struct('fuel',1, 'O2',coeff_O2, 'CO2',coeff_CO2, 'H2O',coeff_H2O);
    out.method = 'combustion (CxHy + O2 -> CO2 + H2O)';
end

% =================== Formula parser ===================
function [mass, counts, totalAtoms] = parse_formula(formula)
    % Built-in element masses
    masses = struct( ...
        'H', 1.008, 'He', 4.003, 'Li', 6.941, 'Be', 9.012, 'B', 10.811, ...
        'C', 12.011, 'N', 14.007, 'O', 15.999, 'F', 18.998, 'Ne', 20.180, ...
        'Na', 22.990, 'Mg', 24.305, 'Al', 26.982, 'Si', 28.085, 'P', 30.974, ...
        'S', 32.06, 'Cl', 35.45, 'Ar', 39.948, 'K', 39.098, 'Ca', 40.078, ...
        'Sc', 44.956, 'Ti', 47.867, 'V', 50.942, 'Cr', 51.996, 'Mn', 54.938, ...
        'Fe', 55.845, 'Co', 58.933, 'Ni', 58.693, 'Cu', 63.546, 'Zn', 65.38, ...
        'Ga', 69.723, 'Ge', 72.64, 'As', 74.922, 'Se', 78.96, 'Br', 79.904, ...
        'Kr', 83.798, 'Rb', 85.468, 'Sr', 87.62, 'Ag', 107.868, 'Cd', 112.411, ...
        'Sn', 118.71, 'I', 126.904, 'Xe', 131.293, 'Cs', 132.905, ...
        'Ba', 137.327, 'Au', 196.967, 'Hg', 200.59, 'Pb', 207.2, 'Bi', 208.98, ...
        'U', 238.029);
    mass = 0;
    counts = struct();
    totalAtoms = 0;
    % Tokenize: element symbol (Capital + optional lowercase) + optional number
    % Handle simple parens: (NH4)2 -> expand
    expanded = expand_parens(formula);
    tokens = regexp(expanded, '([A-Z][a-z]?)(\d*)', 'match');
    tokens = tokens(~cellfun('isempty', tokens));
    for k = 1:numel(tokens)
        tok = tokens{k};
        m = regexp(tok, '^([A-Z][a-z]?)(\d*)$', 'tokens');
        if isempty(m), continue; end
        elem = m{1}{1};
        countStr = m{1}{2};
        if isempty(countStr)
            count = 1;
        else
            count = sscanf(countStr, '%d');
        end
        if isfield(masses, elem)
            mass = mass + masses.(elem) * count;
            if isfield(counts, elem)
                counts.(elem) = counts.(elem) + count;
            else
                counts.(elem) = count;
            end
            totalAtoms = totalAtoms + count;
        end
    end
end

function out = expand_parens(s)
    % Expand (ABC)n -> n copies of ABC, also handle nested
    out = s;
    changed = true;
    while changed
        changed = false;
        % Find innermost group
        m = regexp(out, '\(([^()]+)\)(\d*)', 'tokens');
        if ~isempty(m)
            inner = m{1}{1};
            multStr = m{1}{2};
            if isempty(multStr)
                mult = 1;
            else
                mult = sscanf(multStr, '%d');
            end
            expandedInner = '';
            % Multiply each element in inner
            toks = regexp(inner, '([A-Z][a-z]?)(\d*)', 'tokens');
            for k = 1:numel(toks)
                elem = toks{k}{1};
                cntStr = toks{k}{2};
                if isempty(cntStr), cnt = 1; else, cnt = sscanf(cntStr, '%d'); end
                expandedInner = [expandedInner, elem, num2str(cnt * mult)];
            end
            % Replace this specific match in out
            % regexpreplace only the first occurrence
            out = regexprep(out, '\([^()]+\)\d*', expandedInner, 'once');
            changed = true;
        end
    end
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
