#!/bin/bash

# Author:  Panagiotis Velissariou <pvelissariou@fsu.edu>
#                                 <velissariou.1@osu.edu>
# Version: 1.1
#
# Version - 1.1 Fri Jul 26 2013
# Version - 1.0 Wed Jul 25 2012

# This script takes zero or one arguments:
# fix_permissions.sh perm -> to only fix the permissions of the files
# fix_permissions.sh dos  -> to only convert from dos to unix the files
# fix_permissions.sh all  -> to do both of the above

##########
# Script identification variables
# The script name and the directory where this script is located
scrNAME=`basename ${0}`
scrDIR=`dirname ${0}`
pushd ${scrDIR} > /dev/null 2>&1
scrDIR="`pwd`"
popd > /dev/null 2>&1

FILE=/usr/bin/file
FIND=/bin/find
DOS2UNIX=/usr/bin/dos2unix

do_perm=0
do_dos=0
do_all=0
my_opt="`echo "${1}" | tr A-Z a-z`"
case "${my_opt}" in
  per*) do_perm=1;;
  dos*) do_dos=1;;
   all) do_all=1;;
     *) do_perm=1;; # DEFAULT
esac

#============================================================
# BEG:: LOCAL FUNCTIONS
#============================================================
# -------------------------------------------------------
# checkPROG()
# Usage:      checkPROG [options] program
# Parameters: program (string)
# Returns:    1 if the options are not met or, no arguments
#             were supplied or, the program is an empty string
#             0 in any other case (success)
# Echoes:     NONE
#
# Possible options are:
# -h FILE exists and is a symbolic link (same as -L)
# -L FILE exists and is a symbolic link (same as -h)
# -r FILE exists and is readable
# -s FILE exists and has a size greater than zero
#
# Checks if the program "program" is a valid executable
# program based on the options supplied. If no options
# supplied it simply checks that if "program" is an
# executable program
# -------------------------------------------------------
checkPROG()
{
  local -i retval=0
  local get_opts my_arg="" chk_my_arg="" my_opts="-f -x" iopt
# Use these to reset the options since the shell does not
# do that automatically
  local opt_id=${OPTIND} opt_arg="${OPTARG}"

  [ $# -eq 0 ] && { retval=1; return ${retval}; }

  while getopts ":hLrs" get_opts
  do
    case ${get_opts} in
      h|L) my_opts="${my_opts} -h";;
        r) my_opts="${my_opts} -r";;
        s) my_opts="${my_opts} -s";;
        *) ;; # DEFAULT
    esac
  done

# Get the first argument after the options
  shift $(($OPTIND - 1))
  my_arg=${1}

# Reset the option variables since the shell doesn't do it
  OPTIND=${opt_id}
  OPTARG="${opt_arg}"

  chk_my_arg="`echo "${my_arg##*/}" | sed -e 's/[ \t]//g'`"
  [ "X${chk_my_arg}" = "X" ] && { retval=1; return ${retval}; }

  for iopt in ${my_opts}
  do
    [ ! ${iopt} ${my_arg} ] && { retval=1; return ${retval}; }
  done

  return ${retval}
}
#============================================================
# END:: LOCAL FUNCTIONS
#============================================================


if ! `checkPROG -r "${FILE}"`; then
  echo "Failed to find the executable: ${FILE}"
  echo "Exiting now ..."
  exit 1
fi

if ! `checkPROG -r "${FIND}"`; then
  echo "Failed to find the executable: ${FIND}"
  echo "Exiting now ..."
  exit 1
fi

if ! `checkPROG -r "${DOS2UNIX}"`; then
  echo "Failed to find the executable: ${DOS2UNIX}"
  echo "Exiting now ..."
  exit 1
fi


my_files="`${FIND} -L -type f 2>&1 | grep -v 'find:.*unknown' | xargs`"

for i in ${my_files}
do
  my_check=
  my_text=
  my_data=
  my_script=
  if [ "X`echo ${i} | grep -v ${scrNAME}`" != "X" ]; then
    my_check="`${FILE} -b -p -L ${i} 2>&1`"
    my_text="`echo ${my_check} | grep 'text'`"
    my_data="`echo ${my_check} | grep 'data'`"
    my_script="`echo ${my_check} | grep 'script'`"
    if [ -n "${my_text:+1}" -o -n "${my_data:+1}" ]; then
      # convert the text file from dos to unix format if requested
      if [ ${do_dos} -gt 0 -o ${do_all} -gt 0 ]; then
        [ -n "${my_text:+1}" ] && ${DOS2UNIX} --keepdate "${i}"
      fi
      # change the file permissions if requested (default)
      if [ ${do_perm} -gt 0 -o ${do_all} -gt 0 ]; then
        if [ -n "${my_script:+1}" ]; then
          chmod 0755 "${i}"
        else
          chmod 0644 "${i}"
        fi
      fi
    fi
  fi
done
