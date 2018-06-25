# ed.dir <- "~/MetDownscaling_Manuscript/ED_runs/4_runs/ed_runs.v1/NLDAS_raw/analy"
sitelat =  45.805822
sitelon = -90.079722

# You'll need to make the following into a loop where both ed.dir and out.dir get changed ot be separate folders for each ensemble
# Some runs will have issues because of the start/end date in missing years (Ameriflux) and sims that didn't reach the end
start_date = "2000-01-01"
end_date   = "2014-12-31"

ed.dir <- "4_runs/ed_runs.v1/NLDAS_raw/analy/" # Where the raw data are
outdir <- "4_runs/extracted_output" # Where we want to save our output
if(!dir.exists(outdir)) dir.create(outdir)

# Runs a function (that we need to source)
source("model2netcdf.ed2.Downscaling.R")
model2netcdf.ED2.MetDownscaling(ed.dir, outdir, sitelat, sitelon, start_date, end_date, pft_names = NULL, ed.freq="I")
