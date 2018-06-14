# Define pecan file path
path.pecan <- "~/Desktop/Research/pecan/"

# Source PEcAn ED conversion file
source(file.path(path.pecan, "base/utils/R/seconds_in_year.R"))
source(file.path(path.pecan, "base/utils/R/days_in_year.R"))
source(file.path(path.pecan, "modules/data.atmosphere/R/solar_angle.R"))
source("pecan_met_conversion/met2model.ED2.R")


in.path="/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/data/Raw_Inputs/WILLOWCREEK/NLDAS/"
in.prefix="NLDAS"
outfolder="~/Desktop/Research/MetDownscaling_Manuscript/ED_runs/ED_met"

met2model.ED2(in.path=in.path, 
              in.prefix=in.prefix, 
              outfolde=outfolder, 
              start_date="1999-01-01", 
              end_date="2014-12-31")
