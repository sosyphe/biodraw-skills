#!/usr/bin/env python

import os
import re
import shutil
import pathlib
import textwrap

from PIL import Image
import pandas as pd
import pymupdf as pymu

# 中文字体候选列表（按优先级排序）
CJK_FONT_CANDIDATES = [
    # 思源系列
    "Source Han Sans CN", "Source Han Sans SC", "Source Han Serif SC", "Source Han Serif TC",
    # 文泉驿系列
    "WenQuanYi Micro Hei", "WenQuanYi Zen Hei", "WenQuanYi Zen Hei Sharp",
    # Noto 系列
    "Noto Sans CJK SC", "Noto Sans CJK TC", "Noto Serif CJK SC", "Noto Serif CJK TC",
    # Windows 常见字体
    "Microsoft YaHei", "SimHei", "SimSun", "FangSong", "KaiTi",
    # macOS 常见字体
    "PingFang SC", "PingFang TC", "STHeiti", "STSong",
    # Linux 常见字体
    "Droid Sans Fallback", "AR PL UMing CN", "AR PL UKai CN",
]


def get_system_fonts() -> list:
    """获取系统所有可用字体名称列表"""
    import matplotlib.font_manager as fm
    fonts = set()
    for f in fm.fontManager.ttflist:
        fonts.add(f.name)
    return list(fonts)


def has_cjk_font() -> bool:
    """检测系统是否安装了中文字体"""
    system_fonts = get_system_fonts()
    for cjk_font in CJK_FONT_CANDIDATES:
        if cjk_font in system_fonts:
            return True
    return False


def get_best_font_family(prefer_cjk: bool = True) -> list:
    """
    获取最佳字体列表（matplotlib font.family 格式）

    参数:
        prefer_cjk: 是否优先使用中文字体（当文本可能包含中文时设为 True）

    返回:
        list: 字体列表，用于 matplotlib 的 font.family 设置
    """
    import matplotlib.font_manager as fm

    system_fonts = set(get_system_fonts())
    result = []

    if prefer_cjk:
        # 优先查找中文字体
        for cjk_font in CJK_FONT_CANDIDATES:
            if cjk_font in system_fonts:
                result.append(cjk_font)
                break
        if not result:
            # 没有中文字体，给出提示但不阻止运行
            pass

    # 添加英文/数字常用字体作为后备
    for en_font in ["Arial", "DejaVu Sans", "Helvetica", "sans-serif"]:
        if en_font in system_fonts:
            result.append(en_font)
            break
    else:
        result.append("sans-serif")  # 最终后备

    return result


def suggest_cjk_font_install() -> str:
    """返回中文字体安装建议（当未检测到中文字体时）"""
    import platform
    system = platform.system()

    if system == "Linux":
        return "sudo apt install fonts-noto-cjk fonts-wqy-zenhei  # Debian/Ubuntu\n或 sudo yum install google-noto-sans-cjk-fonts  # CentOS/RHEL"
    elif system == "Darwin":
        return "# macOS 通常自带中文字体，如需安装：\nbrew install --cask font-noto-sans-cjk"
    elif system == "Windows":
        return "# Windows 通常自带中文字体\n# 如需额外字体，从 https://github.com/adobe-fonts/source-han-sans/releases 下载"
    else:
        return "# 请根据您的操作系统安装中文字体"


def re_mkdir(indir: str) -> None:
    if os.path.exists(indir):
        shutil.rmtree(indir)
    os.makedirs(indir)

def get_infiletype(infile: str) -> str:
    path = pathlib.Path(infile)
    suffix = f".{''.join(path.suffixes).split('.')[-1]}"
    return suffix

def hex2rgba(instr: str) -> str:
    color = instr.strip().strip("'\"")
    if color.lower().startswith(("rgb(", "rgba(")):
        return instr
    hexcode = color.lstrip("#")
    if len(hexcode) == 6:
        return f"#{hexcode}"
    elif len(hexcode) == 8:
        r = int(hexcode[0:2], 16)
        g = int(hexcode[2:4], 16)
        b = int(hexcode[4:6], 16)
        a = int(hexcode[6:8], 16) / 255
        return f"rgba({r},{g},{b},{a:.3f})"

def pdf2png(inpdfile:str) -> None :
    doc = pymu.Document(inpdfile)
    page = doc.load_page(0)
    image = page.get_pixmap(matrix=pymu.Matrix(3, 3),dpi=300)
    image.save(f'{inpdfile.replace(".pdf",".png")}', "PNG")

