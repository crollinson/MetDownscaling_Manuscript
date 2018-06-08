# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Extract raw met for an individual site
# Creator: Christy Rollinson, 1 July 2016
# Contact: crollinson@gmail.com
# -----------------------------------

# -----------------------------------
# Description
# -----------------------------------
# Extract raw met for a given site for model at different spatial & temporal scales 
# using get.raw function.
#  -- Funciton Arguments:
#     1. wd.base   = base path to the github repository; there should be subfolders of data & scripts
#     2. site.name = what you want to call the site you're extracting
#     3. lat       = latitude of the site you're extracting (N = positive, 0-90 degrees)
#     4. lon       = longitude of hte site you're processing (W = negative, -180 - 0 degrees)
#     5. ldas.type = whether to extract 3-hourly GLDAS or 1-hourly NLDAS data for the training data
#                     ** If the site is outside the lower 48, you must use GLDAS
#     6. GCM       = Which GCM you want to extract
#  -- Extracts/Processes 3 types of met data:
#     1. LDAS (NLDAS or GLDAS)
#         - Native Temporal Extent: 1980-2015
#         - Driver Usage: 1980-2015, raw
#     2. CRUNCEP
#         - Native Temporal Extent: 1901-2010
#         - Driver Usage: 1901-1979, bias-corrected, temp. downscaled
#     3. GCM
#         A. p1000 simulation
#            - Native Temporal Extent: 850-1850
#            - Driver Usage: 850-1849, bias-corrected, temp. downscaled
#         B. historical simulation
#            - Native Temporal Extent: 1850-2005
#            - Driver Usage: 1850-1900, bias-corrected, temp. downscaled
#  ** Met from each dataset will be saved in {wd.base}/data/paleon_sites/{site.name}
#  -- Function will check to see if each type of data has been done yet before processing
#  -- See get_point_raw.R for internal workflow & more details
# -----------------------------------
rm(list=ls())

wd.base <- "~/Dropbox/PalEON_CR/met_ensemble"
setwd(wd.base)

site.name = "WILLOWCREEK"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W
path.out = "~/Desktop/Research/met_ensembles/data/paleon_sites"

# Path to pecan repository where functions now live
path.pecan <- "~/Desktop/Research/pecan/"

# Download NLDAS (note: this is not a pecan script & requires fill LDAS stored somewhere locally)
source(file.path(path.pecan, "modules/data.atmosphere/R", "extract_local_NLDAS.R"))
ldas.type = "NLDAS"
path.nldas = "/Volumes/Celtis/Meteorology/LDAS/NLDAS_FORA0125_H.002/netcdf/"
extract.local.NLDAS(outfolder=file.path(path.out, site.name, "NLDAS"), in.path=path.nldas, 
                    start_date="1980-01-01", end_date="2015-12-31", 
                    site_id=site.name, lat.in=site.lat, lon.in=site.lon)


# Note: This keeps breaking every 5-10 years; so I'm having to go real slow at it
source(file.path(path.pecan, "modules/data.atmosphere/R", "download.CRUNCEP_Global.R"))
download.CRUNCEP(outfolder=file.path(path.out, site.name, "CRUNCEP"), 
                 start_date="1901-01-01", end_date=paste0("2010-12-31"), 
                 site_id=site.name, lat.in=site.lat, lon.in=site.lon)

# Extract from the GCMs:
source(file.path(path.pecan, "modules/data.atmosphere/R", "extract_local_CMIP5.R"))
path.cmip5 = "/Volumes/Celtis/Meteorology/CMIP5/"
GCM.scenarios = c("p1000", "historical")
GCM.list  = c("CCSM4", "bcc-csm1-1", "MIROC-ESM", "MPI-ESM-P")
# GCM.list="CCSM4"
for(GCM in GCM.list){
  for(scenario in GCM.scenarios){
    if(scenario=="p1000"){
      cmip5.start = "0850-01-01"
      cmip5.end   = "1849-12-31"
    } else if (scenario == "historical"){
      cmip5.start = "1850-01-01"
      cmip5.end   = "2005-12-31"
    } else {
      stop("Scenario not implemented yet")
    }
    
    print(paste(GCM, scenario, sep=" - "))
    # huss_day_MIROC-ESM_past1000_r1i1p1_08500101-10091231.nc
    extract.local.CMIP5(outfolder = file.path(path.out, site.name, GCM, scenario), in.path = file.path(path.cmip5, GCM, scenario), 
                        start_date = cmip5.start, end_date = cmip5.end, 
                        site_id = site.name, lat.in = site.lat, lon.in = site.lon, 
                        model = GCM, scenario = scenario, ensemble_member = "r1i1p1")   
  } # end GCM.scenarios
} # End GM lop



