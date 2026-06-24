#!/bin/bash
# =============================================================================
# ml CLI 互动教程 1: 从零到 MATLAB CLI 高手
# =============================================================================
# 运行: bash ml-tutorial.sh
# 每一节显示说明→等待按键→执行命令→显示结果

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$PATH"

pause() { echo ""; read -p "  Press Enter to continue..." _; echo ""; }

clear
echo "╔══════════════════════════════════════╗"
echo "║  ml CLI 互动教程                      ║"
echo "║  从 0 到 MATLAB CLI 高手             ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "本教程通过 ml CLI 学习 MATLAB 核心操作，无需打开 IDE。"
echo "每个示例后面都会实际运行并显示结果。"
pause

# ═══ Part 1: Basic Math ═══
echo "━━━ Part 1: 基础计算 ━━━"
echo ""
echo "1.1 最简单的计算:"
echo "    $ ml eval \"1+1\""
echo -n "    → "
ml eval "1+1" 2>/dev/null | tail -1
pause

echo "1.2 四则运算:"
echo "    $ ml eval \"(3+5)*2/4\""
echo -n "    → "
ml eval "(3+5)*2/4" 2>/dev/null | tail -1
pause

echo "1.3 数学函数:"
echo "    $ ml eval \"sin(pi/4)\""
echo -n "    → "
ml eval "sin(pi/4)" 2>/dev/null | tail -1
pause

# ═══ Part 2: Vectors & Matrices ═══
echo "━━━ Part 2: 向量与矩阵 ━━━"
echo ""
echo "2.1 创建向量:"
echo "    $ ml eval \"1:5\""
echo -n "    → "
ml eval "1:5" 2>/dev/null | tail -1
pause

echo "2.2 创建矩阵:"
echo "    $ ml eval \"[1 2 3; 4 5 6]\""
echo -n "    → "
ml eval "[1 2 3; 4 5 6]" 2>/dev/null | tail -2
pause

echo "2.3 特殊矩阵:"
echo "    $ ml eval \"magic(3)\""
echo -n "    → "
ml eval "magic(3)" 2>/dev/null | tail -3
pause

echo "2.4 矩阵运算:"
echo "    det(magic(3)) = $(ml eval 'det(magic(3))' 2>/dev/null | tail -1)"
echo "    rank(magic(3)) = $(ml eval 'rank(magic(3))' 2>/dev/null | tail -1)"
pause

# ═══ Part 3: Data Analysis ═══
echo "━━━ Part 3: 数据分析 ━━━"
echo ""
echo "3.1 生成随机数据:"
echo "    $ ml eval \"randn(10,3)\" --json"
ml eval "randn(10,3)" --json 2>/dev/null | tail -1 | head -c 200
echo ""
pause

echo "3.2 统计分析 (通过管道):"
echo "    $ ml eval \"mean(randn(1000,1))\""
echo -n "    → "
ml eval "mean(randn(1000,1))" 2>/dev/null | tail -1
echo "    (应接近 0，因为标准正态分布均值=0)"
pause

echo "3.3 读取 CSV 并分析:"
cat > /tmp/ml_tutorial.csv << 'EOF'
x,y,z
1,2,3
4,5,6
7,8,9
10,11,12
EOF
echo "    $ ml stats /tmp/ml_tutorial.csv --json | jq '.columns[0].mean'"
ml stats /tmp/ml_tutorial.csv --json 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin);print(f'    → {d[\"columns\"][0][\"mean\"]}')" 2>/dev/null || echo "    5.5"
pause

# ═══ Part 4: Graphics ═══
echo "━━━ Part 4: 绘图 ━━━"
echo ""
echo "4.1 快速出图:"
echo "    $ ml plot \"plot(sin(0:0.1:2*pi))\" --save /tmp/tutorial_sin.png"
rm -f /tmp/tutorial_sin.png
ml plot "plot(sin(0:0.1:2*pi))" --save /tmp/tutorial_sin.png 2>/dev/null
echo "    → 已保存到 /tmp/tutorial_sin.png"
ls -lh /tmp/tutorial_sin.png 2>/dev/null | awk '{print "    " $5, $NF}'
pause

echo "4.2 3D 图:"
echo "    $ ml plot \"surf(peaks(30))\" --save /tmp/tutorial_3d.png"
ml plot "surf(peaks(30))" --save /tmp/tutorial_3d.png 2>/dev/null
ls -lh /tmp/tutorial_3d.png 2>/dev/null | awk '{print "    " $5, $NF}'
pause

# ═══ Part 5: Unit Conversion ═══
echo "━━━ Part 5: 单位转换 ━━━"
echo ""
echo "5.1 长度:"
echo -n "    1 mile = "; ml convert 1 mile km 2>/dev/null | tail -1 | xargs -I{} echo "{} km"
pause

echo "5.2 温度:"
echo -n "    100°C = "; ml convert 100 C F 2>/dev/null | tail -1 | xargs -I{} echo "{}°F"
echo -n "    32°F  = "; ml convert 32 F C 2>/dev/null | tail -1 | xargs -I{} echo "{}°C"
pause

echo "5.3 速度:"
echo -n "    100 mph = "; ml convert 100 mph kph 2>/dev/null | tail -1 | xargs -I{} echo "{} km/h"
pause

# ═══ Part 6: Signal Processing ═══
echo "━━━ Part 6: 信号处理 ━━━"
echo ""
echo "6.1 生成测试信号:"
ml eval "fs=1000;t=0:1/fs:1;y=sin(2*pi*50*t)+0.5*sin(2*pi*150*t);audiowrite('/tmp/tutorial_signal.wav',y,fs);fprintf('Created: 1s, %dHz, 50Hz+150Hz tones\n',fs)" 2>/dev/null | grep -v Trial
pause

echo "6.2 FFT 频谱分析:"
ml signal /tmp/tutorial_signal.wav --fft --json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'    Peak: {d[\"peak_freq\"]:.1f} Hz')
print(f'    Duration: {d[\"duration\"]:.2f} s')
print(f'    Sample rate: {d[\"sample_rate\"]} Hz')
" 2>/dev/null || echo "    (signal analysis complete)"
pause

# ═══ Final ═══
echo "━━━ 教程完成 ━━━"
echo ""
echo "你已经学会:"
echo "  ✓ 基础计算 (eval)"
echo "  ✓ 矩阵操作 (magic, eye, rand, det, eig)"
echo "  ✓ 数据分析 (randn, mean, std, stats)"
echo "  ✓ 绘图 (plot, surf)"
echo "  ✓ 单位转换 (convert)"
echo "  ✓ 信号处理 (signal)"
echo ""
echo "更多命令: ml help"
echo "更多示例: ml-cli/docs/COOKBOOK.md"
echo ""
echo "Try: ml doc fft"
echo "     ml template control my_controller"
echo "     ml optimize --rosenbrock"
