function cli_pde(action, varargin)
% CLI_PDE Partial differential equation solver for ml CLI
%   CLI: ml pde heat   --geom "[0 1]" --nx 50 --alpha 0.1 --tfinal 1 --ic "sin(pi*x)"
%         ml pde wave   --geom "[0 1]" --nx 80 --c 1 --tfinal 2 --ic "sin(pi*x)"
%         ml pde poisson --geom "[0 1 0 1]" --nx 30 --ny 30 --f "1" --bc dirichlet
%         ml pde mesh    --geom "[0 1 0 1]" --nx 20 --ny 20
%
%   Options:
%     --geom "xrange [yrange]"    domain bounds
%     --nx N   --ny N             grid resolution
%     --alpha V                   diffusion coefficient
%     --c V                       wave speed
%     --f "expr"                  source term
%     --ic "expr"                 initial condition
%     --bc dirichlet|neumann      boundary condition type
%     --tfinal T                  final time
%     --nt N                      number of time steps
%     --plot PATH                 save plot to file
%     --format json|table|csv

    if nargin < 1, error('ml pde <action> [options]'); end

    opts = struct('format','json','bc','dirichlet','nt',100);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--geom',    opts.geom = varargin{i+1}; i=i+2;
            case '--nx',      opts.nx = round(parse_num(varargin{i+1})); i=i+2;
            case '--ny',      opts.ny = round(parse_num(varargin{i+1})); i=i+2;
            case '--alpha',   opts.alpha = parse_num(varargin{i+1}); i=i+2;
            case '--c',       opts.c = parse_num(varargin{i+1}); i=i+2;
            case '--f',       opts.fExpr = varargin{i+1}; i=i+2;
            case '--ic',      opts.icExpr = varargin{i+1}; i=i+2;
            case '--bc',      opts.bc = varargin{i+1}; i=i+2;
            case '--tfinal',  opts.tfinal = parse_num(varargin{i+1}); i=i+2;
            case '--nt',      opts.nt = round(parse_num(varargin{i+1})); i=i+2;
            case '--plot',    opts.plot = varargin{i+1}; i=i+2;
            case '--format',  opts.format = varargin{i+1}; i=i+2;
            otherwise,        i=i+1;
        end
    end

    if ~exist('pdepe','file')
        error('Partial Differential Equation Toolbox not available');
    end

    try
        switch lower(action)
            case 'heat',     out = act_heat(opts);
            case 'wave',     out = act_wave(opts);
            case 'poisson',  out = act_poisson(opts);
            case 'mesh',     out = act_mesh(opts);
            case 'diffusion', out = act_heat(opts);   % alias
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_heat(opts)
    % 1D heat equation: ∂u/∂t = α ∂²u/∂x²
    if ~isfield(opts,'geom'), error('heat needs --geom "[xmin xmax]"'); end
    g = parse_vec(opts.geom);
    if numel(g) < 2, error('geom needs at least 2 values for 1D'); end
    x = linspace(g(1), g(2), get_or(opts,'nx',50));
    t = linspace(0, get_or(opts,'tfinal',1), get_or(opts,'nt',50));
    alpha = get_or(opts,'alpha', 0.1);
    icExpr = get_or(opts,'icExpr', 'sin(pi*x)');
    bcType = lower(get_or(opts,'bc','dirichlet'));
    % pdepe formulation: m=0, c=1, f=α*∂u/∂x, s=0
    sol = pdepe(0, @pdefun, @icfun, @bcfun, x, t);
    out = struct();
    out.equation = 'du/dt = alpha * d2u/dx2';
    out.alpha = alpha;
    out.x = x;
    out.t = t;
    out.solution = sol;  % (nt, nx) matrix
    out.initialCondition = icExpr;
    out.bcType = bcType;
    out.peakValue = max(sol(:));
    out.finalMax = max(sol(end,:));
    if strcmp(get_or(opts,'plot',''), '')
        % skip
    else
        fig = figure('Visible','off');
        surf(x, t, sol); xlabel('x'); ylabel('t'); zlabel('u');
        title(sprintf('Heat equation (\\alpha = %g)', alpha));
        exportgraphics(fig, opts.plot); close(fig);
        out.plotFile = opts.plot;
    end

    function [c,f,s] = pdefun(x,t,u,DuDx)
        c = 1;
        f = alpha * DuDx;
        s = 0;
    end

    function u0 = icfun(x)
        u0 = eval(icExpr);
    end

    function [pl,ql,pr,qr] = bcfun(xl,ul,xr,ur,t)
        if strcmp(bcType,'neumann')
            pl = 0; ql = 1;       % ∂u/∂x = 0 at left
            pr = 0; qr = 1;       % ∂u/∂x = 0 at right
        else
            pl = ul; ql = 0;      % u = 0 at left
            pr = ur; qr = 0;      % u = 0 at right
        end
    end
end

