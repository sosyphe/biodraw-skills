# 饼图（Pie Chart）

## 功能
基于 matplotlib 或 Plotly 绘制饼图/环形图，支持 TopN 筛选、百分比显示、图例自定义。

## 输入格式
第一列为类别名，后续列为数值（用 `--choosedcol` 选择绘图列）。
支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/pie.txt`

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
| `--choosedcol` | 第2列 | 选择用于绘图的数据列 |
| `--drawtype` | `all` | 绘图类型：top（仅 TopN）/all（全部，超出归为"其他"） |
| `--topN` | `10` | 显示前 N 个类别，其余归为"其他" |
| `--showpercent` | `all` | 百分比显示：label/percent/number/all/nothing |
| `--title` | 无 | 图标题 |
| `--drawstyle` | `style1` | 绘图引擎：style1（matplotlib）/style2（plotly） |
| `--donutwidth` | `1` | 环形比例（0-1），1=饼图，<1=环形图 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `10` | 图片宽度（英寸） |
| `--ofileheight` | `8` | 图片高度（英寸） |
| `--fontfamily` | 自动检测 | 字体（留空则自动检测系统字体） |
| `--fontsize` | `12` | 字体大小 |
| `--legendtitle` | 无 | 图例标题 |
| `--showlegendtype` | `text+count+percent` | 图例显示：nothing/text/text+count/text+percent/text+count+percent |
| `--showpercentlabelpos` | `center` | 百分比标签位置：center（中心）/outer（外侧） |
| `--otherslabel` | `Others` | "其他"分类的标签名 |
| `--startangle` | `0` | 起始角度（度） |
| `--ifsortbycount` | `yes` | 是否按计数排序：yes/no |
| `--decimalplaces` | `1` | 百分比小数位数 |
| `--titleposition` | `center` | 标题位置：left/center/right |
| `--colorlist` | 无 | 自定义颜色列表，逗号分隔 |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪个数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 .claude/skills/biodraw/assets/testdata/pie.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入文件路径"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "图表样式"
    question: "绘制什么类型的图？"
    options:
      - label: "饼图（推荐）"
        description: "标准饼图（donutwidth=1）"
      - label: "环形图"
        description: "中间镂空的环形图（donutwidth=0.4）"
  - header: "显示模式"
    question: "类别显示方式？"
    options:
      - label: "TopN + 其他（推荐）"
        description: "显示前10个类别，其余归为 Others"
      - label: "仅 TopN"
        description: "只显示前N个，不含 Others"
      - label: "全部显示"
        description: "显示所有类别（类别少时适用）"
```

## 输出文件
`SummaryPie.pdf` / `SummaryPie.png` / `SummaryPie.xlsx`

## 字体说明
- 默认自动检测系统字体，无需手动指定
- 若内容含中文但未安装中文字体，会提示安装建议
- 手动指定：`--fontfamily Arial` 或 `--fontfamily "Times New Roman"`
