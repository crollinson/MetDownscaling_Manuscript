# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Check the daily ensemble for outliers so they don't continue to be considered
# Creator: Christy Rollinson, 15 November 2017
# Contact: crollinson@mortonarb.org
# -----------------------------------
# Description
# -----------------------------------
# Despite the addition of new sanity checks, it's possible for values that are way outside of the rest of the 
# distribution to occur.  If these are clear outliers, life will be easier if we don't continue to keep them in
# our ensemble and pass them into the temporal downscaling workflow
# -----------------------------------
# General Workflow Components
# -----------------------------------
# 1. get list of all GCMs & ensemble members
# 2. set up array so that we can plug values: years x vars x ensemble members
# 3. Find the mean & sd for each var/year
# 4. Identify ensembles who have a min/max outside of mean & 6sd
# 5. move problematic ensemble members to a special folder to remove them from consideration
# -----------------------------------


# -----------------------------------
# 0. Set up file paths, etc.
# -----------------------------------
# Path to the ensemble we want to check
wd.base <- "/home/crollinson/met_ensemble"
site.name = "ROOSTER"
vers=".v1"
site.lat  = 43.2309
site.lon  = -74.5267

path.dat <- file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "1hr/ensembles/")
path.bad <- file.path(wd.base, "data/met_ensembles", paste0(site.name, vers), "1hr/rejected/")

if(!dir.exists(path.bad)) dir.create(path.bad, recursive = T)
# -----------------------------------

# -----------------------------------
# 1. Get list of GCM and ensemble members and set up data array
# -----------------------------------
GCM.list <- dir(path.dat)

ens.mems <- vector()
n.files <- 0
vars.names <- vector()
for(GCM in GCM.list){
  ens.now <- dir(file.path(path.dat, GCM))
  ens.mems <- c(ens.mems, ens.now)
  
  files.now <- dir(file.path(path.dat, GCM, ens.now[1]))
  n.files <- max(n.files, length(files.now))
  
  ncT <- ncdf4::nc_open(file.path(path.dat, GCM, ens.now[1], files.now[1]))
  var.names <- names(ncT$var)
  ncdf4::nc_close(ncT)
}

# Set up a blank array to store everything in
dat.summary <- array(dim=c(n.files, length(var.names), 2, length(ens.mems))) # dim[3] == 2 so we can store min/max
dimnames(dat.summary)[[1]] <- seq(2015, 1600, by=-1)
dimnames(dat.summary)[[2]] <- var.names
dimnames(dat.summary)[[3]] <- c("yr.min", "yr.max")
dimnames(dat.summary)[[4]] <- ens.mems
names(dimnames(dat.summary)) <- c("Year", "Var", "max.min", "ensemble.member")
summary(dimnames(dat.summary))

# Loop through and get the summary stats
pb <- txtProgressBar(min=0, max=dim(dat.summary)[1]*dim(dat.summary)[2]*dim(dat.summary)[4], style=3)
pb.ind=1

for(GCM in 1:length(GCM.list)){
  ens.gcm <- dir(file.path(path.dat, GCM.list[GCM]))
  
  for(ens in 1:length(ens.gcm)){
    ens.ind <- which(ens.mems == ens.gcm[ens])
    
    f.all <- rev(dir(file.path(path.dat, GCM.list[GCM], ens.gcm[ens])))
    
    for(fnow in 1:length(f.all)){
      ncT <- ncdf4::nc_open(file.path(path.dat, GCM.list[GCM], ens.gcm[ens], f.all[fnow]))
      
      for(v in length(var.names):1){
        dat.summary[fnow,v,1,ens.ind] <- min(ncdf4::ncvar_get(ncT, var.names[v]))
        dat.summary[fnow,v,2,ens.ind] <- max(ncdf4::ncvar_get(ncT, var.names[v]))
        
        setTxtProgressBar(pb, pb.ind)
        pb.ind <- pb.ind+1
      }
      
      ncdf4::nc_close(ncT)
    }
  }
}
# -----------------------------------

# -----------------------------------
# Filter and identify outliers
# -----------------------------------
ens.bad <- array(dim=c(n.files, length(ens.mems)))
dimnames(ens.bad)[[1]] <- dimnames(dat.summary)[[1]]
dimnames(ens.bad)[[2]] <- dimnames(dat.summary)[[4]]

sum.means <- apply(dat.summary[,,,], c(1, 2, 3), FUN=mean)
sum.sd    <- apply(dat.summary[,,,], c(1, 2, 3), FUN=sd)


for(i in 1:nrow(ens.bad)){
  for(j in 1:ncol(ens.bad)){
    vars.bad <- dat.summary[i,,1,j] < sum.means[i,,1] - 6*sum.sd[i,,1] | dat.summary[i,,2,j] > sum.means[i,,2] + 6*sum.sd[i,,2]
    if(all(is.na(vars.bad))) next
    if(any(vars.bad)){
      ens.bad[i,j] <- length(which(vars.bad==T))
    }
  }
}

# Summarizing bad ensembles 
yrs.bad <- apply(ens.bad, 1, sum, na.rm=T)
summary(yrs.bad)

mems.bad <- apply(ens.bad, 2, sum, na.rm=T)
length(which(mems.bad==0))/length(mems.bad)
summary(mems.bad)

quantile(mems.bad, 0.90)

# -----------------------------------
# Move the bad ensemble members
# -----------------------------------
mems.bad[mems.bad>0]

for(mem in names(mems.bad[mems.bad>0])){
  GCM <- stringr::str_split(mem, "_")[[1]][1]
  system(paste("mv", file.path(path.dat, GCM, mem), file.path(path.bad, mem), sep=" "))
}

# -----------------------------------