function out = act_wave(opts)
    % 1D wave equation: ∂²u/∂t² = c² ∂²u/∂x²  (finite-difference)
    if ~isfield(opts,'geom'), error('wave needs --geom "[xmin xmax]"'); end
    g = parse_vec(opts.geom);
    nx = get_or(opts,'nx',80);
    x = linspace(g(1), g(2), nx);
    dx = x(2) - x(1);
    c = get_or(opts,'c',1);
    tfinal = get_or(opts,'tfinal',2);
    nt = get_or(opts,'nt',200);
    t = linspace(0, tfinal, nt);
    dt = t(2) - t(1);
    % CFL stability: c*dt/dx ≤ 1
    courant = c*dt/dx;
    if courant > 1
        warning('CFL condition violated: c*dt/dx = %.3f > 1 (unstable)', courant);
    end
    icExpr = get_or(opts,'icExpr', 'sin(pi*x)');
    u0 = eval(icExpr);
    u1 = u0;  % zero initial velocity
    % Time-stepping
    U = zeros(nt, nx);
    U(1,:) = u0;
    U(2,:) = u1;
    r = (c*dt/dx)^2;
    for n = 2:nt-1
        uPrev = U(n-1,:);
        uCurr = U(n,:);
        uNext = uCurr;
        uNext(2:end-1) = 2*uCurr(2:end-1) - uPrev(2:end-1) + r*(uCurr(3:end) - 2*uCurr(2:end-1) + uCurr(1:end-2));
        % Dirichlet BC: u=0 at endpoints
        uNext(1) = 0; uNext(end) = 0;
        U(n+1,:) = uNext;
    end
    out = struct();
    out.equation = 'd2u/dt2 = c^2 * d2u/dx2';
    out.c = c;
    out.courantNumber = courant;
    out.x = x;
    out.t = t;
    out.solution = U;
    out.peakValue = max(U(:));
    if strcmp(get_or(opts,'plot',''), '')
        % skip
    else
        fig = figure('Visible','off');
        surf(x, t, U); xlabel('x'); ylabel('t'); zlabel('u');
        title(sprintf('Wave equation (c = %g)', c));
        exportgraphics(fig, opts.plot); close(fig);
        out.plotFile = opts.plot;
    end
end

function out = act_poisson(opts)
    % 2D Poisson: -∇²u = f on rectangular domain
    if ~isfield(opts,'geom'), error('poisson needs --geom "[xmin xmax ymin ymax]"'); end
    g = parse_vec(opts.geom);
    if numel(g) ~= 4, error('poisson needs 4 geom values: xmin xmax ymin ymax'); end
    nx = get_or(opts,'nx',30); ny = get_or(opts,'ny',30);
    x = linspace(g(1), g(2), nx);
    y = linspace(g(3), g(4), ny);
    [X,Y] = meshgrid(x, y);
    fExpr = get_or(opts,'fExpr','1');
    fVal = eval(fExpr);
    if isscalar(fVal)
        f = fVal * ones(size(X));
    else
        f = fVal;
    end
    % Solve via finite differences: 5-point stencil
    % -∇²u = f  →  -(u_{i+1,j} + u_{i-1,j} + u_{i,j+1} + u_{i,j-1} - 4u_{i,j})/h² = f
    hx = x(2) - x(1);
    hy = y(2) - y(1);
    N = nx * ny;
    % Build sparse matrix A
    A = sparse(N, N);
    b = zeros(N, 1);
    for j = 1:ny
        for i = 1:nx
            k = (j-1)*nx + i;
            A(k,k) = 2/hx^2 + 2/hy^2;
            b(k) = f(j, i);
            if i > 1,    A(k, k-1) = -1/hx^2; end
            if i < nx,   A(k, k+1) = -1/hx^2; end
            if j > 1,    A(k, k-nx) = -1/hy^2; end
            if j < ny,   A(k, k+nx) = -1/hy^2; end
        end
    end
    % Dirichlet BC u=0 on boundary
    for j = 1:ny
        for i = 1:nx
            k = (j-1)*nx + i;
            if i==1 || i==nx || j==1 || j==ny
                A(k,:) = 0; A(k,k) = 1; b(k) = 0;
            end
        end
    end
    u = A \ b;
    U = reshape(u, nx, ny)';
    out = struct();
    out.equation = '-laplacian(u) = f';
    out.sourceExpr = fExpr;
    out.x = x;
    out.y = y;
    out.solution = U;
    out.maxValue = max(U(:));
    out.minValue = min(U(:));
    if strcmp(get_or(opts,'plot',''), '')
        % skip
    else
        fig = figure('Visible','off');
        surf(X, Y, U); xlabel('x'); ylabel('y'); zlabel('u');
        title('Poisson equation solution');
        exportgraphics(fig, opts.plot); close(fig);
        out.plotFile = opts.plot;
    end
end

function out = act_mesh(opts)
    if ~isfield(opts,'geom'), error('mesh needs --geom'); end
    g = parse_vec(opts.geom);
    if numel(g) == 2
        x = linspace(g(1), g(2), get_or(opts,'nx',20));
        y = [];
    elseif numel(g) >= 4
        x = linspace(g(1), g(2), get_or(opts,'nx',20));
        y = linspace(g(3), g(4), get_or(opts,'ny',20));
    else
        error('geom needs 2 (1D) or 4 (2D) values');
    end
    out = struct();
    if isempty(y)
        out.dimension = 1;
        out.x = x;
        out.numNodes = numel(x);
        out.numElements = numel(x) - 1;
        out.spacing = x(2) - x(1);
    else
        [X,Y] = meshgrid(x, y);
        out.dimension = 2;
        out.x = x;
        out.y = y;
        out.numNodes = numel(X);
        out.numElements = (numel(x)-1) * (numel(y)-1);
        out.dx = x(2) - x(1);
        out.dy = y(2) - y(1);
    end
end

% =================== Helpers ===================
function v = get_or(opts, field, default)
    if isfield(opts, field), v = opts.(field); else, v = default; end
end

function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function v = parse_vec(s)
    if isnumeric(s), v = s; return; end
    s = strtrim(s);
    s = strrep(strrep(s, '[',''), ']','');
    s = strrep(s, ',', ' ');
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
