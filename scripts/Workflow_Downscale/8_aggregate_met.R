# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: 
# Creator: 
# Contact: crollinson@mortonarb.org
# -----------------------------------
# Description
# -----------------------------------
# 
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 0. Set up file structure, load packages, etc
# 1. 
# -----------------------------------
# rm(list=ls())
library(parallel)
source("aggregate_met.R")
source("aggregate_file.R")

wd.base <- "/home/crollinson/met_ensemble"
site.name = "ROOSTER"
vers=".v1"
site.lat  = 43.2309
site.lon  = -74.5267

in.base = file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "1hr/ensembles/")
out.base = file.path(wd.base, "/data/met_ensembles", paste0(site.name, vers) ,"aggregated")

GCM.list <- dir(in.base)
for(GCM in GCM.list){
  print(GCM)
  gcm.ens <- dir(file.path(in.base, GCM))
  pb <- txtProgressBar(min=0, max=length(gcm.ens), style=3)
  pb.ind=1
  for(ens in gcm.ens){
    aggregate.met(path.in=file.path(in.base, GCM, ens), 
                  years.agg=NULL, save.day=T, save.month=T, 
                  out.base=out.base, day.dir=file.path("day", GCM, ens), mo.dir=file.path("month", GCM, ens), 
                  add.vars=c("daylength", "air_temperature_maximum", "air_temperature_minimum"),
                  parallel=F, n.cores=8, 
                  print.progress=F, verbose=FALSE)
    
    setTxtProgressBar(pb, pb.ind)
    pb.ind=pb.ind+1
  }
  print("")
}
