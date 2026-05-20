#!/usr/bin/env python

import os
import textwrap
import argparse
import traceback
from itertools import product
from collections import Counter

import numpy as np
import pandas as pd
import plotly.express as px
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

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
            ("--choosedcol", str, "classB", "选择的列", None),
            ("--ofiletype", str, "pdf+png", "输出文件类型", ["png", "pdf", "svg" ,"pdf+png"]),
            ("--ofilewidth", int, 10, "输出图宽", None),
            ("--ofileheight", int, 8, "输出图高", None),
            ("--drawtype", str, "all", "绘图类型", ["top", "all"]),
            ("--topN", int, 10, "TopN", None),
            ("--legendtitle", str, "", "图例标题", None),
            ("--showlegendtype", str, "text+count+percent", "图例显示方式", ["nothing", "text", "text+count", "text+percent", "text+count+percent"]),
            ("--showpercent", str, "all", "百分比显示方式", ["label", "percent", "number", "all", "nothing"]),
            ("--showpercentlabelpos", str, "center", "百分比标签位置", ["center", "outer"]),
            ("--fontfamily", str, "Arial", "字体选择", ["Arial", "Times New Roman"]),
            ("--otherslabel", str, "Others", "其他分类标签", None),
            ("--startangle", int, 0, "起始角度", None),
            ("--ifsortbycount", str, "yes", "是否按计数排序", None),
            ("--decimalplaces", int, 1, "百分比小数位", None),
            ("--fontsize", int, 12, "字体大小", None),
            ("--title", str, "", "标题", None),
            ("--titleposition", str, "center", "标题位置", ["left", "center", "right"]),
            ("--colorlist", str, "", "自定义颜色列表", None),
            ("--drawstyle", str, "style1", "绘图样式", ["style1", "style2"]),
            ("--donutwidth", float, 1, "圈图比例(0-1),1为饼图", None)
        ]

        # 批量测试的参数组合
        self.test_cases = {
            "drawtype": ["top", "all"],
            "topN": ["5", "10"],
            "showlegendtype": ["nothing", "text", "text+count", "text+percent", "text+count+percent"],
            "showpercent": ["label", "percent", "number", "all", "nothing"],
            "drawstyle": ["style1", "style2"]
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

class PieChart:
    # 字体选择：用户指定字体优先，否则自动检测系统可用字体
    # 保留 FONT_MAP 用于向后兼容（用户指定 --fontfamily 时）
    FONT_MAP = {
        "Arial": None,  # None 表示由 get_best_font_family 动态选择
        "Times New Roman": None,
    }
    STYLE_CONFIG = {
        "style1": {
            "colormap": list(mcolors.TABLEAU_COLORS.values()) + list(mcolors.XKCD_COLORS.values()),
            "showpercent": {
                "all":    ("autopct", "labels"),
                "label":  (None, "labels"),
                "number": ("number", None),
                "percent":("autopct", None),
                "nothing":(None, None),
            },
            "backend": "matplotlib"
        },
        "style2": {
            "colormap": px.colors.qualitative.Plotly,
            "showpercent": {
                "all": "text+percent",
                "label": "text",
                "percent": "percent",
                "number": "value",
                "nothing": "none"
            },
            "backend": "plotly"
        }
    }

    @staticmethod
    def _text_needs_cjk(text_list, title=""):
        """检测文本中是否包含中文字符"""
        import re
        cjk_pattern = re.compile(r'[一-鿿㐀-䶿]')
        for text in text_list:
            if cjk_pattern.search(str(text)):
                return True
        if cjk_pattern.search(str(title)):
            return True
        return False

    def __init__(self, indata:str, ofilename:str, args:argparse.Namespace):
        self.args = args
        self.indata = indata
        self.ofilename = ofilename
        self.decimalplaces = getattr(args, "decimalplaces", 1)
        # 动态选择字体：用户指定 > 自动检测系统字体
        user_font = getattr(args, "fontfamily", "Arial")
        font_map_entry = self.FONT_MAP.get(user_font)
        if font_map_entry is not None:
            # 用户指定了字体，使用该字体
            self.fontfamilyadd = [user_font] + (font_map_entry if isinstance(font_map_entry, list) else [font_map_entry])
        else:
            # 自动检测：检测是否需要中文字体，然后选择最佳字体
            prefer_cjk = self._text_needs_cjk(self.indata, getattr(args, "title", ""))
            self.fontfamilyadd = autils.get_best_font_family(prefer_cjk=prefer_cjk)
            if prefer_cjk and not autils.has_cjk_font():
                print("提示: 未检测到中文字体，中文可能显示为方块。")
                print(f"如需正确显示中文，可安装中文字体:\n{autils.suggest_cjk_font_install()}")
        self.drawstylecfg = self.STYLE_CONFIG.get(getattr(args, "drawstyle", "style1"),
                                self.STYLE_CONFIG["style1"])
        self.totalnum = 0
        self.drawcount = []
        self.drawlabel = []
        self.resultdata = None

    @classmethod
    def from_file(cls, infile:str, ofilename:str, args:argparse.Namespace, datatype:str = "data"):
        indata = cls._read_and_check_file(infile, ofilename, args, datatype)
        return cls(indata, ofilename, args)

    @staticmethod
    def _read_and_check_file(infile:str, ofilename:str, args:argparse.Namespace, datatype:str):
        data = autils.read_infileinfo(infile, ofilename, args.ofiletype)
        datashape = data.shape
        datacolumns = data.columns
        minrow, mincol = 2, 1

        if datashape[0] < minrow:
            raise ValueError(
                f"输入文件不满足要求:行数不足\n\n"
                f"要求至少 {minrow} 行数据,但当前文件只有 {datashape[0]} 行.\n"
                f"请检查文件内容并确保数据完整.\n"
                f"如需帮助,请联系技术支持人员."
            )
        if datashape[1] < mincol:
            raise ValueError(
                f"输入文件不满足要求:列数不足\n\n"
                f"要求至少 {mincol} 列数据,但当前文件只有 {datashape[1]} 列.\n"
                f"请检查文件内容并确保数据完整.\n"
                f"如需帮助,请联系技术支持人员."
            )
        if datatype == "data":
            if args.choosedcol not in datacolumns:
                raise ValueError(
                    f"输入文件不满足要求:缺少必要列\n\n"
                    f"未找到所选列 '{args.choosedcol}'.\n"
                    f"请确认文件中包含此列,或选择正确的绘图列.\n"
                    f"如需帮助,请联系技术支持人员."
                )
            result = data[args.choosedcol].dropna().to_list()
            if not result:
                raise ValueError(
                    f"输入文件不满足要求:所选列为空\n\n"
                    f"列 '{args.choosedcol}' 中没有有效数据,请检查文件内容.\n"
                    f"如需帮助,请联系技术支持人员."
                )
            return result
        else:
            return data.values.flatten().tolist()

    def prepare_data(self):
        """统计数量、计算百分比、处理 TopN"""
        counter = Counter(self.indata)
        self.resultdata = pd.DataFrame(counter.items(), columns=["ID", "Count"])
        self.totalnum = self.resultdata["Count"].sum()
        self.resultdata["Percent(%)"] = self.resultdata["Count"] / self.totalnum * 100
        if getattr(self.args, "ifsortbycount", "yes") == "yes":
            self.resultdata = self.resultdata.sort_values("Count", ascending=False)
        topN = getattr(self.args, "topN", 10)
        self.indatatop = self.resultdata.head(topN)
        self.drawcount = self.indatatop["Count"].tolist()
        self.drawlabel = self.indatatop["ID"].tolist()
        if getattr(self.args, "drawtype", "all") == "all" and len(self.resultdata) > topN:
            othersum = self.resultdata.iloc[topN:]["Count"].sum()
            self.drawcount.append(othersum)
            self.drawlabel.append(getattr(self.args, "otherslabel", "Others"))

    def draw_fig(self):
        params = self._get_plot_params()
        if self.drawstylecfg["backend"] == "matplotlib":
            return self._draw_matplotlib(params)
        else:
            return self._draw_plotly(params)

    def _get_plot_params(self):
        n = len(self.drawcount)
        legend_formatters = {
            "text": lambda l, v: f"{l}",
            "text+count": lambda l, v: f"{l}:{v}",
            "text+percent": lambda l, v: f"{l} ({v / self.totalnum * 100:.{self.decimalplaces}f}%)",
            "text+count+percent": lambda l, v: f"{l}:{v} ({v / self.totalnum * 100:.{self.decimalplaces}f}%)"
        }
        formatter = legend_formatters.get(getattr(self.args, "showlegendtype", "text"), lambda l, v: l)
        drawlabels = [formatter(l, v) for l, v in zip(self.drawlabel, self.drawcount)]

        colorlist = getattr(self.args, "colorlist", "")
        if colorlist:
            colors = [c.strip().strip("'\"") for c in colorlist.split(",") if c.strip()]
            colorlist = (colors * ((n // len(colors)) + 1))[:n]
        else:
            colorlist = self.drawstylecfg["colormap"][:n]

        sp_type = getattr(self.args, "showpercent", "nothing")
        backend = self.drawstylecfg["backend"]
        showpercent_cfg = self.drawstylecfg["showpercent"]
        if backend == "matplotlib":
            autopct_type, labels_type = showpercent_cfg.get(sp_type, (None, None))
            if autopct_type == "autopct":
                autopct = f"%1.{self.decimalplaces}f%%"
            elif autopct_type == "number":
                idx = {"value": -1}
                def autopct(pct):
                    idx["value"] += 1
                    value = self.drawcount[idx["value"]]
                    return f"{value:.{self.decimalplaces}f}"
                autopct = autopct
            else:
                autopct = None
            labels = self.drawlabel if labels_type == "labels" else None
            showpercent = {"autopct": autopct, "labels": labels}
        else:
            showpercent = {"textinfo": showpercent_cfg.get(sp_type, "none")}
        return {"drawlabels": drawlabels, "colormap": colorlist, "showpercent": showpercent}

    def _draw_matplotlib(self, params):
        plt.rcParams.update({
            "mathtext.fontset": 'stix',
            'figure.constrained_layout.use': True,
            'font.family': self.fontfamilyadd
        })
        fig, ax = plt.subplots(figsize=(self.args.ofilewidth, self.args.ofileheight),
                               subplot_kw=dict(aspect="equal"))

        wedgeprops = {'width': self.args.donutwidth} if self.args.donutwidth < 1 else None
        pctdistance = 1 - (self.args.donutwidth / 2)   if self.args.donutwidth < 1 else 0.6

        result = ax.pie(
            self.drawcount,
            labels=params["showpercent"]["labels"],
            autopct=params["showpercent"]["autopct"],
            colors=params["colormap"],
            startangle=self.args.startangle,
            labeldistance=1.1,
            textprops={'fontsize': self.args.fontsize},
            pctdistance=pctdistance,
            wedgeprops=wedgeprops
        )

        wedges, _texts, autotexts = result[:3] if len(result) > 2 else (*result, [])
        if self.args.showpercentlabelpos == "outer" and autotexts:
            for autotext, wedge in zip(autotexts, wedges):
                ang = (wedge.theta2 + wedge.theta1) / 2
                x, y = 0.85 * np.cos(np.deg2rad(ang)), 0.85 * np.sin(np.deg2rad(ang))
                autotext.set_position((x, y))
                rotation = ang + 180
                if rotation > 270: rotation -= 360
                elif rotation > 90: rotation -= 180
                autotext.set_rotation(rotation)

        if self.args.showlegendtype != "nothing":
            ax.legend(params["drawlabels"], loc="center left", fontsize=self.args.fontsize * 0.8,
                      bbox_to_anchor=(1.05, 0.5), frameon=True)

        plt.title(self.args.title, fontsize=self.args.fontsize, loc=self.args.titleposition)
        plt.close()
        return fig

    def _draw_plotly(self, params):
        drawdata = pd.DataFrame({
            "ID": self.drawlabel,
            "Count": self.drawcount,
            "Label": params["drawlabels"]
        })
        fig = px.pie(drawdata,
                     names="Label",
                     values="Count",
                     color_discrete_sequence=[autils.hex2rgba(c) for c in params["colormap"]],
                     hole=1-self.args.donutwidth if self.args.donutwidth < 1 else 0)
        fig.update_layout(
            title=dict(text=self.args.title, xanchor=self.args.titleposition),
            font=dict(family=",".join(self.fontfamilyadd), color="black", size=self.args.fontsize),
            showlegend=(self.args.showlegendtype != "nothing"),
            legend=dict(y=0.5, orientation='v', title_text=self.args.legendtitle),
            width=self.args.ofilewidth * 96,
            height=self.args.ofileheight * 96,
        )
        fig.update_traces(
            text=self.drawlabel,
            textinfo=params["showpercent"].get("textinfo", "none"),
            rotation=self.args.startangle,
            textposition='outside' if self.args.showpercentlabelpos == 'outer' else 'inside'
        )
        return fig

def run(args):
    autils.ensure_deps_or_exit("pie", None, None)  # 先检查依赖
    ofilename = os.path.join(args.outdir, "SummaryPie")
    Chart = PieChart.from_file(infile=args.infile, ofilename=ofilename, args=args)
    Chart.prepare_data()
    Chart.resultdata.to_excel(f"{ofilename}.xlsx", index=None)
    resultfig = Chart.draw_fig()
    autils.save_matplotfig(resultfig, ofilename, args.ofiletype)

if __name__ == "__main__":
    cli = RunCLI(run)
    cli.run_cli()
    # cli.test_batch()
