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

theMODEL="roms"
theDOM="${DOM_OCN}"


#------------------------------------------------------------
# BEG:: Calculations

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
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${IdlDir} -j4"

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
  tmp_ext=${imod}_tmp

  FirstLastDates "${SimBeg}" "${SimEnd}"
  prev=( ${previousDATES} )
  first=( ${firstDATES} )
  last=( ${lastDATES} )
  next=( ${nextDATES} )
  unset previousDATES firstDATES lastDATES nextDATES

  pushd ${BryDir} >/dev/null
    for ityp in clim bry
    do
      all_files=
      for ((idate = 0; idate <= ${#first[@]}; idate++))
      do
          tmp_str="$( echo "${first[${idate}]}" | sed -e 's/[;:,_\/-]/ /g' )"
        firstYR=$( echo "${tmp_str}" | awk '{print $1}' )
        firstMO=$( echo "${tmp_str}" | awk '{print $2}' )
        firstDA=$( echo "${tmp_str}" | awk '{print $3}' )
        firstHR=$( echo "${tmp_str}" | awk '{print $4}' )

          tmp_str="$( echo "${last[${idate}]}" | sed -e 's/[;:,_\/-]/ /g' )"
        lastYR=$( echo "${tmp_str}" | awk '{print $1}' )
        lastMO=$( echo "${tmp_str}" | awk '{print $2}' )
        lastDA=$( echo "${tmp_str}" | awk '{print $3}' )
        lastHR=$( echo "${tmp_str}" | awk '{print $4}' )

        files=( $( find . -mindepth 1 -maxdepth 1 -type f \
                          -iname "${imod}${ityp}${dom_str}_${firstYR}-${firstMO}*.nc" \
                          -exec basename {} \; | sort -u ) )

        if [ "${lastMO}" != "${firstMO}" ]; then
          last_files=( $( find . -mindepth 1 -maxdepth 1 -type f \
                                 -iname "${imod}${ityp}${dom_str}_${lastYR}-${lastMO}-${lastDA}*.nc" \
                                 -exec basename {} \; | sort -u ) )
          files=( ${files[@]} ${last_files[@]:-} )
        fi
        all_files="${all_files} ${files[@]}"

        if [ ${#files[@]} -ne 0 ]; then
          files="$( strTrim "${files[*]}" 2 )"
          file_stamp="$( getDate --date="${firstYR}-${firstMO}-${firstDA} ${firstHR}" --fmt='+%Y-%m-%d_%H:00:00' )"
          file_out="${imod}${ityp}${dom_str}_${file_stamp}.nc"
          [ -f ${file_out}.${tmp_ext} ] && rm -f ${file_out}.${tmp_ext}
          ncrcat -O -h ${files} ${file_out}.${tmp_ext}
          FAILURE_STATUS=$?
        fi
      done

      if [ ${FAILURE_STATUS} -eq 0 ]; then
        all_files=$( strRmDuplicate "${all_files}" )
        [ -n "${all_files:+1}" ] && rm -f ${all_files}
        for ifile in ${imod}${ityp}${dom_str}_*.${tmp_ext}
        do
          if $( checkFILE -r "${ifile}" ); then
            mv -f ${ifile} ${ifile%.*}
          fi
        done
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
