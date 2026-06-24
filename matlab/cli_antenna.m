function cli_antenna(action, varargin)
% CLI_ANTENNA Antenna design and analysis for ml CLI
%   CLI: ml antenna dipole  --length 0.15 --freq 1
%         ml antenna patch   --length 0.04 --width 0.05 --substrate FR4 --freq 2.4
%         ml antenna array   --type dipole --elements 4 --spacing 0.5 --freq 1
%         ml antenna pattern --type dipole --freq 1 --phi 0 --out polar.png
%         ml antenna sparam  --type dipole --fmin 0.5 --fmax 2 --npts 50
%         ml antenna mesh    --type dipole --freq 1
%
%   Options:
%     --type NAME      dipole|patch (for array/pattern/sparam/mesh)
%     --length m       antenna length
%     --width m        patch width
%     --substrate NAME FR4|RT6010|air (default FR4)
%     --thickness m    substrate thickness
%     --elements N     array element count
%     --spacing LAMBDA element spacing in wavelengths (default 0.5)
%     --freq GHz       operating frequency
%     --phi deg        azimuth cut for pattern (default 0)
%     --fmin GHz       sweep start
%     --fmax GHz       sweep end
%     --npts N         sweep points
%     --out PATH       save plot to file
%     --format json|table|csv

    if nargin < 1, error('ml antenna <action> [options]'); end

    opts = struct('format','json','length',0.15,'width',0.05, ...
                  'substrate','FR4','thickness',1.6e-3,'elements',4, ...
                  'spacing',0.5,'freq',1.0,'phi',0, ...
                  'fmin',0.5,'fmax',2.0,'npts',50,'type','dipole');
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--type',      opts.type = varargin{i+1}; i=i+2;
            case '--length',    opts.length = parse_num(varargin{i+1}); i=i+2;
            case '--width',     opts.width = parse_num(varargin{i+1}); i=i+2;
            case '--substrate', opts.substrate = varargin{i+1}; i=i+2;
            case '--thickness', opts.thickness = parse_num(varargin{i+1}); i=i+2;
            case '--elements',  opts.elements = round(parse_num(varargin{i+1})); i=i+2;
            case '--spacing',   opts.spacing = parse_num(varargin{i+1}); i=i+2;
            case '--freq',      opts.freq = parse_num(varargin{i+1}); i=i+2;
            case '--phi',       opts.phi = parse_num(varargin{i+1}); i=i+2;
            case '--fmin',      opts.fmin = parse_num(varargin{i+1}); i=i+2;
            case '--fmax',      opts.fmax = parse_num(varargin{i+1}); i=i+2;
            case '--npts',      opts.npts = round(parse_num(varargin{i+1})); i=i+2;
            case '--out',       opts.out = varargin{i+1}; i=i+2;
            case '--format',    opts.format = varargin{i+1}; i=i+2;
            otherwise,          i=i+1;
        end
    end

    if ~exist('dipole','class')
        error('Antenna Toolbox not available');
    end

    try
        switch lower(action)
            case 'dipole',  out = act_dipole(opts);
            case 'patch',   out = act_patch(opts);
            case 'array',   out = act_array(opts);
            case 'pattern', out = act_pattern(opts);
            case 'sparam',  out = act_sparam(opts);
            case 'mesh',    out = act_mesh(opts);
            otherwise,      error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Build antenna object ===================
function ant = build_antenna(opts)
    switch lower(opts.type)
        case 'dipole'
            w = min(opts.width, opts.length/10);
            ant = dipole('Length', opts.length, 'Width', w);
        case 'patch'
            d = dielectric(opts.substrate);
            d.Thickness = opts.thickness;
            ant = patchMicrostrip('Length', opts.length, 'Width', opts.width, ...
                'Substrate', d);
        otherwise
            error('unknown antenna type: %s (try dipole|patch)', opts.type);
    end
end

% =================== Actions ===================
function out = act_dipole(opts)
    % Width must be small relative to length (MATLAB constrains < ~Length/5)
    w = min(opts.width, opts.length/10);
    ant = dipole('Length', opts.length, 'Width', w);
    Z = impedance(ant, opts.freq * 1e9);
    out = struct();
    out.type = 'dipole';
    out.length_m = opts.length;
    out.freq_GHz = opts.freq;
    out.impedance_ohm = Z;
    out.resistance_ohm = real(Z);
    out.reactance_ohm = imag(Z);
    out.isResonant = abs(imag(Z)) < 5;
    % Directivity at resonance
    D = pattern(ant, opts.freq * 1e9, 0, 0:5:180);
    out.directivity_dBi = max(D);
    out.beamwidth_deg = beamwidth(ant, opts.freq * 1e9, 0, 0:5:180);
end

