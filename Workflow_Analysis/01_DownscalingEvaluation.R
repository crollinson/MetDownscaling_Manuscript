# Downscaling Method Evaluation -- Improvement in tower agreement

# -----------------------------------
# 0. Set up file structure, load packages, etc
# -----------------------------------
library(ncdf4)
library(ggplot2)
library(cowplot)

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
path.tdm.base <- file.path(wd.base, "data/Downscaled_Outputs", paste0(site.name, vers), "1hr", "ensembles")
# -----------------------------------

# -----------------------------------
# 1. Read in met data
#    1.1. Raw 
#    1.2. Bias-corrected (summarize)
# -----------------------------------
cols.meta <- c("type", "source", "Date", "Year", "DOY", "Hour")
vars.CF <- c("air_temperature", "precipitation_flux", "surface_downwelling_shortwave_flux_in_air", "surface_downwelling_longwave_flux_in_air", "air_pressure", "specific_humidity", "wind_speed")
vars.short <- c("tair", "precip", "swdown", "lwdown", "press", "qair", "wind")

extract.met <- function(train.path){
  files.train <- dir(train.path, ".nc")
  
  yrs.file <- strsplit(files.train, "[.]")
  yrs.file <- matrix(unlist(yrs.file), ncol=length(yrs.file[[1]]), byrow=T)
  yrs.file <- as.numeric(yrs.file[,ncol(yrs.file)-1]) # Assumes year is always last thing before the file extension
  
  met.out <- data.frame()
  for(i in 1:length(files.train)){
    yr.now <- yrs.file[i]
    
    ncT <- ncdf4::nc_open(file.path(train.path, files.train[i]))
    
    # Set up the time data frame to help index
    nday <- ifelse(lubridate::leap_year(yr.now), 366, 365)
    ntime <- length(ncT$dim$time$vals)
    step.day <- nday/ntime
    step.hr  <- step.day*24
    stamps.hr <- seq(step.hr/2, by=step.hr, length.out=1/step.day) # Time stamps centered on period
    
    # Create a data frame with all the important time info
    # center the hour step
    df.tmp <- data.frame(Year=yr.now, DOY=rep(1:nday, each=1/step.day), Hour=rep(stamps.hr, length.out=ntime))
    df.tmp$Date <- strptime(paste(df.tmp$Year, df.tmp$DOY, df.tmp$Hour, sep="-"), format=("%Y-%j-%H"), tz="UTC")
    
    # Extract the met info, making matrices with the appropriate number of ensemble members
    for(v in names(ncT$var)){
      df.tmp[,v] <- ncdf4::ncvar_get(ncT, v)
    }
    ncdf4::nc_close(ncT)
    
    met.out <- rbind(met.out, df.tmp)
  } # End looping through training data files
  
  return(met.out)
} # End function

dat.wcr <- extract.met(train.path = file.path(path.raw.base, "Ameriflux_WCr"))
dat.wcr$wind_speed <- sqrt(dat.wcr$northward_wind^2 + dat.wcr$eastward_wind^2)
dat.wcr$source <- "Ameriflux"
dat.wcr$type <- "raw-tower"
summary(dat.wcr)

dat.nldas <- extract.met(train.path = file.path(path.raw.base, "NLDAS"))
dat.nldas$wind_speed <- sqrt(dat.nldas$northward_wind^2 + dat.nldas$eastward_wind^2)
dat.nldas$source <- "NLDAS"
dat.nldas$type <- "raw-gridded"
summary(dat.nldas)

ens.mems <- dir(file.path(path.tdm.base, "NLDAS"), "NLDAS")
dat.ens <- data.frame()
for(ENS in ens.mems){
  ens.id <- stringr::str_split(ENS, "_")[[1]][3]
  dat.mem <- extract.met(train.path = file.path(path.tdm.base, "NLDAS", ENS))
  dat.mem$source <- paste("ensemble", ens.id, sep="-")
  # summary(dat.mem)
  
  dat.ens <- rbind(dat.ens, dat.mem)
}
dat.ens$type <- "downscaled"

