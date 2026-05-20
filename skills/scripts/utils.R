
re_mkdir <- function(folderpath){
  if (file.exists(folderpath)) {
    unlink(folderpath,recursive = TRUE)
  }
  dir.create(folderpath)
}
check_yes <- function(instring) {
  if (tolower(instring) == "yes") {
    return(TRUE)
  } else {
    return(FALSE)
  }
}
scale_mats <- function(data, scaletype = "no"){
  if (tolower(scaletype) == "no") {
    return(data)
  } else if (tolower(scaletype) == "scale") {
    return(t(apply(data, 1, function(x) (x - min(x)) / (max(x) - min(x)))))
  } else if (tolower(scaletype) == "zscore") {
    return(t(scale(t(data))))
  } else {
    return(data)
  }
}
create_optlist <- function(arg_defs) {
  lapply(arg_defs, function(x) {
    make_option(
      c(x[[1]]),
      type = x[[2]],
      default = x[[3]],
      help = x[[4]]
    )
  })
}
shorten_names <- function(names, max_length = 60) {
  sapply(names, function(name) {
    if (nchar(name) > max_length) {
      return(paste(substr(name, 1, max_length), "...", sep = ""))
    } else {
      return(name)
    }
  })
}
get_ggtheme <- function(themename) {
  themename <- tolower(themename)
  theme <- switch(
    themename,
    bw = ggplot2::theme_bw(),
    classic = ggplot2::theme_classic(),
    gray = ggplot2::theme_gray(),
    light = ggplot2::theme_light(),
    minimal = ggplot2::theme_minimal(),
    void = ggplot2::theme_void(),
    {
      warning(sprintf("未知主题 '%s',已使用默认主题 theme_gray()", themename))
      ggplot2::theme_gray()
    }
  )
  return(theme)
}
isvalid_color <- function(color_vec) {
  sapply(color_vec, function(col) {
    col <- as.character(col)
    if (grepl("^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$", col)) {
        return(TRUE)
    }
    tryCatch({
        grDevices::col2rgb(col)
        TRUE
    }, error = function(e) {
        FALSE
    })
  })
}
gen_anncolorlist <- function(anninfo, anncolorlist_str){
  if (is.null(anncolorlist_str) || anncolorlist_str == "") {
    return(NULL)
  }
  result <- list()
  pairs <- unlist(strsplit(anncolorlist_str, ","))
  for (p in pairs) {
    parts <- unlist(strsplit(p, ":"))
    if (length(parts) >= 2) {
      col <- trimws(parts[1])
      color <- trimws(parts[2])
      if (col %in% names(anninfo)) {
        vals <- unique(anninfo[[col]])
        result[[col]] <- rep(color, length(vals))
        names(result[[col]]) <- vals
      }
    }
  }
  if (length(result) == 0) return(NULL)
  return(result)
}
save_resultfig <- function(drawfig,outfileprefix,outfilesuffix,drawfigwidth,drawfigheight){
  library(Cairo)
  library(pdftools)

  formats <- unlist(strsplit(tolower(outfilesuffix), "\\+"))
  resultfiles <- list(
      pdf = file.path(paste0(outfileprefix, ".pdf")),
      png = file.path(paste0(outfileprefix, ".png")),
      svg = file.path(paste0(outfileprefix, ".svg")),
      html = file.path(paste0(outfileprefix, ".html")),
      htmlfiles = file.path(paste0(outfileprefix, "_files"))
  )

  if ("html" %in% formats){
    htmlwidgets::saveWidget(widget = drawfig, file = resultfiles$html, selfcontained = TRUE)
    unlink(resultfiles$htmlfiles, recursive = TRUE)
  }else{
    ggsave(drawfig, filename = resultfiles$pdf,
            width = drawfigwidth, height = drawfigheight,
            dpi = 300, unit = "in", device = cairo_pdf,
            limitsize = FALSE)
    pdftools::pdf_convert(resultfiles$pdf, page = 1, dpi = 300, filenames = resultfiles$png)
    if ("svg" %in% formats){
      ggsave(drawfig, filename = resultfiles$svg,
            width = drawfigwidth, height = drawfigheight,
            unit = "in", device = svg,
            limitsize = FALSE)
    }
  }
  for (fmt in setdiff(names(resultfiles)[1:3], formats)) {
    if (file.exists(resultfiles[[fmt]])) unlink(resultfiles[[fmt]])
  }
}
write_resultdata <- function(data,outfilename,outfiletype=""){
  library(openxlsx)
  wb <- createWorkbook()

  if (outfiletype == "Correlation"){
    addWorksheet(wb,"cor_rvalue")
    writeData(wb,sheet = 1,data$cor_rvalue,
              rowNames = TRUE,colNames = TRUE)
    addWorksheet(wb,"cor_pvalue")
    writeData(wb,sheet = 2,data$cor_pvalue,
              rowNames = TRUE,colNames = TRUE)
  } else {
    addWorksheet(wb,"PCA")
    writeData(wb,sheet = 1,data$pca,
              rowNames = FALSE,colNames = TRUE)
    addWorksheet(wb,"Variance")
    writeData(wb,sheet = 2,data$variance,
              rowNames = FALSE,colNames = TRUE)
  }
  saveWorkbook(wb,outfilename,overwrite = TRUE)
}
ensure_deps_or_exit <- function(req_file, outfileprefix = NULL, outfilesuffix = NULL) {
  # 检查依赖文件是否存在
  if (!file.exists(req_file)) return(invisible(NULL))

  content <- readLines(req_file, warn = FALSE)
  content <- content[!grepl("^#|^$", content)]

  # 支持 JSON 格式（renv.lock 格式）的依赖文件
  is_json <- grepl("^\\s*\\{", content[1])

  if (is_json) {
    # JSON 格式: 从 renv.lock 中提取包名
    if (!require("jsonlite", character.only = TRUE, quietly = TRUE)) {
      stop("检测到 JSON 格式的依赖文件, 但未安装 jsonlite 包, 请先安装 jsonlite")
    }
    lock_data <- jsonlite::fromJSON(req_file)
    pkgs <- names(lock_data$Packages)
  } else {
    # 文本格式: 每行一个包名
    pkgs <- content
  }

  missing <- character(0)
  for (p in pkgs) {
    if (!require(p, character.only = TRUE, quietly = TRUE)) {
      missing <- c(missing, p)
    }
  }

  if (length(missing) == 0) return(invisible(NULL))

  msg <- paste0(
    "依赖检查失败\n\n",
    "缺失的包: ", paste(missing, collapse = ", "), "\n\n",
    "请先安装依赖:\n",
    "  cd ", dirname(req_file), "/../\n",
    "  Rscript scripts/check_deps.R ", basename(req_file), "\n\n",
  )

  if (!is.null(outfileprefix) && !is.null(outfilesuffix)) {
    tryCatch({
      library(ggplot2)
      fig <- ggplot() + annotate("text", x = 0.5, y = 0.5, label = msg,
                                 size = 4, hjust = 0.5, vjust = 0.5) +
        theme_void() + theme(text = element_text(family = "sans"))
      ggsave(paste0(outfileprefix, ".pdf"), fig, width = 10, height = 6, dpi = 300)
    }, error = function(e) {
      message("[check_deps] 无法生成错误 PDF: ", conditionMessage(e))
    })
  }
  stop(msg, call. = FALSE)
}