function out = act_patch(opts)
    d = dielectric(opts.substrate);
    d.Thickness = opts.thickness;
    ant = patchMicrostrip('Length', opts.length, 'Width', opts.width, 'Substrate', d);
    Z = impedance(ant, opts.freq * 1e9);
    D = pattern(ant, opts.freq * 1e9, 0, 0:5:180);
    out = struct();
    out.type = 'patch';
    out.length_m = opts.length;
    out.width_m = opts.width;
    out.substrate = opts.substrate;
    out.thickness_m = opts.thickness;
    out.freq_GHz = opts.freq;
    out.impedance_ohm = Z;
    out.resistance_ohm = real(Z);
    out.reactance_ohm = imag(Z);
    out.directivity_dBi = max(D);
    out.beamwidth_deg = beamwidth(ant, opts.freq * 1e9, 0, 0:5:180);
end

function out = act_array(opts)
    elem = build_antenna(opts);
    ant = linearArray('Element', elem, 'NumElements', opts.elements, ...
        'ElementSpacing', opts.spacing * 3e8/(opts.freq*1e9));
    % Full 2D scan — single azimuth cut misses the peak of linearArray
    D2 = pattern(ant, opts.freq * 1e9, 0:5:360, -90:2:90);
    D = D2(:);
    out = struct();
    out.type = 'linearArray';
    out.elementType = opts.type;
    out.numElements = opts.elements;
    out.spacing_m = opts.spacing * 3e8/(opts.freq*1e9);
    out.spacing_wavelengths = opts.spacing;
    out.freq_GHz = opts.freq;
    [pk, idx] = max(D);
    [azIdx, elIdx] = ind2sub(size(D2), idx);
    out.directivity_dBi = pk;
    out.peakAz_deg = (azIdx-1)*5;
    out.peakElev_deg = -90 + (elIdx-1)*2;
    out.beamwidth_deg = beamwidth(ant, opts.freq * 1e9, out.peakAz_deg, -90:2:90);
    % Sidelobe level (mask main lobe ±10 samples)
    sideMask = true(size(D));
    sideMask(max(1,idx-20):min(end,idx+20)) = false;
    if any(sideMask)
        out.sidellobeLevel_dB = max(D(sideMask)) - pk;
    end
end

function out = act_pattern(opts)
    ant = build_antenna(opts);
    D = pattern(ant, opts.freq * 1e9, opts.phi, -180:1:180);
    out = struct();
    out.type = opts.type;
    out.freq_GHz = opts.freq;
    out.phi_deg = opts.phi;
    out.theta_deg = -180:180;
    out.directivity_dBi = D;
    out.maxDirectivity_dBi = max(D);
    % HPBW
    [pk, loc] = max(D);
    half = pk - 3;
    above = find(D >= half);
    if ~isempty(above)
        out.HPBW_deg = above(end) - above(1);
    else
        out.HPBW_deg = NaN;
    end
    % F/B ratio: max(directivity in front half) - max(in back half)
    n = numel(D);
    frontMax = max(D(1:floor(n/2)));
    backMax = max(D(floor(n/2)+1:end));
    out.frontToBack_dB = frontMax - backMax;
    if isfield(opts,'out')
        fig = figure('Visible','off');
        polarpattern(ant, opts.freq * 1e9, 'Phi', opts.phi);
        exportgraphics(fig, opts.out); close(fig);
        out.plotFile = opts.out;
    end
end

function out = act_sparam(opts)
    ant = build_antenna(opts);
    freqs = linspace(opts.fmin, opts.fmax, opts.npts) * 1e9;
    s = sparameters(ant, freqs);
    S11 = rfparam(s, 1, 1);
    out = struct();
    out.type = opts.type;
    out.freqStart_GHz = opts.fmin;
    out.freqEnd_GHz = opts.fmax;
    out.numPoints = opts.npts;
    out.freqs_GHz = freqs / 1e9;
    out.S11_dB = 20*log10(abs(S11));
    % Find -10dB bandwidth
    below10dB = find(out.S11_dB < -10);
    if ~isempty(below10dB)
        bw_indices = below10dB(1):below10dB(end);
        out.minS11_dB = min(out.S11_dB(bw_indices));
        out.minS11_freq_GHz = freqs(below10dB(1))/1e9;
        out.bandwidth_GHz = (freqs(below10dB(end)) - freqs(below10dB(1)))/1e9;
        out.resonantFreq_GHz = freqs(below10dB(1) + find(out.S11_dB(below10dB)==min(out.S11_dB(below10dB)),1))/1e9;
    else
        out.minS11_dB = min(out.S11_dB);
        out.bandwidth_GHz = 0;
        out.note = 'No -10dB crossing found';
    end
    if isfield(opts,'out')
        fig = figure('Visible','off');
        rfplot(s);
        exportgraphics(fig, opts.out); close(fig);
        out.plotFile = opts.out;
    end
end

function out = act_mesh(opts)
    ant = build_antenna(opts);
    mesh(ant, 'MaxEdgeLength', 3e8/(opts.freq*1e9)/8);
    m = mesh(ant);
    out = struct();
    out.type = opts.type;
    out.freq_GHz = opts.freq;
    out.numTriangles = size(m.Triangles, 2);
    out.numNodes = size(m.Points, 2);
    out.maxEdgeLength = m.MaxEdgeLength;
    out.minEdgeLength = m.MinEdgeLength;
    out.meshQuality = m.MinimumMeshQuality;
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
