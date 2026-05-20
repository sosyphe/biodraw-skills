#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sys.frames()[[1]]$ofile %||% 
                                    sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))])))
source(file.path(script_dir, "utils.R"))

parser_args <- function(){
  library(optparse)
  arg_defs <- list(
      list("--infile", "character", "./testdata/exampledata.tsv", "", NULL),
      list("--insamplefile", "character", "./testdata/examplesample.tsv", "", NULL),
      list("--outdir", "character", "./testdata/output", "", NULL),
      list("--ofiletype", "character", "pdf", "", NULL),
      list("--ofilewidth", "numeric", 12, "", NULL),
      list("--ofileheight", "numeric", 8, "", NULL),
      list("--title", "character", "", "", NULL),
      list("--titletextsize", "numeric", 1.5, "", NULL),
      list("--dotxlabelsize", "numeric", 1.3, "", NULL),
      list("--labeltextsize", "numeric", 1, "", NULL),
      list("--heatmaptextsize", "numeric", 1, "", NULL),
      list("--fontfamily", "character", "Times New Roman", "", NULL),
      list("--labelfold", "character", "yes", "", NULL),
      list("--drawtopN", "numeric", 20, "", NULL),
      list("--sortorder", "character", "desc", "", NULL),
      list("--labelrotation", "numeric", 45, "", NULL),
      list("--colorlist", "character", "", "", NULL)
  )

  option_list <- create_optlist(arg_defs)
  args = parse_args(OptionParser(option_list = option_list,usage = ""))
  return(args)
}
calc_lollipopheatmap <- function(data,sampledata,args){
  library(dplyr)
  library(tidyr)

  # 流程用
  # if ('Sig' %in% colnames(data)){
  #   data <- data[data$Sig %in% c('down','up'),]
  # }

  col <- sampledata$sample[sampledata$sample %in% colnames(data)]
  resultdata <- data[,c("Index","VIP",col)] %>%
                    pivot_longer(cols = col,
                    names_to = "sample",
                    values_to = "value")
  tmpresultdata <- merge(resultdata, sampledata, by = "sample", all.x = TRUE)
  calcresultdata <- tmpresultdata %>%
                    group_by(Index,VIP,group) %>%
                    summarize(
                        mean = mean(value, na.rm = TRUE),
                        .groups = 'keep'
                      ) %>%
                      pivot_wider(
                        names_from = group,
                        values_from = mean
                      )

  if (args$sortorder == "desc"){
    calcresultdata <- calcresultdata %>% arrange(desc(VIP)) %>% head(args$drawtopN)
  }else{
    calcresultdata <- calcresultdata %>% arrange(VIP) %>% head(args$drawtopN)
  }

  return(calcresultdata)
}
drawsave_lollipopheatmap <- function(indata,outfileprefix,args){
  library(ggrepel)
  library(showtext)
  showtext_auto()
  showtext_opts(dpi = 300)
  font_add(family = "Arial", regular = "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf")
  font_add(family = "Times New Roman", regular = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf")
  font_add(family = "Courier New", regular = "/usr/share/fonts/truetype/msttcorefonts/Courier_New.ttf")
  font_add(family = "SourceHanSans", regular = "/usr/share/fonts/truetype/chinese/SourceHanSansCN-Regular.otf")
  font_add(family = "SourceHanSerif", regular = "/usr/share/fonts/truetype/chinese/SourceHanSerif-Regular.ttc")
  
  if (!is.null(args$colorlist) && args$colorlist != "") {
      groupcolor <- unlist(stringr::str_split(args$colorlist,","))
      if (length(groupcolor) < length(unique(sampledata$group))) {
        print("输入的颜色个数少于组数")
      }
      if (!all(isvalid_color(groupcolor))) {
        gen_errorexit("检测到非法的颜色代码\n请确保所有颜色为合法的16进制格式(如 #FF0000)或者常规red/blue等颜色",
                      outfileprefix,args$ofiletype)
      }
      col <- rep(groupcolor, length.out = ncol(indata)-2)
  }else{
      colorpalette <- ifelse(F, "Greys", "RdYlBu")
      col <- colorRampPalette(RColorBrewer::brewer.pal(10, colorpalette))(ncol(indata)-2)
  }

  if (args$labelfold == "yes") {
    drawdata$Index <- shorten_names(drawdata$Index)
  }
  drawdata$Index <- factor(drawdata$Index,level=drawdata$Index)
  drawdataheatmap <- drawdata[,3:ncol(drawdata)]

  tryCatch({
    formats <- unlist(strsplit(tolower(args$ofiletype), "\\+"))
    resultfiles <- list(
      pdf = file.path(paste0(outfileprefix, ".pdf")),
      png = file.path(paste0(outfileprefix, ".png")),
      svg = file.path(paste0(outfileprefix, ".svg")),
      temp = file.path(paste0(outfileprefix, ".temp.pdf"))
    )
    pdf(resultfiles$pdf, width=args$ofilewidth, height=args$ofileheight)
    
    par(mar = c(3,max(nchar(as.character(drawdata$Index)))/2.5, 3, ncol(drawdataheatmap)+3),bg = "white",
          family = args$fontfamily)
    dotchart(drawdata$VIP,
            bg = "#585855", cex = args$dotxlabelsize)
    mtext(side = 2, at = 1:nrow(drawdataheatmap), drawdata$Index, las = 2, line = 1, cex = args$labeltextsize,
          family = args$fontfamily)
    axis.lims <- par("usr")
    shift <- 2 * par("cxy")[1]
    x <- rep(axis.lims[2] + shift, nrow(drawdataheatmap))
    y <- 1:nrow(drawdataheatmap)
    # colorpalette <- ifelse(F, "Greys", "RdYlBu")
    # col <- colorRampPalette(RColorBrewer::brewer.pal(10, colorpalette))(ncol(drawdataheatmap))

    bg <- matrix("", nrow(drawdataheatmap), ncol(drawdataheatmap))
    for (m in 1:nrow(drawdataheatmap)) {
      bg[m, ] <- (col[ncol(drawdataheatmap):1])[rank(drawdataheatmap[m, ])]
    }
    par(xpd = TRUE,family = args$fontfamily)
    for (n in 1:ncol(drawdataheatmap)) {
      points(x, y, bty = "n", pch = 22, bg = bg[, n], cex = 3)
      text(x[1], axis.lims[4], colnames(drawdataheatmap)[n], srt = args$labelrotation, adj = c(0.2,0.5),
          cex=args$heatmaptextsize,
          family = args$fontfamily)
      x <- x + shift
    }

    title(main = args$title, family = args$fontfamily, cex.main = args$titletextsize)
    dev.off()
    pdftools::pdf_convert(resultfiles$pdf, page = 1, dpi = 300, filenames = resultfiles$png)
    for (fmt in setdiff(names(resultfiles)[1:3], formats)) {
      if (file.exists(resultfiles[[fmt]])) unlink(resultfiles[[fmt]])
    }
  }, error = function(e) {
    if (dev.cur() > 1) {dev.off()}
    gen_errorexit(paste0("绘图过程中出现错误: ", e$message, "\n", "请适当调大图片宽度和高度\n或者启用标签折叠选项\n或者联系工作人员"),
                  outfilename,args$ofiletype)
  })
}
#################################### MAIN ######################################
args <- parser_args()
# 小工具不需要重新创建文件夹
# re_mkdir(args$outdir)
if (!dir.exists(args$outdir)) dir.create(args$outdir, recursive = TRUE)

data <- read_infile(args$infile,labelcolname="",infiletype="data",
                    datacolumns=c("VIP"),
                    outfileprefix=file.path(args$outdir,"VIP_lollipopheatmap"),
                    outfilesuffix=args$ofiletype)
sampleinfo <- read_infile(args$insamplefile,infiletype="sample",
                    datacolumns=colnames(data),
                    outfileprefix=file.path(args$outdir,"VIP_lollipopheatmap"),
                    outfilesuffix=args$ofiletype)
samplecols <- intersect(colnames(data), sampleinfo$sample)
sampledata <- data[, c("Index","VIP", samplecols), drop = FALSE]
nonnumeric <- samplecols[!vapply(sampledata[, samplecols, drop = FALSE], is.numeric, logical(1))]
if (length(nonnumeric) > 0) {
  gen_errorexit(paste0("输入文件中样本列和VIP列存在非数字值，请检查以下列: ", paste(nonnumeric, collapse = ", ") ),
                file.path(args$outdir,"VIP_lollipopheatmap"),args$ofiletype)
}

drawdata <- calc_lollipopheatmap(sampledata,sampleinfo,args)
drawsave_lollipopheatmap(drawdata,file.path(args$outdir,"VIP_lollipopheatmap"),args)