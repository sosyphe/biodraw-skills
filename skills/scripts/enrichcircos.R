#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sys.frames()[[1]]$ofile %||% 
                                    sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))])))
source(file.path(script_dir, "utils.R"))

parser_args <- function(){
  library(optparse)
  arg_defs <- list(
      list("--infile", "character", "./testdata/exampledata2.tsv", "输入文件", NULL),
      list("--infcfile", "character", "", "输入的 FC 文件", NULL),
      list("--outdir", "character", "./testdata/output", "输出目录", NULL),
      list("--ofiletype", "character", "png", "输出图像格式", NULL),
      list("--ofilewidth", "numeric", 12, "输出图像宽度", NULL),
      list("--ofileheight", "numeric", 12, "输出图像高度", NULL),
      list("--labelfontsize", "numeric", 10, "标签字体大小", NULL),
      list("--fontsize", "numeric", 12, "整体字体大小", NULL),
      list("--fontfamily", "character", "Times New Roman", "字体族", NULL),
      list("--title", "character", "", "图标题", NULL),
      list("--legendlabel", "character", "", "图例名称", NULL),
      list("--geneordertype", "character", "logFC", "基因排序方式", NULL),
      list("--genefontsize", "numeric", 4, "基因字体大小", NULL),
      list("--genewidthspace", "numeric", 0.25, "基因间距", NULL),
      list("--legendcolnum", "numeric", 3, "图例列数", NULL),
      list("--logfcmincolor", "character", "firebrick3", "logFC 最小颜色", NULL),
      list("--logfcmidcolor", "character", "white", "logFC 中间颜色", NULL),
      list("--logfcmaxcolor", "character", "royalblue3", "logFC 最大颜色", NULL),
      list("--groupcolor", "character", "", "分组颜色", NULL)
  )

  option_list <- create_optlist(arg_defs)
  args <- parse_args(OptionParser(option_list = option_list, usage = ""))
  return(args)
}
data_tomatrix <- function(df, gene_col = "GeneInfo", pathway_col = "Index") {
  library(tidyr)
  library(dplyr)
  library(stringr)

  resultdata <- df %>%
                  separate_rows(!!sym(gene_col), sep = "/", convert = TRUE) %>%
                  mutate(
                    !!gene_col := str_trim(!!sym(gene_col)),   # 去除基因名的空格
                    value = 1
                  ) %>%
                  pivot_wider(
                    names_from = !!sym(gene_col),
                    values_from = value,
                    values_fill = list(value = 0)
                  ) %>%
                  {
                    gene_cols <- sort(setdiff(names(.), pathway_col))
                    select(., !!sym(pathway_col), all_of(gene_cols))
                  } %>%
                  tibble::column_to_rownames(var = "Index")

  return(resultdata)
}
GOChord2 <- function(data, title, space, gene.order, gene.size, gene.space, nlfc = 1, lfc.col, lfc.min, lfc.max, ribbon.col, border.size, process.label, limit,
                     fontfamily,fontsize,legendlabel,legendcolnum){
  y <- id <- xpro <- ypro <- xgen <- ygen <- lx <- ly <- ID <- logFC <- NULL
  Ncol <- dim(data)[2]

  if (missing(title)) title <- ''
  if (missing(space)) space = 0
  if (missing(gene.order)) gene.order <- 'none'
  if (missing(gene.size)) gene.size <- 3
  if (missing(gene.space)) gene.space <- 0.2
  if (missing(lfc.col)) lfc.col <- c('brown1', 'azure', 'cornflowerblue')
  if (missing(lfc.min)) lfc.min <- -3
  if (missing(lfc.max)) lfc.max <- 3
  if (missing(border.size)) border.size <- 0
  if (missing (process.label)) process.label <- 11
  if (missing(limit)) limit <- c(0, 0)

  if (gene.order == 'logFC') data <- data[order(data[, Ncol], decreasing = T), ]
  if (gene.order == 'alphabetical') data <- data[order(rownames(data)), ]
  if (sum(!is.na(match(colnames(data), 'logFC'))) > 0){
    if (nlfc == 1){
      cdata <- GOplot:::check_chord(data[, 1:(Ncol - 1)], limit)
      lfc <- sapply(rownames(cdata), function(x) data[match(x,rownames(data)), Ncol])
    }else{
      cdata <- GOplot:::check_chord(data[, 1:(Ncol - nlfc)], limit)
      lfc <- sapply(rownames(cdata), function(x) data[, (Ncol - nlfc + 1)])
    }
  }else{
    cdata <- GOplot:::check_chord(data, limit)
    lfc <- 0
  }
  if (missing(ribbon.col)) colRib <- grDevices::rainbow(dim(cdata)[2]) else colRib <- ribbon.col
  nrib <- colSums(cdata)
  ngen <- rowSums(cdata)
  Ncol <- dim(cdata)[2]
  Nrow <- dim(cdata)[1]
  colRibb <- c()
  for (b in 1:length(nrib)) colRibb <- c(colRibb, rep(colRib[b], 202 * nrib[b]))
  r1 <- 1; r2 <- r1 + 0.1
  xmax <- c(); x <- 0
  for (r in 1:length(nrib)){
    perc <- nrib[r] / sum(nrib)
    xmax <- c(xmax, (pi * perc) - space)
    if (length(x) <= Ncol - 1) x <- c(x, x[r] + pi * perc)
  }
  xp <- c(); yp <- c()
  l <- 50
  for (s in 1:Ncol){
    xh <- seq(x[s], x[s] + xmax[s], length = l)
    xp <- c(xp, r1 * sin(x[s]), r1 * sin(xh), r1 * sin(x[s] + xmax[s]), r2 * sin(x[s] + xmax[s]), r2 * sin(rev(xh)), r2 * sin(x[s]))
    yp <- c(yp, r1 * cos(x[s]), r1 * cos(xh), r1 * cos(x[s] + xmax[s]), r2 * cos(x[s] + xmax[s]), r2 * cos(rev(xh)), r2 * cos(x[s]))
  }
  df_process <- data.frame(x = xp, y = yp, id = rep(c(1:Ncol), each = 4 + 2 * l))
  xp <- c(); yp <- c(); logs <- NULL
  x2 <- seq(0 - space, -pi - (-pi / Nrow) - space, length = Nrow)
  xmax2 <- rep(-pi / Nrow + space, length = Nrow)
  for (s in 1:Nrow){
    xh <- seq(x2[s], x2[s] + xmax2[s], length = l)
    if (nlfc <= 1){
      xp <- c(xp, (r1 + 0.05) * sin(x2[s]), (r1 + 0.05) * sin(xh), (r1 + 0.05) * sin(x2[s] + xmax2[s]), r2 * sin(x2[s] + xmax2[s]), r2 * sin(rev(xh)), r2 * sin(x2[s]))
      yp <- c(yp, (r1 + 0.05) * cos(x2[s]), (r1 + 0.05) * cos(xh), (r1 + 0.05) * cos(x2[s] + xmax2[s]), r2 * cos(x2[s] + xmax2[s]), r2 * cos(rev(xh)), r2 * cos(x2[s]))
    }else{
      tmp <- seq(r1, r2, length = nlfc + 1)
      for (t in 1:nlfc){
        logs <- c(logs, data[s, (dim(data)[2] + 1 - t)])
        xp <- c(xp, (tmp[t]) * sin(x2[s]), (tmp[t]) * sin(xh), (tmp[t]) * sin(x2[s] + xmax2[s]), tmp[t + 1] * sin(x2[s] + xmax2[s]), tmp[t + 1] * sin(rev(xh)), tmp[t + 1] * sin(x2[s]))
        yp <- c(yp, (tmp[t]) * cos(x2[s]), (tmp[t]) * cos(xh), (tmp[t]) * cos(x2[s] + xmax2[s]), tmp[t + 1] * cos(x2[s] + xmax2[s]), tmp[t + 1] * cos(rev(xh)), tmp[t + 1] * cos(x2[s]))
      }}}
  if(lfc[1] != 0){
    if (nlfc == 1){
      df_genes <- data.frame(x = xp, y = yp, id = rep(c(1:Nrow), each = 4 + 2 * l), logFC = rep(lfc, each = 4 + 2 * l))
    }else{
      df_genes <- data.frame(x = xp, y = yp, id = rep(c(1:(nlfc*Nrow)), each = 4 + 2 * l), logFC = rep(logs, each = 4 + 2 * l))
    }
  }else{
    df_genes <- data.frame(x = xp, y = yp, id = rep(c(1:Nrow), each = 4 + 2 * l))
  }
  aseq <- seq(0, 180, length = length(x2)); angle <- c()
  for (o in aseq) if((o + 270) <= 360) angle <- c(angle, o + 270) else angle <- c(angle, o - 90)
  df_texg <- data.frame(xgen = (r1 + gene.space) * sin(x2 + xmax2/2),ygen = (r1 + gene.space) * cos(x2 + xmax2 / 2),labels = rownames(cdata), angle = angle)
  df_texp <- data.frame(xpro = (r1 + 0.15) * sin(x + xmax / 2),ypro = (r1 + 0.15) * cos(x + xmax / 2), labels = colnames(cdata), stringsAsFactors = FALSE)
  cols <- rep(colRib, each = 4 + 2 * l)
  x.end <- c(); y.end <- c(); processID <- c()
  for (gs in 1:length(x2)){
    val <- seq(x2[gs], x2[gs] + xmax2[gs], length = ngen[gs] + 1)
    pros <- which((cdata[gs, ] != 0) == T)
    for (v in 1:(length(val) - 1)){
      x.end <- c(x.end, sin(val[v]), sin(val[v + 1]))
      y.end <- c(y.end, cos(val[v]), cos(val[v + 1]))
      processID <- c(processID, rep(pros[v], 2))
    }
  }
  df_bezier <- data.frame(x.end = x.end, y.end = y.end, processID = processID)
  df_bezier <- df_bezier[order(df_bezier$processID,-df_bezier$y.end),]
  x.start <- c(); y.start <- c()
  for (rs in 1:length(x)){
    val<-seq(x[rs], x[rs] + xmax[rs], length = nrib[rs] + 1)
    for (v in 1:(length(val) - 1)){
      x.start <- c(x.start, sin(val[v]), sin(val[v + 1]))
      y.start <- c(y.start, cos(val[v]), cos(val[v + 1]))
    }
  }
  df_bezier$x.start <- x.start
  df_bezier$y.start <- y.start
  df_path <- GOplot:::bezier(df_bezier, colRib)
  if(length(df_genes$logFC) != 0){
    tmp <- sapply(df_genes$logFC, function(x) ifelse(x > lfc.max, lfc.max, x))
    logFC <- sapply(tmp, function(x) ifelse(x < lfc.min, lfc.min, x))
    df_genes$logFC <- logFC
  }

  df_texp_right <- df_texp  # 复制原来的 df_texp
  df_texp_right$xpro <- df_texp_right$xpro * 1.2  # 让右侧的标签稍微远一点，防止重叠


  g<- ggplot() +
    geom_polygon(data = df_process, aes(x, y, group=id), fill='gray70', inherit.aes = F,color='black') +
    geom_polygon(data = df_process, aes(x, y, group=id), fill=cols, inherit.aes = F,alpha=0.6,color='black') +
    geom_point(aes(x = xpro, y = ypro, size = factor(labels, levels = labels), shape = NA), data = df_texp) +
    guides(shape = "none",
           size = guide_legend(legendlabel, ncol = legendcolnum, byrow = T,
           override.aes = list(shape = 22, fill = unique(cols), size = 8))
           ) +
    theme(text = element_text(fontfamily),
          legend.text = element_text(size = process.label)) +
    geom_text(aes(xgen, ygen, label = labels, angle = angle), data = df_texg, size = gene.size,
              family = fontfamily) +
    # geom_text(aes(xpro*.8, ypro, label = labels), data = df_texp_right, size = gene.size, hjust = 0,
    #          family = fontfamily) +
    geom_polygon(aes(x = lx, y = ly, group = ID), data = df_path, fill = colRibb, size = border.size, inherit.aes = F) +
    labs(title = title) +
    theme(text = element_text(fontfamily),
          plot.title = element_text(hjust = 0.5,size=fontsize),
          axis.line = element_blank(), axis.text.x = element_blank(),
          plot.margin = margin(10, 80, 10, 10),
          axis.text.y = element_blank(), axis.ticks = element_blank(), axis.title.x = element_blank(),
          axis.title.y = element_blank(), panel.background = element_blank(), panel.border = element_blank(),
          panel.grid.major = element_blank(), panel.grid.minor = element_blank(), plot.background = element_blank()
          )

  if (nlfc >= 1){
    g + geom_polygon(data = df_genes, aes(x, y, group = id, fill = logFC), inherit.aes = F, color = 'black') +
      scale_fill_gradient2('logFC', space = 'Lab', low = lfc.col[3], mid = lfc.col[2], high = lfc.col[1],
                           guide = guide_colorbar(title.position = "top", title.hjust = 0.5,order = 1),
                           breaks = c(min(df_genes$logFC), max(df_genes$logFC)), labels = c(round(min(df_genes$logFC)), round(max(df_genes$logFC)))) +
      theme(text = element_text(fontfamily),
            legend.position = 'bottom', legend.background = element_rect(fill = 'transparent'), legend.box = 'horizontal', legend.direction = 'horizontal')
  }else{
    g + geom_polygon(data = df_genes, aes(x, y, group = id), fill = 'gray50', inherit.aes = F, color = 'black')+
      theme(text = element_text(fontfamily),
            legend.position = 'bottom',
            legend.background = element_rect(fill = 'transparent'), legend.box = 'horizontal', legend.direction = 'horizontal')
  }
}
draw_chord <- function(drawdata,fcdata,outfileprefix,args){
  library(dplyr)
  library(tidyr)
  # library(circlize)
  # library(GOplot)
  library(ggplot2)
  library(showtext)
  library(RColorBrewer)
  set.seed(123)
  showtext_auto()
  showtext_opts(dpi = 300)
  font_add(family = "Arial", regular = "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf")
  font_add(family = "Times New Roman", regular = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf")
  font_add(family = "Courier New", regular = "/usr/share/fonts/truetype/msttcorefonts/Courier_New.ttf")
  font_add(family = "SourceHanSans", regular = "/usr/share/fonts/truetype/chinese/SourceHanSansCN-Regular.otf")
  font_add(family = "SourceHanSerif", regular = "/usr/share/fonts/truetype/chinese/SourceHanSerif-Regular.ttc")

  grouplist <- rownames(drawdata)
  if (!is.null(args$groupcolor) && args$groupcolor != "") {
    groupcolor <- unlist(stringr::str_split(args$groupcolor,","))
    if (!all(isvalid_color(groupcolor))) {
        gen_errorexit("检测到非法的颜色代码\n请确保所有颜色为合法的16进制格式(如 #FF0000)或者常规red/blue等颜色",
                      file.path(args$outdir,"flowerplot"),args$ofiletype)
    }
    if (length(groupcolor) < length(grouplist)) {
      print("输入的颜色个数少于组数")
    }
    groupcolor <- {
      n <- length(grouplist)
      if(length(groupcolor) < n) c(groupcolor, grDevices::rainbow(n - length(groupcolor))) else groupcolor
    }[1:n]
  }else{
    groupcolor <- brewer.pal(length(grouplist), "Set3")
  }
  groupcolormap <- setNames(groupcolor, grouplist)

  dealdata <- drawdata %>%
    tibble::rownames_to_column("Term") %>%
    pivot_longer(-Term, names_to = "Genes", values_to = "Value") %>%
    filter(Value == 1)

  if (is.null(fcdrawdata)){
    dealdata <- dealdata %>%
      select(Term,Genes) %>%
      data.frame()
    dealdata$Term <- gsub(":", "--", dealdata$Term)
    dfPlot <- GOplot::chord_dat(dealdata, process=unique(dealdata$Term))
    colnames(dfPlot) <- gsub("--", ":", colnames(dfPlot))
  }else{
    dealdata <- dealdata %>%
      left_join(fcdata %>% mutate(logFC = log2FC) %>% select(Index, logFC) %>% distinct(), by=c("Genes" = "Index")) %>%
      select(Term,Genes,logFC) %>%
      data.frame()
    dealdata$Term <- gsub(":", "--", dealdata$Term)
    dfPlot <- GOplot::chord_dat(dealdata, genes = fcdata, process=unique(dealdata$Term))
    colnames(dfPlot) <- gsub("--", ":", colnames(dfPlot))
  }

  tryCatch({
    formats <- unlist(strsplit(tolower(args$ofiletype), "\\+"))
    resultfiles <- list(
      pdf = file.path(paste0(outfileprefix, ".pdf")),
      png = file.path(paste0(outfileprefix, ".png")),
      svg = file.path(paste0(outfileprefix, ".svg")),
      temp = file.path(paste0(outfileprefix, ".temp.pdf"))
    )
    pdf(resultfiles$pdf, width=args$ofilewidth, height=args$ofileheight)
    print(GOChord2(dfPlot,
        title=args$title,
        space = 0.02,
        gene.order = args$geneordertype,
        gene.space = args$genewidthspace,
        gene.size = args$genefontsize,
        lfc.col=c(args$logfcmincolor,args$logfcmidcolor,args$logfcmaxcolor),
        ribbon.col=groupcolormap,
        process.label = args$labelfontsize,
        fontsize = args$fontsize,
        fontfamily = args$fontfamily,
        legendlabel = args$legendlabel,
        legendcolnum = args$legendcolnum,
    ))
    dev.off()
    pdftools::pdf_convert(resultfiles$pdf, page = 1, dpi = 300, filenames = resultfiles$png)
    for (fmt in setdiff(names(resultfiles)[1:3], formats)) {
      if (file.exists(resultfiles[[fmt]])) unlink(resultfiles[[fmt]])
    }
  }, error = function(e) {
    if (dev.cur() > 1) {dev.off()}
    gen_errorexit(paste0("绘图过程中出现错误: ",stringr::str_wrap(e$message, width = 60),
                  "\n", "请适当调大图片宽度和高度\n或者联系工作人员"),
                  file.path(args$outdir,"chord"),args$ofiletype)
  })
}

#################################### MAIN ######################################
args <- parser_args()
# 小工具不需要重新创建文件夹
# re_mkdir(args$outdir)
if (!dir.exists(args$outdir)) dir.create(args$outdir, recursive = TRUE)

data <- read_infile(args$infile,labelcolname="Pathway",infiletype="data",
                    datacolumns = c("GeneInfo"),
                    outfileprefix=file.path(args$outdir,"chord"),
                    outfilesuffix=args$ofiletype)
drawdata <- data_tomatrix(data)
if (!is.null(args$infcfile) && (args$infcfile != "")){
  fcdata <- read_infile(args$infcfile,labelcolname="",infiletype="fcdata",
                        datacolumns = c("log2FC"),
                        outfileprefix = file.path(args$outdir,"chord"),
                        outfilesuffix=args$ofiletype)
  if(length(intersect(fcdata$Index, colnames(drawdata))) == 0){
     gen_errorexit("输入log2FC信息文件中第一列和数据文件中获取到的基因没有交集\n请检查数据",
                  file.path(args$outdir,"chord"),args$ofiletype)
  }else{
    fcdrawdata <- fcdata %>% select(Index,log2FC) %>% arrange(match(Index, colnames(drawdata)))
  }
}else{
  fcdrawdata <- NULL
}

draw_chord(drawdata,fcdrawdata,file.path(args$outdir,"chord"),args)
