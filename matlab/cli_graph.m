function cli_graph(action, varargin)
% CLI_GRAPH Graph/network analysis for ml CLI
%   CLI: ml graph info       --edges "1-2,2-3,3-4,4-1"
%         ml graph shortest  --edges "1-2,2-3" --from 1 --to 3
%         ml graph mst       --edges "1-2,2-3" --weights "1,5"
%         ml graph pagerank  --diedges "1-2,2-3"
%         ml graph components --edges "1-2,4-5"
%         ml graph degree    --diedges "1-2,1-3"
%
%   Options:
%     --edges "1-2,2-3"        undirected edges
%     --diedges "1-2,2-3"      directed edges
%     --adj "[0 1;1 0]"        adjacency matrix
%     --weights "1,2,3"        edge weights
%     --from N --to N          node IDs for path queries
%     --method bfs|dijkstra    path method (auto for unweighted)
%     --alpha 0.85             PageRank damping
%     --top K                  top-K limit for pagerank/degree
%     --weak|--strong          component type (directed)
%     --format json|table|csv

    if nargin < 1, error('ml graph <action> [options]'); end

    opts = struct('format','json','alpha',0.85,'top',0);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--edges',    opts.edges = varargin{i+1}; opts.directed = false; i=i+2;
            case '--diedges',  opts.edges = varargin{i+1}; opts.directed = true;  i=i+2;
            case '--adj',      opts.adj = varargin{i+1}; i=i+2;
            case '--weights',  opts.weights = varargin{i+1}; i=i+2;
            case '--from',     opts.fromN = parse_num(varargin{i+1}); i=i+2;
            case '--to',       opts.toN = parse_num(varargin{i+1}); i=i+2;
            case '--method',   opts.method = varargin{i+1}; i=i+2;
            case '--alpha',    opts.alpha = parse_num(varargin{i+1}); i=i+2;
            case '--top',      opts.top = parse_num(varargin{i+1}); i=i+2;
            case '--weak',     opts.compType = 'weak'; i=i+1;
            case '--strong',   opts.compType = 'strong'; i=i+1;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        G = build_graph(opts);
        switch lower(action)
            case 'info',       out = act_info(G);
            case 'shortest',   out = act_shortest(G, opts);
            case 'mst',        out = act_mst(G);
            case 'pagerank',   out = act_pagerank(G, opts);
            case 'components', out = act_components(G, opts);
            case 'degree',     out = act_degree(G, opts);
            otherwise,         error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Graph construction ===================
function G = build_graph(opts)
    if isfield(opts,'adj')
        A = parse_bracket_mat(opts.adj);
        if opts.directed || isfield(opts,'directed') == false
            G = graph(A, 'upper');
        else
            G = digraph(A);
        end
        return;
    end
    if ~isfield(opts,'edges'), error('need --edges, --diedges, or --adj'); end
    [s, t] = parse_edges(opts.edges);
    if isfield(opts,'weights')
        w = parse_vec(opts.weights);
        if numel(w) ~= numel(s), error('weights count (%d) != edges (%d)', numel(w), numel(s)); end
        if opts.directed, G = digraph(s, t, w); else, G = graph(s, t, w); end
    else
        if opts.directed, G = digraph(s, t); else, G = graph(s, t); end
    end
end

function [s, t] = parse_edges(spec)
    % "1-2,2-3,3-4" -> s=[1 2 3], t=[2 3 4]
    edges = strsplit(spec, ',');
    edges = strtrim(edges);
    s = []; t = [];
    for k = 1:numel(edges)
        parts = strsplit(edges{k}, '-');
        if numel(parts) ~= 2, error('bad edge: %s', edges{k}); end
        s(end+1) = str2double(strtrim(parts{1})); %#ok<AGROW>
        t(end+1) = str2double(strtrim(parts{2})); %#ok<AGROW>
    end
end

