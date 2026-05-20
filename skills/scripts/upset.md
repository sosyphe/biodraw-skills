# UpSet 图（UpSet Plot）

## 功能
基于 matplotlib 和 UpSet 库，可视化多集合（>3）的交集关系。

## 输入格式
第一列：元素名；后续列：集合名（1=属于，0=不属于）。
支持：`.xlsx` / `.csv` / `.tsv` / `.txt`
示例数据：`.claude/skills/biodraw/assets/testdata/upset.txt`

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
| `--orientation` | `horizontal` | 交集排列方向：horizontal（水平）/vertical（垂直） |
| `--sort_by` | `cardinality` | 子集排序：cardinality（基数）/degree（度）/input（输入顺序） |
| `--title` | 无 | 图标题 |
| `--facecolor` | `black` | 颜色（条形图和激活点） |
| `--show_percentages` | `False` | 是否显示百分比标签：True/False |

## 高级参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--ofilewidth` | `8` | 图片宽度（英寸） |
| `--ofileheight` | `8` | 图片高度（英寸） |
| `--fontfamily` | 自动检测 | 字体（留空则自动检测系统字体） |
| `--fontsize` | `12` | 字体大小 |
| `--titleposition` | `center` | 标题位置：left/center/right |
| `--sort_categories_by` | `cardinality` | 分类排序：cardinality/-cardinality/input/-input |
| `--min_subset_size` | 无 | 子集最小大小 |
| `--max_subset_size` | 无 | 子集最大大小 |
| `--max_subset_rank` | `30` | 子集排名上限 |
| `--min_degree` | 无 | 子集最小度数 |
| `--max_degree` | 无 | 子集最大度数 |
| `--element_size` | `32` | 元素边长 (pt) |
| `--intersection_plot_elements` | `6` | 交集图显示的矩阵元素数 |

## AskUserQuestion 配置

```yaml
questions:
  - header: "数据"
    question: "使用哪个数据文件？"
    options:
      - label: "示例数据"
        description: "使用内置测试数据 .claude/skills/biodraw/assets/testdata/upset.txt"
      - label: "自己的文件"
        description: "请在 Other 中输入文件路径"
  - header: "输出目录"
    question: "输出到哪个目录？"
    options:
      - label: "./output（默认）"
        description: "当前工作目录下的 output 文件夹"
      - label: "自定义路径"
        description: "请在 Other 中输入目录路径"
  - header: "方向"
    question: "交集条形图的排列方向？"
    options:
      - label: "horizontal（推荐）"
        description: "水平排列，适合大多数场景"
      - label: "vertical"
        description: "垂直排列"
  - header: "排序"
    question: "子集按什么排序？"
    options:
      - label: "cardinality（推荐）"
        description: "按交集元素数量排序"
      - label: "degree"
        description: "按交集涉及的集合数排序"
      - label: "input"
        description: "按输入数据顺序"
```

## 输出文件
`Upset.pdf` / `Upset.png` / `Upset.xlsx`
