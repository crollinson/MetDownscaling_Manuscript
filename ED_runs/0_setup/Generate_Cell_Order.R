# ------------------------------------------------------------------
# Script to Determine in which order to run grid cells to make sure 
# we're getting the full spatial distribution as we run through so 
# that we can kreig the results if we run out of time
# 
# Christy Rollinson (crollinson@gmail.com)
# 2 November, 2015
#
# Order of Operations:
# 1) Use the PalEON Mask to determine what cells we have
# 2) Generate a set of progressively finer grids starting with 10-degree 
#    and working down to 0.5-degree; at each set of grids, prioritize cells
#    that fill in new lat/lon bands (but within each group, the cells will 
#    go in order)
#
# NOTE: If we do all cells (0.5-degree grid), there will be 1629 cells; 
#       If we stop at 1-degree grids, there will only be 583
# ------------------------------------------------------------------

# -------------------------------
# Libraries, base layers, etc
# -------------------------------
library(raster); library(ggplot2)
library(zoo)

paleon.mask <- raster("~/Dropbox/PalEON_CR/env_regional/env_paleon/domain_mask/paleon_domain.nc")
plot(paleon.mask)
# -------------------------------

# -------------------------------
# Convert the paleon mask to a list of grid cells
# -------------------------------
paleon.cells <- data.frame(rasterToPoints(paleon.mask))
paleon.cells$latlon <- as.factor(paste0("lat", paleon.cells$y, "lon", paleon.cells$x))
summary(paleon.cells)
dim(paleon.cells)

paleon.order <- data.frame(order=1:nrow(paleon.cells), x=NA, y=NA)
summary(paleon.order)

# First re-do the HIPs sites from teh site-level runs
p0 <- data.frame(x=c(-72.25, -68.75, -89.75, -94.75, -95.25, -82.75), y=c(42.75, 45.25, 46.25, 46.25, 47.25, 43.75))
p0$latlon <- as.factor(paste0("lat", p0$y, "lon", p0$x))
p0

# 10-degree grid
x1 <- seq(round(min(paleon.cells$x), 0)-7.25, round(max(paleon.cells$x), 0)+7.25, by=10) 
y1 <- seq(round(min(paleon.cells$y), 0)-7.25, round(max(paleon.cells$y), 0)+7.25, by=10) 
p1 <- merge(x1, y1)
p1$latlon <- as.factor(paste0("lat", p1$y, "lon", p1$x))
p1  <- p1[(p1$latlon %in% paleon.cells$latlon),]
p1

# 5-degree grid
x2  <- seq(round(min(paleon.cells$x)*2, 0)/2-7.25, round(max(paleon.cells$x)*2, 0)/2+7.25, by=5) 
y2  <- seq(round(min(paleon.cells$y)*2, 0)/2-7.25, round(max(paleon.cells$y)*2, 0)/2+7.25, by=5) 
p2  <- merge(x2, y2)
p2$latlon <- as.factor(paste0("lat", p2$y, "lon", p2$x))
p2  <- p2[!(p2$latlon %in% rbind(p0, p1)[,"latlon"]) & (p2$latlon %in% paleon.cells$latlon),]
p2a <- p2[!(p2$x %in% p1$x) & !(p2$y %in% p1$y),]
p2b <- p2[!(p2$latlon %in% p2a$latlon),]

# 2.5-degree grid
x3  <- seq(round(min(paleon.cells$x)*2, 0)/2-7.25, round(max(paleon.cells$x)*2, 0)/2+7.25, by=2.5) 
y3  <- seq(round(min(paleon.cells$y)*2, 0)/2-7.25, round(max(paleon.cells$y)*2, 0)/2+7.25, by=2.5) 
p3  <- merge(x3, y3)
p3$latlon <- as.factor(paste0("lat", p3$y, "lon", p3$x))
p3  <- p3[!(p3$latlon %in% rbind(p0, p1, p2)[,"latlon"]) & (p3$latlon %in% paleon.cells$latlon),]
p3a <- p3[!(p3$x %in% rbind(p1, p2)[,"x"]) & !(p3$y %in% rbind(p1, p2)[,"y"]),]
p3b <- p3[!(p3$latlon %in% p3a$latlon),]

# 1.5-degree grid
x4  <- seq(round(min(paleon.cells$x)*2, 0)/2-7.25, round(max(paleon.cells$x)*2, 0)/2+7.25, by=1.5) 
y4  <- seq(round(min(paleon.cells$y)*2, 0)/2-7.25, round(max(paleon.cells$y)*2, 0)/2+7.25, by=1.5) 
p4  <- merge(x4, y4)
p4$latlon <- as.factor(paste0("lat", p4$y, "lon", p4$x))
p4  <- p4[!(p4$latlon %in% rbind(p0, p1, p2, p3)[,"latlon"]) & (p4$latlon %in% paleon.cells$latlon),]
p4a <- p4[!(p4$x %in% rbind(p1, p2, p3)[,"x"]) & !(p4$y %in% rbind(p1, p2, p3)[,"y"]),]
p4b <- p4[!(p4$latlon %in% p4a$latlon),]

