#!/bin/bash
# =============================================================================
# ml CLI 自动测试套件
# 覆盖所有子命令、管道、exit code、输出格式
# =============================================================================

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$PATH"
export ML_TEST_DIR="/tmp/ml_test_$(date +%s)"
mkdir -p "$ML_TEST_DIR"

PASS=0; FAIL=0; SKIP=0

# ─── 测试函数 ─────────────────────────────────────────
assert_ok() {
    local desc="$1"; shift
    if "$@" > /dev/null 2>&1; then
        echo "  ✓ $desc"
        ((PASS++))
    else
        echo "  ✗ $desc"
        ((FAIL++))
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $desc"
        ((PASS++))
    else
        echo "  ✗ $desc (expected: $expected, got: $actual)"
        ((FAIL++))
    fi
}

assert_fail() {
    local desc="$1"; shift
    if ! "$@" > /dev/null 2>&1; then
        echo "  ✓ $desc"
        ((PASS++))
    else
        echo "  ✗ $desc (should have failed)"
        ((FAIL++))
    fi
}

# ─── eval ──────────────────────────────────────────────
echo "=== Test: ml eval ==="
assert_ok "eval basic" ml eval "1+1"
assert_ok "eval matrix" ml eval "eye(2)"
assert_eq "eval result" "2" "$(ml eval "1+1" 2>/dev/null | tail -1 | tr -d ' ')"
assert_ok "eval JSON" ml eval --json "[1 2;3 4]"
assert_ok "eval TABLE" ml eval --table "[1 2;3 4]"
assert_ok "eval CSV" ml eval --csv "[1 2;3 4]"
assert_fail "eval error exit code" ml eval "undefined_var"

# ─── convert ───────────────────────────────────────────
echo "=== Test: ml convert ==="
assert_eq "convert km->m" "1000" "$(ml convert 1 km m 2>/dev/null | tail -1 | tr -d ' ')"
assert_eq "convert C->F" "212" "$(ml convert 100 C F 2>/dev/null | tail -1 | tr -d ' ')"
assert_eq "convert rad->deg" "179.909" "$(ml convert 3.14 rad deg 2>/dev/null | tail -1 | tr -d ' ')"

# ─── optimize ──────────────────────────────────────────
echo "=== Test: ml optimize ==="
assert_ok "optimize rosenbrock" ml optimize --rosenbrock --json
assert_ok "optimize himmelblau" ml optimize --himmelblau --json

# ─── solve ─────────────────────────────────────────────
echo "=== Test: ml solve ==="
assert_ok "solve vanderpol" ml solve --vanderpol --json
assert_ok "solve lorenz" ml solve --lorenz --json

# ─── info ───────────────────────────────────────────────
echo "=== Test: ml info ==="
assert_ok "info text" ml info
assert_ok "info JSON" ml info --json

# ─── bench ──────────────────────────────────────────────
echo "=== Test: ml bench ==="
assert_ok "bench text" ml bench
assert_ok "bench JSON" ml bench --json

# ─── lint ───────────────────────────────────────────────
echo "=== Test: ml lint ==="
echo "x = 1; y = 2;" > "$ML_TEST_DIR/test_lint.m"
assert_ok "lint pass" ml lint "$ML_TEST_DIR/test_lint.m"

# ─── pipe ───────────────────────────────────────────────
echo "=== Test: Pipe ==="
assert_ok "eval pipe" bash -c 'echo "1:5" | ml eval "sum(ans)"'
assert_ok "eval pipe JSON" bash -c 'echo "1:5" | ml eval "sum(ans)"'

# ─── plot ───────────────────────────────────────────────
echo "=== Test: ml plot ==="
assert_ok "plot sin" ml plot "plot(sin(0:0.1:2*pi))" --save "$ML_TEST_DIR/test_plot.png"

# ─── signal ─────────────────────────────────────────────
echo "=== Test: ml signal ==="
/Applications/MATLAB_R2026a.app/bin/matlab -batch "fs=1000;t=0:1/fs:1;y=sin(2*pi*50*t);audiowrite('$ML_TEST_DIR/test.wav',y,fs);exit" 2>/dev/null
assert_ok "signal FFT" ml signal "$ML_TEST_DIR/test.wav" --fft --json
assert_ok "signal PSD" ml signal "$ML_TEST_DIR/test.wav" --psd --json
assert_ok "signal PIPE" bash -c "ml signal '$ML_TEST_DIR/test.wav' --fft --json | python3 -c 'import json,sys;d=json.load(sys.stdin);exit(0 if abs(d[\"peak_freq\"]-50)<1 else 1)'"

# ─── image ──────────────────────────────────────────────
echo "=== Test: ml image ==="
/Applications/MATLAB_R2026a.app/bin/matlab -batch "imwrite(rand(100,100,3),'$ML_TEST_DIR/test.png');exit" 2>/dev/null
assert_ok "image info" ml image "$ML_TEST_DIR/test.png" --info --json
assert_ok "image hist" ml image "$ML_TEST_DIR/test.png" --hist --json
assert_ok "image PIPE" bash -c "ml image '$ML_TEST_DIR/test.png' --info --json | python3 -c 'import json,sys;d=json.load(sys.stdin);exit(0 if d[\"width\"]==100 else 1)'"

# ─── control/aero ───────────────────────────────────────
echo "=== Test: ml control/aero ==="
assert_ok "aero ISA" ml aero --alt 10000
assert_ok "aero mach" ml aero --alt 0 --mach 0.8

# ─── stats ──────────────────────────────────────────────
echo "=== Test: ml stats ==="
echo "1,2,3" > "$ML_TEST_DIR/test_stats.csv"
echo "4,5,6" >> "$ML_TEST_DIR/test_stats.csv"
echo "7,8,9" >> "$ML_TEST_DIR/test_stats.csv"
assert_ok "stats JSON" ml stats "$ML_TEST_DIR/test_stats.csv" --json

# ─── 汇总 ───────────────────────────────────────────────
echo ""
echo "═════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "═════════════════════════════════════"

# Cleanup
rm -rf "$ML_TEST_DIR"
exit $FAIL
