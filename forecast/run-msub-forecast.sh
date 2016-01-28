#!/bin/bash

## Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
##                                 <velissariou.1@osu.edu>
## Version: 1.2
##
## Version - 1.2 Fri Jul 26 2013
## Version - 1.1 Wed Jul  3 2013
## Version - 1.0 Tue Jul 31 2012

#####
## Can run this msub script by suppling command line options (in addition to the msub options).
## Alternatively, these options can be set within this msub script (see lines just below the
## MOAB directive lines.
## These options are passed to the main script (after the MOAB directives) and they can
## be specified by using:
##    msub [moab/torque options] [-v opt1=val1,opt2=val2,...]
##        where the pairs optX=valX are comma seperated options (no spaces) following
##        the -v command line option
## Valid options optX=valX are:
## ms_id="caseid"   : Set a name/id for the case being run
##                    MANDATORY: yes
##                    DEFAULT  : not set
## ms_dat="data_dir": The root directory where all necessary data are stored
##                    USE: ms_dat=path_to_directory
##                    MANDATORY: yes
##                    DEFAULT  : not set
## ms_beg="start"   : The starting date for the simulation being run
##                    Can be set using the "sbeg" option or the "SimBeg" defined
##                    a few lines below
##                    USE: ms_beg="2010/02/12"
##                    FORMAT : YYYY/MM/DD [HH:MN:SC] or YYYY-MM-DD [HH:MN:SC]
##                    MANDATORY: yes
##                    DEFAULT  : not set
## ms_end="end"     : The ending date for the simulation being run
##                    Can be set using the "sbeg" option or the "SimEnd" defined
##                    a few lines below
##                    USE: ms_end="2010/03/12"
##                    FORMAT : YYYY/MM/DD [HH:MN:SC] or YYYY-MM-DD [HH:MN:SC]
##                    MANDATORY: yes
##                    DEFAULT  : not set
## ms_inp=input     : The main input/configuration file to be used for the simulation
##                    USE: ms_inp=filename
##                    MANDATORY: yes
##                    DEFAULT  : not set
## ms_init=init_flag: Set the initialization flag. init_flag >= 1 means that the model
##                    is to be initialized while, init_flag <= 0 means that the model will
##                    run using restart files
##                    USE: ms_init=1
##                    MANDATORY: no
##                    DEFAULT  : 0 (work from restart files)
## ms_host=host_flag: host_flag >= 1 means that the model is to use a host/machine file
##                    while, host_flag <= 0 means do not use a machinefile
##                    This machine file is created internally by this
##                    USE:  ms_host=1
##                    MANDATORY: no
##                    DEFAULT  : 0 (do not use a hostfile)
## ms_mods="modules": The names of the modules to load and use at runtime
##                    The required modules are already set by the build script during compilation
##                    This option is available to supply these modules from the command line,
##                    in case the names of the modules are different or, something went wrong
##                    USE: ms_mods="module1 module2 ..."
##                    MANDATORY: no
##                    DEFAULT  : not set
#####

##MOAB -l nodes=N:ppn=M
##MOAB -l nodes=N
##MOAB -l walltime=HH:MM:SS
#MOAB -j oe
#MOAB -e moab_error.log
#MOAB -o moab_output.log
#MOAB -N run-msub-coawstM
#MOAB -q coaps_q


# The following can be supplied from the commandline as described above, or
# their values can be specified here instead. By setting these values you will
# always overwrite the script relevant values defined after the line progNAME=...
# If they are not set, then the values defined after the line progNAME=... will
# be used instead. See function "ParseArgsMsub" in the file functions_run.
# ms_id   : It used instead of CASEID, see in ParseArgsMsub
# ms_dat  : It used instead of DATA_DIR, see in ParseArgsMsub
# ms_beg  : It used instead of SimBeg, see in ParseArgsMsub
# ms_end  : It used instead of SimEnd, see in ParseArgsMsub
# ms_inp  : It used instead of MODEL_INP, see in ParseArgsMsub
# ms_init : It used instead of FORCE_INI, see in ParseArgsMsub
# ms_mods : It used instead of MODFILES, see in ParseArgsMsub
# ms_host : If it is set to a value >=0 the script will try to create a host file to be used
#           along with the mpirun command
#
#ms_id=
#ms_dat=
#ms_beg=
#ms_end=
#ms_inp=
#ms_init=
#ms_mods=
#ms_host=


