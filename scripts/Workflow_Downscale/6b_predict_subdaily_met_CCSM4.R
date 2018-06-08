# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Create statistical models to predict subdaily meteorology from daily means
# Creator: Christy Rollinson, 7 September 2017
# Contact: crollinson@gmail.com
# -----------------------------------

# -----------------------------------
# Description
# -----------------------------------
# Apply the statistical models from step 3 to convert the daily, bias-corrected met 
# files from step 2 (daily means) and predict subdaily values.  This gets done by 
# filtering backwards in time starting with the present (where the trianing data is).
#
# There are ways to improve this and speed it up, but hopefully this works for now.
# We whould also probably think about applying this filter approach to the bias-
# correction step to avoid abrupt and unreasonable jumps in climate.
# -----------------------------------


# -----------------------------------
# Workflow
# -----------------------------------
# 0. Load libraries, set up file paths, etc
# ----- Loop through by ensemble member by year ----------
#    1. Use align.met to match temporal resolution to training data
#    2. Predict subdaily values, filtering backwards in time
#    3. Write annual output into .nc files 
#       - separate file for each year/ensemle member; 
#       - all met vars in one annual file (similar to pecan met structure)
# ----- recycle steps 1 - 3 for all years in file ----------
# -----------------------------------


# -----------------------------------
# 0. Load libraries, set up file paths, etc
# -----------------------------------
# Script to prototype temporal downscaling
library(ncdf4)
library(mgcv)
library(MASS)
library(lubridate)
library(ggplot2)
library(stringr)
library(tictoc)
library(parallel)
# library(tictoc)
rm(list=ls())

wd.base <- "/home/crollinson/met_ensemble/"
# wd.base <- "~/Desktop/Research/PalEON_CR/met_ensemble/"
setwd(wd.base)

dat.base <- file.path(wd.base, "data")
path.pecan <- "/home/crollinson/pecan"

# Hard-coding numbers for Harvard
site.name = "ROOSTER"
vers=".v1"
site.lat  = 43.2309
site.lon  = -74.5267
# 

path.train <- file.path(dat.base, "paleon_sites", site.name, "NLDAS")
path.lm <- file.path(dat.base, "met_ensembles", paste0(site.name, vers), "1hr/mods.tdm")
path.in <- file.path(dat.base, "met_ensembles", paste0(site.name, vers), "day/ensembles")
path.out <- file.path(dat.base, "met_ensembles", paste0(site.name, vers), "1hr/ensembles")

# GCM.list = c("CCSM4", "MIROC-ESM", "MPI-ESM-P", "bcc-csm1-1")
# GCM.list = "MIROC-ESM"
ens.hr  <- 2 # Number of hourly ensemble members to create
n.day <- 10 # Number of daily ensemble members to process
# yrs.plot <- c(2015, 1985, 1920, 1875, 1800, 1000, 850)
yrs.plot <- c(2015, 1985, 1920, 1875, 1600)
timestep="1hr"
# years.sim=2015:1900
yrs.sim=NULL

# Setting up parallelization
parallel=TRUE
cores.max = 10

# Set up the appropriate seed
set.seed(0017)
seed.vec <- sample.int(1e6, size=500, replace=F)
# -----------------------------------

# -----------------------------------
# 2. Apply the model
# -----------------------------------
source(file.path(path.pecan, "modules/data.atmosphere/R", "tdm_predict_subdaily_met.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R", "tdm_lm_ensemble_sims.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R", "align_met.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R", "tdm_subdaily_pred.R"))
# source(file.path(path.pecan, "tdm_predict_subdaily_met.R"))

# Set & create the output directory
if(!dir.exists(path.out)) dir.create(path.out, recursive=T)

GCM="CCSM4"
# for(GCM in GCM.list){
  # GCM="Ameriflux"
  # tic()
  # Set the directory where the output is & load the file
  path.gcm <- file.path(path.in, GCM)
  
  out.ens <- file.path(path.out, GCM)
  
  # Doing this one ensemble member at at time
  # Figure out what's been done already
  ens.done <- str_split(dir(out.ens), "[.]")
  if(length(ens.done)>0) ens.done <- unique(matrix(unlist(ens.done), ncol=length(ens.done[[1]]), byrow = T)[,1])
  
  # Figure out what we can pull from
  gcm.members <- dir(path.gcm)
  if(length(ens.done)>0) gcm.members <- gcm.members[!gcm.members %in% ens.done]
  
  gcm.now <- sample(gcm.members, min(n.day, length(gcm.members)))

  if(parallel==TRUE){
    mclapply(gcm.now, predict_subdaily_met, mc.cores=min(length(gcm.now), cores.max),
             outfolder=out.ens, in.path=file.path(path.in, GCM), 
             lm.models.base=path.lm, path.train=path.train, direction.filter="backward",
             yrs.predict=yrs.sim, ens.labs=str_pad(1:ens.hr, width=2, pad="0"),
             resids=F, force.sanity=TRUE, sanity.attempts=5, overwrite=F,
             seed=seed.vec[length(ens.done)+1], print.progress=F)
  } else {
    for(ens.now in gcm.now){
      predict_subdaily_met(outfolder=out.ens, in.path=file.path(path.in, GCM),
                           in.prefix=ens.now, lm.models.base=path.lm,
                           path.train=path.train, direction.filter="backward", yrs.predict=yrs.sim,
                           ens.labs = str_pad(1:ens.hr, width=2, pad="0"), resids = FALSE, force.sanity=TRUE, sanity.attempts=5,
                           overwrite = FALSE, seed=seed.vec[length(ens.done)+1], print.progress = TRUE)
    }
  }
# }
# -----------------------------------
