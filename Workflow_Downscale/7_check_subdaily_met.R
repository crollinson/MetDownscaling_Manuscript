# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Perform a visual check on the met that has been temporally downscaled
# Creator: Christy Rollinson, 5 September 2017
# Contact: crollinson@gmail.com
# -----------------------------------
# Description
# -----------------------------------
# Post-bias correct QAQC to make sure diurnal patterns and transitions between days (& years!) look okay
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 0. Set up file structure, load packages, etc
# 1. Read in & format met data
#    1.1. Raw 
#    1.2. Bias-corrected (summarize)
# 2. QAQC graphing
# -----------------------------------
# rm(list=ls())

# -----------------------------------
# 0. Set up file structure, load packages, etc
# -----------------------------------
library(ncdf4)
library(ggplot2)
library(stringr)

# Ensemble directories
wd.base <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/"
# wd.base <- "~/Desktop/Research/met_ensembles/"
site.name = "WILLOWCREEK"
vers=".v1"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W

path.dat <- file.path(wd.base, "data/Downscaled_Outputs", paste0(site.name, vers), "1hr/ensembles/")
path.out <- file.path(wd.base, "data/Downscaled_Outputs", paste0(site.name, vers), "1hr/figures_qaqc")

dir.create(path.out, recursive=T, showWarnings = F)
# GCM.list <- c("bcc-csm1-1", "CCSM4", "MIROC-ESM", "MPI-ESM-P")

n.day <- 5 # How many parent ensembles we want to graph
n.hr <- 4 # How many independent hourly ensembles we want to show

# yrs.check <- c(2015, 1990, 1900, 1850, 1800, 1300, 1000, 850)
yrs.check <- c(1999, 2004, 2009, 2014)
# yrs.check <- 2015
days.graph <- data.frame(winter=(45-3):(45+3), spring=(135-3):(135+3), summer=(225-3):(225+3), fall=(315-3):(315+3))

vars.CF <- c("air_temperature", "precipitation_flux", "surface_downwelling_shortwave_flux_in_air", "surface_downwelling_longwave_flux_in_air", "air_pressure", "specific_humidity", "wind_speed")
vars.short <- c("tair", "precip", "swdown", "lwdown", "press", "qair", "wind")
# -----------------------------------

# -----------------------------------
# Extract the Met data
# - we're going to extract everything and store it in memory so 
#   we can compare at different levels
# -----------------------------------
met.plot <- list()
dat.hr <- NULL

# Get a list of the *unique* daily ensemble members and then randomly sample 
# *up to* n.day for plotting
ens.all <- dir(file.path(path.dat))
ens.names <- str_split(ens.all, "[.]")
ens.names <- matrix(unlist(ens.names), ncol=length(ens.names[[1]]), byrow=T)
parent.day <- unique(ens.names[,1])

# Randomly picking up to n.day ensemble members for plotting
day.plot <- parent.day[sample(1:length(parent.day), min(length(parent.day), n.day))]

# Extracting the hourly members
for(ens.day in day.plot){
  # Get a list of the ensemble members
  hr.all <- dir(path.dat, ens.day)
  hr.plot <- hr.all[sample(1:length(hr.all), min(length(hr.all), n.hr))]
  
  # Extract our hourly info for the years we want and store in a dataframe
  for(ens.now in hr.all){
    for(yr in yrs.check){
      nday <- ifelse(lubridate::leap_year(yr), 366, 365)
      
      nc.now <- dir(file.path(path.dat, ens.now), paste(yr))
      if(length(nc.now)==0) next 

      ncT <- ncdf4::nc_open(file.path(path.dat, ens.now, nc.now))
      time.nc <- ncdf4::ncvar_get(ncT, "time")
      
      dat.temp <- data.frame(GCM="NLDAS_downscaled", ens.day=ens.day, ens.hr=ens.now, year = yr, doy = rep(1:nday, each=24), hour=rep(seq(0.5, 24, by=1), nday))
      dat.temp$date <- strptime(paste(dat.temp$year, dat.temp$doy, dat.temp$hour, sep="-"), format=("%Y-%j-%H"), tz="UTC")
      
      for(v in 1:length(vars.CF)){
        dat.temp[,vars.CF[v]] <- ncdf4::ncvar_get(ncT, vars.CF[v])
      }
      nc_close(ncT)
      dat.temp <- dat.temp[dat.temp$doy %in% unlist(days.graph),]
      
      if(is.null(dat.hr)){
        dat.hr <- dat.temp
      } else {
        dat.hr <- rbind(dat.hr, dat.temp)
      }
      
    }
  }
}
dim(dat.hr)
# -----------------------------------


