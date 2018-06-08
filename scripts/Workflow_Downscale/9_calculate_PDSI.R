# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Calculate PDSI from our ensemble of met drivers
# Creator: Christy ROllinson
# Contact: crollinson@mortonarb.org
# -----------------------------------
# Description
# -----------------------------------
# This script calls code adapted from Ben Cook (LDEO) to calculate PDSI
# so that it can then be compared to
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 0. Set up file structure, load packages, etc
# 1. 
# -----------------------------------

# -----------------------------------
# 0. define file paths and some info about the site
# -----------------------------------
wd.base <- "/home/crollinson/met_ensemble"
site.name = "ROOSTER"
vers=".v1"
site.lat  = 43.2309
site.lon  = -74.5267

in.base = file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "aggregated/month/")
years.pdsi = NULL
years.calib = c(1931, 1990)
# ----------


# -----------------------------------
# 1. Extract & calculate our soil water values
# -----------------------------------
source("calc_pdsi.R")
source("calc.awc.R")
source("pdsi1.R")
source("pdsix.R")
source("PE.thornthwaite.R")
source("soilmoi1.R")

path.soil <- "~/ED_PalEON/MIP2_Region/phase2_env_drivers_v2/soil/"
# path.soil <- "~/Dropbox/PalEON_CR/env_regional/phase2_env_drivers_v2/soil" 

sand.t <- ncdf4::nc_open(file.path(path.soil, "paleon_soil_t_sand.nc"))
sand.s <- ncdf4::nc_open(file.path(path.soil, "paleon_soil_s_sand.nc"))
clay.t <- ncdf4::nc_open(file.path(path.soil, "paleon_soil_t_clay.nc"))
clay.s <- ncdf4::nc_open(file.path(path.soil, "paleon_soil_s_clay.nc"))
depth  <- ncdf4::nc_open(file.path(path.soil, "paleon_soil_soil_depth.nc"))

lon <- ncdf4::ncvar_get(sand.t, "longitude")
lat <- ncdf4::ncvar_get(sand.t, "latitude")

x.ind <- which(lon-0.25<=site.lon & lon+0.25>=site.lon)
y.ind <- which(lat-0.25<=site.lat & lat+0.25>=site.lat)

sand1 <- ncdf4::ncvar_get(sand.t, "t_sand", c(x.ind, y.ind), c(1,1))
sand2 <- ncdf4::ncvar_get(sand.s, "s_sand", c(x.ind, y.ind), c(1,1))
clay1 <- ncdf4::ncvar_get(clay.t, "t_clay", c(x.ind, y.ind), c(1,1))
clay2 <- ncdf4::ncvar_get(clay.s, "s_clay", c(x.ind, y.ind), c(1,1))
depth2 <- ncdf4::ncvar_get(depth, "soil_depth", c(x.ind, y.ind), c(1,1))

awc1 <- calc.awc(sand1, clay1)
awc2 <- calc.awc(sand2, clay2)

wcap1 <- awc1*ifelse(depth2>30, 30, depth2-1) * 1/2.54 # 30 cm top depth * 1 in / 2.54 cm
wcap2 <- awc2*ifelse(depth2>30, depth2-30, 1) * 1/2.54 # remaining depth * 1 in / 2.54 cm

watcap <- c(wcap1, wcap2)
# -----------------------------------


# -----------------------------------
# Loop through and perform the calculation
# -----------------------------------
# in.base = "~/Desktop/Research/met_ensembles/data/met_ensembles/HARVARD/aggregated/month/CCSM4/CCSM4_001.01"

out.save <- NULL
GCM.list <- list.dirs(in.base, recursive=F, full.names = F)
for(GCM in GCM.list){
  print(GCM)
  
  gcm.ens <- list.dirs(file.path(in.base, GCM), full.names=F, recursive=F)
  pb <- txtProgressBar(min=0, max=length(gcm.ens), style=3)
  pb.ind=1
  for(ens in gcm.ens){
    ens.out <- calc.pdsi(path.in=file.path(in.base, GCM, ens), 
                         years.pdsi=NULL, years.calib=years.calib, 
                         watcap=watcap)
    
    if(is.null(out.save)){
      out.save <- list()
      out.save$Temp   <- data.frame(ens=as.vector(t(ens.out$T)))
      out.save$Precip <- data.frame(ens=as.vector(t(ens.out$P)))
      out.save$PDSI   <- data.frame(ens=as.vector(t(ens.out$X)))
      
      names(out.save$Temp) <- names(out.save$Precip) <- names(out.save$PDSI) <- ens
      row.labs <- paste(rep(row.names(ens.out$T), each=ncol(ens.out$T)), stringr::str_pad(1:ncol(ens.out$T), 2, pad="0"), sep="-")
      row.names(out.save$Temp) <- row.names(out.save$Precip) <- row.names(out.save$Precip) <- row.labs 
      
      temp.array   <- array(ens.out$T, dim=c(dim(ens.out$T), 1))
      precip.array <- array(ens.out$P, dim=c(dim(ens.out$P), 1))
      pdsi.array   <- array(ens.out$X, dim=c(dim(ens.out$X), 1))
    } else {
      out.save$Temp  [,ens] <- as.vector(t(ens.out$T))
      out.save$Precip[,ens] <- as.vector(t(ens.out$P))
      out.save$PDSI  [,ens] <- as.vector(t(ens.out$X))
      
      temp.array   <- abind::abind(temp.array, ens.out$T, along=3)
      precip.array <- abind::abind(precip.array, ens.out$P, along=3)
      pdsi.array   <- abind::abind(pdsi.array, ens.out$X, along=3)
    }
    
    setTxtProgressBar(pb, pb.ind)
    pb.ind=pb.ind+1
  } # End ensemble member loop
  print("")
} # End GCM Loop

