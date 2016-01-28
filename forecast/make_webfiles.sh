#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.0
#
# Version - 1.0 Sun Feb 23 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`

# MAKE_MOVIES > 0 means that will create movies/animations
#                 from the plot files (in mp4 format)
MAKE_MOVIES=1


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
SimBeg="${FcastDate}"
SimEnd="${EndDate}"

ParseArgsCast "${@}"
############################################################


if [ ${REMOVE_DIR:-0} -gt 0 ]; then
  MakeDeleteDirs "${WebDir}"
  if [ $? -ne 0 ]; then
    procError "could not delete/create the directory: ${WebDir}"
  fi
fi

MAKE_MOVIES="$( getPosInteger "${MAKE_MOVIES:-0}" )"


############################################################
##### BEG:: Calculations
############################################################

echo "----- Generating the data files for the web for the current forecast."

############################################################
##### Get the possible forecast dates
GetFcastDates

############################################################
##### Copy the plot files into the web directory
echo "        Copying the plot/image files ..."

web_dir="${WebDir}/plots"
MakeDeleteDirs "${web_dir}"
if [ $? -ne 0 ]; then
  procError "could not delete/create the directory: ${web_dir}"
fi

if [ ${MAKE_MOVIES:-0} -gt 0 ]; then
  movies_dir="${WebDir}/movies"
  MakeDeleteDirs "${movies_dir}"
  if [ $? -ne 0 ]; then
    procError "could not delete/create the directory: ${movies_dir}"
  fi
fi

