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

# CONV_PLOTS_HERE > 0 means that the converion of the plot files
# is performed here and not within the idl program
CONV_PLOTS_HERE=1

# MAX_PAR_NJOBS >= 0 the maximum number of jobs per node
# to be launched if GNU parallel is used (4 is optimal)
MAX_PAR_NJOBS=4

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


if [ ${REMOVE_DIR:-0} -gt 0 ]; then
  MakeDeleteDirs "${PlotDir}"
  if [ $? -ne 0 ]; then
    procError "could not delete/create the directory: ${PlotDir}"
  fi
fi


############################################################
##### BEG:: Calculations
############################################################

############################################################
##### Misc. script variables
ListIdlFiles=
ListBatchFiles=

############################################################
##### ROMS model
IdlFilesMaps roms ${DOM_OCN}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### WRF model
IdlFilesMaps wrf ${DOM_WRF}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### SWAN model
IdlFilesMaps swan ${DOM_SWAN}
ListIdlFiles="${ListIdlFiles} ${listIDL}"
ListBatchFiles="${ListBatchFiles} ${listBATCH}"
unset listIDL listBATCH

############################################################
##### SED model
IdlFilesMaps sed ${DOM_SED}
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


############################################################
##### Run the parallel program
echo "----- Generating the map images for the current forecast."
echo "        Running the jobs defined in \"${scrNAME}\" in parallel"
echo "        and waiting for them to finish ..."

echo "        Creating the \"${PLOT_TYPE}\" files ..."

if [ -f "${COMMON_FUNC}" ]; then
  [ -f "${IdlDir}/${COMMON_FUNC}" ] && \
    rm -f "${IdlDir}/${COMMON_FUNC}"
  cp -f "${COMMON_FUNC}" ${IdlDir}/
fi

pushd ${IdlDir} >/dev/null
  scriptIDLJOBS="makeplot${PLOT_TYPE:+-${PLOT_TYPE}}.sh"

  GPARAL_JOBLOG="${LogDir}/${scriptIDLJOBS%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir}/${scriptIDLJOBS%%.*}-run.log"

  GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
  GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${IdlDir} -j${MAX_PAR_NJOBS:-4}"

  # Remove any old log files
  [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
  [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

  MakeScript_IdlPlots ${scriptIDLJOBS}
  [ $? -ne 0 ] && exit 1

  # We cannot run parallel in the background, somehow remote jobs are not
  # killed properly when a failure occurs and subsequently parallel does not exit
  ${GPARAL} ${GPARAL_OPTS} ${scriptIDLJOBS} {} ::: $(echo ${ListBatchFiles}) > ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?
popd >/dev/null

if [ ${CONV_PLOTS_HERE:-0} -gt 0 ]; then
  if [ ${FAILURE_STATUS:-0} -eq 0 ]; then
    echo "        Creating the \"${IMG_TYPE}\" files ..."

    if [ -f "${COMMON_FUNC}" ]; then
      [ -f "${PlotDir}/${COMMON_FUNC}" ] && \
        rm -f "${PlotDir}/${COMMON_FUNC}"
      cp -f "${COMMON_FUNC}" ${PlotDir}/
    fi

    pushd ${PlotDir} >/dev/null
      plot_dirs="`GetPlotDirs`"
      if [ "X${plot_dirs}" != "X" ]; then
        scriptIMGJOBS="makeimg${IMG_TYPE:+-${IMG_TYPE}}.sh"

        # For ImageMagick image conversion
        CONVERT_OPTS="-flatten -antialias -colorspace RGB -density 400 -geometry 29.40% -quality 100"

        GPARAL_JOBLOG="${LogDir}/${scriptIMGJOBS%%.*}-status.log"
        GPARAL_RUNLOG="${LogDir}/${scriptIMGJOBS%%.*}-run.log"

        GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
        GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
        GPARAL_OPTS="${GPARAL_OPTS} --wd ${PlotDir} -j${MAX_PAR_NJOBS:-4}"

        # Remove any old log files
        [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
        [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

        MakeScript_Images "${scriptIMGJOBS}"
        [ $? -ne 0 ] && exit 1

        # We cannot run parallel in the background, somehow remote jobs are not
        # killed properly when a failure occurs and subsequently parallel does not exit
        ${GPARAL} ${GPARAL_OPTS} ${scriptIMGJOBS} \
           ::: $(echo ${plot_dirs}) > ${GPARAL_RUNLOG} 2>&1
        FAILURE_STATUS=$?
      fi
    popd >/dev/null
  fi
fi

############################################################
##### Perform a cleanup of the temporary files
if [ "${CLEANUP}" -ge 1 ]; then
  echo "        Cleaning all the temporary files ..."
  pushd ${IdlDir} >/dev/null
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
  popd >/dev/null

  pushd ${PlotDir} >/dev/null
    [ -f "${scriptIMGJOBS}" ] && rm -f "${scriptIMGJOBS}"
    [ -f "${COMMON_FUNC}" ] && rm -f "${COMMON_FUNC}"
  popd >/dev/null
fi
####################

############################################################
##### END:: Calculations
############################################################

exit ${FAILURE_STATUS:-0}
