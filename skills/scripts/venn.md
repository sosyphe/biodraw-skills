# Venn 图（Venn Diagram）

## 功能
基于 matplotlib 绘制 Venn 图，支持 1-6 组普通/成比例 Venn 图。

## 输入格式
第一列：集合名；后续列：该集合的元素。
支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/venn.txt`

## 必填参数
| 参数 | 说明 |
|------|------|
| `--infile` | 输入文件路径 |

## 核心参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--infile` | 必填 | 输入数据文件路径 |
| `--outdir` | `./output` | 输出目录（相对于 Claude 工作目录） |
| `--ofiletype` | `pdf+png` | 输出格式：png/pdf/svg/pdf+png |
| `--filltype` | `number+percent` | 填充类型：number（数值）/percent（百分比）/number+percent（数值+百分比） |
| `--drawstyle` | `normal` | 绘图样式：normal（普通 Venn）/ratio（成比例 Venn） |
| `--title` | 无 | 图标题 |
| `--colorlist` | 无 | 颜色列表，逗号分隔 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `8` | 图片宽度（英寸） |
| `--ofileheight` | `8` | 图片高度（英寸） |
| `--fontfamily` | 自动检测 | 字体（留空则自动检测系统字体） |
| `--fontsize` | `12` | 字体大小 |
| `--titleposition` | `center` | 标题位置：left/center/right |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪个数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 .claude/skills/biodraw/assets/testdata/venn.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入文件路径"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "样式"
    question: "Venn 图绘制样式？"
    options:
      - label: "normal（推荐）"
        description: "普通 Venn 图，圆/椭圆大小一致"
      - label: "ratio"
        description: "成比例 Venn 图，面积反映集合大小（仅支持2-3组）"
  - header: "填充"
    question: "区域内显示什么？"
    options:
      - label: "number+percent（推荐）"
        description: "同时显示数值和百分比"
      - label: "number"
        description: "仅显示数值"
      - label: "percent"
        description: "仅显示百分比"
```

## 输出文件
`Venn.pdf` / `Venn.png` / `Venn.xlsx`
