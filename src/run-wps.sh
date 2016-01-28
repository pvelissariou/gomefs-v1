#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.0
#
# Version - 1.0 Wed Jul 25 2012


##########
# Source the Utility Functions so they are available
# to this script
if [ -f functions_common ]; then
  . functions_common
else
  echo " ### ERROR: in ${scrNAME}"
  echo "       Couldn't locate the file <functions_common> that contains"
  echo "       all the necessary utility functions required for this"
  echo "       script to be executed properly."
  echo "     Exiting now ..."
  exit 1
fi

[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."


# ---------- BEG:: USER DEFINITIONS SECTION

#    SimBeg   -> The starting date for the simulation being run,
#                in the form of:
#                  YYYY/MM/DD [HH:MN:SC] or YYYY-MM-DD [HH:MN:SC]
#                Currently the HH:MN:SC part is set to: "00:00:00"
#                This value can be either specified here or in the command line
#                DEFAULT: none, NEEDS TO BE SPECIFIED
#    SimEnd   -> The ending date for the simulation being run
#                (format/specification/default similar as in SimBeg)
SimBeg="2010-01-01"
SimEnd="2010-12-31"


# The directory under which the geog data are stored
dataGEOG="/Net/mars/takis/DATA-GEOG/"

# The prefix in the &ungrib section in the namelist.wps file.
dataTYPE="GFS"

# The prefix used in the data files (if any), the script will
# search for all files starting with the following prefix.
dataFILEPFX="fnl_"

# The root directory under which the data are stored
dataROOT="/Net/mars/takis/DATA-${dataTYPE}/ds083.2-grib2"

# If the dataDIR variable is empty the script will search 
# for the data files under the directory:
#   dataROOT/dataDIR/YEAR/MONTH/dataFILEPFX*
# otherwise it will search under: dataROOT/dataDIR/dataFILEPFX*
dataDIR=

# The SEP variable is used to separate the YEAR, MONTH, DAY
# part of the data filename like:
#   YEAR[SEP]MONTH[SEP]DAY
# this string, according to SEP can be:
# YYYYMMDD (SEP is empty), YYYY_MM_DD, YYYY-MM-DD, ...
SEP=

# The suffix to be used when searching for Vtable files in 
# the Variable_Tables directory.
# The scripts will make a link from Variable_Tables/Vtable.${vtableSFX}
# to Vtable. If vtableSFX is empty, then the script will use
# the value of dataTYPE.
vtableSFX=

# ---------- END:: USER DEFINITIONS SECTION


# ============================================================
# Ideally you won't have to modify anything below
# ============================================================
##### Get the "start" and the "end" times for the current simulation.
getStartEndTimes

# Check if the user supplied the number of cpus to be used
# as the first argument of this script.
unset nproc
if [ -n "${1:+1}" ]; then
  let num="${1}" 2>/dev/null
  if [ $? -eq 0 ]; then
    [ ${num} -gt 0 ] && nproc="${num}"
  fi
fi

##### The name of the modulefile(s) to load (if any).
#     If during compilation modules were used to set the paths
#     of the compilers/libraries then, the same modules should
#     be used/loaded at runtime as well.
#     It is given the option to supply these modules from the
#     environment as well, in case something went wrong.
MODFILES="${MODFILES:-_MY_MODFILES_}"

# Load any requested modules.
if [ -n "${MODFILES:+1}" ]; then
  chkMOD="`which modulecmd 2>&1 | grep -vEi "no.*modulecmd"`"
  if [ -n "${chkMOD:+1}" ]; then
    chkMOD="$(echo $(module -V 2>&1) | grep -vEi "not.*found")"
    [ -z "${chkMOD:-}" ] && module() { eval `modulecmd sh $*`; }
    echo "Removing all loaded modules"
    module purge > /dev/null 2>&1
    [[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."
    for imod in ${MODFILES}
    do
      module load "${imod}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Couldn't load the requested module: ${imod}"
        exit 1
      else
        echo "Loaded module: ${imod}"
      fi
    done
  fi
fi


#----- Check for the required programs.
if [ ! -x geogrid.exe ] || \
   [ ! -x ungrib.exe  ] || \
   [ ! -x metgrid.exe ] || \
   [ ! -x real.exe    ]; then
  echo "ERROR:: $0: Can not execute one of the required programs:"
  echo "              geogrid.exe, ungrib.exe, metgrid.exe, or real.exe"
  echo "        Exiting now ..."
  echo -n
  exit 1
fi


# ----- BEG:: Check the namelist files.
#
nml_files="namelist.wps namelist.input"
for inml in ${nml_files}
do
  if [ -f ${inml}-tmpl ]; then
    [ -f ${inml} ] && rm -f ${inml}

    /bin/cp -f ${inml}-tmpl ${inml}
  else
    echo "ERROR:: $0: The required file ${inml}-tmpl not found"
    echo "        Exiting now ..."
    echo -n
    exit 1
  fi
done

# Check for the number of cpus (nproc_x, nproc_y) required and modify if needed
my_nprocx="$(grep -Ei "^[[:space:]]*nproc_x" namelist.input 2>/dev/null)"
my_nprocy="$(grep -Ei "^[[:space:]]*nproc_y" namelist.input 2>/dev/null)"
if [ -z "${my_nprocx:-}" ] || [ -z "${my_nprocy:-}" ]; then
  echo "ERROR:: $0: Missing nproc_x/nproc_y lines in file: namelist.input"
  echo "        Exiting now ..."
  echo -n
  exit 1
fi

# Check for the number of domains required and modify if needed
my_Dom1="$(grep -Ei "^[[:space:]]*max_dom" namelist.input 2>/dev/null)"
my_Dom1="$(echo "${my_Dom1}" | sed -e 's/.*=//g'| sed -e 's/[=;:,_\{\}\\]/ /g' | awk '{print $1}')"
let my_Dom1="${my_Dom1}" 2>/dev/null
[ $? -ne 0 ] && my_Dom1=1
[ ${my_Dom1} -le 0 ] && my_Dom1=1

my_Dom2="$(grep -Ei "^[[:space:]]*max_dom" namelist.wps 2>/dev/null)"
my_Dom2="$(echo "${my_Dom2}" | sed -e 's/.*=//g'| sed -e 's/[=;:,_\{\}\\]/ /g' | awk '{print $1}')"
let my_Dom2="${my_Dom2}" 2>/dev/null
[ $? -ne 0 ] && my_Dom2=1
[ ${my_Dom2} -le 0 ] && my_Dom2=1

if [ ${my_Dom1} -ne ${my_Dom2} ]; then
  echo "ERROR:: $0: Wrong number of domains found in the files: namelist.input and namelist.wps"
  echo "        Exiting now ..."
  echo -n
  exit 1
fi

nDOMS=${my_Dom1}
xpr1='^[ \t]*max_dom[ \t]*='
xpr2=" ${nDOMS},"
sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps

# Check for the prefix parameter in namelist.wps
my_PFX="$(grep -Ei "^[[:space:]]*prefix" namelist.wps 2>/dev/null)"
my_PFX="$(echo "${my_PFX}" | sed -e 's/.*=//g'| sed -e "s/[=;,\'\"\\\(\)\{\}]/ /g" | awk '{print $1}')"
if [ "${my_PFX}" != "${dataTYPE}" ]; then
  echo "ERROR:: $0: Inconsistent prefix in '&ungrib' section in file: namelist.wps"
  echo "            Expected: prefix = ${dataTYPE:-UNDEF}"
  echo "        Exiting now ..."
  echo -n
  exit 1
fi
#
# ----- END:: Check the namelist files.


# ----- Make the link of the corresponding Vtable file.
vtableSFX=${vtableSFX:-${dataTYPE:-UNDEF}}
if [ -f "Variable_Tables/Vtable.${vtableSFX}" ]; then
  [ -f Vtable ] && rm -f Vtable
  ln -sf "Variable_Tables/Vtable.${vtableSFX}" Vtable
else
  echo "ERROR:: $0: Couldn't locate the file: Variable_Tables/Vtable.${vtableSFX}"
  echo "            expected to be found in: Variable_Tables/"
  echo "        Exiting now ..."
  echo -n
  exit 1
fi


# ----- Cycle through the months for each year.
rm -f geo_em.d*.nc
rm -f RUNWPS:${dataFILEPFX}* ${dataTYPE:+${dataTYPE}:*} GRIBFILE.*
rm -f *.log* met_em.* namelist.output

for ((iyr = ${SimBegYR}; iyr <= ${SimEndYR}; iyr++))
do
  firstYR=${iyr}
  lastYR=${iyr}

  # If multiple years are specified, adjust the month count.
  f_mo=1
    [ ${iyr} -eq ${SimBegYR} ] && f_mo=${SimBegMO}
  l_mo=12
    [ ${iyr} -eq ${SimEndYR} ] && l_mo=${SimEndMO}
  # Loop through the months. Ajust the month count when entering a new year.
  for ((imo = ${f_mo}; imo <= ${l_mo}; imo++))
  do
    firstMO=${imo}
    lastMO=${imo}

    # If multiple months are specified, adjust the day count.
    firstDA=1
    moDAYS="`getMonthDays ${iyr} ${imo}`"
      [ ${imo} -eq ${SimBegMO} ] && [ ${iyr} -eq ${SimBegYR} ] && \
        firstDA=${SimBegDA}
    lastDA=${moDAYS}
      [ ${imo} -eq ${SimEndMO} ] && [ ${iyr} -eq ${SimEndYR} ] && \
        lastDA=${SimEndDA}

    nextDA="$(( ${lastDA} + 1 ))"
    nextMO=${imo}
    nextYR=${iyr}
    if [ ${nextDA} -gt ${moDAYS} ]; then
      nextDA=1
      nextMO="$(( ${imo} + 1 ))"
      if [ ${nextMO} -gt 12 ]; then
        nextMO=1
        nextYR="$(( ${iyr} + 1 ))"
      fi
    fi

    firstHR=0
    firstMN=0
    firstSC=0

    lastHR=0
    lastMN=0
    lastSC=0

    nextHR=0
    nextMN=0
    nextSC=0

    firstYRStr="`getYearString ${firstYR}`"
    firstMOStr="`get2DString   ${firstMO}`"
    firstDAStr="`get2DString   ${firstDA}`"
    firstHRStr="`get2DString   ${firstHR}`"
    firstMNStr="`get2DString   ${firstMN}`"
    firstSCStr="`get2DString   ${firstSC}`"

    lastYRStr="`getYearString ${lastYR}`"
    lastMOStr="`get2DString   ${lastMO}`"
    lastDAStr="`get2DString   ${lastDA}`"
    lastHRStr="`get2DString   ${lastHR}`"
    lastMNStr="`get2DString   ${lastMN}`"
    lastSCStr="`get2DString   ${lastSC}`"

    nextYRStr="`getYearString ${nextYR}`"
    nextMOStr="`get2DString   ${nextMO}`"
    nextDAStr="`get2DString   ${nextDA}`"
    nextHRStr="`get2DString   ${nextHR}`"
    nextMNStr="`get2DString   ${nextMN}`"
    nextSCStr="`get2DString   ${nextSC}`"


    # ---------- Create the strings to be used in the construction
    #            of the filenames, get the full path to the filenames
    #            and make links into the current directory.
    unset my_FILES

    data_dir="${dataROOT}/${dataDIR:-${firstYRStr}/${firstMOStr}}"

    for ((ida = ${firstDA}; ida <= ${lastDA}; ida++))
    do
      f_daySTR="`get2DString   ${ida}`"
      fileSTR="${firstYRStr}${SEP:-}${firstMOStr}${SEP:-}${f_daySTR}"

      tmpNAMES="$(echo $(ls ${data_dir}/${dataFILEPFX}*${fileSTR}* 2>/dev/null))"
      if [ -n "${tmpNAMES:+1}" ]; then
        my_FILES="${my_FILES} ${tmpNAMES}"
      else
        echo "ERROR:: $0: Missing data files for date: ${fileSTR}"
        echo "            in the data dir: ${data_dir}"
        echo "        Exiting now ..."
        echo -n
        exit 1
      fi
    done

    # Do an extra data record
    fileSTR="${nextYRStr}${SEP:-}${nextMOStr}${SEP:-}${nextDAStr}"
    tmpNAMES="$(echo $(ls ${data_dir}/${dataFILEPFX}*${fileSTR}* 2>/dev/null))"
    if [ -z "${tmpNAMES:-}" ]; then
      data_dir="${dataROOT}/${dataDIR:-${nextYRStr}/${nextMOStr}}"
      tmpNAMES="$(echo $(ls ${data_dir}/${dataFILEPFX}*${fileSTR}* 2>/dev/null))"
    fi
    [ -n "${tmpNAMES:+1}" ] && my_FILES="${my_FILES} ${tmpNAMES}"

    # Make the data file links
    if [ -n "${my_FILES:+1}" ]; then
      for ifl in ${my_FILES}
      do
        ifl_base="`basename ${ifl}`"
        ln -sf "${ifl}" "RUNWPS:${ifl_base}"
      done
    fi
    #
    # ----------


    #----- BEG:: prepare the namelist.input and namelist.wps files
    #
    unset my_begYR my_begMO my_begDA my_begHR my_begMN my_begSC
    unset my_endYR my_endMO my_endDA my_endHR my_endMN my_endSC
    for ((ido = 0; ido < ${nDOMS}; ido++))
    do
      my_begYR="${my_begYR:-} ${firstYRStr},"
      my_begMO="${my_begMO:-} ${firstMOStr},"
      my_begDA="${my_begDA:-} ${firstDAStr},"
      my_begHR="${my_begHR:-} ${firstHRStr},"
      my_begMN="${my_begMN:-} ${firstMNStr},"
      my_begSC="${my_begSC:-} ${firstSCStr},"

      my_endYR="${my_endYR:-} ${nextYRStr},"
      my_endMO="${my_endMO:-} ${nextMOStr},"
      my_endDA="${my_endDA:-} ${nextDAStr},"
      my_endHR="${my_endHR:-} ${nextHRStr},"
      my_endMN="${my_endMN:-} ${nextMNStr},"
      my_endSC="${my_endSC:-} ${nextSCStr},"
    done

    # start_year
    xpr1='^[ \t]*start_year[ \t]*='
    xpr2="${my_begYR}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # start_month
    xpr1='^[ \t]*start_month[ \t]*='
    xpr2="${my_begMO}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # start_day
    xpr1='^[ \t]*start_day[ \t]*='
    xpr2="${my_begDA}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # start_hour
    xpr1='^[ \t]*start_hour[ \t]*='
    xpr2="${my_begHR}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # start_minute
    xpr1='^[ \t]*start_minute[ \t]*='
    xpr2="${my_begMN}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # start_second
    xpr1='^[ \t]*start_second[ \t]*='
    xpr2="${my_begSC}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps

    # end_year
    xpr1='^[ \t]*end_year[ \t]*='
    xpr2="${my_endYR}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # end_month
    xpr1='^[ \t]*end_month[ \t]*='
    xpr2="${my_endMO}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # end_day
    xpr1='^[ \t]*end_day[ \t]*='
    xpr2="${my_endDA}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # end_hour
    xpr1='^[ \t]*end_hour[ \t]*='
    xpr2="${my_endHR}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # end_minute
    xpr1='^[ \t]*end_minute[ \t]*='
    xpr2="${my_endMN}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    # end_second
    xpr1='^[ \t]*end_second[ \t]*='
    xpr2="${my_endSC}"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps

    # nproc_x
    xpr1='^[ \t]*nproc_x[ \t]*='
    xpr2=" -1,"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input

    # nproc_y
    xpr1='^[ \t]*nproc_y[ \t]*='
    xpr2=" -1,"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input

    # geog_data_path
    xpr1='^[ \t]*geog_data_path[ \t]*='
    xpr2="$(escapeSTR " '${dataGEOG}',")"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.wps
    #
    #----- END:: prepare the namelist.input and namelist.wps files


    # Run the "geogrid" program (needs to be run just once).
    ls geo_*.d*.nc  > /dev/null 2>&1
    retval=$?
    if [ ${retval} -ne 0 ]; then
      ./geogrid.exe
      retval=$?
      if [ ${retval} -ne 0 ]; then
        echo "ERROR:: $0: geogrid.exe failed"
        echo "        Exiting now ..."
        echo -n
        exit 1
      fi
    fi

    # Link the required data files
    if [ -x link_grib.csh ]; then
      ./link_grib.csh RUNWPS:${dataFILEPFX}*
      retval=$?
      if [ ${retval} -ne 0 ]; then
        echo "ERROR:: $0: link_grib.csh failed"
        echo "        Exiting now ..."
        echo -n
        exit 1
      fi
    else
      echo "ERROR:: $0: The required file link_grib.csh can not be executed"
      echo "        Exiting now ..."
      echo -n
      exit 1
    fi


    # Run the "ungrib" program
    ./ungrib.exe
    retval=$?
    if [ ${retval} -ne 0 ]; then
      echo "ERROR:: $0: ungrib.exe failed"
      echo "        Exiting now ..."
      echo -n
      exit 1
    fi


    # Run the "metgrid" program
    ${nproc:+mpirun -np ${nproc}} ./metgrid.exe
    retval=$?
    if [ ${retval} -ne 0 ]; then
      echo "ERROR:: $0: metgrid.exe failed"
      echo "        Exiting now ..."
      echo -n
      exit 1
    fi


    #----- BEG:: Check the "met*" files for consistent metgrid levels
    #            and metgrid_soil_levels. Modify the namelist.input file.
    #
    unset chkMET_LEV chkST_LAY chkMET_FILE chkST_FILE
    for imet in met_*.d*.nc
    do
      if [ -f ${imet} ]; then
          met_lev=num_metgrid_levels
        met_lev="$(ncdump -h ${imet} 2>&1 | grep -Ei "^[[:space:]]*${met_lev}[[:space:]]*=")"
        met_lev="$(echo "${met_lev}" | sed -e 's/.*=//g' | sed 's/[;:,_\{\}]/ /g')"
        met_lev=$(String_getInteger "${met_lev}" 0)
          st_lay=num_st_layers
        st_lay="$(ncdump -h ${imet} 2>&1 | grep -Ei "^[[:space:]]*${st_lay}[[:space:]]*=")"
        st_lay="$(echo "${st_lay}" | sed -e 's/.*=//g' | sed 's/[;:,_\{\}]/ /g')"
        st_lay=$(String_getInteger "${st_lay}" 0)

        if [ -z "${chkMET_LEV:-}" ]; then
          chkMET_LEV=${met_lev}
          chkMET_FILE=${imet}
        else
          if [ ${met_lev} -ne ${chkMET_LEV} ]; then
            echo "  Inconsistent number of metgrid levels in file: ${imet}"
            echo "    Expected: num_metgrid_levels = ${chkMET_LEV}"
            echo "        from: ${chkMET_FILE}"
            echo "    Got:      num_metgrid_levels = ${imet}"
            echo "        from: ${imet}"
            echo "Exiting now ..."
            exit 1
          fi
        fi
        if [ -z "${chkST_LAY:-}" ]; then
          chkST_LAY=${st_lay}
          chkST_FILE=${imet}
        else
          if [ ${st_lay} -ne ${chkST_LAY} ]; then
            echo "  Inconsistent number of soil layers in file: ${imet}"
            echo "    Expected: num_st_layers = ${chkST_LAY}"
            echo "        from: ${chkST_FILE}"
            echo "    Got:      num_st_layers = ${imet}"
            echo "        from: ${imet}"
            echo "Exiting now ..."
            exit 1
          fi
        fi
      fi
    done

    # num_metgrid_levels
    xpr1='^[ \t]*num_metgrid_levels[ \t]*='
    xpr2=" ${chkMET_LEV},"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    # num_metgrid_soil_levels
    xpr1='^[ \t]*num_metgrid_soil_levels[ \t]*='
    xpr2=" ${chkST_LAY},"
    sed -i "s/\(${xpr1}\)\(.*\)/\1${xpr2}/g" namelist.input
    #
    #----- BEG:: Check the "met*" files for consistent metgrid levels


    # Finally run the "real" program
    ${nproc:+mpirun -np ${nproc}} ./real.exe
    retval=$?
    if [ ${retval} -ne 0 ]; then
      echo "ERROR:: $0: real.exe failed"
      echo "        Exiting now ..."
      echo -n
      exit 1
    fi


    # Rename the resulting WRF input files
    fileSTR="${firstYRStr}-${firstMOStr}-${firstDAStr}"
    fileSTR="${fileSTR}_${firstHRStr}:${firstMNStr}:${firstSCStr}"
    for idom in wrfbdy_d[0-9][0-9] wrfinput_d[0-9][0-9] wrflowinp_d[0-9][0-9]
    do
      [ -f ${idom} ] && \
        mv -f ${idom} ${idom}_${fileSTR}.nc
    done


    # Remove all the files that are not needed any more
    rm -f RUNWPS:${dataFILEPFX}* ${dataTYPE:+${dataTYPE}:*} GRIBFILE.*
    rm -f *.log* met_em.* namelist.output

  done
done

[ -L Vtable ] && rm -f Vtable
