function cli_sensor(action, varargin)
% CLI_SENSOR Sensor fusion and tracking for ml CLI
%   CLI: ml sensor ekf  [--model constvel] [--steps 50] [--noise 0.1]
%         ml sensor ukf  [same as ekf]
%         ml sensor imu   --accel "..." --gyro "..." --samplerate 100
%         ml sensor track --detections FILE.json
%         ml sensor rac   --freq 10 --range 1000 --rcs -10
%
%   Options:
%     --model NAME      constvel|constacc (default constvel)
%     --steps N         number of time steps (default 50)
%     --noise V         measurement noise variance (default 1.0)
%     --measurements X  measurements as csv (auto-generated if omitted)
%     --accel "x,y,z,..." accelerometer readings
%     --gyro "x,y,z,..."  gyro readings (rad/s)
%     --samplerate Hz   IMU sample rate
%     --freq GHz        radar operating frequency
%     --range m         target range
%     --rcs dBsm        target radar cross section
%     --format json|table|csv

    if nargin < 1, error('ml sensor <action> [options]'); end

    opts = struct('format','json','model','constvel','steps',50,'noise',1.0, ...
                  'samplerate',100,'freq',10,'range',1000,'rcs',-10);
    i = 1;
    while i <= numel(varargin)
        tok = varargin{i};
        switch tok
            case '--model',        opts.model = varargin{i+1}; i=i+2;
            case '--steps',        opts.steps = round(parse_num(varargin{i+1})); i=i+2;
            case '--noise',        opts.noise = parse_num(varargin{i+1}); i=i+2;
            case '--measurements', opts.measurements = parse_vec(varargin{i+1}); i=i+2;
            case '--accel',        opts.accel = parse_vec(varargin{i+1}); i=i+2;
            case '--gyro',         opts.gyro = parse_vec(varargin{i+1}); i=i+2;
            case '--samplerate',   opts.samplerate = parse_num(varargin{i+1}); i=i+2;
            case '--freq',         opts.freq = parse_num(varargin{i+1}); i=i+2;
            case '--range',        opts.range = parse_num(varargin{i+1}); i=i+2;
            case '--rcs',          opts.rcs = parse_num(varargin{i+1}); i=i+2;
            case '--detections',   opts.detections = varargin{i+1}; i=i+2;
            case '--format',       opts.format = varargin{i+1}; i=i+2;
            otherwise,             i=i+1;
        end
    end

    if ~exist('trackingEKF','file')
        error('Sensor Fusion and Tracking Toolbox not available');
    end

    try
        switch lower(action)
            case 'ekf',  out = act_ekf(opts);
            case 'ukf',  out = act_ukf(opts);
            case 'imu',  out = act_imu(opts);
            case 'track',out = act_track(opts);
            case 'rac',  out = act_rac(opts);
            otherwise,   error('unknown action: %s', action);
        end
        print_output(out, opts.format);
    catch ME
        fprintf(2, 'ERROR: %s\n', ME.message);
        quit(1);
    end
end

% =================== Actions ===================
function out = act_ekf(opts)
    % EKF for 3D tracking
    [trueStates, measurements, dt] = generate_trajectory(opts);
    filter = trackingEKF(@constvel, @cvmeas, ...
        trueStates(1,:), 'ProcessNoise', 0.1*eye(6), ...
        'MeasurementNoise', eye(3)*opts.noise);
    estStates = zeros(opts.steps, 6);
    for k = 1:opts.steps
        predict(filter, dt);
        if size(measurements,1) >= k
            estStates(k,:) = correct(filter, measurements(k,:))';
        else
            estStates(k,:) = filter.State';
        end
    end
    posEst = estStates(:,[1 3 5]);
    posTrue = trueStates(:,[1 3 5]);
    mse = mean(sum((posEst - posTrue).^2, 2));
    out = struct();
    out.filter = 'EKF';
    out.model = opts.model;
    out.numSteps = opts.steps;
    out.dt = dt;
    out.estimatedStates = estStates;
    out.trueStates = trueStates;
    out.measurements = measurements;
    out.positionRMSE = sqrt(mse);
    out.finalState = estStates(end,:);
end

function out = act_ukf(opts)
    [trueStates, measurements, dt] = generate_trajectory(opts);
    filter = trackingUKF(@constvel, @cvmeas, ...
        trueStates(1,:), 'ProcessNoise', 0.1*eye(6), ...
        'MeasurementNoise', eye(3)*opts.noise);
    estStates = zeros(opts.steps, 6);
    for k = 1:opts.steps
        predict(filter, dt);
        if size(measurements,1) >= k
            estStates(k,:) = correct(filter, measurements(k,:))';
        else
            estStates(k,:) = filter.State';
        end
    end
    posEst = estStates(:,[1 3 5]);
    posTrue = trueStates(:,[1 3 5]);
    mse = mean(sum((posEst - posTrue).^2, 2));
    out = struct();
    out.filter = 'UKF';
    out.model = opts.model;
    out.numSteps = opts.steps;
    out.dt = dt;
    out.estimatedStates = estStates;
    out.trueStates = trueStates;
    out.measurements = measurements;
    out.positionRMSE = sqrt(mse);
    out.finalState = estStates(end,:);
