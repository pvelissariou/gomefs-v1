#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.3
#
# Version - 1.3 Fri Apr 24 2015
# Version - 1.2 Sun Aug 03 2014
# Version - 1.1 Sun Feb 23 2014
# Version - 1.0 Wed Jul 25 2012

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0`

scrDIR=`dirname $0`
[ "X${scrDIR}" = "X." ] && scrDIR="`pwd`"


#------------------------------------------------------------
# SOURCE THE WPS FUNCTIONS
if [ -f functions_wps ]; then
  source functions_wps
else
  echo " ### ERROR:: in ${scrNAME}"
  echo "     Cannot load the required file: functions_wps"
  echo "     Exiting now ..."
  echo
  exit 1
fi

if [ -f "wps_env" ]; then
  source wps_env
fi
#------------------------------------------------------------


############################################################
##### Get possible command line arguments
SimBeg="${SimBeg:-}"
SimEnd="${SimEnd:-}"

  EXTRA_REC_BEFORE="$( getPosInteger "${EXTRA_REC_BEFORE}" )"
EXTRA_REC_BEFORE=${EXTRA_REC_BEFORE:-0}
  EXTRA_REC_AFTER="$( getPosInteger "${EXTRA_REC_AFTER}" )"
EXTRA_REC_AFTER=${EXTRA_REC_AFTER:-0}

# The directory under which the geog data are stored
GEOG_DIR="${GEOG_DIR:-DATA-GEOG}"

# The directory under which the data are stored. This script searches
# for data in DATA_DIR, DATA_DIR/YEAR, DATA_DIR/YEAR/MONTH
# to find data. In the first occurence of a relevant dataset the
# script quits the search
DATA_DIR="${DATA_DIR:-Data}"

# The time interval between data records (hours)
# Ex., 3, 6, ... 24 (maximum)
DATA_INTERVAL="${DATA_INTERVAL:-}"

# The prefix in the &ungrib section in the namelist.wps file.
# Also the type of the corresponding VTable
DATA_TYPE="${DATA_TYPE:-GFS}"

# The prefix used in the data files (if any), the script will
# search for all files starting with the following prefix.
DATA_PFX="${DATA_PFX:-gfs_}"

# This will construct a regular expression for the date part of the input datafiles
DATE_EXPR="${DATE_EXPR:-YMDH}"

# The suffix used in the data files (if any), the script will
# search for all files ending with the following suffix.
DATA_SFX="${DATA_SFX:-.gr}"

# The suffix to be used when searching for Vtable files in 
# the Variable_Tables directory.
# The scripts will make a link from Variable_Tables/Vtable.${VTABLE_SFX}
# to Vtable. If VTABLE_SFX is empty, then the script will use
# the value of DATA_TYPE.
VTABLE_SFX="${VTABLE_SFX:-}"

# Check if the user supplied the environment modules to be used
MODFILES="${MODFILES:-}"

# Check if the user supplied the number of cpus to be used,
# an empty (undefined) NCROCS means that the code(s) will run in serial
NPROCS="${NPROCS:-}"

# Check if the user supplied a hostfile (machinefile) to be used,
# when the code(s) are run in parallel using MPI
HOSTFILE="${HOSTFILE:-}"

# Check if the user requested to remove the work directory
REMOVE_DIR="${REMOVE_DIR:-0}"

# Check if the user requested to use GNU Parallel for the calculations
USE_PARALLEL="${USE_PARALLEL:-0}"

# Command line arguments, they overwrite the above or in the environment
# set parameter values
ParseArgsWps "$@"
############################################################


# ============================================================
# Ideally you won't have to modify anything below
# ============================================================

########## BEG:: Check the input variables.
#
runWPS="run-wps_sequence.sh"
WPS_DIR="${WPS_DIR:-${scrDIR}}"

if ! `checkFILE -r "${WPS_DIR}/${runWPS}"`; then
  procError "can not find the required file:" \
            "REQ_FILE = ${WPS_DIR}/${runWPS}" \
            "is ${WPS_DIR} a valid WPS directory?" \
            "or ${WPS_DIR}/${runWPS} is missing?"
fi

wrfNListFile="namelist.input"
wpsNListFile="namelist.wps"
DateFile="date.dat"


GPARAL="${GPARAL:-parallel}"
GPARAL_OPTS_GLB="${GPARAL_OPTS_GLB:--gnu --no-run-if-empty -vv --verbose --progress --halt 1}"
GPARAL_OPTS_SSH="${GPARAL_OPTS_SSH:--filter-hosts --slf ..}"
GPARAL_OPTS_TIME="${GPARAL_OPTS_TIME:--timeout 3600}"
GPARAL_OPTS_RESUME="${GPARAL_OPTS_RESUME:--resume-failed --retries 1}"


#----------
# Check if the user supplied valid simulation "start" and "end" dates
myTmpVal="${SimBeg:-UNDEF}"
SimBeg="$( getDate --date="${myTmpVal}" --fmt="%F %T" )"
if [ $? -ne 0 ]; then
  procError "the supplied date for the start of the simulation is not valid" \
            "SimBeg = ${myTmpVal}"
fi

myTmpVal="${SimEnd:-UNDEF}"
SimEnd="$( getDate --date="${myTmpVal}" --fmt="%F %T" )"
if [ $? -ne 0 ]; then
  procError "the supplied date for the start of the simulation is not valid" \
            "SimEnd = ${myTmpVal}"
fi

b_jul=$( getDate --date="${SimBeg}" --fmt='+%s' )
e_jul=$( getDate --date="${SimEnd}" --fmt='+%s' )
if [ ${e_jul} -le ${b_jul} ]; then
  procError "wrong \"end\" date for the simulation: SimEnd >= SimBeg." \
            "SimBeg = ${SimBeg}" \
            "SimEnd = ${SimEnd}"
fi

unset myTmpVal b_jul e_jul
#----------


#----------
# Check if the user supplied a valid directory for the WRF/WPS geo data
if ! `checkDIR -rx "${GEOG_DIR}"` ; then
  procError "not a valid directory for the WPS geo data" \
            "GEOG_DIR = ${GEOG_DIR:-UNDEF}"
fi
#----------


#----------
# Check if the user supplied valid data types
# Make all variables to be arrays (the length is to be the same
# as the length of DATA-TYPE, this is done in the function getDataTypeWps)
getDataTypeWps "${DATA_TYPE}" "${VTABLE_SFX}"

DATA_TYPE=( ${DATA_TYPE} )
VTABLE_SFX=( ${VTABLE_SFX} )
VTABLE_NAME=( ${VTABLE_NAME} )
#----------


#----------
# Check if the user supplied multiple and valid data directories
# for the different data types
if [ -z "${DATA_DIR}" ]; then
  procError "need to specify the director(ies) where the data are stored" \
            "DATA_DIR  = ${DATA_DIR:-UNDEF}"
fi

myTmpVal=( ${DATA_DIR} )
for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
do
  idx=${ityp}
  [ -z "${myTmpVal[${idx}]}" ] && idx=$(( ${ityp} - 1))
  DATA_DIR[${ityp}]="${myTmpVal[${idx}]}"

  # Check if this is a valid directory for the input data
  if ! `checkDIR -rx "${DATA_DIR[${ityp}]}"` ; then
    procError "not a valid directory for the WPS input data" \
              "DATA_DIR = ${DATA_DIR[${ityp}]}"
  fi
done
DATA_DIR=( ${DATA_DIR[@]:0:${#DATA_TYPE[@]}} )

unset myTmpVal
#----------


#----------
# Check if the user supplied date interval falls between 0 and 23:
# 0 < DATA_INTERVAL <= 23
myTmpVal="${DATA_INTERVAL:-UNDEF}"
DATA_INTERVAL="$( getPosInteger "${DATA_INTERVAL}" )"
if [ -n "${DATA_INTERVAL:+1}" ]; then
  if [ "${DATA_INTERVAL}" -le 0 -o "${DATA_INTERVAL}" -gt 23 ]; then
    procError "the supplied data interval (hours) between the data records" \
              "should be between: 0< DATA_INTERVAL <=23" \
              "DATA_INTERVAL = ${myTmpVal}"
  fi
else
  DATA_INTERVAL=6
fi
unset myTmpVal
#----------


#----------
# Check if the user supplied prefixes for the datafiles
# and create the names for the data list files
DATA_PFX=( ${DATA_PFX} )
DATA_PFX=( ${DATA_PFX[@]:0:${#DATA_TYPE[@]}} )
for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
do
  if [ -z "${DATA_PFX[${ityp}]}" ]; then
    procError "a prefix for the input data filenames need to be provided" \
              "this prefix is used to identify the files in the data directory" \
              "DATA_DIR  = ${DATA_DIR[${ityp}]:-UNDEF}" \
              "DATA_TYPE = ${DATA_TYPE[${ityp}]:-UNDEF}" \
              "DATA_PFX  = ${DATA_PFX[${ityp}]:-UNDEF}"
  fi
  datListFile[${ityp}]="data_${DATA_TYPE[${ityp}]}.list"
done
#----------


#----------
# Check if the user supplied the date expressions in the datafile names
# for the different data types
if [ -z "${DATE_EXPR}" ]; then
  procError "need to specify the date expression(s) in the datafile names" \
            "one of: YMDH YMD MDYH MDY DMYH DMY YJH YJ" \
            "DATE_EXPR = ${DATE_EXPR:-UNDEF}"
fi

myTmpVal=( ${DATE_EXPR} )
for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
do
  idx=${ityp}
  [ -z "${myTmpVal[${idx}]}" ] && idx=$(( ${ityp} - 1))
  DATE_EXPR[${ityp}]="${myTmpVal[${idx}]}"
done
DATE_EXPR=( ${DATE_EXPR[@]:0:${#DATA_TYPE[@]}} )

unset myTmpVal
#----------


#----------
# Check if the user supplied suffixes for the datafiles
if [ -z "${DATA_SFX}" ]; then
  procError "need to specify the sufix(es)/extension(s) for the datafiles" \
            "DATA_SFX  = ${DATA_SFX:-UNDEF}"
fi

myTmpVal=( ${DATA_SFX} )
for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
do
  idx=${ityp}
  [ -z "${myTmpVal[${idx}]}" ] && idx=$(( ${ityp} - 1))
  DATA_SFX[${ityp}]="${myTmpVal[${idx}]}"
done
DATA_SFX=( ${DATA_SFX[@]:0:${#DATA_TYPE[@]}} )

unset myTmpVal
#----------


#----------
# The names of the modulefiles to load (if any).
# If during compilation modules were used to set the paths
# of the compilers/libraries then, the same modules should
# be used/loaded at runtime as well.
#
# Load the requested modules.
if [ -n "${MODFILES:+1}" ]; then
  chkMOD="`which modulecmd 2>&1 | grep -vEi "no.*modulecmd"`"
  if [ -n "${chkMOD:+1}" ]; then
    chkMOD="$(echo $(module -V 2>&1) | grep -vEi "not.*found")"
    [ -z "${chkMOD:-}" ] && module() { eval `modulecmd sh $*`; }
    for imod in ${MODFILES}
    do
      av_mod="$( module available "${imod}" 2>&1 | grep "${imod}" )"
      av_mod="$( echo "${av_mod}" | tr " " "\n" | grep "^${imod}$" )"
      if [ -z "${av_mod}" ]; then
        procError "the requested environment module is not available:" \
                  "  USER REQUESTED MODULE: ${imod}" \
                  "please check the MODFILES variable defined in this script:" \
                  "  MODFILES: ${MODFILES}"
      fi
    done
  fi
fi
#----------


#----------
# Check if the user supplied a valid number of cpus to be used
NPROCS="$( getPosInteger "${NPROCS:-0}" )"
[ "${NPROCS}" -le 0 ] && NPROCS=
#----------


#----------
# Check if the user requested to remove all working directories
# after the "end" of the simulation
REMOVE_DIR="$( getPosInteger "${REMOVE_DIR}" )"
REMOVE_DIR="${REMOVE_DIR:-0}"
#----------


#----------
# Check if the user requires the use of GNU parallel
# This makes sense only for multi-month simulation
USE_PARALLEL="$( getPosInteger "${USE_PARALLEL}" )"
USE_PARALLEL="${USE_PARALLEL:-0}"
#----------
#
########## END:: Check the input variables.


WPS_PRINT="$( getPosInteger "${WPS_PRINT}" )"
[ "${WPS_PRINT:-0}" -gt 0 ] && wps_print


######### BEG:: Check for required files and programs.
#
# -----Check for the namelist files.
NListFiles="${wrfNListFile} ${wpsNListFile}"
for iname in ${NListFiles}
do
  if [ ! -f ${iname}-tmpl ]; then
    procError "could not find the required namelist file:" \
              "NAMELIST_FILE = ${iname}-tmpl"
  fi
done
#-----


#----- Check for required programs.
wpsPROGS="geogrid.exe ungrib.exe metgrid.exe real.exe link_grib.csh"
for iname in ${scrNAME} ${runWPS} ${wpsPROGS}
do
  if ! `checkPROG -r "${iname}"`; then
    procError "can not find the required program:" \
              "REQ_PROG = ${iname:-UNDEF}"
  fi
done
unset iname
#-----
#
######### END:: Check for required files and programs.

# ============================================================


# WPS, "metgrid" and "real" require that "start", "end" simulation
# date hours are exactly defined in DATA_INTERVAL hours. If this is
# no the case then this script aborts.
# This is for SimBeg
sim_jul="$( getDate --date="${SimBeg}" --fmt='+%s' )"
my_date="$( getDate --date="${SimBeg}" --fmt='+%F 00:00:00' )"
my_jul="$( getDate --date="${my_date}" --fmt='+%s' )"
sim_beg_OK=0
while [ ${my_jul} -le ${sim_jul} ]
do
  [ ${my_jul} -eq ${sim_jul} ] && sim_beg_OK=1

  my_date="$( getDate --date="${my_date}" ) +${DATA_INTERVAL} hours"
  my_date="$( getDate --date="${my_date}" --fmt='+%F %T' )"
  my_jul="$( getDate --date="${my_date}" --fmt='+%s' )"
done
# This is for the SimEnd
sim_jul="$( getDate --date="${SimEnd}" --fmt='+%s' )"
my_date="$( getDate --date="${SimEnd}" ) +1 days"
my_date="$( getDate --date="${my_date}" --fmt='+%F 00:00:00' )"
my_jul="$( getDate --date="${my_date}" --fmt='+%s' )"
sim_end_OK=0
while [ ${my_jul} -ge ${sim_jul} ]
do
  [ ${my_jul} -eq ${sim_jul} ] && sim_end_OK=1

  my_date="$( getDate --date="${my_date}" ) -${DATA_INTERVAL} hours"
  my_date="$( getDate --date="${my_date}" --fmt='+%F %T' )"
  my_jul="$( getDate --date="${my_date}" --fmt='+%s' )"
done

if [ ${sim_beg_OK} -le 0 -o ${sim_end_OK} -le 0 ]; then
  procError "WPS requires that the hour specification in all simulation dates" \
            "should be an integral expression of the specified \"DATA_INTERVAL\"" \
            "DATA_INTERVAL = ${DATA_INTERVAL}" \
            "SimBeg        = ${SimBeg}" \
            "SimEnd        = ${SimEnd}"
fi


############################################################
##### BEG:: Calculations
############################################################

#----- Get the simulation start/end dates and break the simulation
#      length in monthly chunks (if the simulation length spans
#      more than one month)
#      See comments in the FirstLastDates funcion (in functions_common)
FirstLastDates "${SimBeg}" "${SimEnd}"
prev=( ${previousDATES} )
first=( ${firstDATES} )
last=( ${lastDATES} )
next=( ${nextDATES} )
unset previousDATES firstDATES lastDATES nextDATES
unset listWorkDirs

for ((idate = 0; idate < ${#first[@]}; idate++))
do
    tmp_str="$( echo "${first[${idate}]}" | sed -e 's/[;:,_\/-]/ /g' )"
  firstYR=$( echo "${tmp_str}" | awk '{print $1}' )
  firstMO=$( echo "${tmp_str}" | awk '{print $2}' )
  firstDA=$( echo "${tmp_str}" | awk '{print $3}' )
  firstHR=$( echo "${tmp_str}" | awk '{print $4}' )
  firstMN=$( echo "${tmp_str}" | awk '{print $5}' )
  firstSC="00"
    tmp_str="$( echo "${last[${idate}]}" | sed -e 's/[;:,_\/-]/ /g' )"
  lastYR=$( echo "${tmp_str}" | awk '{print $1}' )
  lastMO=$( echo "${tmp_str}" | awk '{print $2}' )
  lastDA=$( echo "${tmp_str}" | awk '{print $3}' )
  lastHR=$( echo "${tmp_str}" | awk '{print $4}' )
  lastMN=$( echo "${tmp_str}" | awk '{print $5}' )
  lastSC="00"
    tmp_str="$( echo "${prev[${idate}]}" | sed -e 's/[;:,_\/-]/ /g' )"
  prevYR=$( echo "${tmp_str}" | awk '{print $1}' )
  prevMO=$( echo "${tmp_str}" | awk '{print $2}' )
  prevDA=$( echo "${tmp_str}" | awk '{print $3}' )
  prevHR=$( echo "${tmp_str}" | awk '{print $4}' )
  prevMN=$( echo "${tmp_str}" | awk '{print $5}' )
  prevSC="00"
    tmp_str="$( echo "${next[${idate}]}" | sed -e 's/[;:,_\/-]/ /g' )"
  nextYR=$( echo "${tmp_str}" | awk '{print $1}' )
  nextMO=$( echo "${tmp_str}" | awk '{print $2}' )
  nextDA=$( echo "${tmp_str}" | awk '{print $3}' )
  nextHR=$( echo "${tmp_str}" | awk '{print $4}' )
  nextMN=$( echo "${tmp_str}" | awk '{print $5}' )
  nextSC="00"

  #----- For each "idate" create a work directory and perform
  #      all subsequent calculations in this directory. This
  #      is useful when parallel runs are performed.
  workDir="${WPS_DIR:+${WPS_DIR}/}workWPS_${firstYR}-${firstMO}-${firstDA}"
  listWorkDirs="${listWorkDirs} ${workDir}"
  MakeDeleteDirs "${workDir}"

  ####################
  ##### Copy all the required files into the "workDir"
  for iname in Geogrid_Tables Metgrid_Tables Variable_Tables
  do
    cp -rf ${iname} ${workDir}/${iname} 2>/dev/null
    if [ $? -ne 0 ]; then
      procError "could not copy the WRF/WPS Tables directory:" \
                "TABLE_DIR = ${iname:-UNDEF}"
    fi
  done

  for iname in ${NListFiles}
  do
    cp -f ${iname}-tmpl ${workDir}/${iname} 2>/dev/null
    if [ $? -ne 0 ]; then
      procError "could not copy the WRF/WPS namelist file:" \
                "FILE = ${iname:-UNDEF}"
    fi
    chmod 0644 ${workDir}/${iname}
  done

  for iname in ${wpsPROGS}
  do
    install -m 0755 ${iname} ${workDir}/${iname} 2>/dev/null
    if [ $? -ne 0 ]; then
      procError "could not install the WRF/WPS required program:" \
                "REQ_PROG = ${iname:-UNDEF}"
    fi
  done
  ####################


  ####################
  ##### Modify the namelist files found in the "workDir"
  pushd ${workDir} >/dev/null
    datesListFile=dates_file.list
    rm -f ${datesListFile} "*.list"

    unset wps_firstYR wps_firstMO wps_firstDA
    unset wps_firstHR wps_firstMN wps_firstSC
    unset wps_lastYR wps_lastMO wps_lastDA
    unset wps_lastHR wps_lastMN wps_lastSC

    ##### Check the namelist files for consistency
    checkNameLists

    ##### Get the number of the domains
    nDOMS="$( echo "`getNameListVar ${wrfNListFile} max_dom`" | awk '{print $3}' )"
    nDOMS="`getPosInteger "${nDOMS}"`"
    nDOMS="${nDOMS:-1}"

    ##### This is for the beginning of the simulation
    echo "${firstYR}-${firstMO}-${firstDA}_${firstHR}:${firstMN}:${firstSC}" > ${DateFile}

    ##### (A) The previous records (the extra previous data record, if data are found)
    if [ "${EXTRA_REC_BEFORE:-0}" -gt 0 ]; then
      unset dat_DIRS datFILES datFNAMES datFEXPR

      b_date="${prevYR}-${prevMO}-${prevDA} ${prevHR}:${prevMN}:${prevSC}"
      e_date="${firstYR}-${firstMO}-${firstDA} ${firstHR}:${firstMN}:${firstSC}"
      b_jul=$( getDate --date="${b_date}" --fmt='+%s' )
      e_jul=$( getDate --date="${e_date}" --fmt='+%s' )

      last_rec_date="$(echo "${e_date}" | sed 's/ /_/'g )"
      ndays="$(echo "scale=0; ( ${e_jul} - ${b_jul} ) / 86400.0" | bc -ql 2>/dev/null)"

      for ((iday = 0; iday <= ${ndays}; iday++))
      do
          advDA="$( getDate --date="${b_date}" ) +${iday} days"
        chkDATE="$( getDate --date="${advDA}" --fmt="+%Y %m %d %H" )"
        chkYR=$(echo "${chkDATE}" | awk '{print $1}' )
        chkMO=$(echo "${chkDATE}" | awk '{print $2}' )
        chkDA=$(echo "${chkDATE}" | awk '{print $3}' )
        chkHR=$(echo "${chkDATE}" | awk '{print $4}' )

        for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
        do
          dat_DIRS="${DATA_DIR[${ityp}]}
                    ${DATA_DIR[${ityp}]}/${chkYR}
                    ${DATA_DIR[${ityp}]}/${chkYR}/${chkMO}"

          datFEXPR="${DATA_PFX[${ityp}]}(.*)?$( getDateExpr ${DATE_EXPR[${ityp}]} ${chkYR} ${chkMO} ${chkDA} ${chkHR} )"
          datFEXPR="${datFEXPR}(.*)?${DATA_SFX[${ityp}]:+${DATA_SFX[${ityp}]}}(.*)?"
          datFNAMES="$( GetListGribDataFiles "${datFEXPR}" "${dat_DIRS}" )"

          # Output the data listing to the files
          for idat in ${datFNAMES}
          do
            date_str="$( grib_getTimeStamp "${idat}" )"
            date_str="$( echo "${date_str}" | awk '{print $1}' )"
            if [ -z "{date_str}" ]; then
              procError "can not determine the forecast date from the input file:" \
                        "FILE           = ${idat}" \
                        "DATE IN FILE   = ${date_str:-UNDEF}" \
                        "DATE REQUESTED = $( getDate --date"${chkYR}-${chkMO}-${chkDA}${chkHR:+ ${chkHR}}" --fmt="+%F %T" )"
            fi
            echo "${date_str} ${idat}" >> ${datListFile[${ityp}]}
          done
        done
      done
    fi # EXTRA_REC_BEFORE


    ##### (B) The current records
    unset dat_DIRS datFILES datFNAMES datFEXPR

    b_date="${firstYR}-${firstMO}-${firstDA} ${firstHR}:${firstMN}:${firstSC}"
    e_date="${lastYR}-${lastMO}-${lastDA} ${lastHR}:${lastMN}:${lastSC}"
    b_jul=$( getDate --date="${b_date}" --fmt='+%s' )
    e_jul=$( getDate --date="${e_date}" --fmt='+%s' )
    if [ ${e_jul} -lt ${b_jul} ]; then
      procError "wrong end date for the simulation: SimEnd >= SimBeg." \
                "first DATE = ${b_date}" \
                "last DATE  = ${e_date}"
    fi

    last_rec_date="$(echo "${e_date}" | sed 's/ /_/'g )"
    ndays="$(echo "scale=0; ( ${e_jul} - ${b_jul} ) / 86400.0" | bc -ql 2>/dev/null)"

    for ((iday = 0; iday <= ${ndays}; iday++))
    do
        advDA="$( getDate --date="${b_date}" ) +${iday} days"
      chkDATE="$( getDate --date="${advDA}" --fmt="+%Y %m %d %H" )"

      chkYR=$(echo "${chkDATE}" | awk '{print $1}' )
      chkMO=$(echo "${chkDATE}" | awk '{print $2}' )
      chkDA=$(echo "${chkDATE}" | awk '{print $3}' )
      chkHR=$(echo "${chkDATE}" | awk '{print $4}' )

      for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
      do
        dat_DIRS="${DATA_DIR[${ityp}]}
                  ${DATA_DIR[${ityp}]}/${chkYR}
                  ${DATA_DIR[${ityp}]}/${chkYR}/${chkMO}"

        datFEXPR="${DATA_PFX[${ityp}]}(.*)?$( getDateExpr ${DATE_EXPR[${ityp}]} ${chkYR} ${chkMO} ${chkDA} ${chkHR} )"
        datFEXPR="${datFEXPR}(.*)?${DATA_SFX[${ityp}]:+${DATA_SFX[${ityp}]}}(.*)?"
        datFNAMES="$( GetListGribDataFiles "${datFEXPR}" "${dat_DIRS}" )"

        if [ "X${datFNAMES:-}" = "X" ]; then
          procError "missing/invalid GRIB data files for date: ${chkYR}-${chkMO}-${chkDA}" \
                    "DATA_TYPE = ${DATA_TYPE[${ityp}]:-UNDEF}" \
                    "DATA_PFX  = ${DATA_PFX[${ityp}]:-UNDEF}" \
                    "checked for files(s): ${datFEXPR}" \
                    "     checked in dirs: ${dat_DIRS}"
        fi

        # Output the data listing to the files
        for idat in ${datFNAMES}
        do
          date_str="$( grib_getTimeStamp "${idat}" )"
          date_str="$( echo "${date_str}" | awk '{print $1}' )"
          if [ -z "{date_str}" ]; then
            procError "can not determine the forecast date from the input file:" \
                      "FILE           = ${idat}" \
                      "DATE IN FILE   = ${date_str:-UNDEF}" \
                      "DATE REQUESTED = $( getDate --date"${chkYR}-${chkMO}-${chkDA}${chkHR:+ ${chkHR}}" --fmt="+%F %T" )"
          fi
          echo "${date_str} ${idat}" >> ${datListFile[${ityp}]}
        done
      done
    done


    ##### (C) The next records (the extra next data record, if data are found)
    unset dat_DIRS datFILES datFNAMES datFEXPR

    b_date="${nextYR}-${nextMO}-${nextDA} ${nextHR}:${nextMN}:${nextSC}"
    e_date="${b_date}"
    if [ "${EXTRA_REC_AFTER:-0}" -gt 0 ]; then
      e_date="$( getDate --date="${b_date}" ) +1 days"
      e_date="$( getDate --date="${e_date}" --fmt="+%F %T" )"
    fi
    b_jul=$( getDate --date="${b_date}" --fmt='+%s' )
    e_jul=$( getDate --date="${e_date}" --fmt='+%s' )

    last_rec_date="$(echo "${e_date}" | sed 's/ /_/'g )"
    ndays="$(echo "scale=0; ( ${e_jul} - ${b_jul} ) / 86400.0" | bc -ql 2>/dev/null)"

    for ((iday = 0; iday <= ${ndays}; iday++))
    do
        advDA="$( getDate --date="${b_date}" ) +${iday} days"
      chkDATE="$( getDate --date="${advDA}" --fmt="+%Y %m %d %H" )"
      chkYR=$(echo "${chkDATE}" | awk '{print $1}' )
      chkMO=$(echo "${chkDATE}" | awk '{print $2}' )
      chkDA=$(echo "${chkDATE}" | awk '{print $3}' )
      chkHR=$(echo "${chkDATE}" | awk '{print $4}' )

      for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
      do
        dat_DIRS="${DATA_DIR[${ityp}]}
                  ${DATA_DIR[${ityp}]}/${chkYR}
                  ${DATA_DIR[${ityp}]}/${chkYR}/${chkMO}"

        datFEXPR="${DATA_PFX[${ityp}]}(.*)?$( getDateExpr ${DATE_EXPR[${ityp}]} ${chkYR} ${chkMO} ${chkDA} ${chkHR} )"
        datFEXPR="${datFEXPR}(.*)?${DATA_SFX[${ityp}]:+${DATA_SFX[${ityp}]}}(.*)?"
        datFNAMES="$( GetListGribDataFiles "${datFEXPR}" "${dat_DIRS}" )"

        # Output the data listing to the files
        for idat in ${datFNAMES}
        do
          date_str="$( grib_getTimeStamp "${idat}" )"
          date_str="$( echo "${date_str}" | awk '{print $1}' )"
          if [ -z "{date_str}" ]; then
            procError "can not determine the forecast date from the input file:" \
                      "FILE           = ${idat}" \
                      "DATE IN FILE   = ${date_str:-UNDEF}" \
                      "DATE REQUESTED = $( getDate --date"${chkYR}-${chkMO}-${chkDA}${chkHR:+ ${chkHR}}" --fmt="+%F %T" )"
          fi
          echo "${date_str} ${idat}" >> ${datListFile[${ityp}]}
        done
      done
    done


    ##### (D) Sort the data files and the data dates in ascending order
    for ((ityp=0; ityp<${#DATA_TYPE[@]}; ityp++))
    do
      # sort the data filenames according to the data dates
      cat ${datListFile[${ityp}]} | sort -k 1 -u > ${datListFile[${ityp}]}.tmp
      mv -f ${datListFile[${ityp}]}.tmp ${datListFile[${ityp}]}

      # eliminate the data filenames beyond the "last_rec_date"
      nl=$( grep -n "${last_rec_date}" ${datListFile[${ityp}]} | awk -F: '{print $1}' )
      head -n ${nl} ${datListFile[${ityp}]} > ${datListFile[${ityp}]}.tmp
      mv -f ${datListFile[${ityp}]}.tmp ${datListFile[${ityp}]}

      # create the file that contains only the dates of the data
      awk '{ print $1 }' ${datListFile[${ityp}]} >> ${datesListFile}

      # modify the "datListFile" files to only contain the data filenames
      awk '{ print $2 }' ${datListFile[${ityp}]} >> ${datListFile[${ityp}]}.tmp
      mv -f ${datListFile[${ityp}]}.tmp ${datListFile[${ityp}]}
    done
    # finally re-sort the dates in datesListFile to be used below
    cat ${datesListFile} | sort -u > ${datesListFile}.tmp
    mv -f ${datesListFile}.tmp ${datesListFile}


    ##### (E) Modify the namelist files and start the calculations
    ##### WPS "start" and "end" dates
      tmp_str="$( head -n 1 ${datesListFile} | sed -e 's/[;:,_\/-]/ /g' )"
    wps_firstYR=$( echo "${tmp_str}" | awk '{print $1}' )
    wps_firstMO=$( echo "${tmp_str}" | awk '{print $2}' )
    wps_firstDA=$( echo "${tmp_str}" | awk '{print $3}' )
    wps_firstHR=$( echo "${tmp_str}" | awk '{print $4}' )
    wps_firstMN=$( echo "${tmp_str}" | awk '{print $5}' )
    wps_firstSC=$( echo "${tmp_str}" | awk '{print $6}' )
      tmp_str="$( tail -n 1 ${datesListFile} | sed -e 's/[;:,_\/-]/ /g' )"
    wps_lastYR=$( echo "${tmp_str}" | awk '{print $1}' )
    wps_lastMO=$( echo "${tmp_str}" | awk '{print $2}' )
    wps_lastDA=$( echo "${tmp_str}" | awk '{print $3}' )
    wps_lastHR=$( echo "${tmp_str}" | awk '{print $4}' )
    wps_lastMN=$( echo "${tmp_str}" | awk '{print $5}' )
    wps_lastSC=$( echo "${tmp_str}" | awk '{print $6}' )

    ##### WRF "start" and "end" dates
    extra_hours=$(( ${EXTRA_REC_BEFORE:-0} * ${DATA_INTERVAL} ))
      tmp_str="${firstYR}-${firstMO}-${firstDA} ${firstHR}:${firstMN}:${firstSC}"
      tmp_str="$( getDate --date="${tmp_str}" ) -${extra_hours} hours"
      tmp_str="$( getDate --date="${tmp_str}" --fmt="+%F %T" )"
      tmp_str="$( echo "${tmp_str}" | sed -e 's/[;:,_\/-]/ /g' )"
    wrf_firstYR=$( echo "${tmp_str}" | awk '{print $1}' )
    wrf_firstMO=$( echo "${tmp_str}" | awk '{print $2}' )
    wrf_firstDA=$( echo "${tmp_str}" | awk '{print $3}' )
    wrf_firstHR=$( echo "${tmp_str}" | awk '{print $4}' )
    wrf_firstMN=$( echo "${tmp_str}" | awk '{print $5}' )
    wrf_firstSC=$( echo "${tmp_str}" | awk '{print $6}' )

    extra_hours=$(( (${EXTRA_REC_AFTER:-0} + 1) * ${DATA_INTERVAL} ))
      tmp_str="${lastYR}-${lastMO}-${lastDA} ${lastHR}:${lastMN}:${lastSC}"
      tmp_str="$( getDate --date="${tmp_str}" ) +${extra_hours} hours"
      tmp_str="$( getDate --date="${tmp_str}" --fmt="+%F %T" )"
      tmp_str="$( echo "${tmp_str}" | sed -e 's/[;:,_\/-]/ /g' )"
    wrf_lastYR=$( echo "${tmp_str}" | awk '{print $1}' )
    wrf_lastMO=$( echo "${tmp_str}" | awk '{print $2}' )
    wrf_lastDA=$( echo "${tmp_str}" | awk '{print $3}' )
    wrf_lastHR=$( echo "${tmp_str}" | awk '{print $4}' )
    wrf_lastMN=$( echo "${tmp_str}" | awk '{print $5}' )
    wrf_lastSC=$( echo "${tmp_str}" | awk '{print $6}' )

    ##### Prepare the namelist files
    # start_year
      ModifyNameListVar ${wrfNListFile} start_year   "${wrf_firstYR}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} start_year   "${wps_firstYR}" ${nDOMS}
    # start_month
      ModifyNameListVar ${wrfNListFile} start_month  "${wrf_firstMO}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} start_month  "${wps_firstMO}" ${nDOMS}
    # start_day
      ModifyNameListVar ${wrfNListFile} start_day    "${wrf_firstDA}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} start_day    "${wps_firstDA}" ${nDOMS}
    # start_hour
      ModifyNameListVar ${wrfNListFile} start_hour   "${wrf_firstHR}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} start_hour   "${wps_firstHR}" ${nDOMS}
    # start_minute
      ModifyNameListVar ${wrfNListFile} start_minute "${wrf_firstMN}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} start_minute "${wps_firstMN}" ${nDOMS}
    # start_second
      ModifyNameListVar ${wrfNListFile} start_second "${wrf_firstSC}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} start_second "${wps_firstSC}" ${nDOMS}

    # end_year
      ModifyNameListVar ${wrfNListFile} end_year     "${wrf_lastYR}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} end_year     "${wps_lastYR}" ${nDOMS}
    # end_month
      ModifyNameListVar ${wrfNListFile} end_month    "${wrf_lastMO}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} end_month    "${wps_lastMO}" ${nDOMS}
    # end_day
      ModifyNameListVar ${wrfNListFile} end_day      "${wrf_lastDA}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} end_day      "${wps_lastDA}" ${nDOMS}
    # end_hour
      ModifyNameListVar ${wrfNListFile} end_hour     "${wrf_lastHR}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} end_hour     "${wps_lastHR}" ${nDOMS}
    # end_minute
      ModifyNameListVar ${wrfNListFile} end_minute   "${wrf_lastMN}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} end_minute   "${wps_lastMN}" ${nDOMS}
    # end_second
      ModifyNameListVar ${wrfNListFile} end_second   "${wrf_lastSC}" ${nDOMS}
      ModifyNameListVar ${wpsNListFile} end_second   "${wps_lastSC}" ${nDOMS}

    # modify the data time interval variables
      int_sec="$(echo "scale=0; ( ${DATA_INTERVAL} * 3600 ) / 1" | bc -ql 2>/dev/null)"
      int_min="$(echo "scale=0; ( ${DATA_INTERVAL} * 60 ) / 1" | bc -ql 2>/dev/null)"
      
      ModifyNameListVar ${wrfNListFile} interval_seconds   "${int_sec}"
      ModifyNameListVar ${wpsNListFile} interval_seconds   "${int_sec}"
      ModifyNameListVar ${wrfNListFile} auxinput4_interval "${int_min}" ${nDOMS}

    # let WRF decide how it will distribute the processors
      ModifyNameListVar ${wrfNListFile} nproc_x "-1"
      ModifyNameListVar ${wrfNListFile} nproc_y "-1"

    # modify the rest of relevant variables
      ModifyNameListVar ${wpsNListFile} geog_data_path "${GEOG_DIR}"
  popd >/dev/null
  ####################
done


############################################################
##### Run run-wps_sequence.sh in parallel or serial
############################################################

##### Modify runWPS for variables: WPS_DIR, wrfNListFile,
#     wpsNListFile, datListFile, sstListFile, ...
ModifyAVar ${runWPS} WPS_DIR       "${WPS_DIR}"
ModifyAVar ${runWPS} wrfNListFile  "${wrfNListFile}"
ModifyAVar ${runWPS} wpsNListFile  "${wpsNListFile}"
ModifyAVar ${runWPS} DateFile      "${DateFile}"
ModifyAVar ${runWPS} X_DATA_TYPE   "${DATA_TYPE[*]}"
ModifyAVar ${runWPS} X_VTABLE_NAME "${VTABLE_NAME[*]}"
ModifyAVar ${runWPS} MODFILES      "${MODFILES}"
ModifyAVar ${runWPS} NPROCS        "${NPROCS}"
ModifyAVar ${runWPS} HOSTFILE      "${HOSTFILE}"
ModifyAVar ${runWPS} REMOVE_DIR    "${REMOVE_DIR:-0}"

echo
echo "Creating the WRF initial and boundary conditions files"
echo "Please wait ..."
echo

if [ ${USE_PARALLEL:-0} -gt 0 ]; then
  GPARAL_JOBLOG="${LogDir:+/}${scrNAME%%.*}-status.log"
  GPARAL_RUNLOG="${LogDir:+/}${scrNAME%%.*}-run.log"

  GPARAL_OPTS="${GPARAL_OPTS_GLB} ${GPARAL_OPTS_SSH} ${GPARAL_OPTS_TIME}"
  GPARAL_OPTS="${GPARAL_OPTS} --joblog ${GPARAL_JOBLOG} ${GPARAL_OPTS_RESUME}"
  GPARAL_OPTS="${GPARAL_OPTS} --wd ${WPS_DIR} -j4"

 # Remove any old log files
  [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}
  [ -f ${GPARAL_JOBLOG} ] && rm -f ${GPARAL_JOBLOG}

  ${GPARAL} ${GPARAL_OPTS} ${runWPS} {} ::: $(echo ${listWorkDirs}) > ${GPARAL_RUNLOG} 2>&1
else
  for idir in ${listWorkDirs}
  do
    ${runWPS} ${idir}
    status=$?
    FAILURE_STATUS=$(( ${FAILURE_STATUS:-0} + ${status} ))
  done
fi

exit ${FAILURE_STATUS:-0}
