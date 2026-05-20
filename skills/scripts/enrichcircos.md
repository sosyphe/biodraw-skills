# 富集分析弦图（Enrichment Chord Diagram）

## 功能
基于 GOplot 绘制富集分析的弦图（Chord Diagram），展示通路与基因之间的关联关系，可选叠加 logFC 信息。

## 输入格式
**必填：**
| 参数 | 说明 |
|------|------|
| `--infile` | 通路-基因映射文件（需含 `Pathway` 和 `GeneInfo` 列，基因用 `/` 分隔） |

**可选：**
| 参数 | 说明 |
|------|------|
| `--infcfile` | logFC 文件（需含 `Index` 和 `log2FC` 列），提供后弦图颜色反映 logFC |

支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/enrichcircos.txt`

## 核心参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--infile` | 必填 | 通路-基因映射文件 |
| `--infcfile` | 无 | logFC 文件（可选） |
| `--outdir` | `./output` | 输出目录（相对于 Claude 工作目录） |
| `--ofiletype` | `png` | 输出格式：png/pdf/svg/pdf+png |
| `--title` | 无 | 图标题 |
| `--geneordertype` | `logFC` | 基因排序方式：logFC/alphabetical/none |
| `--legendlabel` | 无 | 图例名称 |
| `--legendcolnum` | `3` | 图例列数 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `12` | 图片宽度（英寸） |
| `--ofileheight` | `12` | 图片高度（英寸） |
| `--fontfamily` | `Times New Roman` | 字体 |
| `--fontsize` | `12` | 整体字体大小 |
| `--labelfontsize` | `10` | 标签字体大小 |
| `--genefontsize` | `4` | 基因名字体大小 |
| `--genewidthspace` | `0.25` | 基因间距 |
| `--logfcmincolor` | `firebrick3` | logFC 高值颜色（上调） |
| `--logfcmidcolor` | `white` | logFC 中间颜色 |
| `--logfcmaxcolor` | `royalblue3` | logFC 低值颜色（下调） |
| `--groupcolor` | 无 | 通路分组颜色，逗号分隔 |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪个数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 .claude/skills/biodraw/assets/testdata/enrichcircos.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入文件路径"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "logFC"
    question: "是否提供 logFC 文件？"
    options:
      - label: "不提供"
        description: "不叠加差异倍数信息，基因区域显示灰色"
      - label: "提供 logFC 文件"
        description: "请在 Other 中输入 logFC 文件路径（需含 Index 和 log2FC 列）"
  - header: "基因排序"
    question: "基因按什么方式排序？"
    options:
      - label: "logFC（推荐）"
        description: "按差异倍数排序"
      - label: "alphabetical"
        description: "按字母顺序排序"
      - label: "none"
        description: "不排序，保持输入顺序"
```

## 输出文件
`chord.pdf` / `.png` / `.svg`
