function cli_text(action, varargin)
% CLI_TEXT Text processing and analysis for ml CLI
%   CLI: ml text tokenize  --input "hello world from matlab"
%         ml text stats    --input "the quick brown fox jumps over the lazy dog"
%         ml text regex    --input "phone: 555-1234, zip: 94040" --pattern "(\d+)-(\d+)"
%         ml text sentiment --input "this product is amazing and wonderful"
%         ml text keywords --input "matlab is great. matlab rocks. matlab forever." --top 3
%         ml text ngrams   --input "the quick brown fox jumps" --n 2
%
%   Options:
%     --input STR     input text (quoted)
%     --file PATH     read text from file
%     --pattern REGEX regular expression pattern
%     --top N         number of top keywords (default 5)
%     --n N           n-gram size (default 2)
%     --stopwords BOOL include common english stop words (default false)
%     --format json|table|csv

    if nargin < 1, error('ml text <action> [options]'); end

    opts = struct('format','json','input','','file','','pattern','','top',5,'n',2, ...
                  'stopwords',false);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--input',     opts.input = varargin{i+1}; i=i+2;
            case '--file',      opts.file = varargin{i+1}; i=i+2;
            case '--pattern',   opts.pattern = varargin{i+1}; i=i+2;
            case '--top',       opts.top = round(parse_num(varargin{i+1})); i=i+2;
            case '--n',         opts.n = round(parse_num(varargin{i+1})); i=i+2;
            case '--stopwords', opts.stopwords = parse_bool(varargin{i+1}); i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    % Resolve input text
    text = opts.input;
    if ~isempty(opts.file)
        fid = fopen(opts.file, 'r');
        if fid < 0, error('cannot open file: %s', opts.file); end
        text = fread(fid, '*char')';
        fclose(fid);
    end

    try
        switch lower(action)
            case 'tokenize',  out = act_tokenize(text, opts);
            case 'stats',     out = act_stats(text, opts);
            case 'regex',     out = act_regex(text, opts);
            case 'sentiment', out = act_sentiment(text, opts);
            case 'keywords',  out = act_keywords(text, opts);
            case 'ngrams',    out = act_ngrams(text, opts);
            otherwise,        error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_tokenize(text, opts)
    % Lowercase, strip punctuation, split on whitespace
    cleaned = lower(regexprep(text, '[^a-zA-Z0-9\s]', ''));
    tokens = strsplit(strtrim(cleaned));
    tokens = tokens(~cellfun('isempty', tokens));
    out = struct();
    out.action = 'tokenize';
    out.tokenCount = numel(tokens);
    out.uniqueTokens = numel(unique(tokens));
    out.tokens = tokens;
end

function out = act_stats(text, opts)
    words = strsplit(strtrim(regexprep(text, '\s+', ' ')));
    words = words(~cellfun('isempty', words));
    sentences = regexp(text, '[.!?]+', 'split');
    sentences = sentences(~cellfun(@(s) isempty(strtrim(s)), sentences));
    % Syllable count (rough estimate via vowel groups)
    syllableCount = 0;
    for w = 1:numel(words)
        vowels = numel(regexpi(words{w}, '[aeiouy]+'));
        syllableCount = syllableCount + max(1, vowels);
    end
    charCount = numel(text);
    charNoSpaces = numel(regexprep(text, '\s', ''));
    out = struct();
    out.action = 'stats';
    out.wordCount = numel(words);
    out.sentenceCount = numel(sentences);
    out.syllableCount = syllableCount;
    out.charCount = charCount;
    out.charCountNoSpaces = charNoSpaces;
    out.avgWordLength = mean(cellfun(@numel, words));
    out.avgWordsPerSentence = numel(words) / max(1, numel(sentences));
    % Flesch reading ease
    if numel(words) > 0
        out.fleschReadingEase = 206.835 - 1.015 * (numel(words)/max(1,numel(sentences))) ...
                                - 84.6 * (syllableCount/numel(words));
    else
        out.fleschReadingEase = NaN;
    end
end

function out = act_regex(text, opts)
    if isempty(opts.pattern), error('--pattern required for regex action'); end
    matches = regexp(text, opts.pattern, 'match');
    tokens = regexp(text, opts.pattern, 'tokens');
    out = struct();
    out.action = 'regex';
    out.pattern = opts.pattern;
    out.matchCount = numel(matches);
    out.matches = matches;
    if ~isempty(tokens)
        out.tokenGroups = tokens;
    end
