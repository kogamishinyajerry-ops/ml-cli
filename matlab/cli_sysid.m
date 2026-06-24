function cli_sysid(action, varargin)
% CLI_SYSID System identification for ml CLI
%   CLI: ml sysid arx   --u "u1,u2,..." --y "y1,y2,..." --na 2 --nb 2 --nk 1
%         ml sysid arma  --y "y1,..." --na 2 --nc 2
%         ml sysid ss    --u "..." --y "..." --order 3
%         ml sysid tfest --freq "..." --resp "..." --np 2 --nz 1
%         ml sysid compare --model FILE.mat --u "..." --y "..."
%         ml sysid validate --model FILE.mat --u "..." --y "..."
%
%   Options:
%     --u "u1,u2,..."   input signal (csv)
%     --y "y1,y2,..."   output signal (csv)
%     --na N --nb N --nk N   ARX orders
%     --nc N            ARMA C-order
%     --order N         state-space order
%     --freq "w1,..."   frequencies (rad/s) for tfest
%     --resp "h1,..."   frequency response (complex "re,im,re,im,..." or mag)
%     --np N --nz N     tfest poles/zeros count
%     --ts T            sample time (default 1)
%     --model PATH      saved .mat model path (for compare/validate)
%     --save PATH       save identified model to .mat
%     --format json|table|csv

    if nargin < 1, error('ml sysid <action> [options]'); end

    opts = struct('format','json','ts',1,'na',2,'nb',2,'nk',1,'nc',2,'order',3,'np',2,'nz',1);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--u',       opts.u = parse_vec(varargin{i+1}); i=i+2;
            case '--y',       opts.y = parse_vec(varargin{i+1}); i=i+2;
            case '--na',      opts.na = round(parse_num(varargin{i+1})); i=i+2;
            case '--nb',      opts.nb = round(parse_num(varargin{i+1})); i=i+2;
            case '--nk',      opts.nk = round(parse_num(varargin{i+1})); i=i+2;
            case '--nc',      opts.nc = round(parse_num(varargin{i+1})); i=i+2;
            case '--order',   opts.order = round(parse_num(varargin{i+1})); i=i+2;
            case '--ts',      opts.ts = parse_num(varargin{i+1}); i=i+2;
            case '--freq',    opts.freq = parse_vec(varargin{i+1}); i=i+2;
            case '--resp',    opts.resp = parse_vec(varargin{i+1}); i=i+2;
            case '--np',      opts.np = round(parse_num(varargin{i+1})); i=i+2;
            case '--nz',      opts.nz = round(parse_num(varargin{i+1})); i=i+2;
            case '--model',   opts.model = varargin{i+1}; i=i+2;
            case '--save',    opts.save = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    if ~exist('idpoly','class')
        error('System Identification Toolbox not available');
    end

    try
        switch lower(action)
            case 'arx',      out = act_arx(opts);
            case 'arma',     out = act_arma(opts);
            case 'ss',       out = act_ss(opts);
            case 'tfest',    out = act_tfest(opts);
            case 'compare',  out = act_compare(opts);
            case 'validate', out = act_validate(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_arx(opts)
    if ~isfield(opts,'u') || ~isfield(opts,'y')
        error('arx needs --u and --y');
    end
    z = iddata(opts.y(:), opts.u(:), opts.ts);
    model = arx(z, [opts.na, opts.nb, opts.nk]);
    out = struct();
    out.action = 'arx';
    out.orders = struct('na',opts.na,'nb',opts.nb,'nk',opts.nk);
    out.A = model.A;
    out.B = model.B;
    out.Ts = opts.ts;
    out.fitPercent = model.Report.Fit.FitPercent;
    out.lossFcn = model.Report.Fit.LossFcn;
    out.FPE = model.Report.Fit.FPE;
    out.AIC = model.Report.Fit.AIC;
    out.MSE = model.Report.Fit.MSE;
    if isfield(opts,'save')
        m = model; save(opts.save, 'm'); out.savedTo = opts.save;
    end
end

function out = act_arma(opts)
    if ~isfield(opts,'y'), error('arma needs --y'); end
    z = iddata(opts.y(:), [], opts.ts);
    model = armax(z, [opts.na, opts.nc]);
    out = struct();
    out.action = 'arma';
    out.orders = struct('na',opts.na,'nc',opts.nc);
    out.A = model.A;
    out.C = model.C;
    out.Ts = opts.ts;
    out.fitPercent = model.Report.Fit.FitPercent;
    out.FPE = model.Report.Fit.FPE;
    out.AIC = model.Report.Fit.AIC;
    out.MSE = model.Report.Fit.MSE;
    if isfield(opts,'save')
        m = model; save(opts.save, 'm'); out.savedTo = opts.save;
    end
end

function out = act_ss(opts)
    if ~isfield(opts,'u') || ~isfield(opts,'y')
        error('ss needs --u and --y');
    end
    z = iddata(opts.y(:), opts.u(:), opts.ts);
    model = n4sid(z, opts.order);
    out = struct();
    out.action = 'ss';
    out.order = opts.order;
    out.A = model.A;
    out.B = model.B;
    out.C = model.C;
    out.D = model.D;
    out.Ts = opts.ts;
    out.fitPercent = model.Report.Fit.FitPercent;
    out.FPE = model.Report.Fit.FPE;
    out.AIC = model.Report.Fit.AIC;
    if isfield(opts,'save')
        m = model; save(opts.save, 'm'); out.savedTo = opts.save;
    end
end

function out = act_tfest(opts)
    if ~isfield(opts,'freq') || ~isfield(opts,'resp')
        error('tfest needs --freq "w1,w2,..." and --resp "h1,h2,..."');
    end
    w = opts.freq(:);
    % If resp has 2x length of freq, it's complex (re,im pairs)
    if numel(opts.resp) == 2*numel(w)
        H = complex(opts.resp(1:2:end), opts.resp(2:2:end));
    else
        H = opts.resp(:);
    end
    G = idfrd(H, w, opts.ts);
    model = tfest(G, opts.np, opts.nz);
    out = struct();
    out.action = 'tfest';
    [num, den] = tfdata(model, 'v');
    out.num = num;
    out.den = den;
    out.np = opts.np;
    out.nz = opts.nz;
    out.fitPercent = model.Report.Fit.FitPercent;
    if isfield(opts,'save')
        m = model; save(opts.save, 'm'); out.savedTo = opts.save;
    end
end

function out = act_compare(opts)
    if ~isfield(opts,'model'), error('compare needs --model FILE.mat'); end
    L = load(opts.model);
    fn = fieldnames(L);
    model = L.(fn{1});
    if ~isfield(opts,'u') || ~isfield(opts,'y')
        error('compare needs --u and --y validation data');
    end
    z = iddata(opts.y(:), opts.u(:), opts.ts);
    yfit = compare(z, model);
    out = struct();
    out.action = 'compare';
    out.modelFile = opts.model;
    out.fitPercent = compare(z, model);
    yh = sim(model, z);
    out.rmse = sqrt(mean((opts.y(:) - yh.OutputData).^2));
    out.predictedOutput = yh.OutputData(:);
end

function out = act_validate(opts)
    if ~isfield(opts,'model'), error('validate needs --model FILE.mat'); end
    L = load(opts.model);
    fn = fieldnames(L);
    model = L.(fn{1});
    if ~isfield(opts,'u') || ~isfield(opts,'y')
        error('validate needs --u and --y data');
    end
    z = iddata(opts.y(:), opts.u(:), opts.ts);
    [e, r, rNorm] = resid(z, model);
    out = struct();
    out.action = 'validate';
    out.modelFile = opts.model;
    out.residualMean = mean(e.OutputData);
    out.residualStd = std(e.OutputData);
    out.isWhite = (abs(out.residualMean) < 3*out.residualStd/sqrt(numel(e.OutputData)));
    out.autocorrLag1 = r.OutputData(2,1);
    out.normalResid = rNorm.OutputData;
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function v = parse_vec(s)
    if isnumeric(s), v = s; return; end
    s = strtrim(strrep(s, ',', ' '));
    parts = strsplit(s, ' ');
    parts = parts(~cellfun(@isempty, parts));
    v = str2double(parts);
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
