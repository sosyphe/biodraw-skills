#!/usr/bin/env Rscript
# init_renv.R — 使用 renv 安装 R 包依赖
# 用法: Rscript init_renv.R <requirements.txt>

args <- commandArgs(trailingOnly = TRUE)
req_file <- args[1]

if (length(args) == 0 || is.na(req_file) || req_file == "") {
  stop("Usage: Rscript init_renv.R <requirements.txt>", call. = FALSE)
}
if (!file.exists(req_file)) {
  stop(paste0("依赖文件不存在: ", req_file), call. = FALSE)
}

# 获取 biodraw 根目录（脚本目录的父目录）
script_dir <- dirname(normalizePath(sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))])))
biodraw_dir <- dirname(script_dir)

# 设置镜像
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
options(BioC_mirror = "https://mirrors.tuna.tsinghua.edu.cn/bioconductor")

# 1. 检查 renv 是否安装(基础前置条件,必须由用户预先安装)
if (!requireNamespace("renv", quietly = TRUE)) {
  stop(
    paste0(
      "未检测到 renv 包,这是使用本 skill 的基础前置条件之一.\n",
      "请先在 R 中执行: install.packages(\"renv\")\n",
      "然后重新运行本脚本."
    ),
    call. = FALSE
  )
}
library("renv", character.only = TRUE)

# 2. 复制 requirements.txt 为 renv.lock
lockfile <- file.path(biodraw_dir, "renv.lock")
cat(paste("Using lockfile:", req_file, "\n"))
ok <- file.copy(req_file, lockfile, overwrite = TRUE)
if (!isTRUE(ok)) {
  stop(paste0("复制 lockfile 失败: ", req_file, " -> ", lockfile), call. = FALSE)
}

# 3. 在 biodraw 目录下初始化 renv（如果尚未初始化）
setwd(biodraw_dir)
if (!dir.exists(file.path(biodraw_dir, "renv"))) {
  cat("Initializing renv...\n")
  renv::init(bare = TRUE)
}

# 4. 安装依赖
cat("Restoring packages from renv.lock...\n")
tryCatch(
  renv::restore(prompt = FALSE),
  error = function(e) {
    stop(paste0("renv::restore 安装依赖失败:\n", conditionMessage(e)), call. = FALSE)
  }
)

cat("All dependencies installed.\n")
