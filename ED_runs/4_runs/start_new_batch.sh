#!bin/bash
# This file starts the next runID from the PalEON Regional ED Runs
# Christy Rollinson, crollinson@gmail.com

# Things to specify
# n          = Number of sites to start
# ED2IN_Base = template ED2IN to be modified
# file.dir   = spininit directory; used to find what sites have been done
# soil.path  = path of percent clay and percent sand to query for
#              SLXCLAY & SLXSAND, respectively
# grid.order = .csv file with the order sites should be run in to determine 
#              what sites should be done next


# Order of Operations
# 1) Sync file with order sites & status/location 
# 2) Add file directories for any sites that are remote so we don't repeat them
# 3) loop through the next n runID and adjust base ED2IN for specific characters
#    Things to be Modified per site:
#     -  NL%POI_LAT  =  
#     -  NL%POI_LON  = 
#     -  NL%FFILOUT = '~/ED_PalEON/MIP2_Region/1_spin_initial/phase2_spininit.v1/XXXXX/analy/XXXXX'
#     -  NL%SFILOUT = '~/ED_PalEON/MIP2_Region/1_spin_initial/phase2_spininit.v1/XXXXX/histo/XXXXX'
#     -  NL%SFILIN  = '~/ED_PalEON/MIP2_Region/1_spin_initial/phase2_spininit.v1/XXXXX/histo/XXXXX'
#     -  NL%SLXCLAY = 
#     -  NL%SLXSAND = 


## Load the necessary hdf5 library
# module load hdf5/1.6.10
# module load nco/4.3.4

# Define constants & file paths for the scripts
file_base=~/MetDownscaling_Manuscript/ED_runs/ # whatever you want the base output file path to be
EDI_base=/home/models/ED_inputs/ # The location of basic ED Inputs for you
met_base=/home/models/ED_MET/WILLOWCREEK.v2

ed_exec=/home/models/ED2/ED/build/ed_2.1-opt # Location of the ED Executable
file_dir=${file_base}/4_runs/ed_runs.v1/ # Where everything will go
setup_dir=${file_base}/0_setup/ # Where some constant setup files are
site_file=${setup_dir}/ED_Run_Priority.csv # # Path to list of ED sites w/ status

# # Lets double check and make sure the order status file is up to date
# # Note: need to make sure you don't have to enter a password for this to work right
# git fetch --all
# git checkout origin/master -- $site_file

finalyear=2015
finalfull=2014
n=2

# Making the file directory if it doesn't already exist
mkdir -p $file_dir

# Extract the file names of sites that haven't been started yet
sites_done=($(awk -F ',' 'NR>1 && $6!="" {print $3}' ${site_file})) # Get sites that have a location
runID=($(awk -F ',' 'NR>1 && $6=="" {print $3}' ${site_file}))
met=($(awk -F ',' 'NR>1 && $6=="" {print $2}' ${site_file}))


# for FILE in $(seq 0 (($n-1)))
for ((FILE=0; FILE<$n; FILE++)) # This is a way of doing it so that we don't have to modify N
do
	# Site Name and Lat/Lon
	SITE=${runID[FILE]}
	echo $SITE

	# -----------------------------------------------------------------------------
	# What needs to change:
	# 1. Met Header -- needs to go to specific GCM
	# 2. File paths -- need to point to specific dirictory
	# -----------------------------------------------------------------------------
	# -----------------------------------------------------------------------------


	# File Paths
    new_analy="'${file_dir}${SITE}/analy/${SITE}'"
    new_histo="'${file_dir}${SITE}/histo/${SITE}'"
    old_analy="'${file_dir}TEST/analy/TEST'"
    old_histo="'${file_dir}TEST/histo/TEST'"
    newbase=${file_dir}/$SITE
    oldbase=${file_dir}/TEST
	oldname=TESTinit
	met_path=${met_base}/${SITE}


	file_path=${file_dir}/${SITE}/

	mkdir -p ${file_path} 
	
	pushd ${file_path}
		# Creating the default file structure and copying over the base files to be modified
		mkdir -p histo analy
		ln -s $ed_exec
		cp ../../ED2IN_Base_MetManuscript ED2IN
		cp ${setup_dir}PalEON_Phase2.v1.xml .
		
		# ED2IN Changes	    
		sed -i "s,/dummy/path,${file_dir},g" ED2IN # set the file path
		sed -i "s,/met/path,${met_path},g" ED2IN # set the file path
	    sed -i "s,TEST,${SITE},g" ED2IN #change site ID


		# spin spawn start changes -- 
		# Note: spins require a different first script because they won't have any 
		#       histo files to read
		cp ${setup_dir}spawn_startloops_spinstart.sh .
		sed -i "s/USER=.*/USER=${USER}/" spawn_startloops_spinstart.sh
		sed -i "s/SITE=.*/SITE=${SITE}/" spawn_startloops_spinstart.sh 		
		sed -i "s/finalyear=.*/finalyear=${finalfull}/" spawn_startloops_spinstart.sh 		
	    sed -i "s,/dummy/path,${file_path},g" spawn_startloops_spinstart.sh # set the file path
	    sed -i "s,sub_post_process.sh,sub_post_process_spininit.sh,g" spawn_startloops_spinstart.sh # set the file path

		# spawn restarts changes
		cp ${setup_dir}spawn_startloops.sh .
		sed -i "s/USER=.*/USER=${USER}/" spawn_startloops.sh
		sed -i "s/SITE=.*/SITE=${SITE}/" spawn_startloops.sh 		
		sed -i "s/finalyear=.*/finalyear=${finalfull}/" spawn_startloops.sh 		
	    sed -i "s,/dummy/path,${file_path},g" spawn_startloops.sh # set the file path
	    sed -i "s,sub_post_process.sh,sub_post_process_spininit.sh,g" spawn_startloops.sh # set the file path

		# adjust integration step changes
		cp ${setup_dir}adjust_integration_restart.sh .
		sed -i "s/USER=.*/USER=${USER}/" adjust_integration_restart.sh
		sed -i "s/SITE=.*/SITE=${SITE}/" adjust_integration_restart.sh 		
		
#  		sh spawn_startloops_spinstart.sh
	popd	

	chmod -R a+rwx ${file_path}

done

# git stash # stash the pulled file so we don't get confilcts

