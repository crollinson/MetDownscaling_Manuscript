# -----------------------------------
# Script Information
# -----------------------------------
# Purpose: Extract raw met for an individual site
# Creator: Christy Rollinson, 1 July 2016
# Contact: crollinson@gmail.com
# -----------------------------------

# -----------------------------------
# Description
# -----------------------------------
# Extract raw met for a given site for model at different spatial & temporal scales 
# using get.raw function.
#  -- Funciton Arguments:
#     1. wd.base   = base path to the github repository; there should be subfolders of data & scripts
#     2. site.name = what you want to call the site you're extracting
#     3. lat       = latitude of the site you're extracting (N = positive, 0-90 degrees)
#     4. lon       = longitude of hte site you're processing (W = negative, -180 - 0 degrees)
#     5. ldas.type = whether to extract 3-hourly GLDAS or 1-hourly NLDAS data for the training data
#                     ** If the site is outside the lower 48, you must use GLDAS
#     6. GCM       = Which GCM you want to extract
#  -- Extracts/Processes 3 types of met data:
#     1. LDAS (NLDAS or GLDAS)
#         - Native Temporal Extent: 1980-2015
#         - Driver Usage: 1980-2015, raw
#     2. CRUNCEP
#         - Native Temporal Extent: 1901-2010
#         - Driver Usage: 1901-1979, bias-corrected, temp. downscaled
#     3. GCM
#         A. p1000 simulation
#            - Native Temporal Extent: 850-1850
#            - Driver Usage: 850-1849, bias-corrected, temp. downscaled
#         B. historical simulation
#            - Native Temporal Extent: 1850-2005
#            - Driver Usage: 1850-1900, bias-corrected, temp. downscaled
#  ** Met from each dataset will be saved in {wd.base}/data/paleon_sites/{site.name}
#  -- Function will check to see if each type of data has been done yet before processing
#  -- See get_point_raw.R for internal workflow & more details
# -----------------------------------
rm(list=ls())

# wd.base <- "~/Dropbox/PalEON_CR/met_ensemble"
# setwd(wd.base)

site.name = "WILLOWCREEK"
site.lat  =  45.805822 # 45°48′21″N
site.lon  = -90.079722 # 90°04′47″W
path.out = "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/data/Raw_Inputs/"

# Path to pecan repository where functions now live
path.pecan <- "~/Desktop/Research/pecan/"

# Download NLDAS (note: this is not a pecan script & requires fill LDAS stored somewhere locally)
source(file.path(path.pecan, "modules/data.atmosphere/R", "extract_local_NLDAS.R"))
ldas.type = "NLDAS"
path.nldas = "/Volumes/Celtis/Meteorology/LDAS/NLDAS_FORA0125_H.002/netcdf/"
extract.local.NLDAS(outfolder=file.path(path.out, site.name, "NLDAS"), in.path=path.nldas, 
                    start_date="1999-01-01", end_date="2014-12-31", 
                    site_id=site.name, lat.in=site.lat, lon.in=site.lon)

