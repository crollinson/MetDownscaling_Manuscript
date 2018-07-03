#!/bin/bash

# This script cleans up all the spin initial & spin finish that happened before the 
# automated file management was included in the run scripts
file_base=/home/cbutkiewicz/MetDownscaling_Manuscript/ED_runs # whatever you want the base output file path to be
setup_dir=${file_base}/0_setup/


# ---------------------
# Clean up Runs
# ---------------------
runs_dir=${file_base}/4_runs/ed_runs.v1/ 
finalruns=2014

pushd $runs_dir
	runs_done=(*)
popd

for SITE in ${runs_done[@]}
do
	pushd ${runs_dir}/$SITE
		# Put key history outputs into a new temporary folder
		mkdir histo2
		cp histo/*.xml histo2/ # settings file
		cp histo/*-1999-06-01* histo2/ # first
		cp histo/*-2010-01-01* histo2/ # 

		# Remove all the other history files
		rm -rf histo

		# rename the temporary histo folder
		mv histo2 histo

		# tar the analy files (J. Rollinson says .tar.bz2 is best)
		tar -jcvf analy.tar.bz2 analy

		# remove the uncompressed analy files
		rm -rf analy

		# make sure everyone has access to the files
		chmod -R a+rwx .
	popd
done
# ---------------------
