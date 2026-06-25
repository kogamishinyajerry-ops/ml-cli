function cli_game(action, varargin)
% CLI_GAME Game theory for ml CLI
%   CLI: ml game nash     --payoff "[3,0;5,1;0,2;4,3]"
%         ml game dominant --payoff "[3,0;5,1;0,2;4,3]"
%         ml game prisoner --tempt 5 --reward 3 --punish 1 --sucker 0
%         ml game mixed    --payoff "[3,0;5,1;0,2;4,3]"
%         ml game zero_sum --payoff "[2,-1;-3,4]"
%         ml game payoff   --a "[3,1;5,0]" --b "[0,2;4,3]"
%
%   Options:
%     --payoff MATRIX   payoff matrix (player 1 rows, player 2 cols)
%     --a MATRIX        player 1's payoff matrix
%     --b MATRIX        player 2's payoff matrix
%     --tempt VAL       temptation payoff (defect vs cooperate)
%     --reward VAL      reward for mutual cooperation
%     --punish VAL      punishment for mutual defection
%     --sucker VAL      sucker's payoff
%     --strategy N      strategy index to check (1-based)
%     --format json|table|csv

    if nargin < 1, error('ml game <action> [options]'); end

    opts = struct('format','json','payoff','','a','','b','', ...
                  'tempt',5,'reward',3,'punish',1,'sucker',0,'strategy',1);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--payoff',   opts.payoff = varargin{i+1}; i=i+2;
            case '--a',        opts.a = varargin{i+1}; i=i+2;
            case '--b',        opts.b = varargin{i+1}; i=i+2;
            case '--tempt',    opts.tempt = parse_num(varargin{i+1}); i=i+2;
            case '--reward',   opts.reward = parse_num(varargin{i+1}); i=i+2;
            case '--punish',   opts.punish = parse_num(varargin{i+1}); i=i+2;
            case '--sucker',   opts.sucker = parse_num(varargin{i+1}); i=i+2;
            case '--strategy', opts.strategy = round(parse_num(varargin{i+1})); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'nash',     out = act_nash(opts);
            case 'dominant', out = act_dominant(opts);
            case 'prisoner', out = act_prisoner(opts);
            case 'mixed',    out = act_mixed(opts);
            case 'zero_sum', out = act_zero_sum(opts);
            case 'payoff',   out = act_payoff(opts);
            otherwise,       error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_nash(opts)
    % Find pure-strategy Nash equilibria in 2-player normal-form game
    % Payoff: [P1_strat1_col1 P1_strat1_col2 P1_strat2_col1 P1_strat2_col2 ...
    %          P2_strat1_col1 P2_strat1_col2 P2_strat2_col1 P2_strat2_col2]
    v = parse_payoff_vec(opts.payoff);
    if numel(v) < 4
        error('payoff must have at least 4 values (2x2 game)');
    end
    half = numel(v) / 2;
    nStrats = sqrt(half);
    if abs(nStrats - round(nStrats)) > 1e-10
        error('payoff must encode equal strategies per player');
    end
    nStrats = round(nStrats);
    P1 = reshape(v(1:half), nStrats, nStrats)';
    P2 = reshape(v(half+1:end), nStrats, nStrats)';
    nashEq = {};
    for s1 = 1:nStrats
        for s2 = 1:size(P1, 2)
            % Check player 1 best response
            p1Best = true;
            for alt = 1:nStrats
                if P1(alt, s2) > P1(s1, s2)
                    p1Best = false; break;
                end
            end
            % Check player 2 best response
            p2Best = true;
            for alt = 1:size(P2, 2)
                if P2(s1, alt) > P2(s1, s2)
                    p2Best = false; break;
                end
            end
            if p1Best && p2Best
                nashEq{end+1} = struct('player1Strategy', s1, 'player2Strategy', s2, ...
                    'payoff1', P1(s1, s2), 'payoff2', P2(s1, s2));
            end
        end
    end
    out = struct();
    out.action = 'nash';
    out.method = 'pure-strategy best response check';
    out.nashEquilibria = nashEq;
    out.count = numel(nashEq);
end

function out = act_dominant(opts)
    % Check for strictly/weakly dominant strategies
    v = parse_payoff_vec(opts.payoff);
    if numel(v) < 4, error('payoff needs at least 4 values'); end
    half = numel(v) / 2;
    nStrats = sqrt(half);
    if abs(nStrats - round(nStrats)) > 1e-10
        error('payoff must encode equal strategies per player');
    end
    nStrats = round(nStrats);
    P1 = reshape(v(1:half), nStrats, nStrats)';
    P2 = reshape(v(half+1:end), nStrats, nStrats)';
    % Check player 1: strict dominance = all others strictly worse
    p1Strict = [];
    for s1 = 1:nStrats
        strictlyDominant = true;
        for alt = 1:nStrats
            if alt == s1, continue; end
            if ~all(P1(s1, :) > P1(alt, :))
                strictlyDominant = false;
                break;
            end
        end
        if strictlyDominant, p1Strict = [p1Strict, s1]; end
    end
    % Check player 2 similarly
    p2Strict = [];
    for s2 = 1:nStrats
        strictlyDominant = true;
        for alt = 1:nStrats
            if alt == s2, continue; end
            if ~all(P2(:, s2)' > P2(:, alt)')
                strictlyDominant = false;
                break;
            end
        end
        if strictlyDominant, p2Strict = [p2Strict, s2]; end
    end
    out = struct();
    out.action = 'dominant';
    out.player1StrictlyDominant = p1Strict;
    out.player2StrictlyDominant = p2Strict;
    out.originalPayoffs = struct('P1',P1,'P2',P2);
