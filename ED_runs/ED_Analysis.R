path.dat <- "~/Desktop/Research/MetDownscaling_Manuscript/ED_runs/4_runs/extracted_output/"
dat.all <- data.frame()
for(yr in 2000:2014){
  # Open connection to file
  ncT <- ncdf4::nc_open(file.path(path.dat, paste("ED2", yr, "nc", sep=".")))
	
  # Extract data into temporary data frame
	dat.nc <- data.frame(year=yr, 
	                     doy=rep(1:ifelse(lubridate::leap_year(yr), 366, 365), each=24),
	                     hour=1:24,
	                     tair=ncdf4::ncvar_get(ncT, "Tair"),
	                     swdown=ncdf4::ncvar_get(ncT, "SWdown"),
	                     precip=ncdf4::ncvar_get(ncT, "Rainf"),
	                     GPP=ncdf4::ncvar_get(ncT, "GPP"),
	                     NPP=ncdf4::ncvar_get(ncT, "NPP"),
	                     NEE=ncdf4::ncvar_get(ncT, "NEE"),  
	                     AbvGrndWood=ncdf4::ncvar_get(ncT, "AbvGrndWood"),
	                     SoilMoist.30 = apply(ncdf4::ncvar_get(ncT, "SoilMoist")[5:8,], 2, mean))
	
	# Close connection to file
	ncdf4::nc_close(ncT)
	
	# Add temporary data to the total dataset
	dat.all <- rbind(dat.all, dat.nc)
	
}
summary(dat.all)


plot(dat.all[dat.all$year==2007 & dat.all$doy>=180 & dat.all$doy<=181, "tair"], type="l"); abline(v=25, col="red")
plot(dat.all[dat.all$year==2007 & dat.all$doy>=180 & dat.all$doy<=181, "swdown"], type="l"); abline(v=25, col="red")
plot(dat.all[dat.all$year==2007 & dat.all$doy>=180 & dat.all$doy<=181, "precip"], type="l"); abline(v=25, col="red")
plot(dat.all[dat.all$year==2007 & dat.all$doy>=180 & dat.all$doy<=181, "NEE"], type="l"); abline(v=25, col="red")
plot(dat.all[dat.all$year==2007 & dat.all$doy>=180 & dat.all$doy<=181, "NPP"], type="l"); abline(v=25, col="red")
plot(dat.all[dat.all$year==2007 & dat.all$doy>=180 & dat.all$doy<=181, "GPP"], type="l"); abline(v=25, col="red")
