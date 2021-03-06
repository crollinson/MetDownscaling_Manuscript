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

wd.base <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/"
setwd(wd.base)

dat.base <- file.path(wd.base, "data")
path.pecan <- "~/Desktop/Research/pecan"
# path.pecan <- "~/Desktop/Research/pecan"

# Hard-coding numbers for Harvard
site.name = "WILLOWCREEK"
vers=".v2"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W
# 

path.train <- file.path(wd.base, "data/Raw_Inputs", site.name, "Ameriflux_WCr")
path.lm <- file.path(dat.base, "Downscaled_Outputs", paste0(site.name, vers), "1hr/mods.tdm")
path.in <- file.path(wd.base, "data/Raw_Inputs", site.name)
path.out <- file.path(dat.base, "Downscaled_Outputs", paste0(site.name, vers), "1hr/ensembles/Ameriflux")

ens.hr  <- 30 # Number of hourly ensemble members to create
n.day <- 1 # Number of daily ensemble members to process
# yrs.plot <- c(2015, 1985, 1920, 1875, 1800, 1000, 850)
yrs.plot <- c(1999, 2004, 2009, 2014)
timestep="1hr"
# years.sim=2015:1900
yrs.sim=NULL

# Setting up parallelization
parallel=FALSE
cores.max = 8

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

GCM="NLDAS_downscaled"
# tic()
# Set the directory where the output is & load the file
ens.done <- vector()
path.gcm <- file.path(path.in)

out.ens <- file.path(path.out)

# Doing this one ensemble member at at time
predict_subdaily_met(outfolder=out.ens, in.path=file.path(path.in),
                     in.prefix="Ameriflux_day", lm.models.base=path.lm,
                     path.train=path.train, direction.filter="forward", yrs.predict=yrs.sim,
                     ens.labs = str_pad(1:ens.hr, width=2, pad="0"), resids = FALSE,
                     overwrite = FALSE, seed=seed.vec[length(ens.done)+1], print.progress = TRUE)
# -----------------------------------