end

function out = act_prisoner(opts)
    % Prisoner's dilemma payoff matrix
    T = opts.tempt; R = opts.reward; P = opts.punish; S = opts.sucker;
    if ~(T > R && R > P && P > S)
        % Not a proper PD, but still analyze
        isPD = false;
    else
        isPD = true;
    end
    payoffs = struct();
    payoffs.CC = [R, R];
    payoffs.CD = [S, T];
    payoffs.DC = [T, S];
    payoffs.DD = [P, P];
    % Dominant strategy: defect
    dominant = 'Defect (D)';
    % Nash equilibrium
    nash = 'Both Defect (D,D)';
    % Pareto optimal: Both Cooperate (C,C)
    pareto = 'Both Cooperate (C,C)';
    out = struct();
    out.action = 'prisoner';
    out.isPrisonersDilemma = isPD;
    out.payoffMatrix = payoffs;
    out.dominantStrategy = dominant;
    out.nashEquilibrium = nash;
    out.paretoOptimal = pareto;
    out.parameters = struct('T_temptation',T, 'R_reward',R, 'P_punishment',P, 'S_sucker',S);
end

function out = act_mixed(opts)
    % Solve for mixed-strategy NE in 2x2 game
    v = parse_payoff_vec(opts.payoff);
    if numel(v) < 8
        error('need 8 payoff values for 2x2 mixed (P1_row1 P1_row2 P2_row1 P2_row2)');
    end
    a = v(1); b = v(2); c = v(3); d = v(4);
    e = v(5); f = v(6); g = v(7); h = v(8);
    % Player 2's mix (q = prob of col 1): player 1 indifferent
    denom = a - c - b + d;
    if abs(denom) < 1e-10
        q = 0.5;  % degenerate
    else
        q = (d - c) / denom;
    end
    q = max(0, min(1, q));
    % Player 1's mix (p = prob of row 1): player 2 indifferent
    denom2 = e - g - f + h;
    if abs(denom2) < 1e-10
        p = 0.5;
    else
        p = (h - g) / denom2;
    end
    p = max(0, min(1, p));
    % Expected payoffs
    p1Exp = p*q*a + p*(1-q)*b + (1-p)*q*c + (1-p)*(1-q)*d;
    p2Exp = p*q*e + p*(1-q)*f + (1-p)*q*g + (1-p)*(1-q)*h;
    out = struct();
    out.action = 'mixed';
    out.method = 'indifference condition (2x2)';
    out.mixedStrategy1 = struct('probRow1', p, 'probRow2', 1-p);
    out.mixedStrategy2 = struct('probCol1', q, 'probCol2', 1-q);
    out.expectedPayoffs = struct('player1', p1Exp, 'player2', p2Exp);
end

function out = act_zero_sum(opts)
    v = parse_payoff_vec(opts.payoff);
    n = sqrt(numel(v));
    if abs(n - round(n)) > 1e-10
        error('zero-sum payoff must be square');
    end
    n = round(n);
    P = reshape(v, n, n)';
    % Player 1 payoff = P, player 2 = -P
    [m, n] = size(P);
    % Maximin strategy (security level)
    rowMins = min(P, [], 2);
    [p1Security, p1Strategy] = max(rowMins);
    % Minimax for player 2 (maximize their floor)
    colMaxs = max(P, [], 1);
    [p2BestOfWorst, p2Strategy] = min(colMaxs);
    % Saddle point check
    hasSaddle = (abs(p1Security - p2BestOfWorst) < 1e-10);
    out = struct();
    out.action = 'zero_sum';
    out.payoff = P;
    out.saddlePoint = hasSaddle;
    if hasSaddle
        out.value = p1Security;
        out.optimalStrategy1 = p1Strategy;
        out.optimalStrategy2 = p2Strategy;
    else
        out.player1Security = p1Security;
        out.player2Guarantee = p2BestOfWorst;
        out.note = 'no pure saddle point, mixed strategy needed';
    end
end

function out = act_payoff(opts)
    % Show payoff for specific strategy pair
    P1 = parse_mat(opts.a);
    P2 = parse_mat(opts.b);
    out = struct();
    out.action = 'payoff';
    out.matrixPlayer1 = P1;
    out.matrixPlayer2 = P2;
    out.note = 'use nash/mixed/dominant for equilibrium analysis';
end

% =================== Helpers ===================
function v = parse_payoff_vec(s)
    % Parse a flattened payoff string for game theory
    if ischar(s) || isstring(s)
        s = regexprep(s, '[\[\]{}\(\),;]', ' ');
        v = sscanf(s, '%f');
    else
        v = s(:)';
    end
end

function M = parse_mat(s)
    if ischar(s) || isstring(s)
        s = regexprep(s, '[\[\]{}]', '');
        s = regexprep(s, ';', ' ');
        v = sscanf(s, '%f');
        % Try to detect dimensions
        n = sqrt(numel(v));
        if abs(n - round(n)) < 1e-10
            M = reshape(v, round(n), round(n))';
        else
            M = v(:)';
        end
    else
        M = s;
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
