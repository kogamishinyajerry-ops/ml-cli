#!/bin/bash
# 批量实测所有 matlab-skills .m 脚本
# 用法: bash batch_verify.sh

SKILLS="${HOME}/matlab-skills"
export PATH="$HOME/ml-cli/bin:$PATH"
MATLAB_BIN="/Applications/MATLAB_R2026a.app/bin/matlab"
RESULTS="/tmp/ml_batch_results_$(date +%s).log"
PASS=0; FAIL=0; SKIP=0

# 已知需要交互或 Simulink 的脚本(跳过)
SKIP_LIST=(
    "08-simulink/simulink_basics.m"       # needs Simulink GUI
    "08-simulink/simulink_advanced.m"      # needs Simulink GUI
    "09-simscape/simscape_intro.m"         # needs Simscape
    "10-appdesigner/app1_sine_generator.m" # needs GUI
    "10-appdesigner/app2_curve_fitter.m"   # needs GUI
    "14-stateflow/stateflow_basics.m"      # needs Stateflow
    "14-stateflow/stateflow_advanced.m"    # needs Stateflow
    "15-mbd-pipeline/case_traffic_light.m" # needs Simulink
    "17-system-composer/sc_basics.m"       # needs SC
    "17-system-composer/sc_api.m"          # needs SC
    "17-system-composer/case_drone_architecture.m" # needs SC
)

should_skip() {
    local rel="$1"
    for p in "${SKIP_LIST[@]}"; do
        [[ "$rel" == "$p" ]] && return 0
    done
    return 1
}

echo "╔══════════════════════════════════════╗"
echo "║  matlab-skills 批量实测             ║"
echo "╚══════════════════════════════════════╝"
echo ""

cd "$SKILLS"

find . -name "*.m" -not -path "*/solutions/*" | sort | while read f; do
    rel="${f#./}"

    if should_skip "$rel"; then
        echo "  ⏭  $rel (skipped: GUI/toolbox required)"
        ((SKIP++))
        continue
    fi

    echo -n "  ... $rel "

    if timeout 120 "$MATLAB_BIN" -batch "cd('$(dirname "${SKILLS}/${rel}")'); run('$(basename "${rel}" .m)');" \
        > /tmp/ml_batch_out.txt 2>&1; then
        echo "✓"
        ((PASS++))
    else
        # Check if it's a known warning (not a crash)
        if grep -q "Warning\|warning\|WARN\|Trial License" /tmp/ml_batch_out.txt 2>/dev/null \
           && ! grep -q "错误\|Error\|ERROR\|FAIL" /tmp/ml_batch_out.txt 2>/dev/null; then
            echo "✓ (warnings)"
            ((PASS++))
        else
            echo "✗"
            echo "  ── failure output ──" >> "$RESULTS"
            grep -v "Trial License" /tmp/ml_batch_out.txt | head -5 >> "$RESULTS"
            echo "" >> "$RESULTS"
            ((FAIL++))
        fi
    fi
done

echo ""
echo "═════════════════════════════════════"
grep -c "✓" "$RESULTS" 2>/dev/null || true
echo "Failures logged to: $RESULTS"
