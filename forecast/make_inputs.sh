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
  if [ ${NO_INI:-0} -le 0 ]; then
    MakeDeleteDirs "${IniDir}"
    [ $? -ne 0 ] && \
      procError "could not delete/create the directory: ${IniDir}"
  fi

  if [ ${NO_BRY:-0} -le 0 ]; then
    MakeDeleteDirs "${BryDir}"
    [ $? -ne 0 ] && \
      procError "could not delete/create the directory: ${BryDir}"
  fi
fi


#------------------------------------------------------------
# BEG:: Calculations
FAILURE_STATUS=

############################################################
##### Run the requested tasks in parallel
############################################################
ListOfTasks=

# Generate the ROMS model input data for the current forecast
if [ ${DOM_OCN:-0} -gt 0 ]; then
  TASK_PROG="make_inputs_roms.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

# Generate the WRF model input data for the current forecast
if [ ${DOM_WRF:-0} -gt 0 ]; then
  TASK_PROG="make_inputs_wrf.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

# Generate the SWAN model input data for the current forecast
if [ ${DOM_SWAN:-0} -gt 0 ]; then
  TASK_PROG="make_inputs_swan.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

# Generate the SED model input data for the current forecast
if [ ${DOM_SED:-0} -gt 0 ]; then
  TASK_PROG="make_inputs_sed.sh"
  TaskFound "${TASK_PROG}"
  ListOfTasks="${ListOfTasks} ${TASK_PROG}"
fi

ListOfTasks="$( strTrim "${ListOfTasks}" 2 )"

if [ -n "${ListOfTasks:+1}" ]; then
  ##### Run the requested tasks in parallel
  echo "----- Generating the initial and boundary conditions for the current forecast."
  echo "        Running the tasks defined in \"${scrNAME}\""
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

  ${GPARAL} ${GPARAL_OPTS} -q exec {} "${@}" \
    ::: $(echo ${ListOfTasks}) >> ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?
fi

# END:: Calculations
#------------------------------------------------------------

exit ${FAILURE_STATUS:-0}
