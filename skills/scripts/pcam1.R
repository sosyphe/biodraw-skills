#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sys.frames()[[1]]$ofile %||% 
                                    sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))])))
source(file.path(script_dir, "utils.R"))

parser_args <- function(){
  library(optparse)
  arg_defs <- list(
    list("--infile", "character", "./testdata/exampledata.tsv", "输入文件", NULL),
    list("--insamplefile", "character", "./testdata/examplesample.tsv", "输入样本文件", NULL),
    list("--outdir", "character", "./testdata/output", "输出目录", NULL),
    list("--ofiletype", "character", "pdf", "输出文件类型", NULL),
    list("--ofilewidth", "numeric", 8, "输出图宽", NULL),
    list("--ofileheight", "numeric", 8, "输出图高", NULL),
    list("--scaledata", "character", "yes", "是否对数据进行放缩", NULL),
    list("--pointsize", "numeric", 2, "点大小", NULL),
    list("--addEllipses", "character", "yes", "是否添加椭圆", NULL),
    list("--xlab", "character", "", "X轴标签", NULL),
    list("--xlabsize", "numeric", 12, "X轴标签大小", NULL),
    list("--axisxsize", "numeric", 12, "X轴刻度大小", NULL),
    list("--axisxangle", "numeric", 0, "X轴刻度旋转角度", NULL),
    list("--ylab", "character", "", "Y轴标签", NULL),
    list("--ylabsize", "numeric", 12, "Y轴标签大小", NULL),
    list("--axisysize", "numeric", 12, "Y轴刻度大小", NULL),
    list("--axisyangle", "numeric", 0, "Y轴刻度旋转角度", NULL),
    list("--zlab", "character", "", "Z轴标签", NULL),
    list("--title", "character", "", "标题", NULL),
    list("--titlepos", "character", "center", "标题位置", NULL),
    list("--titlesize", "numeric", 14, "标题字体大小", NULL),
    list("--legendlab", "character", "", "图例标签", NULL),
    list("--legendtitlesize", "numeric", 10, "图例标题大小", NULL),
    list("--legendtextsize", "numeric", 10, "图例文本大小", NULL),
    list("--labelsize", "numeric", 3, "数据标签大小", NULL),
    list("--fontfamily", "character", "Times New Roman", "字体选择", NULL),
    list("--theme", "character", "bw", "绘图主题", NULL),
    list("--addEllipsestype", "character", "v1", "椭圆类型", NULL),
    list("--geomind", "character", "point,text", "几何元素", NULL),
    list("--groupcolor", "character", "", "分组颜色", NULL),
    list("--drawstyle", "character", "2d", "绘制类型", NULL),
    list("--dotshapenormal", "numeric", 19, "普通点形状", NULL)
  )

  option_list <- create_optlist(arg_defs)
  args = parse_args(OptionParser(option_list = option_list,usage = ""))
  return(args)
}
get_geomind <- function(str){
  strlen <- length(unlist(stringr::str_split(string = str,pattern = ",")))
  if (strlen != 1) {
    inputstr <- c(unlist(stringr::str_split(string = str,pattern = ",")))
  }else {
    inputstr <- str
  }
  return(inputstr)
}
get_ellipse <- function(df, level = 0.95, segments = 100) {
  n <- nrow(df)
  mu <- colMeans(df[, c("Comp1", "Comp2")])
  if (n < 2) return(NULL)  # 太少无法画椭圆
  # 计算协方差矩阵，若退化则补救
  sigma <- tryCatch({
    cov(df[, c("Comp1", "Comp2")])
  }, error = function(e) {
    diag(2) * 1e-6  # 返回小单位矩阵以避免崩溃
  })
  if (any(is.na(sigma)) || det(sigma) == 0) {
    sigma <- sigma + diag(2) * 1e-6  # 加一点扰动防止退化
  }
  # 计算椭圆
  radius <- sqrt(qchisq(level, df = 2))
  angles <- seq(0, 2 * pi, length.out = segments)
  circle <- cbind(cos(angles), sin(angles))
  ellipse <- t(t(circle %*% chol(sigma)) * radius + mu)
  ellipse_df <- as.data.frame(ellipse)
  colnames(ellipse_df) <- c("x", "y")
  return(ellipse_df)
}
addgrids3d <- function(x, y=NULL, z=NULL, grid = TRUE,
                    col.grid = "grey", lty.grid = par("lty"),
                    lab = par("lab"), lab.z = mean(lab[1:2]),
                    scale.y = 1, angle = 40,
                    xlim=NULL, ylim=NULL, zlim=NULL){
  if(inherits(x, c("matrix", "data.frame"))){
    x <- as.data.frame(x)
    y <- unlist(x[,2])
    z <- unlist(x[,3])
    x <- unlist(x[,1])
  }
  p.lab <- par("lab")
  angle <- (angle%%360)/90
  yz.f <- scale.y * abs(if (angle < 1) angle else if (angle >3) angle - 4 else 2 - angle)
  yx.f <- scale.y * (if (angle < 2) 1 - angle else angle - 3)
  # x axis range
  x.range <- range(x[is.finite(x)], xlim)
  x.prty <- pretty(x.range, n = lab[1], min.n = max(1, min(0.5 *lab[1], p.lab[1])))
  x.scal <- round(diff(x.prty[1:2]), digits = 12)
  x <- x/x.scal
  x.range <- range(x.prty)/x.scal
  x.max <- ceiling(x.range[2])
  x.min <- floor(x.range[1])
  if (!is.null(xlim)) {
    x.max <- max(x.max, ceiling(xlim[2]/x.scal))
    x.min <- min(x.min, floor(xlim[1]/x.scal))
  }
  x.range <- range(x.min, x.max)
  # y axis range
  y.range <- range(y[is.finite(y)], ylim)
  y.prty <- pretty(y.range, n = lab[2], min.n = max(1, min(0.5 *lab[2], p.lab[2])))
  y.scal <- round(diff(y.prty[1:2]), digits = 12)
  y.add <- min(y.prty)
  y <- (y - y.add)/y.scal
  y.max <- (max(y.prty) - y.add)/y.scal
  if (!is.null(ylim))
    y.max <- max(y.max, ceiling((ylim[2] - y.add)/y.scal))
  # Z axis range
  z.range <- range(z[is.finite(z)], zlim)
  z.prty <- pretty(z.range, n = lab.z, min.n = max(1, min(0.5 *lab.z, p.lab[2])))
  z.scal <- round(diff(z.prty[1:2]), digits = 12)
  z <- z/z.scal
  z.range <- range(z.prty)/z.scal
  z.max <- ceiling(z.range[2])
  z.min <- floor(z.range[1])
  if (!is.null(zlim)) {
    z.max <- max(z.max, ceiling(zlim[2]/z.scal))
    z.min <- min(z.min, floor(zlim[1]/z.scal))
  }
  z.range <- range(z.min, z.max)
  # Add grid
  if ("xy" %in% grid || grid == TRUE) {
    i <- x.min:x.max
    segments(i, z.min, i + (yx.f * y.max), yz.f * y.max + 
               z.min, col = col.grid, lty = lty.grid)
    i <- 0:y.max
    segments(x.min + (i * yx.f), i * yz.f + z.min, x.max + 
               (i * yx.f), i * yz.f + z.min, col = col.grid, lty = lty.grid)
  }
  if ("xz" %in% grid) {
    i <- x.min:x.max
    segments(i + (yx.f * y.max), yz.f * y.max + z.min, 
             i + (yx.f * y.max), yz.f * y.max + z.max, 
             col = col.grid, lty = lty.grid)
    temp <- yx.f * y.max
    temp1 <- yz.f * y.max
    i <- z.min:z.max
    segments(x.min + temp,temp1 + i, 
             x.max + temp,temp1 + i , col = col.grid, lty = lty.grid)
    
  }
  if ("yz" %in% grid) {
    i <- 0:y.max
    segments(x.min + (i * yx.f), i * yz.f + z.min,  
             x.min + (i * yx.f) ,i * yz.f + z.max,  
             col = col.grid, lty = lty.grid)
    temp <- yx.f * y.max
    temp1 <- yz.f * y.max
    i <- z.min:z.max
    segments(x.min + temp,temp1 + i, 
             x.min, i , col = col.grid, lty = lty.grid)
    }
}
calc_pcaresult <- function(indata, scaledata="yes", outfileprefix){
  library(FactoMineR)
  set.seed(123)

  tryCatch({
    if ("Index" %in% colnames(indata)){
      rownames(indata) <- indata$Index
      data <- as.matrix(indata[, setdiff(colnames(indata), "Index"), drop = FALSE])
    }else{
      data <- as.matrix(indata)
    }
    data[is.na(data)] <- 0

    pcaresult <- FactoMineR::PCA(t(data),
                                  graph = F,
                                  ncp = ncol(data)-1,
                                  scale.unit = if (scaledata == "yes") TRUE else FALSE,
                                  )

    pcaresultSitedf <- as.data.frame(pcaresult$ind$coord)
    colnames(pcaresultSitedf) <- paste0("Comp",seq(1,ncol(pcaresultSitedf),1))
    pcaresultSitedf$Sample <- rownames(pcaresultSitedf)
    pcaresultSitedf <- cbind(pcaresultSitedf["Sample"], pcaresultSitedf[-which(names(pcaresultSitedf) == "Sample")])
    pcaresultStddf <- as.data.frame(pcaresult$eig)[2]
    pcaresultStddf$Comp <- paste0("Comp",seq(1,nrow(pcaresultStddf),1))
    pcaresultStddf <- cbind(pcaresultStddf["Comp"], pcaresultStddf[-which(names(pcaresultStddf) == "Comp")])
    resultdata <- list("result"=pcaresult,"pca"=pcaresultSitedf,"variance"=pcaresultStddf)
    return(resultdata)
  }, error = function(e) {
    gen_errorexit(paste0("PCA计算错误,请联系工作人员\n具体报错信息如下\n",
                          stringr::str_wrap(e$message, width = 60)),outfileprefix,args$ofiletype)
  })
}
draw_pcaresult <- function(pcaresult,sampledata,outfileprefix,args){
  library(ggforce)
  library(showtext)
  library(factoextra)
  library(scatterplot3d)
  showtext_auto()
  showtext_opts(dpi = 300)
  font_add("Arial", regular = "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf",
                    bold = "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf",
                    italic = "/usr/share/fonts/truetype/msttcorefonts/Arial_Italic.ttf")
  font_add("Times New Roman", regular = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf",
                              bold = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold.ttf",
                              italic = "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Italic.ttf")
  font_add("Courier New", regular = "/usr/share/fonts/truetype/msttcorefonts/Courier_New.ttf",
                          bold = "/usr/share/fonts/truetype/msttcorefonts/Courier_New_Bold.ttf",
                          italic = "/usr/share/fonts/truetype/msttcorefonts/Courier_New_Italic.ttf")
  font_add("SourceHanSans", regular = "/usr/share/fonts/truetype/chinese/SourceHanSansCN-Regular.otf",
                            bold = "/usr/share/fonts/truetype/chinese/SourceHanSansCN-Bold.otf")
  font_add("SourceHanSerif", regular = "/usr/share/fonts/truetype/chinese/SourceHanSerif-Regular.ttc",
                             bold = "/usr/share/fonts/truetype/chinese/SourceHanSerif-Bold.ttc")

  tryCatch({
    grouplist <- unique(sampledata$group)
    if (!is.null(args$groupcolor) && args$groupcolor != "") {
        groupcolor <- unlist(stringr::str_split(args$groupcolor,","))
        if (!all(isvalid_color(groupcolor))) {
          gen_errorexit("检测到非法的颜色代码\n请确保所有颜色为合法的16进制格式(如 #FF0000)或者常规red/blue等颜色",
                        outfileprefix,args$ofiletype)
        }
        groupcolor <- rep(groupcolor, length.out = length(unique(sampledata$group)))
        groupcolormap <- setNames(groupcolor, grouplist)
    }else if ("color" %in% colnames(sampledata)){
        groupcolor <- trimws(sampledata$color)
        if (!all(isvalid_color(groupcolor))) {
          gen_errorexit("检测到非法的颜色代码\n请确保所有颜色为合法的16进制格式(如 #FF0000)或者常规red/blue等颜色",
                        outfileprefix,args$ofiletype)
        }
        groupcolormap <- setNames(groupcolor, sampledata$group)
    }else{
        groupcolor <- grDevices::rainbow(length(grouplist))
        groupcolormap <- setNames(groupcolor, grouplist)
    }
    subsampledata <- sampledata[match(pcaresult$pca$Sample,sampledata$sample),]
  }, error = function(e) {
    gen_errorexit(paste0("颜色设置错误,请检测颜色相关配置\n具体报错信息如下\n",
                          stringr::str_wrap(e$message, width = 60)),
                          outfileprefix,args$ofiletype)
  })

  tryCatch({
    if (args$drawstyle == "2d"){
      drawfig <- factoextra::fviz_pca_ind(pcaresult$result,
                    geom.ind = get_geomind(args$geomind),
                    fill.ind = subsampledata$group,
                    pointsize = args$pointsize,
                    mean.point = FALSE,
                    repel = TRUE,
                    palette = groupcolormap,
                    pointshape = 21,
                    addEllipses = FALSE,
                    legend.title = args$legendlab,
                    title = args$title) +
                  get_ggtheme(args$theme) +
                  labs(x=paste0(args$xlab,"(",round(pcaresult$variance$`percentage of variance`[1],2),"%)"),
                      y=paste0(args$ylab,"(",round(pcaresult$variance$`percentage of variance`[2],2),"%)")) +
                  theme(text = element_text(family = args$fontfamily),
                        plot.title = element_text(hjust = switch(args$titlepos, left = 0, center = 0.5, right = 1, 0.5),
                                                  size = args$titlesize),
                        axis.title.x = element_text(size = args$xlabsize),
                        axis.title.y = element_text(size = args$ylabsize),
                        axis.text.x = element_text(size = args$axisxsize,
                                                  angle = args$axisxangle,
                                                  color = "black"),
                        axis.text.y = element_text(size = args$axisysize,
                                                  angle = args$axisyangle,
                                                  color = "black"),
                        legend.title = element_text(size = args$legendtitlesize),
                        legend.text = element_text(size = args$legendtextsize)
                        )

      text_layer_idx <- which(sapply(drawfig$layers, function(x) inherits(x$geom, "GeomTextRepel")))
      if (length(text_layer_idx) > 0) {
        drawfig$layers[[text_layer_idx[1]]][["aes_params"]]$family <- args$fontfamily
        drawfig$layers[[text_layer_idx[1]]][["aes_params"]]$size <- args$labelsize
      }

      if (args$addEllipses == "yes"){
        pcaresult$pca <- left_join(pcaresult$pca, subsampledata[, c("sample", "group")], by = c("Sample" = "sample"))
        if (args$addEllipsestype == "v1"){
          ellipses_df <- pcaresult$pca %>% group_by(group) %>%
                                            group_modify(~ {
                                              ell <- get_ellipse(.x, level = 0.95)
                                              if (!is.null(ell)) {
                                                ell
                                              } else {
                                                NULL
                                              }
                                            }) %>% ungroup()
          drawfig <- drawfig + geom_polygon(data = ellipses_df,
                                aes(x = x, y = y, fill = group, color = group),
                                alpha = 0.2)
        }else if(args$addEllipsestype == "v0"){
          # tryCatch的话会出现组内样本>3的组有椭圆而<=3的组没有
          # 还是事先根据所有组内最小样本数判断一下画图类型.
          # 兼容老版本
          minsamplenum <- subsampledata %>%
                          group_by(group) %>%
                          summarise(count = n_distinct(sample)) %>%
                          summarise(min_count = min(count))
          if (minsamplenum$min_count > 3){
              drawfig <- drawfig +
                        stat_ellipse(aes(fill = subsampledata$group,
                                          color = subsampledata$group),
                                      geom = "polygon",
                                      alpha = 0.2,
                                      level = 0.95)
          }else{
            print("最少样本组内样本个数小于4个,绘制椭圆而非置信区间")
            drawfig <- drawfig +
                ggforce::geom_mark_ellipse(aes(fill = subsampledata$group,
                                              color = subsampledata$group),
                                          alpha=0.2)
          }
        }
        bounds <- pcaresult$pca %>%
          group_by(group) %>%
          summarise(
            x_min = mean(.data[["Comp1"]]) - sqrt(var(.data[["Comp1"]])) * qnorm(0.9999),
            x_max = mean(.data[["Comp1"]]) + sqrt(var(.data[["Comp1"]])) * qnorm(0.9999),
            y_min = mean(.data[["Comp2"]]) - sqrt(var(.data[["Comp2"]])) * qnorm(0.9999),
            y_max = mean(.data[["Comp2"]]) + sqrt(var(.data[["Comp2"]])) * qnorm(0.9999)
          )
        drawfig <- drawfig + coord_cartesian(xlim = range(c(bounds$x_min, bounds$x_max)),
                                            ylim = range(c(bounds$y_min, bounds$y_max)))
      }
      # return(drawfig)
      save_resultfig(drawfig,ofileprefix,args$ofiletype,args$ofilewidth,args$ofileheight)
    }else{
      formats <- unlist(strsplit(tolower(args$ofiletype), "\\+"))
      resultfiles <- list(
        pdf = file.path(paste0(ofileprefix, ".pdf")),
        png = file.path(paste0(ofileprefix, ".png")),
        svg = file.path(paste0(ofileprefix, ".svg"))
      )
      pdf(resultfiles$pdf,width=args$ofilewidth, height=args$ofileheight)
        par(family = args$fontfamily)
        drawfig <- scatterplot3d(pcaresult$pca$Comp1,
                                 pcaresult$pca$Comp2,
                                 pcaresult$pca$Comp3,
                                 color = groupcolormap[subsampledata$group[match(pcaresult$pca$Sample, subsampledata$sample)]],
                                 pch = args$dotshapenormal,
                                 grid=TRUE,
                                 box=TRUE,
                                 main = args$title,
                                 xlab = args$xlab,
                                 ylab = args$ylab,
                                 zlab = args$zlab,
                                 )
        addgrids3d(pcaresult$pca$Comp1,
                   pcaresult$pca$Comp2,
                   pcaresult$pca$Comp3,
                   grid = c("xy", "xz", "yz"))
        text(
          drawfig$xyz.convert(
            pcaresult$pca$Comp1,
            pcaresult$pca$Comp2,
            pcaresult$pca$Comp3
          ),
          labels = rownames(pcaresult$pca),
          cex = 0.7,
          col = groupcolormap[subsampledata$group[match(pcaresult$pca$Sample, subsampledata$sample)]],
        )
        legend_coords <- par("usr")
        legend(
          x = legend_coords[2] - (legend_coords[2] - legend_coords[1]) * 0.05,
          y = legend_coords[4]/2,
          xpd = TRUE,
          legend = names(groupcolormap[!duplicated(names(groupcolormap))]),
          col = groupcolormap[!duplicated(names(groupcolormap))],
          pch = args$dotshapenormal,
          cex = 0.7,
        )
      dev.off()
      pdftools::pdf_convert(resultfiles$pdf, page = 1, dpi = 300, filenames = resultfiles$png)
      for (fmt in setdiff(names(resultfiles)[1:3], formats)) {
        if (file.exists(resultfiles[[fmt]])) unlink(resultfiles[[fmt]])
      }
    }
  }, error = function(e) {
    gen_errorexit(paste0("PCA绘图错误,请联系工作人员\n具体报错信息如下\n",
                          stringr::str_wrap(e$message, width = 60)),outfileprefix,args$ofiletype)
  })
}
#################################### MAIN ######################################
args <- parser_args()
# 小工具不需要重新创建文件夹
# re_mkdir(args$outdir)
if (!dir.exists(args$outdir)) dir.create(args$outdir, recursive = TRUE)

ofileprefix <- file.path(args$outdir,"PCA")

data <- read_infile(args$infile,labelcolname="",infiletype="data",
                    outfileprefix=ofileprefix,outfilesuffix=args$ofiletype)
sampleinfo <- read_infile(args$insamplefile,infiletype="sample",datacolumns=colnames(data),
                    outfileprefix=ofileprefix,outfilesuffix=args$ofiletype)
samplecols <- intersect(colnames(data), sampleinfo$sample)
sampledata <- data[, c("Index", samplecols), drop = FALSE]
nonnumeric <- samplecols[!vapply(sampledata[, samplecols, drop = FALSE], is.numeric, logical(1))]
if (length(nonnumeric) > 0) {
  gen_errorexit(paste0("输入文件中样本列存在非数字值，请检查以下列: ", paste(nonnumeric, collapse = ", ") ),
                ofileprefix,args$ofiletype)
}

pcaresult <- calc_pcaresult(sampledata,args$scaledata,ofileprefix)
write_resultdata(pcaresult,file.path(args$outdir,"PCA.xlsx"))
draw_pcaresult(pcaresult,sampleinfo,ofileprefix,args)