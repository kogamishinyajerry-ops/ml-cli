function cli_crypto(action, varargin)
% CLI_CRYPTO Cryptography primitives for ml CLI (native MATLAB, no Java/toolbox)
%   CLI: ml crypto hash    --data "hello" --algo sha256
%         ml crypto base64  --data "hello world" --op encode
%         ml crypto random  --bytes 16 --op hex
%         ml crypto xor     --data "secret" --key "key"
%         ml crypto caesar  --data "hello" --shift 3
%         ml crypto vigenere --data "attackatdawn" --key "lemon"
%
%   Options:
%     --data STR       input data string
%     --algo NAME      hash algorithm: sha256|sha1 (native impl)
%     --op ACTION      encode|decode for base64
%     --bytes N        number of random bytes
%     --key STR        key string (xor / vigenere)
%     --shift N        shift for caesar cipher
%     --format json|table|csv

    if nargin < 1, error('ml crypto <action> [options]'); end

    opts = struct('format','json','data','','algo','sha256','op','encode', ...
                  'bytes',32,'key','','shift',3);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--data',   opts.data = varargin{i+1}; i=i+2;
            case '--algo',   opts.algo = lower(varargin{i+1}); i=i+2;
            case '--op',     opts.op = lower(varargin{i+1}); i=i+2;
            case '--bytes',  opts.bytes = round(parse_num(varargin{i+1})); i=i+2;
            case '--key',    opts.key = varargin{i+1}; i=i+2;
            case '--shift',  opts.shift = round(parse_num(varargin{i+1})); i=i+2;
            case '--format', opts.format = varargin{i+1}; i=i+2;
            otherwise,       i=i+1;
        end
    end

    try
        switch lower(action)
            case 'hash',    out = act_hash(opts);
            case 'base64',  out = act_base64(opts);
            case 'random',  out = act_random(opts);
            case 'xor',     out = act_xor(opts);
            case 'caesar',  out = act_caesar(opts);
            case 'vigenere',out = act_vigenere(opts);
            otherwise,      error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_hash(opts)
    data = uint8(opts.data);
    algo = opts.algo;
    switch algo
        case 'sha256'
            hexStr = sha256_native(data);
            algoLabel = 'SHA-256';
        case 'sha1'
            hexStr = sha1_native(data);
            algoLabel = 'SHA-1';
        otherwise
            error('unknown algo: %s (sha256|sha1)', algo);
    end
    out = struct();
    out.action = 'hash';
    out.algorithm = algoLabel;
    out.inputLength = numel(data);
    out.hash = hexStr;
end

function out = act_base64(opts)
    data = opts.data;
    op = opts.op;
    switch op
        case 'encode'
            bytes = uint8(data);
            encoded = matlab.net.base64encode(bytes);
            out = struct();
            out.action = 'base64';
            out.op = 'encode';
            out.inputLength = numel(data);
            out.encoded = char(encoded);
        case 'decode'
            decoded = matlab.net.base64decode(string(data));
            decodedBytes = uint8(decoded);
            text = char(decodedBytes);
            out = struct();
            out.action = 'base64';
            out.op = 'decode';
            out.inputLength = numel(data);
            out.decoded = text;
            out.decodedBytes = numel(decodedBytes);
        otherwise
            error('unknown op: %s (encode|decode)', op);
    end
end

