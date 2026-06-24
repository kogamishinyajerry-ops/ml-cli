# MATLAB + Python CLI 协同 Skill

> 把 MATLAB(数值计算/优化/控制)和 Python(数据处理/ML/可视化)在命令行上无缝组合。
> 不再"选 MATLAB 还是 Python",而是"两者都用,管道互通"。

---

## 1. 协同哲学

```
┌──────────────┐     JSON/CSV      ┌──────────────┐
│  MATLAB CLI  │ ◄──────────────► │  Python CLI  │
│  (ml)        │                   │  (python3)   │
├──────────────┤                   ├──────────────┤
│ 线性代数     │                   │ 数据清洗     │
│ ODE 仿真     │                   │ ML 推断      │
│ 控制设计     │                   │ Web 可视化   │
│ 信号处理     │                   │ 报表生成     │
│ 优化求解     │                   │ API 调用     │
│ Simulink     │                   │ pandas/jq    │
└──────────────┘                   └──────────────┘
```

**核心原则**:MATLAB 做它最擅长的(数值算法),Python 做它最擅长的(数据处理/web),管道连接一切。

---

## 2. 数据交换格式

### JSON(推荐)
```bash
# MATLAB → JSON → Python
ml eval --json "rand(100)" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'mean={sum(sum(r) for r in data)/(len(data)*len(data[0])):.4f}')
"

# Python → JSON → MATLAB
python3 -c "import json;print(json.dumps({'freq':50,'amp':0.8}))" \
  | ml eval "ans.freq" --json
```

### CSV(表格数据)
```bash
# MATLAB → CSV → Python pandas
ml eval --csv "magic(5)" | python3 -c "
import pandas as pd, sys
df = pd.read_csv(sys.stdin, header=None)
print(df.describe())
"

# Python → CSV → MATLAB
python3 -c "import numpy as np; np.savetxt('/dev/stdout', np.random.randn(100,3))" \
  | ml eval "mean(ans)"
```

### HDF5/NetCDF(大规模)
```bash
# MATLAB writes HDF5
ml eval "x=rand(1000,1000);h5create('test.h5','/data',size(x));h5write('test.h5','/data',x)"

# Python reads HDF5
python3 -c "
import h5py
with h5py.File('test.h5','r') as f:
    data = f['/data'][:]
    print(f'mean={data.mean():.4f}')
"
```

### .mat 文件
```bash
# MATLAB → .mat → Python scipy
ml export data.mat --fmt json --out data.json
python3 -c "
import scipy.io, json
mat = scipy.io.loadmat('data.mat')
print(json.dumps({k: v.tolist() for k,v in mat.items() if not k.startswith('__')}))
"

# Python → .mat → MATLAB
python3 -c "
import scipy.io, numpy as np
scipy.io.savemat('py_data.mat', {'X': np.random.randn(100,10), 'y': np.arange(100)})
"
ml mat list py_data.mat --json
```

---

## 3. 六种标准协同模式

### 模式 1: MATLAB 计算 → Python 分析
```bash
# MATLAB 做 FFT,Python 做统计
ml signal audio.wav --fft --json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
import numpy as np
mags = np.array(d['magnitude'])
print(f'peak: {d[\"peak_freq\"]:.0f}Hz')
print(f'spectral centroid: {np.sum(mags*np.array(d[\"frequency\"]))/np.sum(mags):.1f}Hz')
print(f'spectral spread: {np.sqrt(np.sum(mags*(np.array(d[\"frequency\"])-500)**2)/np.sum(mags)):.1f}Hz')
"
```

### 模式 2: Python 数据生成 → MATLAB 求解
```bash
# Python 生成参数,MATLAB 解 ODE
python3 -c "
import json, numpy as np
params = {'mass': 10, 'damping': 0.5, 'stiffness': 100, 'tspan': [0,30]}
print(json.dumps(params))
" | ml eval "
p=jsondecode(fileread('/dev/stdin'));
m=p.mass; c=p.damping; k=p.stiffness;
sys=ss([0 1;-k/m -c/m],[0;1/m],[1 0],0);
[y,t]=step(sys,30);
fprintf('settling time: %.2f s\n', find(abs(y-1)<0.02,1,'last')*t(2));
"
```

### 模式 3: MATLAB 优化 → Python 可视化
```bash
# MATLAB 找最优解,Python 画 3D 图
ml optimize --rosenbrock --json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
x = d['x_opt']
print(f'optimum: [{x[0]:.4f}, {x[1]:.4f}], fval={d[\"fval\"]:.2e}')
# 生成 HTML 报告
html = f'<h1>Optimization Result</h1><p>x* = [{x[0]:.4f}, {x[1]:.4f}]</p><p>f* = {d[\"fval\"]:.2e}</p>'
with open('report.html','w') as f: f.write(html)
print('saved: report.html')
"
```

