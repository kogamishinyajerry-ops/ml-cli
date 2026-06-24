# MATLAB CLI 技能索引

> 跨 m/ml 双 CLI 体系的完整能力图谱。每一项都是实测通过的技能。

## 快速导航

| 想做什么 | 用哪个 CLI | 命令 |
|----------|-----------|------|
| 算个数学表达式 | ml eval | `ml eval "1+2"` |
| 运行 MATLAB 脚本 | ml run / m run | `ml run script.m` |
| 查函数文档 | ml doc | `ml doc fft` |
| 矩阵运算 | m matrix | `m matrix det "1 2;3 4"` |
| 单位换算 | ml convert / m convert | `ml convert 1 km m` |
| 画图 | ml plot | `ml plot "plot(sin(x))" --save out.png` |
| 数据分析 | m data / ml stats | `ml stats data.csv --json` |
| .mat 文件操作 | ml mat | `ml mat list data.mat` |
| 信号 FFT | ml signal | `ml signal audio.wav --fft` |
| 图像处理 | ml image | `ml image photo.png --info` |
| 模拟 ODE | ml solve | `ml solve --vanderpol` |
| 优化求解 | ml optimize | `ml optimize --rosenbrock` |
| 控制系统 | ml control | `ml control "tf(1,[1 2 1])"` |
| 航空计算 | ml aero | `ml aero --alt 10000` |
| 性能测试 | ml bench | `ml bench` |
| 代码检查 | ml lint | `ml lint script.m` |
| 创建项目 | ml new | `ml new my_project` |
| 生成模板 | ml template | `ml template simulation sim` |
| 查看环境 | ml info | `ml info --json` |
| 导出数据 | ml export | `ml export data.mat --fmt csv` |
| 交互 REPL | ml repl | `ml repl` |
| 定时监控 | ml watch | `ml watch -n 5 "rand"` |
| 浏览仓库脚本 | ml skills | `ml skills aerospace` |

## 命令矩阵 (m vs ml)

| 操作 | m(matlab-skills) | ml(ml-cli) |
|------|-----------------|------------|
| eval | `m eval "expr"` | `ml eval "expr"` |
| run | `m run -dir PATH script` | `ml run script.m` |
| plot | `m plot data.csv` | `ml plot "plot(x,y)" --save` |
| convert | `m convert val from to` | `ml convert val from to` |
| matrix | `m matrix det A` | `ml eval "det(A)"` |
| data | `m data file --stats` | `ml stats file --json` |
| info | `m info [file]` | `ml info` |
| help | `m help [cmd]` | `ml help [cmd]` |
| signal | — | `ml signal file --fft` |
| image | — | `ml image file --info` |
| control | — | `ml control "tf(...)"` |
| aero | — | `ml aero --alt H` |
| solve | — | `ml solve --vanderpol` |
| optimize | — | `ml optimize --rosenbrock` |
| doc | — | `ml doc function` |
| new | — | `ml new project` |
| template | — | `ml template type name` |
| mat | — | `ml mat list file.mat` |
| export | — | `ml export file.mat` |
| test | — | `ml test [dir]` |
| watch | — | `ml watch expr` |
| repl | — | `ml repl` |
| skills | — | `ml skills` |

## 管道能力

```
stdin  → ml eval → stdout
stdin  → ml stats → stdout
ml data → jq     → shell
ml bench → jq    → shell
```

## 环境变量

| 变量 | 用途 | 默认值 |
|------|------|--------|
| `MATLAB_BIN` | MATLAB 可执行文件 | `/Applications/MATLAB_R2026a.app/bin/matlab` |
| `MATLAB_SKILLS` | matlab-skills 仓库 | `~/matlab-skills` |
| `M_DEBUG` | 调试模式(1=显示发送的代码) | 0 |
| `M_TIMEOUT` | 超时(秒) | 120 |

## 学习路径

```
新手: ml eval → ml doc → ml convert → ml plot
进阶: ml stats → ml signal → ml solve → ml optimize
专业: ml control → ml aero → ml skills → ml run --skills
工程: ml new → ml template → ml mat → ml export
CLI 高手: 管道组合 → ml watch → ml repl → ml test
```

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `ml eval` 报 `%s` | 表达式含 `*` 被 shell glob | 用 `set -f` 或单引号包裹 |
| plot 无输出 | 参数顺序错了 | `--save file.png` 要在表达式后 |
| `ml doc` 无输出 | 函数名不存在 | run `ml info` 确认有对应 toolbox |
| `-batch` 不接受多行 | 已知限制 | 用管道/heredoc 传多行代码 |
| MATLAB 启动慢 | 每次新进程 | `ml repl` 持续会话 |
| JSON 格式不正确 | `jsonify` 不支持该类型 | 用 `disp()` 代替 |

---

*索引 v1.0 — 2026-06-24*