# Binding everything together
# cols.meta[!cols.meta %in% names(dat.wcr)]
# vars.CF[!vars.CF %in% names(dat.wcr)]
dat.all <- rbind(dat.wcr[,c(cols.meta, vars.CF)], dat.nldas[,c(cols.meta, vars.CF)], dat.ens[,c(cols.meta, vars.CF)])
summary(dat.all)
dim(dat.all)

dat.long <- stack(dat.all[,vars.CF])
dat.long[,cols.meta] <- dat.all[,cols.meta]
summary(dat.long)
# -----------------------------------

# -----------------------------------
# Aggregating to different scales and graphing
# -----------------------------------
# -------------------
# Annual means
# -------------------
# Aggregate to annual means, preserving each ensemble member (source) along the way 
dat.ann <- aggregate(dat.long$values, by=dat.long[,c("type", "source", "Year", "ind")], FUN=mean, na.rm=F)
names(dat.ann)[which(names(dat.ann)=="x")] <- "values"

# Aggregate again to get the ensemble mean & CI
dat.ann2 <- aggregate(dat.ann$values, by=dat.ann[,c("type", "Year", "ind")], FUN=mean, na.rm=F)
names(dat.ann2)[which(names(dat.ann2)=="x")] <- "val.mean"
dat.ann2$val.025 <- aggregate(dat.ann$values, by=dat.ann[,c("type", "Year", "ind")], FUN=quantile, 0.025, na.rm=F)$x
dat.ann2$val.975 <- aggregate(dat.ann$values, by=dat.ann[,c("type", "Year", "ind")], FUN=quantile, 0.975, na.rm=F)$x
dat.ann2$scale <- "annual"
dat.ann2$type <- factor(dat.ann2$type, levels=c("raw-tower", "raw-gridded", "downscaled"))
summary(dat.ann2)

plot.ann <- ggplot(data=dat.ann2) +
  facet_grid(ind ~ scale, scales="free_y", switch="y") +
  geom_ribbon(aes(x=Year, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=Year, y=val.mean, color=type)) +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  theme_bw() +
  theme(strip.placement = "outside",
        axis.title.y=element_blank(),
        legend.position="top")

png(file.path(wd.base, "figures", "MetComparison_01_annual.png"), height=17, width=4, units="in", res=180)
plot.ann
dev.off()

# -------------------

# -------------------
# Daily means (seasonal cycle)
# -------------------
# Aggregate to annual means, preserving each ensemble member (source) along the way 
dat.seas <- aggregate(dat.long$values, by=dat.long[,c("type", "source", "DOY", "ind")], FUN=mean, na.rm=F)
names(dat.seas)[which(names(dat.seas)=="x")] <- "values"

# Aggregate again to get the ensemble mean & CI
dat.seas2 <- aggregate(dat.seas$values, by=dat.seas[,c("type", "DOY", "ind")], FUN=mean, na.rm=F)
names(dat.seas2)[which(names(dat.seas2)=="x")] <- "val.mean"
dat.seas2$val.025 <- aggregate(dat.seas$values, by=dat.seas[,c("type", "DOY", "ind")], FUN=quantile, 0.025, na.rm=F)$x
dat.seas2$val.975 <- aggregate(dat.seas$values, by=dat.seas[,c("type", "DOY", "ind")], FUN=quantile, 0.975, na.rm=F)$x
dat.seas2$scale <- "seasonal"
dat.seas2$type <- factor(dat.seas2$type, levels=c("raw-tower", "raw-gridded", "downscaled"))
summary(dat.seas2)