% =================== Actions ===================
function out = act_info(G)
    out = struct();
    out.numNodes = numnodes(G);
    out.numEdges = numedges(G);
    out.directed = is_digraph(G);
    out.density = numedges(G) / max_edges(out.numNodes, out.directed);
    if out.directed
        bins = conncomp(G, 'Type', 'weak');
    else
        bins = conncomp(G);
    end
    out.numComponents = max(bins);
    out.isConnected = (out.numComponents == 1);
    try
        out.diameter = max(distances(G), [], 'all');
    catch
        out.diameter = NaN;
    end
    try
        out.avgPathLength = mean(distances(G), 'all');
    catch
        out.avgPathLength = NaN;
    end
end

function val = max_edges(n, directed)
    if directed, val = n*(n-1); else, val = n*(n-1)/2; end
end

function out = act_shortest(G, opts)
    if ~isfield(opts,'fromN') || ~isfield(opts,'toN')
        error('shortest requires --from and --to');
    end
    s = opts.fromN; t = opts.toN;
    [path, d] = shortestpath(G, s, t);
    out = struct();
    out.fromNode = s;
    out.toNode = t;
    out.distance = d;
    out.path = path;
    out.numHops = numel(path) - 1;
end

function out = act_mst(G)
    if is_digraph(G), error('MST requires undirected graph'); end
    [T, pred] = minspantree(G);
    out = struct();
    out.totalWeight = sum(T.Edges.Weight);
    e = T.Edges;
    % EndNodes is N×2 matrix; convert to cell of "i-j" strings
    en = e.EndNodes;
    edgeStrs = cell(size(en,1), 1);
    for k = 1:size(en,1)
        edgeStrs{k} = sprintf('%d-%d', en(k,1), en(k,2));
    end
    out.treeEdges = edgeStrs';
    out.numTreeEdges = size(en,1);
end

function out = act_pagerank(G, opts)
    scores = centrality(G, 'pagerank', 'FollowProbability', opts.alpha, 'Tolerance', 1e-6, 'MaxIterations', 500);
    nodes = (1:numnodes(G))';
    [~, idx] = sort(scores, 'descend');
    if opts.top > 0, idx = idx(1:min(opts.top, numel(idx))); end
    out = struct();
    out.nodes = nodes(idx);
    out.pageRank = scores(idx);
    out.alpha = opts.alpha;
end

function out = act_components(G, opts)
    if is_digraph(G)
        type = 'weak';
        if isfield(opts,'compType'), type = opts.compType; end
        bins = conncomp(G, 'Type', type);
        out.type = type;
    else
        bins = conncomp(G);
        out.type = 'undirected';
    end
    nComp = max(bins);
    out.numComponents = nComp;
    members = cell(1, nComp);
    for k = 1:nComp
        members{k} = find(bins == k);
    end
    out.componentMembers = members;
end

function out = act_degree(G, opts)
    n = numnodes(G);
    if is_digraph(G)
        inDeg = indegree(G);
        outDeg = outdegree(G);
        nodes = (1:n)';
        if opts.top > 0
            [~, idx] = sort(outDeg, 'descend');
            idx = idx(1:min(opts.top, n));
            nodes = nodes(idx); inDeg = inDeg(idx); outDeg = outDeg(idx);
        end
        out.nodes = nodes;
        out.inDegree = inDeg;
        out.outDegree = outDeg;
        out.totalDegree = inDeg + outDeg;
    else
        d = degree(G);
        nodes = (1:n)';
        if opts.top > 0
            [~, idx] = sort(d, 'descend');
            idx = idx(1:min(opts.top, n));
            nodes = nodes(idx); d = d(idx);
        end
        out.nodes = nodes;
        out.degree = d;
    end
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

function A = parse_bracket_mat(s)
    inner = regexp(s, '\[([^\]]*)\]', 'tokens');
    if isempty(inner), error('expected [a b;c d] form'); end
    rows = strsplit(inner{1}{1}, ';');
    R = [];
    for k = 1:numel(rows)
        r = parse_vec(strtrim(rows{k}));
        R = [R; r]; %#ok<AGROW>
    end
    A = R;
end

function tf = is_digraph(G)
    tf = isa(G, 'digraph');
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