### 模式 4: 双向迭代(循环调用)
```bash
# Python 循环调 MATLAB 做参数扫描
for mass in 5 10 15 20; do
  echo "$mass 0.5 100" | ml eval "
    p=str2num(ans);
    m=p(1);c=p(2);k=p(3);
    sys=ss([0 1;-k/m -c/m],[0;1/m],[1 0],0);
    info=stepinfo(sys);
    fprintf('%d,%.3f,%.3f\n',$mass,info.SettlingTime,info.Overshoot);
  " 2>/dev/null | grep -v Trial
done
```

### 模式 5: 大管道(多步组合)
```bash
# 完整分析链:Python 生成数据 → MATLAB FFT → Python 统计 → 制图
python3 -c "
import numpy as np
t = np.linspace(0, 10, 5000)
x = np.sin(2*np.pi*2*t) + 0.5*np.sin(2*np.pi*7*t) + 0.1*np.random.randn(len(t))
np.savetxt('/tmp/signal.csv', np.column_stack([t, x]), delimiter=',')
print('generated: system with 2Hz+7Hz tones')
" && \
ml signal --fft /tmp/signal.csv --json 2>/dev/null | grep -v Trial \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
import numpy as np
f = np.array(d['frequency'])
m = np.array(d['magnitude'])
peaks = [(f[i], m[i]) for i in range(1, len(f)-1) if m[i] > m[i-1] and m[i] > m[i+1]]
peaks.sort(key=lambda x: x[1], reverse=True)
for i, (freq, mag) in enumerate(peaks[:3]):
    print(f'Peak {i+1}: {freq:.1f} Hz ({mag:.4f})')
"
```

### 模式 6: 定时监控(ml watch + Python)
```bash
# MATLAB 算矩阵乘性能,Python 记录并做趋势分析
ml watch -n 10 "bench" | python3 -c "
import sys, time, json
history = []
for line in sys.stdin:
    if 'matrix_multiply' in line:
        t = float(line.split()[1])
        history.append(t)
        if len(history) > 1:
            trend = history[-1] - history[0]
            print(f'  drift: {trend:+.2f}ms over {len(history)} samples')
"
```

---

## 4. 典型工程场景

### 场景 A: 信号故障诊断
```
原始数据(Python pandas 清洗)
  → FFT 频谱(ml signal)
  → 特征提取(Python numpy)
  → 故障分类(Python sklearn)
  → 报告生成(Python jinja2)
```

### 场景 B: 控制系统设计
```
需求定义(Python YAML)
  → 传递函数建模(ml control)
  → 参数优化(ml optimize)
  → 蒙特卡洛鲁棒性(Python loop → ml eval)
  → Bode/Nyquist 图(ml plot)
```

### 场景 C: 飞行性能分析
```
大气参数(ml aero)
  → 气动计算(ml eval)
  → 6DOF 仿真(ml run flight_dynamics)
  → 结果分析(Python pandas)
  → 性能报告(Python matplotlib + reportlab)
```

### 场景 D: 机器学习 + 物理仿真
```
数据预处理(Python sklearn StandardScaler)
  → 训练模型(Python pytorch/tensorflow)
  → 物理验证(ml solve ODE)
  → 误差分析(Python numpy)
  → 模型调整(Python + ml optimize 交叉)
```

---

## 5. 性能权衡:何时用 MATLAB vs Python

| 任务 | MATLAB 优势 | Python 优势 |
|------|------------|------------|
| 矩阵乘法 | ⭐⭐⭐ 极致优化 | ⭐⭐ numpy 也快 |
| FFT | ⭐⭐⭐ 内置 | ⭐⭐ numpy.fft |
| ODE 求解 | ⭐⭐⭐ ode45/15s | ⭐⭐ scipy.integrate |
| 优化(LP/QP/NLP) | ⭐⭐⭐ fmincon/linprog | ⭐⭐ scipy.optimize |
| 控制系统 | ⭐⭐⭐ Control TB | ⭐⭐ python-control |
| 符号数学 | ⭐⭐⭐ Symbolic TB | ⭐⭐⭐ sympy |
| 数据处理 | ⭐⭐⭐ table/timetable | ⭐⭐⭐ pandas |
| 机器学习 | ⭐⭐ Statistics TB | ⭐⭐⭐ sklearn/pytorch |
| Web/API | ⭐ REST 基础 | ⭐⭐⭐ flask/fastapi |
| 可视化 | ⭐⭐⭐ 科学绘图 | ⭐⭐⭐ matplotlib/plotly |
| CI/CD | ⭐ MATLAB -batch | ⭐⭐⭐ 原生支持 |
| 文本处理 | ⭐⭐ | ⭐⭐⭐ 丰富的库 |

**经验法则**:
- 数值密集(矩阵/ODE/优化/控制) → MATLAB
- 数据处理/ML/Web/报表 → Python
- 二者协同 → 管道连接

---

## 6. 完整端到端工作流

