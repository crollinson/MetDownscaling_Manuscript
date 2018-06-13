## --------------------------------------------------------------
## Reformatting of HDF5 ED2 output to PalEON standardized ncdf
## Loosely based on the PEcAn script (model2netcdf.ED2)
## --------------------------------------------------------------

## --------------------------------------------------------------
## Necessary Libraries
## --------------------------------------------------------------
library(ncdf4)
library(zoo)
#library(bigmemory)
# library(abind)

## --------------------------------------------------------------
## Defining parameters & setting up some data to be added later
## --------------------------------------------------------------

## --------------------------------------------------------------
## --------------------------------------------------------------
## Creating a funciton that can be executed
## --------------------------------------------------------------
## --------------------------------------------------------------
model2netcdf.ED2.paleon <- function(site, raw.dir, new.dir, sitelat, sitelon, start.run, end.run) {


## --------------------------------------------------------------
## Handy functions developed by the pecan folks
## --------------------------------------------------------------

getHdf5Data <- function(nc, var) {
	if(var %in% names(nc$var)) {
		return(ncvar_get(nc, var))
	} else {
		print("Could not find", var, "in ed hdf5 output.")
		return(-999)
    	}
  	}

add <- function(dat, col) {
	### CR Note: This has been modified from the PEcAn code and will only work work with adding vectors (no 3-D array adding)
	if(length(out) < col){
		out[[col]] <- array(dat)
	} else {
		out[[col]] <- cbind(out[[col]], array(dat))
	}
	return(out)
}

yr2sec <- 1/(365*24*60*60)
mo2sec <- 1/(12*24*60*60)

## ------------------------------------------------------------------------------
## Data Frames Specifying some of the parameters we need
## ------------------------------------------------------------------------------
PFTs <- data.frame(cbind(1:17, c("C4 grass", "Early tropical", "Mid Tropical", "Late tropical", "Temperate C3 Grass", "North Pine", "South Pine", "Late conifer", "Early hardwood", "Mid hardwood", "Late hardwood", "C3 crop", "C3 pasture", "C4 crop", "C4 pasture", "C3 grass", "Araucaria")))
colnames(PFTs) <- c("PFT", "Description")
PFTs$PFT <- as.numeric(paste(PFTs$PFT))


Var.ED <- c("BDEAD", "BLEAF", "BROOT", "BSAPWOODA", "BSAPWOODB", "BSEEDS_CO", "BSTORAGE", "CWD", "FAST_SOIL_C", "SLOW_SOIL_C")
Var.Desc <- c("Dead", "Leaf", "Root", "Sapwood Aboveground", "Sapwood Belowground", "Seeds", "Wood Storage", "CWD", "Soil C, Fast", "Soil C, Slow", "Soil C, Structural")
C.pools <- cbind(1:length(Var.ED), Var.ED, Var.Desc) 
colnames(C.pools) <- c("Var.No", "Var.ED", "Description")



var.names <- c("PFT", "poolname", "SoilDepth", "Fcomp", "BA", "Dens", "Mort", "AGB", "CarbPools", "TotLivBiom", "TotSoilCarb", "GWBI", "BAI", "GPP", "AutoResp", "HeteroResp", "NPP", "NEE", "IgnitionRate", "LW_albedo", "SW_Albedo", "LWnet", "SWnet", "Qh", "Qle", "LAI", "Qs", "Qsb", "Evap", "Transp", "SFCWDepth", "SFCWMass", "SoilMoist", "SoilTemp", "lwdown", "swdown", "precipf", "psurf", "qair", "tair", "wind", "CO2")

## ------------------------------------------------------------------------------
## Extracting ED data outside of the function/loop created by PEcAn folks
## Function Name: mdoel2netcdf.ED2
## ------------------------------------------------------------------------------

## ------------------------------------ 
# Step 1: Creating a list of all files meeting the criteria
  flist <- dir(file.path(raw.dir, "analy/"),"-E-") # edited by CRR
  if (length(flist) == 0) {
    print(paste("*** WARNING: No output for :",raw.dir)) # Edited by CRR
    break
  }
 
## ------------------------------------ 
# Step 2: Extracting some info from file names

# List of Years contained in the directory/file path
  yr <- rep(NA,length(flist)) # create empty vector the same length as the file list
  for(i in 1:length(flist)){
    index <- gregexpr("-E-",flist[i])[[1]] # Searching for the monthly data marker (-E-); returns 3 bits of information: 1) capture.start (4); 2) capture.length (3); 3) capture.names (TRUE)
    index <- index[1] # indexing off of just where the monthly flag starts
    yr[i] <- as.numeric(substr(flist[i],index+3,index+6)) # putting in the Years, indexed off of where the year starts & ends
  }  


## ------------------------------------ 
# Step 3: Looping through files by year bins -- these bins become the output files -- This has a lot of parts

# Settting up some stuff to cycle through by year
  yrs <- sort(unique(yr)) # creating a vector with each unique year in the data list
	
# Begin Bin Loop!
  for(y in 1:length(bins)){ # The bulk of the function loops through by year to summarize data by year

## ----------------
	# Selecting a subset and double checking valid dates
	start <- yrs[yrs==bins[y]]
	if(y < length(bins)){
		end <- yrs[yrs==bins[y+1]-1]
	}else{
		end <- as.numeric(strftime(end.run, "%Y")) 		
	}
		
	# get index of cells that belong to the bin of interest
		ysel <- which(yr>=start & yr<=end) # Set up non-overlapping bins

    # This flags if years are before or after the year of interest
    if (yrs[y] < strftime(start.run, "%Y")) {
      print(paste0(yrs[y], "<", strftime(start.run, "%Y")))
      next
    }
    if (yrs[y] > strftime(end.run, "%Y")) {
      print(paste0(yrs[y], ">", strftime(end.run, "%Y")))
      next
    }

## ----------------
    n <- length(ysel) # length of the files you're looking for

	# just letting you know what year you're working on
	print(paste0("----------  Processing Bin: ", start, " - ", end, "  ----------")) 
		

## ------------------------------------ 
# Creating a blank matrix & then adding in the variables that are static through time (soil, PFT info)
	out <- list()
    
    ncT <- nc_open(file.path(raw.dir, "analy/", flist[ysel[1]])) # Opening the first hdf5 file in the output

	out[[1]] <- PFTs[,2]
	out[[2]] <- C.pools[,3]
	out[[3]] <- getHdf5Data(ncT, "SLZ")

    nc_close(ncT)

## ----------------
# Begin File Loop! For each file belonging to the time period of interest
  for(i in seq_along(ysel)){ # looping through each of the files of interest
#	print(paste0("-------------------  Year: ", start, " - ", end, "  ----------")) 
      ncT <- nc_open(file.path(raw.dir, "analy/", flist[ysel[i]])) # Opening the hdf5 file for the month of interest (package ndcf4 will read hdf5)
      # ncT.histo <- nc_open(file.path(raw.dir, "histo/", paste0(substr(sub('-E-', '-S-', flist[ysel[i]]),1,13), "-01-", substr(sub('-E-', '-S-', flist[i]),18,30))))

  
	  ## ----------------
	  ## Some data needed to do conversions on specific parameters
	  ## ----------------
    # General info
    npatch <- ncvar_get(ncT, "NPATCHES_GLOBAL")
    ncohort <- ncvar_get(ncT, "NCOHORTS_GLOBAL")
    
	  # Cohort-Level Info
		nplant <- ncvar_get(ncT, "NPLANT")
		pft <- ncvar_get(ncT, "PFT")
    pftT <- sort(unique(pft)) # listing the PFTs present, in order

		# Patch-Level Info:
		patch.n <- ncvar_get(ncT, 'PACO_N') 
		patch.start <- ncvar_get(ncT, 'PACO_ID')
		patch.area <- ncvar_get(ncT, 'AREA')
		patch.area.df <- data.frame(patch.area, 1:npatch); names(patch.area.df) <- c("area", "patch")
    patch.area.df$area.rel <- patch.area.df$area/sum(patch.area.df$area)
		total.area <- sum(patch.area)

		patch.co <- vector(length=ncohort)
		patch.area.co <- vector(length=ncohort)
		for(p in 1:length(patch.start)){
			if(patch.n[p]>0)
      patch.co[patch.start[p]:(patch.start[p]+patch.n[p]-1)] <- p
			patch.area.co[patch.start[p]:(patch.start[p]+patch.n[p]-1)] <- patch.area[p]
		}
#    patch.area.co.sum <- sum(patch.area.co)

		dens.co <- data.frame(cbind(nplant, pft, patch.co)); colnames(dens.co) <- c("density", "pft", "patch") # plants/m2
		
	  ## ----------------
	  ## Diversity
	  ## ----------------
      	# PFT - PFT Names; already added above: out[[1]]

      	# Fcomp - Fractional Composition by above ground biomass
      	agb <- cbind(ncvar_get(ncT, 'AGB_CO')*dens.co[,1], pft, patch.co) # AGB by cohort; units: kgC/plant x plant/m2 = kgC/m2
        agb2 <- aggregate(agb[,1], by=list(agb[,2], agb[,3]), sum); names(agb2) <- c("pft", "patch", "agb") # total PFT AGB within a patch

        agb3 <- agb2
        for(p in unique(agb3$patch)){
          patch.agb <- sum(agb3[agb3$patch==p, "agb"])
          for(s in unique(agb3$pft)){
            agb3[agb3$patch==p & agb3$pft==s, "agb"] <- agb3[agb3$patch==p & agb3$pft==s, "agb"]/patch.agb
          }
        }
        agb3 <- merge(agb3, patch.area.df)
        agb4 <- tapply(agb3$agb*agb3$area, list(agb3$pft), FUN=sum);  # relative PFT AGB within a patch; Units: fraction (unitless)
        agb4 <- data.frame(cbind(agb4, names(agb4))); names(agb4) <- c("fcomp", "PFT") 
        fcomp <- merge(PFTs, agb4, all.x=T, all.y=T)
#         fcomp$PFT <- as.numeric(paste(fcomp$PFT)) # neccessary if reading PFT as categorical
#         fcomp <- fcomp[ordered(as.numeric(paste(fcomp$PFT))),] # neccessary if reading PFT as categorical
		    fcomp$fcomp <- as.numeric(paste(fcomp$fcomp))
    		fcomp[is.na(fcomp)] <- 0   

        out <- add(fcomp$fcomp,4) 
		    
      	# BA - Basal Area by PFT 
        ## -- NOTE: right now the units are cm2/plant --> use nplant to get area    

		    ba <- cbind(ncvar_get(ncT, 'BA_CO')*dens.co[,1], pft, patch.co) # BA by cohort; note: cm2/m2 = m2/ha
		    ba2 <- aggregate(ba[,1], by=list(ba[,2], ba[,3]), sum); names(ba2) <- c("pft", "patch", "ba") # total PFT BA within a patch; units: m2/ha
		    ba2 <- merge(ba2, patch.area.df)

		    ba3 <- tapply(ba2$ba*ba2$area, list(ba2$pft), FUN=sum);  # PFT BA weighted by patch
		    ba3 <- data.frame(cbind(ba3, names(ba3))); names(ba3) <- c("ba", "PFT")
		    ba.pft <- merge(PFTs, ba3, all.x=T, all.y=T) # adding in all PFTs for record keeping
		    ba.pft$ba <- as.numeric(paste(ba.pft$ba))
		    ba.pft[is.na(ba.pft)] <- 0
    
    		out <- add(as.numeric(paste(ba.pft$ba)), 5)

      	# Density - Stem Density by PFT (in plants/m2)
      	# dens.co <- data.frame(cbind(nplant*patch.area.co, pft)); colnames(dens.co) <- c("density", "pft") # done above to get ba/ha
		 dens2 <- aggregate(dens.co[,1], by=list(dens.co[,2], dens.co[,3]), sum); names(dens2) <- c("pft", "patch", "dens") # summing by pft within patch;
		dens2 <- merge(dens2, patch.area.df)
		
        dens3 <- tapply(dens2$dens*dens2$area, list(dens2$pft), FUN=sum);  # PFT BA weighted by patch; units: plants/m2
        dens3 <- data.frame(cbind(dens3, names(dens3))); names(dens3) <- c("dens", "PFT")
        dens.pft <- merge(PFTs, dens3, all.x=T, all.y=T) # adding in all PFTs for record keeping
		    dens.pft$dens <- as.numeric(paste(dens.pft$dens))
        dens.pft[is.na(dens.pft)] <- 0
        dens.pft$dens <- dens.pft$dens*10000 # Converting from plants/m2 to plants/ha

    		out <- add(dens.pft$dens, 6)

	  # Establishment Rate

	  # # Mortality Rate
	  mort  <- cbind(NA, pft, patch.co)
	  # mort <- cbind(apply(ncvar_get(ncT, "MORT_RATE_CO"),2, sum)*dens.co[,1], pft, patch.co)
	  mort2 <- aggregate(mort[,1], by=list(mort[,2], mort[,3]), sum); names(mort2) <- c("pft", "patch", "mort")
	  mort2 <- merge(mort2, patch.area.df)
	  mort3 <- tapply(mort2$mort*mort2$area, list(mort2$pft), FUN=sum)
	  mort3 <- data.frame(mort=mort3, PFT=names(mort3))
	  mort.pft <- merge(PFTs, mort3, all.x=T, all.y=T)
	  mort.pft$mort <- as.numeric(paste(mort.pft$mort))
	  mort.pft[is.na(mort.pft)] <- 0
	  mort.pft$mort <- mort.pft$mort*10000
	  out <- add(mort.pft$mort, 7)
	  
	  ## ----------------
	  ## Carbon Pools
	  ## ----------------
	  	# AGB - total aboveground biomass
      agb2b <- aggregate(agb[,1], by=list(agb[,3]), sum); names(agb2) <- c("patch", "agb") # total PFT AGB within a patch
      agb.total <- sum(agb2b*patch.area[patch.n>0]) # units *should* be kg/m2
      out <- add(agb.total, 8)

	  	# CarbPools - individual soil pools; by cohort kgC/plant
      Cpools.co <- data.frame(array(dim=c(ncohort,7))); names(Cpools.co) <- Var.ED[1:7]; Cpools.co$patch <- patch.co
      Cpools <- vector(length=length(Var.ED)); names(Cpools) <- Var.ED
      
      for(p in unique(Var.ED[1:7])){
        Cpools.co[,p] <- ncvar_get(ncT, p)*dens.co[,1] # units: kgC/plant x plants/m2 = kgC/m2
        Cpools[p] <- sum(tapply(Cpools.co[,p], list(Cpools.co[,8]), sum)*patch.area[patch.n>0])
      }

      Cpools["CWD"] <- ncvar_get(ncT, 'MMEAN_CWD_C_PY') # units: kgC/m2
      Cpools["FAST_SOIL_C"] <- ncvar_get(ncT, 'MMEAN_FAST_SOIL_C_PY') # units: kgC/m2
      Cpools["SLOW_SOIL_C"] <- ncvar_get(ncT, 'MMEAN_SLOW_SOIL_C_PY') # units: kgC/m2
      Cpools["STRUCT_SOIL_C"] <- ncvar_get(ncT, 'MMEAN_STRUCT_SOIL_C_PY') # units: kgC/m2

      out <- add(array(Cpools), 9)
	  	
	  	# TotLivBiom - Total living biomass (leaf + root + wood); NOTE: right now that includes storage C, but not dead (=structural wood/heartwood)
      live <-  cbind(ncvar_get(ncT, 'BALIVE')*dens.co[,1], pft, patch.co) # AGB by cohort; units: kgC/plant x plant/m2 = kgC/m2
      live2 <- aggregate(live[,1], by=list(live[,3]), sum); names(live2) <- c("patch", "live") # total PFT live within a patch
      live.tot <- sum(live2*patch.area[patch.n>0])

      out <- add(live.tot, 10) # units: kgC/m2

	  	# TotSoilCarb - total soil & litter content over entire profile
		  out <- add(sum(Cpools[c("FAST_SOIL_C", "SLOW_SOIL_C", "STRUCT_SOIL_C")]), 11) # units: kgC/m2
	  		  	
	  	# poolname - names of the CarbPools; done above: out[[2]]
	  	
	  	# GWBI - gross woody biomass increment 
      #     -> I'm going to go ahead and split this into DBA (= BAI cm2/plant/yr) and DAGB (AGB increment kgC/plant/yr)
      #     -> Note: there are some pretty wonky values in DBA right now
      dbiomass.co <- data.frame(array(dim=c(ncohort, 2))); names(dbiomass.co) <- c("DAGB_DT", "DBA_DT"); dbiomass.co$patch <- patch.co
      
      dbiomass.co[,"DAGB_DT"] <- ncvar_get(ncT, "DAGB_DT")*dens.co[,1]
      dbiomass.co[,"DBA_DT"] <- ncvar_get(ncT, "DBA_DT")*dens.co[,1]
      dbiomass <- aggregate(dbiomass.co[,c("DAGB_DT", "DBA_DT")], by=list(dbiomass.co$patch), sum); names(dbiomass) <- c("patch", "DAGB_DT", "DBA_DT")
      
      out <- add(sum(dbiomass["DAGB_DT"]*patch.area[patch.n>0]), 12)
      out <- add(sum(dbiomass["DBA_DT"]*patch.area[patch.n>0]), 13)


	  ## ----------------
	  ## Carbon Fluxes
	  ## ----------------
		# GPP - Gross primary productivity
		out <- add(ncvar_get(ncT, "MMEAN_GPP_PY")*yr2sec, 14) # original untis: kgC/m2/yr

		# AutoResp - Autotrophic respirtation
		out <- add(ncvar_get(ncT, "MMEAN_PLRESP_PY")*yr2sec, 15) # original units: kgC/m2/yr

		# HeteroResp - Heterotrophic respiration
		out <- add(ncvar_get(ncT, "MMEAN_RH_PY")*yr2sec, 16) # original units: kgC/m2/yr

		# NPP - Net Primary Productivity
		out <- add(ncvar_get(ncT, "MMEAN_NPP_PY")*yr2sec, 17) # original units: kgC/m2/yr

		# NEE - Net Ecosystem Exchange
		out <- add(ncvar_get(ncT, "MMEAN_NEP_PY")*yr2sec*(-1), 18) # original units: kgC/m2/yr

		# Fire - Fire emissions - need to calculate from Ignition Rate
		out <- add(ncvar_get(ncT, "IGNITION_RATE")*mo2sec, 19) # original units: kgC/m2/month (I think, definitely kgC/m2)
		
	  ## ----------------
	  ## Energy Fluxes
	  ## ----------------
	  	# LW_albedo - Longwave Albedo
  		out <- add(ncvar_get(ncT, "MMEAN_RLONG_ALBEDO_PY"), 20)

	  	# SW_albedo - Shortwave Albedo 
	  	out <- add(array(ncvar_get(ncT, "MMEAN_ALBEDO_PY")), 21)
	  	
	  	# LWnet - Net Longwave Radiation
		  out <- add(array(ncvar_get(ncT, "MMEAN_ATM_RLONG_PY")-ncvar_get(ncT, "MMEAN_RLONGUP_PY")), 22) # Units: W/m2
      # out <- add(array(ncvar_get(ncT, "MMEAN_ATM_RLONG_PY")), 22) # Units: W/m2

	  	# SWnet - Net Shortwave Radiation (incoming - upgoing)
      out <- add(array(ncvar_get(ncT, "MMEAN_ATM_RSHORT_PY")-ncvar_get(ncT, "MMEAN_RSHORTUP_PY")), 23) # Units: W/m2
      # out <- add(array(ncvar_get(ncT, "MMEAN_ATM_RSHORT_PY")), 23) # Units: W/m2

	  	# Qh - Sensible Heat -  ATM -> CAS
	  	out <- add(ncvar_get(ncT, "MMEAN_SENSIBLE_AC_PY")*-1, 24) # Units: W/m2
	  	
	  	# Qle - Latent Heat = Evapotranspiration
      out <- add(ncvar_get(ncT, "MMEAN_VAPOR_AC_PY")*(-2.26e6), 25) # units: kg/m2/s


	  ## ----------------
	  ## Other
	  ## ----------------
	  	# LAI - Leaf Area Index (total)
      lai.co <- data.frame(cbind(ncvar_get(ncT, "LAI_CO"), patch.co)); names(lai.co) <- c("LAI", "patch")
      lai <- aggregate(lai.co[,"LAI"], by=list(lai.co[,"patch"]), sum); names(lai) <- c("patch", "LAI")
      out <- add(sum(lai[,"LAI"]*patch.area[patch.n>0]), 26)

	  	# Qs - Surface Runoff
  		out <- add(ncvar_get(ncT, "MMEAN_RUNOFF_PY"), 27)

	  	# Qsb - Subsurface Runoff (drainage + lateral flow); no lateralflow found
	  	out <- add(ncvar_get(ncT, "MMEAN_DRAINAGE_PY"), 28)

	  	# Evap - Total Evaporation
		  out <- add(sum(ncvar_get(ncT, "MMEAN_VAPOR_GC_PY"), ncvar_get(ncT, "MMEAN_VAPOR_LC_PY"), ncvar_get(ncT, "MMEAN_VAPOR_WC_PY"))*(-1), 29) # units: kg/m2/s

	  	# Transp - Total Transpriation
  		out <- add(ncvar_get(ncT, "MMEAN_TRANSP_PY"), 30) # Units: kg/m2/s

	  	# SnowDepth - Total snow depth --> SFCW_DEPTH
      # Supplementing SFCW Depth (snow + water)
	  	out <- add(ncvar_get(ncT, "MMEAN_SFCW_DEPTH_PY"), 31) # units: m

	  	# SWE - Snow Water Equivalent 
      #   --> Suplementing SFCW MASS 
		  out <- add(ncvar_get(ncT, "MMEAN_SFCW_MASS_PY"), 32) # units: kg/m2

	  	# SoilMoist - Soil Moisture
		  out <- add(ncvar_get(ncT, "MMEAN_SOIL_WATER_PY")*100, 33) # units: m3/m3 * 100 kg/m3

	  	# SoilTemp - Soil Temperature
		  out <- add(ncvar_get(ncT, "MMEAN_SOIL_TEMP_PY"), 34) # units: K

	  	# SoilDepth - Soil Layer Depths - done above: out[[3]]
	  

	  ## ----------------
	  ## Met Drivers
	  ## ----------------
	  # lwdown - Incoming longwave radiation
		out <- add(ncvar_get(ncT, "MMEAN_ATM_RLONG_PY"), 35) # units: W/m2
	  	
	  # swdown - Incoming shortwave radiation
		out <- add(ncvar_get(ncT, "MMEAN_ATM_RSHORT_PY"), 36) # units: W/m2
	  	
	  # precipf - Preciptiation rate (mean)
		out <- add(ncvar_get(ncT, "MMEAN_PCPG_PY"), 37) # units: kg/m2/s
	  	
	  # psurf - surface pressure
		out <- add(ncvar_get(ncT, "MMEAN_ATM_PRSS_PY"), 38) # units: Pa
	  	
	  # qair - specific humidity
		out <- add(ncvar_get(ncT, "MMEAN_ATM_SHV_PY"), 39) # units: kg/kg
	  	
	  # tair - air temperature
		out <- add(ncvar_get(ncT, "MMEAN_ATM_TEMP_PY"), 40) # units: K
	  	
	  # wind - wind speed
		out <- add(ncvar_get(ncT, "MMEAN_ATM_VELS_SI"), 41) # untis: m/s
	  	
	  # CO2 - CO2 concentration
		out <- add(ncvar_get(ncT, "MMEAN_ATM_CO2_PY"), 42) # units: umol/mol

      
		## ----------------
		nc_close(ncT)
#		nc_close(ncT.histo)
    rm(patch.area.co, patch.co, agb, agb2, agb3, agb4, fcomp, ba, ba2, ba3, ba.pft, dens.co, dens2, dens3, dens.pft, mort, mort2, mort3, mort.pft, Cpools, Cpools.co, dbiomass.co, dbiomass, ncohort, npatch)
    }  ## end file (month) loop 
    
print(paste0("----------  Data organized  ----------")) 

names(out) <- var.names

    ## ----------------
    ## declare variables
	## ----------------
    ## vector of dates included in the run
	dates <- as.Date(paste0(substr(flist[ysel], index+3, index+11), "1"), "%Y-%m-%d")
	

	## ----------------
	## These will get printed below
    dim.t <- ncdim_def(name = "time",
                   units = paste0("months since run start:", start.run),
                   vals = (as.yearmon(dates)-as.yearmon(start.run))*12, # calculating the number of months in this run
                   calendar = "standard", unlim = TRUE)
    dim.lat <- ncdim_def("lat", "degrees_east",
                     vals =  as.numeric(sitelat),
                     longname = "station_latitude") 
    dim.lon <- ncdim_def("lon", "degrees_north",
                     vals = as.numeric(sitelon),
                     longname = "station_longitude")
    dim.string <- ncdim_def("names", "", 1:24, create_dimvar=FALSE)
    dim.pft1 <- ncdim_def("pft", "",
                     1:length(PFTs$PFT),
                     longname = "Plant Functional Type", create_dimvar=FALSE)                 
    dim.pft <- ncdim_def("pft", "",
                     vals = as.numeric(PFTs[,"PFT"]),
                     longname = "Plant Functional Type")                 
    dim.pft2 <- ncdim_def("pft.dims", "",
                     vals = 1:ncol(PFTs),
                     longname = "Plant Functional Type Description")                 

    dim.cpools <- ncdim_def("cpools", "",
                     vals = 1:nrow(C.pools),
                     longname = "Carbon Pools")                 
    dim.cpools1 <- ncdim_def("cpools", "",
                        vals = 1:nrow(C.pools),
                        longname = "Carbon Pools", create_dimvar=FALSE)                 
    dim.cpools2 <- ncdim_def("cpool.dims", "",
                     vals = 1:ncol(C.pools),
                     longname = "C Pool Descriptions")                 

    dim.soil <- ncdim_def("SoilLayer", "meters",
                     vals = nrow(out[[3]]):1,
                     longname = "Soil Layer")                 
    # zg <- ncdim_def("SoilLayerMidpoint", "meters", c(slzdata[1:length(dz)] + dz / 2, 0))
    
    
	## ----------------
	## Defining Variables
	## mstmipvar is in the pecan libraries (/pecan/utils/man/mstmipvar.Rd)	
    var <- list() # Create a blank list for the variables
    var[[1]] <- ncvar_def("PFT", units="", dim=list(dim.string, dim.pft1), longname="Plant Functional Type", prec="char")
    var[[2]] <- ncvar_def("poolname", units="", dim=list(dim.string, dim.cpools1), longname="Carbon Pool Names", prec="char")
    var[[3]] <- ncvar_def("SoilDepth", units="m", dim=list(dim.soil), longname="Depth to Bottom of Soil Layers")
    var[[4]] <- ncvar_def("Fcomp", units="kgC/KgC", dim=list(dim.pft, dim.t), longname="Fractional Composition of PFTs by AGB")
    var[[5]] <- ncvar_def("BA", units="m2 ha-1", dim=list(dim.pft, dim.t), longname="Basal Area of PFTs")
    var[[6]] <- ncvar_def("Dens", units="ha-1", dim=list(dim.pft, dim.t), longname="Density of PFTs")
    var[[7]] <- ncvar_def("Mort", units="ha-1", dim=list(dim.pft, dim.t), longname="Mortality of PFTs")
    var[[8]] <- ncvar_def("AGB", units="kg m-2", dim=list(dim.t), longname="Total Aboveground Biomass")
    var[[9]] <- ncvar_def("CarbPools", units="kg m-2", dim=list(dim.cpools, dim.t), longname="Carbon in Each Model Carbon Pool")
    var[[10]] <- ncvar_def("TotLivBiom", units="kg m-2", dim=list(dim.t), longname="Total Living Biomass (leaf + root + sapwood)")
    var[[11]] <- ncvar_def("TotSoilCarb", units="kg m-2", dim=list(dim.t), longname="Total Soil Carbon (fast + slow)")
    var[[12]] <- ncvar_def("GWBI", units="kg m-2 yr-1", dim=list(dim.t), longname="Gross Woody Biomass Increment (analgous to tree-ring derive biomass)")
    var[[13]] <- ncvar_def("BAI", units="cm2 m-2 yr-1", dim=list(dim.t), longname="Basal Area Increment (analgous to tree-ring meaurements)")
    var[[14]] <- ncvar_def("GPP", units="kg m-2 s-1", dim=list(dim.t), longname="Gross Primary Productivity")
    var[[15]] <- ncvar_def("AutoResp", units="kg m-2 s-1", dim=list(dim.t), longname="Autotrophic Respiration")
    var[[16]] <- ncvar_def("HeteroResp", units="kg m-2 s-1", dim=list(dim.t), longname="Heterotrophic Respiration")
    var[[17]] <- ncvar_def("NPP", units="kg m-2 s-1", dim=list(dim.t), longname="Net Primary Productivity") # NOTE: Not broken down by PFT
    var[[18]] <- ncvar_def("NEE", units="kg m-2 s-1", dim=list(dim.t), longname="Net Ecosystem Exchange")
    var[[19]] <- ncvar_def("Fire", units="kg m-2 s-1", dim=list(dim.t), longname="Fire Emissions; note: I think original units were kgC/m2/month and have been converted to KgC/m2/s here")
    var[[20]] <- ncvar_def("LW_albedo", units="", dim=list(dim.t), longname="Longwave Albedo")
    var[[21]] <- ncvar_def("SW_albedo", units="", dim=list(dim.t), longname="Shortwave Albedo")
    var[[22]] <- ncvar_def("LWnet", units="W m-2", dim=list(dim.t), longname="Net Longwave Radiation")
    var[[23]] <- ncvar_def("SWnet", units="W m-2", dim=list(dim.t), longname="Net Shortwave Radiation")
    var[[24]] <- ncvar_def("Qh", units="W m-2", dim=list(dim.t), longname="Sensible Heat Flux (ATM -> Canopy)")
    var[[25]] <- ncvar_def("Qle", units="W m-2", dim=list(dim.t), longname="Latent Heat Flux; note: I'm going from the model documentation, but this seems off")
    var[[26]] <- ncvar_def("LAI", units="m2 m-2", dim=list(dim.t), longname="Leaf Area Index")
    var[[27]] <- ncvar_def("Qs", units="kg m-2 s-1", dim=list(dim.t), longname="Surface Runoff")
    var[[28]] <- ncvar_def("Qsb", units="kg m-2 s-1", dim=list(dim.t), longname="Subsurface Runoff (Drainage)")
    var[[29]] <- ncvar_def("Evap", units="kg m-2 s-1", dim=list(dim.t), longname="Total Evaporation")
    var[[30]] <- ncvar_def("Transp", units="kg m-2 s-1", dim=list(dim.t), longname="Total Transpiration") # NOTE: not broken down by PFT
    var[[31]] <- ncvar_def("SnowDepth", units="m", dim=list(dim.t), longname="Total Snow/Water Depth (includes ponded rain)") # NOTE: Units differ from the protocol sheet
    var[[32]] <- ncvar_def("SWE", units="kg m-2", dim=list(dim.t), longname="Snow Water Equivalent (includes ponded rain)")
    var[[33]] <- ncvar_def("SoilMoist", units="kg m-3", dim=list(dim.soil, dim.t), longname="Soil Moisture") # NOTE: Units differ from the protocol sheet
    var[[34]] <- ncvar_def("SoilTemp", units="K", dim=list(dim.soil, dim.t), longname="Soil Temperature")
    var[[35]] <- ncvar_def("lwdown", units="W m-2", dim=list(dim.t), longname="Incoming Longwave Radiation")
    var[[36]] <- ncvar_def("swdown", units="W m-2", dim=list(dim.t), longname="Incoming Shortwave Radiation")
    var[[37]] <- ncvar_def("precipf", units="kg m-2 s-1", dim=list(dim.t), longname="Mean Precipitation Rate")
    var[[38]] <- ncvar_def("psurf", units="Pa", dim=list(dim.t), longname="Surface Pressure")
    var[[39]] <- ncvar_def("qair", units="kg kg-1", dim=list(dim.t), longname="Specific Humidity")
    var[[40]] <- ncvar_def("tair", units="K", dim=list(dim.t), longname="Air Temperature")
    var[[41]] <- ncvar_def("wind", units="m s-1", dim=list(dim.t), longname="Wind Speed")
    var[[42]] <- ncvar_def("CO2", units="ppm", dim=list(dim.t), longname="CO2 Concentration")
 
    ## write NCDF File
    print(paste0("----------  Creating ncdf File  ----------")) 

    yr.real <- ifelse(bins[y]-1000<1000, paste0(0, bins[y]-1000), bins[y]-1000)

    nc <- nc_create(file.path(new.dir, paste(site, "ED2", yr.real, "nc", sep=".")), var)
    for(i in 1:length(var)) {
      ncvar_put(nc, var[[i]], out[[i]])
    }
    nc_close(nc)
    rm(out, nc, var, pft, dim.t, dim.lat, dim.lon, dim.string, dim.pft, dim.pft2, dim.cpools, dim.cpools2, dim.soil)
}  ## end bin loop
}	## End function


