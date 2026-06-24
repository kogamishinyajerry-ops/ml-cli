# ml — MATLAB CLI: "CLI Anything" 项目设计文档

> 把 MATLAB 从重 GUI IDE 变成 Unix CLI 一等公民。
> 设计哲学: Unix 管道 + JSON 结构化输出 + 零 GUI 依赖。

---

## 1. 核心架构

```
┌─────────────────────────────────────────────────────┐
│  终端 (bash/zsh)                                    │
│  ├─ $ ml eval "1+1"          → stdout: 2           │
│  ├─ $ echo "rand(3)" | ml    → stdout: <matrix>    │
│  ├─ $ ml run sim.m --json    → stdout: {json}      │
│  ├─ $ ml plot "surf(v)" --save out.png              │
│  ├─ $ ml lint script.m       → stdout: diagnostics │
│  ├─ $ ml info                → stdout: env info    │
│  └─ $ ml bench               → stdout: perf stats  │
│                                                      │
│  ↓ shell wrapper (bin/ml)                           │
│      ├─ 参数解析 (getopt)                            │
│      ├─ stdin 管道检测                               │
│      ├─ 构造 MATLAB -batch 命令                      │
│      └─ 后处理输出 (JSON/Table 格式化)                │
│                                                      │
│  ↓ MALTAB 侧 (matlab/*.m)                           │
│      ├─ jsonify.m     数据→JSON                    │
│      ├─ to_table.m    数据→Markdown table           │
│      ├─ cli_entry.m   命令行入口                    │
│      └─ lint_check.m  代码静态分析                  │
└─────────────────────────────────────────────────────┘
```

## 2. 子命令矩阵

| 子命令 | 功能 | stdin | 输出格式 | 示例 |
|--------|------|-------|---------|------|
| `eval` | 内联计算表达式 | 支持 | text/json/table | `ml eval "eig(rand(3))"` |
| `run` | 执行 .m 脚本 | — | stdout+file | `ml run optimize.m` |
| `plot` | 生成图片 | — | png/svg | `ml plot "plot(sin)" --save sin.png` |
| `lint` | 代码风格检查 | — | text | `ml lint script.m` |
| `info` | 环境信息 | — | json/table | `ml info --json` |
| `bench` | 性能基准 | — | json/table | `ml bench` |
| `fmt` | 代码格式化 | 支持 | stdout | `ml fmt script.m` |

## 3. 输出模式

- **默认 (text)**: 人类可读,精简
- **`--json`**: 机器可读,可 pip 给 `jq .`
- **`--table`**: Markdown 表格,适合文档/报告
- **`--csv`**: CSV 格式,适合导入 Excel/Pandas

## 4. 管道设计

```bash
# 从 stdin 读表达式
echo "sin(pi/2)" | ml eval
# → 1

# 命令行参数
ml eval "1 + 2 * 3"
# → 7

# pip 给 jq 解析
ml bench --json | jq '.matrix_multiply.time_ms'

# 生成图片管道
ml plot "plot(rand(100,1))" --save - | feh -
```

## 5. ml 命令入口 (bin/ml)

```bash
#!/bin/bash
# ml — MATLAB CLI 入口
# 用法: ml <subcommand> [options] [args...]
#   ml eval "1+1"         内联计算
#   ml run script.m       执行脚本
#   ml plot "surf(peaks)" 绘图
#   ml lint file.m        代码检查
#   ml info               环境信息
#   ml bench              性能测试
```

## 6. MATLAB 侧辅助函数

### jsonify.m
```matlab
function jsonify(data, varargin)
% 将 MATLAB 数据转为 JSON 并打印到 stdout
% 支持: double, cell, struct, table, string
% 用法: jsonify(result)
%       jsonify(x, 'format', 'pretty')
```

### to_table.m
```matlab
function to_table(data, varargin)
% 将 MATLAB 数据转为 Markdown 表格
% 支持: matrix, table, struct array
```

### cli_entry.m
```matlab
function cli_entry(command, args)
% MATLAB 侧命令行入口,被 ml shell 脚本调用
% 解析命令,执行,格式化输出
```

## 7. 安装方式

```bash
# 添加到 PATH
git clone ... ml-cli
echo 'export PATH="$HOME/ml-cli/bin:$PATH"' >> ~/.zshrc
```

## 8. 与现有生态的关系

- **不是替代 MATLAB IDE**:仍用 IDE 写复杂代码,用 `ml` 做快捷操作
- **不是替代 Python**:数值计算管道工具,和 `python -c` 互补
- **互补 matlab-skills**:`ml` 让 skills 仓库里的 .m 脚本可以一行命令执行

---

*架构设计 v1.0 · 2026-06-24*