pushd ${PlotDir} >/dev/null
  for idir in $( GetPlotDirs )
  do
    out_dir="${web_dir}/${idir}"
    out_dir_high="${out_dir}/high"

    deleteDIR "${out_dir}"
    makeDIR ${out_dir_high}

    pushd ${idir} >/dev/null
      tmp_file="tmp.list"
      [ -f ${tmp_file} ] && rm -f ${tmp_file}

      for idate in ${dates_stamp}
      do
        find . -type f -name "${idir}*${idate}*.${IMG_TYPE}" -exec basename {} \; >> ${tmp_file}
      done

      inp_files="$( cat ${tmp_file} | sort -u )"
      [ -f ${tmp_file} ] && rm -f ${tmp_file}

      count=1
      for i in ${inp_files}
      do
        j="`basename ${i} .${IMG_TYPE}`-`get3DString ${count}`.${IMG_TYPE}"
        cp ${i} ${out_dir}/${j}
        cp ${i} ${out_dir_high}/${j}
        count=$(( ${count} + 1 ))
      done
    popd >/dev/null

    pushd ${out_dir} >/dev/null
      # The following are based on a high resolution image of size: 1000x792 pixels
      my_dirs=( 710 650 458 thumb )
      my_res=( 71.00 65.00 45.80 8.53 )
      res_thumb=${my_res[3]}
      res_movie=${my_res[0]}

      MakeDeleteDirs "${my_dirs[*]}"

      GPARAL_RUNLOG="${LogDir}/${scrNAME%%.*}-run.log"

      # Remove any old log files
      [ -f ${GPARAL_RUNLOG} ] && rm -f ${GPARAL_RUNLOG}

      inp_files="$( find . -mindepth 1 -maxdepth 1 -type f -iname "*.${IMG_TYPE}" -exec basename {} \; | sort -u )"
      for ((idir = 0; idir < ${#my_dirs[@]}; idir++))
      do
        out_files="$( echo "${inp_files}" | sed "s/\(^[[:alnum:]].*${IMG_TYPE}\)/${my_dirs[${idir}]}\/\1/g" )"

        export MAGICK_THREAD_LIMIT=1
        export OMP_NUM_THREADS=1

        #CONVERT_OPTS="-flatten -antialias -geometry ${my_res[${idir}]}% -quality 75"
        if [ "${my_res[${idir}]}" = "${res_thumb}" ]; then
          CONVERT_OPTS="-thumbnail ${my_res[${idir}]}% -quality 75"
        else
          CONVERT_OPTS="-resize ${my_res[${idir}]}% -quality 75"
        fi

        GPARAL_OPTS="${GPARAL_OPTS_GLB} --timeout 1200"
        GPARAL_OPTS="${GPARAL_OPTS} --wd ${out_dir} -j0"

        ${GPARAL} ${GPARAL_OPTS} --xapply ${CONVERT} ${CONVERT_OPTS} {1} {2} \
          ::: $(echo ${inp_files}) \
          ::: $(echo ${out_files}) >> ${GPARAL_RUNLOG} 2>&1
        status=$?
        FAILURE_STATUS=$(( ${FAILURE_STATUS:-0} + ${status} ))
      done

      # BEG:: Create a movie
      if [ ${MAKE_MOVIES:-0} -gt 0 ]; then
        movie_files=
        dfmt="%05d"
        count=1
        for i in ${out_files}
        do
          j="`echo ${count} | awk -v dfmt="${dfmt}" '{printf dfmt, $1}'`.${IMG_TYPE}"
          movie_files="${movie_files} ${j}"
          count=$(( ${count} + 1 ))
        done

        movie_out="`basename ${out_dir}`.mp4"
        [ -f ${movie_out} ] && rm -f ${movie_out}

        CONVERT_OPTS="-resize ${res_movie}% -quality 100"

        ${GPARAL} ${GPARAL_OPTS} --xapply ${CONVERT} ${CONVERT_OPTS} {1} {2} \
          ::: $(echo ${inp_files}) \
          ::: $(echo ${movie_files}) > /dev/null 2>&1
        status=$?

        ffmpeg -r 7 -i ${dfmt}.${IMG_TYPE} \
               -r 7 -b:v 5000k -vcodec libx264 -qscale:v 0 -an \
               ${movie_out} >> ${GPARAL_RUNLOG} 2>&1
        [ $? -ne 0 ] && rm -f ${movie_out}
        rm -f ${movie_files}
        unset movie_files

        [ -f ${movie_out} ] && mv -f ${movie_out} ${movies_dir}/${movie_out}
      fi
      # END:: Create a movie

      rm -f ${inp_files}
    popd >/dev/null
  done
popd >/dev/null

############################################################
##### Copy the config files into the web directory
echo "        Copying the configuration files ..."

web_dir="${WebDir}/config"
MakeDeleteDirs "${web_dir}"
[ $? -ne 0 ] && exit 1

inp_files="coupling.in ocean.in namelist.input sediment.in"
for ifile in ${inp_files}
do
  if [ -f ${ifile} ]; then
    cp -f ${ifile} ${web_dir}/${ifile}
    chmod 0644 ${web_dir}/${ifile}
  fi
done

############################################################
##### Create the forecast cycle date file
web_dir="${WebDir}"
echo "$( date -d "${SimBeg}" '+%m/%d/%Y %H' ) UTC" > \
     ${web_dir}/cycle.txt

############################################################
##### Copy the plot files into the web directory
echo "        Copying the data files ..."

web_dir="${WebDir}/data"
MakeDeleteDirs "${web_dir}"
[ $? -ne 0 ] && exit 1

pushd ${OutDir} >/dev/null
  if [ ${DOM_OCN:-0} -ne 0 ]; then
    inp_files=
    model="ocn"
    log_file="${LogDir}/copy_data-${model}.log"
    for idate in ${dates_fcast}
    do
      inp_files="${inp_files} $( find . -type f -iname "${model}_his*${idate}*.nc" -exec basename {} \; )"
    done
    inp_files="$( strTrim "${inp_files}" 2 )"
    if [ -n "${inp_files:+1}" ]; then
      /bin/cp -f -v --preserve=timestamps ${inp_files} ${web_dir}/ > ${log_file} 2>&1 &
    else
      echo "no data files found for ${model} in ${OutDir}" > ${log_file}
    fi
  fi

  if [ ${DOM_WRF:-0} -ne 0 ]; then
    inp_files=
    model="atm"
    log_file="${LogDir}/copy_data-${model}.log"
    for idate in ${dates_fcast}
    do
      inp_files="${inp_files} $( find . -type f -iname "${model}_his*${idate}*.nc" -exec basename {} \; )"
    done
    inp_files="$( strTrim "${inp_files}" 2 )"
    if [ -n "${inp_files:+1}" ]; then
      /bin/cp -f -v --preserve=timestamps ${inp_files} ${web_dir}/ > ${log_file} 2>&1 &
    else
      echo "no data files found for ${model} in ${OutDir}" > ${log_file}
    fi
  fi

  if [ ${DOM_SWAN:-0} -ne 0 ]; then
    inp_files=
    model="wav"
    log_file="${LogDir}/copy_data-${model}.log"
    for idate in ${dates_fcast}
    do
      inp_files="${inp_files} $( find . -type f -iname "${model}_his*${idate}*.nc" -exec basename {} \; )"
    done
    inp_files="$( strTrim "${inp_files}" 2 )"
    if [ -n "${inp_files:+1}" ]; then
      /bin/cp -f -v --preserve=timestamps ${inp_files} ${web_dir}/ > ${log_file} 2>&1 &
    else
      echo "no data files found for ${model} in ${OutDir}" > ${log_file}
    fi
  fi

  if [ ${DOM_SED:-0} -ne 0 ]; then
    inp_files=
    model="sed"
    log_file="${LogDir}/copy_data-${model}.log"
    for idate in ${dates_fcast}
    do
      inp_files="${inp_files} $( find . -type f -iname "${model}_his*${idate}*.nc" -exec basename {} \; )"
    done
    inp_files="$( strTrim "${inp_files}" 2 )"
    if [ -n "${inp_files:+1}" ]; then
      /bin/cp -f -v --preserve=timestamps ${inp_files} ${web_dir}/ > ${log_file} 2>&1 &
    else
      echo "no data files found for ${model} in ${OutDir}" > ${log_file}
    fi
  fi
popd >/dev/null

############################################################
##### END:: Calculations
############################################################

exit ${FAILURE_STATUS:-0}
