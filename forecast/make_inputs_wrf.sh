#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.2
#
# Version - 1.2 Wed May 06 2015
# Version - 1.1 Wed Jul 23 2014
# Version - 1.0 Sun Feb 23 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`

# nPROCS: the number of processors to be used to run "metgrid" and "real"
# CLEANUP > 0: to remove the intermediate "work" directories
nPROCS=
CLEANUP=
# USE_PARALLEL can be re-defined here if it is not desired to
# use the global setting
USE_PARALLEL=${USE_PARALLEL:-0}


#------------------------------------------------------------
# SOURCE THE FORECAST FUNCTIONS AND ENVIRONMENT FILES
if [ -f functions_cast ]; then
  source functions_cast
else
  echo " ### ERROR:: in ${scrNAME}"
  echo "     Cannot load the required file: functions_cast"
  echo "     Exiting now ..."
  echo
  exit 1
fi

if [ -f "${CAST_XENV}" ]; then
  source ${CAST_XENV}
else
  echo " ### ERROR:: in ${scrNAME}"
  echo "     The CAST_XENV environment variable is not set or"
  echo "     it points to a non-existing file"
  echo "       CAST_XENV = ${CAST_XENV:-UNDEF}"
  echo "     Exiting now ..."
  echo
  exit 1
fi
#------------------------------------------------------------


############################################################
##### Get possible command line arguments
ParseArgsCast "${@}"
############################################################

theMODEL="wrf"

if [ ${OcnSST:-0} -gt 0 ]; then
  DATA_TYPE="GFS SST"
  DATA_PFX="gfs_ hycom-sst_"
  DATA_SFX=".gr"
  DATE_EXPR="YMD YMD"
else
  DATA_TYPE="GFS"
  DATA_PFX="gfs_"
  DATA_SFX=".gr"
  DATE_EXPR="YMD"
fi

#------------------------------------------------------------
# BEG:: Calculations

####################
# Check for required programs and scripts
TASK_PROG="${WpsDir:+${WpsDir}/}run-wps.sh"
TaskFound "${TASK_PROG}"

####################
# Generate the WRF inputs
echo "        Creating the \"`toUPPER ${theMODEL}`\" boundary and initial conditions files ..."

pushd ${WpsDir} >/dev/null
  GPARAL_JOBLOG="${LogDir}/${scrNAME%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir}/${scrNAME%%.*}-run.log"

  run-wps.sh --wpsdir="${WpsDir}"        \
             --start="${SimBeg}"         \
             --end="${SimEnd}"           \
             --datdir="${DataDir}"       \
             --datint="${DATA_INTERVAL}" \
             --dattype="${DATA_TYPE}"    \
             --datexpr="${DATE_EXPR}"    \
             --datpfx="${DATA_PFX}"      \
             --datsfx="${DATA_SFX}"      \
             --mods="${MODULE_FILES}"    \
             --nproc="${nPROCS}"         \
             --rmdir="${CLEANUP:-0}"     \
             --par="${USE_PARALLEL:-0}"  > ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?

  if [ ${FAILURE_STATUS} -ne 0 ]; then
    procError "failed to generate all the required WRF input files" \
              "check the log, is it due to lack of input data?"
  fi

  for idat in wrfbdy_d[0-9][0-9]*.nc wrflowinp_d[0-9][0-9]*.nc
  do
    if [ -f "${idat}" ]; then
     makeDIR "${BryDir}"
     mv -f "${idat}" "${BryDir}/"
    fi
  done

  for idat in wrfinput_d[0-9][0-9]*.nc
  do
    if [ -f "${idat}" ]; then
     makeDIR "${IniDir}"
     mv -f "${idat}" "${IniDir}/"
    fi
  done

  for idat in met_d[0-9][0-9]*.nc
  do
    if [ -f "${idat}" ]; then
     makeDIR "${OutDir}"
     mv -f "${idat}" "${OutDir}/atm_${idat}"
    fi
  done
popd >/dev/null

# END:: Calculations
#------------------------------------------------------------

exit ${FAILURE_STATUS:-0}
