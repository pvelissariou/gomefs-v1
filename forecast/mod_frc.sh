#!/bin/bash

source functions_common

my_files="ocn_gst* ocn_rst* ocn_his*
          ocn_tlm* ocn_tlf* ocn_adj*
          ocn_avg* ocn_dia* ocn_sta*
          ocn_flt*
         "
echo "${my_files}"
echo
for i in ${my_files}
do
  f_inp="${i}"
echo "f_inp = ${f_inp}"
  if `checkFILE -r "${f_inp}"`; then
    # output file names
    f_date="$( ncdf_getTimeStamp "${f_inp}" | awk '{print $1}' )"

    if [ -n "$( isNcdf "${f_inp}" )" ]; then
      f_sfx=".nc"
    else
      f_sfx=".dat"
    fi

    f_out="$(strstr ${f_inp} "_[0-9]*")"
    f_out="${f_inp%*${f_out}}"
    f_out="${f_out%*${f_sfx}}"
    f_out="${out_dir:+${out_dir}/}${f_out}${f_date:+_${f_date}}${f_sfx}"

echo "f_out = ${f_out}"
  fi
done
