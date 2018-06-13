#!/bin/bash

# This script cleans up files from the previous step to save space on the server
# Cleanup involves:
# 1. Deleting most history files (
#    - save the last one that we use to start the runs
#    - save the .xml file that has ALL the settings written
# 2. tar the analy files to save room
#
# NOTES: 
#  - Keep any & all log files untarred so we can can easily check settings etc. 
#  - do not tar the whole folder because that would screw up my referencing system
file_base=/home/crollinson/ED_PalEON/MIP2_Region # whatever you want the base output file path to be

SITE=latXXXlon-XXX
runs_dir=/DUMMY/PATH
lastyear=3011

pushd ${runs_dir}
	# Put key history outputs into a new temporary folder
	mkdir histo2
	cp histo/*.xml histo2/ # settings file
	cp histo/*-1850-01-01* histo2/ # first
	cp histo/*-2350-01-01* histo2/ # 500 yrs in
	cp histo/*-2850-01-01* histo2/ # Set Veg
	cp histo/*-S-$lastyear-01-01-* histo2/ # Final year

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
