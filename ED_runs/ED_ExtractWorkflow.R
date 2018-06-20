# ed.dir <- "~/MetDownscaling_Manuscript/ED_runs/4_runs/ed_runs.v1/NLDAS_raw/analy"
ed.dir <- "4_runs/ed_runs.v1/NLDAS_raw/analy/"
outdir <- "4_runs/extracted_output"
if(!dir.exists(outdir)) dir.create(outdir)

sitelat =  45.805822
sitelon = -90.079722
start_date = "1999-06-01"
end_date   = "2014-12-31"

model2netcdf.ED2.MetDownscaling(ed.dir, outdir, sitelat, sitelon, start_date, end_date, pft_names = NULL, ed.freq="I")
