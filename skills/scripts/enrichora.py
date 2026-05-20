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
import scipy.stats as scistat
from statsmodels.stats.multitest import multipletests

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
            ("--infile", str, "./testdata/exampledata.txt", "输入文件", None),
            ("--refmapfile", str, "./testdata/examplebackground.txt", "输入文件", None),
            ("--outdir", str, "./testdata/output", "输出目录", None),
            ("--fdrmethods", str, "fdr_bh", "输出目录", ["fdr_bh","bonferroni","simes-hochberg","hommel"]),
            ("--ofiletype", str, "png", "输出文件类型", ["png", "pdf", "svg", "pdf+png"]),
            #("--ofilewidth", int, 8, "输出文件宽度", None),
            #("--ofileheight", int, 6, "输出文件高度", None),
            #("--fontfamily", str, "Arial", "字体类型", ["Arial", "Times New Roman"]),
            #("--fontsize", int, 12, "字体大小", None),
            #("--legendtitle", str, "", "图例标题", None),
            #("--title", str, "", "图标题", None),
            #("--titleposition", str, "center", "标题位置", ["left", "center", "right"]),
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

def read_and_checkfile(infile:str,needcol:list, ofilename:str, args:argparse.Namespace, datatype:str,
                       minrow:int=1,mincol:int=1):
    data = autils.read_infileinfo(infile, ofilename, args.ofiletype)
    datashape = data.shape
    datacolumns = data.columns

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
    if datatype in ["data","bgdata"]:
        if data[datacolumns[0]].duplicated().any() and datatype=="data":
            raise ValueError(f"输入文件第一列{datacolumns[0]}中存在重复值,请确保该列中无重复值")
        elif list(data.columns).count(datacolumns[0]) > 1:
            raise ValueError(f"输入文件第一列{datacolumns[0]}在输入文件列名中不唯一")
        else :
            missing_cols = [col for col in needcol if col not in data.columns]
            if missing_cols:
                raise ValueError(
                    f"输入文件缺少必要列: {', '.join(missing_cols)}"
                )
        try:
            result = data.copy()
            if datatype=="data":
                result = pd.concat(
                    [pd.DataFrame([data.columns.tolist()], columns=data.columns), data],
                    ignore_index=True
                )
                result.columns = range(result.shape[1])
            return result
        except Exception as e:
            raise ValueError(f"输入文件检查异常,请联系工作人员,错误信息如下\n{e}")

def get_enrichinfo(deginfo:pd.DataFrame, indata: pd.DataFrame, needcols:list) :
    if deginfo.empty :
        return pd.DataFrame(columns=needcols),pd.DataFrame(),0,0
    result = deginfo[[0]].rename(columns={0: "ID"})
    refinfo = indata.copy()[needcols]
    degresult = pd.merge(indata,result,how="right",on="ID")
    degdfWithAnn = degresult[needcols]
    degdfWithAnn = degdfWithAnn.dropna(subset=["PathwayID"])
    degAnnGene = len(set(degdfWithAnn["ID"].values.tolist()))
    totalAnnGene = len(set(indata["ID"].values.tolist()))

    return refinfo,degdfWithAnn,degAnnGene,totalAnnGene

def calc_orapvalues(data: pd.DataFrame) :
    '''
    For 2*2 contingency table:
    =============================================================================
                         |   in  query  |  not in query |    row total
    =>      in gene_set  |        a     |       b       |       a+b
    =>  not in gene_set  |        c     |       d       |       c+d
           column total                                 | a+b+c+d = anno database
    =============================================================================
    background genes number = a + b + c + d.

    Then, in R
        x=a     the number of white balls drawn without replacement
                from an urn which contains both black and white balls.
        m=a+b   the number of white balls in the urn
        n=c+d   the number of black balls in the urn
        k=a+c   the number of balls drawn from the urn

    In Scipy:
    for args in scipy.hypergeom.sf(k, M, n, N, loc=0):
        M: the total number of objects,
        n: the total number of Type I objects.
        k: the random variate represents the number of Type I objects in N drawn
           without replacement from the total population.

    Therefore, these two functions are the same when using parameters from 2*2 table:
    R:     >   phyper(x-1, m, n, k, lower.tail=FALSE)
    Scipy: >>> hypergeom.sf(x-1, m+n, m, k)

    For Odds ratio in Enrichr (see https://maayanlab.cloud/Enrichr/help#background&q=4)
        oddsRatio = (1.0 * x * d) / Math.max(1.0 * b * c, 1)
    where:
        x are the overlapping genes,
        b (m-x) are the genes in the annotated set - overlapping genes,
        c (k-x) are the genes in the input set - overlapping genes,
        d (bg-m-k+x) are the total genes[genes in the annotated set]

    In Excel:
        GeneRatio:7/1167 & BgRatio:45/9798
    =============================================================================
                         |   in  query  |  not in query |    row total
    =>      in gene_set  |       45     |       7       |       a+b
    =>  not in gene_set  |      9753    |      1160     |       c+d
           column total         9798           1167     | a+b+c+d = anno database
    =============================================================================
        Pvalue: 1 - HYPGEOM.DIST(C2-1,C4,B2,B4,TRUE)
              : 1 - HYPGEOM.DIST(LEFT(A2,FIND("/",A2)-1)-1, RIGHT(A2,LEN(A2)-FIND("/",A2)),
                                 LEFT(B2,FIND("/",B2)-1), RIGHT(B2,LEN(B2)-FIND("/",B2)),TRUE)
    '''
    mapped = data["MappingRatio"]
    backgroup = data["BgRatio"]
    a = int(mapped.split("/")[0]) - 1
    b = int(backgroup.split("/")[1])
    c = int(backgroup.split("/")[0])
    d = int(mapped.split("/")[1])

    pvalue = scistat.hypergeom.sf(a,b,c,d)
    return pvalue