# Save the Output
write.csv(out.save$Temp, file.path(in.base, "Temperature_AllMembers.csv"), row.names=T)
write.csv(out.save$Precip, file.path(in.base, "Precipitation_AllMembers.csv"), row.names=T)
write.csv(out.save$PDSI, file.path(in.base, "PDSI_AllMembers.csv"), row.names=T)

# -----------------------------------


# -----------------------------------
# Do some graphing
# -----------------------------------
tair.ann <- data.frame(apply(temp.array, c(1,3), mean, na.rm=T))
precip.ann <- data.frame(apply(precip.array, c(1,3), sum, na.rm=T))
pdsi.ann <- data.frame(apply(pdsi.array, c(1,3), mean, na.rm=T))


tair.summ <- data.frame(var="Temperature", 
                        year=1600:2015, 
                        median=apply(tair.ann, 1, median, na.rm=T),
                        lwr =apply(tair.ann, 1, quantile, 0.025, na.rm=T),
                        upr =apply(tair.ann, 1, quantile, 0.975, na.rm=T))
precip.summ <- data.frame(var="Precipitation",
                          year=1600:2015, 
                          median=apply(precip.ann, 1, median, na.rm=T),
                          lwr =apply(precip.ann, 1, quantile, 0.025, na.rm=T),
                          upr =apply(precip.ann, 1, quantile, 0.975, na.rm=T))
pdsi.summ <- data.frame(var="PDSI",
                        year=1600:2015, 
                        median=apply(pdsi.ann, 1, median, na.rm=T),
                        lwr =apply(pdsi.ann, 1, quantile, 0.025, na.rm=T),
                        upr =apply(pdsi.ann, 1, quantile, 0.975, na.rm=T))

met.all <- rbind(tair.summ, precip.summ, pdsi.summ)

library(ggplot2)
png(file.path(in.base, "Met_Summary_Annual.png"), height=8.5, width=11, unit="in", res=220)
print(
  ggplot(data=met.all) + facet_grid(var~., scales="free_y") +
    geom_ribbon(aes(x=year, ymin=lwr, ymax=upr, fill=var), alpha=0.5) +
    geom_line(aes(x=year, y=median, color=var)) + 
    geom_vline(xintercept=c(2010, 1900, 1849), linetype="dashed", size=0.5) +
    scale_fill_manual(values=c("red", "blue2", "green3")) +
    scale_color_manual(values=c("red", "blue2", "green3")) +
    theme_bw() +
    theme(legend.position="top")
)
dev.off()

# Tricking the PDSI CI into not being ridiculous
met.all[met.all$var=="PDSI" & met.all$lwr < -5, "lwr"] <- -5
met.all[met.all$var=="PDSI" & met.all$upr > 7.5, "upr"] <- 7.5
png(file.path(in.base, "Met_Summary_Annual2.png"), height=8.5, width=11, unit="in", res=220)
print(
  ggplot(data=met.all) + facet_grid(var~., scales="free_y") +
    geom_ribbon(aes(x=year, ymin=lwr, ymax=upr, fill=var), alpha=0.5) +
    geom_line(aes(x=year, y=median, color=var)) + 
    geom_vline(xintercept=c(2010, 1900, 1849), linetype="dashed", size=0.5) +
    scale_fill_manual(values=c("red", "blue2", "green3")) +
    scale_color_manual(values=c("red", "blue2", "green3")) +
    # scale_x_continuous(expand=c(0,0)) +
    scale_y_continuous((expand=c(0,0))) +
    # coord_cartesian(ylim=c(-15,15)) +
    theme_bw() +
    theme(legend.position="top")
)
dev.off()
# -----------------------------------
