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
thisMODEL="GFS"

# URL definitions for the required input data
URL_GFS="http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod"

# The GFS data resolution to use
# For lower resolution use      -> -1 (not implemented)
# For 1.0 degree resolution use ->  0
# For 0.5 degree resolution use ->  1
# For higher resolution use     ->  2 (not implemented)
# Default: GFS_DATA_RESOL=1
GFS_DATA_RESOL=1

export URL_GFS GFS_DATA_RESOL
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
  MakeScript_ListsGFS ${theSCRIPT}
  [ $? -ne 0 ] && exit 1

  theINPLIST=${inpLIST}
  theOUTLIST=${outLIST}
  unset inpLIST outLIST

  ${theSCRIPT} ${theINPLIST} ${theOUTLIST}
  FAILURE_STATUS=$?

  if [ ${FAILURE_STATUS} -eq 0 -a ${CLEANUP} -ge 1 ]; then
    echo "        Cleaning all \"${thisMODEL}\" related temporary files ..."

    for ilist in ${theINPLIST} ${theOUTLIST}
    do
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
