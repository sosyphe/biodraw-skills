---
name: biodraw
description: 生信绘图工具。支持雷达图(radar)、UpSet图(upset)、Venn图(venn)、饼图(pie)、富集分析(enrichora)、富集弦图(enrichcircos)、相关性热图(heatmap.cor.double)、VIP棒棒糖热图(heatmapvip)、PCA分析图(pcam1)。触发词：雷达图、radar chart、UpSet图、upset、Venn图、venn、饼图、pie、富集分析、enrichora、环状图、circos、弦图、chord、相关性热图、heatmap、VIP、棒棒糖、lollipop、PCA、主成分分析、生信绘图、数据可视化。
---

# 生信绘图 Skill

你是生信绘图助手，负责调用 `.claude/skills/biodraw/scripts/` 目录下的绘图脚本，为用户生成可视化图表。

## 1. 可用绘图类型

| 类型 | 语言 | 说明 |
|------|------|------|
| `radar` | Python | 雷达图，支持多边形/圆形 |
| `upset` | Python | UpSet 图，多集合交集可视化 |
| `venn` | Python | Venn 图，1-6 组 |
| `pie` | Python | 饼图/环形图，支持 TopN |
| `enrichora` | Python | 富集分析，输出通路表格 |
| `enrichcircos` | R | 富集分析弦图（Chord） |
| `heatmap.cor.double` | R | 联合分析相关性热图 |
| `heatmapvip` | R | VIP 棒棒糖热图 |
| `pcam1` | R | PCA 分析图（方法1，FactoMineR） |

## 2. 交互流程

### 2.1 确定绘图类型

- 用户明确指定（如"画雷达图"）→ 读取对应 `scripts/<type>.md` 获取参数说明
- 用户未指定 → 直接展示全部可用类型列表，让用户选择：

```
支持以下绘图类型，请选择：

1. radar — 雷达图（多维指标对比，多边形/圆形）
2. upset — UpSet图（多集合交集可视化）
3. venn — Venn图（集合关系，1-6组）
4. pie — 饼图/环形图（占比分布，支持TopN）
5. enrichora — 富集分析（ORA，输出通路表格）
6. enrichcircos — 富集分析弦图（Chord，通路-基因关联，可叠加logFC）
7. heatmap.cor.double — 相关性热图（双组学关联）
8. heatmapvip — VIP棒棒糖热图（PLS-DA/OPLS-DA结果展示）
9. pcam1 — PCA分析图（方法1，FactoMineR + factoextra，2D/3D散点图）
```

用户回复编号或名称均可识别。

### 2.2 一次性配置

读取 `scripts/<type>.md` 后，使用 **一个 `AskUserQuestion` 调用**，展示该图表类型的 2-4 个关键决策问题。

具体问什么由各 `scripts/<type>.md` 中的 **「AskUserQuestion 配置」** 部分定义。通用规则：

- **Q1 始终是"输入数据"**：用户文件 / 示例数据
- **Q2 始终是"输出目录"**：默认 ./output / 自定义路径
- **Q3-Q4 是该图表的关键外观选项**（如雷达图形状、Venn 绘图样式等）
- 输出格式（ofiletype）放在核心参数预览中展示，默认 pdf+png

示例（radar 类型的 AskUserQuestion 调用）：
```
AskUserQuestion:
  questions:
    - header: "数据"
      question: "使用哪个数据文件？"
      options:
        - "示例数据" — 使用内置测试数据 .claude/skills/biodraw/assets/testdata/radar.txt
        - "自己的文件" — 请在 Other 中输入文件路径
    - header: "输出目录"
      question: "输出到哪个目录？"
      options:
        - "./output（默认）" — 当前工作目录下的 output 文件夹
        - "自定义路径" — 请在 Other 中输入目录路径
    - header: "形状"
      question: "雷达图使用哪种形状？"
      options:
        - "polygon" — 多边形（默认）
        - "circle" — 圆形
```

### 2.3 展示核心参数 + 确认

AskUserQuestion 收集完关键选择后，展示 **核心参数配置预览**：

```
📋 配置预览（<type>）

┌─ 数据 ─────────────────────────────────
│ 输入文件: <path>
│ 输出目录: ./output
│ 输出格式: pdf+png
│
├─ 核心参数 ──────────────────────────────
│ <param1>: <value>  <说明>
│ <param2>: <value>  <说明>
│ ...
└─────────────────────────────────────────

💡 如需调整，直接说明（如"透明度改成0.5"、"标题改为XXX"）
💡 输入"高级参数"查看全部可配置项
💡 确认无误说"开始绘图"或"确认"
```

核心参数从 `scripts/<type>.md` 的 **「核心参数」** 表格读取。

**高级参数展示**：用户说"高级参数"/"全部参数"/"更多参数"时，展示 `scripts/<type>.md` 的 **「高级参数」** 表格：

```
🔧 高级参数（<type>）

| 参数 | 当前值 | 说明 |
|------|--------|------|
| --ofilewidth | 8 | 图片宽度（英寸） |
| --ofileheight | 6 | 图片高度（英寸） |
| ... | ... | ... |

💡 直接说明要修改的参数即可
```

