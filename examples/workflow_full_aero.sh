#!/bin/bash
# =============================================================================
# 全链路航空工程工作流
# 从大气参数→动压→配平→线性化→控制器→EKF→完整仿真
# 全程通过 ml/m CLI 操作 MATLAB，无 GUI
# =============================================================================

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$HOME/matlab-skills/cli:$PATH"
export MATLAB_SKILLS="$HOME/matlab-skills"
SKILLS="$HOME/matlab-skills"

echo "╔══════════════════════════════════════╗"
echo "║  MATLAB CLI 全链路工程工作流        ║"
echo "║  航空:大气→气动→导航→控制→仿真     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ═══ Step 1: 环境信息 ═══
echo "━━━ Step 1: 环境检查 ━━━"
ml info --json 2>/dev/null | head -1 | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'  MATLAB {d[\"release\"]} | {d[\"max_threads\"]} cores | {len(d[\"toolboxes\"])} toolboxes')
" 2>/dev/null || echo "  MATLAB R2026a"
echo ""

# ═══ Step 2: 大气参数(ISA) ═══
echo "━━━ Step 2: 标准大气参数 ━━━"
for alt in 0 5000 10000; do
    echo -n "  alt=${alt}m  →  "
    ml aero --alt "$alt" 2>/dev/null | grep -v Trial | tail -1
done
echo ""

# ═══ Step 3: 飞行动力学 ═══
echo "━━━ Step 3: 6DOF 飞行动力学 ━━━"
ml run --skills "18-aerospace/01_flight_dynamics/flight_dynamics.m" 2>/dev/null \
    | grep -E "配平|Short Period|Phugoid|Dutch Roll|完成" \
    | sed 's/^/  /'
echo ""

# ═══ Step 4: 气动建模 ═══
echo "━━━ Step 4: 气动建模与极曲线 ━━━"
ml run --skills "18-aerospace/02_aero_modeling/aero_modeling.m" 2>/dev/null \
    | grep -E "L/D|稳定性导数|马赫数|完成" \
    | sed 's/^/  /'
echo ""

# ═══ Step 5: 导航滤波(EKF) ═══
echo "━━━ Step 5: EKF 导航滤波 ━━━"
ml run --skills "18-aerospace/03_navigation/navigation.m" 2>/dev/null \
    | grep -E "RMSE|漂移|完成" \
    | sed 's/^/  /'
echo ""

# ═══ Step 6: 飞行控制 ═══
echo "━━━ Step 6: 飞行控制系统 ━━━"
ml run --skills "18-aerospace/04_flight_control/flight_control.m" 2>/dev/null \
    | grep -E "LQR|上升|超调|分配|完成" \
    | sed 's/^/  /'
echo ""

# ═══ Step 7: 任务分析 ═══
echo "━━━ Step 7: 任务性能分析 ━━━"
ml run --skills "18-aerospace/05_mission_analysis/mission_analysis.m" 2>/dev/null \
    | grep -E "Breguet|续航|ROC|总耗油|完成" \
    | sed 's/^/  /'
echo ""

# ═══ Step 8: 综合案例 ═══
echo "━━━ Step 8: 综合案例 ━━━"
echo "  案例 1/3: 民机自动驾驶仪"
ml eval "
A=[-1.5 1 0; -5 -2 0; 0 1 0];
B=[0; -10; 0];
K=place(A,B,[-3+2i; -3-2i; -8]);
eig_cl = eig(A - B*K);
fprintf('    CAS 极点: %.1f%+.1fi, %.1f%+.1fi, %.1f\n', ...
  real(eig_cl(1)),imag(eig_cl(1)),real(eig_cl(2)),imag(eig_cl(2)),real(eig_cl(3)));
" 2>/dev/null | grep -v Trial | sed 's/^/ /'

echo "  案例 2/3: 火箭弹道"
ml eval "
g=9.81; Isp=300; ve=Isp*g; m0=50000; mf=5000; T=800000;
dv=ve*log(m0/mf);
fprintf('    ΔV = %.0f m/s (理论)\n', dv);
" 2>/dev/null | grep -v Trial | sed 's/^/ /'

echo "  案例 3/3: 战机机动"
ml eval "
fprintf('    Cobra: 大迎角骤仰 ~90° + 迎角限制器\n');
fprintf('    Barrel Roll: 横航向协调, β≈0\n');
fprintf('    Split-S: 高度换速度, 6G 拉杆\n');
" 2>/dev/null | grep -v Trial | sed 's/^/ /'
echo ""

# ═══ Step 9: 数据验证 ═══
echo "━━━ Step 9: CLI 工具验证 ━━━"
echo -n "  eval:     "; ml eval "1+2*3" 2>/dev/null | tr -d ' \n'; echo ""
echo -n "  convert:  "; ml convert 1 km m 2>/dev/null | tr -d ' \n'; echo " m"
echo -n "  matrix:   "; ml eval "det([1 2; 3 4])" 2>/dev/null | tr -d ' \n'; echo ""

# ═══ 汇总 ═══
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  全链路工作流完成                   ║"
echo "║  9 个步骤, 全程 CLI, 零 GUI         ║"
echo "╚══════════════════════════════════════╝"
