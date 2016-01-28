#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.2
#
# Version - 1.2 Sun Jul 28 2013
# Version - 1.1 Wed Feb 27 2013
# Version - 1.0 Wed Jul 25 2012

Make_RUNScripts()
{
  local file1 file2

  file1="${1}"
  file2="${2}"

  if `checkFILE -r ${file1}`; then
    echo "Creating -> ${file2}"
    install -m 0755 "${file1}" "${file2}"

    sed -i "s/\(^[ \t]*\)COUPLED_SYSTEM=\(.*\)/\1COUPLED_SYSTEM=${COUPLED_SYSTEM:-no}/g"   "${file2}"
    sed -i "s/\(^[ \t]*\)USE_MPI=\(.*\)/\1USE_MPI=${USE_MPI:-no}/g"                        "${file2}"
    sed -i "s/\(^[ \t]*\)USE_ROMS=\(.*\)/\1USE_ROMS=${USE_ROMS:-no}/g"                     "${file2}"
    sed -i "s/\(^[ \t]*\)USE_WRF=\(.*\)/\1USE_WRF=${USE_WRF:-no}/g"                        "${file2}"
    sed -i "s/\(^[ \t]*\)USE_SWAN=\(.*\)/\1USE_SWAN=${USE_SWAN:-no}/g"                     "${file2}"
    sed -i "s/\(^[ \t]*\)USE_SED=\(.*\)/\1USE_SED=${USE_SED:-no}/g"                        "${file2}"
    sed -i "s/\(^[ \t]*\)romsDOMS=\(.*\)/\1romsDOMS=${NestedGrids:-1}/g"                   "${file2}"
    sed -i "s/\(^[ \t]*\)swanDOMS=\(.*\)/\1swanDOMS=${NestedGrids:-1}/g"                   "${file2}"
    sed -i "s/_MY_BINDIR_/./g"                                                             "${file2}"
    sed -i "s/_MY_MODEL_EXE_/${model_name:+-${model_name}}/g"                                "${file2}"
    sed -i "s/_MY_PROG_EXE_/${model_exe}/g"                                                "${file2}"
    sed -i "s/_MY_CASE_ID_/${CASEID:-}/g"                                                  "${file2}"
    sed -i "s/_MY_VER_STR_/${VER_STR:-}/g"                                                 "${file2}"
    sed -i "s/_MY_MODFILES_/${MODFILES:+${MODFILES}}/g"                                    "${file2}"
    sed -i "s/_MY_COMPSYS_/${COMPSYS:+${COMPSYS}}/g"                                       "${file2}"
    sed -i "s/_MY_MPISYS_/${MPISYS:+-${MPISYS}}/g"                                         "${file2}"
    sed -i "s/_MY_MPIVER_/${MPISYS:+-${MPISYS}${MPIVER:+-${MPIVER}}}/g"                    "${file2}"
  fi
}

#============================================================
# BEG:: SCRIPT INITIALIZATION
#============================================================
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

##########
# Script identification variables
# The script name and the directory where this script is located
scrNAME=`basename ${0}`
scrDIR=`dirname ${0}`
pushd ${scrDIR} > /dev/null 2>&1
scrDIR="`pwd`"
popd > /dev/null 2>&1

##########
# Set/Check the "rootDIR" variable
# This is the directory of the COAWST source code
rootDIR=${rootDIR:=${scrDIR}}

if [ ! -d "${rootDIR}" ]; then
  echo " ### ERROR: in ${scrNAME}"
  echo "       The supplied value for:"
  echo "       rootDIR = ${rootDIR}"
  echo "       is not a valid directory. This variable is essential"
  echo "       for this script to be executed properly."
  echo "     Exiting now ..."
  echo
  exit 1
fi

##########
# Source the Utility Functions so they are available
# to this script
if [ -f functions_build ]; then
  . functions_build
else
  echo " ### ERROR: in ${scrNAME}"
  echo "       Couldn't locate the file <functions_build> that contains"
  echo "       all the necessary utility functions required for this"
  echo "       script to be executed properly."
  echo "     Exiting now ..."
  exit 1
fi

