# 富集分析（Enrichment Analysis - ORA）

## 功能
基于超几何检验进行基因集富集分析，输出通路富集结果表格。

## 输入格式
**必填参数：**
| 参数 | 说明 |
|------|------|
| `--infile` | 差异基因列表（需含 `ID` 列） |
| `--refmapfile` | 背景注释文件（需含 `ID`、`PathwayID`、`PathwayDescription` 列） |

支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/enrichora.1.txt` / `.2.txt`

## 核心参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--infile` | 必填 | 输入文件（差异基因列表） |
| `--refmapfile` | 必填 | 背景注释文件 |
| `--outdir` | `./output` | 输出目录（相对于 Claude 工作目录） |
| `--fdrmethods` | `fdr_bh` | 校正方法：fdr_bh（Benjamini-Hochberg）/bonferroni/holm/simes-hochberg/hommel |
| `--ofiletype` | `png` | 输出格式：png/pdf/svg/pdf+png |

本工具参数较少，全部为核心参数，无高级参数。

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪组数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 enrichora.1.txt（基因列表）+ enrichora.2.txt（背景注释）"
      - label: "自己的文件"
        description: "请在 Other 中输入：基因列表路径 和 背景注释路径（空格分隔）"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "FDR校正"
    question: "使用哪种多重检验校正方法？"
    options:
      - label: "fdr_bh（推荐）"
        description: "Benjamini-Hochberg FDR 校正，最常用"
      - label: "bonferroni"
        description: "Bonferroni 校正，最严格"
      - label: "holm"
        description: "Holm 逐步校正"
```

## 输出文件
`EnrichORA.xlsx` / `EnrichORA.txt` — 含通路ID、描述、P值、FDR等
