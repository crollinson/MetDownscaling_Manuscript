# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Perform a visual check on the met that has been bias-corrected
# Creator: Christy Rollinson, 5 September 2017
# Contact: crollinson@gmail.com
# -----------------------------------
# Description
# -----------------------------------
# Post-bias correct QAQC to make sure means & variances look more or less okay 
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 0. Set up file structure, load packages, etc
# 1. Read in & format met data
#    1.1. Raw 
#    1.2. Bias-corrected (summarize)
# 2. QAQC graphing
# -----------------------------------
rm(list=ls())

# -----------------------------------
# 0. Set up file structure, load packages, etc
# -----------------------------------
library(ncdf4)
library(ggplot2)

# Ensemble directories
wd.base <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/"
path.pecan <- "~/Desktop/Research/pecan"

# Site name for indexing
site.name = "WILLOWCREEK"
vers=".v2"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W

# Setting up some file paths, etc
path.raw.base <- file.path(wd.base, "data/Raw_Inputs", site.name)
path.day.base <- file.path(wd.base, "data/Downscaled_Outputs", paste0(site.name, vers), "day")

# defining some variable names
vars.CF <- c("air_temperature_minimum", "air_temperature_maximum", "precipitation_flux", "surface_downwelling_shortwave_flux_in_air", "surface_downwelling_longwave_flux_in_air", "air_pressure", "specific_humidity", "wind_speed")
vars.short <- c("tair.min", "tair.max", "precip", "swdown", "lwdown", "press", "qair", "wind")

# -----------------------------------


# -----------------------------------
# 1. Read in met data
#    1.1. Raw 
#    1.2. Bias-corrected (summarize)
# -----------------------------------
# Use the align.met funciton to get everything harmonized
source(file.path(path.pecan, "modules/data.atmosphere/R/align_met.R"))

# ---------
# 1.1. Raw Data
# ---------
# Do this once with NLDAS and CRUNCEP
met.base <- align.met(train.path=file.path(path.raw.base, "Ameriflux_day"), source.path = file.path(path.raw.base, "NLDAS_day"), n.ens=1, seed=20170905)

met.raw <- data.frame(met.base$dat.train$time)
met.raw$dataset <- "Ameriflux"
met.raw$tair.min <- met.base$dat.train$air_temperature_minimum[,1]
met.raw$tair.max <- met.base$dat.train$air_temperature_maximum[,1]
met.raw$precip   <- met.base$dat.train$precipitation_flux[,1]
met.raw$swdown   <- met.base$dat.train$surface_downwelling_shortwave_flux_in_air[,1]
met.raw$lwdown   <- met.base$dat.train$surface_downwelling_longwave_flux_in_air[,1]
met.raw$press    <- met.base$dat.train$air_pressure[,1]
met.raw$qair     <- met.base$dat.train$specific_humidity[,1]
met.raw$wind     <- met.base$dat.train$wind_speed[,1]


met.tmp <- data.frame(met.base$dat.source$time)
met.tmp$dataset <- "NLDAS"
met.tmp$tair.min <- met.base$dat.source$air_temperature_minimum[,1]
met.tmp$tair.max <- met.base$dat.source$air_temperature_maximum[,1]
met.tmp$precip   <- met.base$dat.source$precipitation_flux[,1]
met.tmp$swdown   <- met.base$dat.source$surface_downwelling_shortwave_flux_in_air[,1]
met.tmp$lwdown   <- met.base$dat.source$surface_downwelling_longwave_flux_in_air[,1]
met.tmp$press    <- met.base$dat.source$air_pressure[,1]
met.tmp$qair     <- met.base$dat.source$specific_humidity[,1]
met.tmp$wind     <- met.base$dat.source$wind_speed[,1]

met.raw <- rbind(met.raw, met.tmp)
# ---------


