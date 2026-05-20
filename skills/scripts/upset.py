#!/usr/bin/env python

import os
import sys
import shutil
import pathlib
import textwrap
import argparse
import traceback
from datetime import datetime
from itertools import product
from collections import OrderedDict

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import matplotlib.patches as mpatches
import plotly.express as px
import plotly.offline as pyo
import plotly.graph_objs as go
import matplotlib.font_manager as mfont

import utils
from upset_lib import from_contents, plot as upset_plot


class RunCLI:
    """
    管理命令行解析与批量测试
    """
    def __init__(self, run_func):
        """
        run_func: 执行单次绘图的函数，接收 argparse.Namespace
        """
        self.run_func = run_func

        self.arg_defs = [
            ("--infile", str, "./testdata/exampledata.tsv", "输入文件", None),
            ("--outdir", str, "./testdata/output", "输出目录", None),
            ("--ofiletype", str, "pdf+png", "输出文件类型", ["png", "pdf", "svg", "pdf+png"]),
            ("--ofilewidth", int, 8, "输出文件宽度", None),
            ("--ofileheight", int, 8, "输出文件高度", None),
            ("--fontfamily", str, "Arial", "字体（留空则自动检测系统字体）", None),
            ("--fontsize", int, 12, "字体大小", None),
            ("--title", str, "", "图标题", None),
            ("--titleposition", str, "center", "标题位置", ["left", "center", "right"]),
            ("--orientation", str, "horizontal", "交集排列方向", ["horizontal", "vertical"]),
            ("--sort_by", str, "cardinality", "子集排序方式", ["cardinality", "degree", "input"]),
            ("--sort_categories_by", str, "cardinality", "分类排序方式", ["cardinality", "-cardinality", "input", "-input"]),
            ("--min_subset_size", int, None, "子集最小大小", None),
            ("--max_subset_size", int, None, "子集最大大小", None),
            ("--max_subset_rank", int, 30, "子集排名上限", None),
            ("--min_degree", int, None, "子集最小度数", None),
            ("--max_degree", int, None, "子集最大度数", None),
            ("--facecolor", str, "black", "颜色（条形图和激活点）", None),
            ("--element_size", float, 32, "元素边长 (pt)", None),
            ("--intersection_plot_elements", int, 6, "交集图显示的矩阵元素数", None),
            ("--show_percentages", bool, False, "是否显示百分比标签", None),
        ]

        # 批量测试的参数组合
        self.test_cases = {
            "infile": ["./testdata/exampledata4.tsv","./testdata/exampledata3.tsv"],
            "fontfamily": ["Arial", "Times New Roman"],
            "sort_by": ["cardinality", "degree", "input"],
            "orientation": ["horizontal", "vertical"],
        }

    # -------------------------
    # 命令行参数解析
    # -------------------------
    def parse_args(self, test=None):
        parser = argparse.ArgumentParser(description="")
        for name, typ, default, helpt, choices in self.arg_defs:
            kwargs = {"type": typ, "default": default}
            if helpt:
                kwargs["help"] = helpt
            if choices:
                kwargs["choices"] = choices
            parser.add_argument(name, **kwargs)
        return parser.parse_args(test) if test else parser.parse_args()

    def run_cli(self):
        """单次运行,解析命令行参数并执行绘图"""
        args = self.parse_args()
        self.run_func(args)

    def test_batch(self):
        '''测试用:批量运行，遍历所有组合参数'''
        keys, values_list = zip(*self.test_cases.items())
        for idx, combo in enumerate(product(*values_list), 1):
            # 构造命令行参数
            test_args = sum([[f"--{k}", str(v)] for k, v in zip(keys, combo)], [])
            args = self.parse_args(test_args)
            args.title = " | ".join(f"{k}={v}" for k, v in zip(keys, combo))
            args.outdir = os.path.join("testdata/output", f"test_{idx}")
            utils.re_mkdir(args.outdir)

            # 打印参数信息
            print("\n" + "="*60)
            print(f"TEST CASE {idx}".center(60))
            print("-"*60)
            for key in sorted(vars(args).keys()):
                print(f"{key:<20}: {getattr(args, key)}")
            print("-"*60)
            print(f"Saving figure to: {args.outdir}")
            print("="*60 + "\n")

            # 调用绘图
            self.run_func(args)

