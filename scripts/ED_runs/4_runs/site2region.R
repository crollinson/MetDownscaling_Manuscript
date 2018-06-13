# Script to convert site-level runs into spatio-temporal output for PalEON

# ----------------------------------------------
# Load libaries, Set up Directories, etc
# ----------------------------------------------
library(ncdf4)

# file paths
raw.dir <- "phase2_runs.v1"
out.dir <- paste0("ED2.v1.", Sys.Date())
dir.create(out.dir, recursive=T)

# The lat & lon range of the paleon domain
lat <- seq( 35.25,  49.75, by=0.5)
lon <- seq(-99.75, -60.25, by=0.5)
nzg <- 12 # Maximum possible soil layers
file.yrs <- c("0850", "0900", seq(1000, 2000, by=100))

# Making a note of which variables are soil vars 
#  because they need to be dealt with differently
vars.soil <- c("SoilMoist", "SoilTemp")

# ----------------------------------------------


# ----------------------------------------------
# Figure out which sites have paleon-formatted output ready to go
# ----------------------------------------------
# Get a list of all sites
sites.all <- dir(raw.dir)

# Figure out which sites have been post-processed for the site
# (i.e. exclude in-progress sites)
sites.done <- vector()
for(s in sites.all){
  if(dir.exists(file.path(raw.dir, s, paste0(s, "_paleon")))) sites.done <- c(sites.done, s)
}
# ----------------------------------------------