# Graphing the output just to make sure everythign looks okay
met.qaqc <- c("NLDAS", "CRUNCEP")
for(met in c("NLDAS", "CRUNCEP")){
  # Extract & print QAQC graphs for NLDAS
  dat.qaqc <- NULL
  files.qaqc <- dir(file.path(path.out, site.name, met))
  for(i in 1:length(files.qaqc)){
    y.now <- as.numeric(strsplit(files.qaqc[i], "[.]")[[1]][2])
    nday <- ifelse(lubridate::leap_year(y.now), 366, 365)
    
    ncT <- ncdf4::nc_open(file.path(path.out, site.name, met, files.qaqc[i]))
    nc.time <- ncdf4::ncvar_get(ncT, "time")/(60*60*24) 
    day.step <- length(nc.time)/nday
    
    dat.temp <- data.frame(Year=y.now, DOY=rep(1:nday, each=day.step), time=1:day.step-(24/day.step/2))
    for(v in names(ncT$var)){
      dat.temp[,v] <- ncdf4::ncvar_get(ncT, v)
    }
    ncdf4::nc_close(ncT)
    
    if(is.null(dat.qaqc)){
      dat.qaqc <- dat.temp
    } else {
      dat.qaqc <- rbind(dat.qaqc, dat.temp)
    }
  }
  
  dat.qaqc2 <- aggregate(dat.qaqc[,4:ncol(dat.qaqc)], by=dat.qaqc[,c("Year", "DOY")], FUN=mean)
  
  dat.yr1 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"Year"]), FUN=mean)
  names(dat.yr1)[1] <- "Year"
  dat.yr <- stack(dat.yr1[,2:ncol(dat.yr1)])
  dat.yr$Year <- dat.yr1$Year
  summary(dat.yr)
  
  library(ggplot2)
  png(file.path(path.out, site.name, paste0("MetQAQC_", met, "_annual.png")), height=8, width=8, units="in", res=220)
  print(
  ggplot(data=dat.yr) + facet_wrap(~ind, scales="free_y") +
    geom_line(aes(x=Year, y=values))
  )
  dev.off()
  
  dat.doy1 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"DOY"]), FUN=mean)
  dat.doy2 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"DOY"]), FUN=quantile, 0.025)
  dat.doy3 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"DOY"]), FUN=quantile, 0.975)
  names(dat.doy1)[1] <- "DOY"
  dat.doy <- stack(dat.doy1[,2:ncol(dat.doy1)])
  dat.doy$DOY <- dat.doy1$DOY
  dat.doy$lwr <- stack(dat.doy2[,2:ncol(dat.doy2)])[,1]
  dat.doy$upr <- stack(dat.doy3[,2:ncol(dat.doy3)])[,1]
  summary(dat.doy)
  
  png(file.path(path.out, site.name, paste0("MetQAQC_", met, "_DOY.png")), height=8, width=8, units="in", res=220)
  print(
  ggplot(data=dat.doy) + facet_wrap(~ind, scales="free_y") +
    geom_ribbon(aes(x=DOY, ymin=lwr, ymax=upr), alpha=0.5) +
    geom_line(aes(x=DOY, y=values))
  )
  dev.off()
}

GCM.list  = c("MIROC-ESM", "MPI-ESM-P", "bcc-csm1-1", "CCSM4")
for(GCM in GCM.list){
  for(scenario in c("historical", "p1000")){    
    # Extract & print QAQC graphs for NLDAS
    dat.qaqc <- NULL
    files.qaqc <- dir(file.path(path.out, site.name, GCM, scenario))
    for(i in 1:length(files.qaqc)){
      y.now <- strsplit(files.qaqc[i], "[.]")[[1]]
      y.now <- as.numeric(y.now[length(y.now)-1])
      nday <- ifelse(lubridate::leap_year(y.now), 366, 365)
      
      ncT <- ncdf4::nc_open(file.path(path.out, site.name, GCM, scenario, files.qaqc[i]))
      nc.time <- ncdf4::ncvar_get(ncT, "time")/(60*60*24) 
      day.step <- length(nc.time)/nday
      
      dat.temp <- data.frame(Year=y.now, DOY=rep(1:nday, each=day.step), time=1:day.step-(24/day.step/2))
      for(v in names(ncT$var)){
        dat.temp[,v] <- ncdf4::ncvar_get(ncT, v)
      }
      ncdf4::nc_close(ncT)
      
      if(is.null(dat.qaqc)){
        dat.qaqc <- dat.temp
      } else {
        dat.qaqc <- rbind(dat.qaqc, dat.temp)
      }
    }
    
    dat.qaqc2 <- aggregate(dat.qaqc[,4:ncol(dat.qaqc)], by=dat.qaqc[,c("Year", "DOY")], FUN=mean)
    
    dat.yr1 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"Year"]), FUN=mean)
    names(dat.yr1)[1] <- "Year"
    dat.yr <- stack(dat.yr1[,2:ncol(dat.yr1)])
    dat.yr$Year <- dat.yr1$Year
    summary(dat.yr)
    
    library(ggplot2)
    png(file.path(path.out, site.name, paste0("MetQAQC_", GCM, "_", scenario, "_annual.png")), height=8, width=8, units="in", res=220)
    print(
      ggplot(data=dat.yr) + facet_wrap(~ind, scales="free_y") +
        geom_line(aes(x=Year, y=values))
    )
    dev.off()
    
    dat.doy1 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"DOY"]), FUN=mean, na.rm=T)
    dat.doy2 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"DOY"]), FUN=quantile, 0.025, na.rm=T)
    dat.doy3 <- aggregate(dat.qaqc2[,3:ncol(dat.qaqc2)], by=list(dat.qaqc2[,"DOY"]), FUN=quantile, 0.975, na.rm=T)
    names(dat.doy1)[1] <- "DOY"
    dat.doy <- stack(dat.doy1[,2:ncol(dat.doy1)])
    dat.doy$DOY <- dat.doy1$DOY
    dat.doy$lwr <- stack(dat.doy2[,2:ncol(dat.doy2)])[,1]
    dat.doy$upr <- stack(dat.doy3[,2:ncol(dat.doy3)])[,1]
    summary(dat.doy)
    
    png(file.path(path.out, site.name, paste0("MetQAQC_", GCM, "_", scenario, "_DOY.png")), height=8, width=8, units="in", res=220)
    print(
      ggplot(data=dat.doy) + facet_wrap(~ind, scales="free_y") +
        geom_ribbon(aes(x=DOY, ymin=lwr, ymax=upr), alpha=0.5) +
        geom_line(aes(x=DOY, y=values))
    )
    dev.off()
  }
}