def gen_enrichresult(deginfo: pd.DataFrame, backinfo:pd.DataFrame,args) -> pd.DataFrame:
    needcols = ["ID","PathwayID","PathwayDescription"]
    header = ["PathwayID", "PathwayDescription",
              "MappingRatio", "BgRatio", "Count", "RichFactor", "FoldEnrichment",
              "Info"]
    refdf, degAnn, degAnnGene, totalAnnGene = get_enrichinfo(deginfo, backinfo,needcols)

    result = []
    colname = header.copy()
    colname.insert(len(header)-6,"Pvalue")
    colname.insert(len(header)-5,"Padj")
    if not degAnn.empty :
        ANNID = list(set(degAnn[header[0]].tolist()))
        for iANNID in ANNID :
            refSub = refdf[refdf[header[0]] == iANNID]
            degAnnSub = degAnn[degAnn[header[0]] == iANNID]

            annterm="/".join(set(degAnnSub[header[1]].tolist()))
            genelist = "/".join(degAnnSub["ID"].tolist())
            termdegnum = len(set(degAnnSub["ID"].values.tolist()))
            termtotalnum = len(set(refSub["ID"].values.tolist()))
            GeneRatio = f"{termdegnum}/{degAnnGene}"
            BgRatio = f"{termtotalnum}/{totalAnnGene}"
            RichFactor = termdegnum / termtotalnum
            FoldEnrichment = (termdegnum / degAnnGene) / (termtotalnum / totalAnnGene)
            result.append([iANNID,annterm,
                           GeneRatio,BgRatio,termdegnum,RichFactor,FoldEnrichment,
                           genelist])
        resultdf=pd.DataFrame(result,columns=header)
        resultdf['Pvalue']=resultdf.apply(calc_orapvalues, axis = 1)
        # FDR
        if resultdf['Pvalue'].dropna().empty :
            resultdf['Padj'] = np.nan
        else :
            # resultdf['Padj'] = scistat.false_discovery_control(resultdf['Pvalue'], method='bh')
            resultdf['Padj'] = multipletests(resultdf['Pvalue'], method=args.fdrmethods)[1]

        resultdf=resultdf[colname]
        resultdf=resultdf.sort_values("Pvalue")
    else :
        resultdf = pd.DataFrame(columns=colname)
    return resultdf

def run(args):
    autils.ensure_deps_or_exit("enrichora", None, None)  # 先检查依赖
    ofilename = os.path.join(args.outdir, "EnrichORA")
    try:
        indata = read_and_checkfile(args.infile,[],ofilename,args,"data")
        bgdata = read_and_checkfile(args.refmapfile,["ID","PathwayID","PathwayDescription"],
                                    ofilename,args,"bgdata",mincol=3)
        enrichdf = gen_enrichresult(indata,bgdata,args)
        enrichdf.to_excel(f"{ofilename}.xlsx",index=None)
        enrichdf.to_csv(f"{ofilename}.txt",sep="\t",index=None)
        print(f"富集分析完成，结果已保存至：")
        print(f"  {ofilename}.xlsx")
        print(f"  {ofilename}.txt")
    except Exception as e:
        print("".join(traceback.format_exception(type(e), e, e.__traceback__)))
        error_msg = (
            "富集分析计算出现错误.\n"
            "错误信息如下:\n" +
            "\n".join(textwrap.wrap(str(e), width=60))
        )
        print(error_msg)
        exit(1)

if __name__ == "__main__":
    cli = RunCLI(run)
    cli.run_cli()
    # cli.test_batch()
