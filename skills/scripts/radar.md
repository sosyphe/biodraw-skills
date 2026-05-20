# 雷达图（Radar Chart）

## 功能
基于 matplotlib 绘制雷达图，支持多边形/圆形，输入为数值矩阵。

## 输入格式
第一列：样本名（字符串，不可重复）；后续列：数值变量。
支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/radar.txt`

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
| `--radartype` | `polygon` | 雷达图形状：polygon（多边形）/circle（圆形） |
| `--alpha` | `0.2` | 填充透明度（0-1） |
| `--markersize` | `5` | 标记点大小 |
| `--title` | 无 | 图标题 |
| `--colorlist` | 无 | 自定义颜色列表，逗号分隔 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `8` | 图片宽度（英寸） |
| `--ofileheight` | `6` | 图片高度（英寸） |
| `--fontfamily` | 自动检测 | 字体（留空则自动检测系统字体） |
| `--fontsize` | `12` | 字体大小 |
| `--tickangle` | `0` | 刻度标签旋转角度 |
| `--legendtitle` | 无 | 图例标题 |
| `--titleposition` | `center` | 标题位置：left（左）/center（中）/right（右） |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪个数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 .claude/skills/biodraw/assets/testdata/radar.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入文件路径"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "形状"
    question: "雷达图使用哪种形状？"
    options:
      - label: "polygon（推荐）"
        description: "多边形雷达图，默认样式"
      - label: "circle"
        description: "圆形雷达图"
```

## 输出文件
`radar.pdf` / `radar.png` / `radar.svg`
