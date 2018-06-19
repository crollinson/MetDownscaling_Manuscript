# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Aggregate Ameriflux dataset to daily resolution for use in bias correction
# Creator: Christy Rollinson, 1 July 2016
# Contact: crollinson@gmail.com
# -----------------------------------

# -----------------------------------
# Description
# -----------------------------------
# In order for the bias correction script to work most robustly, it's going to best best 
# if the training dataset is matched in temporal resolution to most of the data we're trying
# to bias correct
# -----------------------------------

rm(list=ls())

# -----------------------------------
# 0. Set up file structure, load packages, etc
# -----------------------------------
# Load libraries
library(ncdf4)
library(mgcv); library(ggplot2)
library(stringr)
library(lubridate)

# Set the working directory
path.google <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/"
# wd.base <- "/home/crollinson/met_ensemble"
# out.base <- wd.base
# setwd(wd.base)

# Setting some important file paths
path.pecan <- "/home/crollinson/pecan"

# Defining a site name -- this can go into a function later
site.name = "WILLOWCREEK"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W

path.raw <- file.path(path.google, "data/Raw_Inputs", site.name, "Ameriflux_WCr")
files.train <- dir(path.raw, ".nc")

outfolder <- file.path(path.google, "data/Raw_Inputs", site.name, "Ameriflux_day")
dir.create(outfolder, recursive=T)
# -----------------------------------

# -----------------------------------
# 1. generate a daily training dataset to get us started
# 
# this will end up being a 1-member "ensemble" of the Ameriflux dataset
# -----------------------------------

df.var <- data.frame(CF.name = c("air_temperature", "air_temperature_maximum", "air_temperature_minimum", 
                                 "surface_downwelling_longwave_flux_in_air",
                                 "air_pressure", "surface_downwelling_shortwave_flux_in_air", 
                                 "eastward_wind", "northward_wind", "wind_speed", "specific_humidity", "precipitation_flux"), 
                     units = c("Kelvin", "Kelvin", "Kelvin", "W/m2", "Pascal", "W/m2", "m/s", "m/s", "m/s", "g/g", "kg/m2/s"))

nc.info <- data.frame(CF.name = c("air_temperature_minimum", "air_temperature_maximum", "precipitation_flux", 
                                  "surface_downwelling_shortwave_flux_in_air", "surface_downwelling_longwave_flux_in_air", 
                                  "air_pressure", "specific_humidity", "wind_speed"), 
                      longname = c("2 meter minimum air temperature", "2 meter maximum air temperature", 
                                   "cumulative precipitation (water equivalent)", "incident (downwelling) showtwave radiation", 
                                   "incident (downwelling) longwave radiation", "air_pressureure at the surface", 
                                   "Specific humidity measured at the lowest level of the atmosphere", 
                                   "Wind speed"), 
                      units = c("K", "K", "kg m-2 s-1", "W m-2", "W m-2", "Pa", 
                                "kg kg-1", "m s-1"))


for(i in 1:length(files.train)){
  
  # Figure out what year we're working with
  yr.now <- as.numeric(strsplit(files.train[i], "[.]")[[1]][2])
  nday <- ifelse(leap_year(yr.now), 366, 365)
  
  dat.day <- list()
  
  # Open the file so we can query from it
  ncT <- nc_open(file.path(path.raw, files.train[i]))
  
  # Extract som plot dimensions
  lat.nc <- ncvar_get(ncT, "latitude")
  lon.nc <- ncvar_get(ncT, "longitude")
  
  time.nc <- ncvar_get(ncT, "time") 
  time.day <- apply(matrix(time.nc, ncol=nday), 2, mean) # get the daily time stamps
  
  # Extract plot info & aggregate to daily resolution
  for(v in names(ncT$var)){
    dat.hr <- matrix(ncvar_get(ncT, v), ncol=nday)
    if(v %in% c("air_temperature_max", "air_temperature_min")) next # Need to trackt his down, but I think this is the max/min for that hour
    if(v == "air_temperature"){
      dat.day[["air_temperature_minimum"]] <- apply(dat.hr, 2, min)
      dat.day[["air_temperature_maximum"]] <- apply(dat.hr, 2, max)
    } else if(v %in% c("eastward_wind", "northward_wind")) {
      wind.e <- matrix(ncvar_get(ncT, "eastward_wind"), ncol=nday)
      wind.n <- matrix(ncvar_get(ncT, "northward_wind"), ncol=nday)
      wind <- sqrt(wind.e^2 + wind.n^2)
      dat.day[["wind_speed"]] <- apply(wind, 2, mean)
    } else {
      dat.day[[v]] <- apply(dat.hr, 2, mean)
    }
  }

  # Create a daily .nc file for each year
  dim.lat <- ncdim_def(name='latitude', units='degree_north', vals=lat.nc, create_dimvar=TRUE)
  dim.lon <- ncdim_def(name='longitude', units='degree_east', vals=lon.nc, create_dimvar=TRUE)
  dim.time <- ncdim_def(name='time', units="sec", vals=time.day, create_dimvar=TRUE, unlim=TRUE)
  nc.dim=list(dim.lat,dim.lon,dim.time)
  
  var.list = list()
  for(v in names(dat.day)){
    var.list[[v]] = ncvar_def(name=v, units=as.character(nc.info[nc.info$CF.name==v, "units"]), dim=nc.dim, missval=-999, verbose=F)
  }
  
  loc.file <- file.path(outfolder, paste("Ameriflux_day", str_pad(yr.now, width=4, side="left",  pad="0"), "nc", sep = "."))
  loc <- nc_create(filename = loc.file, vars = var.list, verbose = F)
  
  for (v in names(dat.day)) {
    ncvar_put(nc = loc, varid = as.character(v), vals = dat.day[[v]])
  }
  nc_close(loc)	
}

# -----------------------------------