#------------------------------------------------------------
# Change directory to PBS_O_WORKDIR. All subsequent operations
# are performed relative to this directory.
cd ${PBS_O_WORKDIR}
#------------------------------------------------------------


#------------------------------------------------------------
# UTILITY FUNCTIONS
#
[[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."

if [ -f functions_run ]; then
  . functions_run
else
  echo " ### ERROR: in $0"
  echo "     Cannot locate the file: functions_run"
  echo "     Exiting now ..."
  echo
  exit 1
fi

progDIR=.
progNAME=coawstM

####################
# External forcing variables
# This is used when:
#   (a) WRF forcing is not desired and the WRF model is not compiled in;
#       Atmospheric fields are supplied by external forcing data, these
#       fields are pre-processed to conform with ROMS formats.
#   (b) Additional forcing is required for ROMS (e.g., river inputs).
#   (c) Atmospheric forcing is supplied only from external data (1-way coupling).
#   USE_FRC   -> Indicates the use of external forcing data (other than WRF);
#                expected values are 1/yes, 0/no
#                DEFAULT: no
#   FRC_DIR   -> The directory or the list of directories where the
#                forcing files are stored.
#                DEFAULT: "DATA_DIR DATA_DIR/forcing" (specification is optional).
#    FRC_PFX  -> The list of the prefixes (up to the date substring in the filenames)
#                of ALL forcing files.
#                DEFAULT: NONE (specification is mandatory).
#    FRC_SFX   -> The list of the suffixes (after the date substring in the filenames)
#                DEFAULT: NONE (specification is optional).
USE_FRC=
FRC_DIR=
FRC_PFX=
FRC_SFX=


####################
# Simulation and common variables
# These variables are shared amongnst all models involved
# YYYY/MM/DD [HH:MN:SC] or YYYY-MM-DD [HH:MN:SC]
# The values can be specified here or in the command line
# Currently the HH:MN:SC are set to: 00:00:00
#  SimTitle   -> The title for the simulation being run
#                DEFAULT: GOM 1\/50 degree
#    SimBeg   -> The starting date for the simulation being run,
#                in the form of:
#                  YYYY/MM/DD [HH:MN:SC] or YYYY-MM-DD [HH:MN:SC]
#                Currently the HH:MN:SC part is set to: "00:00:00"
#                This value can be either specified here or in the command line
#                DEFAULT: none, NEEDS TO BE SPECIFIED
#    SimEnd   -> The ending date for the simulation being run
#                (format/specification/default similar as in SimBeg)
#  DATA_DIR   -> The root directory where all necessary data for this
#                simulation are stored
#    ref_date -> Reference date for all simulations, in the form of:
#                  YYYY/MM/DD [HH:MN:SC] or YYYY-MM-DD [HH:MN:SC]
#                See: functions "check*FILE" in "functions_run"
#                DEFAULT: "1900/12/31 00:00:00"
#    his_freq -> Frequency of writing the new history files
#                See: functions "Modify_*Config" found in "functions_run"
#                DEFAULT: 86400 (seconds) = 1-day
#    rst_freq -> Frequency of writing the re-start fields
#                See: functions "Modify_*Config" found in "functions_run"
#                DEFAULT: 86400 (seconds)
SimTitle=
SimBeg=
SimEnd=
DATA_DIR=
ref_date="1900/12/31 00:00:00"
#his_freq=21600
#rst_freq=21600
#his_freq=43200
#rst_freq=43200
his_freq=86400
rst_freq=86400


####################
# ROMS related variables
# From this script, only these variables are modified
# in the ROMS input config file (e.g., ocean.in)
# See: functions "checkROMSFILE" and "Modify_ROMSConfig" in the file "functions_run"
# romsPFX     -> Optional prefix for all ROMS related I/O files,
#                this is used when the user needs to differentiate
#                the input files based on the case being simulated,
#                or some other reason
#                DEFAULT: none
# romsSFX     -> Optional suffix for all ROMS related I/O files,
#                this is used when the user needs to differentiate
#                the input files based on the case being simulated,
#                or some other reason,
#                or some other reason
#                DEFAULT: none
# romsNPROC_X -> The number of tiles to be assigned for the x-direction
#                of the computations (modifies the variable NtileI).
#                USAGE: romsNPROC_X="1 3 5 4 ..." (string of unlimited entries)
#                       romsNPROC_X=              (empty string)
#                - If romsNPROC_X is empty the script will get its values
#                  from the variable NtileI in the input file
#                - If the number of entries in romsNPROC_X are less than
#                  romsDOMS, then the last entry in romsNPROC_X is used
#                  to fill the remaining entries. Setting for example:
#                  romsNPROC_X=6 and romsDOMS=4 the script will modify
#                  "romsNPROC_X" as romsNPROC_X="6 6 6 6"
#                DEFAULT: none
# romsNPROC_Y -> The number of tiles to be assigned for the x-direction
#                of the computations (modifies the variable NtileJ).
#                USAGE: same as "romsNPROC_X"
#                Modified the same way as "romsNPROC_X"
#                DEFAULT: none
# romsDT      -> The time-step size (baroclinic in 3D, barotropic in 2D),
#                one to unlimited entries.
#                Modified in a similar way as "romsNPROC_X".
#                DEFAULT: 600 (seconds)
# romsNDTFAST -> The number of barotropic time-steps to reach "romsDT",
#                one to unlimited entries.
#                Modified in a similar way as "romsNPROC_X".
#                DEFAULT: 30 (dimensionless)
# romsHFRM    -> The time lengths to write in each history file for each nest
#                that is, write records every XXX seconds
#                romsHFRM="XXX XXX XXX ..." (up to number of nested domains)
#                DEFAULT: 86400 (seconds), 1-day
romsPFX=
romsSFX=
romsNPROC_X=
romsNPROC_Y=
romsDT=
romsNDTFAST=
romsHFRM=


####################
# WRF related variables
# From this script, only these variables are modified
# in the WRF input config file (e.g., namelist.input)
# See: functions "checkWRFFILE" and "Modify_WRFConfig" in the file "functions_run"
# wrfPFX      -> Optional prefix for all WRF related I/O files
#                DEFAULT: none
# wrfSFX      -> Optional suffix for all WRF related I/O files
#                DEFAULT: none
# wrfDOMS     -> The number of nested domains in WRF
#                (the parent or largest domain always has id=1)
#                wrfDOMS is set in the function "Check_InputConfigs"
#                DEFAULT: 1
# wrfNPROC_X  -> The number of processors to be assigned for the x-direction
#                of the computations (modifies the variable nproc_x).
#                USAGE: wrfNPROC_X=20   (string of unlimited entries)
#                       wrfNPROC_X=     (empty string)
#                (script will use only the first entry).
#                - If wrfNPROC_X is empty the script will get its value
#                  from the variable nproc_x in the input file
#                - If wrfNPROC_X is assigned a value, the script will
#                  modify the variable nproc_x accordingly.
#                DEFAULT: none
# wrfNPROC_Y  -> The number processors to be assigned for the y-direction
#                of the computations (modifies the variable nproc_y).
#                USAGE: same as "wrfNPROC_X"
#                Modified the same way as "wrfNPROC_X"
# wrfDT       -> The time-step size (~6*50km = 300s)
#                wrfDT="XXX XXX XXX ..." (up to number of nested domains)
#                DEFAULT: 300 (seconds)
# wrfHFRM     -> The time lengths to write in each history file for each nest
#                that is, write records every XXX seconds
#                wrfHFRM="XXX XXX XXX ..." (up to number of nested domains)
#                DEFAULT: 86400 (seconds), 1-day
wrfPFX=
wrfSFX=
wrfDOMS=
wrfNPROC_X=
wrfNPROC_Y=
wrfDT=
wrfHFRM=


####################
# SWAN related variables
# From this script, only these variables are modified
# in the SWAN input config file(s) (e.g., ????)
# See: functions "checkSWANFILE" and "Modify_SWANConfig" in the file "functions_run"
# swanPFX     -> Optional prefix for all SWAN related I/O files,
#                this is used when the user needs to differentiate
#                the input files based on the case being simulated,
#                or some other reason
#                DEFAULT: none
# swanSFX     -> Optional suffix for all ROMS related I/O files,
#                this is used when the user needs to differentiate
#                the input files based on the case being simulated,
#                or some other reason
#                DEFAULT: none
#  swanNPROC  -> The number of processors to be assigned for SWAN computations.
#                If a value is supplied from the command line and
#                  COUPLED_SYSTEM=no and USE_SWAN=yes
#                it overwrites the variable "swanNPROC"
#                DEFAULT: 1
swanPFX=
swanSFX=
swanNPROC=


#============================================================
# NO NEED TO MODIFY ANYTHING BELOW
#============================================================
####################
# Define here what modeling components are being used.
# VALID VALUES: yes/no or empty
# These are set by the build script during the compilation statge.
# If for some reason the values are not what you want you can modify
# these variables manually.
# romsDOMS    -> The number of nested domains in ROMS
#                (the parent or largest domain always has id=1)
#                DEFAULT: 1
# swanDOMS    -> The number of nested domains in SWAN
#                (the parent or largest domain always has id=1)
#                DEFAULT: 1
COUPLED_SYSTEM=yes
USE_MPI=yes
USE_WRF=yes
USE_ROMS=yes
USE_SWAN=no
USE_SED=no
romsDOMS=1
swanDOMS=1


#------------------------------------------------------------
# Call ParseArgsMsub to get any supplied options to the script.
ParseArgsMsub
#------------------------------------------------------------


#------------------------------------------------------------
# Get all the input variables

##### Get the "start" and the "end" times for the current simulation.
getStartEndTimes

##### The id of the case we are running (if any).
#     This is just an identification string that separates
#     model outputs to different directories according
#     to the case id.
CASEID="${CASEID:-}"
VERSID=""

##### The name of the filename of main model input file.
#     This file should exist and be readable by the current user.
#     Also get the names of the individual model input files (if any) and
#     the total number of cpus to be used for this run
#     (if defined in the input files)
MODEL_INP="${MODEL_INP:-coawst_input_script.in}"
Check_InputConfigs "${MODEL_INP}"

##### The name of the modulefile(s) to load (if any).
#     If during compilation modules were used to set the paths
#     of the compilers/libraries then, the same modules should
#     be used/loaded at runtime as well.
#     It is given the option to supply these modules from the
#     command line of this script, in case the names of the modulefiles
#     is different or, something went wrong.
#      MODFILES: is an optional parameter passed if the
#                user supplied a value for it.
MODFILES="${MODFILES:-intel12 intel12-openmpi}"
##### If MODFILES is still null, try to use the uncommented option next:
#MODFILES="${MODFILES:-intel-openmpi}"
#MODFILES="${MODFILES:-intel-openmpi-1.6.4}"

##### The command line to run the model and the total number of cpus
#     to be used for this run.
if ! `checkPROG -r "${progDIR:+${progDIR}/}${progNAME}"`; then
  echo "Failed to find the executable: ${progDIR:+${progDIR}/}${progNAME}"
  echo "Exiting now ..."
  exit 1
fi
RUN_AS="`RunModelAs`"

# Check if the -n [cpus] option was supplied to the script.
# It has no effect if USE_MPI is set to "no"
if [ "`getYesNo "${USE_MPI:-no}"`" = "yes" ]; then
  s_npc=$(String_getInteger "${UserCPUS:-0}" 0)
    [ "${s_npc:-0}" -le 0 ] && unset s_npc
  m_npc=$(String_getInteger "${ModelCPUS:-0}" 0)
    [ "${m_npc:-0}" -le 0 ] && unset m_npc

  npc="${s_npc:-${m_npc:+${m_npc}}}"
  if [ -z "${npc:-}" ]; then
    echo "ERROR:: Couldn't determine the number of CPUs from the file(s):"
    echo "          files(s) = ${MODEL_INP}"
    echo "         or from the user's supplied input"
    exit 1
  else
    if [ -n "${m_npc:+1}" -a -n "${s_npc:+1}" ]; then
      if [ ${m_npc} -ne ${s_npc} ]; then
        echo "ERROR:: Inconsistent number of CPUs between the values obtained from the file(s):"
        echo "          files(s) = ${MODEL_INP}"
        echo "        and the user's input"
        exit 1
      fi
    fi
  fi

  # Set the options passed to mpirun.
  #mpirun_opt="-np ${npc}"

  # The hostfile to be used (if any)
  if `checkFILE -r "${HOSTFILE:-}"`; then
    mpirun_opt="${mpirun_opt:-} -machinefile ${HOSTFILE}"
  fi

  RUN_AS="mpirun ${mpirun_opt} ${RUN_AS}"
fi
#------------------------------------------------------------


#------------------------------------------------------------
out_dir="Output${CASEID:+/${CASEID}}${VERSID:+/${VERSID}}"
if ! `checkDIR -rx "${out_dir}"`; then mkdir -p "${out_dir}"; fi

log_dir="Logs${CASEID:+/${CASEID}}${VERSID:+/${VERSID}}"
if ! `checkDIR -rx "${log_dir}"`; then mkdir -p "${log_dir}"; fi

log_file="${log_dir:+${log_dir}/}run.log"
if `checkFILE -r "${log_file}"`; then
  my_date="`stat -c "%x" "${log_file}" | sed 's/\./ /g' | awk '{printf "%s_%s", $1, $2}'`"
  my_name="`basename ${log_file} .log`"
  mv -f "${log_file}" "${log_dir:+${log_dir}/}${my_name}_${my_date}.log"
fi

log_script="${log_dir:+${log_dir}/}run-msub-coawstM.log"
if `checkFILE -r "${log_script}"`; then
  my_date="`stat -c "%x" "${log_script}" | sed 's/\./ /g' | awk '{printf "%s_%s", $1, $2}'`"
  my_name="`basename ${log_script} .log`"
  mv -f "${log_script}" "${log_dir:+${log_dir}/}${my_name}_${my_date}.log"
fi
#------------------------------------------------------------


#echo "Setting -> ulimit -c unlimited" >> ${log_script}
#ulimit -c unlimited
echo "      Setting: ulimit -s unlimited" >> ${log_script}
ulimit -s unlimited


#------------------------------------------------------------
# Load any requested modules.
if [ -n "${MODFILES:+1}" ]; then
  chkMOD="`which modulecmd 2>&1 | grep -vEi "no.*modulecmd"`"
  if [ -n "${chkMOD:+1}" ]; then
    chkMOD="$(echo $(module -V 2>&1) | grep -vEi "not.*found")"
    [ -z "${chkMOD:-}" ] && module() { eval `modulecmd sh $*`; }
    echo "Removing all loaded modules" >> ${log_script}
    module purge > /dev/null 2>&1
    [[ ! :$PATH: == *:".":* ]] && export PATH="${PATH}:."
    for imod in ${MODFILES}
    do
      module load "${imod}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Couldn't load the requested module: ${imod}" >> ${log_script}
        exit 1
      else
        echo "Loaded module: ${imod}" >> ${log_script}
      fi
    done
  fi
fi
#------------------------------------------------------------


#------------------------------------------------------------
# Run the model multiple times using the appropriate restart files.
# This script assumes that the minimum run has at least a length of 1-day.
#
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

    # ---------- Create the strings to be used in the construction
    #            of the filenames.
    firstYRStr="`getYearString ${firstYR}`"
    firstMOStr="`get2DString ${firstMO}`"
    firstDAStr="`get2DString ${firstDA}`"

    lastYRStr="`getYearString ${lastYR}`"
    lastMOStr="`get2DString ${lastMO}`"
    lastDAStr="`get2DString ${lastDA}`"

    nextYRStr="`getYearString ${nextYR}`"
    nextMOStr="`get2DString ${nextMO}`"
    nextDAStr="`get2DString ${nextDA}`"

    # ---------- Modify/Adjust the configuation of the three models
    #            based on the simulation dates and other user inputs.
    Modify_ROMSConfig
    Modify_WRFConfig
    Modify_SWANConfig

    # ---------- Run the model/system
    echo "      Running: ${RUN_AS}" >> ${log_script}
    ${RUN_AS}  >> ${log_file} 2>&1
    move_files >> ${log_file} 2>&1

    # next monthly runs will use restart files for all models.
    FORCE_INI=0
  done
done
