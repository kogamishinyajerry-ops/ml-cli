#!/bin/bash
# Learning Path 1: MATLAB CLI 新手入门 (15 min)
set -euo pipefail; export PATH="$HOME/ml-cli/bin:$PATH"
clear
echo "╔══════════════════════════════════════╗"
echo "║  Path 1: 新手入门 (15 min)           ║"
echo "║  从 1+1 到画第一张图                 ║"
echo "╚══════════════════════════════════════╝"

pause() { echo; read -p "  [Enter] " _; }
run()  { echo -e "\n  \$ ml $*"; eval "ml $*" 2>/dev/null | grep -v Trial | head -3; }

echo -e "\n━━━ 1. 基础计算 ━━━"
run eval "1+1"
run eval "2+3*4"
run eval "sin(pi/4)"
run eval "sqrt(2)"
pause

echo -e "\n━━━ 2. 向量 ━━━"
run eval "1:10"
run eval "1:2:10"
run eval "linspace(0,1,5)"
pause

echo -e "\n━━━ 3. 矩阵 ━━━"
run eval "eye(3)"
run eval "ones(2,4)"
run eval "magic(3)"
run eval "[1 2 3; 4 5 6]"
pause

echo -e "\n━━━ 4. 统计 ━━━"
run eval "mean(1:100)"
run eval "sum(1:100)"
run eval "std(randn(1,1000))"
pause

echo -e "\n━━━ 5. 单位转换 ━━━"
run convert "1 km m"
run convert "100 C F"
run convert "60 mph kph"
pause

echo -e "\n━━━ 6. 第一张图 ━━━"
run plot "'plot(sin(0:0.1:2*pi))' --save /tmp/my_first_plot.png"
file /tmp/my_first_plot.png 2>/dev/null

echo -e "\n━━━ ✓ 完成! 你已学会 CLI 基本操作 ━━━"
echo "下一步: Path 2 (数据处理)"
