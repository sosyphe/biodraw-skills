#!/usr/bin/env python

import os
import re
import math
import textwrap
import argparse
import traceback
from decimal import Decimal
from itertools import product

import numpy as np
import pandas as pd
import plotly.express as px
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib import colormaps
from adjustText import adjust_text
from matplotlib.patches import Circle, RegularPolygon
from matplotlib.path import Path
from matplotlib.spines import Spine
from matplotlib.ticker import MaxNLocator
from matplotlib.transforms import Affine2D
from matplotlib.projections import register_projection
from matplotlib.projections.polar import PolarAxes

import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import utils as autils

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
            ("--ofileheight", int, 6, "输出文件高度", None),
            ("--fontfamily", str, "Arial", "字体类型（留空则自动检测系统字体）", None),
            ("--fontsize", int, 12, "字体大小", None),
            ("--markersize", int, 5, "标记大小", None),
            ("--trickangle", int, 0, "刻度旋转角度", None),
            ("--alpha", float, 0.2, "透明度", None),
            ("--radartype", str, "polygon", "雷达图类型", None),
            ("--legendtitle", str, "", "图例标题", None),
            ("--title", str, "", "图标题", None),
            ("--titleposition", str, "center", "标题位置", ["left", "center", "right"]),
            ("--colorlist", str, "", "颜色列表", None)
        ]

        # 批量测试的参数组合
        self.test_cases = {
            "titleposition": ["center", "left"],
            "bincolor": ["red", "blue", "grey"],
            "fontfamily": ["Arial", "Times New Roman"]
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
            autils.re_mkdir(args.outdir)

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

def read_and_checkfile(infile:str,needcol:list, ofilename:str, args:argparse.Namespace, datatype:str):
    data = autils.read_infileinfo(infile, ofilename, args.ofiletype)
    datashape = data.shape
    datacolumns = data.columns
    minrow, mincol = 1, 4

    if datashape[0] < minrow:
        autils.gen_errorexit(
            f"输入文件不满足要求:行数不足\n\n"
            f"要求至少 {minrow} 行数据,但当前文件只有 {datashape[0]} 行.\n"
            f"请检查文件内容并确保数据完整.\n"
            f"如需帮助,请联系技术支持人员.",
            ofilename, args.ofiletype
        )
    if datashape[1] < mincol:
        autils.gen_errorexit(
            f"输入文件不满足要求:列数不足\n\n"
            f"要求至少 {mincol} 列数据,但当前文件只有 {datashape[1]} 列.\n"
            f"请检查文件内容并确保数据完整.\n"
            f"如需帮助,请联系技术支持人员.",
            ofilename, args.ofiletype
        )
    if datatype == "data":
        if data[datacolumns[0]].duplicated().any():
            autils.gen_errorexit(f"输入文件第一列{datacolumns[0]}中存在重复值,请确保该列中无重复值",
                                  ofilename, args.ofiletype)
        elif list(data.columns).count(datacolumns[0]) > 1:
            autils.gen_errorexit(f"输入文件第一列{datacolumns[0]}在输入文件列名中不唯一",
                                ofilename, args.ofiletype)
        try:
            numericpart = data.drop(columns=[datacolumns[0]])
            is_numeric_and_not_null = numericpart.map(lambda x: isinstance(x, (int, float, complex))) \
                                                .all().all() and numericpart.notnull().all().all()
            if not is_numeric_and_not_null:
                autils.gen_errorexit("输入文件内容错误: 除第一列外应全为非空数字值",
                              ofilename, args.ofiletype)
        except Exception as e:
            autils.gen_errorexit(f"输入文件检查异常,请联系工作人员,错误信息如下\n{e}",
                                 ofilename, args.ofiletype)

    return data

def radar_factory(num_vars, frame='circle'):
    """
    Create a radar chart with `num_vars` Axes.

    This function creates a RadarAxes projection and registers it.

    Parameters
    ----------
    num_vars : int
        Number of variables for radar chart.
    frame : {'circle', 'polygon'}
        Shape of frame surrounding Axes.

    """
    # calculate evenly-spaced axis angles
    theta = np.linspace(0, 2*np.pi, num_vars, endpoint=False)

    class RadarTransform(PolarAxes.PolarTransform):

        def transform_path_non_affine(self, path):
            # Paths with non-unit interpolation steps correspond to gridlines,
            # in which case we force interpolation (to defeat PolarTransform's
            # autoconversion to circular arcs).
            if path._interpolation_steps > 1:
                path = path.interpolated(num_vars)
            return Path(self.transform(path.vertices), path.codes)

    class RadarAxes(PolarAxes):

        name = 'radar'
        PolarTransform = RadarTransform

        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            # rotate plot such that the first axis is at the top
            self.set_theta_zero_location('N')

        def fill(self, *args, closed=True, **kwargs):
            """Override fill so that line is closed by default"""
            return super().fill(closed=closed, *args, **kwargs)

        def plot(self, *args, **kwargs):
            """Override plot so that line is closed by default"""
            lines = super().plot(*args, **kwargs)
            for line in lines:
                self._close_line(line)

        def _close_line(self, line):
            x, y = line.get_data()
            # FIXME: markers at x[0], y[0] get doubled-up
            if x[0] != x[-1]:
                x = np.append(x, x[0])
                y = np.append(y, y[0])
                line.set_data(x, y)

        def set_varlabels(self, labels):
            self.set_thetagrids(np.degrees(theta), labels)

        def _gen_axes_patch(self):
            # The Axes patch must be centered at (0.5, 0.5) and of radius 0.5
            # in axes coordinates.
            if frame == 'circle':
                return Circle((0.5, 0.5), 0.5)
            elif frame == 'polygon':
                return RegularPolygon((0.5, 0.5), num_vars,
                                      radius=.5, edgecolor="k")
            else:
                raise ValueError("Unknown value for 'frame': %s" % frame)

        def _gen_axes_spines(self):
            if frame == 'circle':
                return super()._gen_axes_spines()
            elif frame == 'polygon':
                # spine_type must be 'left'/'right'/'top'/'bottom'/'circle'.
                spine = Spine(axes=self,
                              spine_type='circle',
                              path=Path.unit_regular_polygon(num_vars))
                # unit_regular_polygon gives a polygon of radius 1 centered at
                # (0, 0) but we want a polygon of radius 0.5 centered at (0.5,
                # 0.5) in axes coordinates.
                spine.set_transform(Affine2D().scale(.5).translate(.5, .5)
                                    + self.transAxes)
                return {'polar': spine}
            else:
                raise ValueError("Unknown value for 'frame': %s" % frame)

    register_projection(RadarAxes)
    return theta

def draw_radar(indata:pd.DataFrame,args:argparse.Namespace) :
    # 动态选择字体：用户指定 > 自动检测系统字体
    import re
    cjk_pattern = re.compile(r'[一-鿿㐀-䶿]')
    prefer_cjk = any(cjk_pattern.search(str(v)) for col in indata.columns for v in indata[col])
    if args.fontfamily:
        # 用户指定了字体
        font_family = args.fontfamily
    else:
        # 自动检测
        font_family = autils.get_best_font_family(prefer_cjk=prefer_cjk)
        if prefer_cjk and not autils.has_cjk_font():
            print("提示: 未检测到中文字体，中文可能显示为方块。")
            print(f"如需正确显示中文，可安装中文字体:\n{autils.suggest_cjk_font_install()}")

    plt.rcParams.update({
        "mathtext.fontset": 'stix',
        'figure.constrained_layout.use': True,
        'font.family': font_family if isinstance(font_family, list) else [font_family]
    })

    if args.colorlist != "":
        colorlist = args.colorlist.split(',')
        colormaplist = (colorlist * ((len(indata) // len(colorlist)) + 1))[:len(indata)]
    else:
        colormaplist = list(mcolors.TABLEAU_COLORS.values()) + list(mcolors.XKCD_COLORS.values())

    radarangle = [col for col in indata.columns if col != indata.columns[0]]
    theta = radar_factory(len(radarangle), frame=args.radartype)
    theta = np.append(theta, theta[0])

    drawfig,drawfigax = plt.subplots(nrows=1, ncols=1,
                                    figsize=(args.ofilewidth,args.ofileheight),
                                    subplot_kw=dict(projection='radar'))

    for idx, row in indata.iterrows():
        values = row[radarangle].tolist()
        values += values[:1]
        label = row[indata.columns[0]]
        color = colormaplist[idx % len(colormaplist)]
        drawfigax.plot(theta, values, label=label, color=color,
                    marker='o', markersize=args.markersize)
        drawfigax.fill(theta, values, alpha=args.alpha, color=color)

    drawfigax.set_varlabels(radarangle)
    radii = drawfigax.get_yticks()
    drawfigax.set_rgrids(radii,angle=args.trickangle)
    labels = drawfigax.yaxis.get_ticklabels()
    for label in labels: label.set_color('gray'); label.set_fontsize(args.fontsize * 0.6)
    if len(labels) >= 1:
        labels[-1].set_visible(False)
    drawfigax.legend(loc="center left",
                     title=args.legendtitle,
                     fontsize=args.fontsize * .8,
                     bbox_to_anchor=(1.05, 0.5),
                     frameon=True)

    plt.title(args.title,fontsize=args.fontsize, loc=args.titleposition)
    return drawfig

def run(args):
    autils.ensure_deps_or_exit("radar", None, None)  # 先检查依赖
    ofilename = os.path.join(args.outdir, "radar")
    try:
        data = read_and_checkfile(args.infile,[],ofilename,
                                 args,"data")
        resultfig = draw_radar(data,args)
        autils.save_matplotfig(resultfig,ofilename,args.ofiletype)
    except Exception as e:
        print("".join(traceback.format_exception(type(e), e, e.__traceback__)))
        error_msg = (
            "雷达图计算绘制出现错误.\n"
            "请联系技术支持人员协助解决.\n"
            "错误信息如下:\n" +
            "\n".join(textwrap.wrap(str(e), width=60))
        )
        autils.gen_errorexit(f"{error_msg}", ofilename, args.ofiletype)

if __name__ == "__main__":
    cli = RunCLI(run)
    cli.run_cli()
    # cli.test_batch()
