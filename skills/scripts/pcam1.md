# PCA 分析图（PCA Plot - Method 1）

## 功能
基于 FactoMineR + factoextra 进行 PCA 分析并绘制 2D/3D 散点图，支持置信椭圆、分组着色。

## 输入格式
**必填：**
| 参数 | 说明 |
|------|------|
| `--infile` | 数据文件（第一列为特征名 `Index`，其余列为样本数值） |
| `--insamplefile` | 样本分组文件（需含 `sample` 和 `group` 列，可选 `color` 列） |

支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/pcam1.txt` + `pcam1.sample.txt`

## 核心参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--infile` | 必填 | 数据文件 |
| `--insamplefile` | 必填 | 样本分组文件 |
| `--outdir` | `./output` | 输出目录（相对于 Claude 工作目录） |
| `--ofiletype` | `pdf` | 输出格式：png/pdf/svg/pdf+png |
| `--drawstyle` | `2d` | 绘制类型：2d（2D散点图）/3d（3D散点图） |
| `--scaledata` | `yes` | 是否标准化数据：yes/no |
| `--addEllipses` | `yes` | 是否添加置信椭圆：yes/no |
| `--title` | 无 | 图标题 |
| `--groupcolor` | 无 | 分组颜色，逗号分隔 |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `8` | 图片宽度（英寸） |
| `--ofileheight` | `8` | 图片高度（英寸） |
| `--fontfamily` | `Times New Roman` | 字体 |
| `--theme` | `bw` | ggplot 主题 |
| `--pointsize` | `2` | 点大小 |
| `--labelsize` | `3` | 数据标签大小 |
| `--addEllipsestype` | `v1` | 椭圆类型：v1（自定义椭圆）/v0（stat_ellipse/geom_mark_ellipse） |
| `--geomind` | `point,text` | 几何元素：point/text 的组合 |
| `--xlab` | 无 | X 轴标签（自动附加方差百分比） |
| `--xlabsize` | `12` | X 轴标签大小 |
| `--axisxsize` | `12` | X 轴刻度大小 |
| `--axisxangle` | `0` | X 轴刻度旋转角度 |
| `--ylab` | 无 | Y 轴标签 |
| `--ylabsize` | `12` | Y 轴标签大小 |
| `--axisysize` | `12` | Y 轴刻度大小 |
| `--axisyangle` | `0` | Y 轴刻度旋转角度 |
| `--zlab` | 无 | Z 轴标签（仅 3D） |
| `--titlepos` | `center` | 标题位置：left/center/right |
| `--titlesize` | `14` | 标题字体大小 |
| `--legendlab` | 无 | 图例标签 |
| `--legendtitlesize` | `10` | 图例标题大小 |
| `--legendtextsize` | `10` | 图例文本大小 |
| `--dotshapenormal` | `19` | 点形状编号（仅 3D） |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪组数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 pcam1.txt + pcam1.sample.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入：数据文件路径 和 样本分组文件路径（空格分隔）"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "维度"
    question: "绘制 2D 还是 3D 散点图？"
    options:
      - label: "2d（推荐）"
        description: "2D 散点图，支持置信椭圆"
      - label: "3d"
        description: "3D 散点图（PC1/PC2/PC3）"
  - header: "椭圆"
    question: "是否添加置信椭圆？（仅 2D）"
    options:
      - label: "yes（推荐）"
        description: "添加 95% 置信椭圆"
      - label: "no"
        description: "不添加椭圆"
```

## 输出文件
`PCA.pdf` / `.png` / `.svg` / `PCA.xlsx`（含主成分坐标和方差贡献）