end

function out = act_sentiment(text, opts)
    % Simple lexicon-based sentiment (no toolbox dependency)
    posWords = {'good','great','excellent','amazing','wonderful','best','love', ...
                'like','awesome','fantastic','perfect','happy','beautiful', ...
                'brilliant','superb','outstanding','positive','win','success'};
    negWords = {'bad','terrible','awful','worst','hate','dislike','horrible', ...
                'poor','ugly','disgusting','negative','fail','failure','sad', ...
                'angry','disappointed','boring','stupid','wrong'};
    cleaned = lower(regexprep(text, '[^a-zA-Z\s]', ''));
    tokens = strsplit(strtrim(cleaned));
    tokens = tokens(~cellfun('isempty', tokens));
    posCount = sum(cellfun(@(t) any(strcmp(posWords, t)), tokens));
    negCount = sum(cellfun(@(t) any(strcmp(negWords, t)), tokens));
    score = posCount - negCount;
    if score > 0, sentiment = 'positive';
    elseif score < 0, sentiment = 'negative';
    else, sentiment = 'neutral'; end
    out = struct();
    out.action = 'sentiment';
    out.tokenCount = numel(tokens);
    out.positiveWords = posCount;
    out.negativeWords = negCount;
    out.score = score;
    out.sentiment = sentiment;
end

function out = act_keywords(text, opts)
    % TF-based keyword extraction (no IDF since single doc)
    stopList = {'the','a','an','and','or','but','is','are','was','were','be', ...
                'to','of','in','on','at','for','with','by','from','as','this', ...
                'that','it','its','has','have','had','not','no','do','does','did'};
    cleaned = lower(regexprep(text, '[^a-zA-Z\s]', ''));
    tokens = strsplit(strtrim(cleaned));
    tokens = tokens(~cellfun('isempty', tokens));
    if opts.stopwords
        keep = true(size(tokens));
        for i = 1:numel(tokens)
            if any(strcmp(stopList, tokens{i})) || strlength(tokens{i}) < 3
                keep(i) = false;
            end
        end
        tokens = tokens(keep);
    end
    [uniqueTok, ~, idx] = unique(tokens);
    counts = accumarray(idx, 1);
    [~, sortIdx] = sort(counts, 'descend');
    topN = min(opts.top, numel(uniqueTok));
    kw = cell(topN, 1);
    ct = zeros(topN, 1);
    for i = 1:topN
        kw{i} = uniqueTok{sortIdx(i)};
        ct(i) = counts(sortIdx(i));
    end
    out = struct();
    out.action = 'keywords';
    out.totalTokens = numel(tokens);
    out.uniqueTokens = numel(uniqueTok);
    out.keywords = kw;
    out.counts = ct;
end

function out = act_ngrams(text, opts)
    cleaned = lower(regexprep(text, '[^a-zA-Z0-9\s]', ''));
    tokens = strsplit(strtrim(cleaned));
    tokens = tokens(~cellfun('isempty', tokens));
    n = opts.n;
    if numel(tokens) < n
        ngrams = {};
    else
        ngrams = cell(numel(tokens)-n+1, 1);
        for i = 1:(numel(tokens)-n+1)
            ngrams{i} = strjoin(tokens(i:i+n-1), ' ');
        end
    end
    [uniqueNG, ~, idx] = unique(ngrams);
    counts = accumarray(idx, 1);
    [~, sortIdx] = sort(counts, 'descend');
    out = struct();
    out.action = 'ngrams';
    out.n = n;
    out.totalNgrams = numel(ngrams);
    out.uniqueNgrams = numel(uniqueNG);
    out.top = arrayfun(@(k) sprintf('%s (%d)', uniqueNG{sortIdx(k)}, counts(sortIdx(k))), ...
                       1:min(10,numel(uniqueNG)), 'UniformOutput', false);
end

% =================== Helpers ===================
function v = parse_num(s)
    if isnumeric(s), v = s; else, v = str2double(s); end
end

function b = parse_bool(s)
    if islogical(s), b = s;
    elseif ischar(s) || isstring(s)
        b = any(strcmpi(s, {'1','true','yes','on'}));
    else
        b = logical(s);
    end
end

function print_output(out, fmt)
    switch lower(fmt)
        case 'json',  jsonify(out);
        case 'table', to_table(out);
        case 'csv',   to_csv(out);
        otherwise,    jsonify(out);
    end
end
