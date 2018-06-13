#!/bin/bash

# This script cleans up all the spin initial & spin finish that happened before the 
# automated file management was included in the run scripts
file_base=/home/crollinson/ED_PalEON/MIP2_Region # whatever you want the base output file path to be
setup_dir=${file_base}/0_setup/


# ---------------------
# Clean up Spin Initial
# ---------------------
spininit_dir=${file_base}/1_spin_initial/phase2_spininit.v1/ 
finalinit=2851

pushd $spininit_dir
	init_done=(lat*)
popd

# ------- 
# Skip files that we can't access, etc. for now
# ------- 
files_skip=(lat47.75lon-82.25 lat47.75lon-92.25 lat42.75lon-77.25 lat35.25lon-89.75 lat35.25lon-84.75 lat35.25lon-79.75) # Right now these are from Betsy and Ann
files_skip=(${files_skip[@]} lat35.25lon-94.75) # Add the one site I used as my test

for REMOVE in ${files_skip[@]}
do 
	init_done=(${init_done[@]/$REMOVE/})
done
# ------- 

for SITE in ${init_done[@]}
do
	echo $SITE

	#get dates of last histo file
    spath=${spininit_dir}${SITE}
    lastyear=`ls -l -rt ${spath}/histo| tail -1 | rev | cut -c21-24 | rev`

	# If the last year isn't the last year of the spin finish, don't do it for now
	if [[(("${lastyear}" < "${finalinit}"))]]
	then
		echo "  Site not done: $SITE"
		break # if it's not done, skip to the next item
	else
		pushd ${spath}
			cp ${setup_dir}sub_post_process_spininit_cleanup.sh .
			cp ${setup_dir}post_process_spininit_cleanup.sh .
	    	sed -i "s,TEST,post_${SITE},g" sub_post_process_spininit_cleanup.sh # change job name
	    	sed -i "s,/dummy/path,${spath},g" sub_post_process_spininit_cleanup.sh # set the file path
			sed -i "s/SITE=.*/SITE=${SITE}/" post_process_spininit_cleanup.sh 
			sed -i "s/job_name=.*/job_name=extract_${SITE}/" post_process_spininit_cleanup.sh 
			sed -i "s,/dummy/path,${spath}/${SITE}_paleon,g" post_process_spininit_cleanup.sh # set the file path

			cp ${setup_dir}submit_ED_extraction.sh .
			cp ${setup_dir}extract_output_paleon.R .
		    sed -i "s,TEST,extract_${SITE},g" submit_ED_extraction.sh # change job name
		    sed -i "s,/dummy/path,${spath},g" submit_ED_extraction.sh # set the file path
			sed -i "s/site=.*/site='${SITE}'/" extract_output_paleon.R
		    sed -i "s,/dummy/path,${spath},g" extract_output_paleon.R # set the file path
	    
			cp ${setup_dir}cleanup_spininit.sh .
			cp ${setup_dir}sub_cleanup_spininit.sh .
		    sed -i "s,/DUMMY/PATH,${spath}/,g" cleanup_spininit.sh # set the file path
			sed -i "s/SITE=.*/SITE=${SITE}/" cleanup_spininit.sh 		
		    sed -i "s/spin_last=.*/spin_last=${finalinit}/" cleanup_spininit.sh 		
		    sed -i "s,/dummy/path,${spath},g" sub_cleanup_spininit.sh # set the file path
		    sed -i "s,TEST,clean_${SITE}_spininit,g" sub_cleanup_spininit.sh # change job name
 		
	 		qsub sub_post_process_spininit_cleanup.sh
	 	popd
	fi		
done
# ---------------------
