# ml — MATLAB CLI

[![GitHub](https://img.shields.io/badge/repository-GitHub-181717?logo=github)](https://github.com/kogamishinyajerry-ops/ml-cli)
![MATLAB R2026a](https://img.shields.io/badge/MATLAB-R2026a-orange)
![Commands](https://img.shields.io/badge/commands-49-blue)
![License](https://img.shields.io/badge/license-MIT-green)

> **CLI Anything**: 把 MATLAB 变成可组合的 Unix 管道工具。
>
> No GUI. No IDE. Just pipe.

## Quick Start

```bash
export PATH="$HOME/ml-cli/bin:$PATH"

# Basic math
ml eval "1+2*3"              # → 7
ml eval "eig(magic(5))" --json | jq '.'

# Pipeline
echo "1:100" | ml eval "sum(ans)"     # → 5050
ml bench --json | jq '.matrix_multiply_1k'

# Symbolic math
ml sym diff "x^3" --order 2          # → 6*x
ml sym laplace "exp(-t)"             # → 1/(s+1)
ml sym latex "exp(-x^2)"             # → \mathrm{e}^{-x^2}

# LTI control system
ml lti info    --tf "[1] / [1 0.5 1]"          # stability, DC gain
ml lti bode    --tf "[10] / [1 1 100]" --plot bode.png
ml lti margin  --tf "[1] / [1 2 5 1]" --json

# Curve fitting
ml fit poly   --degree 2 --xy "0,0,1,1,2,4,3,9" --json
ml fit custom --model "a*sin(b*x)+c" --params "a,b,c" --start "1,1,0" --xy "0,1,1,2,2,3"

# Fuzzy inference (full Mamdani system)
ml fuzzy newfis  --name tipper
ml fuzzy addvar  --name tipper --var service --range "[0 10]" --type input
ml fuzzy addmf   --name tipper --var service --mf "poor:gaussmf:[1.5 0]"
ml fuzzy addrule --name tipper --rules "1,1,1,1,1; 2,0,2,1,1; 3,2,3,1,1"
ml fuzzy eval    --name tipper --inputs "5,5"   # → 15

# Animation
ml animate func  --expr "sin(x-0.5*t)" --xrange "[0 10]" --trange "[0 20]" --out wave.gif
ml animate trace --xexpr "cos(t)" --yexpr "sin(t)" --trange "[0 2*pi]" --out circle.mp4

# Graph analysis
ml graph shortest  --edges "1-2,2-3,3-4,4-1,1-3" --from 1 --to 4 --json
ml graph pagerank  --diedges "1-2,1-3,2-3,3-1,3-4" --top 3

# Wavelet denoising
ml wavelet families                       # list 13 wavelet families
ml wavelet denoise --signal "$SIG" --wavelet db4 --level 3 --threshold -1
```

## Commands (49)

### Core

| Command | Description | JSON | TABLE | CSV |
|---------|-------------|------|-------|-----|
| `ml eval "expr"` | Evaluate expression | ✓ | ✓ | ✓ |
| `ml run script.m` | Execute script | — | — | — |
| `ml plot "cmd"` | Generate plot | — | — | — |
| `ml doc "fn"` | Show MATLAB help | — | — | — |
| `ml repl` | Interactive REPL | — | — | — |
| `ml watch -n 2 "cmd"` | Polling repeat | — | — | — |
| `ml ls [dir]` | List .m/.mat files | — | — | — |
| `ml diff a.m b.m` | Diff scripts | — | — | — |
| `ml info` | Environment | ✓ | ✓ | — |
| `ml bench` | Performance | ✓ | ✓ | — |
| `ml profile script.m` | Profile | ✓ | ✓ | — |
| `ml lint file.m` | Code style | — | — | — |
| `ml fmt file.m` | Format | — | — | — |
| `ml help [cmd]` | Help | — | — | — |

### Data & Files

| Command | Description | JSON | TABLE | CSV |
|---------|-------------|------|-------|-----|
| `ml mat <act> f.mat` | .mat file ops (list/info/export/merge/compare) | ✓ | ✓ | ✓ |
| `ml export f.mat` | Export to csv/json/txt | ✓ | — | ✓ |
| `ml convert v from to` | Unit conversion (40+ units) | — | — | — |
| `ml new project` | Create scaffold | — | — | — |
| `ml template type [name]` | Generate code template (9 types) | — | — | — |
| `ml test [dir]` | Run unit tests | — | — | — |
| `ml skills [phase]` | List matlab-skills scripts | — | — | — |

### Engineering

| Command | Description | Toolbox | JSON |
|---------|-------------|---------|------|
| `ml sym <op> "expr"` | Symbolic math (12 ops) | Symbolic Math | ✓ |
| `ml lti <act> --tf` | LTI systems (7 actions) | Control System | ✓ |
| `ml graph <act> --edges` | Graph analysis (6 actions) | Base MATLAB | ✓ |
| `ml fit <act> --xy` | Curve fitting (5 methods) | Curve Fitting | ✓ |
| `ml solve --ode NAME` | ODE solver (vanderpol/lorenz/lotka) | Base MATLAB | ✓ |
| `ml optimize --problem` | Optimization | Base MATLAB | ✓ |
| `ml signal file` | Signal analysis (--fft/--psd/--filter) | Signal Processing | ✓ |
| `ml image file` | Image processing (--gray/--edge/...) | Image Processing | ✓ |
| `ml control "tf"` | Control (legacy) | Control System | — |
| `ml aero --alt H` | Aerospace (ISA/Mach) | Aerospace | — |
| `ml pde <act> --geom` | PDE solver (heat/wave/poisson) | Base MATLAB | ✓ |
| `ml sysid <act> --y` | System identification (arx/ss/tfest) | System ID | ✓ |
| `ml sensor <act> --meas` | Sensor fusion (EKF/UKF/IMU/radar) | Sensor Fusion | ✓ |
| `ml antenna <act> --type` | Antenna design (dipole/patch/array) | Antenna | ✓ |
| `ml robot <act> --dh` | Robotics (DH/FK/IK/Jacobian/traj) | Robotics System | ✓ |
| `ml vehicle <act>` | Vehicle dynamics (bicycle/Pacejka) | Base MATLAB | ✓ |
| `ml audio <act> <file>` | Audio analysis (pitch/formant/spectrogram) | Audio | ✓ |
| `ml lidar <act> <cloud>` | Point cloud (segment/cluster/fit) | Lidar | ✓ |

### Advanced

| Command | Description | Toolbox | JSON |
|---------|-------------|---------|------|
| `ml par [--info/--bench/--gpu]` | Parallel computing | Parallel Computing | ✓ |
| `ml stats data.csv` | Descriptive statistics | Statistics | ✓ |
| `ml animate <act> --expr` | GIF/MP4 animation (3 modes) | Base MATLAB | ✓ |
| `ml wavelet <act> --signal` | Wavelet analysis (5 actions) | Wavelet | ✓ |
| `ml fuzzy <act> --name` | Fuzzy inference (7 actions) | Fuzzy Logic | ✓ |
| `ml dnn <act>` | Deep learning inference (14 nets) | Deep Learning | ✓ |
| `ml sim <act> --model` | Simulink batch (run/linearize) | Simulink | ✓ |
| `ml codegen <act> --file` | MATLAB Coder (C/MEX) | MATLAB Coder | ✓ |
| `ml cv <act> <img>` | Computer vision (features/match/track) | Computer Vision | ✓ |

## Command Details

### `ml lti` — LTI System Analysis

```bash
ml lti info     --tf "[1] / [1 0.5 1]"               # order, stability, DC gain
ml lti poles    --tf "[1] / [1 0.5 1]"               # ωn, ζ, damping
ml lti step     --tf "..." --tfinal 30               # peak/settling/rise time
ml lti bode     --tf "..." --wmin 0.01 --wmax 10     # magnitude/phase/margin
ml lti nyquist  --tf "..." --wmin 0.1 --wmax 10      # real/imag contour
ml lti margin   --tf "..."                           # GM/PM, crossover freqs
ml lti roots    --tf "..."                           # characteristic roots

# System spec formats
--tf "[1 2] / [1 3 5]"                              # transfer function
--zpk "z:[0,-1] p:[-2,-3] k:2"                      # zeros/poles/gain

# Options
--plot out.png    # export plot (headless)
--format json|table|csv
```

### `ml graph` — Graph/Network Analysis

```bash
ml graph info        --edges "1-2,2-3,3-4,4-1,1-3"    # nodes, edges, diameter
ml graph shortest    --edges "..." --from 1 --to 4    # path + distance
ml graph mst         --edges "..." --weights "1,5,1"  # min spanning tree
ml graph pagerank    --diedges "1-2,2-3" --alpha 0.85 # centrality
ml graph components  --edges "..." [--weak|--strong]  # connected comps
ml graph degree      --edges "..."                    # degree sequence

# Graph spec
--edges "1-2,2-3"       # undirected
--diedges "1-2,2-3"     # directed
--adj "[0 1;1 0]"        # adjacency matrix
```

### `ml fit` — Curve Fitting

```bash
ml fit poly    --degree 2 --xy "0,0,1,1,2,4,3,9"     # coefficients + R² + RMSE
ml fit exp     --xy "0,1,1,2.7,2,7.4"                # y = a*exp(b*x)
ml fit power   --xy "1,1,2,4,3,9"                    # y = a*x^b
ml fit custom  --model "a*sin(b*x)+c" \
                --params "a,b,c" --start "1,1,0" \
                --xy "..."                            # nonlinear regression
ml fit interp  --method spline \
                --xy "0,0,1,1,2,4" --query "0.5,1.5" # interpolation

# Data input formats
--xy "x1,y1,x2,y2,..."           # interleaved (recommended)
--x "x1,x2,..." --y "y1,y2,..."  # separate
--predict "x1,x2,..."            # evaluate fitted model at new points
```

### `ml animate` — Animation Generation

```bash
# Function animation: y = f(x, t)
ml animate func  --expr "sin(x-0.5*t)" \
                 --xrange "[0 10]" --trange "[0 20]" \
                 --frames 30 --fps 10 --out wave.gif

# Parameter sweep: y = f(x, p)
ml animate param --expr "sin(p*x)" \
                 --xrange "[0 6]" --prange "[0.5 3]" --out sweep.gif

# Trajectory: (x(t), y(t))
ml animate trace --xexpr "cos(t)" --yexpr "sin(t)" \
                 --trange "[0 2*pi]" --frames 40 --out circle.mp4

# Output formats
--out file.gif   # animated GIF (imwrite, loop forever)
--out file.mp4   # MPEG-4 video (VideoWriter)
```

### `ml wavelet` — Wavelet Analysis

```bash
ml wavelet families                              # list 13 wavelet families
ml wavelet info     --wavelet db4                # scaling/wavelet functions
ml wavelet dwt      --signal "$SIG" \
                    --wavelet db4 --level 3      # multi-level decomposition
ml wavelet denoise  --signal "$SIG" \
                    --wavelet db4 --threshold -1 # universal threshold (auto)
ml wavelet cwt      --signal "$SIG" \
                    --wavelet morl --scales "1,2,4,8,16"  # continuous WT

# Wavelet families: haar, db(1-10), sym(1-10), coif(1-5), bior, rbio,
#                   dmey, mexh, morl, cgau, shan, fbsp, cmor
```

### `ml fuzzy` — Fuzzy Inference System

Stateful: FIS is persisted in `/tmp/ml_fuzzy_<name>.mat` across CLI calls.

```bash
# Build pipeline
ml fuzzy newfis  --name tipper
ml fuzzy addvar  --name tipper --var service --range "[0 10]" --type input
ml fuzzy addvar  --name tipper --var tip     --range "[0 30]" --type output
ml fuzzy addmf   --name tipper --var service --mf "poor:gaussmf:[1.5 0]"
ml fuzzy addmf   --name tipper --var service --mf "good:gaussmf:[1.5 5]"
ml fuzzy addmf   --name tipper --var tip     --mf "cheap:trimf:[0 5 10]"
ml fuzzy addrule --name tipper --rules "1,1,1,1,1; 2,0,2,1,1; 3,2,3,1,1"

# Query
ml fuzzy eval    --name tipper --inputs "5,5"   # → tip=15
ml fuzzy info    --name tipper                  # variables, MFs, rules
ml fuzzy surface --name tipper --out surf.png   # control surface 3D plot

# MF spec: "name:type:[params]"
#   gaussmf:[sigma mu]   trimf:[a b c]   trapmf:[a b c d]
# Rule row: in_mf1,in_mf2,...,out_mf1,...,weight,operator
#   operator: 1=AND, 2=OR, 0=don't care
```

### `ml sym` — Symbolic Math (12 operations)

```bash
ml sym diff      "x^2"              # → 2*x
ml sym diff      "x^3" --order 2    # → 6*x
ml sym int       "x^2" --at 0 1     # → 1/3
ml sym solve     "x^2-4=0"          # → [-2, 2]
ml sym simplify  "sin(x)^2+cos(x)^2"  # → 1
ml sym expand    "(x+1)^3"
ml sym factor    "x^2-1"
ml sym laplace   "exp(-t)"
ml sym limit     "sin(x)/x" --at 0  # → 1
ml sym taylor    "exp(x)" --order 5
ml sym latex     "exp(-x^2)"
ml sym matrix    "det [[a,b];[c,d]]"  # → a*d-b*c
```

### `ml cv` — Computer Vision

```bash
ml cv features coins.png --det surf --max 100     # SURF keypoints (count + top-N)
ml cv features img.png --det orb                  # ORB keypoints
ml cv match  a.png b.png                          # feature match + homography
ml cv track  frame1.png frame2.png                # KLT point tracker
ml cv stereo left.png right.png                   # stereo disparity map
ml cv detect img.png                              # YOLOv4 (or ACF fallback)
```

### `ml sensor` — Sensor Fusion & Tracking

```bash
ml sensor ekf   --meas track.json --dt 1.0        # Extended Kalman Filter
ml sensor ukf   --meas track.json                 # Unscented Kalman Filter
ml sensor imu   --accel 9.8 --gyro 0.1            # IMU attitude fusion
ml sensor track --meas multi.json                 # multi-object tracker (GNN)
ml sensor rac   --freq 10e9 --rcs 1 --range 1000  # radar equation SNR
```

### `ml sysid` — System Identification

```bash
ml sysid arx     --y y.csv --u u.csv --ts 0.1 --order 2   # ARX polynomial fit
ml sysid ss      --y y.csv --u u.csv --ts 0.1 --order 4   # state-space model
ml sysid tfest   --y y.csv --u u.csv --ts 0.1 --np 2      # transfer function est
ml sysid compare --model m.mat --y y.csv --u u.csv        # fit % + MSE
```

### `ml antenna` — Antenna Design & RF Analysis

```bash
ml antenna dipole  --length 0.15 --freq 1                            # Z, D, HPBW
ml antenna patch   --length 0.045 --width 0.06 --substrate FR4 --freq 2.4
ml antenna array   --type dipole --elements 4 --spacing 0.5 --freq 1  # linear array
ml antenna pattern --type dipole --freq 1 --phi 0 --out polar.png     # radiation pattern
ml antenna sparam  --type dipole --fmin 0.5 --fmax 2 --npts 50        # S11 sweep
ml antenna mesh    --type dipole --freq 1                             # mesh stats
```

### `ml robot` — Robotics

```bash
ml robot dh       --dh "[1 0 0 0; 1 0 0 pi/2; 0.5 0 0 0]"              # build tree
ml robot fk       --dh "..." --q "[0.3 0.5 0.2]"                       # forward kinematics
ml robot jacobian --dh "..." --q "..."                                 # geometric Jacobian
ml robot ik       --dh "..." --target "[1.5 1 0 0 0 90]"               # inverse kinematics
ml robot traj     --q0 "[0 0 0]" --q1 "[pi/2 pi/3 pi/4]" --method quintic
ml robot rpy      --rpy "[10 20 30]"                                   # rotation → rotm/quat
```

### `ml vehicle` — Vehicle Dynamics

```bash
ml vehicle info       --mass 1500 --a 1.2 --b 1.5                      # understeer, Vcr
ml vehicle pacejka    --slip 5 --B 10 --C 1.65 --D 1                   # Magic Formula
ml vehicle steer      --v 20 --delta 0.05 --tfinal 4                   # step steer
ml vehicle lanechange --v 20 --tfinal 8                                # sine-with-dwell
ml vehicle straight   --v 30                                           # eigenvalues
ml vehicle road       --radius 50 --v 15                               # curvature → δ
```

### `ml audio` — Audio Analysis

```bash
ml audio info        speech.wav                                       # file metadata
ml audio spectrogram speech.wav --nfft 1024                           # STFT
ml audio pitch       voice.wav --fmin 80 --fmax 400                   # F0 tracking
ml audio formant     vowel.wav --numformants 3                        # F1/F2/F3 (LPC)
ml audio noise       noisy.wav --method wiener --out clean.wav        # denoise
ml audio synth       --freq 440 --dur 1 --type sine --out tone.wav    # tone synth
```

### `ml lidar` — Point Cloud Processing

```bash
ml lidar info       scan.pcd                                         # point count, bbox
ml lidar downsample scan.pcd --grid 0.1                              # voxel downsample
ml lidar segment    scan.pcd --threshold 0.3                         # ground segmentation
ml lidar cluster    scan.pcd --dist 0.5 --minpoints 10               # euclidean clusters
ml lidar fit        scan.pcd --shape plane --maxdist 0.05            # RANSAC plane fit
ml lidar view       scan.pcd --out plot.png                          # visualize
```

## Pipeline Examples

```bash
# Signal → FFT → peak frequency
ml signal audio.wav --fft --json | jq '.peak_freq'

# Batch processing
for f in data/*.csv; do
  ml eval "mean(readmatrix('$f'))" --json | jq '.[0:3]'
done

# MATLAB → Python pipeline
ml eval --json "eig(magic(5))" | python3 -c "
import json, sys, numpy as np
eigs = np.array(json.load(sys.stdin))
print(f'max eigenvalue: {eigs.real.max():.3f}')"

# Optimization workflow
ml fit poly --degree 3 --xy "$DATA" --json | jq '.rSquared'

# LTI design loop
for zeta in 0.3 0.5 0.7 1.0; do
  den="1 2*${zeta} 1"
  overshoot=$(ml lti step --tf "[1] / [${den}]" --json | jq '.overshoot_pct')
  echo "ζ=$zeta overshoot=${overshoot}%"
done

# Fuzzy system sweep
for s in 1 3 5 7 9; do
  tip=$(ml fuzzy eval --name tipper --inputs "${s},5" --json | jq '.output')
  echo "service=$s → tip=$tip"
done
```

## Architecture

```
ml (bash entry, 1150 lines)
  ├─ forward_to(fn, args...)  ── 通用参数转发器
  │    └─ 把 shell 参数按数字/字符串自动包装后传给 MATLAB 函数
  │
  ├─ run_matlab(code)
  │    └─ addpath('matlab/') → 写 tmp .m → matlab -batch "run('tmp')"
  │
  ├─ Core:    eval / run / plot / doc / repl / watch / ls / diff
  │           info / bench / profile / lint / fmt
  │
  ├─ Data:    mat / export / convert / new / template / test / skills
  │
  ├─ Eng:     sym / lti / graph / fit / solve / optimize
  │           signal / image / control / aero / par / stats
  │
  └─ Advanced: animate / wavelet / fuzzy

matlab/*.m  (25 files)
  ├─ I/O:      jsonify / to_table / to_csv
  ├─ Core:     cli_info / cli_bench / cli_lint / cli_profile / cli_fmt
  ├─ Data:     cli_mat / cli_stats / cli_optimize / cli_ode_solve
  ├─ Eng:      cli_sym / cli_lti / cli_graph / cli_fit
  │           signal_fft / signal_psd / signal_filter
  │           image_info / image_hist
  └─ Advanced: cli_par / cli_animate / cli_wavelet / cli_fuzzy
```

### `forward_to` Helper

The generic argument forwarder (added v0.3.0) lets new commands be added in
~15 lines of bash. It inspects each shell argument:

- **Pure numeric** (`-?[0-9]+(\.[0-9]+)?`) → passed bare to MATLAB
- **Everything else** → quoted as a MATLAB string (with `'` escaped)

This avoids writing a custom bash parser per subcommand; the MATLAB function
uses `inputParser` for real validation.

## Testing

```bash
# Unit tests (fast)
bash scripts/ci-local.sh --fast

# Full CI suite
bash scripts/ci-local.sh --full

# Integration tests (MATLAB+Python)
bash scripts/ci-local.sh --integration

# Manual verification
ml eval "1+1"                      # → 2
ml lti info --tf "[1]/[1 1]" --json | jq '.isStable'
ml graph info --edges "1-2,2-3" --json | jq '.isConnected'
ml fit poly --degree 1 --xy "0,0,1,1" --json | jq '.coefficients'
```

## Requirements

- **MATLAB R2015b+** (tested on R2026a Home Suite)
- **bash** 4.0+ (macOS users: `brew install bash`)
- Optional toolboxes (per command):
  - Control System Toolbox — `ml lti`, `ml control`
  - Curve Fitting Toolbox — `ml fit custom`
  - Wavelet Toolbox — `ml wavelet`
  - Fuzzy Logic Toolbox — `ml fuzzy`
  - Symbolic Math Toolbox — `ml sym`
  - Signal Processing Toolbox — `ml signal`
  - Image Processing Toolbox — `ml image`
  - Parallel Computing Toolbox — `ml par`
  - Statistics & Machine Learning Toolbox — `ml stats`
  - Aerospace Toolbox — `ml aero`

## Documentation

- [`docs/COOKBOOK.md`](docs/COOKBOOK.md) — 50+ CLI recipes
- [`docs/INDEX.md`](docs/INDEX.md) — Cross-reference (m / ml / python)
- [`docs/SKILL_MATLAB_PYTHON.md`](docs/SKILL_MATLAB_PYTHON.md) — MATLAB+Python interop
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Design notes
- [`docs/CI_SETUP.md`](docs/CI_SETUP.md) — GitLab CI/CD runner setup

## Version History

- **v0.3.4** (2026-06-24): `robot`, `vehicle`, `audio`, `lidar` commands.
  4 new engineering modules — robotics (DH kinematics, IK, Jacobian, trajectory),
  vehicle dynamics (bicycle model, Pacejka tire, step/lane-change maneuvers),
  audio (spectrogram, pitch, formants, Wiener denoise, synthesis), and lidar
  point cloud (downsample, ground segmentation, clustering, RANSAC fitting).
  **49 commands total.**
- **v0.3.3** (2026-06-24): `cv`, `sensor`, `sysid`, `antenna` commands.
  4 new engineering modules — computer vision (SURF/ORB/KLT/stereo/YOLO),
  sensor fusion (EKF/UKF/IMU/radar), system identification (ARX/SS/TF), and
  antenna design (dipole/patch/array/pattern/S-params). **45 commands total.**
- **v0.3.2** (2026-06-24): `wavelet` and `fuzzy` commands. 6 new engineering
  modules, full tipper FIS example verified.
- **v0.3.1** (2026-06-24): `lti`, `graph`, `fit`, `animate` commands.
  Generic `forward_to` helper for rapid command addition.
- **v0.3.0** (2026-06-24): `sym` (symbolic math), `par` (parallel), `stats`,
  `optimize`, `solve`, `convert`, `mat`, `doc`, `new`, `template`, `watch`,
  `export`, `test`, `repl`, `ls`, `diff`, `profile`. MATLAB+Python interop.
  GitLab CI/CD pipeline.
- **v0.2.0** (2026-06-24): signal, image, control, aero. JSON/Table/CSV on
  eval. Pipeline stdin support.
- **v0.1.0** (2026-06-24): Initial release. eval, run, plot, lint, info,
  bench, fmt.

## License

MIT
