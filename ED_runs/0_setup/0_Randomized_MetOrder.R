# Generate a randomized priority list for Forward Runs
set.seed(1535)
site.name = "WILLOWCREEK"
vers=".v1"
site.lat  = 43.2309
site.lon  = -74.5267

# Creating a data frame with all of the information we need for our ensemble runs
# Priority 1: The two raw datasets (NLDAS, Ameriflux)
ed.runs <- data.frame(order=1:3, metEns=c("NLDAS_raw", rep("Ameriflux_raw", 2)), 
                      runID=c("NLDAS_raw", "Ameriflux_raw1", "Ameriflux_raw2"),
                      start.year = c(1999, 1999, 2000),
                      end.year = c(2014, 2008, 2004))

# Generate a list of all the hourly downscaled ensemble members we have
path.1hr <- "/Volumes/GoogleDrive/My Drive/Temporal Downscaling Group/Analyses/data/Downscaled_Outputs/WILLOWCREEK.v1/1hr/ensembles/"
ens.mems <- dir(path.1hr)

# Randomizing the ensemble members
set.seed(06141357) # Makes sure that every time we run this we keep our order
ens.mems <- sample(ens.mems)
runIDs <- matrix(unlist(stringr::str_split(ens.mems, "_")), nrow=length(ens.mems), byrow = T)[,3]

ed.runs2 <- data.frame(order=4:(3+length(ens.mems)), metEns=ens.mems, runID=paste0("TDM_", runIDs), start.year=1999, end.year=2014)

# Put the two lists together
ed.runs <- rbind(ed.runs, ed.runs2)
ed.runs$Status <- ""

write.csv(ed.runs, file.path("ED_Run_Priority.csv"), row.names=F, eol = "\r\n", na="")

