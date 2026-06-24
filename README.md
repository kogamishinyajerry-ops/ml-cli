# ml — MATLAB CLI

[![CI](https://github.com/Zhuanz/ml-cli/actions/workflows/test.yml/badge.svg)](https://github.com/Zhuanz/ml-cli/actions/workflows/test.yml)
[![Integration](https://github.com/Zhuanz/ml-cli/actions/workflows/integration.yml/badge.svg)](https://github.com/Zhuanz/ml-cli/actions/workflows/integration.yml)

> **CLI Anything**: 把 MATLAB 变成可组合的 Unix 管道工具。
>
> No GUI. No IDE. Just pipe.

## Quick Start

```bash
export PATH="$HOME/ml-cli/bin:$PATH"

# Basic math
ml eval "1+2*3"              # → 7
ml eval "eig(magic(5))"

# Pipeline
echo "1:100" | ml eval "sum(ans)"     # → 5050
ml bench --json | jq '.matrix_multiply_1k'

# Data analysis
ml eval --json "rand(3)" | jq '.'
ml eval --table "magic(3)"

# Signal processing
ml signal audio.wav --fft --json | jq '.peak_freq'

# Image processing
ml image photo.png --info --json
ml image photo.png --gray --save gray.png

# Control systems
ml control "tf(1,[1 2 1])"

# Aerospace
ml aero --alt 10000             # ISA at 10km
ml aero --alt 5000 --mach 0.8   # Mach speed
```

## Commands

| Command | Description | JSON | TABLE | CSV |
|---------|-------------|------|-------|-----|
| `ml eval "expr"` | Evaluate | ✓ | ✓ | ✓ |
| `ml run script.m` | Execute script | — | — | — |
| `ml plot "cmd"` | Generate plot | — | — | — |
| `ml signal file` | Signal analysis | ✓ | — | ✓ |
| `ml image file` | Image processing | ✓ | — | — |
| `ml control "tf"` | Control systems | — | — | — |
| `ml aero --alt H` | Aerospace | — | — | — |
| `ml info` | Environment | ✓ | ✓ | — |
| `ml bench` | Performance | ✓ | ✓ | — |
| `ml lint file.m` | Code style | — | — | — |
| `ml help [cmd]` | Help | — | — | — |

## Pipeline Examples

```bash
# Signal analysis workflow
ml signal audio.wav --fft --json | jq '.peak_freq'

# Data processing
for f in data/*.csv; do
  ml eval "mean(readmatrix('$f'))" --json | jq '.[0:3]'
done

# Combine with Unix tools
ml bench --json | jq 'keys[]' | while read test; do
  echo "$test: $(ml bench --json | jq ".$test")ms"
done
```

## Architecture

```
ml (bash entry)
  ├─ cmd_eval()   → MATLAB eval
  ├─ cmd_signal() → signal_fft/psd/filter.m
  ├─ cmd_image()  → image_info/hist.m + imread/imwrite
  ├─ cmd_control()→ tf/step/bode/nyquist
  ├─ cmd_aero()   → atmoscoesa + Mach calc
  ├─ cmd_info()   → ver + toolbox listing
  ├─ cmd_bench()  → matrix/FFT/SVD benchmarks
  └─ cmd_lint()   → code style checker

run_matlab(code)
  └─ write tmp .m file → matlab -batch "run('tmp')"
```

## MATLAB Library Functions

- `jsonify.m` — Convert any MATLAB data to JSON
- `to_table.m` — Convert to Markdown table
- `to_csv.m` — Convert to CSV
- `cli_info.m` — Environment information
- `cli_bench.m` — Performance benchmarks
- `cli_lint.m` — Code style checker
- `signal_fft.m`, `signal_psd.m`, `signal_filter.m`
- `image_info.m`, `image_hist.m`

## Shell Wrapper Details

The `matlab.zsh` library provides:
- `matlab_batch(code)` — Execute MATLAB code via temp file + `-batch`
- `matlab_eval(expr)` — Execute single expression
- `matlab_run(dir, script)` — Run .m script from directory
- `die(msg)`, `warn(msg)` — Error handling with exit codes

## Testing

```bash
# Run individual tests
ml eval "1+1"
ml eval "rand(3)" --json
ml signal test.wav --fft --json | jq '.peak_freq'
ml image test.png --info --json | jq '.width'

# Verify exit codes
ml eval "undefined_func()" && echo "FAIL" || echo "PASS: error detected"

# Pipe test
echo "1:5" | ml eval "sum(ans)"  # expect: 15
```

## Version History

- **v0.2.0** (2026-06-24): signal, image, control, aero commands. JSON/Table/CSV on eval. Pipeline support. Temp file approach for multi-line code.
- **v0.1.0** (2026-06-24): Initial release. eval, run, plot, lint, info, bench, fmt.

## License

MIT
