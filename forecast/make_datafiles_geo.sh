#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.0
#
# Version - 1.0 Sun Feb 23 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`

COMMON_FUNC="functions_common"

# CLEANUP > 0 means that the resulting temporary idl files
# will be removed after this script finishes its calculations
CLEANUP=1


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
SimBeg="${BegDate}"
SimEnd="${EndDate}"

ParseArgsCast "${@}"
############################################################


#------------------------------------------------------------
# BEG:: Calculations

############################################################
##### Misc. script variables
ListIdlFiles=
ListBatchFiles=

############################################################
##### ROMS model
IdlFilesGeo roms ${DOM_OCN}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### WRF model
IdlFilesGeo wrf ${DOM_WRF}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### SWAN model
IdlFilesGeo swan ${DOM_SWAN}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### SED model
IdlFilesGeo sed ${DOM_SED}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### Check for the required IDL files
ListIdlFiles="$( strTrim "${ListIdlFiles}" 2 )"
ListBatchFiles="$( strTrim "${ListBatchFiles}" 2 )"
if [ "X${ListIdlFiles}" = "X" ]; then
  echo "ERROR:: ${scrNAME}: ${scrNAME}: no idl files were defined"
  echo "        Exiting now ..."
  exit 1
fi

if [ -f "${COMMON_FUNC}" ]; then
  [ -f "${IdlDir}/${COMMON_FUNC}" ] && \
    rm -f "${IdlDir}/${COMMON_FUNC}"
  cp -f "${COMMON_FUNC}" ${IdlDir}/
fi

############################################################
##### Run the parallel program
echo "----- Generating the geo datafiles for the current forecast."
echo "        Running the jobs defined in \"${scrNAME}\" in parallel"
echo "        and waiting for them to finish ..."

echo "        Creating the \"geo\" files ..."
pushd ${IdlDir} >/dev/null
  scriptIDLJOBS="makegeofiles.sh"

  GPARAL_JOBLOG="${LogDir}/${scriptIDLJOBS%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir}/${scriptIDLJOBS%%.*}-run.log"

  GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
  GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${IdlDir} -j4"

  # Remove any old log files
  [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
  [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

  MakeScript_IdlGeo ${scriptIDLJOBS}
  [ $? -ne 0 ] && exit 1

  # We cannot run parallel in the background, somehow remote jobs are not
  # killed properly when a failure occurs and subsequently parallel does not exit
  ${GPARAL} ${GPARAL_OPTS} ${scriptIDLJOBS} {} ::: $(echo ${ListBatchFiles}) > ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?

  if [ ${FAILURE_STATUS:-0} -eq 0 -a ${CLEANUP} -ge 1 ]; then
    echo "        Cleaning all GEO related temporary files ..."
    for ilist in ${ListIdlFiles} ${ListBatchFiles}
    do
      for ifile in $(cat ${ilist})
      do
        [ -f "${ifile}" ] && rm -f "${ifile}"
      done
      [ -f "${ilist}" ] && rm -f "${ilist}"
    done
    [ -f "${scriptIDLJOBS}" ] && rm -f "${scriptIDLJOBS}"
    [ -f "${COMMON_FUNC}" ] && rm -f "${COMMON_FUNC}"
  fi
popd >/dev/null

for ilog in run status
do
  log_file="${LogDir}/${scriptIDLJOBS%%.*}-${ilog}.log"
  stripESCFILE "${log_file}"
done

############################################################
##### END:: Calculations
############################################################

exit ${FAILURE_STATUS:-0}