end

function out = act_imu(opts)
    if ~isfield(opts,'accel') || ~isfield(opts,'gyro')
        error('imu needs --accel "x,y,z,..." and --gyro "x,y,z,..."');
    end
    accel = reshape(opts.accel, 3, []).';
    gyro = reshape(opts.gyro, 3, []).';
    if size(accel,1) ~= size(gyro,1)
        minN = min(size(accel,1), size(gyro,1));
        accel = accel(1:minN,:); gyro = gyro(1:minN,:);
    end
    fuse = imufilter('SampleRate', opts.samplerate);
    [orientation, angularVel] = fuse(accel, gyro);
    out = struct();
    out.numSamples = size(accel,1);
    out.sampleRate = opts.samplerate;
    out.orientationQuaternion = orientation;
    out.angularVelocity = angularVel;
    eul = eulerd(orientation, 'ZYX', 'frame');
    out.meanRoll = mean(eul(:,2));
    out.meanPitch = mean(eul(:,1));
    out.meanYaw = mean(eul(:,3));
end

function out = act_track(opts)
    % Simple multi-target track demo: generate 2 crossing targets
    dt = 0.5;
    numSteps = 20;
    tracks = struct('timeStep',{},'trackID',{},'position',{});
    rng(42);
    for k = 1:numSteps
        % Two targets moving
        pos1 = [k*1.0, k*0.5];
        pos2 = [k*0.8, 10-k*0.3];
        det1 = objectDetection(k, pos1, 'MeasurementNoise', 0.1*eye(2));
        det2 = objectDetection(k, pos2, 'MeasurementNoise', 0.1*eye(2));
        tracks(end+1).timeStep = k; %#ok<AGROW>
        tracks(end).trackID = 1;
        tracks(end).position = pos1;
        tracks(end+1).timeStep = k; %#ok<AGROW>
        tracks(end).trackID = 2;
        tracks(end).position = pos2;
    end
    out = struct();
    out.numSteps = numSteps;
    out.numTargets = 2;
    out.tracks = tracks;
    out.meanPositionT1 = mean(cell2mat({tracks([tracks.timeStep]==1 & [tracks.trackID]==1).position}), 1);
    out.meanPositionT2 = mean(cell2mat({tracks([tracks.timeStep]==1 & [tracks.trackID]==2).position}), 1);
end

function out = act_rac(opts)
    % Radar equation: SNR = Pt * G^2 * λ^2 * σ / ((4π)^3 * R^4 * k * T * B * F * L)
    c = 3e8;
    lambda = c / (opts.freq * 1e9);
    Pt = 1e3;  % 1 kW transmit power
    G = 30;    % 30 dBi antenna gain
    sigma = 10^(opts.rcs/10);  % RCS in m^2
    k = 1.38e-23;
    T = 290;
    B = 1e6;   % 1 MHz bandwidth
    F = 3;     % 3 dB noise figure
    L = 1;     % losses
    snr_lin = Pt * (10^(G/10))^2 * lambda^2 * sigma / ...
              ((4*pi)^3 * opts.range^4 * k * T * B * 10^(F/10) * L);
    snr_dB = 10*log10(snr_lin);
    pd = normcdf(sqrt(2*snr_lin) - norminv(0.9999));
    out = struct();
    out.freq_GHz = opts.freq;
    out.range_m = opts.range;
    out.rcs_dBsm = opts.rcs;
    out.lambda_m = lambda;
    out.snr_dB = snr_dB;
    out.detectionProb = double(pd);
    out.maxRange_m = opts.range;
end

% =================== Helpers ===================
function [states, measurements, dt] = generate_trajectory(opts)
    dt = 0.5;
    N = opts.steps;
    states = zeros(N, 6);  % [x, vx, y, vy, z, vz] for 3D constvel
    states(1,:) = [0, 1.0, 0, 0.5, 0, 0.0];
    for k = 2:N
        states(k,1) = states(k-1,1) + states(k-1,2)*dt;
        states(k,2) = states(k-1,2);
        states(k,3) = states(k-1,3) + states(k-1,4)*dt;
        states(k,4) = states(k-1,4);
        states(k,5) = states(k-1,5) + states(k-1,6)*dt;
        states(k,6) = states(k-1,6);
    end
    % Generate noisy 3D position measurements
    rng(1);
    measurements = states(:,[1 3 5]) + sqrt(opts.noise)*randn(N, 3);
end

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