gen_errorexit <- function(message, outfileprefix, outfilesuffix) {
  msg <- paste(message, collapse = "\n")
  tryCatch({
    library(ggplot2)
    fig <- ggplot() + annotate("text", x = 0.5, y = 0.5, label = msg,
                               size = 4, hjust = 0.5, vjust = 0.5) +
      theme_void() + theme(text = element_text(family = "sans"))
    ggsave(paste0(outfileprefix, ".pdf"), fig, width = 10, height = 6, dpi = 300)
  }, error = function(e) {
    message("[gen_errorexit] 无法生成错误 PDF: ", conditionMessage(e))
  })
  stop(msg, call. = FALSE)
}

read_infile <- function(infile,infiletype="data",labelcolname="",datacolumns=c(""),outfileprefix="",outfilesuffix="png"){
  library(readr)
  library(dplyr)
  library(openxlsx)

  if (!file.exists(infile)) {
    stop(
      paste0(
        "读取文件失败: 未找到输入文件\n\n",
        "请确认文件路径是否正确, 并确保文件已上传.\n",
      ),
      call. = FALSE
    )
  }

  file_name <- tools::file_path_sans_ext(infile)
  file_extension <- tools::file_ext(infile)
  if (file_extension == "xlsx"){
    tryCatch(
      {
        indata <- read.xlsx(infile,
                            colNames = TRUE,
                            rowNames = FALSE,
                            check.names = FALSE) %>%
                  magrittr::set_colnames(read.xlsx(infile,
                                                    rows = 1,
                                                    colNames = FALSE,
                                                    check.names = FALSE) %>%
                                      as.character())
      },error = function(e) {
        error_msg <- paste0(
            "读取Excel文件失败: 文件内容或编码格式可能存在问题\n\n",
            "常见原因:\n",
            "1. 文件编码不是 UTF-8(特别是包含中文时)\n",
            "2. 文件损坏或格式与扩展名xlsx不一致\n",
            "3. 文件中存在特殊符号或空行\n\n",
            "技术错误信息:\n",
            stringr::str_wrap(conditionMessage(e), width = 60)
          )
        stop(error_msg, call. = FALSE)
      }
    )
  } else if (file_extension %in% c("csv","tsv","txt","xls")) {
    filesep <- switch(file_extension, csv = ",", tsv = "\t", txt = "\t", "\t")
    enc <- tryCatch({
      guess_encoding(infile)
    }, error = function(e) {
      stop(
        paste0(
          "无法读取输入文件: 请检查输入文件编码格式是否为 UTF-8\n",
          stringr::str_wrap(conditionMessage(e), width = 60)
        ),
        call. = FALSE
      )
    })
    denc <- if (!is.null(enc) && nrow(enc) > 0) enc$encoding[1] else "UTF-8"
    tryCatch(
      {
        indata <- readr::read_delim(infile,
                             delim = filesep,
                             col_names = TRUE,
                             quote = "\"",
                             locale = locale(encoding = denc),
                             trim_ws = TRUE,
                             show_col_types = FALSE)
      },
      error = function(e) {
        error_msg <- paste0(
              "读取文件失败: 文件内容或编码格式可能存在问题\n\n",
              "常见原因:\n",
              "1. 文件编码不是 UTF-8(特别是包含中文时)\n",
              "2. 文件损坏或格式与扩展名不一致\n",
              "3. 文件中存在特殊符号或空行\n\n",
              "技术错误信息:\n",
              stringr::str_wrap(conditionMessage(e), width = 60)
            )
        stop(error_msg, call. = FALSE)
      }
    )
  } else {
    stop(
      paste0(
        "读取文件失败: 不支持的文件格式\n\n",
        "目前仅支持以下格式: xlsx / csv / tsv / txt / xls\n",
      ),
      call. = FALSE
    )
  }

  ### 判断输入文件是否正确
  if (is.null(indata)) {
    stop("输入文件为空或未读取到数据,请检查文件内容", call. = FALSE)
  }
  if (nrow(indata) == 0) {
    stop("输入文件中至少含有一行数据,请检查文件内容", call. = FALSE)
  } else if (ncol(indata) == 0) {
    stop("输入文件中至少含有一列数据,请检查文件内容", call. = FALSE)
  }
  if(infiletype == "data"){
    if (is.null(labelcolname) || labelcolname == "") {
      labelcolname <- as.character(colnames(indata)[1])
    }
    col_idx <- which(as.character(colnames(indata)) == labelcolname)
    if (length(col_idx) == 0) {
      stop(paste0("输入文件中未找到必须的列\n", labelcolname,
                  "\n请确保特征列名(如 KEGG 模式需 Mapid,GO 模式需 ID)与文件中第一列名一致"),
           call. = FALSE)
    } else if (length(col_idx) > 1) {
      stop(paste0("输入文件第一列\n",labelcolname,"\n在列名中不唯一,请确保特征列名在文件中不重复"), call. = FALSE)
    }
    col_vals <- as.character(indata[[labelcolname]])
    dup_vals <- unique(col_vals[duplicated(col_vals)])
    if(any(is.na(col_vals) | col_vals == "")){
      stop(paste0("输入文件第一列\n",labelcolname,"\n中存在空值,请确保特征列中没有空值"), call. = FALSE)
    }else if(length(dup_vals) > 0){
      stop(
        paste0(
          "输入文件第一列\n", labelcolname,
          "\n中存在重复值,请确保特征列中没有重复值\n",
          "重复值为: ", stringr::str_wrap(paste(dup_vals, collapse = ", "), width = 60)
        ), call. = FALSE)
    }else{
      indata$Index <- indata[[labelcolname]]
      if (labelcolname != "Index") {
        indata[[labelcolname]] <- NULL
      }
    }
    if(length(datacolumns) > 0 && !all(datacolumns == "")) {
      missingcols <- datacolumns[!datacolumns %in% colnames(indata)]
      if (length(missingcols) > 0) {
        stop(
          paste0(
            "请检查文件列名,输入数据文件中缺少以下必须的列名:\n",
            stringr::str_wrap(paste(missingcols, collapse = ", ")),
            "\n"
          ), call. = FALSE
      )
    }
    }
  } else if(infiletype == "sample"){
    needcols <- c("sample","group")
    missingcols <- setdiff(needcols, colnames(indata))
    if (length(missingcols) > 0) {
      stop(
        paste0(
          "输入样本文件必须包含以下列:",
          paste(missingcols, collapse = ", "),
          ".请检查上传的样本文件内容."
        ), call. = FALSE
        )
    }
    indata <- indata %>%
      dplyr::mutate(
        sample = as.character(sample),
        group = as.character(group)
      )
    dupsamples <- unique(indata$sample[duplicated(indata$sample)])
    if (length(dupsamples) > 0) {
      stop(
        paste0(
          "输入样本文件中的 sample 列存在重复值,请保证 sample 列中没有重复值.重复值为: ",
          stringr::str_wrap(paste(dupsamples, collapse = ", "), width = 60)
        ), call. = FALSE
        )
    }
    missingsamples <- setdiff(indata$sample, datacolumns)
    if (length(missingsamples) > 0) {
      stop(
        paste0(
          "输入样本文件中以下样本不在数据文件中,请检查文件内容:",
          stringr::str_wrap(paste(missingsamples, collapse = ", ")),
          "\n注意: 数据文件第一列在绘图时默认会被去除,请不要将这些样本作为第一列."
        ), call. = FALSE
        )
    }
  }
  return(indata)
}
