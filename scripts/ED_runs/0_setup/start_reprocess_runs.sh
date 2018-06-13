#!/bin/bash

# This script cleans up all the spin initial & spin finish that happened before the 
# automated file management was included in the run scripts
file_base=/home/crollinson/ED_PalEON/MIP2_Region # whatever you want the base output file path to be
setup_dir=${file_base}/0_setup/


# ---------------------
# Clean up Runs
# ---------------------
runs_dir=${file_base}/4_runs/phase2_runs.v1/ 
# spininit_dir=${file_base}/1_spin_initial/phase2_spininit.v1/ 
finalruns=2851

pushd $runs_dir
	runs_done=(lat*)
popd

# ------- 
# Skip files that don't need to be re-processed
# ------- 
files_skip=(lat45.25lon-69.75)

for REMOVE in ${files_skip[@]}
do 
	runs_done=(${runs_done[@]/$REMOVE/})
done
# ------- 


for SITE in ${runs_done[@]}
do
    spath=${runs_dir}${SITE}

	pushd ${spath}
		cp ${setup_dir}sub_reprocess_runs.sh .
		cp ${setup_dir}reprocess_runs.sh .
		sed -i "s,TEST,post_${SITE},g" sub_reprocess_runs.sh # change job name
		sed -i "s,/dummy/path,${spath},g" sub_reprocess_runs.sh # set the file path
		sed -i "s/SITE=.*/SITE=${SITE}/" reprocess_runs.sh
		sed -i "s/job_name=.*/job_name=extract_${SITE}/" reprocess_runs.sh
		sed -i "s,/dummy/path,${spath}/${SITE}_paleon,g" reprocess_runs.sh # set the file path
	
		qsub sub_reprocess_runs.sh
	popd
done
# ---------------------
