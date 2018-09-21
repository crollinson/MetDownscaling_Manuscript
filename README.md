# modeling_met_ensemble

## Overview:
This repository contains an R-based workflow to generate ensembles of continuous, hourly meteorology drivers for a to-be-submitted manuscript by Simkins, Rollinson, Dietze & Desai.
NOTE: This README is basically copy-pasted from the PalEON README where all this originated.

## Development

*We welcome contributions from any individual, whether code, documentation, or issue tracking.  All participants are expected to follow the [code of conduct](https://github.com/PalEON-Project/modeling_met_ensemble/blob/master/code_of_conduct.md) for this project.*

- Model Development Lead: Christy Rollinson, Forest Ecologist, Morton Arboretum (former PALEON postdoc at Boston University), crollinson@mortonarb.org**
- Model implementation lead: Jamkes Simkins, University of Delware (former PEcAn MS student at University of Wisconsin)
- Additional PIs: Mike Dietze (Boston University, PalEON/PEcAn), Ankur Desai (University of Wisconsin, PEcAn)

## Available Data

The following meteorological variables are available in our drivers (code, description, units):

| Variable | Description | Units |
| -------- | ----------- | ----- |
| tair | air temperature | K |
| precipf | hourly mean preciptiation rate | water equivalent, kg m<sup>-2</sup> s<sup>-1</sup> |
| swdown | incident shortwave radiation  | W m<sup>-2</sup> |
| lwdown | incident longwave radiation  | W m<sup>-2</sup> |
| press | surface pressure  | Pa |
| qair | specific humidity | kg kg<sup>-1</sup> |
| wind | wind speed | m s<sup>-1</sup> |

This particular implementation uses an Ameriflux tower (point; has missing data) as the basis of downscaling NLDAS (gridded, continuous coverage).
The routines were originally designed to generate met ensembles by extracting raw meteorology output for a single location from four different sources that have different native temporal and spatial resolutions and temporal extents: 

| Run | Temporal Range | Spatial Resolution | Temporal Resolution |
| -------- | ------ | ------------ | --------------- |
| CMIP5 p1000 runs | 850-1849 CE | variable spatial resolution | mostly daily output, radiation monthly | 
| CMIP5 historical | 1850-2010 |  variable spatial resolution | daily output |
| CRUNCEP | 1901-2010 | 0.5-degree spatial resolution | 6-hourly temporal resolution | 
| NLDAS | 1980-present | 0.125-degree spatial resolution | 1-hourly temporal resolution |

CMIP5 simulations include the following four GCMs had all required seven meteorological variables at daily resolution (except radiation) for the p1000 simulations and are included in our ensemble: bcc-csm1-1, CCSM4, MIROC-ESM, MPI-ESM-P.  Version 1 of the PalEON Phase 3 met ensemble uses output from the r1i1p1 scenario.  More information on CMIP5 can be found here: http://cmip-pcmdi.llnl.gov/cmip5/experiment_design.html and here: http://cmip-pcmdi.llnl.gov/cmip5/docs/cmip5_data_reference_syntax.pdf

Because the raw meteorology sources exist at different native resolutiosn and were generated through different methodologies, spatial and temporal downscaling is required to create continuous, sensible records without step-change shifts in climatology.  This is necessarily an uncertain process and this workflow generates ensembles from this uncertainty, propogating the uncertainty through time.  There are two steps for the generation of hourly meteorological forcing from the abvoe raw products:

1. **Spatial downscaling / climatological de-biasing & creation of continuous daily records —** This step uses high-resolution LDAS (Land Data Assimilation Systems) data to statistically adjust the climatic mean of datasets to match the adjacent datasets. This climate adjustment takes into account the seasonal (day of year) cycle and corrects for both potential incorrect seasonal patterns in GCMs. The bias-adjustment is determined by comparing either the available overlapping period of datasets or closest available 30 years.  For example, CRUNCEP was downscaled by comparing the climatic data for 1980-2010 between CRUNCEP and NLDAS whereas the climatology from 1820-1849 of CMIP5 p1000 simulations was compared to 1850-1879 CMIP5 historical simulation that had already been bias-corrected. This step uses covariance among meteorological variables to estimate the daily variability of lwdown, press, and wind in the CRUNCEP dataset (all assumed constant prior to 1950) and daily variability of wind, short-, and longwave radiation in the CMIP5 datasets (only available at monthly resolution). _primary script used: bias_correct_day.R_

2. **Temporal Downscaling to hourly records —** This step generates hourly meteorological values based on the observed hourly relationship between mean daily value, hour, and the last hour of the previous day seen in the NLDAS training data.  This step is applied in filter starting with the last day in the dataset (2015-12-31) and applied day by day towards the beginning of the dataset (850-01-01). This filter approach smooths over abrupt transitions at splice points and should reduce impossible jumps in meteorological forcing that might cause problems in ecosystem model simulations. _primary script used: temporal_downscale.R_
 
**NOTE: This repository is not a single function to be executed blindly.**  While I have tried to make flexible, generalized functions so that new or larger ensembles can be generated for anly location, this code should be considered in beta development.  Some of the raw met products will need to be stored locally while others can be scraped from remote servers, but it is a slow process.  Once all of the raw data products are in place, it takes about 5 days for all of the scripts to execute.  Eventually this met ensemble generation method will be incorporated into PEcAn, but that's still in development.  Talk to James Simpkins, Ankur Desai, and/or Mike Dietze for updates on the status of PEcAn integration.

The met ensemble generated by this work flow can be used to directly drive ecosystem models but it will also go through a data assimilation step for the full PalEON MIP Phase 3.  This part is still in development with J. Tipton & M. Hooten.  At the moment these drivers will be assimillated with Mann et al temperature anomaly reconstructions for the northern hemisphere and the North American Drought Atlas (Cook et al.)

## Workflow (how you should use this repository):
All scripts to be executed are in the "scripts/" directory.  Scripts are generally R-based and should generate the dependent file structures as you go (I think) [#]s scripts are the "qsub" scripts used to submit long jobs to the BU server.  If you clone/fork/branch this code for a different system, you will want to adjust these scripts for your particular system.  Many of the numbered R scripts will call generalized functions (scripts without numbers). If you're looking for the nuts & bolts of how each step is done, these are the scripts to look at.

***Update 2 August, 2017:** The under-the-hood functions are being migrated to PEcAn to increase flexibility and applicability of the script as well as add the feature ensemble meteorology generation to their data assimlation framework.  This is still in process.  Christy's development branch of PEcAn can be found here: https://github.com/crollinson/pecan/tree/met_downscaling*

*Upon completion, the met downscaling will be fully integrated with PEcAn and will be found here: https://github.com/PecanProject/pecan* 

**Description of Workflow Scripts/Steps**

1. **1_get_raw_site.R --** This will extract a single grid point from the base datasets for the specified lat & lon and attach a specified name or code (site.name).  This relies on the script _get_point_raw.R_ This script will first check to see if you've already downloaded/extracted each met product for your specified site.  If the data needs to be extracted, the appropriate function for will be used.  These extraction functions are located in "scripts/GetMet_Scripts/".  Downloading NLDAS data in particular is very slow, so you don't want to do this unless you have to.  **NOTE: This workflow currently requires you to have the GCMs downloaded and stored in the following file path "data/full_raw/[GCM]".**  The bash scripts 1_get_data_[GCM]_ceda.sh will download these in the appropraite locations, but you will need to register as a user on ceda first.

2. **2_aggregate_[Ameriflux/LDAS].R --** Aggregating raw, subdaily data to daily for the bias-correction step.  The code should theoretically run on subdaily data, but when I tried it, it was SLOOOOW and I lost patience, so I'm not *positive* that usage will be stable.

3. **3_bias_correct.R --** This does the corrections to adjust the climatological means of the different raw data products using the function _bias_correct_day.R_.  In the case of long- and shortwave radiation in GCMs, it also converts the raw monthly values into daily resolution by leveraging the covariance of radiation with other meteorological variables.  A similar method is used for the CRUNCEP variables that assume a constance value prior to 1950.  The general method used here is to first bias-adjust the seasonal climate cycle using a thin-plate regression spline and then to adjust the raw anomalies to (try to) maintain constant variance throughout the final 850-2010 temporal extent.  This isn't necessarily working perfectly, but it seems to work okay. See the above bit in the "Overview" section for a few more details. This is probably the most convoluted script and there's certainly room for improvement, so please ask if you have questions or suggestions!

4. **4_check_bias.R --** Quick QAQC of the bias correction before & after.

5. **5_generate_subdaily_models.R --** This is the step that generates a model of the diurnal cycle for each meteorological variable for each day of the year using the specified training dataset (NLDAS).  This only needs to be run once per location as the models are then saved to make the execution of the temporal downscaling easier. This step calls _temporal_downscale_functions.R_

6. **6_predict_subdaily_met.R --** This is the step that takes the daily ensembles generated in step 2 to hourly (or whatever the resolution of your specified training dataset it).  There are variants of this script (4a, 4b...) available to run each GCM separately to aid in parallelization and speed up ensemble member generation.  This step calls _temporal_downscale.R_  **The output from this step can be fed directly into model-specific met conversion functions such as those in PEcAn or that PalEON model contributors should have developed for their particular model**

7. **7_check_subdaily_met.R --** Quick QAQC graphs of the subdaily output.

**Note:**  In the PalEON implementation, I add additional steps to remove outliers.  Because this is the official evaluation of the method, we have left all ensemble members in so we can quantify the rate at which met vars leave the realm of sanity.
