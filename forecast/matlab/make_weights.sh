#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.0
#
# Version - 1.0 Thu Jul 10 2014

# Make sure that the current working directory is in the PATH
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

scrNAME=`basename $0 .sh`


#------------------------------------------------------------
# USER INPUT
DOM_WRF="_d01"
DOM_ROMS="_d01"
DOM_SWAN="_d01"

#GRID_WRF=/Net/yucatan/daktas/TEST1/WPS/BIC/wrfinput${DOM_WRF}
GRID_WRF=/Net/mars/takis/FORECAST/Data/ini/wrfinput${DOM_WRF}_2014-02-28_00:00:00.nc
GRID_ROMS=/Net/mars/takis/FORECAST/Data/bath/romsgrd${DOM_ROMS}.nc
GRID_SWAN=/Net/mars/takis/FORECAST/Data/bath/swangrd${DOM_SWAN}.nc

# Request what weight files will be created
WRF_WEIGHTS=1
ROMS_WEIGHTS=1
SWAN_WEIGHTS=0
#------------------------------------------------------------


#------------------------------------------------------------
# LOCAL FUNCTIONS
escapeSTR()
{
  echo -n "$(echo "${1}" | sed -e "s/[\"\'\(\)\/\*]/\\\&/g;s/\[/\\\&/g;s/\]/\\\&/g")"
}

