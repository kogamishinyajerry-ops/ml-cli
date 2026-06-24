# ml CLI Cookbook — 50+ Practical Recipes

> MATLAB CLI 实战手册。每条命令可直接复制执行。

## 基础计算

```bash
# 算术
ml eval "1+2*3"                    # 7
ml eval "sqrt(2)"                   # 1.4142
ml eval "sin(pi/4) + cos(pi/4)"   # 1.4142
ml eval "log10(1000)"              # 3

# 矩阵
ml eval "eye(3)"                   # 3x3 identity
ml eval "magic(3)"                 # 3x3 magic square
ml eval "ones(2,4)"               # 2x4 ones
ml eval "rand(100)"               # 100x100 random

# 线性代数
ml eval "det([1 2; 3 4])"         # -2
ml eval "eig([1 2; 3 4])"         # eigenvalues
ml eval "inv([1 2; 3 4])"         # inverse
ml eval "svd(rand(5))"            # singular values
ml eval "rank(magic(4))"           # matrix rank
ml eval "cond(hilb(5))"           # condition number

# Statistics
ml eval "mean(1:100)"              # 50.5
ml eval "var(randn(1,1000))"      # ~1
ml eval "corrcoef(rand(100,2))"    # correlation
```

## 单位转换

```bash
# Length
ml convert 1 km m                # 1000
ml convert 5 mile km             # 8.04672
ml convert 100 cm inch           # 39.3701

# Temperature
ml convert 0 C F                 # 32
ml convert 100 C F               # 212
ml convert 373 K C               # 99.85

# Pressure
ml convert 1 atm Pa              # 101325
ml convert 14.7 psi kPa          # ~101.3

# Speed
ml convert 100 mph kph           # 160.934
ml convert 60 mph m_s            # 26.8224
ml convert 100 knot kph          # 185.2

# Angle
ml convert pi rad deg            # 180
ml convert 90 deg rad             # ~1.5708
```

## 数据分析

```bash
# Basic stats on CSV
ml stats data.csv --json | jq '.columns[] | {mean: .mean, std: .std}'

# Filter specific columns
ml eval "d=readmatrix('data.csv'); mean(d(:,1:3))"

# Sort and find max
ml eval "[v,idx]=max(readmatrix('data.csv')); fprintf('max=%f at row=%d\n',v,idx)"

# Quick histogram
ml plot "histogram(readmatrix('data.csv'),20); xlabel('Value'); ylabel('Count')" --save hist.png
```

## 信号处理

```bash
# FFT spectrum
ml signal audio.wav --fft --json | jq '{peak: .peak_freq, duration: .duration}'

# Filter
ml signal audio.wav --filter 1000 --json
ml signal audio.wav --psd --json

# Generate test signal
ml eval "fs=1000;t=0:1/fs:1;y=sin(2*pi*50*t);audiowrite('test.wav',y,fs)"
```

## 图像处理

```bash
# Image info
ml image photo.png --info --json | jq '{w: .width, h: .height, fmt: .format}'

# Grayscale
ml image photo.png --gray --save gray.png

# Edge detection
ml image photo.png --edge --save edges.png

# Histogram data
ml image photo.png --hist --json | jq '{mean: .mean, std: .std}'

# Resize
ml image photo.png --resize 800x600 --save thumbnail.png
```

## 控制系统

```bash
# Step response
ml control "tf(1,[1 2 1])"

# Bode plot
ml control "tf(10,[1 2 10])"

# PID design
ml eval "[C,info]=pidtune(tf(1,[1 2 1]),'PIDF'); fprintf('Kp=%.2f Ki=%.2f Kd=%.2f\n',C.Kp,C.Ki,C.Kd)"

# LQR
ml eval "K=lqr(ss([-1 1;-5 -2],[0;-10],eye(2),0),eye(2),1); disp(K)"
```

## Aerospace

```bash
# ISA atmosphere
ml aero --alt 0        # Sea level: T=288K, ρ=1.225
ml aero --alt 10000    # Cruise: T=223K, ρ=0.413
ml aero --alt 0 --mach 0.8  # Mach speed at sea level

# Dynamic pressure
ml eval "[~,~,~,rho]=atmoscoesa(10000); Q=0.5*rho*250^2; fprintf('Q=%.0f Pa\n',Q)"

# Lift coefficient
ml eval "W=50000*9.81; S=100; [~,~,~,rho]=atmoscoesa(10000); CL=W/(0.5*rho*250^2*S); fprintf('CL=%.3f\n',CL)"

# Breguet range
ml eval "V=250; c_t=0.6/3600; LD=18; R=(V/c_t)*LD*log(1.4); fprintf('Range: %.0f km\n',R/1000)"
```

## ODE 仿真

```bash
# Van der Pol oscillator
ml solve --vanderpol --json | jq '{steps: .n_steps, t_final: .t_final}'

# Lorenz attractor
ml solve --lorenz --json

# Custom ODE
ml eval "f=@(t,x)[x(2);-sin(x(1))-0.1*x(2)]; [t,y]=ode45(f,[0 20],[1;0]); plot(t,y(:,1))"
```

## Optimization

```bash
# Rosenbrock (analytical min at [1,1])
ml optimize --rosenbrock --json | jq '{x: .x_opt, fval: .fval, iters: .iterations}'

# Himmelblau (4 local minima)
ml optimize --himmelblau --json | jq '{x: .x_opt, fval: .fval}'
```

## .mat File Operations

```bash
# List variables
ml mat list data.mat --json | jq '.variables[].name'

# Export to CSV
ml export data.mat --fmt csv --out output.csv

# Compare two .mat files
ml mat compare a.mat b.mat --json

# Merge multiple .mat
ml mat merge a.mat b.mat c.mat --out merged.mat --json
```

## Pipes & Composition

```bash
# Chain calculations
ml eval "randn(1000,1)" | ml eval "mean(ans)"
ml eval "magic(5)" | ml eval "eig(ans)"

# JSON pipeline with jq
ml bench --json | jq 'to_entries | sort_by(.value) | .[0]'
ml stats data.csv --json | jq '.columns[].mean'
ml signal audio.wav --fft --json | jq '.peak_freq'

# Generate data → analyze → plot
ml eval "randn(100,3)" > /tmp/data.txt
ml stats data.csv --json | jq '.columns[0].mean'
ml plot "plot(readmatrix('data.csv'))" --save plot.png
```

## Project Management

```bash
# Create new project
ml new my_analysis
cd my_analysis && ls  # src/ tests/ data/ results/ scripts/

# Generate template script
ml template simulation my_simulator

# Find existing scripts
ml skills aerospace

# Run script from skills repository
ml run --skills flight_dynamics

# Search documentation
ml doc fft
ml doc eig
ml doc ode45
```

## Environment

```bash
# MATLAB info
ml info --json | jq '{version: .version, toolboxes: (.toolboxes | length)}'

# Performance benchmarks
ml bench
ml bench --json | jq '{matrix: .matrix_multiply_1k, fft: .fft_1M}'

# Code quality check
ml lint script.m

# Generate project scaffold
ml template control my_controller
```

---

*Cookbook v1.0 — 2026-06-24*
