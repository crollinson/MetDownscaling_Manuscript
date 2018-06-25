#-------------------------------------------------------------------------------
# Copyright (c) 2012 University of Illinois, NCSA.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the
# University of Illinois/NCSA Open Source License
# which accompanies this distribution, and is available at
# http://opensource.ncsa.illinois.edu/license.html
#-------------------------------------------------------------------------------


##' Modified from Code to convert ED2.1's HDF5 output into the NACP Intercomparison format (ALMA using netCDF)
##'
##' @name model2netcdf.ED2
##' @title Code to convert ED2's -I- HDF5 output into netCDF format
##'
##' @param ed.dir Location of ED model output
##' @param outdir Location of extracted & syntehsized output
##' @param sitelat Latitude of the site
##' @param sitelon Longitude of the site
##' @param start_date Start time of the simulation
##' @param end_date End time of the simulation
##' @param pft_names Names of PFTs used in the run, vector
##' @param ed.freq Frequency of files to be analyzed:
##'                I = instaneous (set in ED2IN), 
##'                E = monthly means,
##'                Y = annual means
##'                
##' @export
##'
##' @author Michael Dietze, Shawn Serbin, Rob Kooper, Toni Viskari, Istem Fer
## modified M. Dietze 07/08/12 modified S. Serbin 05/06/13
## refactored by Istem Fer on 03/2018
model2netcdf.ED2.MetDownscaling <- function(ed.dir, outdir, sitelat, sitelon, start_date, end_date, pft_names = NULL, ed.freq=c("I", "E", "Y")) {
  
  start_year <- lubridate::year(start_date)
  end_year   <- lubridate::year(end_date) 
  
  flist <- list()
  for(FREQ in ed.freq){
    flist[[FREQ]] <- dir(ed.dir, paste0("-", FREQ, "-"))
  }
  # flist[["-I-"]] <- dir(outdir, "-I-") # tower files
  # flist[["-E-"]] <- dir(outdir, "-E-") # monthly files
  
  # check if there are files
  file.check <- sapply(flist, function (f) length(f) != 0)
  
  if (!any(file.check)) {
    
    # no output files
    stop("WARNING: No output files found for :", outdir)
    return(NULL)
    
  }else{ 
    
    # which output files are there
    ed.res.flag <- names(flist)[file.check]
    
    # extract year info from the file names
    ylist <-lapply(ed.res.flag, function(f) {
      yr <- rep(NA, length(flist[[f]]))
      for (i in seq_along(flist[[f]])) {
        index <- gregexpr(f, flist[[f]][i])[[1]] # Find where our time stamp flag is
        index <- index[1]
        yr[i] <- as.numeric(substr(flist[[f]][i], index + 2, index + 5)) # The year starts 2 characters after our timestamp
      }
      return(yr)
    })
    
    names(ylist) <- ed.res.flag
  }
  
  # prepare list to collect outputs
  out_list <- vector("list", length(ed.res.flag)) 
  names(out_list) <- ed.res.flag
  
  # if run failed there might be less years, no output case is handled above
  # we can process whatever is there
  # but of course this upsets ensemble.ts because the outputs are not of same length now
  # two options:
  # (i)  don't process anything
  #      return(NULL)
  # (ii) check whether this is an ensemble run, then return null, otherwise process whatever there is
  #      for now I'm going with this, do failed runs also provide information on parameters?
  year.check <- unique(unlist(ylist))
  if(max(year.check) < end_year){
    stop("Run failed with some outputs.")
    # rundir <- gsub("/out/", "/run/", outdir)
    # readme <- file(paste0(rundir,"/README.txt"))
    # runtype <- readLines(readme, n=1)
    # close(readme)
    # if(grepl("ensemble", runtype)){
    #    PEcAn.logger::logger.info("This is an ensemble run. Not processing anything.")
    #    return(NULL)
    # }else{
    #   PEcAn.logger::logger.info("This is not an ensemble run. Processing existing outputs.")
    #    end_year <- max(year.check)
    # }
  }
  
  # ----- start loop over years
  for(y in start_year:end_year){
    
    print(paste0("----- Processing year: ", y))
    
    # ----- read values from ED output files
    for(j in seq_along(out_list)){
      rflag <- ed.res.flag[j]
      fcnx  <- paste0("read_", gsub("-", "", rflag), "_files")
      fcn   <- match.fun(fcnx)
      out_list[[rflag]] <- fcn(yr = y, yfiles=ylist[[rflag]], tfiles=flist[[rflag]], 
                               outdir=ed.dir, start_date=start_date, end_date=end_date, 
                               pft_names)
    }
    
    
    if (y == strftime(start_date, "%Y")) {
      begins <- as.numeric(strftime(start_date, "%j")) - 1
    } else {
      begins <- 0
    }
    
    if (y == strftime(end_date, "%Y")) {
      ends <- as.numeric(strftime(end_date, "%j"))
    } else {
      ends <- as.numeric(strftime(paste0(y, "-12-31"), "%j")) 
    }
    
    lat <- ncdf4::ncdim_def("lat", "degrees_north", vals = as.numeric(sitelat), longname = "station_latitude")
    lon <- ncdf4::ncdim_def("lon", "degrees_east",  vals = as.numeric(sitelon), longname = "station_longitude")
    
    # ----- put values to nc_var list   
    nc_var <- list()
    for(j in seq_along(out_list)){
      rflag   <- ed.res.flag[j]
      fcnx    <- paste0("put_", gsub("-", "", rflag), "_values")
      fcn     <- match.fun(fcnx)
      put_out <- fcn(yr = y, nc_var = nc_var, out = out_list[[rflag]], lat = lat, lon = lon, 
                     begins = begins, ends = ends, pft_names)
      
      nc_var            <- put_out$nc_var
      out_list[[rflag]] <- put_out$out
    }
    
    # SLZ specific hack until I figure that out
    if(!is.null(out_list[["-I-"]]$SLZ)){
      out_list[["-I-"]]$SLZ <- NULL
    }
    
    # ----- write ncdf files
    
    print("*** Writing netCDF file ***")
    
    out <- unlist(out_list, recursive = FALSE)
    nc <- ncdf4::nc_create(file.path(outdir, paste("ED2", y, "nc", sep = ".")), nc_var)
    varfile <- file(file.path(outdir, paste(y, "nc", "var", sep = ".")), "w")
    for (i in seq_along(nc_var)) {
      ncdf4::ncvar_put(nc, nc_var[[i]], out[[i]])
      cat(paste(nc_var[[i]]$name, nc_var[[i]]$longname), file = varfile, sep = "\n")
    }
    close(varfile)
    ncdf4::nc_close(nc)
    
  } # end year-loop
  
  
} # model2netcdf.ED2
##-------------------------------------------------------------------------------------------------#