COLORSET=`getYesNo "${COLORSET:-yes}"`
  [ "${COLORSET:-no}" = "no" ] && unset COLORSET

#============================================================
# END:: SCRIPT INITIALIZATION
#============================================================


#============================================================
# BEG:: SETTING DEFAULTS AND/OR THE USER INPUT
#============================================================

Get_LibName

##########
# First, source the file pointed by the COAWST_ENV environment variable
# (if it is set) to get any user defined values. If COAWST_ENV is
# not set try a file called "coawst_environment.sh" next. We source
# these files before calling ParseArgs below in case the user has
# already set this environment.
unset envISSET
if [ -z "${COAWST_ENV:-}" ]; then
  srchPATH="./ ${scrDIR} ${rootDIR}
            ${scrDIR}/.. ${scrDIR}/../scripts
            ${rootDIR}/scripts"
  for spath in ${srchPATH}
  do
    if `checkFILE -r ${spath}/coawst_environment.sh`; then
      . ${spath}/coawst_environment.sh
      export envISSET=1
      break
    fi
  done
  unset spath srchPATH
else
  if `checkFILE -r "${COAWST_ENV}"`; then
    . "${COAWST_ENV}"
    export envISSET=2
  fi
fi

export WRF_OS="${WRF_OS:-`uname`}"
export WRF_MACH="${WRF_MACH:-`uname -m`}"
export WRF_EM_CORE="${WRF_EM_CORE:-1}"
export WRF_NMM_CORE="${WRF_NMM_CORE:-0}"

#########
# Call ParseArgs to get any additional user input
# (if requested).
ParseArgs $*

#============================================================
# END:: SETTING DEFAULTS AND/OR THE USER INPUT
#============================================================


#============================================================
# BEG:: CHECK THE VARIABLES
# Check the environment variables and adjust as needed
# User defined environmental variables. See the ROMS makefile for
# details on other options the user might want to set here. Be sure to
# leave the switches meant to be off set to an empty string or commented
# out. Any string value (including off) will evaluate to TRUE in
# conditional if-statements.
#============================================================

# ------------------------------------------------------------
# ROMS_APPLICATION should be set in any case.
if [ -z "${ROMS_APPLICATION:-}" ]; then
  echo " ### ERROR: in ${scrNAME}"
  echo "     The ROMS_APPLICATION variable is not set:"
  echo "       ROMS_APPLICATION = ${ROMS_APPLICATION:-UNDEF}"
  echo "     Use: ${scrNAME} -h, to see all available options"
  echo "     Exiting now ..."
  echo
  exit 1
fi

