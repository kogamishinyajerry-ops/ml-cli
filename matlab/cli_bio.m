function cli_bio(action, varargin)
% CLI_BIO Bioinformatics for ml CLI
%   CLI: ml bio dna      --seq "ATGCATGC" --op complement
%         ml bio gc      --seq "ATGCATGC"
%         ml bio translate --seq "ATGGCC" --frame 0
%         ml bio align    --seq1 AACCGGT --seq2 AACAGT
%         ml bio motif    --seq ATGCAATGCAA --pattern ATGCAA
%         ml bio stats    --seq "ATGCATGC"
%
%   Options:
%     --seq STR        DNA sequence
%     --seq1 --seq2    sequences for alignment
%     --op NAME        complement|reverse|reverse_complement
%     --frame N        0|1|2 reading frame
%     --pattern STR    motif to search
%     --mismatch N     allowed mismatches (default 0)
%     --match --mismatch --gap  alignment scores
%     --format json|table|csv

    if nargin < 1, error('ml bio <action> [options]'); end

    opts = struct('format','json','seq','','seq1','','seq2','','op','complement', ...
                  'frame',0,'pattern','','mismatch',0,'match',1,'mism',-1,'gap',-2);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--seq',      opts.seq = upper(varargin{i+1}); i=i+2;
            case '--seq1',     opts.seq1 = upper(varargin{i+1}); i=i+2;
            case '--seq2',     opts.seq2 = upper(varargin{i+1}); i=i+2;
            case '--op',       opts.op = lower(varargin{i+1}); i=i+2;
            case '--frame',    opts.frame = round(parse_num(varargin{i+1})); i=i+2;
            case '--pattern',  opts.pattern = upper(varargin{i+1}); i=i+2;
            case '--mismatch', opts.mismatch = round(parse_num(varargin{i+1})); i=i+2;
            case '--match',    opts.match = parse_num(varargin{i+1}); i=i+2;
            case '--mism',     opts.mism = parse_num(varargin{i+1}); i=i+2;
            case '--gap',      opts.gap = parse_num(varargin{i+1}); i=i+2;
            case '--format',   opts.format = varargin{i+1}; i=i+2;
            otherwise,         i=i+1;
        end
    end

    try
        switch lower(action)
            case 'dna',       out = act_dna(opts);
            case 'gc',        out = act_gc(opts);
            case 'translate', out = act_translate(opts);
            case 'align',     out = act_align(opts);
            case 'motif',     out = act_motif(opts);
            case 'stats',     out = act_stats(opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_dna(opts)
    seq = opts.seq;
    op = opts.op;
    switch op
        case 'complement'
            result = complement(seq);
        case 'reverse'
            result = seq(end:-1:1);
        case 'reverse_complement'
            result = complement(seq(end:-1:1));
        otherwise
            error('unknown op: %s (complement|reverse|reverse_complement)', op);
    end
    out = struct();
    out.action = 'dna';
    out.inputLength = numel(seq);
    out.op = op;
    out.result = result;
end

function out = act_gc(opts)
    seq = opts.seq;
    counts = count_bases(seq);
    gc = 100 * (counts.G + counts.C) / max(1, numel(seq));
    % Molecular weight (ssDNA)
    mw = counts.A*331.2 + counts.T*322.2 + counts.G*347.2 + counts.C*307.2;
    out = struct();
    out.action = 'gc';
    out.sequence = seq;
    out.length = numel(seq);
    out.gcContent = gc;
    out.counts = counts;
    out.molecularWeight_Da = mw;
end

function out = act_translate(opts)
    seq = opts.seq;
    frame = opts.frame;
    % Truncate to codon boundary starting from frame
    n = numel(seq) - frame;
    n = n - mod(n, 3);
    codons = seq(frame+1 : frame+n);
    nCodons = n / 3;
    protein = '';
    stopPositions = [];
    for k = 0:nCodons-1
        codon = codons(3*k+1 : 3*k+3);
        aa = codon_to_aa(codon);
        protein = [protein, aa];
        if aa == '*'
            stopPositions = [stopPositions, k+1];
        end
    end
    out = struct();
    out.action = 'translate';
    out.frame = frame;
    out.codonsTranslated = nCodons;
    out.protein = protein;
    out.stopCodonPositions = stopPositions;
end

function out = act_align(opts)
    % Needleman-Wunsch global alignment
    s1 = opts.seq1;
    s2 = opts.seq2;
    match = opts.match;
    mism = opts.mism;
    gap = opts.gap;
    n1 = numel(s1);
    n2 = numel(s2);
    % DP matrix
    D = zeros(n1+1, n2+1);
    % Traceback pointer: 1=diag, 2=up (gap in s2), 3=left (gap in s1)
    T = zeros(n1+1, n2+1);
    for i = 1:n1
        D(i+1, 1) = i * gap;
        T(i+1, 1) = 2;
    end
    for j = 1:n2
        D(1, j+1) = j * gap;
        T(1, j+1) = 3;
    end
    for i = 1:n1
        for j = 1:n2
            if s1(i) == s2(j)
                diagScore = D(i, j) + match;
            else
                diagScore = D(i, j) + mism;
            end
            upScore = D(i, j+1) + gap;
            leftScore = D(i+1, j) + gap;
            scores = [diagScore, upScore, leftScore];
            [best, k] = max(scores);
            D(i+1, j+1) = best;
            T(i+1, j+1) = k;
        end
    end
    % Traceback
    a1 = '';
    a2 = '';
    i = n1 + 1;
    j = n2 + 1;
    while i > 1 || j > 1
        if i == 1
            a1 = ['-', a1];
            a2 = [s2(j-1), a2];
            j = j - 1;
        elseif j == 1
            a1 = [s1(i-1), a1];
            a2 = ['-', a2];
            i = i - 1;
        else
            switch T(i, j)
                case 1  % diag
                    a1 = [s1(i-1), a1];
                    a2 = [s2(j-1), a2];
                    i = i - 1; j = j - 1;
                case 2  % up
                    a1 = [s1(i-1), a1];
                    a2 = ['-', a2];
                    i = i - 1;
                case 3  % left
                    a1 = ['-', a1];
                    a2 = [s2(j-1), a2];
                    j = j - 1;
            end
        end
    end
    % Build match line
    matchLine = '';
    matches = 0;
    for k = 1:numel(a1)
        if a1(k) == a2(k) && a1(k) ~= '-'
            matchLine = [matchLine, '|'];
            matches = matches + 1;
        elseif a1(k) == '-' || a2(k) == '-'
            matchLine = [matchLine, ' '];
        else
            matchLine = [matchLine, '.'];
        end
    end
    identity = 100 * matches / numel(a1);
    out = struct();
    out.action = 'align';
    out.method = 'Needleman-Wunsch';
    out.aligned1 = a1;
    out.matchLine = matchLine;
    out.aligned2 = a2;
    out.score = D(n1+1, n2+1);
    out.identity_pct = identity;
    out.matches = matches;
    out.alignedLength = numel(a1);
end

function out = act_motif(opts)
    seq = opts.seq;
    pattern = opts.pattern;
    allowedMismatch = opts.mismatch;
    n = numel(seq);
    m = numel(pattern);
    if m > n, error('pattern longer than sequence'); end
    positions = [];
    matched = {};
    for i = 1:(n - m + 1)
        sub = seq(i:i+m-1);
        d = sum(sub ~= pattern);
        if d <= allowedMismatch
            positions = [positions, i];
            matched{end+1} = sub;
        end
    end
    out = struct();
    out.action = 'motif';
    out.pattern = pattern;
    out.allowedMismatches = allowedMismatch;
    out.matchCount = numel(positions);
    out.positions = positions;
    out.matchedSubstrings = matched;
end

function out = act_stats(opts)
    seq = opts.seq;
    n = numel(seq);
    counts = count_bases(seq);
    gc = 100 * (counts.G + counts.C) / max(1, n);
    at = 100 * (counts.A + counts.T) / max(1, n);
    mw = counts.A*331.2 + counts.T*322.2 + counts.G*347.2 + counts.C*307.2;
    % Wallace rule Tm
    if n < 14
        tm = 2*(counts.A + counts.T) + 4*(counts.G + counts.C);
    else
        % GC-based formula
        tm = 64.9 + 41 * (counts.G + counts.C - 16.4) / n;
    end
    % Di-nucleotide frequencies
    diCounts = struct();
    bases = 'ATGC';
    totalDi = max(0, n - 1);
    for b1 = bases
        for b2 = bases
            key = [b1, b2];
            cnt = 0;
            for k = 1:totalDi
                if seq(k:k+1) == key
                    cnt = cnt + 1;
                end
            end
            diCounts.(key) = cnt;
        end
    end
    out = struct();
    out.action = 'stats';
    out.sequence = seq;
    out.length = n;
    out.gcContent = gc;
    out.atContent = at;
    out.counts = counts;
    out.molecularWeight_Da = mw;
    out.meltingTemp_C = tm;
    out.diNucleotideCounts = diCounts;
end

% =================== Helpers ===================
function c = complement(seq)
    % DNA complement (preserves case for unknown chars)
    c = seq;
    for i = 1:numel(seq)
        switch seq(i)
            case 'A', c(i) = 'T';
            case 'T', c(i) = 'A';
            case 'G', c(i) = 'C';
            case 'C', c(i) = 'G';
            case 'a', c(i) = 't';
            case 't', c(i) = 'a';
            case 'g', c(i) = 'c';
            case 'c', c(i) = 'a';
            otherwise, c(i) = seq(i);
        end
    end
end

function counts = count_bases(seq)
    counts = struct('A',0,'T',0,'G',0,'C',0,'N',0,'other',0);
    for i = 1:numel(seq)
        switch seq(i)
            case 'A', counts.A = counts.A + 1;
            case 'T', counts.T = counts.T + 1;
            case 'G', counts.G = counts.G + 1;
            case 'C', counts.C = counts.C + 1;
            case 'N', counts.N = counts.N + 1;
            otherwise, counts.other = counts.other + 1;
        end
    end
end

function aa = codon_to_aa(codon)
    % Standard genetic code (table 1)
    switch codon
        case {'TTT','TTC'}, aa = 'F';
        case {'TTA','TTG','CTT','CTC','CTA','CTG'}, aa = 'L';
        case {'TCT','TCC','TCA','TCG','AGT','AGC'}, aa = 'S';
        case {'TAT','TAC'}, aa = 'Y';
        case {'TAA','TAG','TGA'}, aa = '*';
        case {'TGT','TGC'}, aa = 'C';
        case {'TGG'}, aa = 'W';
        case {'CCT','CCC','CCA','CCG'}, aa = 'P';
        case {'CAT','CAC'}, aa = 'H';
        case {'CAA','CAG'}, aa = 'Q';
        case {'CGT','CGC','CGA','CGG','AGA','AGG'}, aa = 'R';
        case {'ATT','ATC','ATA'}, aa = 'I';
        case {'ATG'}, aa = 'M';
        case {'ACT','ACC','ACA','ACG'}, aa = 'T';
        case {'AAT','AAC'}, aa = 'N';
        case {'AAA','AAG'}, aa = 'K';
        case {'GTT','GTC','GTA','GTG'}, aa = 'V';
        case {'GCT','GCC','GCA','GCG'}, aa = 'A';
        case {'GAT','GAC'}, aa = 'D';
        case {'GAA','GAG'}, aa = 'E';
        case {'GGT','GGC','GGA','GGG'}, aa = 'G';
        otherwise, aa = '?';
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
