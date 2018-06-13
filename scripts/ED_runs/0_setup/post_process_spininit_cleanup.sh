#!/bin/bash
# This script contains the post-runs workflow for extracting output and 
# cleaning up the history & analy files to save space
#
# Order of Opertations
# 1. Submit R extraction & start checking to see if it finished
# 2. Once it's no longer running, check to make sure the extraction actually finished
# (If finished safely) get rid of 
# 3. Get rid of extra histo files;
#    - keep 850, 1350, 1850, 2010 (names 1850, 2350, 2850, 3010)
# 4. tar analy files to save space

# Some useful names & paths
paleon_out=/dummy/path
SITE=TEST
job_name=post_TEST

# 1. submit job & check to see if it's running 
qsub submit_ED_extraction.sh

while true
do
	sleep 120 # check every 2 minutes
	runstat=$(qstat -j ${job_name} | wc -l)	
	
	if [[(("${runstat}" -eq 0))]]
	then
		# 2. Check to see if we have all output
		lastyear=`ls -l -rt ${paleon_out} | tail -1 | rev | cut -c4-7 | rev`
		
		if [[(("${lastyear}" -eq 1800))]]
		then
	    	echo 'Yay, things are working! Time to move on.'
	    	
	    	# don't do the clean up now because we need to do the 
	    	# SAS first
	    	sh cleanup_spininit.sh

	    	exit
		else
	    	echo 'Output extraction in R failed!'
	    	
	    	EMAIL_TXT=$(echo 'R extraction failed -- site' ${SITE} '!')
	    	fail_mail='fail_mail_R.txt'
    		echo $EMAIL_TXT >> $fail_mail
    		EMAIL_SUB=$(echo ${SITE}_'extraction_FAIL!')  

	    	mail -s $EMAIL_SUB crollinson@gmail.com < $fail_mail
	    	rm -f $fail_mail
	    	
	    	exit
		fi
	fi
	done
done
