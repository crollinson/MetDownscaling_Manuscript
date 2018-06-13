# Checking the ED quasi-regional output
library(ncdf4)
library(ggplot2)

ed.file <- nc_open("~/Desktop/Research/paleon/MIP2_Region/model_output/ED2.v1.2017-05-09/ED2_0850.nc")
summary(ed.file$var)

ed.lon <- ncvar_get(ed.file, "lon")
ed.lat <- ncvar_get(ed.file, "lat")


# ------------
# Fcomp
# ------------
ed.fcomp <- ncvar_get(ed.file, "Fcomp")
ed.fcomp <- apply(ed.fcomp, 1:3, FUN=mean)
dim(ed.fcomp)

for(i in 1:dim(ed.fcomp)[3]){
	f.pft <- data.frame(ed.fcomp[,,i])
	names(f.pft) <- ed.lat

	stack.pft <- stack(f.pft)
	names(stack.pft) <- c("Fcomp", "lat")
	stack.pft$lat <- as.numeric(paste(stack.pft$lat))
	stack.pft$lon <- ed.lon
	stack.pft$PFT <- as.factor(i)

	if(i==1){
		fcomp.stack <- stack.pft
	} else {
		fcomp.stack <- rbind(fcomp.stack, stack.pft)
	}
}

summary(fcomp.stack)

pfts <- unique(fcomp.stack[!is.na(fcomp.stack$Fcomp) & fcomp.stack$Fcomp>0,"PFT"])

ggplot(data=fcomp.stack[fcomp.stack$PFT %in% pfts, ]) +
	facet_wrap(~PFT) +
	geom_raster(aes(x=lon, y=lat, fill=Fcomp)) +
	coord_equal(ratio=1)
# ------------


# ------------
# AGB
# ------------
ed.agb <- ncvar_get(ed.file, "AGB")
ed.agb <- data.frame(apply(ed.agb, 1:2, FUN=mean))
names(ed.agb) <- ed.lat
summary(ed.agb)

agb.stack <- stack(ed.agb)
names(agb.stack) <- c("AGB", "lat")
agb.stack$lat <- as.numeric(paste(agb.stack$lat))
agb.stack$lon <- as.numeric(ed.lon)
summary(agb.stack)

ggplot(data=agb.stack[, ]) +
	geom_raster(aes(x=lon, y=lat, fill=AGB)) +
	coord_equal(ratio=1)

# ------------


# ------------
# Tair
# ------------
ed.tair <- ncvar_get(ed.file, "tair")
ed.tair <- data.frame(apply(ed.tair, 1:2, FUN=mean))
names(ed.tair) <- ed.lat
summary(ed.tair)

tair.stack <- stack(ed.tair)
names(tair.stack) <- c("tair", "lat")
tair.stack$lat <- as.numeric(paste(tair.stack$lat))
tair.stack$lon <- as.numeric(ed.lon)
summary(tair.stack)

ggplot(data=tair.stack[, ]) +
	geom_raster(aes(x=lon, y=lat, fill=tair-273.15)) +
	coord_equal(ratio=1)

# ------------
