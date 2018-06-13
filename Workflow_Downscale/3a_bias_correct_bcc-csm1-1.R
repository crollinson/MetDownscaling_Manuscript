# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Bias-correction to create a smooth daily met product from multiple sources 
#          of varying temporal frequencies and extents
# Creator: Christy Rollinson, 1 July 2016
# Contact: crollinson@gmail.com
# -----------------------------------
# Description
# -----------------------------------
# Bias-correct raw met data & take monthly variables to daily time step
# The end state of this script is continuous, smoothly daily output from 850-2010+ 
# that can be used as is or fed into the day to subday script to get hourly drivers
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 0. Set up file structure, load packages, etc
# 1. Align Data:
# 2. Debias & Save Met
# -----------------------------------
# Met Dataset Workflow
# -----------------------------------
# 1. Set up ensemble structure; copy LDAS into ensemble directories
# 2. Debias CRUNCEP (1 series) using LDAS (1 series)
#    - save 1901-1979 (until LDAS kicks in)
# 3. Debias GCM historical runs (1 time series) using CRUNCEP (n.ens series)
#    - save 1850-1901 (until CRUNCEP kicks in)
# 4. Debias GCM past millennium (1 time series) using GCM Historical (n.ens series)
#    - save 850-1849 (until GCM historical kicks in)
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
wd.base <- "/home/crollinson/met_ensemble/"
# wd.base <- "~/Desktop/Research/met_ensembles/"
out.base <- wd.base
setwd(wd.base)

# Setting some important file paths
path.pecan <- "/home/crollinson/pecan"
# path.pecan <- "~/Desktop/Research/pecan"

# Defining a site name -- this can go into a function later
site.name = "WILLOWCREEK"
vers=".v1"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W

GCM.list=c("MIROC-ESM", "MPI-ESM-P", "bcc-csm1-1", "CCSM4")
# GCM.list=c("CCSM4", "MIROC-ESM")
ens=1:10
n.ens=length(ens)
ens.mems=str_pad(ens, 3, "left", pad=0)

# Set up the appropriate seeds to use when adding ensembles
set.seed(1159)
seed.vec <- sample.int(1e6, size=500, replace=F)
seed <- seed.vec[min(ens)] # This makes sure that if we add ensemble members, it gets a new, but reproducible seed

# Setting up some basics for the file structure
out.base <- file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "day")
raw.base <- file.path(wd.base, "data/paleon_sites", site.name)
# -----------------------------------

# -----------------------------------
# Run a loop to do all of the downscaling steps for each GCM and put in 1 place
# -----------------------------------
# Source the functions we need
source(file.path(path.pecan, "modules/data.atmosphere/R", "align_met.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R", "debias_met_regression.R"))


