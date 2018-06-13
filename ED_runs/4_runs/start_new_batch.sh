#!bin/bash
# This file starts the next cells from the PalEON Regional ED Runs
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
# 3) loop through the next n cells and adjust base ED2IN for specific characters
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

ed_exec=/home/models/ED2/ED/build/ed_2.1-opt # Location of the ED Executable
file_dir=${file_base}/4_runs/ed_runs.v1/ # Where everything will go
setup_dir=${file_base}/0_setup/ # Where some constant setup files are
site_file=${setup_dir}/Downscaling_RunPriority.csv # # Path to list of ED sites w/ status

# # Lets double check and make sure the order status file is up to date
# # Note: need to make sure you don't have to enter a password for this to work right
# git fetch --all
# git checkout origin/master -- $site_file

finalyear=2015
finalfull=2014
n=1

# Making the file directory if it doesn't already exist
mkdir -p $file_dir

# Extract the file names of sites that haven't been started yet
sites_done=($(awk -F ',' 'NR>1 && $6!="" {print $4}' ${site_file})) # Get sites that have a location
cells=($(awk -F ',' 'NR>1 && $6=="" {print $4}' ${site_file}))
lat=($(awk -F ',' 'NR>1 && $6=="" {print $3}' ${site_file}))
lon=($(awk -F ',' 'NR>1 && $6=="" {print $2}' ${site_file}))


# for FILE in $(seq 0 (($n-1)))
for ((FILE=0; FILE<$n; FILE++)) # This is a way of doing it so that we don't have to modify N
do
	# Site Name and Lat/Lon
	SITE=${cells[FILE]}
	echo $SITE

	lat_now=${lat[FILE]}
	lon_now=${lon[FILE]}

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


	file_path=${file_dir}/${SITE}/

	mkdir -p ${file_path} 
	
	pushd ${file_path}
		# Creating the default file structure and copying over the base files to be modified
		mkdir -p histo analy
		ln -s $ed_exec
		cp ../../ED2IN_Base_MetManuscript ED2IN
		cp ${setup_dir}PalEON_Phase2.v1.xml .
		
		if [[ "$SITE" == "NLDAS_raw" ]]
		then
			cp ${file_base}/0_setup/PL_MET_HEADER_NLDAS_RAW .
		else
			cp ${file_base}/0_setup/PL_MET_HEADER_HOURLY .
		fi

		# Make sure the file paths on the Met Header have been updated for the current file structure
		# Update Met Header
		### sed -i "s,$BU_base_spin,$file_base,g" ${file_base}/0_setup/PL_MET_HEADER
	    sed -i "s,TEST,${SITE},g" PL_MET_HEADER #change site ID

		# ED2IN Changes	    
		sed -i "s,/dummy/path,${file_path},g" ED2IN # set the file path
	    sed -i "s,TEST,${SITE},g" ED2IN #change site ID


		# spin spawn start changes -- 
		# Note: spins require a different first script because they won't have any 
		#       histo files to read
		cp ${setup_dir}spawn_startloops_spinstart.sh .
		cp ${setup_dir}sub_spawn_restarts_spinstart.sh .
		sed -i "s/USER=.*/USER=${USER}/" spawn_startloops_spinstart.sh
		sed -i "s/SITE=.*/SITE=${SITE}/" spawn_startloops_spinstart.sh 		
		sed -i "s/finalyear=.*/finalyear=${finalfull}/" spawn_startloops_spinstart.sh 		
	    sed -i "s,/dummy/path,${file_path},g" spawn_startloops_spinstart.sh # set the file path
	    sed -i "s,sub_post_process.sh,sub_post_process_spininit.sh,g" spawn_startloops_spinstart.sh # set the file path
	    sed -i "s,/dummy/path,${file_path},g" sub_spawn_restarts_spinstart.sh # set the file path
	    sed -i "s,TEST,check_${SITE},g" sub_spawn_restarts_spinstart.sh # change job name
        sed -i "s/h_rt=.*/h_rt=48:00:00/" sub_spawn_restarts_spinstart.sh # Sets the run time around what we should need

		# spawn restarts changes
		cp ${setup_dir}spawn_startloops.sh .
		cp ${setup_dir}sub_spawn_restarts.sh .
		sed -i "s/USER=.*/USER=${USER}/" spawn_startloops.sh
		sed -i "s/SITE=.*/SITE=${SITE}/" spawn_startloops.sh 		
		sed -i "s/finalyear=.*/finalyear=${finalfull}/" spawn_startloops.sh 		
	    sed -i "s,/dummy/path,${file_path},g" spawn_startloops.sh # set the file path
	    sed -i "s,sub_post_process.sh,sub_post_process_spininit.sh,g" spawn_startloops.sh # set the file path
	    sed -i "s,/dummy/path,${file_path},g" sub_spawn_restarts.sh # set the file path
	    sed -i "s,TEST,check_${SITE},g" sub_spawn_restarts.sh # change job name
        sed -i "s/h_rt=.*/h_rt=48:00:00/" sub_spawn_restarts_spinstart.sh # Sets the run time around what we should need

		# adjust integration step changes
		cp ${setup_dir}adjust_integration_restart.sh .
		cp ${setup_dir}sub_adjust_integration.sh .
		sed -i "s/USER=.*/USER=${USER}/" adjust_integration_restart.sh
		sed -i "s/SITE=.*/SITE=${SITE}/" adjust_integration_restart.sh 		
	    sed -i "s,/dummy/path,${file_path},g" sub_adjust_integration.sh # set the file path
	    sed -i "s,TEST,adjust_${SITE},g" sub_adjust_integration.sh # change job name
        sed -i "s/h_rt=.*/h_rt=24:00:00/" sub_adjust_integration.sh # Sets the run time around what we should need
		
#  		sh spawn_startloops_spinstart.sh
	popd	

	chmod -R a+rwx ${file_path}

done

# git stash # stash the pulled file so we don't get confilcts