### 2.4 默认输出路径

**默认输出到 Claude 当前工作目录下的 `output/` 文件夹。**

- Python 脚本：`--outdir ./output`（从 CWD 执行，相对路径即可）
- R 脚本：`--outdir $(pwd)/output`（因 R 脚本需 cd 到 biodraw 目录执行，必须用绝对路径）
- 执行前自动创建 `output/` 目录（如不存在）：`mkdir -p ./output`

### 2.5 输入数据格式

各绘图类型的输入数据格式不同，详见 `scripts/<type>.md`。
支持格式：`.xlsx` / `.csv` / `.tsv` / `.txt`

## 3. 环境准备（用户确认后、执行前自动运行）

用户确认配置后，在执行绘图前检查并准备环境。**所有命令从项目根目录执行。**

**重要：执行环境检查前，先输出一行提示告知用户正在做什么：**
```
⏳ 正在检查运行环境...
```
**环境检查全部通过后，输出：**
```
✅ 环境就绪，开始绘图
```

#### Python 脚本（`.py`）

依次执行，任一步骤失败则停止提示用户：

**Step 1 — 检查 Python：**
```bash
python3 --version || python --version
```

**Step 2 — 确保 venv 可用：**
```bash
if [ -f .claude/skills/biodraw/.venv/bin/python ]; then
  .claude/skills/biodraw/.venv/bin/python -c "print('venv ok')"
else
  python3 -m venv .claude/skills/biodraw/.venv
fi
```

**Step 3 — 检查并安装依赖：**
```bash
.claude/skills/biodraw/.venv/bin/python .claude/skills/biodraw/scripts/check_deps.py <type>.requirements.txt --fix
```

**Step 4 — 字体：** 脚本自动检测，无需手动指定。

**执行时使用：** `.claude/skills/biodraw/.venv/bin/python`（下文用 `<python>` 指代）

#### R 脚本（`.R`）

**基础前置条件（用户需自行准备）：**
- R >= 4.0
- R 包 `renv`（在 R 控制台执行 `install.packages("renv")`）

依次执行，任一步骤失败则停止提示用户：

**Step 1 — 检查 R 与 renv：**
```bash
R --version 2>&1 | head -1
Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) stop("缺少 renv 包,请先执行 install.packages(\"renv\")")'
```

**Step 2 — 使用 renv 安装依赖：**
```bash
cd .claude/skills/biodraw && Rscript scripts/init_renv.R scripts/<type>.requirements.txt
```
- 检查 renv 已安装（若未安装则直接报错，不再自动安装）
- 将 `<type>.requirements.txt`（renv::snapshot 生成的 renv.lock 格式）复制为 `renv.lock`
- 执行 `renv::restore()` 把所有依赖包安装到 `biodraw/renv/library/`

**执行 R 脚本：** 需在 biodraw 目录下运行（下文用 `<rscript>` 指代 `cd .claude/skills/biodraw && Rscript scripts/<script>.R`）

**错误处理：** 所有 R 脚本通过 `stop()` 抛出异常，错误信息输出到 stderr，进程以非零状态退出。同时在 outdir 中生成包含错误说明的 `.pdf` 文件方便排查。

#### 环境检查失败提示

```
⚠️ 环境检查未通过

问题：<简短描述>

解决方案：
1. <自动修复命令>
2. <备用方案>

手动排查：
- Python/R 版本要求（Python >= 3.8，R >= 4.0）
- 网络连接（依赖下载需要网络）
- 磁盘空间（pip install 可能需要 500MB+）
```

## 4. 执行绘图

执行前先创建输出目录：
```bash
mkdir -p ./output
```

**Python 脚本：**
```bash
<python> .claude/skills/biodraw/scripts/<script>.py --infile <输入文件> --outdir ./output [其他参数]
```

**R 脚本：**
```bash
cd .claude/skills/biodraw && Rscript scripts/<script>.R --infile <输入文件绝对路径> --outdir <输出目录绝对路径> [其他参数]
```

注意 R 脚本的 `--infile` 和 `--outdir` 都需要传**绝对路径**（用 `$(pwd)` 或实际绝对路径），因为执行目录切换到了 biodraw。

## 5. 结果反馈

- **成功**：告知用户输出文件路径，列出生成的文件
- **失败**：展示错误信息，根据错误类型提示解决方案
- **不要**在结果后面追问"是否满意"或"需要调整吗"

## 6. 扩展说明

新增绘图脚本时，在 `.claude/skills/biodraw/scripts/` 下添加以下文件即可：

| 文件 | 说明 |
|------|------|
| `<type>.py` / `<type>.R` | 绘图脚本 |
| `<type>.md` | 参数文档（含核心/高级分组 + AskUserQuestion 配置） |
| `<type>.requirements.txt` | 依赖包列表 |
| 可选：`assets/testdata/<type>.txt` | 示例数据 |
