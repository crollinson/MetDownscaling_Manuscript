#Process netCDF PalEON met files into HDF5 files for ED2:
#
#This works with files in the regional met driver rasters that can then be run site-by-site
#It loads the netCDF file, formats the data into HDF5 format, and renames variables and the date 
#to be in the ED2 HDF5 format with the correct dimensions.  
#
#It requires the rhdf5 library, which is not available on CRAN, but by can be installed locally:
#source("http://bioconductor.org/biocLite.R")
#biocLite("rhdf5")
#
#on GEO CLUSTER (local install of rhdf5): 
#install.packages("/usr4/spclpgm/jmatthes/zlibbioc_1.6.0.tar.gz",repos=NULL,type="source",lib="/usr4/spclpgm/jmatthes/")
#install.packages("/usr4/spclpgm/jmatthes/rhdf5_2.4.0.tar.gz",repos=NULL,type="source",lib="/usr4/spclpgm/jmatthes/")
#
#Original (Sites): Jaclyn Hatala Matthes, 1/7/14, jaclyn.hatala.matthes@gmail.com
#Edits (Sites): Christy Rollinson, January 2015, crollinson@gmail.com
#Edits (Region): Christy Rollinson, 2 December 2015, crollinson@gmail.com

library(ncdf4)
library(rhdf5)
library(abind)

# in.path  <- "/home/crollinson/MetDownscaling_Manuscript/data/raw_met/NLDAS"
in.path <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/data/Raw_Inputs/WILLOWCREEK/NLDAS/"
out.path <- "/home/models/ED_MET/WILLOWCREEK/NLDAS/NLDAS_raw"
dir.create(file.path(out.path), showWarnings = FALSE)

orig.vars <- c("lwdown", "precipf", "psurf", "qair", "swdown", "tair", "wind")
ed2.vars  <- c( "dlwrf",   "prate",  "pres",   "sh",  "vbdsf",  "tmp", "ugrd")
month.txt <- c("JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC")
vars.stat <- c("hgt", "vddsf", "nbdsf", "nddsf")


for(v in 1:length(orig.vars)){
  print(orig.vars[v])    
  var.path <- file.path(in.path,orig.vars[v])
  in.files <- list.files(var.path)
  dir.create(file.path(out.path,ed2.vars[v]), showWarnings = FALSE)
  
  for(f in 1:length(in.files)){
    
    #open and read netcdf file
    nc.file <- nc_open(file.path(var.path,in.files[f]))
    var     <- ncvar_get(nc.file,orig.vars[v])
    time    <- ncvar_get(nc.file,"time")
    lat     <- ncvar_get(nc.file,"lat")
    lon     <- ncvar_get(nc.file,"lon")
    nc_close(nc.file)
    
    # var <- array(var,dim=dim(var))                   
    # var2 <- array(dim=c(dim(var)[3],dim(var)[2],dim(var)[1]))                   
    var2 <- array(dim=c(dim(var)[3],dim(var)[1],dim(var)[2]))                   
    
    for(i in 1:dim(var)[3]){
      var2[i,,] <- (var[,dim(var)[2]:1,i])
    }   	  
    
    # Get rid of NAs
    var2[is.na(var2)] <- 0
    
    #process year and month for naming
    filesplit <- strsplit(in.files[f],"_")
    year  <- as.numeric(filesplit[[1]][2])+1000 ###CAREFUL - I HAD TO ADD 1000 FOR PALEON
    monthsplit <- strsplit(filesplit[[1]][3],".nc")
    month <- monthsplit[[1]]
    month.num <- as.numeric(month)
    
    #write HDF5 file
    out.file <- paste(out.path,"/",ed2.vars[v],"/",ed2.vars[v],"_",year,month.txt[month.num],".h5",sep="")
    h5createFile(out.file)
    h5write(var2,out.file,ed2.vars[v])
    h5write(time,out.file,"time")
    h5write(lon,out.file,"lon")
    h5write(lat[order(lat, decreasing=T)],out.file,"lat")
    # H5Fclose(out.file) # don't need this because of how we created & wrote the files
    
  }
}


# Tacking on CO2 -- copying onto a blank tair
co2.file <- "/home/crollinson/ED_PalEON/phase2_env_drivers_v2/co2/paleon_monthly_co2.nc"
co2.in <- nc_open(co2.file)
co2.mo <- ncvar_get(co2.in, "co2")
nc_close(co2.in)


print("CO2")    
dir.create(file.path(out.path,"co2"), showWarnings = FALSE)
var.path <- file.path(in.path,"tair")
in.files <- list.files(var.path)

for(f in 1:(20*12)){
  
  #open and read netcdf file
  nc.file <- nc_open(file.path(var.path,in.files[f]))
  var     <- ncvar_get(nc.file,"tair")
  time    <- ncvar_get(nc.file,"time")
  lat     <- ncvar_get(nc.file,"lat")
  lon     <- ncvar_get(nc.file,"lon")
  nc_close(nc.file)
  
  # Overwriting the tair data with co2 in ALL cells
  # i.e. constant co2 across space and time for that month
  # var2 <- array(dim=c(dim(var)[3],dim(var)[2],dim(var)[1]))                   
  var2 <- array(dim=c(dim(var)[3],dim(var)[1],dim(var)[2]))                   
  var2[,,] <- co2.mo[f]
  
  #process year and month for naming
  filesplit <- strsplit(in.files[f],"_")
  year  <- as.numeric(filesplit[[1]][2])+1000 ###CAREFUL - I HAD TO ADD 1000 FOR PALEON
  monthsplit <- strsplit(filesplit[[1]][3],".nc")
  month <- monthsplit[[1]]
  month.num <- as.numeric(month)
  
  #write HDF5 file
  out.file <- paste(out.path,"/","co2","/","co2","_",year,month.txt[month.num],".h5",sep="")
  h5createFile(out.file)
  h5write(var2,out.file,"co2")
  h5write(time,out.file,"time")
  h5write(lon,out.file,"lon")
  h5write(lat[order(lat, decreasing=T)],out.file,"lat")
  # H5Fclose(out.file) # don't need this because of how we created & wrote the files
}

