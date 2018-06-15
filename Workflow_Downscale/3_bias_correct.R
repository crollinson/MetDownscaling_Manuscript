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
wd.base <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/"
out.base <- wd.base
setwd(wd.base)

# Setting some important file paths
path.pecan <- "~/Desktop/Research/pecan"

# Defining a site name -- this can go into a function later
site.name = "WILLOWCREEK"
vers=".v2"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W

ens=1:10
n.ens=length(ens)
ens.mems=str_pad(ens, 3, "left", pad=0)

# Set up the appropriate seeds to use when adding ensembles
set.seed(1159)
seed.vec <- sample.int(1e6, size=500, replace=F)
seed <- seed.vec[min(ens)] # This makes sure that if we add ensemble members, it gets a new, but reproducible seed

# Setting up some basics for the file structure
out.base <- file.path(wd.base, "data/Downscaled_Outputs", paste0(site.name, vers), "day")
raw.base <- file.path(wd.base, "data/Raw_Inputs", site.name)

if(!dir.exists(out.base)) dir.create(out.base, recursive=T)
# -----------------------------------

# -----------------------------------
# Run a loop to do all of the downscaling steps for each GCM and put in 1 place
# -----------------------------------
# Source the functions we need
source(file.path(path.pecan, "modules/data.atmosphere/R", "align_met.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R", "debias_met_regression.R"))


  
# --------------------------
# 1. Debias 
# --------------------------
ens.ID="NLDAS_downscaled"

# 1. Align daily aggregated NLDAS with Ameriflux 1 hr
train.path <- file.path(raw.base, "Ameriflux_day")
source.path <- file.path(raw.base, "NLDAS_day")

# We're now pulling an ensemble because we've set up the file paths and copied LDAS over 
# (even though all ensemble members will be identical here)
met.out <- align.met(train.path, source.path, yrs.train=1999:2008, yrs.source=NULL, n.ens=n.ens, seed=201708, pair.mems = FALSE, mems.train=paste(ens.ID, ens.mems, sep="_"))

# Calculate wind speed if it's not already there
# Note: right now only set up to do total windspeed and not north/east components
if(!"wind_speed" %in% names(met.out$dat.source)){
  met.out$dat.source$wind_speed <- sqrt(met.out$dat.source$eastward_wind^2 + met.out$dat.source$northward_wind^2)
}
if(!"wind_speed" %in% names(met.out$dat.train)){
  met.out$dat.train$wind_speed <- sqrt(met.out$dat.train$eastward_wind^2 + met.out$dat.train$northward_wind^2)
}

# 2. Pass the training & source met data into the bias-correction functions; this will get written to the ensemble
debias.met.regression(train.data=met.out$dat.train, source.data=met.out$dat.source, n.ens=10, vars.debias=NULL, CRUNCEP=FALSE,
                      pair.anoms = TRUE, pair.ens = FALSE, uncert.prop="mean", resids = FALSE, seed=Sys.Date(),
                      outfolder=file.path(out.base, "ensembles"), 
                      yrs.save=NULL, ens.name=ens.ID, ens.mems=ens.mems, lat.in=site.lat, lon.in=site.lon,
                      save.diagnostics=TRUE, path.diagnostics=file.path(out.base, "bias_correct_qaqc"),
                      parallel = FALSE, n.cores = NULL, overwrite = TRUE, verbose = FALSE) 
# --------------------------


# -----------------------------------