# ------------------------------------------------------------
# The module file(s) to load (if any).
MODFILES="${MODFILES:-}"
if [ -n "${MODFILES:+1}" ]; then
  chkMOD="`which modulecmd 2>&1 | grep -vEi "no.*modulecmd"`"
  if [ -n "${chkMOD:+1}" ]; then
    chkMOD="$(echo $(module -V 2>&1) | grep -vEi "not.*found")"
    [ -z "${chkMOD:-}" ] && module() { eval `modulecmd sh $*`; }
    module purge > /dev/null 2>&1
    [[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."
    for imod in ${MODFILES}
    do
      module load "${imod}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo " ### ERROR: in ${scrNAME}"
        echo "     Couldn't load the requested module:"
        echo "       MODFILES = ${imod}"
        echo "     Exiting now ..."
        echo
        exit 1
      fi
    done
  else
    echo " ### NOTICE: in ${scrNAME}"
    echo "     Please use the script option [-m my_MODFILES], or"
    echo "     the environment variable MODFILES to load the"
    echo "     required modules ..."
    echo "     Make sure that the command [module] is in your path"
    echo
  fi
fi

# ------------------------------------------------------------
# The Fortran compiler to use.
COMPILER=${COMPILER:-ifort}
Get_Compiler "${COMPILER}"

# ------------------------------------------------------------
# Check for the important modelling system directories.
MY_ROOT_DIR="${MY_ROOT_DIR:-${rootDIR}}"
MY_PROJECT_DIR="${MY_PROJECT_DIR:-${MY_ROOT_DIR}}"
MY_ROMS_SRC="${MY_ROMS_SRC:-${MY_ROOT_DIR}}"
ROMS_DIR="${ROMS_DIR:-${MY_ROMS_SRC:+${MY_ROMS_SRC}/ROMS}}"
WRF_DIR="${WRF_DIR:-${MY_ROMS_SRC:+${MY_ROMS_SRC}/WRF}}"
WPS_DIR="${WPS_DIR:-${MY_ROMS_SRC:+${MY_ROMS_SRC}/WPS}}"
SWAN_DIR="${SWAN_DIR:-${MY_ROMS_SRC:+${MY_ROMS_SRC}/SWAN}}"

Check_CoawstDirs

# Get all the models that are active in the coupled system
# that is, ROMS/WRF/SWAN and the coupling status (yes/no) of the system
CoawstActiveModels

# ------------------------------------------------------------
# Get the ROMS Version, Revision and Release Date
ROMS_VER=
ROMS_REV=
ROMS_DATE=
if `checkFILE -r ${ROMS_DIR}/Modules/mod_ncparam.F`; then
  ROMS_VER="`cat ${ROMS_DIR}/Modules/mod_ncparam.F | grep -Ei 'version.*='`"
  ROMS_VER="`echo "${ROMS_VER}" | sed -e 's/.*[vV][eE][rR][sS][iI][oO][nN].*=//g'`"
  ROMS_VER="`echo "${ROMS_VER}" | sed -e 's/'\''//g' | awk '{print $1}' | sed -e 's/[vV]//g'`"
fi
if `checkFILE -r ${ROMS_DIR}/Version`; then
  ROMS_REV="`cat ${ROMS_DIR}/Version | grep -Ei revision:`"
  ROMS_REV="`echo "${ROMS_REV}" | sed -e 's/.*[rR][eE][vV][iI][sS][iI][oO][nN]//g'`"
  ROMS_REV="`echo "${ROMS_REV}" | sed -e 's/[=;:,_()\{\}\$\\]/ /g' | awk '{print $1}'`"
  ROMS_DATE="`cat ${ROMS_DIR}/Version | grep -Ei changeddate: | sed -e 's/.*[aA][tT][eE]://g'`"
  ROMS_DATE="`echo "${ROMS_DATE}" | sed -e 's/\$//g' | awk '{print $1}'`"
  ROMS_DATE="`date --date="${ROMS_DATE}" "+%m-%d-%Y" 2>/dev/null`"
fi

# ------------------------------------------------------------
# Get the WRF Version
WRF_VER=
WRF_REV=
WRF_DATE=
if `checkFILE -r ${WRF_DIR}/inc/version_decl`; then
  WRF_VER="`cat ${WRF_DIR}/inc/version_decl | grep -Ei release_version`"
  WRF_VER="`echo "${WRF_VER}" | sed -e 's/.*[vV][eE][rR][sS][iI][oO][nN].*=//g'`"
  WRF_VER="`echo "${WRF_VER}" | sed -e 's/'\''//g' | awk '{print $1}' | sed -e 's/[vV]//g'`"
fi
if `checkFILE -r ${WRF_DIR}/README`; then
  if [ -n "${WRF_VER:+1}" ]; then
    WRF_DATE="`cat ${WRF_DIR}/README | grep -Ei "Version.*${WRF_VER}.*released on " | sed -e 's/.*released on[ ]//g'`"
    WRF_DATE="`echo ${WRF_DATE} | sed -e 's/[ ](rev.*//g'`"
    WRF_REV="`cat ${WRF_DIR}/README | grep -Ei "Version.*${WRF_VER}.*released on " | sed -e 's/.*[rR][eE][vV]//g'`"
    WRF_REV="`echo "${WRF_REV}" | sed -e 's/[=;,_()\{\}\\]/ /g' | awk '{print $1}'`"
  fi
  WRF_DATE="`date --date="${WRF_DATE}" "+%m-%d-%Y" 2>/dev/null`"
fi

# ------------------------------------------------------------
# Get the WPS Version
WPS_STR=
WPS_VER=
WPS_REV=
WPS_DATE=
if `checkFILE -r ${WPS_DIR}/README`; then
  WPS_STR="`cat ${WPS_DIR}/README | grep -Ei "Pre-Processing System Version"`"
  WPS_STR="`echo ${WPS_STR} | sed -e 's/[=;,_()\{\}\\]/ /g'`"
  WPS_VER="`echo ${WPS_STR} | sed -e 's/.*[vV][eE][rR][sS][iI][oO][nN]//g' | awk '{print $1}'`"
  if [ -n "${WPS_VER:+1}" ]; then
    WPS_DATE="`echo ${WPS_STR} | sed -e "s/.*[vV][eE][rR][sS][iI][oO][nN].*${WPS_VER}//g"`"
    WPS_DATE="`echo ${WPS_DATE} | sed -e "s/[rR][eE][vV].*//g"`"
    WPS_REV="`echo ${WPS_STR} | sed -e "s/.*[rR][eE][vV][iI][sS][iI][oO][nN]//g" | awk '{print $1}'`"
    unset WPS_STR
  fi
  WPS_DATE="`date --date="${WPS_DATE}" "+%m-%d-%Y" 2>/dev/null`"
fi

# ------------------------------------------------------------
# Get the SWAN Version
SWAN_VER=
SWAN_REV=
SWAN_DATE=
if `checkFILE -r ${SWAN_DIR}/Src/swanmain.F`; then
  SWAN_VER="`cat ${SWAN_DIR}/Src/swanmain.F | grep -Ei ".*VERNUM.*="`"
  SWAN_VER="`echo "${SWAN_VER}" | sed -e 's/.*[vV][eE][rR][nN][uU][mM].*=//g' | awk '{print $1}'`"
fi
if `checkFILE -r ${SWAN_DIR}/Src/swanuse.tex`; then
  if [ -n "${SWAN_VER:+1}" ]; then
    SWAN_DATE="`cat ${SWAN_DIR}/Src/swanuse.tex | grep -Ei "\(Version.*${SWAN_VER}" | sort -u`"
    SWAN_DATE="`echo ${SWAN_DATE} | sed -e 's/.*([vV][eE][rR][sS][iI][oO][nN].*,//g' | sed -e 's/[(),.]//g'`"
    SWAN_DATE="`echo ${SWAN_DATE} | awk '{print $1 " 1, " $2}'`"
  fi
  SWAN_DATE="`date --date="${SWAN_DATE}" "+%m-%d-%Y" 2>/dev/null`"
fi

# ------------------------------------------------------------
# Check for an MPI/OpenMP setup
if [ "${USE_MPI:-no}" = "yes" ] && [ "${USE_OpenMP:-no}" = "yes" ]; then
  echo " ### ERROR: in ${scrNAME}"
  echo "          USE_MPI = ${USE_MPI}"
  echo "       USE_OpenMP = ${USE_OpenMP}"
  echo "       Only one of the USE_MPI/USE_OpenMP variables can be set"
  echo "     Resetting OpenMP now ..."
  unset USE_OpenMP
  echo "       USE_OpenMP = ${USE_OpenMP}"
  echo
fi

if [ "${USE_MPI:-no}" = "no" ]; then
  unset USE_MPI
  unset USE_MPIF90
  unset USE_PNETCDF
  unset USE_PARALLEL_IO
else
  # force the use of mpif90 when USE_MPI="yes"
  USE_MPIF90="yes"
  Get_MpiCompiler "mpif90"
  if [ "${USE_PARALLEL_IO:-no}" = "yes" ]; then
    USE_PNETCDF=yes
    USE_NETCDF4=yes
    unset USE_NETCDF3
  else
    unset USE_PNETCDF
  fi
fi

[ "${USE_NETCDF4:-no}" = "yes" -o "${USE_PNETCDF:-no}" = "yes" -o "${USE_PARALLEL_IO:-no}" = "yes" ] && \
  unset USE_NETCDF3

# ------------------------------------------------------------
# Get the path of the NetCDF headers and libraries
Get_NetCDFPath
if [ "$?" -ne 0 ]; then
  echo " ### ERROR: in ${scrNAME} (NetCDF header/libraries)"
  echo "      No suitable NetCDF header/libraries found in the system"
  echo "      User/Script variables used:"
  echo "          USE_NETCDF3 = ${USE_NETCDF3:-no}"
  echo "          USE_NETCDF4 = ${USE_NETCDF4:-no}"
  echo "       NETCDF_VERSION = ${NETCDF_VERSION:-UNDEF}"
  echo "          NETCDF_ROOT = ${NETCDF_ROOT:-UNDEF}"
  echo "            NC_CONFIG = ${NC_CONFIG:-UNDEF}"
  echo "        NETCDF_INCDIR = ${NETCDF_INCDIR:-UNDEF}"
  echo "        NETCDF_LIBDIR = ${NETCDF_LIBDIR:-UNDEF}"
  echo "      NETCDF_PARALLEL = ${NETCDF_PARALLEL:-no}"
  echo "     Exiting now ..."
  echo
  exit 1
fi

# ------------------------------------------------------------
# Get the path of the NetCDF headers and libraries
Get_MCTPath
if [ "$?" -ne 0 ]; then
  echo " ### ERROR: in ${scrNAME} (MCT header/libraries)"
  echo "      No suitable MCT header/libraries found in the system"
  echo "      User/Script variables used:"
  echo "           USE_MCT = ${USE_MCT:-no}"
  echo "       MCT_VERSION = ${MCT_VERSION:-UNDEF}"
  echo "          MCT_ROOT = ${MCT_ROOT:-UNDEF}"
  echo "        MCT_INCDIR = ${MCT_INCDIR:-UNDEF}"
  echo "        MCT_LIBDIR = ${MCT_LIBDIR:-UNDEF}"
  echo "      MCT_PARALLEL = ${MCT_PARALLEL:-no}"
  echo "     Exiting now ..."
  echo
  exit 1
fi

# ------------------------------------------------------------
# Get the path of the HDF5 headers and libraries (possibly for parallel IO)
Get_HDF5Path
if [ "$?" -ne 0 ]; then
  echo " ### ERROR: in ${scrNAME} (HDF5 header/libraries)"
  echo "      No suitable HDF5 header/libraries found in the system"
  echo "      User/Script variables used:"
  echo "          NETCDF_ROOT = ${NETCDF_ROOT:-UNDEF}"
  echo "            NC_CONFIG = ${NC_CONFIG:-UNDEF}"
  echo "        NETCDF_INCDIR = ${NETCDF_INCDIR:-UNDEF}"
  echo "        NETCDF_LIBDIR = ${NETCDF_LIBDIR:-UNDEF}"
  echo "       NETCDF_VERSION = ${NETCDF_VERSION:-UNDEF}"
  echo "      NETCDF_PARALLEL = ${NETCDF_PARALLEL:-no}"
  echo "      USE_PARALLEL_IO = ${USE_PARALLEL_IO:-no}"
  echo "          USE_PNETCDF = ${USE_PNETCDF:-no}"
  echo "             USE_HDF5 = ${USE_HDF5:-no}"
  echo "            HDF5_ROOT = ${NETCDF_ROOT:-UNDEF}"
  echo "          HDF5_INCDIR = ${HDF5_INCDIR:-UNDEF}"
  echo "          HDF5_LIBDIR = ${HDF5_LIBDIR:-UNDEF}"
  echo "         HDF5_VERSION = ${HDF5_VERSION:-UNDEF}"
  echo "        HDF5_PARALLEL = ${HDF5_PARALLEL:-no}"
  echo "     Exiting now ..."
  echo
  exit 1
fi

# ------------------------------------------------------------
# Get the path of the PNetCDF headers and libraries
Get_PNetCDFPath
if [ "$?" -ne 0 ]; then
  echo " ### ERROR: in ${scrNAME} (PNetCDF header/libraries)"
  echo "      No suitable PNetCDF header/libraries found in the system"
  echo "      User/Script variables used:"
  echo "       NETCDF_VERSION = ${NETCDF_VERSION:-UNDEF}"
  echo "          NETCDF_ROOT = ${NETCDF_ROOT:-UNDEF}"
  echo "            NC_CONFIG = ${NC_CONFIG:-UNDEF}"
  echo "        NETCDF_INCDIR = ${NETCDF_INCDIR:-UNDEF}"
  echo "        NETCDF_LIBDIR = ${NETCDF_LIBDIR:-UNDEF}"
  echo "      NETCDF_PARALLEL = ${NETCDF_PARALLEL:-no}"
  echo "      USE_PARALLEL_IO = ${USE_PARALLEL_IO:-no}"
  echo "          USE_PNETCDF = ${USE_PNETCDF:-no}"
  echo "      PNETCDF_VERSION = ${PNETCDF_VERSION:-UNDEF}"
  echo "         PNETCDF_ROOT = ${NETCDF_ROOT:-UNDEF}"
  echo "       PNETCDF_INCDIR = ${PNETCDF_INCDIR:-UNDEF}"
  echo "       PNETCDF_LIBDIR = ${PNETCDF_LIBDIR:-UNDEF}"
  echo "     Exiting now ..."
  echo
  exit 1
fi

# ------------------------------------------------------------
# Get the path of the Jasper headers and libraries
# if requested.

if [ "${USE_JASPER:-no}" = "yes" ]; then
  theFiles="jasper.h jas_version.h"
  Check_Includes "${JASPER_INCDIR}" "${theFiles}" warning
  if [ $? -ne 0 ]; then
    unset JASPER_INCDIR
    echo " ### ERROR: in ${scrNAME} (Checking for Jasper headers)"
    echo "     Jasper headers not found"
    echo "     Exiting now ..."
    echo
    exit 1
  fi

  theFiles="libjasper.*"
  Check_Libraries "${JASPER_LIBDIR}" "${theFiles}" warning
  if [ $? -ne 0 ]; then
    unset JASPER_LIBDIR
    echo " ### ERROR: in ${scrNAME} (Checking for Jasper libraries)"
    echo "     Jasper libraries not found"
    echo "     Exiting now ..."
    echo
    exit 1
  fi
else
  unset JASPER_ROOT JASPER_INCDIR JASPER_LIBDIR
fi

# ------------------------------------------------------------
# Get the path of the NCARG headers and libraries
# if requested.

if [ "${USE_NCL:-no}" = "yes" ]; then
  theFiles="libncarg.* libncarg_gks.* libncarg_c.*"
  Check_Libraries "${NCL_LIBDIR}" "${theFiles}" warning
  if [ $? -ne 0 ]; then
    unset NCL_LIBDIR
    echo " ### ERROR: in ${scrNAME} (Checking for NCAR libraries)"
    echo "     NCAR libraries not found"
    echo "     Exiting now ..."
    echo
    exit 1
  fi
else
  unset NCL_ROOT NCL_INCDIR NCL_LIBDIR
fi

# ------------------------------------------------------------
# Make sure that all variables are set correctly
CoawstDefaults

Adjust_YESNOVars

#============================================================
# END:: CHECK THE VARIABLES
#============================================================


#============================================================
# BEG:: EXPORT ALL USER DEFINED VARIABLES
#============================================================

export CLEAN
export CLEANWRF
export CLEANWPS
export PARMAKE_NCPUS="${PARMAKE_NCPUS:+-j ${PARMAKE_NCPUS}}"
export MODFILES
export USE_DEBUG
export COMPILER
export CASEID
export USE_MPI
export USE_MPIF90
export USE_OpenMP
export ROMS_APPLICATION
export MY_ROOT_DIR
export MY_ROMS_SRC
export MY_PROJECT_DIR
export COMPILERS
export MY_HEADER_DIR
export MY_ANALYTICAL_DIR
export BINDIR
export SCRATCH_DIR
export MY_CPP_FLAGS
export NestedGrids
export USE_ADJOINT
export USE_TANGENT
export USE_REPRESENTER
export USE_ICE
export USE_ROMS
export USE_WRF
export WRF_OS
export WRF_MACH
export WRF_EM_CORE
export WRF_NMM_CORE
export WRFIO_NCD_LARGE_FILE_SUPPORT
export USE_SWAN
export USE_INWAVE
export USE_REFDIF
export USE_SED
export COUPLED_SYSTEM
export ROMS_DIR
export ROMS_VER
export ROMS_REV
export ROMS_DATE
export WRF_DIR
export WPS_DIR
export WRF_VER
export WRF_REV
export WRF_DATE
export SWAN_DIR
export SWAN_VER
export SWAN_REV
export SWAN_DATE
export USE_NETCDF3
export USE_NETCDF4
export USE_LARGE
export NETCDF_ROOT
export NC_CONFIG
export NETCDF_INCDIR
export NETCDF_LIBDIR
export NETCDF_VERSION
export NETCDF_MAJOR
export NETCDF_MINOR
export NETCDF_BUILD
export NETCDF_PARALLEL
export USE_HDF5
export HDF5_ROOT
export HDF5_INCDIR
export HDF5_LIBDIR
export HDF5_VERSION
export HDF5_MAJOR
export HDF5_MINOR
export HDF5_BUILD
export HDF5_PARALLEL
export USE_PARALLEL_IO
export USE_PNETCDF
export PNETCDF_INCDIR
export PNETCDF_LIBDIR
export PNETCDF_VERSION
export PNETCDF_MAJOR
export PNETCDF_MINOR
export PNETCDF_BUILD
export USE_MCT
export MCT_ROOT
export MCT_INCDIR
export MCT_LIBDIR
export MCT_PARALLEL
export MPEU_INCDIR="${MCT_INCDIR:-}"
export MPEU_LIBDIR="${MCT_LIBDIR:-}"
export USE_ARPACK
export ARPACK_ROOT
export ARPACK_INCDIR
export ARPACK_LIBDIR
export USE_PARPACK
export PARPACK_ROOT
export PARPACK_INCDIR
export PARPACK_LIBDIR
export USE_JASPER
export JASPER_ROOT
export JASPER_INCDIR
export JASPER_LIBDIR
export USE_NCL
export NCL_ROOT
export NCL_INCDIR
export NCL_LIBDIR
export NCL_XLIBS
export FORT="${COMPILER:-}"
export COMPSYS
export MPISYS
export MPIVER

#============================================================
# END:: EXPORT ALL USER DEFINED VARIABLES
#============================================================


#============================================================
# BEG:: ECHO THE FINAL VALUES OF THE ASSIGNED PARAMETERS
#       AND THE USER'S RESPONSE
#============================================================

Print_CoawstVars

echo
echo -n "Are these values correct? [y/n]: "
echo_response=
while [ -z "${echo_response}" ] ; do
  read echo_response
  echo_response="`getYesNo "${echo_response}"`"
done

if [ "${echo_response:-no}" = "no" ]; then
  echo
  echo "User responded: ${echo_response}"
  echo "Exiting now ..."
  echo
  exit 1
fi

unset echo_response

#============================================================
# END:: ECHO THE FINAL VALUES OF THE ASSIGNED PARAMETERS
#       AND THE USER'S RESPONSE
#============================================================


#============================================================
# BEG:: START THE COMPILATION
#============================================================

ulimit -s unlimited

# ------------------------------------------------------------
# These are for forcing the model to use the *_INCDIR and *_LIBDIR variables
unset USE_NETCDF3
unset USE_NETCDF4
unset NETCDF
unset USE_PNETCDF
unset PNETCDF

VER_STR=
if [ "${VERSIONING:-0}" -gt 0 ]; then
  VER_STR="${USE_PARALLEL_IO:+-pio}"
  VER_STR="${VER_STR}${COMPSYS:+-${COMPSYS}}${MPISYS:+-${MPISYS}${MPIVER:+-${MPIVER}}}"
  VER_STR="${VER_STR#-}"
fi
EXE_STR="${CASEID:-}${VER_STR:+-${VER_STR}}"
EXE_STR="${EXE_STR#-}"
export VER_STR EXE_STR

# Go to the COAWST/ROMS source directory and perform the preliminary tasks.
pushd ${MY_ROMS_SRC} > /dev/null 2>&1

  INP_MAKE=makefile-tmpl
  if `checkFILE -r ${INP_MAKE}`; then
    [ -f makefile ] && rm -f makefile
    cp -f ${INP_MAKE} makefile
    for imod in coawstS coawstG coawstM coawstO wrf.exe
    do
      imod_p="$(echo ${imod%%.exe})"
      imod_s="$(echo "${imod}" | sed "s/${imod_p}//g")"
      perl -pi -e  "s@\\$\(BINDIR\)/${imod}@\\$\(BINDIR\)/${imod_p}${EXE_STR:+-${EXE_STR}}${imod_s}@g" \
        makefile
    done

    # Remove previous build files/directories in the COAWST/WRF/WPS directories.
    Clean_WRF

    # Remove COAWST/ROMS build directory.
    Clean_ROMS

    # Build COAWST/WRF/WPS.
    Configure_WRF
  else
    echo
    echo "Could not compile ROMS because"
    echo "the makefile <${INP_MAKE}> were not found"
    echo
  fi
popd > /dev/null 2>&1


########## BEG:: DO_COMPILE
if [ "${DO_COMPILE}" -gt 0 ]; then
  # Compile (the binaries will go to BINDIR set above).
  # Always the MY_PROJECT_DIR is the same as the BINDIR
  # (BINDIR is internally set to be: BINDIR=MY_PROJECT_DIR).
  pushd ${MY_ROMS_SRC} > /dev/null 2>&1

    if [ -n "${USE_WRF:+1}" ]; then
      make ${PARMAKE_NCPUS} wrf

      # Compile in the WPS directory.
      if [ -n "${BUILD_WPS:+1}" ]; then
        pushd ${WPS_DIR} > /dev/null 2>&1
          ./compile wps
          ./compile util
        popd > /dev/null 2>&1
      fi
    fi

    make ${PARMAKE_NCPUS}
      
    # Remove the modified makefile
    [ -f makefile ] && rm -f makefile
  popd > /dev/null 2>&1

  model_exe=
  for imod in coawstS coawstG coawstM coawstO wrf.exe
  do
    imod_p="$(echo ${imod%%.exe})"
    imod_s="$(echo "${imod}" | sed "s/${imod_p}//g")"
    if `checkPROG -r ${BINDIR}/${imod_p}${EXE_STR:+-${EXE_STR}}${imod_s}`; then
      model_name="${imod_p}"
      model_exe="${imod_p}${EXE_STR:+-${EXE_STR}}${imod_s}"
      break
    fi
  done

  if `checkPROG -r ${MY_PROJECT_DIR}/${model_exe}`; then

    # ------------------------------------------------------------
    # Install various necessary data files.
    Install_ROMSFiles
    Install_WRFFiles
    Install_WPSFiles
    Install_SWANFiles

    if [ "${BINDIR}" != "${MY_PROJECT_DIR}" ]; then
     install -m 0755 -p "${BINDIR}/${model_exe}" "${MY_PROJECT_DIR}/${model_exe}"
    fi

    # ------------------------------------------------------------
    # Create the run-msub script.
    f_inp="coawst_run-msub-script"
    f_out="${MY_PROJECT_DIR}/run-msub${model_name:+-${model_name}}.sh"
    Make_RUNScripts "${f_inp}" "${f_out}"

    # ------------------------------------------------------------
    # Create the standalone run script(s).
    f_inp="coawst_run-script"
    f_out="${MY_PROJECT_DIR}/run${model_name:+-${model_name}}.sh"
    Make_RUNScripts "${f_inp}" "${f_out}"

    for i in functions_common functions_run gom-coupling.in-tmpl
    do
      if `checkFILE -r ${i}`; then
        j="$(echo ${i} | sed -e 's/gom-//g')"
        j="`basename ${j}`"
        echo "Installing -> ${MY_PROJECT_DIR}/${j}"
        install -m 0644 -p ${i} ${MY_PROJECT_DIR}/${j}
      else
        echo "ERROR:: $0: Couldn't install the required file:"
        echo "          file = ${i:-UNDEF}"
        echo "        Exiting now ..."
        echo -n
        exit 1
      fi
    done

    [ -f fort-namelist ] && \
      install -m 0755 -p fort-namelist ${MY_PROJECT_DIR}/
  fi
fi
########## END:: DO_COMPILE
