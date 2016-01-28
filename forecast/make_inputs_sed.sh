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

theMODEL="sed"
theDOM="${DOM_SED}"


#------------------------------------------------------------
# BEG:: Calculations
FAILURE_STATUS=

############################################################
##### Misc. script variables
ListIdlFiles=
ListBatchFiles=

############################################################
##### Create the IDL files for theMODEL
if [ ${NO_INI} -le 0 ]; then
  IdlFilesIni ${theMODEL} ${theDOM}
  ListIdlFiles="${ListIdlFiles} ${listIDL}"
  ListBatchFiles="${ListBatchFiles} ${listBATCH}"
  unset listIDL listBATCH
fi
if [ ${NO_BRY} -le 0 ]; then
  IdlFilesBry ${theMODEL} ${theDOM}
  ListIdlFiles="${ListIdlFiles} ${listIDL}"
  ListBatchFiles="${ListBatchFiles} ${listBATCH}"
  unset listIDL listBATCH
fi

############################################################
##### Check for the required IDL files
ListIdlFiles="$( strTrim "${ListIdlFiles}" 2 )"
ListBatchFiles="$( strTrim "${ListBatchFiles}" 2 )"
if [ "X${ListIdlFiles}" = "X" ]; then
  procError "no idl files were defined"
fi


############################################################
##### Run the parallel program
echo "        Creating the \"$(echo ${theMODEL} | tr [a-z] [A-Z])\" boundary and initial conditions files ..."

pushd ${IdlDir} >/dev/null
  GPARAL_JOBLOG="${LogDir}/${scrNAME%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir}/${scrNAME%%.*}-run.log"

  GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
  GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${IdlDir} -j0"

  # Remove any old log files
  [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
  [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

  # We cannot run parallel in the background, somehow remote jobs are not
  # killed properly when a failure occurs and subsequently parallel does not exit
  ${GPARAL} ${GPARAL_OPTS} ${IDL_CMD} {} ::: $(cat ${ListBatchFiles}) > ${GPARAL_RUNLOG} 2>&1
  FAILURE_STATUS=$?

  if [ ${FAILURE_STATUS} -eq 0 -a ${CLEANUP} -ge 1 ]; then
    echo "        Cleaning all INI/BRY related temporary files ..."
    for ilist in ${ListIdlFiles} ${ListBatchFiles}
    do
      for ifile in $(cat ${ilist})
      do
        [ -f "${ifile}" ] && rm -f "${ifile}"
      done
      [ -f "${ilist}" ] && rm -f "${ilist}"
    done
  fi
popd >/dev/null

if [ ${FAILURE_STATUS} -eq 0 ]; then
  imod="${theMODEL}"
  dom_str="_d`get2DString ${theDOM}`"

  pushd ${BryDir} >/dev/null
    for ityp in clim bry
    do
      for imo in {1..12}
      do
        regex="[1-9][0-9][0-9][0-9]"
        mo_str="`get2DString ${imo}`"
        files=( $( find . -mindepth 1 -maxdepth 1 -type f \
                         -iname "${imod}${ityp}${dom_str}_${regex}-${mo_str}*.nc" \
                         -exec basename {} \; | sort -u ) )
        if [ ${#files[@]} -ne 0 ]; then
          this_date="$( echo "${files[0]%%.*}" | sed -e "s@${imod}${ityp}${dom_str}_@@g" | sed -e 's/_/ /g' )"
          files="$( strTrim "${files[*]}" 2 )"
          file_stamp="$( date -d "${this_date}" "+%Y-%m-%d_%H:00:00" )"
          file_out="${imod}${ityp}${dom_str}_${file_stamp}.nc"
          ncrcat -h ${files} ${file_out}.tmp
          if [ $? -eq 0 ]; then
            rm -f ${files}
            mv -f ${file_out}.tmp ${file_out}
            link_stamp="$( date -d "${this_date}" "+%Y${mo_str}" )"
            linkFILE "${file_out}" "${imod}${ityp}${dom_str}-${link_stamp}.nc"
          fi
        fi
      done
    done
  popd >/dev/null

  pushd ${IniDir} >/dev/null
    for ityp in init
    do
      file_stamp="$( date -d "${SimBeg}" "+%Y-%m-%d_%H:00:00" )"
      file_out="${imod}${ityp}${dom_str}_${file_stamp}.nc"
      if [ -f "${file_out}" ]; then
        link_stamp="$( date -d "${SimBeg}" "+%Y%m" )"
        linkFILE "${file_out}" "${imod}${ityp}${dom_str}-${link_stamp}.nc"
      fi
    done
  popd >/dev/null
fi

for ilog in ${GPARAL_JOBLOG} ${GPARAL_RUNLOG}
do
  log_file="${ilog}"
  stripESCFILE "${log_file}"
done

# END:: Calculations
#------------------------------------------------------------

exit ${FAILURE_STATUS:-0}
