# ----------------------------------------------
# Script to do some QA/QC on the regional (Phase 2) PalEON met Driver Data
# Christine Rollinson, crollinson@gmail.com
# Original: 14 September, 2015
#
# --------------
# QA/QC Checks
# --------------
# Region-Level:
# Note: This set will probably use parallel processing to: 
#       1) speed things up; 
#       2) provide an example of raster parallelzation in R for others to use
# A) Animated Maps (upload to web)
#    1) Monthly Means -- Entire PalEON Temporal & Spatial Domain
#    2) Diurnal Cycle -- 1 year (mean of tempororal domain?)
# B) Static Maps (for QA/QC document)
#    1) Annual Means  -- spinup (1850-1869); modern climate (1980-2010)
#    3) Monthly Means -- mean of entire temporal domain
# 
# Random Site Checks (10? random points)
# 1) 6-hrly, full time range
# 2) Monthly means, full time range
# 3) Annual means, full time range
# --------------
#
# ----------------------------------------------


# ----------------------------------------------
# Load libaries, Set up Directories, etc
# ----------------------------------------------
library(raster); library(animation)
library(ncdf4); library(ggplot2); library(grid)
dir.met  <- "/home/crollinson/ED_PalEON/phase2_met/"
dir.out  <- "/home/crollinson/ED_PalEON/MIP2_Region/phase2_met_qaqc/"
if(!dir.exists(dir.out)) dir.create(dir.out)

# Variables we're graphing
# vars <- dir(dir.met)
vars <- c("co2", "dlwrf", "prate", "pres", "sh", "tmp", "ugrd", "vbdsf")

# window for graphing monthly means
# Note: 2 windows to get each of the splice points
# yr.start.mo1  <- 1849
yr.start.mo1  <- 1850
yr.end.mo1    <- 1869

paleon.states <- map_data("state")


# ----------------------------------------------


# ----------------------------------------------
# Read in & graph by variable
# ----------------------------------------------
# v="tair"

files.tair     <- dir(file.path(dir.met, "tmp"))
files.precipf  <- dir(file.path(dir.met, "prate"))
files.swdown   <- dir(file.path(dir.met, "vbdsf"))
files.lwdown   <- dir(file.path(dir.met, "dlwrf"))
files.qair     <- dir(file.path(dir.met, "sh"))
files.psurf    <- dir(file.path(dir.met, "pres"))
files.wind     <- dir(file.path(dir.met, "ugrd"))
files.co2      <- dir(file.path(dir.met, "co2"))
# for(v in vars){
	# # Definining our file paths
	# dir.var <- file.path(dir.met, v)	
	# var.files <- dir(dir.var)
	# nchar.v <- nchar(v)

	
# ---------------------
# Saving Monthly: Transition 1
# ---------------------
# Getting just the years for the time frame we're interested in
files.graph <-	which(as.numeric(substr(files.tair, 5,8))>=yr.start.mo1 & as.numeric(substr(files.tair, 5,8))<=yr.end.mo1)

files.year <- as.numeric(substr(files.tair[files.graph], 5,8))
files.mo <- substr(files.tair[files.graph], 9,11)
files.mo <- recode(files.mo, "'JAN'='01'; 'FEB'='02'; 'MAR'='03'; 'APR'='04'; 'MAY'='05'; 'JUN'='06'; 'JUL'='07'; 'AUG'='08'; 'SEP'='09'; 'OCT'='10'; 'NOV'='11'; 'DEC'='12'")

for(i in unique(files.year)){
	files.graph[files.graph[files.year==i]] <- files.graph[files.year==i][order(files.mo[files.year==i])]
}