function out = act_random(opts)
    n = opts.bytes;
    if n <= 0, error('bytes must be positive'); end
    rng_state = rng('shuffle');
    bytes = uint8(randi([0,255], 1, n));
    rng(rng_state);
    hexStr = lower(reshape(dec2hex(bytes, 2).', 1, []));
    b64 = matlab.net.base64encode(bytes);
    out = struct();
    out.action = 'random';
    out.nBytes = n;
    out.hex = hexStr;
    out.base64 = char(b64);
    out.note = 'MATLAB PRNG (not cryptographic-grade)';
end

function out = act_xor(opts)
    data = uint8(opts.data);
    key = uint8(opts.key);
    if isempty(key), error('--key required'); end
    keyIdx = mod(0:numel(data)-1, numel(key)) + 1;
    keyExpanded = key(keyIdx);
    cipher = bitxor(data, keyExpanded);
    hexStr = lower(reshape(dec2hex(cipher, 2).', 1, []));
    out = struct();
    out.action = 'xor';
    out.inputLength = numel(data);
    out.keyLength = numel(key);
    out.ciphertextHex = hexStr;
    out.note = 'XOR cipher (insecure, demo only)';
end

function out = act_caesar(opts)
    data = upper(opts.data);
    shift = opts.shift;
    result = '';
    for i = 1:numel(data)
        c = data(i);
        if c >= 'A' && c <= 'Z'
            newC = char(mod(double(c) - double('A') + shift, 26) + double('A'));
            result = [result, newC];
        else
            result = [result, c];
        end
    end
    out = struct();
    out.action = 'caesar';
    out.inputLength = numel(data);
    out.shift = shift;
    out.result = result;
end

function out = act_vigenere(opts)
    data = upper(opts.data);
    key = upper(regexprep(opts.key, '[^A-Z]', ''));
    if isempty(key), error('--key requires letters'); end
    result = '';
    keyIdx = 1;
    for i = 1:numel(data)
        c = data(i);
        if c >= 'A' && c <= 'Z'
            shift = double(key(keyIdx)) - double('A');
            newC = char(mod(double(c) - double('A') + shift, 26) + double('A'));
            result = [result, newC];
            keyIdx = mod(keyIdx, numel(key)) + 1;
        else
            result = [result, c];
        end
    end
    out = struct();
    out.action = 'vigenere';
    out.inputLength = numel(data);
    out.key = key;
    out.result = result;
end

% =================== Native SHA-256 ===================
function hexStr = sha256_native(msg)
    % SHA-256 per FIPS 180-4. Uses double + mod 2^32 (uint32 saturates).
    K = [1116352408, 1899447441, 3049323471, 3921009573, 961987163, ...
         1508970993, 2453635748, 2870763221, 3624381080, 310598401, ...
         607225278, 1426881987, 1925078388, 2162078206, 2614888103, ...
         3248222580, 3835390401, 4022224774, 264347078, 604807628, ...
         770255983, 1249150122, 1555081692, 1996064986, 2554220882, ...
         2821834349, 2952996808, 3210313671, 3336571891, 3584528711, ...
         113926993, 338241895, 666307205, 773529912, 1294757372, ...
         1396182291, 1695183700, 1986661051, 2177026350, 2456956037, ...
         2730485921, 2820302411, 3259730800, 3345764771, 3516065817, ...
         3600352804, 4094571909, 275423344, 430227734, 506948616, ...
         659060556, 883997877, 958139571, 1322822218, 1537002063, ...
         1747873779, 1955562222, 2024104815, 2227730452, 2361852424, ...
         2428436474, 2756734187, 3204031479, 3329325298];

    H = [1779033703, 3144134277, 1013904242, 2773480762, ...
         1359893119, 2600822924, 528734635, 1541459225];

    % Padding
    lenBits = uint64(numel(msg) * 8);
    msg = [msg, uint8(128)];
    while mod(numel(msg), 64) ~= 56
        msg = [msg, uint8(0)];
    end
    lenBytesLE = typecast(lenBits, 'uint8');
    lenBytes = lenBytesLE(end:-1:1);
    msg = [msg, lenBytes];

    MOD = 2^32;

    for blk = 1:64:numel(msg)
        block = msg(blk:blk+63);
        W = zeros(1, 64);
        for j = 0:15
            b = block(4*j+1:4*j+4);
            W(j+1) = double(b(1))*2^24 + double(b(2))*2^16 + double(b(3))*2^8 + double(b(4));
        end
        for j = 17:64
            s0 = bx(bx(ror(W(j-15), 7), ror(W(j-15), 18)), bs(W(j-15), -3));
            s1 = bx(bx(ror(W(j-2), 17), ror(W(j-2), 19)), bs(W(j-2), -10));
            W(j) = mod(W(j-16) + W(j-7) + s0 + s1, MOD);
        end
        a = H(1); b = H(2); c = H(3); d = H(4);
        e = H(5); f = H(6); g = H(7); h = H(8);
        for j = 1:64
            S1 = bx(bx(ror(e, 6), ror(e, 11)), ror(e, 25));
            ch = bx(ba(e, f), ba(bc(e), g));
            temp1 = mod(h + S1 + ch + K(j) + W(j), MOD);
            S0 = bx(bx(ror(a, 2), ror(a, 13)), ror(a, 22));
            maj = bx(bx(ba(a, b), ba(a, c)), ba(b, c));
            temp2 = mod(S0 + maj, MOD);
            h = g; g = f; f = e;
            e = mod(d + temp1, MOD);
            d = c; c = b; b = a;
            a = mod(temp1 + temp2, MOD);
        end
        H(1) = mod(H(1) + a, MOD); H(2) = mod(H(2) + b, MOD);
        H(3) = mod(H(3) + c, MOD); H(4) = mod(H(4) + d, MOD);
        H(5) = mod(H(5) + e, MOD); H(6) = mod(H(6) + f, MOD);
        H(7) = mod(H(7) + g, MOD); H(8) = mod(H(8) + h, MOD);
    end
    hexStr = lower(reshape(dec2hex(uint32(H), 8).', 1, []));
end

% =================== Native SHA-1 ===================
function hexStr = sha1_native(msg)
    % SHA-1 per FIPS 180-4. Uses double + mod 2^32.
    H = [1732584193, 4023233417, 2562383102, 271733878, 3285377520];

    lenBits = uint64(numel(msg) * 8);
    msg = [msg, uint8(128)];
    while mod(numel(msg), 64) ~= 56
        msg = [msg, uint8(0)];
    end
    lenBytesLE = typecast(lenBits, 'uint8');
    lenBytes = lenBytesLE(end:-1:1);
    msg = [msg, lenBytes];

    MOD = 2^32;

    for blk = 1:64:numel(msg)
        block = msg(blk:blk+63);
        W = zeros(1, 80);
        for j = 0:15
            b = block(4*j+1:4*j+4);
            W(j+1) = double(b(1))*2^24 + double(b(2))*2^16 + double(b(3))*2^8 + double(b(4));
        end
        for j = 17:80
            W(j) = rol(bx(bx(bx(W(j-3), W(j-8)), bx(W(j-14), W(j-16))), 0), 1);
        end
        a = H(1); b = H(2); c = H(3); d = H(4); e = H(5);
        for j = 1:80
            if j <= 20
                f = bx(ba(b, c), ba(bc(b), d));
                k = 1518500249;
            elseif j <= 40
                f = bx(bx(b, c), d);
                k = 1859775393;
            elseif j <= 60
                f = bx(bx(ba(b, c), ba(b, d)), ba(c, d));
                k = 2400959708;
            else
                f = bx(bx(b, c), d);
                k = 3395469782;
            end
            temp = mod(rol(a, 5) + f + e + k + W(j), MOD);
            e = d; d = c; c = rol(b, 30); b = a; a = temp;
        end
        H(1) = mod(H(1) + a, MOD); H(2) = mod(H(2) + b, MOD);
        H(3) = mod(H(3) + c, MOD); H(4) = mod(H(4) + d, MOD);
        H(5) = mod(H(5) + e, MOD);
    end
    hexStr = lower(reshape(dec2hex(uint32(H), 8).', 1, []));
end

% =================== Double-based bit ops (values mod 2^32) ===================
function r = ror(x, n)
    x = mod(x, 2^32);
    r = mod(floor(x / 2^n) + mod(x, 2^n) * 2^(32-n), 2^32);
end

function r = rol(x, n)
    x = mod(x, 2^32);
    r = mod(mod(x, 2^(32-n)) * 2^n + floor(x / 2^(32-n)), 2^32);
end

function r = bs(x, n)
    x = mod(x, 2^32);
    if n >= 0
        r = mod(floor(x * 2^n), 2^32);
    else
        r = floor(x / 2^-n);
    end
end

function r = ba(a, b)
    r = double(bitand(uint32(mod(a, 2^32)), uint32(mod(b, 2^32))));
end

function r = bo(a, b)
    r = double(bitor(uint32(mod(a, 2^32)), uint32(mod(b, 2^32))));
end

function r = bx(a, b)
    r = double(bitxor(uint32(mod(a, 2^32)), uint32(mod(b, 2^32))));
end

function r = bc(x)
    r = double(bitcmp(uint32(mod(x, 2^32))));
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
