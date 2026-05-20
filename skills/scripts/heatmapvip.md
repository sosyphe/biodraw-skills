# VIP 棒棒糖热图（VIP Lollipop Heatmap）

## 功能
绘制 VIP（Variable Importance in Projection）棒棒糖图 + 分组均值热图，常用于 PLS-DA/OPLS-DA 分析结果展示。

## 输入格式
**必填：**
| 参数 | 说明 |
|------|------|
| `--infile` | 数据文件（第一列为特征名 `Index`，需含 `VIP` 列，其余列为样本数值） |
| `--insamplefile` | 样本分组文件（需含 `sample` 和 `group` 列） |

支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/heatmapvip.txt` + `heatmapvip.sample.txt`

## 核心参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--infile` | 必填 | 数据文件（含 VIP 列和样本列） |
| `--insamplefile` | 必填 | 样本分组文件（含 sample 和 group 列） |
| `--outdir` | `./output` | 输出目录（相对于 Claude 工作目录） |
| `--ofiletype` | `pdf` | 输出格式：png/pdf/svg/pdf+png |
| `--drawtopN` | `20` | 显示前 N 个特征 |
| `--sortorder` | `desc` | VIP 排序：desc（降序）/asc（升序） |
| `--title` | 无 | 图标题 |
| `--colorlist` | 无 | 自定义颜色列表，逗号分隔 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `12` | 图片宽度（英寸） |
| `--ofileheight` | `8` | 图片高度（英寸） |
| `--fontfamily` | `Times New Roman` | 字体 |
| `--fontsize` | `12` | 整体字体大小 |
| `--titletextsize` | `1.5` | 标题字体缩放倍数 |
| `--dotxlabelsize` | `1.3` | 棒棒糖点大小 |
| `--labeltextsize` | `1` | 标签字体缩放倍数 |
| `--heatmaptextsize` | `1` | 热图标签字体缩放倍数 |
| `--labelfold` | `yes` | 标签是否折行：yes/no |
| `--labelrotation` | `45` | 热图列标签旋转角度 |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪组数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 heatmapvip.txt + heatmapvip.sample.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入：数据文件路径 和 样本分组文件路径（空格分隔）"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "TopN"
    question: "显示前多少个特征？"
    options:
      - label: "20（默认）"
        description: "显示 VIP 最高的前 20 个"
      - label: "10"
        description: "显示前 10 个"
      - label: "30"
        description: "显示前 30 个"
  - header: "排序"
    question: "VIP 排序方式？"
    options:
      - label: "desc（推荐）"
        description: "降序，VIP 最高的在上"
      - label: "asc"
        description: "升序，VIP 最低的在上"
```

## 输出文件
`VIP_lollipopheatmap.pdf` / `.png` / `.svg`