saveGIF( {  
  # Looping through each file to generate the image for each step of the animation
  for(i in files.graph){
	print(paste0("---- ", files.tair[i], " ----"))
	# Doing all the variables here because we're going to plot them all together on the giff
	tair.full    <- stack(file.path(dir.met, "tmp",    files.tair[i]))
	precipf.full <- stack(file.path(dir.met, "prate", files.precipf[i]))
	swdown.full  <- stack(file.path(dir.met, "vbdsf",  files.swdown[i]))
	lwdown.full  <- stack(file.path(dir.met, "dlwrf",  files.lwdown[i]))
	qair.full    <- stack(file.path(dir.met, "sh",    files.qair[i]))
	psurf.full   <- stack(file.path(dir.met, "pres",   files.psurf[i]))
	wind.full    <- stack(file.path(dir.met, "ugrd",    files.wind[i]))

    tmp  <- strsplit(files.tair[i],"_")
    year <- tmp[[1]][2]
    mon  <- substring(tmp[[1]][3],1,2)

	# Finding the monthly mean for each time step 
	# (for some reason this doesn't work well combined with the next step)
	tair.x1    <- mean(tair.full)
	precipf.x1 <- mean(precipf.full)
	swdown.x1  <- mean(swdown.full)
	lwdown.x1  <- mean(lwdown.full)
	qair.x1    <- mean(qair.full)
	psurf.x1   <- mean(psurf.full)
	wind.x1    <- mean(wind.full)

	tair.x    <- data.frame(rasterToPoints(tair.x1))
	precipf.x <- data.frame(rasterToPoints(precipf.x1))
	swdown.x  <- data.frame(rasterToPoints(swdown.x1))
	lwdown.x  <- data.frame(rasterToPoints(lwdown.x1))
	qair.x    <- data.frame(rasterToPoints(qair.x1))
	psurf.x   <- data.frame(rasterToPoints(psurf.x1))
	wind.x    <- data.frame(rasterToPoints(wind.x1))
	names(tair.x)    <- c("lon", "lat", "tair")
	names(precipf.x) <- c("lon", "lat", "precipf")
	names(swdown.x)  <- c("lon", "lat", "swdown")
	names(lwdown.x)  <- c("lon", "lat", "lwdown")
	names(qair.x)    <- c("lon", "lat", "qair")
	names(psurf.x)   <- c("lon", "lat", "psurf")
	names(wind.x)    <- c("lon", "lat", "wind")

	plot.tair <- ggplot(data=tair.x) +
		geom_raster(aes(x=lon, y=lat, fill=tair)) +
		scale_fill_gradientn(colours=c("gray50", "red3"), limits=c(240,330)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Tair", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position="bottom", 
              # legend.direction="horizontal") +
        theme(panel.background=element_blank(), 
              axis.title.y=element_blank(),
              axis.title.x=element_blank()) +
		coord_equal(ratio=1)

	plot.precipf <- ggplot(data=precipf.x) +
		geom_raster(aes(x=lon, y=lat, fill=precipf)) +
		scale_fill_gradientn(colours=c("gray50", "blue3"), limits=c(0,2.5e-4)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Precipf", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position=c(0.75, 0.1), legend.direction="horizontal") +
        theme(panel.background=element_blank()) +
		coord_equal(ratio=1)

	plot.swdown <- ggplot(data=swdown.x) +
		geom_raster(aes(x=lon, y=lat, fill=swdown)) +
		scale_fill_gradientn(colours=c("gray50", "goldenrod2"), limits=c(0,600)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Tair", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position=c(0.75, 0.1), legend.direction="horizontal") +
        theme(panel.background=element_blank()) +
		coord_equal(ratio=1)

	plot.lwdown <- ggplot(data=lwdown.x) +
		geom_raster(aes(x=lon, y=lat, fill=lwdown)) +
		# scale_fill_gradientn(colours=c("gray50", "darkorange1"), limits=c(0,330)) +
		scale_fill_gradientn(colours=c("gray50", "darkorange1"), limits=c(100,800)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Tair", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position=c(0.75, 0.1), legend.direction="horizontal") +
        theme(panel.background=element_blank()) +
		coord_equal(ratio=1)

	plot.qair <- ggplot(data=qair.x) +
		geom_raster(aes(x=lon, y=lat, fill=qair)) +
		scale_fill_gradientn(colours=c("gray50", "aquamarine3"), limits=c(0, 0.025)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Tair", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position=c(0.75, 0.1), legend.direction="horizontal") +
        theme(panel.background=element_blank()) +
		coord_equal(ratio=1)

	plot.psurf <- ggplot(data=psurf.x) +
		geom_raster(aes(x=lon, y=lat, fill=psurf)) +
		scale_fill_gradientn(colours=c("gray50", "mediumpurple2"), limits=c(91000,110000)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Tair", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position=c(0.75, 0.1), legend.direction="horizontal") +
        theme(panel.background=element_blank()) +
		coord_equal(ratio=1)
		
	plot.wind <- ggplot(data=wind.x) +
		geom_raster(aes(x=lon, y=lat, fill=wind)) +
		scale_fill_gradientn(colours=c("gray80", "gray30"), limits=c(0,15)) +
		geom_path(data=paleon.states, aes(x=long, y=lat, group=group)) +
		scale_x_continuous(limits=range(tair.x$lon), expand=c(0,0), name="Longitude") +
		scale_y_continuous(limits=range(tair.x$lat), expand=c(0,0), name="Latitude") +
		# ggtitle(paste("Tair", year, mon, sep=" - ")) +
        theme(plot.margin=unit(c(0,0,0,0), "lines")) +
        # theme(legend.position=c(0.75, 0.1), legend.direction="horizontal") +
        theme(panel.background=element_blank()) +
		coord_equal(ratio=1)
		
	plot.time <- ggplot(data=tair.x) +
		geom_text(aes(x=1, y=1, label=paste(year, mon, sep=" - ")), size=24) +
        theme(panel.background=element_blank()) 


	# Setting up a grid layout to graph all variables at once
	grid.newpage()
	pushViewport(viewport(layout=grid.layout(4,2)))
	print(plot.tair,    vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
	print(plot.precipf, vp = viewport(layout.pos.row = 1, layout.pos.col = 2))
	print(plot.swdown,  vp = viewport(layout.pos.row = 2, layout.pos.col = 1))
	print(plot.lwdown,  vp = viewport(layout.pos.row = 2, layout.pos.col = 2))
	print(plot.qair,    vp = viewport(layout.pos.row = 3, layout.pos.col = 1))
	print(plot.psurf,   vp = viewport(layout.pos.row = 3, layout.pos.col = 2))
	print(plot.wind,    vp = viewport(layout.pos.row = 4, layout.pos.col = 1))
	print(plot.time,    vp = viewport(layout.pos.row = 4, layout.pos.col = 2))
	}}, movie.name=file.path(dir.out, paste0("MetDrivers_MonthMeans", "_", yr.start.mo1, "-", yr.end.mo1, ".gif")), interval=0.3, nmax=10000, autobrowse=F, autoplay=F, ani.height=800, ani.width=800)
# ---------------------

