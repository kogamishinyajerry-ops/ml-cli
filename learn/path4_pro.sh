#!/bin/bash
# Learning Path 4: 专业开发 (30 min)
set -euo pipefail; export PATH="$HOME/ml-cli/bin:$PATH"
clear
echo "╔══════════════════════════════════════╗"
echo "║  Path 4: 专业开发 (30 min)           ║"
echo "║  CI/模板/管道/项目/测试              ║"
echo "╚══════════════════════════════════════╝"
pause() { echo; read -p "  [Enter] " _; echo; }
SCRIPT="ml"

echo -e "\n━━━ 1. 创建项目 ━━━"
cd /tmp
$SCRIPT new "learn_proj" 2>/dev/null | grep -v Trial
ls learn_proj/
pause

echo -e "\n━━━ 2. 生成模板 ━━━"
$SCRIPT template "simulation" "my_sim" 2>/dev/null | grep -v Trial
echo "Created:" && head -5 my_sim.m
pause
rm -f my_sim.m

echo -e "\n━━━ 3. 代码检查 ━━━"
echo "x=1; y=2; %missing semicolons" > /tmp/lint_demo.m
$SCRIPT lint "/tmp/lint_demo.m" 2>/dev/null | grep -v Trial
pause

echo -e "\n━━━ 4. 管道编程 ━━━"
echo "MATLAB→JSON→jq pipeline:"
$SCRIPT eval "--json 'rand(3)'" 2>/dev/null | grep -v Trial | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'  shape: {len(d)}x{len(d[0])}')
" 2>/dev/null
pause

echo -e "\n━━━ 5. 查看仓库脚本 ━━━"
$SCRIPT skills "18-aerospace" 2>/dev/null | grep -v Trial | head -5
pause

echo -e "\n━━━ 6. 运行仓库脚本 ━━━"
$SCRIPT run "--skills flight_dynamics" 2>/dev/null | grep -v Trial | grep "完成" | head -1
pause

echo -e "\n━━━ 7. CI 本地运行 ━━━"
echo "  bash scripts/ci-local.sh --fast"
echo "  (在 ml-cli 目录中执行)"
pause

echo -e "\n━━━ 8. 生成报告 ━━━"
$SCRIPT mat "list /tmp/learn_out.mat --json" 2>/dev/null | grep -v Trial | python3 -c "
import json,sys
d=json.load(sys.stdin)
for v in d['variables']:
    print(f'  {v[\"name\"]}: {v[\"class\"]} {v[\"size\"]} ({v[\"bytes\"]}B)')
" 2>/dev/null
echo "  (完整报告: python3 scripts/generate_report.py --local)"
pause

echo -e "\n━━━ ✓ 全部4条路径完成! ━━━"
echo "  Path 1: 新手入门 (15 min)"
echo "  Path 2: 数据处理 (20 min)"
echo "  Path 3: 工程分析 (25 min)"
echo "  Path 4: 专业开发 (30 min)"
echo ""
echo "  总时长: ~90 min"
echo "  从 1+1 到 CLI 专家"
