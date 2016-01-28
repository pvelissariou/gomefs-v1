# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.0
#
# Version - 1.0 Sun Feb 23 2014

#------------------------------------------------------------
# LOAD THE ENVIRONMENT FILE
#
if [ -f fcast_env ]; then
  . fcast_env
else
  echo " ### ERROR:: in GetData_GFS"
  echo "     Cannot locate the configuration file: fcast_env"
  echo "     Exiting now ..."
  echo
  exit 1
fi
#------------------------------------------------------------


if [ $# -lt 1 ]; then
  echo "ERROR:: getData_GFS: Need to define a valid date string."
  echo "        use: getData_GFS date_string"
  echo "        Exiting now ..."
  echo -n
  exit 1
fi


####################
# Check for some crucial variables
OutDir="${FCAST_DATA:-.}"
LogDir="${FCAST_LOGS:-.}"
WpsDir="${FCAST_WPS:-.}"

URL="${URL_GFS:-}"
if [ "X${URL:-}" = "X" ]; then
  echo " ### ERROR:: in getData_GFS"
  echo "     Need to define the URL_GFS variable"
  echo "       URL_GFS = ${URL_GFS:-UNDEFINED}"
  echo "     Exiting now ..."
  echo
  exit 1
fi
####################


####################
# Check for required programs and scripts
reqPROG="geogrid.exe ungrib.exe metgrid.exe real.exe run-wps.sh"

for iprog in ${reqPROG}
do
  if ! `checkPROG -r "${WpsDir:+${WpsDir}/}${iprog}"`; then
    echo " ### ERROR:: in getData_GFS"
    echo "     Failed to find the executable: ${WpsDir:+${WpsDir}/}${iprog}"
    echo "     Exiting now ..."
    exit 1
  fi
done
unset reqPROG
####################


####################
# The forecast times
FCAST_TIMES="0 6 12 18"
# The forecast time interval to be used
fcastINTRV=6
####################


####################
# Get the supplied date variables
getInpTimeStamp "${1}"

locYR=${myYR}
locMO=${myMO}
locDA=${myDA}
locHR=${myHR}
locMN=${myMN}
locSC=${mySC}
locYRStr="${myYRStr}"
locMOStr="${myMOStr}"
locDAStr="${myDAStr}"
locHRStr="${myHRStr}"
locMNStr="${myMNStr}"
locSCStr="${mySCStr}"
locDATE="${locYRStr}-${locMOStr}-${locDAStr} ${locHRStr}:${locMNStr}:${locSCStr}"

unset myYR myMO myDA myHR myMN mySC myJUL
unset myYRStr myMOStr myDAStr myHRStr myMNStr mySCStr myDATE
####################


####################
# Get the appropriate forecast time
for i in ${FCAST_TIMES}
do
  fdiff=$(( ${locHR} - i ))
  fHR=${i}
  [ ${fdiff} -eq 0 ] && break
  [ ${fdiff} -gt 0 -a ${fdiff} -lt ${fcastINTRV} ] && break
done

fcstYR=${locYR}
fcstMO=${locMO}
fcstDA=${locDA}
fcstHR=${fHR}
fcstMN=0
fcstSC=0
fcstYRStr="`getYearString ${fcstYR}`"
fcstMOStr="`get2DString ${fcstMO}`"
fcstDAStr="`get2DString ${fcstDA}`"
fcstHRStr="`get2DString ${fcstHR}`"
fcstMNStr="`get2DString ${fcstMN}`"
fcstSCStr="`get2DString ${fcstSC}`"
fcstDATE="${fcstYRStr}-${fcstMOStr}-${fcstDAStr} ${fcstHRStr}:${fcstMNStr}:${fcstSCStr}"
####################


backDAYS=5
BegDate=$( date -d "`date -d "${fcstDATE}"` -${backDAYS} days" '+%Y-%m-%d %H:%M:00' )
EndDate=$( date -d "`date -d "${fcstDATE}"`  ${backDAYS} days" '+%Y-%m-%d %H:%M:00' )


####################
# Get the previous and the next five days for the forecast
inpFNAMES=
outFNAMES=
datDates=

# Get the hindcast filenames
for ((iday = -${backDAYS}; iday < 0; iday++))
do
  myDate=$( date -d "`date -d "${fcstDATE}"` ${iday} days" '+%Y-%m-%d %H:%M:00' )
  for ihr in ${FCAST_TIMES}
  do
    fdate="$( date -d "`date -d "${myDate}"` ${ihr} hours" '+%Y%m%d' )"
    fhour="$(date -d "`date -d "${myDate}"` ${ihr} hours" '+%H')"

    # 1.0 degrees
    #inp_name="gfs.${fdate}${fhour}/gfs.t${fhour}z.pgrbf00.grib2"

    # 0.5 degrees
    inp_name="gfs.${fdate}${fhour}/gfs.t${fhour}z.pgrb2f00"

    out_name="gfs_${fdate}_${fhour}00_000.grib2"

    inpFNAMES="${inpFNAMES} ${inp_name}"
    outFNAMES="${outFNAMES} ${out_name}"
  done
done

# Get the forecast filenames
fdate="$( date -d "${fcstDATE}" '+%Y%m%d' )"
fhour="$( date -d "${fcstDATE}" '+%H')"
for (( idat = 0; idat <= 144; idat=$((${idat} + ${fcastINTRV})) ))
do
  ftime="${idat}"
  [ ${idat} -lt 10 ] && ftime="`get2DString ${idat}`"

  # 1.0 degrees
  inp_name="gfs.${fdate}${fhour}/gfs.t${fhour}z.pgrbf${ftime}.grib2"

  # 0.5 degrees
  inp_name="gfs.${fdate}${fhour}/gfs.t${fhour}z.pgrb2f${ftime}"

  out_name="gfs_${fdate}_${fhour}00_`get3DString ${idat}`.grib2"

  inpFNAMES="${inpFNAMES} ${inp_name}"
  outFNAMES="${outFNAMES} ${out_name}"
done

inpFNAMES=( ${inpFNAMES} )
outFNAMES=( ${outFNAMES} )
####################


####################
# Download the data
log_file="${LogDir:+${LogDir}/}gfs_download.log"
[ -f ${log_file} ] && rm -f ${log_file}

for ((idat = 0; idat < ${#inpFNAMES[@]}; idat++))
do
  finp="${URL:+${URL}/}${inpFNAMES[${idat}]}"
  fout="${OutDir:+${OutDir}/}${outFNAMES[${idat}]}"

  [ -f ${fout} ] && rm -f ${fout}

  wget -c ${finp} -O ${fout}
  if [ $? -ne 0 ]; then
    [ -f ${fout} ] && rm -f ${fout}
  else
    echo ${fout} >> ${log_file}
  fi
done
####################


####################
# Generate the WRF inputs
####################


####################
# Delete the GFS data
#for ((idat = 0; idat < ${#outFNAMES[@]}; idat++))
#do
#  fout="${OutDir:+${OutDir}/}${outFNAMES[${idat}]}"
#  [ -f ${fout} ] && rm -f ${fout}
#done
#[ -f ${log_file} ] && rm -f ${log_file}
#[ "X${OutDir}" != "." ] && rmdir ${OutDir} >/dev/null 2>&1
####################

exit 0