ScripMatRun()
{
  local scrip_file= scrip_tmp=
  local inp_file= out_file=
  local xpr1= xpr2=
  local RUN_CMD=

  # ----- Get all the arguments
  if [ $# -lt 2 ]; then
    echo "ERROR:: ${scrNAME}: ScripMatRun: usage ScripMatRun scripFILE gridFILE"
    echo "        Exiting now ..."
    exit 1
  fi

  if [ ! -f "${1}" ]; then
    echo "ERROR:: ${scrNAME}: ScripMatRun"
    echo "        Scrip file not found: ${1:-UNDEF}"
    echo "        Exiting now ..."
    echo
    exit 1
  fi

  if [ ! -f "${2}" ]; then
    echo "ERROR:: ${scrNAME}: ScripMatRun"
    echo "        Grid file not found: ${2:-UNDEF}"
    echo "        Exiting now ..."
    echo
    exit 1
  fi

  scrip_file="${1}"
  inp_file="${2}"
  if [ "X${3}" != "X" ]; then
    out_file="${3}"
  else
    out_file="scrip_$(basename ${inp_file})"
  fi

  scrip_tmp="${scrip_file%%.*}_tmp.m"

  # Remove any old files
  [ -f "${scrip_tmp}" ] && rm -f "${scrip_tmp}"
  cp -f "${scrip_file}" "${scrip_tmp}"

  xpr1='^[ \t]*grid_file[ \t]*='
  xpr2=" \'`escapeSTR ${inp_file}`\';"
  sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" ${scrip_tmp}
    
  xpr1='^[ \t]*out_file[ \t]*='
  xpr2=" \'`escapeSTR ${out_file}`\';"
  sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" ${scrip_tmp}

  echo          >> ${scrip_tmp}
  echo "close;" >> ${scrip_tmp}
  echo "exit"   >> ${scrip_tmp}

  [ -f "${out_file}" ] && rm -f ${out_file}
  RUN_CMD="matlab -nojvm -nosplash -nodesktop -r ${scrip_tmp%%.*} 2>&1"

  ##########
  echo
  echo "##### Running ${RUN_CMD}"

  ${RUN_CMD}
  if [ $? -ne 0 ]; then
    [ -f "${out_file}" ] && rm -f ${out_file}
    echo "ERROR:: ${scrNAME}: ScripMatRun: the following command failed:"
    echo "        ${RUN_CMD}"
    echo "        Exiting now ..."
    echo
    exit 1
  fi

  [ -f "${scrip_tmp}" ] && rm -fv ${scrip_tmp}
  echo
  ##########

  export scripOUT="${out_file}"

  return 0
}

ScripRun()
{
  local scrip_file= scrip_tmp=
  local grid_file1= grid_file2=
  local map_file1= map_file2=
  local model1= model2=
  local RUN_CMD= scrip_in="scrip_in"

  # ----- Get all the arguments
  if [ $# -lt 5 ]; then
    echo "ERROR:: ${scrNAME}: ScripRun: usage ScripRun scripINP grid1 map1 grid2 map2"
    echo "        Exiting now ..."
    exit 1
  fi

  scrip_file="${1}"

  grid_file1="${2}"
  map_file1="${3}"

  grid_file2="${4}"
  map_file2="${5}"

  model1="${6:-MODEL1}"
  model2="${7:-MODEL2}"

  if [ ! -f "${grid_file1}" ]; then
    echo "ERROR:: ${scrNAME}: ScripRun: grid file not found: ${grid_file1:-UNDEF}"
    echo "        Exiting now ..."
    echo
    exit 1
  fi

  if [ ! -f "${grid_file2}" ]; then
    echo "ERROR:: ${scrNAME}: ScripRun: grid file not found: ${grid_file2:-UNDEF}"
    echo "        Exiting now ..."
    echo
    exit 1
  fi

[ -f "${scrip_file}" ] && rm -f "${scrip_file}"
cat << EOF >> ${scrip_file}
&remap_inputs
num_maps        = 2
grid1_file      = '${grid_file1}'
grid2_file      = '${grid_file2}'
interp_file1    = '${map_file1}'
interp_file2    = '${map_file2}'
map1_name       = '${model1} to ${model2} Mapping'
map2_name       = '${model2} to ${model1} Mapping'
map_method      = 'conservative'
normalize_opt   = 'fracarea'
output_opt      = 'scrip'
restrict_type   = 'latlon'
num_srch_bins   = 90 
luse_grid1_area = .false.
luse_grid2_area = .false.
/
EOF

  [ -f "${scrip_in}" ] && rm -f "${scrip_in}"
    ln -sf ${scrip_file} "${scrip_in}"

  RUN_CMD="scrip 2>&1"

  ##########
  echo
  echo "##### Running ${RUN_CMD} on file: ${scrip_file}"

  ${RUN_CMD}
  if [ $? -ne 0 ]; then
    [ -f "${scrip_in}" ] && rm -f "${scrip_in}"
    echo "ERROR:: ${scrNAME}: ScripMatRun: the following command failed:"
    echo "        ${RUN_CMD}"
    echo "        Exiting now ..."
    echo
    exit 1
  fi

  echo
  ##########

  [ -f "${scrip_in}" ] && rm -f "${scrip_in}"
  [ -f "${grid_file1}" ] && rm -f "${grid_file1}"
  [ -f "${grid_file2}" ] && rm -f "${grid_file2}"

  return 0
}

#------------------------------------------------------------


############################################################
##### BEG:: Calculations
############################################################

echo "----- Creating the weight NetCDF files."

############################################################
##### Run matlab to create the scrip input files
if [ ${WRF_WEIGHTS} -gt 0 ]; then
  ScripMatRun "scrip_wrf.m"  "${GRID_WRF}"
    scripWRF="${scripOUT}"
    unset scripOUT
fi

if [ ${ROMS_WEIGHTS} -gt 0 ]; then
  ScripMatRun "scrip_roms.m" "${GRID_ROMS}"
    scripROMS="${scripOUT}"
    unset scripOUT
fi

if [ ${SWAN_WEIGHTS} -gt 0 ]; then
  ScripMatRun "scrip_swan.m" "${GRID_SWAN}"
    scripSWAN="${scripOUT}"
    unset scripOUT
fi

############################################################
##### Run scrip to create the model weight files
if [ ${WRF_WEIGHTS} -gt 0 -a ${ROMS_WEIGHTS} -gt 0 ]; then
  ScripRun "scrip_in_wrf-roms" \
           "${scripROMS}" "ocn${DOM_ROMS}-atm${DOM_WRF}-weights.nc" \
           "${scripWRF}"  "atm${DOM_WRF}-ocn${DOM_ROMS}-weights.nc" \
           "ROMS" "WRF"
fi

if [ ${ROMS_WEIGHTS} -gt 0 -a ${SWAN_WEIGHTS} -gt 0 ]; then
  ScripRun "scrip_in_roms-swan" \
           "${scripROMS}" "ocn${DOM_ROMS}-wav${DOM_SWAN}-weights.nc" \
           "${scripSWAN}"  "wav${DOM_SWAN}-ocn${DOM_ROMS}-weights.nc" \
           "ROMS" "SWAN"
fi

if [ ${WRF_WEIGHTS} -gt 0 -a ${SWAN_WEIGHTS} -gt 0 ]; then
  ScripRun "scrip_in_wrf-swan" \
           "${scripWRF}" "atm${DOM_WRF}-wav${DOM_SWAN}-weights.nc" \
           "${scripSWAN}"  "wav${DOM_SWAN}-atm${DOM_WRF}-weights.nc" \
           "WRF" "SWAN"
fi

############################################################
##### END:: Calculations
############################################################

exit 0
