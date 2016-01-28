#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.1
#
# Version - 1.1 Wed Jul 23 2014
# Version - 1.0 Sun Jul 20 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`


#------------------------------------------------------------
##### Variable relevant to this script
thisMODEL="HYCOM"
EXPT_HYCOM="expt_91.1"

# URL definitions for the required input data
#URL_HYCOM="http://tds.hycom.org/thredds/dodsC/datasets/GLBa0.08/${EXPT_HYCOM}/data"
#URL_HYCOM="/nexsan/GLBa0.08/${EXPT_HYCOM}/data"
URL_HYCOM="/hycom/ftp/datasets/GLBa0.08/${EXPT_HYCOM}/data"

export URL_HYCOM
#------------------------------------------------------------


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
ParseArgsCast "${@}"
############################################################


#------------------------------------------------------------
# BEG:: Calculations
FAILURE_STATUS=
theINPLIST=
theOUTLIST=

thisMODEL="$(echo ${thisMODEL} | tr [a-z] [A-Z])"
theSCRIPT="gather_${thisMODEL}_data"

############################################################
##### Gather the data for the current forecast
echo "        Downloading the \"${thisMODEL}\" data files ..."

pushd ${DataDir} >/dev/null
  GPARAL_JOBLOG="${LogDir}/${theSCRIPT%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir}/${theSCRIPT%%.*}-run.log"

  GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
  GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${DataDir} -j0"

  # Remove any old log files
  [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
  [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

  export GRIB_TYPE=
  MakeScript_ListsHYCOM ${theSCRIPT}
  [ $? -ne 0 ] && exit 1

  theINPLIST=${inpLIST}
  theOUTLIST=${outLIST}
  unset inpLIST outLIST

  ${GPARAL} ${GPARAL_OPTS} --xapply ${theSCRIPT} {1} {2} \
    ::: $(cat ${theINPLIST}) \
    ::: $(cat ${theOUTLIST}) >> ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?

  if [ ${FAILURE_STATUS} -eq 0 -a ${CLEANUP} -ge 1 ]; then
    echo "        Cleaning all \"${thisMODEL}\" related temporary files ..."
    for ilist in ${theINPLIST} ${theOUTLIST}
    do
      for ifile in $(cat ${ilist})
      do
        [ -f "${ifile}" ] && rm -f "${ifile}"
      done
      [ -f "${ilist}" ] && rm -f "${ilist}"
    done
    [ -f "${theSCRIPT}" ] && rm -f "${theSCRIPT}"
  fi
popd >/dev/null

for ilog in run status
do
  log_file="${LogDir}/${theSCRIPT%%.*}-${ilog}.log"
  stripESCFILE "${log_file}"
done

# END:: Calculations
#------------------------------------------------------------

exit ${FAILURE_STATUS:-0}
