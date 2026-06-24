#!/bin/bash
# Learning Path 3: 工程分析 (25 min)
set -euo pipefail; export PATH="$HOME/ml-cli/bin:$PATH"
clear
echo "╔══════════════════════════════════════╗"
echo "║  Path 3: 工程分析 (25 min)           ║"
echo "║  控制/航空/优化/ODE 仿真             ║"
echo "╚══════════════════════════════════════╝"
pause() { echo; read -p "  [Enter] " _; echo; }
SCRIPT="ml"

echo -e "\n━━━ 1. 航空大气参数 ━━━"
for alt in 0 5000 10000; do
    echo -n "  alt=${alt}m: "; $SCRIPT aero "--alt $alt" 2>/dev/null | grep -v Trial | tail -1
done
pause

echo -e "\n━━━ 2. 控制: 传递函数 ━━━"
$SCRIPT eval "s=tf('s');G=5/(s^2+2*s+5);info=stepinfo(G);fprintf('Rise:%.2fs Settle:%.2fs Overshoot:%.0f%%\n',info.RiseTime,info.SettlingTime,info.Overshoot)" 2>/dev/null | grep -v Trial
pause

echo -e "\n━━━ 3. 控制: LQR 设计 ━━━"
$SCRIPT eval "A=[0 1;-5 -2];B=[0;5];[K,S,e]=lqr(A,B,eye(2),1);fprintf('K=[%.3f %.3f]\\nclosed-loop poles:\\n',K);disp(eig(A-B*K))" 2>/dev/null | grep -v Trial
pause

echo -e "\n━━━ 4. 非线性优化 ━━━"
$SCRIPT optimize "--rosenbrock --json" 2>/dev/null | grep -v Trial | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'  x*=[{d[\"x_opt\"][0]:.6f},{d[\"x_opt\"][1]:.6f}]')
print(f'  f*={d[\"fval\"]:.2e}')
print(f'  iterations={d[\"iterations\"]}')
" 2>/dev/null
pause

echo -e "\n━━━ 5. ODE 仿真 ━━━"
$SCRIPT solve "--vanderpol --json" 2>/dev/null | grep -v Trial | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'  Van der Pol: {d[\"n_steps\"]} steps')
print(f'  Final state: [{d[\"y_final\"][0]:.3f},{d[\"y_final\"][1]:.3f}]')
" 2>/dev/null
pause

echo -e "\n━━━ 6. 性能基准 ━━━"
$SCRIPT bench 2>/dev/null | grep -v Trial | head -8

echo -e "\n━━━ ✓ 完成! ━━━"
echo "下一步: Path 4 (专业开发)"
