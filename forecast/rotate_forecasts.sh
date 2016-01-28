#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.0
#
# Version - 1.0 Sun Feb 23 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`

# The number of forecasts to retain (latest + previous)
# This number should always be greater than 0
KEEP_FCASTS=6

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
##### BEG:: Calculations
############################################################

echo "----- Rotating the forecasts."

KEEP_FCASTS=$( getPosInteger "${KEEP_FCASTS}" )

INP_FDIRS="${CAST_DATA} ${CAST_LOGS} ${CAST_PLOTS} ${CAST_OUT} ${CAST_WEB}"
regex="[1-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"

if [ ${KEEP_FCASTS:-0} -gt 0 ]; then
  for idir in ${INP_FDIRS}
  do
    pushd ${idir} >/dev/null
      fdirs=( $( find . -mindepth 1 -maxdepth 1 -type d -iname "${MODE_PFX}${regex}" \
                      -exec basename {} \; | sort -u -r ) )

      if [ ${#fdirs[@]} -gt 0 ]; then
        maxCNT="$( min "${KEEP_FCASTS} ${#fdirs[@]}" )"

        for icnt in  latest previous*; do
          [ -L "${icnt}" ] && rm -f "${icnt}"; done

        for ((icnt = 0; icnt < ${maxCNT}; icnt++))
        do
          if [ ${icnt} -eq 0 ]; then
            linkFILE "${fdirs[${icnt}]}" "latest"
          else
            linkFILE "${fdirs[${icnt}]}" "previous`get2DString ${icnt}`"
          fi
        done

        echo "        Keeping at most the \"${KEEP_FCASTS}\" latest ones in \"${idir}\""
        for ((icnt = ${maxCNT}; icnt < ${#fdirs[@]}; icnt++))
        do
          echo "          Deleting forecast: \"${fdirs[${icnt}]}\""
          deleteDIR "${fdirs[${icnt}]}"
        done
      fi
    popd >/dev/null
  done
else
  for idir in ${INP_FDIRS}
  do
    pushd ${idir} >/dev/null
      fdirs=( $( find . -mindepth 1 -maxdepth 1 -type d -iname "${MODE_PFX}${regex}" \
                      -exec basename {} \; | sort -u -r ) )

      if [ ${#fdirs[@]} -gt 0 ]; then
        maxCNT="$( min "99 ${#fdirs[@]}" )"
        for icnt in  latest previous*; do
          [ -L "${icnt}" ] && rm -f "${icnt}"; done

        for ((icnt = 0; icnt < ${maxCNT}; icnt++))
        do
          if [ ${icnt} -eq 0 ]; then
            linkFILE "${fdirs[${icnt}]}" "latest"
          else
            linkFILE "${fdirs[${icnt}]}" "previous`get2DString ${icnt}`"
          fi
        done
      fi
    popd >/dev/null
  done
fi

############################################################
##### END:: Calculations
############################################################

exit 0
