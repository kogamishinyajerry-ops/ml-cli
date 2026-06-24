# GitLab CI/CD Setup Guide for ml-cli

## 1. Register a MATLAB Runner

### macOS (where MATLAB is installed)
```bash
# Install GitLab Runner
brew install gitlab-runner

# Register with GitLab
gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_PROJECT_TOKEN \
  --description "MATLAB macOS Runner" \
  --executor shell \
  --tag-list "matlab-runner"

# Start the runner
gitlab-runner run
```

### Verify MATLAB access
```bash
# The runner must be able to find MATLAB
which matlab
/Applications/MATLAB_R2026a.app/bin/matlab -batch "disp('MATLAB ready')"
```

## 2. Set CI/CD Variables

In GitLab: **Settings → CI/CD → Variables**

| Variable | Value | Protected |
|----------|-------|-----------|
| `MATLAB_BIN` | `/Applications/MATLAB_R2026a.app/bin/matlab` | No |

## 3. Pipeline Structure

```
Stage
├── setup
│   ├── check-environment   Python deps check
│   └── check-matlab        Verify MATLAB license (matlab-runner)
├── test
│   ├── unit-tests          Core ml commands (matlab-runner)
│   ├── python-only-tests   numpy/pandas tests (docker)
│   ├── subcommand-tests    All subcommands (matlab-runner)
│   └── format-tests        JSON/Table/CSV/Pipe (matlab-runner)
├── integration
│   ├── integration-pattern-1  FFT→Python
│   ├── integration-pattern-2  Python→ODE
│   ├── integration-pattern-3  Optimize→Python
│   ├── integration-pattern-5  Big pipeline
│   ├── image-processing       Image info
│   └── signal-processing      Signal PSD
└── report
    └── generate-report       Markdown report
```

## 4. Running Locally (without GitLab)

```bash
# Fast mode — core commands only
bash scripts/ci-local.sh --fast

# Full mode — all unit tests
bash scripts/ci-local.sh --full

# Integration mode — MATLAB+Python patterns
bash scripts/ci-local.sh --integration
```

## 5. Troubleshooting

| Problem | Solution |
|---------|----------|
| `matlab-runner` tag not found | Register a shell runner with tag `matlab-runner` |
| MATLAB license error | Ensure MATLAB license is active. Set `allow_failure: true` for initial setup |
| Python deps missing | Install: `pip install numpy scipy pandas` on runner |
| `ml` command not found | Verify `PATH` includes `bin/` directory |
| Pipeline timeout | Increase job timeout in `.gitlab-ci.yml` |
