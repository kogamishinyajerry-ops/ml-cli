#!/bin/bash
# Learning Path 2: 数据处理与分析 (20 min)
set -euo pipefail; export PATH="$HOME/ml-cli/bin:$PATH"
clear
echo "╔══════════════════════════════════════╗"
echo "║  Path 2: 数据处理与分析 (20 min)    ║"
echo "║  CSV/JSON/stats + 信号处理 + 导出   ║"
echo "╚══════════════════════════════════════╝"
pause() { echo; read -p "  [Enter] " _; echo; }
run()  { echo -e "  \$ ml $*"; echo -n "  → "; eval "ml $*" 2>/dev/null | grep -v Trial | head -3; }
SCRIPT="ml"

echo -e "\n━━━ 1. 生成样本数据 ━━━"
$SCRIPT eval "D=randn(100,4);writematrix(D,'/tmp/learn_data.csv');fprintf('100 rows x 4 cols saved\n')" 2>/dev/null | grep -v Trial
pause

echo -e "\n━━━ 2. 描述统计 ━━━"
run stats "/tmp/learn_data.csv --json"
echo "  (完整输出通过管道给 jq:)"
$SCRIPT stats /tmp/learn_data.csv --json 2>/dev/null | grep -v Trial | python3 -c "
import json,sys
d=json.load(sys.stdin)
for c in d['columns']:
    print(f'    col: mean={c[\"mean\"]:.3f} std={c[\"std\"]:.3f}')
" 2>/dev/null
pause

echo -e "\n━━━ 3. 数据清洗(missing values) ━━━"
run eval "D=readmatrix('/tmp/learn_data.csv');D(10:15,2)=NaN;D(50,3)=NaN;fprintf('NaN count: %d\n',sum(isnan(D(:))))"
pause

echo -e "\n━━━ 4. 相关性分析 ━━━"
run eval "D=readmatrix('/tmp/learn_data.csv');R=corrcoef(D);fprintf('Corr(1,2)=%.3f\\n',R(1,2))"
pause

echo -e "\n━━━ 5. 信号生成 + FFT ━━━"
$SCRIPT eval "fs=1000;t=0:1/fs:1-1/fs;y=sin(2*pi*50*t)+0.3*sin(2*pi*150*t);audiowrite('/tmp/learn_sig.wav',y,fs);fprintf('1s audio @ %dHz\n',fs)" 2>/dev/null | grep -v Trial
run signal "/tmp/learn_sig.wav --fft --json"
$SCRIPT signal /tmp/learn_sig.wav --fft --json 2>/dev/null | grep -v Trial | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'    Peak: {d[\"peak_freq\"]:.0f} Hz, Duration: {d[\"duration\"]:.1f}s')
" 2>/dev/null
pause

echo -e "\n━━━ 6. 导出结果 ━━━"
$SCRIPT eval "A=magic(3);save('/tmp/learn_out.mat','A');fprintf('.mat saved\n')" 2>/dev/null | grep -v Trial
run mat "list /tmp/learn_out.mat --json"
run export "/tmp/learn_out.mat --fmt csv --out /tmp/learn_out.csv"

echo -e "\n━━━ ✓ 完成! ━━━"
echo "下一步: Path 3 (工程分析)"
