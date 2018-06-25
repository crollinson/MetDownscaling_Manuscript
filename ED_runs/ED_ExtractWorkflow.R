# Sourcing some functions we need 
source("model2netcdf.ed2.Downscaling.R")
source("pecan.utils/metutils.R")
source("pecan.utils/utils.R")
mstmip_vars <- read.csv("pecan.utils/mstmip_vars.csv")
mstmip_local <- read.csv("pecan.utils/mstmip_local.csv")

# ed.dir <- "~/MetDownscaling_Manuscript/ED_runs/4_runs/ed_runs.v1/NLDAS_raw/analy"
sitelat =  45.805822
sitelon = -90.079722

# You'll need to make the following into a loop where both ed.dir and out.dir get changed to be separate folders for each ensemble
# Some runs will have issues because of the start/end date in missing years (Ameriflux) and sims that didn't reach the end


## Original
# ed.dir <- "4_runs/ed_runs.v1/NLDAS_raw/analy/" # Where the raw data are
# outdir <- "4_runs/extracted_output/NLDAS_raw" # Where we want to save our output
all.runs <- dir("4_runs/ed_runs.v1")
for(RUNID in all.runs){
  
  # -------
  # Set up dynamic file paths based on each site we're looping through
  # -------
  ed.dir <- file.path("4_runs/ed_runs.v1", RUNID, "analy") # Where the raw data are
  outdir <- file.path("4_runs/extracted_output", RUNID) # Where we want to save our output
  if(!dir.exists(outdir)) dir.create(outdir, recursive = T)
  # -------
  
  # -------
  # We now need to change start & end date as we go
  # This fixes the runs that never made it to 2014
  # -------
  ## Defaults
  # start_date = "2000-01-01"
  # end_date   = "2014-12-31"
  
  # get list of output files
  outfiles <- dir(ed.dir, ".h5")
  
  # Pulling out dates
  file.strng <- stringr::str_split(outfiles, "-") # splits name apart based on a -
  file.strng <- data.frame(matrix(unlist(file.strng), ncol=length(file.strng[[1]]), byrow = T)) # Converts a list to a matrix
  colnames(file.strng) <- c("runID", "type", "year", "month", "day", "time", "ext")
  file.strng$year <- as.numeric(paste(file.strng$year))
  file.strng$month <- as.numeric(paste(file.strng$month))
  file.strng$day <- as.numeric(paste(file.strng$day))
  summary(file.strng)

  # Define start & end dates
  start.yr <- min(file.strng[file.strng$month==1 & file.strng$day==1,"year"])
  start_date <- paste0(start.yr, "-01-01" )
  
  end.yr <- max(file.strng[file.strng$month==12 & file.strng$day==31,"year"])
  end_date <- paste0(end.yr, "-01-01" )
  # -------
  
  # Special cases we need to deal with
  # Ameriflux_raw is missing 2009
  # Easy Way: if(RUNID=="Ameriflux1"){
  # Hard (but more robust) way below
  yrs.expected <- start.yr:end.yr
  yrs.have <- unique(file.strng$year)
  if(all(yrs.expected %in% yrs.have)){ 
    # %in% compares vectors/arrays; a %in% b looks for each item of a in 
    # b regardless of order; numbers & dimensions can be mismatched 
    
    # For everything that is fine and not missing a year
    model2netcdf.ED2.MetDownscaling(ed.dir, outdir, sitelat, sitelon, start_date, end_date, pft_names = NULL, ed.freq="I")
  } else {
    # Find what year(s) we're missing
    yrs.gone <- yrs.expected[!yrs.expected %in% yrs.have]
    
    # Breaking exctraction into 2 parts based on what's missing 
    # (makes assumption all missing years are consequetive)
    # Getting everything before the break
    start.yr <- max(min(yrs.expected[yrs.expected<yrs.gone]), min(yrs.have[yrs.have<yrs.gone]))
    start_date <- paste0(start.yr, "-01-01" )
    
    end.yr <- min(max(yrs.expected[yrs.expected<yrs.gone]), max(yrs.have[yrs.have<yrs.gone]))
    end_date <- paste0(end.yr, "-01-01" )
    model2netcdf.ED2.MetDownscaling(ed.dir, outdir, sitelat, sitelon, start_date, end_date, pft_names = NULL, ed.freq="I")

    # Getting everything AFTER the break
    start.yr <- max(min(yrs.expected[yrs.expected>yrs.gone]), min(yrs.have[yrs.have>yrs.gone]))
    start_date <- paste0(start.yr, "-01-01" )
    
    end.yr <- min(max(yrs.expected[yrs.expected>yrs.gone]), max(yrs.have[yrs.have>yrs.gone]))
    end_date <- paste0(end.yr, "-01-01" )
    model2netcdf.ED2.MetDownscaling(ed.dir, outdir, sitelat, sitelon, start_date, end_date, pft_names = NULL, ed.freq="I")
    
  }
}