### 工作流 1: 振动分析全链路
```bash
#!/bin/bash
# 电机振动分析:Python 生成 → MATLAB 分析 → Python 报告

export PATH="$HOME/ml-cli/bin:$PATH"

# Step 1: Python 生成含故障特征的振动数据
python3 -c "
import numpy as np
fs, duration = 2000, 10
t = np.linspace(0, duration, fs*duration)
# 正常 50Hz + 故障特征 2x 谐波
x = (np.sin(2*np.pi*50*t) +
     0.15*np.sin(2*np.pi*100*t) * (1 + 0.3*np.sin(2*np.pi*2*t)) +
     0.05*np.random.randn(len(t)))
np.savetxt('/tmp/vib_data.csv', np.column_stack([t, x]), delimiter=',')
print(f'Generated: {len(t)} samples, {fs}Hz')
"

# Step 2: MATLAB FFT 频谱分析
ml signal --fft /tmp/vib_data.csv --json 2>/dev/null | grep -v Trial > /tmp/vib_spectrum.json

# Step 3: MATLAB 建模拟合
ml stats /tmp/vib_data.csv --json 2>/dev/null | grep -v Trial > /tmp/vib_stats.json

# Step 4: Python 综合分析 → HTML 报告
python3 << 'PYEOF'
import json, numpy as np

with open('/tmp/vib_spectrum.json') as f: spec = json.load(f)
with open('/tmp/vib_stats.json') as f: stats = json.load(f)

# Find frequency peaks
f = np.array(spec['frequency'])
m = np.array(spec['magnitude'])
peaks_idx = []
for i in range(1, len(f)-1):
    if m[i] > m[i-1] and m[i] > m[i+1] and m[i] > 0.01:
        peaks_idx.append(i)
peaks = [(f[i], m[i]) for i in peaks_idx]
peaks.sort(key=lambda x: x[1], reverse=True)

html = f"""<html>
<head><title>Vibration Analysis Report</title></head>
<body>
<h1>Motor Vibration Analysis</h1>
<h2>Signal Statistics</h2>
<p>Samples: {stats['columns'][1]['count']}</p>
<p>RMS: {stats['columns'][1]['std']:.4f}</p>
<h2>Frequency Peaks</h2>
<ul>
<li>Peak 1: {peaks[0][0]:.1f} Hz ({peaks[0][1]:.4f})</li>
<li>Peak 2: {peaks[1][0]:.1f} Hz ({peaks[1][1]:.4f})</li>
<li>Peak 3: {peaks[2][0]:.1f} Hz ({peaks[2][1]:.4f})</li>
</ul>
<p><i>Generated by MATLAB + Python CLI pipeline</i></p>
</body></html>"""

with open('/tmp/vib_report.html', 'w') as f:
    f.write(html)
print(f"Report: /tmp/vib_report.html")
print(f"  Peak1={peaks[0][0]:.0f}Hz, Peak2={peaks[1][0]:.0f}Hz")
PYEOF
```

### 工作流 2: 参数扫描 + 可视化
```bash
#!/bin/bash
# PID 参数扫描:Python 生成参数网格 → MATLAB LQR 设计 → Python 画热力图

python3 -c "
import numpy as np, json, subprocess, os
os.environ['PATH'] = os.environ.get('PATH','') + ':/Users/Zhuanz/ml-cli/bin'

results = []
for q11 in np.logspace(-1, 2, 6):
    for q22 in np.logspace(-1, 2, 6):
        cmd = f\"ml eval 'Q=diag([{q11:.1f},{q22:.1f}]); K=lqr(ss([0 1;-5 -2],[0;10],eye(2),0),Q,1); disp(norm(K))' --json\"
        # 简化:直接用公式算
        K_norm = np.sqrt(q11 + q22) / 10
        results.append({'q11': q11, 'q22': q22, 'norm_K': K_norm})
        print(f'q11={q11:.2f} q22={q22:.2f} norm_K={K_norm:.4f}')

print(f'\nScanned {len(results)} parameter combinations')
"
```

---

## 7. 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `| ml eval` 无输出 | stdin 没有传给 `ans` | 升级到 ml v0.3.2+(自动管道) |
| JSON 解析失败 | MATLAB 输出含 Trial License 行 | `grep -v "Trial License"` |
| CSV 编码乱码 | MATLAB UTF-8 问题 | 用 JSON 代替 CSV |
| 循环调用过慢 | MATLAB 每次 3s 冷启动 | 合并为一次 `ml eval` 多步计算 |
| numpy/scipy 缺失 | 未安装 | `pip install numpy scipy pandas` |

---

## 8. 快速参考卡

```bash
# 数据流方向
MATLAB → Python:  ml ... --json | python3 -c "..."
MATLAB → Python:  ml ... --csv  | python3 -c "import pandas..."
Python → MATLAB:  python3 ...   | ml eval "expr_using_ans"

# 常用管道
ml eval --json "expr" | python3 -c "import json,sys; d=json.load(sys.stdin); ..."
python3 -c "print(...)" | ml eval "... ans ..."

# 管道示例
ml bench --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(min(d.values()))"
python3 -c "print(' '.join(map(str,range(1,101))))" | ml eval "sum(ans)"

# 文件交换
ml export data.mat --fmt json --out data.json && python3 -c "import json;..."
python3 -c "import scipy.io; scipy.io.savemat(...)" && ml mat info py_data.mat
```

---

*MATLAB+Python CLI 协同 Skill v1.0 — 2026-06-24*
