# 联合分析相关性热图

## 功能
基于 ComplexHeatmap 计算两组数据间相关性并绘制热图。

## 输入格式
**必填参数：**
| 参数 | 说明 |
|------|------|
| `--infile` | 第一个输入文件（如代谢物数据） |
| `--infile2` | 第二个输入文件（如基因数据） |

两文件列名（样本名）必须一致。
支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/heatmap.cor.double.1.txt` / `.2.txt`

## 核心参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--infile` | 必填 | 第一个输入数据文件路径 |
| `--infile2` | 必填 | 第二个输入数据文件路径 |
| `--outdir` | `./output` | 输出目录（相对于 Claude 工作目录） |
| `--ofiletype` | `pdf+png` | 输出格式：png/pdf/svg/pdf+png |
| `--cormethod` | `pearson` | 相关性方法：pearson（皮尔逊）/spearman（斯皮尔曼） |
| `--clusterrows` | `yes` | 是否对行聚类：yes/no |
| `--clustercols` | `yes` | 是否对列聚类：yes/no |
| `--ifdisplaysig` | `yes` | 是否显示显著性标记：yes/no（*** p<0.001，** p<0.01，* p<0.05） |
| `--downcolor` | `navy` | 负相关颜色 |
| `--upcolor` | `red` | 正相关颜色 |
| `--title` | 无 | 图标题 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--colannfile` | 无 | 列注释文件（样本注释） |
| `--rowannfile` | 无 | 行注释文件（特征注释） |
| `--colanncolorlist` | 无 | 列注释颜色，格式如 `group:red,type:blue` |
| `--rowanncolorlist` | 无 | 行注释颜色 |
| `--ofilewidth` | `12` | 图片宽度（英寸） |
| `--ofileheight` | `12` | 图片高度（英寸） |
| `--legendtitle` | 空格 | 图例标题 |
| `--axisxsize` | `12` | X轴字体大小 |
| `--axisxrotation` | `90` | X轴标签旋转角度 |
| `--axisysize` | `12` | Y轴字体大小 |
| `--fontfamily` | `Times New Roman` | 字体家族 |
| `--labelbold` | `yes` | 标签是否折行：yes/no |
| `--scaletype` | `no` | 数据缩放：no（无）/scale（缩放）/zscore（Z分数） |
| `--showrownames` | `yes` | 是否显示行名：yes/no |
| `--showcolnames` | `yes` | 是否显示列名：yes/no |
| `--clustermethod` | `complete` | 聚类方法：complete/ward.D/ward.D2/single/average/mcquitty/median/centroid |
| `--ifdisplaynumbers` | `no` | 是否显示相关系数值：yes/no |
| `--displaydigits` | `2` | 显示的小数位数 |
| `--midcolor` | `white` | 中间颜色（相关性为0） |
| `--bordercolor` | `grey` | 热图边框颜色 |
| `--fontfacerow` | `plain` | 行名字体样式：plain/bold/italic/bold.italic |
| `--fontfacecol` | `plain` | 列名字体样式：plain/bold/italic/bold.italic |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪组数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 heatmap.cor.double.1.txt + .2.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入：文件1路径 和 文件2路径（空格分隔）"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "相关性"
    question: "使用哪种相关性计算方法？"
    options:
      - label: "pearson（推荐）"
        description: "皮尔逊相关系数，衡量线性相关"
      - label: "spearman"
        description: "斯皮尔曼等级相关，适合非线性或有异常值的数据"
  - header: "显著性"
    question: "是否在热图上显示显著性标记？"
    options:
      - label: "yes（推荐）"
        description: "显示 * / ** / *** 标记（p<0.05/0.01/0.001）"
      - label: "no"
        description: "不显示显著性标记"
```

## 输出文件
`Heatmap.Correlation.pdf` / `.png` / `.svg` / `.xlsx`
