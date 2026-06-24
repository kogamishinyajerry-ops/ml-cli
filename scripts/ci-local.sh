#!/bin/bash
# =============================================================================
# ci-local.sh — Local CI Runner (no GitHub needed)
# =============================================================================
# 在本地模拟 GitHub Actions 的测试流程
# 用法: bash scripts/ci-local.sh [--fast|--full|--integration]

set -euo pipefail
export PATH="$(pwd)/bin:$PATH"
export CI=true  # signal to tests that we're in CI mode

MATLAB_BIN="${MATLAB_BIN:-/Applications/MATLAB_R2026a.app/bin/matlab}"
PASS=0; FAIL=0; TOTAL=0

# ─── Colors ───────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────
header()  { echo -e "\n${BLUE}${BOLD}━━━ $1 ━━━${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
err()     { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()    { echo -e "  $1"; }
run_test() {
    local desc="$1"; shift
    ((TOTAL++))
    echo -n "  [$TOTAL] $desc ... "
    if "$@" > /tmp/ci_test_out.txt 2>&1; then
        echo -e "${GREEN}OK${NC}"; ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        head -3 /tmp/ci_test_out.txt | sed 's/^/    /'
        ((FAIL++))
    fi
}

# ─── Mode ─────────────────────────────────────────────────
MODE="${1:-fast}"
case "$MODE" in
    --fast)    header "FAST MODE: core commands only" ;;
    --full)    header "FULL MODE: all unit tests" ;;
    --integration) header "INTEGRATION MODE: MATLAB+Python" ;;
    --help|-h) echo "Usage: bash scripts/ci-local.sh [--fast|--full|--integration]"; exit 0 ;;
    *)         header "Running: $MODE" ;;
esac

# ─── 0. Environment Check ─────────────────────────────────
header "0. Environment"

if [[ -x "$MATLAB_BIN" ]]; then
    ok "MATLAB binary: $MATLAB_BIN"
    info "  $( "$MATLAB_BIN" -batch "fprintf('%s', version('-release'))" 2>/dev/null | grep -v Trial )"
else
    err "MATLAB not found at $MATLAB_BIN"
    exit 1
fi

python3 --version > /dev/null 2>&1 && ok "Python3: $(python3 --version 2>&1)" || warn "Python3 not found"
python3 -c "import numpy" 2>/dev/null && ok "numpy" || warn "numpy missing"
python3 -c "import scipy" 2>/dev/null && ok "scipy" || warn "scipy missing"
ml --version > /dev/null 2>&1 && ok "ml CLI" || err "ml CLI not in PATH"

# ─── 1. Core Commands ─────────────────────────────────────
header "1. Core Commands"

run_test "eval basic"      ml eval "1+1"
run_test "eval matrix"     ml eval "eye(2)"
run_test "eval pipe"       bash -c 'echo "1:5" | ml eval "sum(ans)"'
run_test "JSON output"     ml eval --json "[1 2;3 4]"
run_test "TABLE output"    ml eval --table "[1 2;3 4]"
run_test "CSV output"      ml eval --csv "[1 2;3 4]"
run_test "error exit code" bash -c '! ml eval "bad_func()" 2>/dev/null'
run_test "info command"    ml info

# ─── 2. Subcommands ───────────────────────────────────────
header "2. Subcommands"

run_test "convert"       ml convert 1 km m
run_test "optimize"      ml optimize --rosenbrock --json
run_test "solve"         ml solve --vanderpol --json
run_test "mat list"      bash -c 'matlab -batch "save('"'/tmp/ci_test.mat'"','"'A'"','"'eye(2)'"');exit" 2>/dev/null; ml mat list /tmp/ci_test.mat --json'
run_test "doc"           ml doc fft
run_test "aero"          ml aero --alt 10000
run_test "skills list"   ml skills
run_test "lint"          bash -c 'echo "x=1;" > /tmp/ci_lint_test.m; ml lint /tmp/ci_lint_test.m'
run_test "bench"         ml bench

[ "$MODE" = "--fast" ] && { run_summary; exit $FAIL; }

# ─── 3. Output Formats (full mode) ───────────────────────
header "3. Output Formats — Roundtrip"

run_test "JSON→Python" bash -c '
  ml eval --json "rand(3)" 2>/dev/null | grep -v Trial | python3 -c "
  import json,sys
  d=json.load(sys.stdin)
  assert len(d)==3 and len(d[0])==3, \"Bad shape\"
  print(\"OK\")
  "'

run_test "CSV→Python" bash -c '
  ml eval --csv "magic(3)" 2>/dev/null | grep -v Trial | python3 -c "
  import sys
  lines=[l.strip() for l in sys.stdin if l.strip()]
  assert len(lines)==3, \"Bad rows\"
  print(\"OK\")
  "'

run_test "Python→MATLAB" bash -c '
  python3 -c "import json;print(json.dumps([1,2,3,4,5]))" | ml eval "sum(ans)" 2>/dev/null | grep -v Trial | grep -q 15'

# ─── 4. MATLAB+Python Patterns ────────────────────────────
header "4. MATLAB+Python Patterns"

run_test "Pattern 1: FFT→Python" bash -c '
  matlab -batch "fs=1000;t=0:1/fs:1;x=sin(2*pi*50*t);audiowrite('"'/tmp/ci_signal.wav'"',x,fs);exit" 2>/dev/null
  peak=$(ml signal /tmp/ci_signal.wav --fft --json 2>/dev/null | grep -v Trial | python3 -c "import json,sys;d=json.load(sys.stdin);print(int(d[\"peak_freq\"]))")
  [ "$peak" = "50" ]'

run_test "Pattern 2: Python→ODE" bash -c '
  echo "1 0.2 10" | ml eval "a=ans;m=a(1);c=a(2);k=a(3);[t,y]=ode45(@(t,y)[y(2);(-c*y(2)-k*y(1))/m],[0 10],[1;0]);fprintf(\"steps=%d\",length(t))" 2>/dev/null | grep -v Trial | grep -q steps'

run_test "Pattern 3: Optimize→Py" bash -c '
  ml optimize --rosenbrock --json 2>/dev/null | grep -v Trial | python3 -c "
  import json,sys
  d=json.load(sys.stdin)
  assert d[\"exitflag\"]==1, \"Optimization failed\"
  print(\"OK\")"'

run_test "Pattern 5: Big pipeline" bash -c '
  matlab -batch "fs=1000;t=0:1/fs:2-1/fs;x=sin(2*pi*50*t)+0.3*sin(2*pi*150*t);audiowrite('"'/tmp/ci_pipe.wav'"',x,fs);exit" 2>/dev/null
  ml signal /tmp/ci_pipe.wav --fft --json 2>/dev/null | grep -v Trial | python3 -c "
  import json,sys
  d=json.load(sys.stdin)
  assert abs(d[\"peak_freq\"]-50)<2, \"Peak not 50Hz\"
  print(\"OK\")"'

[ "$MODE" != "--integration" ] && { run_summary; exit $FAIL; }

# ─── 5. Full Integration Suite ────────────────────────────
header "5. Full Integration Suite"

if [ -f "tests/test_ml_python_integration.sh" ]; then
    info "Running integration test suite..."
    if bash tests/test_ml_python_integration.sh 2>&1 | tail -5; then
        ok "Integration suite passed"
    else
        warn "Integration suite had failures (see log)"
    fi
else
    warn "Integration test script not found"
fi

run_summary() {
    echo ""
    echo "═════════════════════════════════════"
    echo -e "  ${BOLD}Results:${NC} ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, $TOTAL total"
    echo "═════════════════════════════════════"
}

run_summary
exit $FAIL