# ----------------------------------------------
# Set up the dimesniosn for what we're extracting
# ----------------------------------------------
for(t in file.yrs){

  # -------------------
  # Setting up the array dimensions for each variable
  # ------------------- 
  # Open up an example file to get the dims for each variable right
  s=sites.done[1]
  nc.path <- file.path(raw.dir, s, paste0(s, "_paleon"))
  nc.file <- dir(nc.path, t)
  ncT <- nc_open(file.path(nc.path, nc.file))
  
  # getting the time dimension
  time.now <- ncvar_get(ncT, "time")
  
  # Creating a blank list for the output
  out <- list()

  # Temporally & Spatially Static variables
  out[["PFT"]] <- data.frame(PFT=ncvar_get(ncT, "PFT"))
  out[["poolname"]] <- data.frame(CPools=ncvar_get(ncT, "poolname"))
  
  # Temporally Static, but Spatially Dynamic 
  out[["SoilDepth"]] <- array(dim=c(length(lon),length(lat),nzg))
  
  # Formatting the temporally-dynamic variables
  for(v in names(ncT$var)[4:length(ncT$var)]){
    if(v %in% vars.soil){
      out[[v]] <- array(dim=c(length(lon),length(lat),nzg,length(time.now)))
    } else {
      out[[v]] <- array(dim=c(length(lon),length(lat),dim(ncvar_get(ncT, v))))
    }
  }
  
  # Close the example file
  nc_close(ncT)
  # -------------------
  
  # -------------------
  # Going by site and adding its data to the appropriate lat/lon
  # -------------------
  for(s in sites.done){
    # Finding the appropriate indexing for the lat & lon of the current site
    n.lat <- which(lat == substr(s, 4, 8))
    n.lon <- which(lon == substr(s, 12, 17))
    
    # opening the file
    nc.path <- file.path(raw.dir, s, paste0(s, "_paleon"))
    nc.file <- dir(nc.path, t)
    ncT <- nc_open(file.path(nc.path, nc.file))
    
    soil.depth <- ncvar_get(ncT, "SoilDepth")
    soil.index <- (dim(out$SoilDepth)[3]-length(soil.depth)+1):dim(out$SoilDepth)[3]
    out[["SoilDepth"]][n.lon,n.lat,soil.index] <- soil.depth
    
    # Going through temporally-dynamic variables
    for(v in names(out)[4:length(out)]){
      if(length(dim(out[[v]]))==3){
        out[[v]][n.lon,n.lat,] <- ncvar_get(ncT, v)
      } else {
        if(v %in% vars.soil){
          out[[v]][n.lon,n.lat,soil.index,] <- ncvar_get(ncT, v)
        } else {
          out[[v]][n.lon,n.lat,,] <- ncvar_get(ncT, v)
        }
      }
    }
  }
  # -------------------
  
  
  # ----------------
  # Defining dimensions
  # NOTE: time will get saved for inside the loop
  # ----------------
  # These will get printed below
  dim.t <- ncdim_def(name = "time",
                     units = paste0("months since 1 Jan 0850"),
                     vals = time.now, # calculating the number of months in this run
                     calendar = "standard", unlim = TRUE)
  dim.lat <- ncdim_def("lat", "degrees_east",
                       vals =  lat,
                       longname = "latitude") 
  dim.lon <- ncdim_def("lon", "degrees_north",
                       vals = lon,
                       longname = "longitude")
  dim.string <- ncdim_def("names", "", 1:24, create_dimvar=FALSE)
  dim.pft1 <- ncdim_def("pft.name", "",
                        1:ncol(out$PFT),
                        longname = "Plant Functional Type", create_dimvar=FALSE)                 
  dim.pft <- ncdim_def("pft", "",
                       vals = 1:nrow(out$PFT),
                       longname = "Plant Functional Type")                 
  dim.pft2 <- ncdim_def("pft.dims", "",
                        vals = 1:nrow(out$PFT),
                        longname = "Plant Functional Type Description")                 
  
  dim.cpools <- ncdim_def("cpools", "",
                          vals = 1:nrow(out$poolname),
                          longname = "Carbon Pools")                 
  dim.cpools1 <- ncdim_def("cpools.name", "",
                           vals = 1:ncol(out$poolname),
                           longname = "Carbon Pools", create_dimvar=FALSE)                 
  dim.cpools2 <- ncdim_def("cpool.dims", "",
                           vals = 1:nrow(out$poolname),
                           longname = "C Pool Descriptions")                 
  dim.soil <- ncdim_def("SoilLayer", "meters",
                        vals = nzg:1,
                        longname = "Soil Layer")                 
  # ----------------
  
  # ----------------
  # Defining Variables
  # ----------------
  # mstmipvar is in the pecan libraries (/pecan/utils/man/mstmipvar.Rd)  
  var <- list() # Create a blank list for the variables
  var[[1]] <- ncvar_def("PFT", units="", dim=list(dim.string, dim.pft1), longname="Plant Functional Type", prec="char")
  var[[2]] <- ncvar_def("poolname", units="", dim=list(dim.string, dim.cpools1), longname="Carbon Pool Names", prec="char")
  var[[3]] <- ncvar_def("SoilDepth", units="m", dim=list(dim.lon, dim.lat, dim.soil), longname="Depth to Bottom of Soil Layers")
  var[[4]] <- ncvar_def("Fcomp", units="kgC/KgC", dim=list(dim.lon, dim.lat, dim.pft, dim.t), longname="Fractional Composition of PFTs by AGB")
  var[[5]] <- ncvar_def("BA", units="m2 ha-1", dim=list(dim.lon, dim.lat, dim.pft, dim.t), longname="Basal Area of PFTs")
  var[[6]] <- ncvar_def("Dens", units="ha-1", dim=list(dim.lon, dim.lat, dim.pft, dim.t), longname="Density of PFTs")
  var[[7]] <- ncvar_def("Mort", units="ha-1", dim=list(dim.lon, dim.lat, dim.pft, dim.t), longname="Mortality of PFTs")
  var[[8]] <- ncvar_def("AGB", units="kg m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Total Aboveground Biomass")
  var[[9]] <- ncvar_def("CarbPools", units="kg m-2", dim=list(dim.lon, dim.lat, dim.cpools, dim.t), longname="Carbon in Each Model Carbon Pool")
  var[[10]] <- ncvar_def("TotLivBiom", units="kg m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Total Living Biomass (leaf + root + sapwood)")
  var[[11]] <- ncvar_def("TotSoilCarb", units="kg m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Total Soil Carbon (fast + slow)")
  var[[12]] <- ncvar_def("GWBI", units="kg m-2 yr-1", dim=list(dim.lon, dim.lat, dim.t), longname="Gross Woody Biomass Increment (analgous to tree-ring derive biomass)")
  var[[13]] <- ncvar_def("BAI", units="cm2 m-2 yr-1", dim=list(dim.lon, dim.lat, dim.t), longname="Basal Area Increment (analgous to tree-ring meaurements)")
  var[[14]] <- ncvar_def("GPP", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Gross Primary Productivity")
  var[[15]] <- ncvar_def("AutoResp", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Autotrophic Respiration")
  var[[16]] <- ncvar_def("HeteroResp", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Heterotrophic Respiration")
  var[[17]] <- ncvar_def("NPP", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Net Primary Productivity") # NOTE: Not broken down by PFT
  var[[18]] <- ncvar_def("NEE", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Net Ecosystem Exchange")
  var[[19]] <- ncvar_def("Fire", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Fire Emissions; note: I think original units were kgC/m2/month and have been converted to KgC/m2/s here")
  var[[20]] <- ncvar_def("LW_albedo", units="", dim=list(dim.lon, dim.lat, dim.t), longname="Longwave Albedo")
  var[[21]] <- ncvar_def("SW_albedo", units="", dim=list(dim.lon, dim.lat, dim.t), longname="Shortwave Albedo")
  var[[22]] <- ncvar_def("LWnet", units="W m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Net Longwave Radiation")
  var[[23]] <- ncvar_def("SWnet", units="W m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Net Shortwave Radiation")
  var[[24]] <- ncvar_def("Qh", units="W m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Sensible Heat Flux (ATM -> Canopy)")
  var[[25]] <- ncvar_def("Qle", units="W m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Latent Heat Flux; note: I'm going from the model documentation, but this seems off")
  var[[26]] <- ncvar_def("LAI", units="m2 m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Leaf Area Index")
  var[[27]] <- ncvar_def("Qs", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Surface Runoff")
  var[[28]] <- ncvar_def("Qsb", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Subsurface Runoff (Drainage)")
  var[[29]] <- ncvar_def("Evap", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Total Evaporation")
  var[[30]] <- ncvar_def("Transp", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Total Transpiration") # NOTE: not broken down by PFT
  var[[31]] <- ncvar_def("SnowDepth", units="m", dim=list(dim.lon, dim.lat, dim.t), longname="Total Snow/Water Depth (includes ponded rain)") # NOTE: Units differ from the protocol sheet
  var[[32]] <- ncvar_def("SWE", units="kg m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Snow Water Equivalent (includes ponded rain)")
  var[[33]] <- ncvar_def("SoilMoist", units="kg m-3", dim=list(dim.lon, dim.lat, dim.soil, dim.t), longname="Soil Moisture") # NOTE: Units differ from the protocol sheet
  var[[34]] <- ncvar_def("SoilTemp", units="K", dim=list(dim.lon, dim.lat, dim.soil, dim.t), longname="Soil Temperature")
  var[[35]] <- ncvar_def("lwdown", units="W m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Incoming Longwave Radiation")
  var[[36]] <- ncvar_def("swdown", units="W m-2", dim=list(dim.lon, dim.lat, dim.t), longname="Incoming Shortwave Radiation")
  var[[37]] <- ncvar_def("precipf", units="kg m-2 s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Mean Precipitation Rate")
  var[[38]] <- ncvar_def("psurf", units="Pa", dim=list(dim.lon, dim.lat, dim.t), longname="Surface Pressure")
  var[[39]] <- ncvar_def("qair", units="kg kg-1", dim=list(dim.lon, dim.lat, dim.t), longname="Specific Humidity")
  var[[40]] <- ncvar_def("tair", units="K", dim=list(dim.lon, dim.lat, dim.t), longname="Air Temperature")
  var[[41]] <- ncvar_def("wind", units="m s-1", dim=list(dim.lon, dim.lat, dim.t), longname="Wind Speed")
  var[[42]] <- ncvar_def("CO2", units="ppm", dim=list(dim.lon, dim.lat, dim.t), longname="CO2 Concentration")
  # ----------------

  # ----------------
  # Creating & filling the regional netcdf file
  # ----------------
  nc <- nc_create(file.path(out.dir, paste0("ED2_", t, ".nc")), var)
  for(i in 1:length(var)) {
    print(paste0("Working on var ", i, " - ", names(out)[i]))
    ncvar_put(nc, var[[i]], out[[i]])
  }
  nc_close(nc)
  # ----------------
}


# ----------------------------------------------