plot.seas <- ggplot(data=dat.seas2) +
  facet_grid(ind ~ scale, scales="free_y", switch="y") +
  geom_ribbon(aes(x=DOY, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  theme_bw() +
  theme(strip.placement = "outside",
        axis.title.y=element_blank(),
        legend.position="top",
        strip.text.y=element_blank())

png(file.path(wd.base, "figures", "MetComparison_02_season.png"), height=17, width=4, units="in", res=180)
plot.seas
dev.off()

# -------------------

# -------------------
# Subdaily means (diel cycle)
# -------------------
days.graph <- data.frame(winter=(45-3):(45+3), spring=(135-3):(135+3), summer=(225-3):(225+3), fall=(315-3):(315+3))
days.graph <- stack(days.graph)
names(days.graph) <- c("DOY", "season")

# Aggregate to annual means, preserving each ensemble member (source) along the way 
dat.diel <- aggregate(dat.long$values[dat.long$DOY %in% days.graph$DOY], by=dat.long[dat.long$DOY %in% days.graph$DOY,c("type", "source", "DOY", "Hour", "ind")], FUN=mean, na.rm=F)
names(dat.diel)[which(names(dat.diel)=="x")] <- "values"
dat.diel$DOY2 <- dat.diel$DOY + dat.diel$Hour/24
dat.diel <- merge(dat.diel, days.graph)
summary(dat.diel)

# Aggregate again to get the ensemble mean & CI
dat.diel2 <- aggregate(dat.diel$values, by=dat.diel[,c("type", "season", "DOY", "Hour", "ind")], FUN=mean, na.rm=F)
names(dat.diel2)[which(names(dat.diel2)=="x")] <- "val.mean"
dat.diel2$val.025 <- aggregate(dat.diel$values, by=dat.diel[,c("type", "season", "DOY", "Hour", "ind")], FUN=quantile, 0.025, na.rm=F)$x
dat.diel2$val.975 <- aggregate(dat.diel$values, by=dat.diel[,c("type", "season", "DOY", "Hour", "ind")], FUN=quantile, 0.975, na.rm=F)$x
dat.diel2$DOY2 <- dat.diel2$DOY + dat.diel2$Hour/24
dat.diel2$scale <- "diel"
dat.diel2$type <- factor(dat.diel2$type, levels=c("raw-tower", "raw-gridded", "downscaled"))
summary(dat.diel2)

plot.tair <- ggplot(data=dat.diel2[dat.diel2$ind=="air_temperature",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title=element_blank(),
        axis.text.y=element_blank())
plot.precipf <- ggplot(data=dat.diel2[dat.diel2$ind=="precipitation_flux",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title=element_blank(),
        axis.text.y=element_blank())
plot.swdown <- ggplot(data=dat.diel2[dat.diel2$ind=="surface_downwelling_shortwave_flux_in_air",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title=element_blank(),
        axis.text.y=element_blank())
plot.lwdown <- ggplot(data=dat.diel2[dat.diel2$ind=="surface_downwelling_longwave_flux_in_air",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title=element_blank(),
        axis.text.y=element_blank())
plot.press <- ggplot(data=dat.diel2[dat.diel2$ind=="air_pressure",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title=element_blank(),
        axis.text.y=element_blank())
plot.qair <- ggplot(data=dat.diel2[dat.diel2$ind=="specific_humidity",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title=element_blank(),
        axis.text.y=element_blank())
plot.wind <- ggplot(data=dat.diel2[dat.diel2$ind=="wind_speed",]) +
  facet_wrap(~season, scales="free") +
  geom_ribbon(aes(x=DOY2, ymin=val.025, ymax=val.975, fill=type), alpha=0.5) +
  geom_line(aes(x=DOY2, y=val.mean, color=type)) +
  scale_x_continuous(name="Day of Year") +
  scale_color_manual(values=c("black", "red2", "blue2")) + 
  scale_fill_manual(values=c("black", "red2", "blue2")) + 
  guides(color=F, fill=F) +
  theme_bw() +
  theme(strip.placement = "outside",
        legend.position="top",
        axis.title.y=element_blank(),
        axis.text.y=element_blank())

plot.diel <- plot_grid(plot.tair, plot.precipf, plot.swdown, plot.lwdown, plot.press, plot.qair, plot.wind, ncol=1)

png(file.path(wd.base, "figures", "MetComparison_03_diel.png"), height=16, width=4, units="in", res=180)
plot.diel
dev.off()
# -------------------

# -------------------
# Putting everything together with cowplot
# -------------------
# -------------------

# -----------------------------------