# ---------
# 1.2. Bias-Corrected data
# ---------
GCM="NLDAS_downscaled"
met.bias <- list()
met.base <- align.met(train.path=file.path(path.raw.base, "NLDAS_day"), source.path = file.path(path.day.base, "ensembles"), n.ens=10, pair.mems=FALSE, seed=201709)

met.tmp <- list()
met.tmp$mean <- data.frame(met.base$dat.source$time)
met.tmp$mean$dataset <- GCM
met.tmp$mean$tair.min <- apply(met.base$dat.source$air_temperature_minimum, 1, mean, na.rm=T)
met.tmp$mean$tair.max <- apply(met.base$dat.source$air_temperature_maximum, 1, mean, na.rm=T)
met.tmp$mean$precip   <- apply(met.base$dat.source$precipitation_flux     , 1, mean, na.rm=T)
met.tmp$mean$swdown   <- apply(met.base$dat.source$surface_downwelling_shortwave_flux_in_air, 1, mean, na.rm=T)
met.tmp$mean$lwdown   <- apply(met.base$dat.source$surface_downwelling_longwave_flux_in_air , 1, mean, na.rm=T)
met.tmp$mean$press    <- apply(met.base$dat.source$air_pressure           , 1, mean, na.rm=T)
met.tmp$mean$qair     <- apply(met.base$dat.source$specific_humidity      , 1, mean, na.rm=T)
met.tmp$mean$wind     <- apply(met.base$dat.source$wind_speed             , 1, mean, na.rm=T)