##-------------------------------------------------------------------------------------------------#

##' Function for reading -I- files
##'
##' @details
##'  e.g.    yr = 1999
##'      yfiles = 1999 2000
##'      tfiles = "analysis-I-1999-00-00-000000-g01.h5" "analysis-I-2000-00-00-000000-g01.h5"
##'
##' @param yr the year being processed
##' @param yfiles the years on the filenames, will be used to matched tfiles for that year
##' @export
read_I_files <- function(yr, yfiles, tfiles, outdir, start_date, end_date, ...){
  
  print(paste0("*** Reading -I- file ***"))
  
  # add
  add <- function(dat, col) {
    
    dims <- dim(dat)
    
    if (is.null(dims)) {
      if (length(dat) == 1) {
        if (length(out) < col) {
          out[[col]] <- array(dat, dim = 1)
        } else {
          out[[col]] <- abind::abind(out[[col]], array(dat, dim = 1), along = 1)
        }
      } else {
        warning("expected a single value")
      }
    } else if(length(dims)==1){
      if(length(out) < col){
        out[[col]] <- array(dat)
      } else {
        out[[col]] <- cbind(out[[col]], array(dat))
      }
    } else if (length(dims)==2) {
      dat <- t(dat)
      dims <- dim(dat)
      # dat <- dat[1:(nrow(dat)), ]
      if (length(out) < col) {
        out[[col]] <- dat
      } else {
        out[[col]] <- abind::abind(out[[col]], dat, along = 1)
      }
    } else {
      stop("can't handle arrays with >2 dimensions yet")
    }
    return(out)
  
    ## finally make sure we use -999 for invalid values
    out[[col]][is.null(out[[col]])] <- -999
    out[[col]][is.na(out[[col]])] <- -999
    
    return(out)
  } # end add-function
  
  
  getHdf5Data <- function(nc, var) {
    if (var %in% names(nc$var)) {
      return(ncdf4::ncvar_get(nc, var))
    } else {
      warning("Could not find", var, "in ed hdf5 output.")
      return(-999)
    }
  }
  
  CheckED2Version <- function(nc) {
    if ("FMEAN_BDEAD_PY" %in% names(nc$var)) {
      return("Git")
    }
  }
  
  # note that there is always one Iower file per year
  ysel <- which(yr == yfiles)
  
  if (yr < strftime(start_date, "%Y")) {
    warning(yr, "<", strftime(start_date, "%Y"))
    next
  }
  
  if (yr > strftime(end_date, "%Y")) {
    warning(yr, ">", strftime(end_date, "%Y"))
    next
  }
  
  n <- length(ysel)
  out <- list()
  row <- 1
    
  # note that there is always one Tower file per year
  ## ## NEED TO SET THIS UP TO LOOP THROUGH YSEL!
  pb <- txtProgressBar(min=0, max=length(ysel), style=3)
  for(i in seq_along(ysel)){
    setTxtProgressBar(pb, i)
    ncT <- ncdf4::nc_open(file.path(outdir, tfiles[ysel[i]]))
    
    ## determine timestep from HDF5 file
    # block <- 60*60 # We presecribed 1 hour
    block <- ncT$dim$phony_dim_0$len
    dat.blank <- array(rep(-999, block)) # This is a little different from Pecan, but makes sure everything has same dims
    
    # block = 86400/(60*60)
    # PEcAn.logger::logger.info(paste0("Output interval: ", 86400/block, " sec"))
    
    
    if ("SLZ" %in% names(ncT$var)) {
      slzdata <- getHdf5Data(ncT, "SLZ")[,1]
    } else {
      warning("Could not find SLZ in Y file, making a crude assumpution.")
      slzdata <- array(c(-2, -1.5, -1, -0.8, -0.6, -0.4, -0.2, -0.1, -0.05))
    }
    
    ## Check for which version of ED2 we are using.
    ED2vc <- CheckED2Version(ncT)
    
    ## store for later use, will only use last data
    dz <- diff(slzdata)
    dz <- dz[dz != 0]
    
    if (!is.null(ED2vc)) {
      ## out <- add(getHdf5Data(ncT, 'TOTAL_AGB,1,row, yr) ## AbvGrndWood
      out <- add(getHdf5Data(ncT, "FMEAN_BDEAD_PY"), 1)  ## AbvGrndWood
      out <- add(getHdf5Data(ncT, "FMEAN_PLRESP_PY"), 2)  ## AutoResp
      out <- add(dat.blank, 3)  ## CarbPools
      out <- add(getHdf5Data(ncT, "FMEAN_CAN_CO2_PY"), 4)  ## CO2CAS
      out <- add(dat.blank, 5)  ## CropYield
      out <- add(getHdf5Data(ncT, "FMEAN_GPP_PY"), 6)  ## GPP
      out <- add(getHdf5Data(ncT, "FMEAN_RH_PY"), 7)  ## HeteroResp
      out <- add(-getHdf5Data(ncT, "FMEAN_GPP_PY") + getHdf5Data(ncT, "FMEAN_PLRESP_PY") + 
                                    getHdf5Data(ncT, "FMEAN_RH_PY"), 8)  ## NEE
      out <- add(getHdf5Data(ncT, "FMEAN_GPP_PY") - getHdf5Data(ncT, "FMEAN_PLRESP_PY"), 9)  ## NPP
      out <- add(getHdf5Data(ncT, "FMEAN_RH_PY") + getHdf5Data(ncT, "FMEAN_PLRESP_PY"), 10)  ## TotalResp
      # out <- add(getHdf5Data(ncT, 'BDEAD + getHdf5Data(ncT, 'BALIVE'),11,row, yr) ## TotLivBiom
      out <- add(dat.blank, 11)  ## TotLivBiom
      out <- add(getHdf5Data(ncT, "FAST_SOIL_C_PY") + getHdf5Data(ncT, "STRUCT_SOIL_C_PY") + 
                                    getHdf5Data(ncT, "SLOW_SOIL_C_PY"), 12)  ## TotSoilCarb
      
      ## depth from surface to frozen layer
      tdepth <- 0
      fdepth <- 0
      soiltemp <- getHdf5Data(ncT, "FMEAN_SOIL_TEMP_PY")
      if (length(dim(soiltemp)) == 3) {
        fdepth <- array(0, dim = dim(soiltemp)[1:2])
        tdepth <- array(0, dim = dim(soiltemp)[1:2])
        for (t in 1:dim(soiltemp)[1]) { # time
          for (p in 1:dim(soiltemp)[2]) { # polygon
            for (i in dim(soiltemp)[3]:2) { # depth
              if (fdepth[t, p] == 0 & soiltemp[t, p, i] < 273.15 & 
                  soiltemp[t, p, i - 1] > 273.13) {
                fdepth[t, p] <- i
              }
              if (tdepth[t, p] == 0 & soiltemp[t, p, i] > 273.15 & 
                  soiltemp[t, p, i - 1] < 273.13) {
                tdepth[t, p] <- i
              }
            }
            SLZ <- c(slzdata[t, ], 0)
            z1 <- (SLZ[fdepth[t, p] + 1] + SLZ[fdepth[t, p]]) / 2
            z2 <- (SLZ[fdepth[t, p]] + SLZ[fdepth[t, p] - 1]) / 2
            if (fdepth[t, p] > 0) {
              fdepth[t, p] <- z1 + (z2 - z1) * (273.15 - soiltemp[t, p, fdepth[t, p]]) / 
                (soiltemp[t, p, fdepth[t, p] - 1] - soiltemp[t, p, fdepth[t, p]])
            }
            if (tdepth[t, p] > 0) {
              SLZ <- c(slzdata[t, ], 0)
              z1 <- (SLZ[tdepth[t, p] + 1] + SLZ[tdepth[t, p]]) / 2
              z2 <- (SLZ[tdepth[t, p]] + SLZ[tdepth[t, p] - 1]) / 2
              tdepth[t, p] <- z1 + (z2 - z1) * (273.15 - soiltemp[t, p, tdepth[t, p]]) / 
                (soiltemp[t, p, tdepth[t, p] - 1] - soiltemp[t, p, tdepth[t, p]])
            }
          }
        }
      } else {
        # no polygons, just time vs depth
        fdepth <- array(0, ncol(soiltemp))
        tdepth <- array(0, ncol(soiltemp))
        for (t in 1:ncol(soiltemp)) { # time
          for (d in 2:nrow(soiltemp)) { # depth
            if (fdepth[t] == 0 & soiltemp[d, t] < 273.15 & soiltemp[d - 1, t] > 273.13) {
              fdepth[t] <- d
            }
            if (tdepth[t] == 0 & soiltemp[d, t] > 273.15 & soiltemp[d - 1, t] < 273.13) {
              tdepth[t] <- d
            }
          }
          if (fdepth[t] > 0) {
            SLZ <- c(slzdata, 0)
            z1 <- (SLZ[fdepth[t] + 1] + SLZ[fdepth[t]]) / 2
            z2 <- (SLZ[fdepth[t]] + SLZ[fdepth[t] - 1]) / 2
            fdepth[t] <- z1 + (z2 - z1) * (273.15 - soiltemp[fdepth[t], t]) / 
              (soiltemp[fdepth[t] - 1, t] - soiltemp[fdepth[t], t])
          }
          if (tdepth[t] > 0) {
            SLZ <- c(slzdata, 0)
            z1 <- (SLZ[tdepth[t] + 1] + SLZ[tdepth[t]]) / 2
            z2 <- (SLZ[tdepth[t]] + SLZ[tdepth[t] - 1]) / 2
            tdepth[t] <- z1 + (z2 - z1) * (273.15 - soiltemp[tdepth[t], t]) / 
              (soiltemp[tdepth[t] - 1, t] - soiltemp[tdepth[t], t])
          }
        }
      }
      
      out <- add(fdepth, 13)  ## Fdepth
      out <- add(getHdf5Data(ncT, "FMEAN_SFCW_DEPTH_PY"), 14)  ## SnowDepth (ED2 currently groups snow in to surface water)
      out <- add(1 - getHdf5Data(ncT, "FMEAN_SFCW_FLIQ_PY"), 15)  ## SnowFrac (ED2 currently groups snow in to surface water)
      out <- add(tdepth, 16)  ## Tdepth
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_CO2_PY"), 17)  ## CO2air
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_RLONG_PY"), 18)  ## Lwdown
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_PRSS_PY"), 19)  ## Psurf
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_SHV_PY"), 20)  ## Qair
      out <- add(getHdf5Data(ncT, "FMEAN_PCPG_PY"), 21)  ## Rainf
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_PAR_PY"), 22)  ## Swdown
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_TEMP_PY"), 23)  ## Tair
      out <- add(getHdf5Data(ncT, "FMEAN_ATM_VELS_PY"), 24)  ## Wind
      out <- add(getHdf5Data(ncT, 'FMEAN_ATM_RLONG_PY')-getHdf5Data(ncT, 'FMEAN_RLONGUP_PY'), 25) ## Lwnet
      # out <- add(apply(getHdf5Data(ncT, 'FMEAN_SENSIBLE_GG_PY'),2,sum) + getHdf5Data(ncT,'FMEAN_VAPOR_GC_PY')*2272000, 26) ## Qg
      out <- add(dat.blank, 26)  ## Qg
      out <- add(getHdf5Data(ncT, "FMEAN_SENSIBLE_AC_PY"), 27)  ## Qh
      out <- add(getHdf5Data(ncT, "FMEAN_VAPOR_LC_PY") + getHdf5Data(ncT, "FMEAN_VAPOR_WC_PY") +
                                    getHdf5Data(ncT, "FMEAN_VAPOR_GC_PY") + getHdf5Data(ncT, "FMEAN_TRANSP_PY"), 28)  ## Qle
      out <- add(dat.blank, 29)  ## Swnet
      out <- add(dat.blank, 30)  ## RootMoist
      out <- add(getHdf5Data(ncT, "FMEAN_TRANSP_PY"), 31)  ## Tveg
      out <- add(getHdf5Data(ncT, "ZBAR"), 32)  ## WaterTableD
      out <- add(dat.blank, 33)  ## fPAR
      
      # code changes proposed by MCD, tested by SPS 20160607
      laidata <- getHdf5Data(ncT, "LAI_PY")
      if (length(dim(laidata)) == 3) {
        laidata <- apply(laidata, 3, sum)
        out <- add(array(laidata, dim = length(laidata)), 34)
      } else {
        out <- add(dat.blank, 34)
      }
      
      ##fliq <- sum(getHdf5Data(ncT, 'AVG_SOIL_FRACLIQ')*dz)/-min(z)
      fliq <- NA  #getHdf5Data(ncT, 'FMEAN_SFCW_FLIQ_PY')
      # out <- add(1 - fliq, 35)  ## SMFrozFrac
      # out <- add(fliq, 36)  ## SMLiqFrac
      out <- add(dat.blank, 35)  ## SMFrozFrac
      out <- add(dat.blank, 36)  ## SMLiqFrac
      ## This needs to be soil wetness, i.e. multilple levels deep
      out <- add(getHdf5Data(ncT, "FMEAN_SOIL_WATER_PY"), 37)  ## SoilWater  **********
      ## out <- add(sum(soiltemp*dz)/-min(z),38) ## SoilTemp
      out <- add(soiltemp, 38)  ## SoilTemp
      out <- add(dat.blank, 39)  ## SoilWet
      out <- add(getHdf5Data(ncT, "FMEAN_ALBEDO_PY"), 40)  ## Albedo
      out <- add(getHdf5Data(ncT, "FMEAN_SFCW_TEMP_PY"), 41)  ## SnowT (ED2 currently groups snow in to surface water)
      out <- add(getHdf5Data(ncT, "FMEAN_SFCW_MASS_PY"), 42)  ## SWE (ED2 currently groups snow in to surface water)
      out <- add(getHdf5Data(ncT, "FMEAN_LEAF_TEMP_PY"), 43)  ## VegT
      out <- add(getHdf5Data(ncT, "FMEAN_VAPOR_LC_PY") + getHdf5Data(ncT, "FMEAN_VAPOR_WC_PY") + 
                             getHdf5Data(ncT, "FMEAN_VAPOR_GC_PY") + getHdf5Data(ncT, "FMEAN_TRANSP_PY"), 44)  ## Evap
      out <- add(getHdf5Data(ncT, "FMEAN_QRUNOFF_PY"), 45)  ## Qs
      out <- add(getHdf5Data(ncT, "BASEFLOW"), 46)  ## Qsb
      
      out <- add(getHdf5Data(ncT, "FMEAN_ROOT_RESP_PY") + getHdf5Data(ncT, "FMEAN_ROOT_GROWTH_RESP_PY") + 
                                 getHdf5Data(ncT, "FMEAN_RH_PY"), 47)  ## SoilResp
      out$SLZ <- slzdata
      
    }
    
    ncdf4::nc_close(ncT)
    
  }
  
  return(out)
  
} # read_I_files


