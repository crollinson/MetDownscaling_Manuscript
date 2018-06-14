# Define pecan file path
path.pecan <- "~/Desktop/Research/pecan/"

# Source PEcAn ED conversion file
source(file.path(path.pecan, "base/utils/R/seconds_in_year.R"))
source(file.path(path.pecan, "base/utils/R/days_in_year.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R/solar_angle.R"))
source(file.path(path.pecan, "models/ed/R/write_ed_metheader.R"))
source(file.path(path.pecan, "models/ed/R/check_ed_metheader.R"))
source("pecan_met_conversion/met2model.ED2.R")


in.base="/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/data/Raw_Inputs/WILLOWCREEK/"
outfolder="../ED_runs/ED_met"

# Convert LDAS Raw
met2model.ED2(in.path=file.path(in.path, "NLDAS"), 
              in.prefix="NLDAS", 
              outfolde=outfolder, 
              start_date="1999-01-01", 
              end_date="2014-12-31")

# Convert Ameriflux 1 hr raw
met2model.ED2(in.path=file.path(in.path, "Ameriflux_WCr"), 
              in.prefix="WCr_1hr", 
              outfolde=outfolder, 
              start_date="1999-01-01", 
              end_date="2014-12-31")