GCM="bcc-csm1-1"
# GCM.list <- GCM.list[1]
# for(GCM in GCM.list){
  # GCM=GCM.list[1]
  ens.ID=GCM
  
  # Set up a file path our our ensemble to work with now
  train.path <- file.path(out.base, "ensembles", GCM)
  dir.create(train.path, recursive=T, showWarnings=F)
  
  # --------------------------
  # 1. Set up ensemble structure; copy LDAS into ensemble directories
  # --------------------------
  # get a list of all the files we're going to have to copy over from LDAS_Day
  files.ldas <- dir(file.path(raw.base, "NLDAS_day"))

  for(i in 1:n.ens){
    # Create a directory for each ensemble member
    path.ens <- file.path(train.path, paste(ens.ID, ens.mems[i], sep="_"))
    dir.create(path.ens, recursive=T, showWarnings=F)
    
    # Copy LDAS in there with the new name
    for(j in 1:length(files.ldas)){
      yr <- strsplit(files.ldas[j], "[.]")[[1]][2]
      name.new <- paste(ens.ID, ens.mems[i], yr, "nc", sep=".")
      cmd.call <- paste("cp", file.path(raw.base, "NLDAS_day", files.ldas[j]), file.path(path.ens, name.new), sep=" ")
      system(cmd.call)
    }
  }
  
  # --------------------------

  # --------------------------
  # 2. Debias CRUNCEP (1 series) using LDAS (1 series)
  #    - save 1901-1979 (until LDAS kicks in)
  # --------------------------
  # 1. Align CRU 6-hourly with LDAS daily
  source.path <- file.path(raw.base, "CRUNCEP")
  
  # We're now pulling an ensemble because we've set up the file paths and copied LDAS over 
  # (even though all ensemble members will be identical here)
  met.out <- align.met(train.path, source.path, yrs.train=NULL, yrs.source=NULL, n.ens=n.ens, seed=201708, pair.mems = FALSE, mems.train=paste(ens.ID, ens.mems, sep="_"))
  
  # Calculate wind speed if it's not already there
  if(!"wind_speed" %in% names(met.out$dat.source)){
    met.out$dat.source$wind_speed <- sqrt(met.out$dat.source$eastward_wind^2 + met.out$dat.source$northward_wind^2)
  }
  
  # 2. Pass the training & source met data into the bias-correction functions; this will get written to the ensemble
  debias.met.regression(train.data=met.out$dat.train, source.data=met.out$dat.source, n.ens=n.ens, vars.debias=NULL, CRUNCEP=TRUE,
                        pair.anoms = TRUE, pair.ens = FALSE, uncert.prop="random", resids = FALSE, seed=seed,
                        outfolder=train.path, 
                        yrs.save=NULL, ens.name=ens.ID, ens.mems=ens.mems, sanity.tries=100,
                        lat.in=site.lat, lon.in=site.lon,
                        save.diagnostics=TRUE, path.diagnostics=file.path(out.base, "bias_correct_qaqc_CRU"),
                        parallel = FALSE, n.cores = NULL, overwrite = TRUE, verbose = FALSE) 
  # --------------------------

  # --------------------------
  # 3. Debias GCM historical runs (1 time series) using CRUNCEP (n.ens series)
  #    - save 1850-1901 (until CRUNCEP kicks in)
  # --------------------------
  # 1. Align GCM daily with our current ensemble
  source.path <- file.path(raw.base, GCM, "historical")
  
  # We're now pulling an ensemble because we've set up the file paths and copied LDAS over 
  # (even though all ensemble members will be identical here)
  # Might want to parse down the years for yrs.train... doing the full time series could maybe throw things off if they don't
  # get the recent warming right
  met.out <- align.met(train.path, source.path, yrs.train=1901:1920, n.ens=n.ens, seed=201708, pair.mems = FALSE, mems.train=paste(ens.ID, ens.mems, sep="_"))
  
  # Calculate wind speed if it's not already there
  if(!"wind_speed" %in% names(met.out$dat.source)){
    met.out$dat.source$wind_speed <- sqrt(met.out$dat.source$eastward_wind^2 + met.out$dat.source$northward_wind^2)
  }
  
  # With MIROC-ESM, running into problem with NAs in 2005, so lets cut it all at 2000
  for(v in names(met.out$dat.source)){
    if(v=="time") next
    met.out$dat.source[[v]] <- matrix(met.out$dat.source[[v]][which(met.out$dat.source$time$Year<=2000),], ncol=ncol(met.out$dat.source[[v]]))
  }
  met.out$dat.source$time <- met.out$dat.source$time[met.out$dat.source$time$Year<=2000,]
  
  # 2. Pass the training & source met data into the bias-correction functions; this will get written to the ensemble
  debias.met.regression(train.data=met.out$dat.train, source.data=met.out$dat.source, n.ens=n.ens, vars.debias=NULL, CRUNCEP=FALSE,
                        pair.anoms = FALSE, pair.ens = FALSE, uncert.prop="random", resids = FALSE, seed=seed,
                        outfolder=train.path, 
                        yrs.save=1850:1900, ens.name=ens.ID, ens.mems=ens.mems, sanity.tries=100,
                        lat.in=site.lat, lon.in=site.lon,
                        save.diagnostics=TRUE, path.diagnostics=file.path(out.base, paste0("bias_correct_qaqc_",GCM,"_hist")),
                        parallel = FALSE, n.cores = NULL, overwrite = TRUE, verbose = FALSE) 
  # --------------------------

  # --------------------------
  # 4. Debias GCM past millennium (1 time series) using GCM Historical (n.ens series)
  #    - save 850-1849 (until GCM historical kicks in)
  # --------------------------
  # 1. Align GCM daily with our current ensemble
  source.path <- file.path(raw.base, GCM, "p1000")
  
  # We're now pulling an ensemble because we've set up the file paths and copied LDAS over 
  # (even though all ensemble members will be identical here)
  # Might want to parse down the years for yrs.train... doing the full time series could maybe throw things off if they don't
  # get the recent warming right
  met.out <- align.met(train.path, source.path, yrs.train=1850:1900, yrs.source=1600:1849, n.ens=n.ens, seed=201708, pair.mems = FALSE, mems.train=paste(ens.ID, ens.mems, sep="_"))
  
  # Calculate wind speed if it's not already there
  if(!"wind_speed" %in% names(met.out$dat.source)){
    met.out$dat.source$wind_speed <- sqrt(met.out$dat.source$eastward_wind^2 + met.out$dat.source$northward_wind^2)
  }
  
  # 2. Pass the training & source met data into the bias-correction functions; this will get written to the ensemble
  debias.met.regression(train.data=met.out$dat.train, source.data=met.out$dat.source, n.ens=n.ens, vars.debias=NULL, CRUNCEP=FALSE,
                        pair.anoms = FALSE, pair.ens = FALSE, uncert.prop="random", resids = FALSE, seed=seed,
                        outfolder=train.path, 
                        yrs.save=NULL, ens.name=ens.ID, ens.mems=ens.mems, sanity.tries=100,
                        lat.in=site.lat, lon.in=site.lon,
                        save.diagnostics=TRUE, path.diagnostics=file.path(out.base, paste0("bias_correct_qaqc_",GCM,"_p1000")),
                        parallel = FALSE, n.cores = NULL, overwrite = TRUE, verbose = FALSE) 
  # --------------------------
  
# }
# -----------------------------------