##-------------------------------------------------------------------------------------------------#

##' Function for put -I- values to nc_var list
##' @export
put_I_values <- function(yr, nc_var, out, lat, lon, begins, ends, ...){
  
  s <- length(nc_var)
  
  ## Conversion factor for umol C -> kg C
  Mc <- 12.017  #molar mass of C, g/mol
  umol2kg_C <- Mc * udunits2::ud.convert(1, "umol", "mol") * udunits2::ud.convert(1, "g", "kg")
  yr2s      <- udunits2::ud.convert(1, "s", "yr")
  
  # TODO - remove this function and replace with ifelse statements inline below (SPS)
  conversion <- function(col, mult) {
    ## make sure only to convert those values that are not -999
    out[[col]][out[[col]] != -999] <- out[[col]][out[[col]] != -999] * mult
    return(out)
  }
  
  checkTemp <- function(col) {
    out[[col]][out[[col]] == 0] <- -999
    return(out)
  }
  
  
  # ----- define ncdf dimensions
  
  t <- ncdf4::ncdim_def(name = "time", units = paste0("days since ", yr, "-01-01 00:00:00"), 
                        vals = seq(begins, ends, length.out = length(out[[1]])), 
                        calendar = "standard", unlim = TRUE)
  
  
  slzdata <- out$SLZ
  dz <- diff(slzdata)
  dz <- dz[dz != 0]
  
  zg <- ncdf4::ncdim_def("SoilLayerMidpoint", "meters", c(slzdata[1:length(dz)] + dz/2, 0))
  
  dims  <- list(lon = lon, lat = lat, time = t)
  dimsz <- list(lon = lon, lat = lat, time = t, nsoil = zg)
  
  # ----- fill list
  
  out <- conversion(1, udunits2::ud.convert(1, "t ha-1", "kg m-2"))  ## tC/ha -> kg/m2
  nc_var[[s+1]] <- ncdf4::ncvar_def("AbvGrndWood", units = "kg C m-2", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Above ground woody biomass")
  out <- conversion(2, umol2kg_C)  ## umol/m2 s-1 -> kg/m2 s-1
  nc_var[[s+2]] <- ncdf4::ncvar_def("AutoResp", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Autotrophic Respiration")
  nc_var[[s+3]] <- ncdf4::ncvar_def("CarbPools", units = "kg C m-2", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Size of each carbon pool")
  nc_var[[s+4]] <- ncdf4::ncvar_def("CO2CAS", units = "ppmv", dim = list(lon, lat, t), missval = -999, 
                                    longname = "CO2CAS")
  nc_var[[s+5]] <- ncdf4::ncvar_def("CropYield", units = "kg m-2", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Crop Yield")
  out <- conversion(6, yr2s)  ## kg C m-2 yr-1 -> kg C m-2 s-1
  nc_var[[s+6]] <- ncdf4::ncvar_def("GPP", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Gross Primary Productivity")
  out <- conversion(7, yr2s)  ## kg C m-2 yr-1 -> kg C m-2 s-1
  nc_var[[s+7]] <- ncdf4::ncvar_def("HeteroResp", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Heterotrophic Respiration")
  out <- conversion(8, yr2s)  ## kg C m-2 yr-1 -> kg C m-2 s-1
  nc_var[[s+8]] <-  ncdf4::ncvar_def("NEE", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Net Ecosystem Exchange")
  out <- conversion(9, yr2s)  ## kg C m-2 yr-1 -> kg C m-2 s-1
  nc_var[[s+9]] <- ncdf4::ncvar_def("NPP", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Net Primary Productivity")
  out <- conversion(10, yr2s)  ## kg C m-2 yr-1 -> kg C m-2 s-1
  nc_var[[s+10]] <- ncdf4::ncvar_def("TotalResp", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Total Respiration")
  nc_var[[s+11]] <- ncdf4::ncvar_def("TotLivBiom", units = "kg C m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Total living biomass")
  nc_var[[s+12]] <- ncdf4::ncvar_def("TotSoilCarb", units = "kg C m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Total Soil Carbon")
  nc_var[[s+13]] <- ncdf4::ncvar_def("Fdepth", units = "m", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Frozen Thickness")
  nc_var[[s+14]] <- ncdf4::ncvar_def("SnowDepth", units = "m", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Total snow depth")
  nc_var[[s+15]] <- mstmipvar("SnowFrac", lat, lon, t, zg) # not standard
  nc_var[[s+16]] <- ncdf4::ncvar_def("Tdepth", units = "m", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Active Layer Thickness")
  nc_var[[s+17]] <- ncdf4::ncvar_def("CO2air", units = "umol mol-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Near surface CO2 concentration")
  nc_var[[s+18]] <- ncdf4::ncvar_def("LWdown", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Surface incident longwave radiation")
  nc_var[[s+19]] <- ncdf4::ncvar_def("Psurf", units = "Pa", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Surface pressure")
  nc_var[[s+20]] <- ncdf4::ncvar_def("Qair", units = "kg kg-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Near surface specific humidity")
  nc_var[[s+21]] <- ncdf4::ncvar_def("Rainf", units = "kg m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Rainfall rate")
  nc_var[[s+22]] <- ncdf4::ncvar_def("SWdown", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Surface incident shortwave radiation")
  out <- checkTemp(23)
  nc_var[[s+23]] <- ncdf4::ncvar_def("Tair", units = "K", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Near surface air temperature")
  nc_var[[s+24]] <- ncdf4::ncvar_def("Wind", units = "m s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Near surface module of the wind")
  nc_var[[s+25]] <- ncdf4::ncvar_def("LWnet", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Net Longwave Radiation")
  nc_var[[s+26]] <- ncdf4::ncvar_def("Qg", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Ground heat")
  nc_var[[s+27]] <- ncdf4::ncvar_def("Qh", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Sensible heat")
  out <- conversion(28, get.lv())  ## kg m-2 s-1 -> W m-2
  nc_var[[s+28]] <- ncdf4::ncvar_def("Qle", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Latent heat")
  nc_var[[s+29]] <- ncdf4::ncvar_def("SWnet", units = "W m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Net shortwave radiation")
  nc_var[[s+30]] <- mstmipvar("RootMoist", lat, lon, t, zg)   # not standard
  nc_var[[s+31]] <- ncdf4::ncvar_def("TVeg", units = "kg m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Transpiration")
  nc_var[[s+32]] <- mstmipvar("WaterTableD", lat, lon, t, zg) # not standard
  
  nc_var[[s+33]] <- ncdf4::ncvar_def("fPAR", units = "", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Absorbed fraction incoming PAR")
  nc_var[[s+34]] <- ncdf4::ncvar_def("LAI", units = "m2 m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Leaf Area Index")
  nc_var[[s+35]] <- mstmipvar("SMFrozFrac", lat, lon, t, zg)  # not standard
  nc_var[[s+36]] <- mstmipvar("SMLiqFrac", lat, lon, t, zg)   # not standard
  nc_var[[s+37]] <- ncdf4::ncvar_def("SoilMoist", units = "kg m-2", dim = list(lon, lat, zg, t), missval = -999, 
                                     longname = "Average Layer Soil Moisture")
  out <- checkTemp(38)
  nc_var[[s+38]] <- ncdf4::ncvar_def("SoilTemp", units = "K", dim = list(lon, lat, zg, t), missval = -999, 
                                     longname = "Average Layer Soil Temperature")
  nc_var[[s+39]] <- ncdf4::ncvar_def("SoilWet", units = "", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Total Soil Wetness")
  nc_var[[s+40]] <- mstmipvar("Albedo", lat, lon, t, zg)      # not standard
  out <- checkTemp(41)
  nc_var[[s+41]] <- mstmipvar("SnowT", lat, lon, t, zg)       # not standard
  nc_var[[s+42]] <- ncdf4::ncvar_def("SWE", units = "kg m-2", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Snow Water Equivalent")
  out <- checkTemp(43)
  nc_var[[s+43]] <- mstmipvar("VegT", lat, lon, t, zg)        # not standard
  nc_var[[s+44]] <- ncdf4::ncvar_def("Evap", units = "kg m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Total Evaporation")
  nc_var[[s+45]] <- ncdf4::ncvar_def("Qs", units = "kg m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Surface runoff")
  nc_var[[s+46]] <- ncdf4::ncvar_def("Qsb", units = "kg m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                     longname = "Subsurface runoff")
  out <- conversion(47, yr2s)  ## kg C m-2 yr-1 -> kg C m-2 s-1
  nc_var[[s+47]]<- ncdf4::ncvar_def("SoilResp", units = "kg C m-2 s-1", dim = list(lon, lat, t), missval = -999, 
                                    longname = "Soil Respiration")
  
  return(list(nc_var = nc_var, out = out))
  
} # put_I_values


##-------------------------------------------------------------------------------------------------#