# -----------------------------------
# Aggregating & graphing data
# -----------------------------------
dat.hr$season <- ifelse(dat.hr$doy %in% days.graph$winter, "winter", 
                        ifelse(dat.hr$doy %in% days.graph$spring, "spring", 
                               ifelse(dat.hr$doy %in% days.graph$summer, "summer", "fall")))
dat.hr$season <- factor(dat.hr$season, levels=c("winter", "spring", "summer", "fall"))
dat.ind <- stack(dat.hr[,vars.CF])
names(dat.ind) <- c("mean", "ind")
dat.ind[,c("lwr", "upr")] <- NA
dat.ind[,c("GCM", "ens.day", "ens.hr", "year", "season", "doy", "hour", "date")] <- dat.hr[,c("GCM", "ens.day", "ens.hr", "year", "season", "doy", "hour", "date")]
dat.ind$doy2 <- dat.ind$doy+dat.ind$hour
summary(dat.ind)

dat.ens <- aggregate(dat.ind[,"mean"], by=dat.ind[,c("ind", "GCM", "ens.day", "year", "season", "doy", "hour")], FUN=mean)
names(dat.ens)[which(names(dat.ens)=="x")] <- "mean"
dat.ens$lwr <- aggregate(dat.ind[,"mean"], by=dat.ind[,c("ind", "GCM", "ens.day", "year", "season", "doy", "hour")], FUN=quantile, 0.025)$x
dat.ens$upr <- aggregate(dat.ind[,"mean"], by=dat.ind[,c("ind", "GCM", "ens.day", "year", "season", "doy", "hour")], FUN=quantile, 0.975)$x
dat.ens$date <- strptime(paste(dat.ens$year, dat.ens$doy, dat.ens$hour, sep="-"), format=("%Y-%j-%H"), tz="UTC")
summary(dat.ens)
# dat.ind <- dat

library(ggplot2)
for(v in unique(dat.ens$ind)){
  pdf(file.path(path.out, paste0(v, "_ensembles.pdf")), width=10, height=8)
  for(yr in yrs.check[yrs.check %in% unique(dat.ens$year)]){
    print(
      ggplot(data=dat.ens[dat.ens$ind==v & dat.ens$year==yr,]) + facet_wrap(~season, scales="free_x") +
        geom_ribbon(aes(x=date, ymin=lwr, ymax=upr, fill=ens.day), alpha=0.5) +
        geom_line(aes(x=date, y=mean, color=ens.day)) +
        ggtitle(paste(v, yr, sep=" - "))
    )
  }
  dev.off()

  pdf(file.path(path.out, paste0(v, "_members.pdf")), width=10, height=8)
  for(yr in yrs.check[yrs.check %in% unique(dat.ens$year)]){
    print(
      ggplot(data=dat.ind[dat.ind$ind==v & dat.ind$year==yr,]) + facet_wrap(~season, scales="free_x") +
        geom_line(aes(x=date, y=mean, color=ens.day, group=ens.hr), size=0.25) +
        ggtitle(paste(v, yr, sep=" - "))
    )
  }
  dev.off()
  
}
# -----------------------------------