def save_matplotfig(drawfig,outfileprefix:str,outfilesuffix:str):
    '''兼容SDK,会有缓存,需要每次都重新生成一遍'''
    def _save(fig, path, fmt):
        try:
            fig.savefig(path, dpi=300, bbox_inches="tight", format=fmt)
        except AttributeError:
            fig.write_image(path, format=fmt, scale=3)
    formats = outfilesuffix.split("+")
    format_pdf = f"{outfileprefix}.pdf"
    format_png = f"{outfileprefix}.png"
    format_svg = f"{outfileprefix}.svg"
    _save(drawfig, format_pdf, "pdf")
    pdf2png(format_pdf)
    _save(drawfig, format_svg, "svg")
    if "pdf" not in formats and os.path.exists(format_pdf):
        os.remove(format_pdf)
    if "png" not in formats and os.path.exists(format_png):
        os.remove(format_png)
    if "svg" not in formats and os.path.exists(format_svg):
        os.remove(format_svg)

def read_infileinfo(infile: str, outfileprefix: str, outfilesuffix: str) -> pd.DataFrame:
    sepdict = {
        ".csv": ",",
        ".tsv": "\t",
        ".txt": "\t",
        ".xls": "\t"
    }
    filetype = get_infiletype(infile)

    if not os.path.exists(infile):
        raise FileNotFoundError(
            f"读取文件失败:未找到输入文件\n"
            f"请确认文件路径是否正确,并确保文件已上传.\n"
        )

    try:
        if filetype == ".xlsx":
            data = pd.read_excel(infile, header=0, engine="openpyxl")
        elif filetype in sepdict.keys():
            data = pd.read_csv(infile, sep=sepdict[filetype], header=0)
        else:
            raise ValueError(
                f"读取文件失败:不支持的文件格式\n"
                f"目前仅支持以下格式:xlsx / csv / tsv / txt / xls\n"
            )
    except (FileNotFoundError, ValueError):
        raise
    except Exception as e:
        raise RuntimeError(
            "读取文件失败:文件内容或编码格式可能存在问题\n"
            "常见原因:\n"
            "1. 文件编码不是 UTF-8(特别是包含中文时)\n"
            "2. 文件损坏或格式与扩展名不一致\n"
            "3. 文件中存在特殊符号或空行\n\n"
            f"技术错误信息:\n{textwrap.shorten(str(e), width=200)}"
        ) from e

    return data

def gen_errorexit(message: str, outfileprefix: str, outfilesuffix: str) -> None:
    """生成错误图片并退出程序"""
    import matplotlib.pyplot as plt
    from matplotlib import font_manager

    # 使用系统默认字体，不强制指定
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.text(0.5, 0.5, message,
            ha='center', va='center',
            fontsize=12, wrap=True)
    ax.axis('off')
    plt.tight_layout()
    save_matplotfig(fig, outfileprefix, outfilesuffix)
    plt.close(fig)
    exit(1)


def ensure_deps_or_exit(script_basename: str, outfileprefix: str | None = None, outfilesuffix: str | None = None) -> None:
    """
    在脚本入口调用，检查当前脚本所需依赖是否已安装。
    script_basename: 脚本名（不含路径和后缀），如 'radar'
    outfileprefix: 输出文件前缀（可选），提供则生成错误图片，否则仅打印
    outfilesuffix: 输出文件后缀（可选）
    """
    import subprocess, sys, os

    script_dir = os.path.dirname(os.path.abspath(__file__))
    req_file = os.path.join(script_dir, f"{script_basename}.requirements.txt")

    if not os.path.exists(req_file):
        return  # 无依赖文件，跳过检查

    venv_python = os.path.join(os.path.dirname(script_dir), ".venv", "bin", "python")
    python = venv_python if os.path.isfile(venv_python) else sys.executable

    check_script = os.path.join(script_dir, "check_deps.py")
    r = subprocess.run(
        [python, check_script, f"{script_basename}.requirements.txt"],
        capture_output=True, text=True, cwd=script_dir
    )

    if r.returncode != 0:
        missing = r.stdout.strip() or r.stderr.strip()
        msg = (
            f"依赖检查失败\n\n"
            f"{missing}\n\n"
            f"请先安装依赖:\n"
            f"  cd {os.path.dirname(script_dir)}\n"
            f"  {python} scripts/check_deps.py {script_basename}.requirements.txt --fix\n\n"
        )
        if outfileprefix and outfilesuffix:
            gen_errorexit(msg, outfileprefix, outfilesuffix)
        else:
            print(f"ERROR: {msg}", file=sys.stderr)
            sys.exit(1)

