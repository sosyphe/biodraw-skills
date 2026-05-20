#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sys.frames()[[1]]$ofile %||%
                                    sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))])))
source(file.path(script_dir, "utils.R"))

# 检查依赖
ensure_deps_or_exit(file.path(script_dir, "heatmap.cor.double.requirements.txt"))

parser_args <- function(){
  library(optparse)
  arg_defs <- list(
    list("--infile", "character", "./testdata/exampledata.tsv", "输入文件", NULL),
    list("--infile2", "character", "./testdata/exampledata2.tsv", "第二输入文件", NULL),
    list("--outdir", "character", "./testdata/output", "输出目录", NULL),
    list("--colannfile", "character", "", "列注释文件", NULL),
    list("--rowannfile", "character", "", "行注释文件", NULL),
    list("--colanncolorlist", "character", "", "列注释颜色列表", NULL),
    list("--rowanncolorlist", "character", "", "行注释颜色列表", NULL),
    list("--cormethod", "character", "pearson", "相关性计算方法", NULL),
    list("--ofiletype", "character", "pdf+png", "输出文件类型", NULL),
    list("--ofilewidth", "numeric", 12, "输出文件宽度", NULL),
    list("--ofileheight", "numeric", 12, "输出文件高度", NULL),
    list("--title", "character", "", "图标题", NULL),
    list("--legendtitle", "character", " ", "图例标题", NULL),
    list("--axisxsize", "numeric", 12, "X轴字体大小", NULL),
    list("--axisxrotation", "numeric", 90, "X轴旋转角度", NULL),
    list("--axisysize", "numeric", 12, "Y轴字体大小", NULL),
    list("--fontfamily", "character", "Times New Roman", "字体家族", NULL),
    list("--labelfold", "character", "yes", "标签是否折行", NULL),
    list("--scaletype", "character", "no", "缩放类型", NULL),
    list("--clusterrows", "character", "yes", "是否聚类行", NULL),
    list("--clustercols", "character", "yes", "是否聚类列", NULL),
    list("--showrownames", "character", "yes", "显示行名", NULL),
    list("--showcolnames", "character", "yes", "显示列名", NULL),
    list("--clustermethod", "character", "complete", "聚类方法", NULL),
    list("--ifdisplaynumbers", "character", "no", "是否显示数值", NULL),
    list("--displaydigits", "numeric", 2, "显示的小数位数", NULL),
    list("--ifdisplaysig", "character", "yes", "是否显示显著性", NULL),
    list("--downcolor", "character", "navy", "下调颜色", NULL),
    list("--midcolor", "character", "white", "中间颜色", NULL),
    list("--upcolor", "character", "red", "上调颜色", NULL),
    list("--bordercolor", "character", "grey", "边框颜色", NULL),
    list("--fontfacerow", "character", "plain", "行字体样式", NULL),
    list("--fontfacecol", "character", "plain", "列字体样式", NULL)
  )

  option_list <- create_optlist(arg_defs)
  args <- parse_args(OptionParser(option_list = option_list, usage = ""))
  return(args)
}
calc_cor <- function(indata1,indata2,errorfigname,args){
  library(Hmisc)
  library(dplyr)
  library(stats)

  tryCatch({
    indata1_mat <- as.matrix(indata1[,-which(names(indata1) == "Index")])
    rownames(indata1_mat) <- indata1$Index
    indata2_mat <- as.matrix(indata2[,-which(names(indata2) == "Index")])
    rownames(indata2_mat) <- indata2$Index
    if (identical(colnames(indata1_mat), colnames(indata2_mat))) {
      indata <- rbind(indata1_mat,indata2_mat)
    } else {
      diff_cols1 <- setdiff(colnames(indata1_mat), colnames(indata2_mat))
      diff_cols2 <- setdiff(colnames(indata2_mat), colnames(indata1_mat))
      stop(paste0("请确保两个输入文件除了特征列外列名完全一致\n",
                  "在第一个输入文件而不在第二个输入文件中的列:\n",
                  stringr::str_wrap(paste(diff_cols1,collapse = " "), width = 60), "\n",
                  "在第二个输入文件而不在第一个输入文件中的列:\n",
                  stringr::str_wrap(paste(diff_cols2,collapse = " "), width = 60), "\n"))
    }
    coresult <- rcorr(t(as.matrix(indata)),type=args$cormethod)
    corrvalue <- coresult$r %>% as.data.frame()
    corpvalue <- coresult$P %>% as.data.frame()
    resultlist <- list(
      cor_rvalue = corrvalue[rownames(indata1_mat), rownames(indata2_mat)],
      cor_pvalue = corpvalue[rownames(indata1_mat), rownames(indata2_mat)]
    )
    names(resultlist) <- c("cor_rvalue","cor_pvalue")

    if(all(is.na(resultlist$cor_rvalue))){
      stop(paste0("相关性计算结果均为NA\n请保证输入文件中没有完全一致的行/列"))
    }

    return(resultlist)
  }, error = function(e) {
    stop(paste0("相关性计算中出现错误:\n",
                stringr::str_wrap(e$message, width = 60),
                "\n\n可能原因及解决方法:\n",
                "1. 检查输入文件中是否包含全0/全NA行/列; \n",
                "2. 请确保至少有5列/5行信息用于计算相关; \n",
                "3. 如果仍有问题, 请联系技术支持人员. "))
  })
}
draw_heatmap <- function(indata,colanninfo,rowanninfo,errorfigname,args){
  library(grid)
  library(ggplot2)
  library(ComplexHeatmap)
  library(showtext)
  set.seed(123)
  showtext_auto()
  showtext_opts(dpi = 300)
  tryCatch(font_add("Arial", regular = "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf",
                    bold = "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf",
                    italic = "/usr/share/fonts/truetype/msttcorefonts/Arial_Italic.ttf"), error=function(e){})
  tryCatch(font_add("Times New Roman", regular = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf",
                              bold = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold.ttf",
                              italic = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Italic.ttf"), error=function(e){})
  tryCatch(font_add("Courier New", regular = "/usr/share/fonts/truetype/msttcorefonts/Courier_New.ttf",
                          bold = "/usr/share/fonts/truetype/msttcorefonts/Courier_New_Bold.ttf",
                          italic = "/usr/share/fonts/truetype/msttcorefonts/Courier_New_Italic.ttf"), error=function(e){})
  tryCatch(font_add("SourceHanSans", regular = "/usr/share/fonts/truetype/chinese/SourceHanSansCN-Regular.otf",
                            bold = "/usr/share/fonts/truetype/chinese/SourceHanSansCN-Bold.otf"), error=function(e){})
  tryCatch(font_add("SourceHanSerif", regular = "/usr/share/fonts/truetype/chinese/SourceHanSerif-Regular.ttc",
                             bold = "/usr/share/fonts/truetype/chinese/SourceHanSerif-Bold.ttc"), error=function(e){})
  tryCatch({
    if(!is.null(colanninfo)){
      colanninfo <- colanninfo %>% as.data.frame()
      colanninfo[is.na(colanninfo)] <- "NA"
      rownames(colanninfo) <- make.unique(as.character(colanninfo$Index))
      colanninfo <- colanninfo[, setdiff(colnames(colanninfo), "Index"), drop = FALSE]
      colcolorlist <- gen_anncolorlist(colanninfo,args$colanncolorlist)
      if("color" %in% colnames(colanninfo)){
        colanninfo <- subset(colanninfo,select = -which(names(colanninfo) == "color"))
      }
      va <- HeatmapAnnotation(
        df = colanninfo,
        col = colcolorlist,
        annotation_name_gp = gpar(fontfamily = args$fontfamily),
        annotation_legend_param = list(
          title_gp = gpar(fontfamily = args$fontfamily),
          labels_gp = gpar(fontfamily = args$fontfamily)
          )
      )
    }else{
      va <- NULL
    }
    if(!is.null(rowanninfo)){
      rowanninfo <- rowanninfo %>% as.data.frame()
      rowanninfo[is.na(rowanninfo)] <- "NA"
      rownames(rowanninfo) <- make.unique(as.character(rowanninfo$Index))
      rowanninfo <- rowanninfo[, setdiff(colnames(rowanninfo), "Index"), drop = FALSE]
      rowcolorlist <- gen_anncolorlist(rowanninfo,args$rowanncolorlist)
      if("color" %in% colnames(rowanninfo)){
        rowanninfo <- subset(rowanninfo,select = -which(names(rowanninfo) == "color"))
      }

      ha <- rowAnnotation(
        df = rowanninfo,
        col = rowcolorlist,
        annotation_name_gp = gpar(fontfamily = args$fontfamily),
        annotation_legend_param = list(
          title_gp = gpar(fontfamily = args$fontfamily),
          labels_gp = gpar(fontfamily = args$fontfamily)
          )
      )
    }else{
      ha <- NULL
    }

    drawdata <- indata$cor_rvalue
    drawdatapvalue <- indata$cor_pvalue
    rownames(drawdata) <- make.unique(as.character(rownames(drawdata)))
    colnames(drawdata) <- make.unique(as.character(colnames(drawdata)))
    rownames(drawdatapvalue) <- make.unique(as.character(rownames(drawdatapvalue)))
    colnames(drawdatapvalue) <- make.unique(as.character(colnames(drawdatapvalue)))
    drawdata[is.na(drawdata)] <- 0

    if ((args$clusterrows == "yes")){
      if ((nrow(drawdata) < 3)){ stop("当行聚类时,输入文件至少有3行")
      }else{
        invalid_rows <- apply(drawdata, 1, function(x) all(is.na(x) | !is.finite(x) | x == 0))
        if (any(invalid_rows)) {
          stop(paste0("当行聚类时,不能有是全0/全NA/全Inf的行\n请去除行聚类,如果需要聚类分析请删去以下行\n",
                      stringr::str_wrap(rownames(drawdata)[invalid_rows], width = 60)))
        }
      }
    }
    if ((args$clustercols == "yes")){
      if ((ncol(drawdata) < 3)){ stop("当列聚类时,输入文件至少有3列")
      }else{
        invalid_cols <- apply(drawdata, 2, function(x) all(is.na(x) | !is.finite(x) | x == 0))
        if (any(invalid_cols)) {
          stop(paste0("当列聚类时,不能有是全0/全NA/全Inf的列\n请去除列聚类,如果需要聚类分析请删去以下列\n",
                      stringr::str_wrap(colnames(drawdata)[invalid_cols], width = 60)))
        }
      }
    }

    if(args$labelfold == "yes"){
      rowshortnames <- shorten_names(rownames(drawdata))
      colshortnames <- shorten_names(colnames(drawdata))
      rownames(drawdata) <- rowshortnames
      colnames(drawdata) <- colshortnames
      rownames(drawdatapvalue) <- rowshortnames
      colnames(drawdatapvalue) <- colshortnames
      if (!is.null(rowanninfo)){
        rownames(rowanninfo) <- make.unique(shorten_names(rownames(rowanninfo)))
      }
      if (!is.null(colanninfo)){
        colnames(colanninfo) <- make.unique(shorten_names(colnames(colanninfo)))
      }
    }

    drawdata_scaled <- scale_mats(drawdata,args$scaletype)
  }, error = function(e) {
      stop(paste0("绘图准备时出现问题:\n",
                  stringr::str_wrap(e$message, width = 60),
                  "\n\n可能原因及解决方法:\n",
                  "1. 检查输入文件第一列是否包含特殊字符; \n",
                  "2. 确认第一列的名称长度不超过200个字符; \n",
                  "3. 如果仍有问题, 请联系技术支持人员. "))
  })

  tryCatch({
    formats <- unlist(strsplit(tolower(args$ofiletype), "\\+"))
    resultfiles <- list(
      pdf = file.path(paste0(errorfigname, ".pdf")),
      png = file.path(paste0(errorfigname, ".png")),
      svg = file.path(paste0(errorfigname, ".svg"))
    )
    pdf(resultfiles$pdf,width=args$ofilewidth, height=args$ofileheight)

    ht_opt(legend_title_gp = gpar(fontfamily = args$fontfamily),
           legend_labels_gp = gpar(fontfamily = args$fontfamily),
           heatmap_row_names_gp = gpar(fontsize = args$axisysize,
                                      fontface = args$fontfacerow,
                                       fontfamily = args$fontfamily),
           heatmap_column_names_gp = gpar(rot = args$axisxrotation,
                                          fontsize = args$axisxsize,
                                          fontface = args$fontfacecol,
                                          fontfamily = args$fontfamily),
           heatmap_row_title_gp = gpar(fontsize = args$axisxsize,
                                       fontfamily = args$fontfamily),
           heatmap_column_title_gp = gpar(fontsize = args$axisxsize,
                                          fontfamily = args$fontfamily))

    heatmap <- ComplexHeatmap::Heatmap(drawdata_scaled,
                       cluster_rows=check_yes(args$clusterrows),
                       cluster_columns=check_yes(args$clustercols),
                       col = colorRampPalette(c(args$downcolor, args$midcolor, args$upcolor))(100),
                       top_annotation = va,
                       left_annotation = ha,
                       column_title = args$title,
                       name = args$legendtitle,
                       rect_gp = gpar(col = args$bordercolor, lwd = 1),
                       show_row_names = check_yes(args$showrownames),
                       row_names_max_width = max_text_width(rownames(drawdata_scaled)),
                       show_column_names = check_yes(args$showcolnames),
                       column_names_max_height = max_text_width(colnames(drawdata_scaled)),
                       layer_fun = function(j, i, x, y, width, height, fill) {
                           val  <- pindex(as.matrix(drawdata), i, j)
                           pval <- pindex(as.matrix(drawdatapvalue), i, j)
                           if (args$ifdisplaynumbers == "yes") {
                                   display_text <- sprintf(paste0("%.", args$displaydigits, "f"), val)
                               } else {
                                   display_text <- ""
                           }
                           if (args$ifdisplaysig == "yes") {
                               sig <- ifelse(is.na(pval), "",
                                             ifelse(pval < 0.001, "***",
                                                   ifelse(pval < 0.01, "**",
                                                           ifelse(pval <= 0.05, "*", ""))))
                               if (args$ifdisplaynumbers == "yes") {
                                   display_text <- paste0(display_text, "\n", sig)
                               } else {
                                   display_text <- sig
                               }
                             }
                           grid.text(display_text, x, y,
                                     gp = gpar(fontsize = args$axisigfontsize,
                                               fontfamily = args$fontfamily))
                       }
                      )

    draw(heatmap)
    dev.off()
    pdftools::pdf_convert(resultfiles$pdf, page = 1, dpi = 300, filenames = resultfiles$png)
    if ("svg" %in% formats){
      svg(resultfiles$svg,width=args$ofilewidth, height=args$ofileheight)
      draw(heatmap)
      dev.off()
    }
    for (fmt in setdiff(names(resultfiles)[1:3], formats)) {
      if (file.exists(resultfiles[[fmt]])) unlink(resultfiles[[fmt]])
    }

    gn <- if (check_yes(args$clusterrows)) rownames(drawdata)[heatmap@row_order] else rownames(drawdata)
    sn <- if (check_yes(args$clustercols)) colnames(drawdata)[heatmap@column_order] else colnames(drawdata)
    heatmapdata=drawdata[gn,sn]
    heatmapdatap=drawdatapvalue[gn,sn]

    return(list(data = list("cor_rvalue"=as.data.frame(heatmapdata),"cor_pvalue"=as.data.frame(heatmapdatap))))
  }, error = function(e) {
    if (!is.null(dev.list())) {
      dev.off()
    }
    stop(paste0("绘图时出现问题:\n",
                stringr::str_wrap(e$message, width = 60),
                "\n\n您可以尝试以下操作解决: \n",
                "1. 调整图片的宽度和高度, 使图形空间足够; \n",
                "2. 关闭行和列数据的标准化处理; \n",
                "3. 取消行和列聚类; \n",
                "4. 如果问题仍然存在, 请联系技术支持人员. "))
  })

}
#################################### MAIN ######################################
args <- parser_args()
if (!dir.exists(args$outdir)) dir.create(args$outdir, recursive = TRUE)

data1 <- read_infile(args$infile,labelcolname="",infiletype="data",
                    outfileprefix = file.path(args$outdir,"Heatmap.Correlation"),outfilesuffix=args$ofiletype)
data2 <- read_infile(args$infile2,labelcolname="",infiletype="data",
                    outfileprefix = file.path(args$outdir,"Heatmap.Correlation"),outfilesuffix=args$ofiletype)
cordata <- calc_cor(data1,data2,file.path(args$outdir,"Heatmap.Correlation"),args)

tryCatch({
  if (!is.null(args$colannfile) && (args$colannfile != "")){
    colann <- read_infile(args$colannfile,infiletype="annotation",labelcolname="",
                          datacolumns = colnames(cordata$cor_rvalue),
                          outfileprefix = file.path(args$outdir,"Heatmap.Correlation"),outfilesuffix=args$ofiletype)
    colanninfo <- colann[colann$Index %in% colnames(cordata$cor_rvalue), , drop = FALSE]
  }else{
    colanninfo <- NULL
  }
  if (!is.null(args$rowannfile) && (args$rowannfile != "")){
    rowann <- read_infile(args$rowannfile,infiletype="annotation",labelcolname="Index",
                          datacolumns = rownames(cordata$cor_rvalue),
                          outfileprefix = file.path(args$outdir,"Heatmap.Correlation"),outfilesuffix=args$ofiletype)
    rowanninfo <- rowann[rowann$Index %in% rownames(cordata$cor_rvalue), , drop = FALSE]
  }else{
    rowanninfo <- NULL
  }
  }, error = function(e) {
    stop(paste0("文件读取时出现问题:\n",
                stringr::str_wrap(e$message, width = 60),
                "\n\n您可以尝试以下操作解决: \n",
                "1. 检查输入数据/注释文件格式; \n",
                "2. 检查输入数据/注释文件是否对应; \n",
                "3. 如果问题仍然存在, 请联系技术支持人员. "))
})

heatmapresult <- draw_heatmap(cordata,colanninfo,rowanninfo,file.path(args$outdir,"Heatmap.Correlation"),args)
write_resultdata(heatmapresult$data,file.path(args$outdir,"Heatmap.Correlation.xlsx"),outfiletype="Correlation")