class VennChart:
    # 字体选择：用户指定字体优先，否则自动检测系统可用字体
    FONT_MAP = {
        "Arial": None,  # None 表示由 get_best_font_family 动态选择
        "Times New Roman": None,
    }
    STYLE_CONFIG = {
        "style1": {
            "colormap": list(mcolors.TABLEAU_COLORS.values()) + list(mcolors.XKCD_COLORS.values()),
            "backend": "matplotlib"
        }
    }

    @staticmethod
    def _text_needs_cjk(data, title=""):
        """检测数据中是否包含中文字符"""
        import re
        cjk_pattern = re.compile(r'[一-鿿㐀-䶿]')
        for col in data.columns:
            for val in data[col]:
                if cjk_pattern.search(str(val)):
                    return True
        if cjk_pattern.search(str(title)):
            return True
        return False

    def __init__(self, indata:str, ofilename:str, args:argparse.Namespace):
        self.args = args
        self.indata = indata
        self.ofilename = ofilename
        # 动态选择字体：用户指定 > 自动检测系统字体
        user_font = getattr(args, "fontfamily", "Arial")
        font_map_entry = self.FONT_MAP.get(user_font)
        if font_map_entry is not None:
            # 用户指定了字体，使用该字体
            self.fontfamilyadd = [user_font] + (font_map_entry if isinstance(font_map_entry, list) else [font_map_entry])
        else:
            # 自动检测：检测是否需要中文字体，然后选择最佳字体
            prefer_cjk = self._text_needs_cjk(self.indata, getattr(args, "title", ""))
            self.fontfamilyadd = utils.get_best_font_family(prefer_cjk=prefer_cjk)
            if prefer_cjk and not utils.has_cjk_font():
                print("提示: 未检测到中文字体，中文可能显示为方块。")
                print(f"如需正确显示中文，可安装中文字体:\n{utils.suggest_cjk_font_install()}")
        self.drawstylecfg = self.STYLE_CONFIG.get(getattr(args, "drawstyle", "style1"),
                                self.STYLE_CONFIG["style1"])
        self.drawdict = None
        self.resultdata = None

    @classmethod
    def from_file(cls, infile:str, ofilename:str, args:argparse.Namespace, datatype:str = "data"):
        indata = cls._read_and_check_file(infile, ofilename, args, datatype)
        return cls(indata, ofilename, args)

    @staticmethod
    def _read_and_check_file(infile:str, ofilename:str, args:argparse.Namespace, datatype:str):
        data = utils.read_infileinfo(infile, ofilename, args.ofiletype)
        datashape = data.shape
        datacolumns = data.columns
        minrow, mincol = 1, 2

        if datashape[0] < minrow:
            raise ValueError(
                f"输入文件不满足要求:行数不足\n\n"
                f"要求至少 1 行数据,但当前文件只有 {datashape[0]} 行.\n"
                f"请检查文件内容并确保数据完整.\n"
                f"如需帮助,请联系技术支持人员."
            )
        if datashape[1] < mincol:
            raise ValueError(
                f"输入文件不满足要求:列数不足\n\n"
                f"要求至少 2 列数据(用于UpSet图的交集分析),但当前文件只有 {datashape[1]} 列.\n"
                f"请检查文件内容并确保数据完整.\n"
                f"如需帮助,请联系技术支持人员."
            )
        if datatype == "data":
            result = data.copy()
            return result
        else:
            return pd.DataFrame()

    def prepare_data(self):
        """
        清理空值并生成绘制 Venn 图所需的数据结构：
        1. drawdict: {列名: 集合元素}
        2. resultdata: 每行每列 0/1 指示元素是否属于集合
        """
        drawdict = self.indata.to_dict(orient='list')
        cleanedict = OrderedDict({
            key: set(x for x in value if pd.notna(x) and x != "")
            for key, value in drawdict.items()
        })

        allelements = list(set().union(*cleanedict.values()))
        resultdata = pd.DataFrame(index=allelements, columns=cleanedict.keys())

        for setname, elements in cleanedict.items():
            resultdata[setname] = resultdata.index.map(lambda x: 1 if x in elements else 0)

        self.drawdict = cleanedict
        self.resultdata = resultdata
        return cleanedict, resultdata

    def draw_fig(self):
        if self.drawstylecfg["backend"] == "matplotlib":
            return self._draw_matplotlib()

    def _draw_matplotlib(self):
        """绘制 Venn 图"""
        plt.rcParams.update({
            "mathtext.fontset": 'stix',
            'figure.constrained_layout.use': True,
            'font.family': self.fontfamilyadd
        })

        totalitem = len(self.resultdata)
        ncol = len(self.drawdict.keys())

        colorlist = getattr(self.args, "colorlist", "")
        if colorlist:
            colors = [c.strip().strip("'\"") for c in colorlist.split(",") if c.strip()]
            colormaplist = (colors * ((ncol // len(colors)) + 1))[:ncol]
        else:
            colormaplist = self.drawstylecfg["colormap"][:ncol]

        fig, ax = plt.subplots(figsize=(self.args.ofilewidth, self.args.ofileheight))

        if (ncol == 1) :
            ax.text(0.5, 0.5, '单比较组不支持绘制UpSet图',
                        fontsize=16, ha='center', va='center')
        else :
            drawdata = from_contents(self.drawdict)
            upset_plot(drawdata,
                        fig=fig,
                        show_counts="{:.0f}",
                        subset_size="count",
                        orientation=self.args.orientation,
                        sort_by=self.args.sort_by,
                        sort_categories_by=self.args.sort_categories_by,
                        min_subset_size=self.args.min_subset_size,
                        max_subset_size=self.args.max_subset_size,
                        max_subset_rank=self.args.max_subset_rank,
                        min_degree=self.args.min_degree,
                        max_degree=self.args.max_degree,
                        facecolor=self.args.facecolor,
                        element_size=self.args.element_size,
                        intersection_plot_elements=self.args.intersection_plot_elements,
                        show_percentages=self.args.show_percentages)

            ax.set_xticks([])
            ax.set_yticks([])
            for pos in ["top","bottom","right","left"] :
                ax.spines[pos].set_visible(False)

        plt.title(self.args.title, fontsize=self.args.fontsize, loc=self.args.titleposition)
        plt.close(fig)
        return fig

def run(args):
    utils.ensure_deps_or_exit("upset", None, None)  # 先检查依赖
    ofilename = os.path.join(args.outdir, "Upset")
    Chart = VennChart.from_file(infile=args.infile, ofilename=ofilename, args=args)
    Chart.prepare_data()
    Chart.resultdata.to_excel(f"{ofilename}.xlsx", index=True)
    resultfig = Chart.draw_fig()
    utils.save_matplotfig(resultfig, ofilename, args.ofiletype)

if __name__ == "__main__":
    cli = RunCLI(run)
    cli.run_cli()
    # cli.test_batch()