# 1.0-degree grid
x5  <- seq(round(min(paleon.cells$x)*2, 0)/2-7.25, round(max(paleon.cells$x)*2, 0)/2+7.25, by=1) 
y5  <- seq(round(min(paleon.cells$y)*2, 0)/2-7.25, round(max(paleon.cells$y)*2, 0)/2+7.25, by=1) 
p5  <- merge(x5, y5)
p5$latlon <- as.factor(paste0("lat", p5$y, "lon", p5$x))
p5  <- p5[!(p5$latlon %in% rbind(p0, p1, p2, p3, p4)[,"latlon"]) & (p5$latlon %in% paleon.cells$latlon),]
p5a <- p5[!(p5$x %in% rbind(p1, p2, p3, p4)[,"x"]) & !(p5$y %in% rbind(p1, p2, p3, p4)[,"y"]),]
p5b <- p5[!(p5$latlon %in% p5a$latlon),]

# 0.5-degree grid
x6  <- seq(round(min(paleon.cells$x)*2, 0)/2-7.25, round(max(paleon.cells$x)*2, 0)/2+7.25, by=0.5) 
y6  <- seq(round(min(paleon.cells$y)*2, 0)/2-7.25, round(max(paleon.cells$y)*2, 0)/2+7.25, by=0.5) 
p6  <- merge(x6, y6)
p6$latlon <- as.factor(paste0("lat", p6$y, "lon", p6$x))
p6  <- p6[!(p6$latlon %in% rbind(p0, p1, p2, p3, p4, p5)[,"latlon"]) & (p6$latlon %in% paleon.cells$latlon),]
p6a <- p6[!(p6$x %in% rbind(p1, p2, p3, p4, p5)[,"x"]) & !(p6$y %in% rbind(p1, p2, p3, p4, p5)[,"y"]),]
p6b <- p6[!(p6$latlon %in% p6a$latlon),]


ggplot() +
	geom_raster(data=paleon.cells, aes(x=x, y=y), fill="gray50"    ) +
	geom_point(data=p0 , aes(x=x, y=y), size=5, color="purple"     ) +
	geom_point(data=p1 , aes(x=x, y=y), size=4, color="black"      ) +
	geom_point(data=p2a, aes(x=x, y=y), size=3, color="cyan3"      ) +
	geom_point(data=p2b, aes(x=x, y=y), size=3, color="blue"       ) +
	# geom_point(data=p3a, aes(x=x, y=y), size=2, color="red"        ) +
	# geom_point(data=p3b, aes(x=x, y=y), size=2, color="coral2"     ) +
	# geom_point(data=p4a, aes(x=x, y=y), size=1.5, color="darkgreen") +
	# geom_point(data=p4b, aes(x=x, y=y), size=1.5, color="green3"   ) +
	# geom_point(data=p5 , aes(x=x, y=y), size=1, color="gray30"     ) +
	# geom_point(data=p6a , aes(x=x, y=y), size=1, color="gray80"    ) +
	coord_equal(ratio=1) +
	theme_bw()

nrow(p0); nrow(p1); nrow(p2);nrow(p3);nrow(p4);nrow(p5);nrow(p6);
nrow(rbind(p0, p1, p2a, p2b, p3a, p3b, p4a, p4b, p5a, p5b))

paleon.order <- rbind(p0, p1, p2a, p2b, p3a, p3b, p4a, p4b, p5a, p5b, p6a, p6b)
names(paleon.order) <- c("lon", "lat", "latlon")
summary(paleon.order)
head(paleon.order)

paleon.states <- map_data("state")

ggplot(paleon.order[1:43,]) +
	geom_raster(data=paleon.cells, aes(x=x, y=y), fill="gray50") +
	geom_path(data=paleon.states, aes(x=long, y=lat, group=group), size=0.25) +
	geom_point(aes(x=lon, y=lat), size=1, color="blue") +
    scale_x_continuous(limits=range(paleon.order$lon), expand=c(0,0), name="Longitude (degrees)") +
    scale_y_continuous(limits=range(paleon.order$lat), expand=c(0,0), name="Latitude (degrees)") +
	coord_equal(ratio=1) +
	theme_bw()


write.csv(paleon.order, "Paleon_MIP_Phase2_ED_Order.csv", row.names=F, eol="\r\n")
write.csv(paleon.order[1:10,], "TEST.csv", row.names=F, eol="\r\n")

# -------------------------------
