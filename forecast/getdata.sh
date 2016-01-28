#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.1
#
# Version - 1.1 Wed Jul 23 2014
# Version - 1.0 Sun Feb 23 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`

COMMON_FUNC="functions_common"


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


if [ ${DOM_OCN:-0} -le 0 ] && \
   [ ${DOM_WRF:-0}  -le 0 ] && \
   [ ${DOM_SWAN:-0} -le 0 ] && \
   [ ${DOM_SED:-0}  -le 0 ]; then
  procError "need to define at least one model running this script as:" \
            "${scrNAME} --doms=\"dom1 dom2 dom3 dom4\"" \
            " where: dom1 >0 if ROMS is to be used" \
            "        dom2 >0 if WRF is to be used" \
            "        dom3 >0 if SWAN is to be used" \
            "        dom4 >0 if SED is to be used" \
            "MODELS_REQUESTED = [${DOM_OCN}, ${DOM_WRF}, ${DOM_SWAN}, ${DOM_SED}]"
fi

if [ ${REMOVE_DIR:-0} -gt 0 ]; then
  MakeDeleteDirs "${DataDir}"
  if [ $? -ne 0 ]; then
    procError "could not delete/create the directory: ${DataDir}"
  fi
fi

if [ -f "${COMMON_FUNC}" ]; then
  [ -f "${DataDir}/${COMMON_FUNC}" ] && \
    rm -f "${DataDir}/${COMMON_FUNC}"
  cp -f "${COMMON_FUNC}" ${DataDir}/
fi


#------------------------------------------------------------
# BEG:: Calculations

############################################################
##### Run the requested tasks in parallel
############################################################
ListOfTasks=

# Gather the data from the HYCOM model for the current forecast
if [ ${DOM_OCN:-0} -gt 0 ] || [ ${DOM_WRF:-0} -gt 0 ]; then
  TASK_PROG="getdata_hycom.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

# Gather the data from the GFS model for the current forecast
if [ ${DOM_WRF:-0} -gt 0 ]; then
  TASK_PROG="getdata_gfs.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

# Gather the data from the WWIII model for the current forecast
if [ ${DOM_SWAN:-0} -gt 0 ]; then
  TASK_PROG="getdata_ww3.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

# Gather the data from the WWIII model for the current forecast
if [ ${DOM_SED:-0} -gt 0 ]; then
  TASK_PROG="getdata_sed.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

ListOfTasks="$( strTrim "${ListOfTasks}" 2 )"

if [ -n "${ListOfTasks:+1}" ]; then
  ##### Run the requested tasks in parallel
  echo "----- Downloading the required data for the current forecast."
  echo "        Running the tasks defined in \"${scrNAME}\" in parallel"
  for itask in ${ListOfTasks}
  do
    echo "           Task: ${itask}"
  done
  echo "        and waiting for them to finish ..."

  GPARAL_JOBLOG="${LogDir}/${scrNAME%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir}/${scrNAME%%.*}-run.log"

  GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
  GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${CAST_ROOT} -j4"

  # Remove any old log files
  [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
  [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

  ${GPARAL} ${GPARAL_OPTS} exec {} "${@}" \
    ::: $(echo ${ListOfTasks}) >> ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?

  ##### Gather all the remaining supporting data for the current forecast
  if [ ${FAILURE_STATUS} -eq 0 ]; then
    echo "        Copying the supporting data files ..."

    for idir in bath weights
    do
      inp_dir="${CAST_DATA:+${CAST_DATA}/}${idir}"
      if [ ! -d "${inp_dir}" ]; then
        procError "could not find the directory that contains the supported data:" \
                  "DIRECTORY_SEARCHED = ${inp_dir}"
      fi

      MakeDeleteDirs "${DataDir}/${idir}"
      FAILURE_STATUS=$?

      cp -fr ${inp_dir}/* ${DataDir}/${idir}/
      FAILURE_STATUS=$?
    done
  fi

  if [ -f "${DataDir}/${COMMON_FUNC}" ]; then
    rm -f "${DataDir}/${COMMON_FUNC}"
  fi
fi

# END:: Calculations
#------------------------------------------------------------

exit ${FAILURE_STATUS:-0}