met.tmp$lwr <- data.frame(met.base$dat.source$time)
met.tmp$lwr$dataset <- GCM
met.tmp$lwr$tair.min <- apply(met.base$dat.source$air_temperature_minimum, 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$tair.max <- apply(met.base$dat.source$air_temperature_maximum, 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$precip   <- apply(met.base$dat.source$precipitation_flux     , 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$swdown   <- apply(met.base$dat.source$surface_downwelling_shortwave_flux_in_air, 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$lwdown   <- apply(met.base$dat.source$surface_downwelling_longwave_flux_in_air , 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$press    <- apply(met.base$dat.source$air_pressure           , 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$qair     <- apply(met.base$dat.source$specific_humidity      , 1, quantile, 0.025, na.rm=T)
met.tmp$lwr$wind     <- apply(met.base$dat.source$wind_speed             , 1, quantile, 0.025, na.rm=T)


met.tmp$upr <- data.frame(met.base$dat.source$time)
met.tmp$upr$dataset <- GCM
met.tmp$upr$tair.min <- apply(met.base$dat.source$air_temperature_minimum, 1, quantile, 0.975, na.rm=T)
met.tmp$upr$tair.max <- apply(met.base$dat.source$air_temperature_maximum, 1, quantile, 0.975, na.rm=T)
met.tmp$upr$precip   <- apply(met.base$dat.source$precipitation_flux     , 1, quantile, 0.975, na.rm=T)
met.tmp$upr$swdown   <- apply(met.base$dat.source$surface_downwelling_shortwave_flux_in_air, 1, quantile, 0.975, na.rm=T)
met.tmp$upr$lwdown   <- apply(met.base$dat.source$surface_downwelling_longwave_flux_in_air, 1, quantile, 0.975, na.rm=T)
met.tmp$upr$press    <- apply(met.base$dat.source$air_pressure           , 1, quantile, 0.975, na.rm=T)
met.tmp$upr$qair     <- apply(met.base$dat.source$specific_humidity      , 1, quantile, 0.975, na.rm=T)
met.tmp$upr$wind     <- apply(met.base$dat.source$wind_speed             , 1, quantile, 0.975, na.rm=T)

if(length(met.bias)==0){
  met.bias <- met.tmp
} else {
  met.bias$mean <- rbind(met.bias$mean, met.tmp$mean)
  met.bias$lwr  <- rbind(met.bias$lwr , met.tmp$lwr )
  met.bias$upr  <- rbind(met.bias$upr , met.tmp$upr )
}

# ---------


# -----------------------------------

# -----------------------------------
# 2. QAQC graphing
# -----------------------------------
met.bias.yr.mean <- aggregate(met.bias$mean[,vars.short], by=met.bias$mean[,c("Year", "dataset")], FUN=mean)
met.bias.yr.lwr  <- aggregate(met.bias$lwr [,vars.short], by=met.bias$lwr [,c("Year", "dataset")], FUN=mean)
met.bias.yr.upr  <- aggregate(met.bias$upr [,vars.short], by=met.bias$upr [,c("Year", "dataset")], FUN=mean)
summary(met.bias.yr.mean)

# Stacking everything together
met.bias.yr <- stack(met.bias.yr.mean[,vars.short])
names(met.bias.yr) <- c("mean", "met.var")
met.bias.yr[,c("Year", "dataset")] <- met.bias.yr.mean[,c("Year", "dataset")]
met.bias.yr$lwr <- stack(met.bias.yr.lwr[,vars.short])[,1]
met.bias.yr$upr <- stack(met.bias.yr.upr[,vars.short])[,1]
summary(met.bias.yr)

# Raw met
met.raw.yr1 <- aggregate(met.raw[,vars.short], by=met.raw[,c("Year", "dataset")], FUN=mean, na.rm=T)
met.raw.yr1$dataset2 <- as.factor(met.raw.yr1$dataset)
for(i in 1:nrow(met.raw.yr1)){
  met.raw.yr1[i,"dataset"] <- stringr::str_split(met.raw.yr1[i,"dataset2"], "[.]")[[1]][1]
}
met.raw.yr1$dataset <- as.factor(met.raw.yr1$dataset)
summary(met.raw.yr1)

met.raw.yr <- stack(met.raw.yr1[,vars.short])
names(met.raw.yr) <- c("raw", "met.var")
met.raw.yr[,c("Year", "dataset", "dataset2")] <- met.raw.yr1[,c("Year", "dataset", "dataset2")]
summary(met.raw.yr)

met.raw.yr <- rbind(met.raw.yr, data.frame(raw=NA, met.var=unique(met.raw.yr$met.var), Year=2009, dataset="Ameriflux", dataset2="Ameriflux"))


library(ggplot2)
png(file.path(path.day.base, "Raw_Annual.png"), height=8, width=10, units="in", res=220)
print(
  ggplot(data=met.raw.yr[,]) + facet_wrap(~met.var, scales="free_y") +
    geom_line(aes(x=Year, y=raw, color=dataset), size=0.5) +
    geom_vline(xintercept=c(2009), linetype="dashed") +
    scale_x_continuous(expand=c(0,0)) +
    scale_color_manual(values=c("black", "red")) +
    theme_bw()
)
dev.off()

png(file.path(path.day.base, "Debias_Annual.png"), height=8, width=10, units="in", res=220)
print(
  ggplot(data=met.bias.yr[, ]) + facet_wrap(~met.var, scales="free_y") +
    geom_line(data=met.raw.yr[met.raw.yr$dataset=="Ameriflux",],aes(x=Year, y=raw, color=dataset), size=0.5) +
    geom_ribbon(aes(x=Year, ymin=lwr, ymax=upr, fill=dataset), alpha=0.5) +
    geom_line(aes(x=Year, y=mean, color=dataset), size=0.5) +
    geom_vline(xintercept=c(2009), linetype="dashed") +
    scale_x_continuous(expand=c(0,0)) +
    guides(fill=F) +
    scale_color_manual(values=c("black", "red")) +
    scale_fill_manual(values=c("red")) +
    theme_bw()
)
dev.off()

# Save the summaries of the raw and bias-corrected data to quickly make some customized graphs elsewhere
write.csv(met.raw.yr , file.path(path.day.base, "Met_Raw_Annual.csv"      ), row.names=F)
write.csv(met.bias.yr, file.path(path.day.base, "Met_Corrected_Annual.csv"), row.names=F)

# Looking at the seasonal cycle
met.bias.doy.mean <- aggregate(met.bias$mean[,vars.short], by=met.bias$mean[,c("DOY", "dataset")], FUN=mean, na.rm=T)
met.bias.doy.lwr  <- aggregate(met.bias$lwr [,vars.short], by=met.bias$lwr [,c("DOY", "dataset")], FUN=mean, na.rm=T)
met.bias.doy.upr  <- aggregate(met.bias$upr [,vars.short], by=met.bias$upr [,c("DOY", "dataset")], FUN=mean, na.rm=T)
summary(met.bias.doy.mean)

# Stacking everything together
met.bias.doy <- stack(met.bias.doy.mean[,vars.short])
names(met.bias.doy) <- c("mean", "met.var")
met.bias.doy[,c("DOY", "dataset")] <- met.bias.doy.mean[,c("DOY", "dataset")]
met.bias.doy$lwr <- stack(met.bias.doy.lwr[,vars.short])[,1]
met.bias.doy$upr <- stack(met.bias.doy.upr[,vars.short])[,1]
summary(met.bias.doy)


# met.raw$dataset <- as.character(met.raw$dataset2)
met.raw.doy1 <- aggregate(met.raw[,vars.short], by=met.raw[,c("DOY", "dataset")], FUN=mean, na.rm=T)
met.raw.doy1$dataset2 <- as.factor(met.raw.doy1$dataset)
for(i in 1:nrow(met.raw.doy1)){
  met.raw.doy1[i,"dataset"] <- stringr::str_split(met.raw.doy1[i,"dataset2"], "[.]")[[1]][1]
}
met.raw.doy1$dataset <- as.factor(met.raw.doy1$dataset)

met.raw.doy <- stack(met.raw.doy1[,vars.short])
names(met.raw.doy) <- c("raw", "met.var")
met.raw.doy[,c("DOY", "dataset", "dataset2")] <- met.raw.doy1[,c("DOY", "dataset", "dataset2")]
summary(met.raw.doy)


summary(met.raw.doy1)
summary(met.bias.doy.mean)

library(ggplot2)
png(file.path(path.day.base, "Raw_DOY.png"), height=8, width=10, units="in", res=220)
print(
  ggplot(data=met.raw.doy[,]) + facet_wrap(~met.var, scales="free_y") +
    geom_path(data=met.raw.doy[,], aes(x=DOY, y=raw, color=dataset), size=0.5) +
    scale_x_continuous(expand=c(0,0)) +
    scale_color_manual(values=c("black", "red")) +
    theme_bw()
)
dev.off()

png(file.path(path.day.base, "Debias_DOY.png"), height=8, width=10, units="in", res=220)
print(
  ggplot(data=met.bias.doy[, ]) + facet_wrap(~met.var, scales="free_y") +
    geom_path(data=met.raw.doy[met.raw.doy$dataset=="Ameriflux",], aes(x=DOY, y=raw, color=dataset), size=1) +
    geom_ribbon(aes(x=DOY, ymin=lwr, ymax=upr, fill=dataset), alpha=0.5) +
    geom_path(aes(x=DOY, y=mean, color=dataset), size=0.5) +
    scale_x_continuous(expand=c(0,0)) +
    guides(fill=F) +
    scale_color_manual(values=c("black", "red")) +
    scale_fill_manual(values=c("red")) +
    theme_bw()
)
dev.off()


# Save the summaries of the raw and bias-corrected data to quickly make some customized graphs elsewhere
write.csv(met.raw.doy , file.path(path.day.base, "Met_Raw_DOY.csv"      ), row.names=F)
write.csv(met.bias.doy, file.path(path.day.base, "Met_Corrected_DOY.csv"), row.names=F)

# -----------------------------------
