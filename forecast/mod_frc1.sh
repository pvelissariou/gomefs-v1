#!/bin/bash

source functions_common

Modify_ROMSConfig()
{
  local nm_func="${FUNCNAME[0]}"

  local -i ido nDOMS ntimes
  local -i intv1 intv2
  local -i ifl nfiles file_OK=0

  local file1 file2 ifile idir
  local rdays

  local my_USE_ROMS my_USE_WRF my_USE_FRC my_USE_SWAN my_USE_SED

  local my_data_dir
  local my_beg_date my_end_date
  local beg_date end_date beg_jul end_jul
  local chk_date chk_jul chk_jul1 chk_jul2

  local my_FPFX my_FSFX my_FEXPR my_FILE my_DIRS
  local fileGRD my_fileGRD fileGRDLNK my_fileGRDLNK
  local fileINI my_fileINI fileINILNK my_fileINILNK
  local fileBRY my_fileBRY fileBRYLNK my_fileBRYLNK
  local fileCLI my_fileCLI fileCLILNK my_fileCLILNK

  local my_NFFILES my_FRC_DIR
  local fileFRC my_fileFRC fileFRCLNK my_fileFRCLNK

  local fileOUT my_fileOUT fileOUTLNK my_fileOUTLNK

  local my_Lm my_Mm my_N
  local my_Vtransform my_Vstretching my_theta_s my_theta_b my_Tcline

  local my_NTIMES my_NTIMESval
  local my_domDT my_domNDTFAST my_domHFRM
  local my_DT my_DTval my_NDTFAST my_NDTFASTval
  local my_NDEFHIS my_NHIS my_HISval my_HFRMval
  local my_NRST my_NRSTval my_NRREC my_NRRECval

  local ixpr xpr1 xpr2 xpr3 xpr4 domstr

  unset romsLINKFILES

  # The environment variables USE_* should be already set before calling this function.
  my_USE_ROMS="`getYesNo "${USE_ROMS:-no}"`"
  my_USE_WRF="`getYesNo "${USE_WRF:-no}"`"
  my_USE_FRC="`getYesNo "${USE_FRC:-no}"`"
  my_USE_SWAN="`getYesNo "${USE_SWAN:-no}"`"
  my_USE_SED="`getYesNo "${USE_SED:-no}"`"

  [ "${my_USE_ROMS}" = "no" ] && return 0

  if ! `checkFILE -r "${romsINP}"`; then
    procError "couldn't locate the ROMS input file" \
              "need to define USE_ROMS=yes" \
              "and the ROMS input configuration file." \
              "USE_ROMS = ${my_USE_ROMS}" \
              "romsINP  = ${romsINP:-UNDEF}"
  fi


  # ---------- BEG:: Initialize local variables
  nDOMS=$(String_getInteger "${romsDOMS:-1}" 1)
  my_data_dir="${DATA_DIR:-.}"

  if [ -n "${romsDT:+1}" ]; then
    my_domDT=( ${romsDT} )
    if [ ${nDOMS} -gt ${#my_domDT[@]} ]; then
      procError "need to specify ${nDOMS} values for romsDT" \
                "ROMS Domains = ${nDOMS}" \
                "      romsDT = ${romsDT:-UNDEF}"
    fi
  fi

  if [ -n "${romsNDTFAST:+1}" ]; then
    my_domNDTFAST=( ${romsNDTFAST} )
    if [ ${nDOMS} -gt ${#my_domNDTFAST[@]} ]; then
      procError "need to specify ${nDOMS} values for romsNDTFAST" \
                "ROMS Domains = ${nDOMS}" \
                " romsNDTFAST = ${romsNDTFAST:-UNDEF}"
    fi
  fi

  # number of time-steps between writing fields into history file
  if [ -n "${romsHFRM:+1}" ]; then
    my_domHFRM=( ${romsHFRM} )
    if [ ${nDOMS} -gt ${#my_domHFRM[@]} ]; then
      procError "need to specify ${nDOMS} values for romsHFRM" \
                "ROMS Domains = ${nDOMS}" \
                "    romsHFRM = ${romsHFRM:-UNDEF}"
    fi
  fi

  my_beg_date="${firstYR}-${firstMO}-${firstDA} ${firstHR}:${firstMN}:${firstSC}"
  my_end_date="${lastYR}-${lastMO}-${lastDA} ${lastHR}:${lastMN}:${lastSC}"

  beg_date="$( getDate --date="${my_beg_date}" --fmt='+%F_%T' )"
  if [ $? -ne 0 ]; then
    procError "wrong \"start\" date for the simulation." \
              "first DATE = ${my_beg_date}"
  fi

  end_date="$( getDate --date="${my_end_date}" --fmt='+%F_%T' )"
  if [ $? -ne 0 ]; then
    procError "wrong \"end\" date for the simulation." \
              "last DATE = ${my_end_date}"
  fi

  beg_jul=$( getDate --date="${my_beg_date}" --fmt='+%s' )
  end_jul=$( getDate --date="${my_end_date}" --fmt='+%s' )
  if [ ${end_jul} -lt ${beg_jul} ]; then
    procError "wrong \"end\" date for the simulation: SimEnd >= SimBeg." \
              "first DATE = ${my_beg_date}" \
              " last DATE = ${my_end_date}"
  fi

  # Determine the length (in days) of the current simulation
  rdays="$(echo "scale=5; ( ${end_jul} - ${beg_jul} ) / 86400.0" | bc -ql 2>/dev/null)"
  # ---------- END:: Initialize local variables


  # ---------- BEG:: Bathymetry files
  # We need to have bathymetry files for all ROMS domains
  for ((ido = 0; ido < ${nDOMS}; ido++))
  do
    domstr="_d`get2DString $((ido + 1))`"
    my_FEXPR=
    my_FILE=
    file_OK=0

    # check for bathymetry files in "my_DIRS"
    my_FPFX="romsgrd${domstr}"
    my_FEXPR="${romsPFX:+${romsPFX}_}${my_FPFX}${romsSFX:+_${romsSFX}}(\.n.*)?"
    my_DIRS="${my_data_dir} ${my_data_dir}/bath"
    fileGRDLNK="ocn_grd${domstr}.nc"

    searchFILE "${my_FEXPR}" "${my_DIRS}"
    if [ $? -eq 0 ]; then
      for file1 in ${foundFilePath}
      do
        if `checkFILE -r "${file1}"`; then
          my_FILE="${file1}"
          file_OK=1
          break
        fi
      done
    fi

    if [ ${file_OK} -le 0 ]; then
      procError "the ROMS bathymetry file for domain: `echo ${domstr} | sed 's/_//g'`" \
                "is either missing" \
                "checked for files(s): ${my_FEXPR}" \
                "     checked in dirs: ${my_DIRS}"
    fi

    fileGRD="${my_FILE}"
    my_fileGRD="${my_fileGRD} ${fileGRD}"
    my_fileGRDLNK="${my_fileGRDLNK} ${fileGRDLNK}"
  done

  my_fileGRD="$(strTrim "${my_fileGRD}" 2)"
  my_fileGRDLNK="$(strTrim "${my_fileGRDLNK}" 2)"
  unset domstr ido foundFilePath
  # ---------- END:: Bathymetry files


  # ---------- BEG:: Initialization/restart files
  #
  # We need to have "init" files for all ROMS domains
  for ((ido = 0; ido < ${nDOMS}; ido++))
  do
    domstr="_d`get2DString $((ido + 1))`"
    my_FEXPR=
    my_FILE=
    file_OK=0

    # check for initial/restart files in "my_DIRS"
    if [ ${FORCE_INI} -gt 0 ]; then
      my_FPFX="romsinit${domstr}"
        my_FEXPR="${my_FPFX}$( getDateExpr YMDH ${firstYR} ${firstMO} ${firstDA} ${firstHR} )"
        my_FEXPR="${romsPFX:+${romsPFX}_}${my_FEXPR}${romsSFX:+_${romsSFX}}(\.n.*)?"
      my_FEXPR="${my_FEXPR} ${my_FPFX}(\.n.*)?"
      my_DIRS="${my_data_dir} ${my_data_dir}/ini"
      fileINILNK="ocn_init${domstr}.nc"
    else
      my_FPFX="ocn_rst${domstr}"
      my_FEXPR="${my_FEXPR}_${beg_date}(\.n.*)?"
      my_DIRS="${out_dir}"
      fileINILNK="ocn_init${domstr}.nc"
    fi

    searchFILE "${my_FEXPR}" "${my_DIRS}"
    if [ $? -eq 0 ]; then
      for file1 in ${foundFilePath}
      do
        chk_date="$( echo $( ncdf_getTimeStamp "${file1}" ) | awk '{print $1}' )"
        chk_jul="$( echo "${chk_date}" | sed 's/_/ /g' )"
        chk_jul="$( getDate --date="${chk_jul}" --fmt='+%s' )"
        if [ ${chk_jul} -eq ${beg_jul} ]; then
          my_FILE="${file1}"
          file_OK=1
          break
        fi
      done
    fi
  
    if [ ${file_OK} -le 0 ]; then
      procError "the ROMS initial/restart file for domain: `echo ${domstr} | sed 's/_//g'`" \
                "is either missing or the date in the file is not correct:" \
                "    checked for date: ${beg_date}" \
                "checked for files(s): ${my_FEXPR}" \
                "     checked in dirs: ${my_DIRS}"
    fi

    fileINI="${my_FILE}"
    my_fileINI="${my_fileINI} ${fileINI}"
    my_fileINILNK="${my_fileINILNK} ${fileINILNK}"

    # get the NTIMES variable from the NetCDF ini file(s) (will be used below)
    ntimes[${ido}]=0
    if [ ${FORCE_INI} -le 0 ]; then
      ncdf_getVar ${fileINI} "ntimes"
      xpr1="$( echo "${ncdfVarVal}" | awk '{print $1}' )"
      ntimes[${ido}]=$(String_getInteger "${xpr1}" -1)
      unset ncdfVarVal

      if [ ${ntimes[${ido}]} -le 0 ]; then
        procError "problem with NTIMES variable in:" \
                  "INI_FILE = ${fileINI}"
      fi
    fi

    # create the output file names
    my_fileOUT="${my_fileOUT} ocn_out${domstr}.nc"
  done

  my_fileINI="$(strTrim "${my_fileINI}" 2)"
  my_fileINILNK="$(strTrim "${my_fileINILNK}" 2)"
  my_fileOUT="$(strTrim "${my_fileOUT}" 2)"
  unset domstr ido foundFilePath
  # ---------- END:: Initialization/restart files


  # ---------- BEG:: Boundary conditions files
  #
  # We need to have "boundary" and "climatology" files ONLY for the parent,
  # largest, ROMS grid (domain: d01)
  domstr="_d01"
  my_DIRS="${my_data_dir} ${my_data_dir}/boundary"

  # (A) check for boundary files in "my_DIRS"
  my_FPFX="romsbry${domstr}"
  my_FEXPR=
  my_FILE=
  file_OK=0

  for ixpr in YMDH YMD YM Y
  do
    xpr1="${my_FPFX}$( getDateExpr ${ixpr} ${firstYR} ${firstMO} ${firstDA} ${firstHR} )"
    xpr1="${romsPFX:+${romsPFX}_}${xpr1}${romsSFX:+_${romsSFX}}(\.n.*)?"
    my_FEXPR="${my_FEXPR} ${xpr1}"
  done
  my_FEXPR="${my_FEXPR} ${my_FPFX}(\.n.*)?"

  searchFILE "${my_FEXPR}" "${my_DIRS}"
  if [ $? -eq 0 ]; then
    for file1 in ${foundFilePath}
    do
      chk_date=( $( ncdf_getTimeStamp "${file1}" ) )
        chk_jul1="$( echo "${chk_date[0]}" | sed 's/_/ /g' )"
      chk_jul1="$( getDate --date="${chk_jul1}" --fmt='+%s' )"
        chk_jul2="$( echo "${chk_date[${#chk_date[@]}-1]}" | sed 's/_/ /g' )"
      chk_jul2="$( getDate --date="${chk_jul2}" --fmt='+%s' )"
      if [ ${beg_jul} -ge ${chk_jul1} -a ${beg_jul} -le ${chk_jul2} -a \
           ${end_jul} -ge ${chk_jul1} -a ${end_jul} -le ${chk_jul2} ]; then
        my_FILE="${file1}"
        file_OK=1
        break
      fi
    done
  fi

  if [ ${file_OK} -le 0 ]; then
    procError "the ROMS BCs file for domain: `echo ${domstr} | sed 's/_//g'`" \
              "is either missing or the dates in the file are not correct" \
              "   checked for dates: ${beg_date} and ${end_date}" \
              "                      these dates should be bounded by the available records in the file" \
              "checked for files(s): ${my_FEXPR}" \
              "     checked in dirs: ${my_DIRS}"
  fi

  fileBRY="${my_FILE}"
  fileBRYLNK="ocn_bry${domstr}.nc"
  my_fileBRY="$(strTrim "${my_fileBRY} ${fileBRY}" 2)"
  my_fileBRYLNK="$(strTrim "${my_fileBRYLNK} ${fileBRYLNK}" 2)"

  # (B) check for climatology files in "my_DIRS"
  my_FPFX="romsclim${domstr}"
  my_FEXPR=
  my_FILE=
  file_OK=0

  for ixpr in YMDH YMD YM Y
  do
    xpr1="${my_FPFX}$( getDateExpr ${ixpr} ${firstYR} ${firstMO} ${firstDA} ${firstHR} )"
    xpr1="${romsPFX:+${romsPFX}_}${xpr1}${romsSFX:+_${romsSFX}}(\.n.*)?"
    my_FEXPR="${my_FEXPR} ${xpr1}"
  done
  my_FEXPR="${my_FEXPR} ${my_FPFX}(\.n.*)?"

  searchFILE "${my_FEXPR}" "${my_DIRS}"
  if [ $? -eq 0 ]; then
    for file1 in ${foundFilePath}
    do
      chk_date=( $( ncdf_getTimeStamp "${file1}" ) )
        chk_jul1="$( echo "${chk_date[0]}" | sed 's/_/ /g' )"
      chk_jul1="$( getDate --date="${chk_jul1}" --fmt='+%s' )"
        chk_jul2="$( echo "${chk_date[${#chk_date[@]}-1]}" | sed 's/_/ /g' )"
      chk_jul2="$( getDate --date="${chk_jul2}" --fmt='+%s' )"
      if [ ${beg_jul} -ge ${chk_jul1} -a ${beg_jul} -le ${chk_jul2} -a \
           ${end_jul} -ge ${chk_jul1} -a ${end_jul} -le ${chk_jul2} ]; then
        my_FILE="${file1}"
        file_OK=1
        break
      fi
    done
  fi

  if [ ${file_OK} -le 0 ]; then
    procError "the ROMS CLIM file for domain: `echo ${domstr} | sed 's/_//g'`" \
              "is either missing or the dates in the file are not correct" \
              "   checked for dates: ${beg_date} and ${end_date}" \
              "                      these dates should be bounded by the available records in the file" \
              "checked for files(s): ${my_FEXPR}" \
              "     checked in dirs: ${my_DIRS}"
  fi

  fileCLI="${my_FILE}"
  fileCLILNK="ocn_clim${domstr}.nc"
  my_fileCLI="$(strTrim "${my_fileCLI} ${fileCLI}" 2)"
  my_fileCLILNK="$(strTrim "${my_fileCLILNK} ${fileCLILNK}" 2)"
  unset domstr ido foundFilePath
  # ---------- END:: Boundary conditions files


  # ---------- BEG:: Forcing files (if any are required)
  #
  # We possibly have "forcing" files for all ROMS domains, but
  # these will be supplied by the user in a sequential list of
  # files, which are handled here
  if [ "${my_USE_FRC}" = "yes" ]; then
    # Check if the user supplied the forcing data directories;
    # if not use the DATA_DIR; if DATA_DIR is not defined use the current directory
    if [ -z "${FRC_DIR}" ]; then
      if [ -z "${DATA_DIR}" ]; then
        my_FRC_DIR=". ./forcing"
      else
        for idir in ${DATA_DIR}
        do
          my_FRC_DIR="${my_FRC_DIR} ${idir} ${idir}/forcing"
        done
      fi
    else
      my_FRC_DIR="${FRC_DIR}"
    fi
    # This removes dublicate entries without sorting the output
    my_FRC_DIR="$( echo "${my_FRC_DIR}" | tr " " "\n" | \
                   awk '{if ($1 in a) next; a[$1]=$0; print}' | tr "\n" " ")"


    ##### Check if the user supplied prefixes for the forcing datafiles (mandatory)
    if [ -z "${FRC_PFX}" ]; then
      procError "prefix(es) for the input forcing filenames need to be provided" \
                "this prefix is used to identify the files in the data directory(ies)" \
                "FRC_DIR  = ${FRC_DIR:-UNDEF}" \
                "FRC_PFX  = ${FRC_PFX:-UNDEF}"
    fi
    my_FPFX=( ${FRC_PFX} )


    ##### Check if the user supplied suffixes for the forcing datafiles (optional)
    myTmpVal=( ${FRC_SFX} )
    for ((ipfx=0; ipfx<${#my_FPFX[@]}; ipfx++))
    do
      idx=${ipfx}
      if [ -z "${myTmpVal[${idx}]}" ]; then
        idx=$(( ${ipfx} - 1))
        [ ${idx} -le 0 ] && idx=0
      fi
      my_FSFX[${ipfx}]="${myTmpVal[${idx}]}"
    done
    my_FSFX=( ${my_FSFX[@]:0:${#my_FPFX[@]}} )
    unset idx ipfx myTmpVal


    ##### Generate the list of forcing files
    my_DIRS=
    for idir in ${my_FRC_DIR}
    do
      myTmpVal="${idir} ${idir}${firstYR:+/${firstYR}}"
      myTmpVal="${myTmpVal} ${idir}${firstYR:+/${firstYR}}${firstMO:+/${firstMO}}"
      for idir in ${myTmpVal}
      do
        `checkDIR -rx "${idir}"` && my_DIRS="${my_DIRS} ${idir}"
      done
    done
    # This removes dublicate entries without sorting the output
    my_DIRS="$( echo "${my_DIRS}" | tr " " "\n" | \
                awk '{if ($1 in a) next; a[$1]=$0; print}' | tr "\n" " ")"

    for ((ifl = 0; ifl < ${#my_FPFX[@]}; ifl++))
    do
      my_FEXPR=
      my_FILE=
      file_OK=0
      for ixpr in YMD YJ YM Y
      do
        xpr1="${my_FPFX[${ifl}]}$( getDateExpr ${ixpr} ${firstYR} ${firstMO} ${firstDA} )"
        if [ $? -eq 0 ]; then
          xpr1="${xpr1}(.*)?${my_FSFX[${ifl}]}(\.n.*)?"
          my_FEXPR="${my_FEXPR} ${xpr1}"
        fi
      done
      my_FEXPR="${my_FEXPR} ${my_FPFX[${ifl}]}${my_FSFX[${ifl}]}(\.n.*)?"

      searchFILE "${my_FEXPR}" "${my_DIRS}"
      if [ $? -eq 0 ]; then
        for file1 in ${foundFilePath}
        do
          chk_date=( $( ncdf_getTimeStamp "${file1}" ) )
            chk_jul1="$( echo "${chk_date[0]}" | sed 's/_/ /g' )"
          chk_jul1="$( getDate --date="${chk_jul1}" --fmt='+%s' )"
            chk_jul2="$( echo "${chk_date[${#chk_date[@]}-1]}" | sed 's/_/ /g' )"
          chk_jul2="$( getDate --date="${chk_jul2}" --fmt='+%s' )"
          if [ ${beg_jul} -ge ${chk_jul1} -a ${beg_jul} -le ${chk_jul2} -a \
               ${end_jul} -ge ${chk_jul1} -a ${end_jul} -le ${chk_jul2} ]; then
            my_FILE="${file1}"
            file_OK=1
            break
          fi
        done
      fi

      if [ ${file_OK} -le 0 ]; then
        procError "the ROMS forcing file is either missing or the dates in the file are not correct" \
                  "   checked for dates: ${beg_date} and ${end_date}" \
                  "                      these dates should be bounded by the available records in the file" \
                  "checked for files(s): ${my_FEXPR}" \
                  "     checked in dirs: ${my_DIRS}"
      fi

      fileFRC="${my_FILE}"
      fileFRCLNK="$( basename "${fileFRC}" )"
      my_fileFRC="${my_fileFRC} ${fileFRC}"
      my_fileFRCLNK="${my_fileFRCLNK} ${fileFRCLNK}"
    done

    my_fileFRC="$(strTrim "${my_fileFRC}" 2)"
    my_fileFRCLNK="$(strTrim "${my_fileFRCLNK}" 2)"

    my_NFFILES=( ${my_fileFRCLNK} )
    my_NFFILES="${#my_NFFILES[@]}"
  fi
  # ---------- END:: Forcing files (if any are required)

exit 0
  # ---------- BEG:: Prepare the romsINP file
  # generation frequency of history files (e.g, 6hours * 3600s / 60.0s = 43200 / 60 = 720)
  # his_freq, my_HISval are in seconds and my_NDEFHIS (below) in number of time steps
  my_HISval=( ${his_freq:-86400} )
    my_HISval="$(echo "scale=0; ${my_HISval[0]}" | bc -ql 2>/dev/null)"

  # output restart frequency (e.g, 6hours * 3600s / 60.0s = 43200 / 60 = 720)
  # rst_freq, my_NRSTval are in seconds and my_NRST (below) in number of time steps
  my_NRSTval=( ${rst_freq:-86400} )
    my_NRSTval=" $(echo "scale=0; ${my_NRSTval[0]}" | bc -ql 2>/dev/null)"

  for ((ido = 0; ido < ${nDOMS}; ido++))
  do
    # time steps are in seconds
    my_DTval=600
    [ -n "${my_domDT:+1}" ] && my_DTval="${my_domDT[${ido}]}"
    my_DT="${my_DT} $(echo "scale=0; ${my_DTval}/1" | bc -ql 2>/dev/null).0d0"

    # number of barotropic time steps
    my_NDTFASTval=30
    [ -n "${my_domNDTFAST:+1}" ] && my_NDTFASTval="${my_domNDTFAST[${ido}]}"
    my_NDTFAST="${my_NDTFAST} $(echo "scale=0; ${my_NDTFASTval}/1" | bc -ql 2>/dev/null)"
    
    # create new history file every "my_NDEFHIS" number of time steps
    # (one value per domain)
    my_NDEFHIS="${my_NDEFHIS} $(echo "scale=0; ${my_HISval} / ${my_DTval}" | bc -ql 2>/dev/null)"

    # write "my_NHIS" records of history fields in each history file
    my_HFRMval=86400
    [ -n "${my_domHFRM:+1}" ] && my_HFRMval="${my_domHFRM[${ido}]}"
    my_NHIS="${my_NHIS} $(echo "scale=0; ${my_HFRMval} / ${my_DTval}" | bc -ql 2>/dev/null)"

    # restart flag, 0 = initialization, -1 = use the last restart record
    my_NRRECval="-1"
    [ ${FORCE_INI} -gt 0 ] && my_NRRECval=0
    my_NRREC="${my_NRREC} ${my_NRRECval}"

    # restart frequencies in number of time steps
    my_NRST="${my_NRST} $(echo "scale=0; ${my_HFRMval} / ${my_DTval}" | bc -ql 2>/dev/null)"

    # run total for rdays (NTIMES = (1day * 86400s / my_DT) * rdays)
    # NOTE: division in bc honors the scale argument, thus the ")/1" below
    my_NTIMESval="$(echo "scale=0; (${ntimes[${ido}]} + ( 86400.0 / ${my_DTval} ) * ${rdays})/1" | bc -ql 2>/dev/null)"
    my_NTIMES="${my_NTIMES} ${my_NTIMESval}"
  done

  ##### multiple value fields (up to number of requested nests)
# # Lm
# xpr1="`Make_BlockText ${romsINP} "Lm" "${my_Lm}" 4 2`"
# Put_BlockText ${romsINP} "Lm" "${xpr1}"
# # Mm
# xpr1="`Make_BlockText ${romsINP} "Mm" "${my_Mm}" 4 2`"
# Put_BlockText ${romsINP} "Mm" "${xpr1}"
# # N
# if [ -n "${my_N:+1}" ]; then
#   xpr1="`Make_BlockText ${romsINP} "N" "${my_N}" 4 2`"
#   Put_BlockText ${romsINP} "N" "${xpr1}"
# fi
# # theta_s
# if [ -n "${my_theta_s:+1}" ]; then
#   xpr1="`Make_BlockText ${romsINP} "theta_s" "${my_theta_s}" 4 2`"
#   Put_BlockText ${romsINP} "theta_s" "${xpr1}"
# fi
# # theta_b
# if [ -n "${my_theta_b:+1}" ]; then
#   xpr1="`Make_BlockText ${romsINP} "theta_b" "${my_theta_b}" 4 2`"
#   Put_BlockText ${romsINP} "theta_b" "${xpr1}"
# fi
# # Tcline
# if [ -n "${my_Tcline:+1}" ]; then
#   xpr1="`Make_BlockText ${romsINP} "Tcline" "${my_Tcline}" 4 2`"
#   Put_BlockText ${romsINP} "Tcline" "${xpr1}"
# fi
# # Vtransform
# if [ -n "${my_Vtransform:+1}" ]; then
#   xpr1="`Make_BlockText ${romsINP} "Vtransform" "${my_Vtransform}" 4 2`"
#   Put_BlockText ${romsINP} "Vtransform" "${xpr1}"
# fi
# # Vstretching
# if [ -n "${my_Vstretching:+1}" ]; then
#   xpr1="`Make_BlockText ${romsINP} "Vstretching" "${my_Vstretching}" 4 2`"
#   Put_BlockText ${romsINP} "Vstretching" "${xpr1}"
# fi

# # NTIMES
  xpr1="`Make_BlockText ${romsINP} "NTIMES" "${my_NTIMES}" 4 2`"
  Put_BlockText ${romsINP} "NTIMES" "${xpr1}"
  # DT
  xpr1="`Make_BlockText ${romsINP} "DT" "${my_DT}" 4 2`"
  Put_BlockText ${romsINP} "DT" "${xpr1}"
  # NDTFAST
  xpr1="`Make_BlockText ${romsINP} "NDTFAST" "${my_NDTFAST}" 4 2`"
  Put_BlockText ${romsINP} "NDTFAST" "${xpr1}"
  # NRREC
  xpr1="`Make_BlockText ${romsINP} "NRREC" "${my_NRREC}" 4 2`"
  Put_BlockText ${romsINP} "NRREC" "${xpr1}"
  # NRST
  xpr1="`Make_BlockText ${romsINP} "NRST" "${my_NRST}" 4 2`"
  Put_BlockText ${romsINP} "NRST" "${xpr1}"
  # NDEFHIS
  xpr1="`Make_BlockText ${romsINP} "NDEFHIS" "${my_NDEFHIS}" 4 2`"
  Put_BlockText ${romsINP} "NDEFHIS" "${xpr1}"
  # NHIS
  xpr1="`Make_BlockText ${romsINP} "NHIS" "${my_NHIS}" 4 2`"
  Put_BlockText ${romsINP} "NHIS" "${xpr1}"
  # NDEFAVG
  xpr1="`Make_BlockText ${romsINP} "NDEFAVG" "${my_NDEFHIS}" 4 2`"
  Put_BlockText ${romsINP} "NDEFAVG" "${xpr1}"
  # NAVG
  xpr1="`Make_BlockText ${romsINP} "NAVG" "${my_NHIS}" 4 2`"
  Put_BlockText ${romsINP} "NAVG" "${xpr1}"
  # NDEFDIA
  xpr1="`Make_BlockText ${romsINP} "NDEFDIA" "${my_NDEFHIS}" 4 2`"
  Put_BlockText ${romsINP} "NDEFDIA" "${xpr1}"
  # NDIA
  xpr1="`Make_BlockText ${romsINP} "NDIA" "${my_NHIS}" 4 2`"
  Put_BlockText ${romsINP} "NDIA" "${xpr1}"
  # NDEFTLM
  xpr1="`Make_BlockText ${romsINP} "NDEFTLM" "${my_NDEFHIS}" 4 2`"
  Put_BlockText ${romsINP} "NDEFTLM" "${xpr1}"
  # NTLM
  xpr1="`Make_BlockText ${romsINP} "NTLM" "${my_NHIS}" 4 2`"
  Put_BlockText ${romsINP} "NTLM" "${xpr1}"
  # NDEFADJ
  xpr1="`Make_BlockText ${romsINP} "NDEFADJ" "${my_NDEFHIS}" 4 2`"
  Put_BlockText ${romsINP} "NDEFADJ" "${xpr1}"
  # NADJ
  xpr1="`Make_BlockText ${romsINP} "NADJ" "${my_NHIS}" 4 2`"
  Put_BlockText ${romsINP} "NADJ" "${xpr1}"

  # ---------- Input files
  # GRDNAME
  xpr1="`Make_BlockText ${romsINP} "GRDNAME" "${my_fileGRDLNK}" 1 2`"
  Put_BlockText ${romsINP} "GRDNAME" "${xpr1}"
  # ININAME
  xpr1="`Make_BlockText ${romsINP} "ININAME" "${my_fileINILNK}" 1 2`"
  Put_BlockText ${romsINP} "ININAME" "${xpr1}"
  # BRYNAME
  xpr1="`Make_BlockText ${romsINP} "BRYNAME" "${my_fileBRYLNK}" 1 2`"
  Put_BlockText ${romsINP} "BRYNAME" "${xpr1}"
  # CLMNAME
  xpr1="`Make_BlockText ${romsINP} "CLMNAME" "${my_fileCLILNK}" 1 2`"
  Put_BlockText ${romsINP} "CLMNAME" "${xpr1}"

  # ---------- Forcing files
  if [ "${my_USE_FRC}" = "yes" ]; then
    # NFFILES
    xpr1="`Make_BlockText ${romsINP} "NFFILES" "${my_NFFILES}" 4 2`"
    Put_BlockText ${romsINP} "NFFILES" "${xpr1}"
    # FRCNAME
    xpr1="`Make_BlockText ${romsINP} "FRCNAME" "${my_fileFRCLNK}" 1 2`"
    Put_BlockText ${romsINP} "FRCNAME" "${xpr1}"
  fi

  # ---------- Output files
  # GSTNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_gst/g'`"
  xpr1="`Make_BlockText ${romsINP} "GSTNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "GSTNAME" "${xpr1}"
  # RSTNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_rst/g'`"
  xpr1="`Make_BlockText ${romsINP} "RSTNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "RSTNAME" "${xpr1}"
  # HISNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_his/g'`"
  xpr1="`Make_BlockText ${romsINP} "HISNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "HISNAME" "${xpr1}"
  # TLMNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_tlm/g'`"
  xpr1="`Make_BlockText ${romsINP} "TLMNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "TLMNAME" "${xpr1}"
  # TLFNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_tlf/g'`"
  xpr1="`Make_BlockText ${romsINP} "TLFNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "TLFNAME" "${xpr1}"
  # ADJNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_adj/g'`"
  xpr1="`Make_BlockText ${romsINP} "ADJNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "ADJNAME" "${xpr1}"
  # AVGNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_avg/g'`"
  xpr1="`Make_BlockText ${romsINP} "AVGNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "AVGNAME" "${xpr1}"
  # DIANAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_dia/g'`"
  xpr1="`Make_BlockText ${romsINP} "DIANAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "DIANAME" "${xpr1}"
  # STANAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_sta/g'`"
  xpr1="`Make_BlockText ${romsINP} "STANAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "STANAME" "${xpr1}"
  # FLTNAME
  xpr1="`echo "${my_fileOUT}" | sed 's/_out/_flt/g'`"
  xpr1="`Make_BlockText ${romsINP} "FLTNAME" "${xpr1}" 1 2`"
  Put_BlockText ${romsINP} "FLTNAME" "${xpr1}"
  # ---------- END:: Prepare the romsINP file


  # ---------- BEG:: Make the links to the data/input files
  if [ -n "${my_fileGRD:+1}" ]; then
    file1=( ${my_fileGRD} )
    file2=( ${my_fileGRDLNK} )
    nfiles=${#file1[@]}
    for ((ifl = 0; ifl < ${nfiles}; ifl++))
    do
      linkFILE ${file1[${ifl}]} ${file2[${ifl}]}
    done
  fi

  if [ -n "${my_fileINI:+1}" ]; then
    file1=( ${my_fileINI} )
    file2=( ${my_fileINILNK} )
    nfiles=${#file1[@]}
    for ((ifl = 0; ifl < ${nfiles}; ifl++))
    do
      linkFILE ${file1[${ifl}]} ${file2[${ifl}]}
    done
  fi

  if [ -n "${my_fileBRY:+1}" ]; then
    file1=( ${my_fileBRY} )
    file2=( ${my_fileBRYLNK} )
    nfiles=${#file1[@]}
    for ((ifl = 0; ifl < ${nfiles}; ifl++))
    do
      linkFILE ${file1[${ifl}]} ${file2[${ifl}]}
    done
  fi

  if [ -n "${my_fileCLI:+1}" ]; then
    file1=( ${my_fileCLI} )
    file2=( ${my_fileCLILNK} )
    nfiles=${#file1[@]}
    for ((ifl = 0; ifl < ${nfiles}; ifl++))
    do
      linkFILE ${file1[${ifl}]} ${file2[${ifl}]}
    done
  fi

  if [ "${my_USE_FRC}" = "yes" ]; then
    file1=( ${my_fileFRC} )
    file2=( ${my_fileFRCLNK} )
    nfiles=${#file1[@]}
    for ((ifl = 0; ifl < ${nfiles}; ifl++))
    do
      linkFILE ${file1[${ifl}]} ${file2[${ifl}]}
    done
  fi
  # ---------- END:: Make the links to the data/input files

  romsLINKFILES="${my_fileGRDLNK} ${my_fileINILNK} ${my_fileBRYLNK} ${my_fileCLILNK} ${my_fileFRCLNK}"
  export romsLINKFILES
}

USE_FRC=32
DATA_DIR="/nexsan/people/takis/DATA-HYCOM/Data/gom_GLBa0.08/2014"
#FRC_DIR="Data Data/latest / takis /home/takis bobo takis bobo Data"
FRC_PFX="archv."
FRC_SFX=""

firstYR=2014
firstMO=03
firstDA=03
Modify_ROMSFRCConfig
