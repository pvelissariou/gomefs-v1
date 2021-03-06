#include "wrfcpp.h"
      MODULE atm_coupler_mod
#ifdef WRF_COUPLING
!svn $Id$
!==================================================== John C. Warner ===
!  Copyright (c) 2002-2008 The ROMS/TOMS Group      Hernan G. Arango   !
!   Licensed under a MIT/X style license                               !
!   See License_ROMS.txt                                               !
!=======================================================================
!                                                                      !
!  This module is used to communicate and exchange data between WRF    !
!  other coupled model(s) using the Model Coupling Toolkit (MCT).      !
!                                                                      !
!=======================================================================
!
!  Componenet model registry.
!
      USE m_MCTWorld, ONLY : MCTWorld_init => init
      USE m_MCTWorld, ONLY : MCTWorld_clean => clean
!
!  Domain decompositin descriptor datatype and assocoiated methods.
!
      USE m_GlobalSegMap, ONLY : GlobalSegMap
      USE m_GlobalSegMap, ONLY : GlobalSegMap_init => init
      USE m_GlobalSegMap, ONLY : GlobalSegMap_lsize => lsize
      USE m_GlobalSegMap, ONLY : GlobalSegMap_clean => clean
      USE m_GlobalSegMap, ONLY : GlobalSegMap_Ordpnts => OrderedPoints
!
!  Field storage data types and associated methods.
!
      USE m_AttrVect, ONLY : AttrVect
      USE m_AttrVect, ONLY : AttrVect_init => init
      USE m_AttrVect, ONLY : AttrVect_zero => zero
      USE m_AttrVect, ONLY : AttrVect_clean => clean
      USE m_AttrVect, ONLY : AttrVect_indxR => indexRA
      USE m_AttrVect, ONLY : AttrVect_importRAttr => importRAttr
      USE m_AttrVect, ONLY : AttrVect_exportRAttr => exportRAttr
!
!  Intercomponent communitcations scheduler.
!
      USE m_Router, ONLY : Router
      USE m_Router, ONLY : Router_init => init
      USE m_Router, ONLY : Router_clean => clean
!
!  Intercomponent transfer.
!
      USE m_Transfer, ONLY : MCT_Send => send
      USE m_Transfer, ONLY : MCT_Recv => recv
!
      USE mct_wrf_coupler_params
!
      implicit none
!
      PRIVATE

      PUBLIC :: initialize_atm_coupling
      PUBLIC :: atm2ocn_coupling
      PUBLIC :: finalize_atm_coupling

      include 'mpif.h'
!
!  Declarations.
!
      TYPE(GlobalSegMap) :: GSMapWRF          ! GloabalSegMap variables
 
      TYPE(AttrVect) :: atm2ocn_AV            ! AttrVect variables
      TYPE(AttrVect) :: ocn2atm_AV 
      type(Router) :: RoutWRFtoROMS           ! Router variables
# if defined SWAN_COUPLING
      TYPE(AttrVect) :: atm2wav_AV            ! AttrVect variables
      TYPE(AttrVect) :: wav2atm_AV            ! AttrVect variables
      type(Router) :: RoutWRFtoSWAN           ! Router variables
# endif

      CONTAINS

      SUBROUTINE initialize_atm_coupling(grid)
!
!=======================================================================
!                                                                      !
!  Initialize waves and ocean models coupling stream.  This is the     !
!  training phase use to constuct  MCT  parallel interpolators and     !
!  stablish communication patterns.                                    !
!                                                                      !
!=======================================================================
!
      USE module_domain
!     USE module_dm
      USE module_parallel

      implicit none

      TYPE(domain) , INTENT (IN) :: grid 

      include 'mpif.h'
!
!  Local variable declarations.  
!
      integer :: MyError, MyRank
      integer :: npoints, gsmsize, nprocs, localsize
      integer :: j, jc, Isize, Jsize
      integer :: is, ie, js, je, cid, cad

      integer, pointer :: start(:), length(:)
      character (len=120)  :: to_add, avstring

!-----------------------------------------------------------------------
!  Begin initialization phase.
!-----------------------------------------------------------------------
!
!  Get communicator local rank and size.
!
      CALL mpi_comm_rank (ATM_COMM_WORLD, MyRank, MyError)
      CALL mpi_comm_size (ATM_COMM_WORLD, nprocs, MyError)
!
!  Initialize MCT coupled model registry.
!
      CALL MCTWorld_init (N_mctmodels,MPI_COMM_WORLD,                   &
     &                    ATM_COMM_WORLD,ATMid)
!
!  Initialize a Global Segment Map for non-haloed transfer of data out
!  of WRF. Determine non-haloed start and length arrays for this
!  processor.
!
      is = grid%sp31
      ie = grid%ep31
      js = grid%sp33
      je = grid%ep33
      IF (grid%ed31.eq.ie) THEN
        ie=ie-1
      END IF
      IF (grid%ed33.eq.je) THEN
        je=je-1
      END IF
!
!  Determine tile size
!
      Isize=ie-is+1
      Jsize=je-js+1
      allocate( start(Jsize) )
      allocate( length(Jsize) )
      jc=0
      DO j=js,je
        jc=jc+1
        start(jc)=(j-1)*(grid%ed31-1)+is
        length(jc)=Isize
      END DO
      gsmsize=Isize*Jsize
!
      CALL GlobalSegMap_init (GSMapWRF, start, length, 0,               &
     &                        ATM_COMM_WORLD, ATMid)
# ifdef ROMS_COUPLING
!
!  Initialize attribute vector holding the export data code strings of
!  the atmosphere model.
      cad=LEN(avstring)
      DO j=1,cad
        avstring(j:j)=''
      END DO
      cid=1
!
      to_add='GSW'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
      to_add=':GLW'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
#  ifdef ATM2OCN_FLUXES
      to_add=':LH'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
      to_add=':HFX'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
      to_add=':USTRESS'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
      to_add=':VSTRESS'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
!
#  if defined BULK_FLUXES || defined ECOSIM || defined ATM_PRESS
      to_add=':MSLP'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
!
#  if defined BULK_FLUXES || defined ECOSIM || \
   (defined SHORTWAVE && defined ANA_SRFLUX)
      to_add=':RELH'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
      to_add=':T2'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
!
#  if defined BULK_FLUXES || defined ECOSIM
      to_add=':U10'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
!
      to_add=':V10'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
!
#  ifdef CLOUDS
      to_add=':CLDFRA'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
!
#  if !defined ANA_RAIN && defined EMINUSP
      to_add=':RAIN'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
!
#  if defined EMINUSP
      to_add=':EVAP'
      cad=LEN_TRIM(to_add)
      write(avstring(cid:cid+cad-1),'(a)') to_add(1:cad)
      cid=cid+cad
#  endif
      cad=LEN_TRIM(avstring)
      avstring=avstring(1:cad)
!
      CALL AttrVect_init (atm2ocn_AV,rlist=TRIM(avstring),lsize=gsmsize)
      CALL AttrVect_zero (atm2ocn_AV)
!
!  Initialize attribute vector holding the export data code string of
!  the ocean model.
      CALL AttrVect_init (ocn2atm_AV,rList="SST",lsize=gsmsize)
      CALL AttrVect_zero (ocn2atm_AV)
!
!  Initialize a router to the ocean model component.
!
      CALL Router_init (OcnId,GSMapWRF,ATM_COMM_WORLD,RoutWRFtoROMS)

# endif
# ifdef SWAN_COUPLING
!
!  Initialize attribute vector holding the export data code string of
!  the wave model.
!
      CALL AttrVect_init (atm2wav_AV, rlist="U10:V10",lsize=gsmsize)
      CALL AttrVect_zero (atm2wav_AV)
!
!  Initialize attribute vector for data from SWAN.
!
      CALL AttrVect_init (wav2atm_AV, rList="HSIGN:WLENP:RTP",         &
     &                    lsize=gsmsize)
      CALL AttrVect_zero (wav2atm_AV)
!
! Initialize a router to the SWAN component.
!
      CALL Router_init (WavId,GSMapWRF,ATM_COMM_WORLD,RoutWRFtoSWAN)
# endif

      deallocate (start)
      deallocate (length)

      RETURN
      END SUBROUTINE initialize_atm_coupling

      SUBROUTINE atm2ocn_coupling (grid)
!
!=======================================================================
!                                                                      !
!  This subroutine reads and writes the coupled data streams.          !
!  Currently, the following data streams are processed:                !
!                                                                      !
!  Possible fields exported to the OCEAN Model:                        !
!                                                                      !
!     * GSW        Short wave raditaion  (Watts/m2)                    !
!     * GLW        Long wave raditaion  (Watts/m2)                     !
!     * LH         Latent heat flux     (Watts/m2)                     !
!     * HFX        Sensible heat flux   (Watts/m2)                     !
!     * USTRESS    Surface U-wind stress (Pa)                          !
!     * VSTRESS    Surface v-stress      (Pa)                          !
!     * MSLP       Mean Sea Level Pressure (Pa)                        !
!     * RELH       Surface air relative humidity (percent)             !
!     * T2         Surface 2m air temperature (Celsius)                !
!     * U10        U-Wind speed at 10 m (m/s)                          !
!     * V10        V-Wind speed at 10 m (m/s)                          !
!     * CLDFRA     Cloud fraction       (percent/100)                  !
!     * RAIN       Precipitation        (m/s)                          !
!     * EVAP       Evaporation          (m/s)                          !
!                                                                      !
!  Fields exported to the WAVE Model:                                  !
!     * U10        U-Wind speed at 10 m (m/s)                          !
!     * V10        V-Wind speed at 10 m (m/s)                          !
!                                                                      !
!  Fields acquired from the WAVE Model:                                !
!                                                                      !
!     * HISGN      Significant wave heigth (m)                         !
!     * WLENP      Peak wave length (m)                                !
!     * RTP        Peak wave period (s)                                !
!                                                                      !
!  Fields acquired from the OCEAN Model:                               !
!                                                                      !
!     * SST        Sea surface temperature                             !
!=======================================================================
!
      USE module_domain
      USE module_parallel
!
      implicit none
      TYPE(domain) , INTENT (IN) :: grid 
!
!  Local variable declarations.
!
      integer :: is, ie, js, je, ij
      integer :: MyStatus, i, j, Asize, ierr, MyRank
      integer :: MyError, MySize, indx, Istr, Iend, Jstr, Jend
      integer :: Isize, Jsize, INDXG, NPROCS, OFFSET

      integer, dimension(MPI_STATUS_SIZE,4) :: status

      real, parameter :: eps=1.0e-10
      real, pointer :: AA(:)
      real :: cff1, cff2, cff3, rnum, rden, c04, c05
!  Set grid range.
!
      is = grid%sp31
      ie = grid%ep31
      js = grid%sp33
      je = grid%ep33
      IF (grid%ed31.eq.ie) THEN
        ie=ie-1
      END IF
      IF (grid%ed33.eq.je) THEN
        je=je-1
      END IF
!
!-----------------------------------------------------------------------
!  Send atmosphere fields to ROMS.
!-----------------------------------------------------------------------
!
      CALL MPI_COMM_RANK (ATM_COMM_WORLD, MyRank, MyError)
      CALL MPI_COMM_SIZE (ATM_COMM_WORLD, nprocs, MyError)
!
!  Get the number of grid point on this processor.
!
      Asize=GlobalSegMap_lsize(GSMapWRF,ATM_COMM_WORLD)
!
!  Allocate attribute vector array used to export/import data.
!
      allocate ( AA(Asize), stat=ierr )
# ifdef ROMS_COUPLING
!
!-----------------------------------------------------------------------
!  Export fields from atmosphere (WRF) to ocean (ROMS) model.
!-----------------------------------------------------------------------
!     GSW        Short wave raditaion (W m-2).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%GSW(i,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "GSW", AA, Asize)
!-----------------------------------------------------------------------
!     GLW        Long wave raditaion (W m-2).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%GLW(i,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "GLW", AA, Asize)
#  ifdef ATM2OCN_FLUXES
!-----------------------------------------------------------------------
!     LH     Latent heat flux (W m-2).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%LH(i,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "LH", AA, Asize)
!-----------------------------------------------------------------------
!     HFX     Sensible heat flux (W m-2).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%HFX(i,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "HFX", AA, Asize)
!-----------------------------------------------------------------------
!     USTRESS    Surface u-stress (m2 s-2).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          cff1=1.0/(grid%alt(i,1,j)+eps)
          cff2=2.0/(((grid%u_2(i,1,j)+grid%u_2(i+1,1,j))**2+            &
     &               (grid%v_2(i,1,j)+grid%v_2(i,1,j+1))**2)**0.5+eps)
          ij=ij+1
          AA(ij)=cff1*cff2*(grid%UST(i,j)**2)*                          &
     &           0.5*(grid%u_2(i,1,j)+grid%u_2(i+1,1,j))
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "USTRESS", AA, Asize)
!-----------------------------------------------------------------------
!     VSTRESS    Surface v-stress (m2 s-2).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          cff1=1.0/(grid%alt(i,1,j)+eps)
          cff2=2.0/(((grid%u_2(i,1,j)+grid%u_2(i+1,1,j))**2+            &
     &               (grid%v_2(i,1,j)+grid%v_2(i,1,j+1))**2)**0.5+eps)
          ij=ij+1
          AA(ij)=cff1*cff2*(grid%UST(i,j)**2)*                          &
     &           0.5*(grid%v_2(i,1,j)+grid%v_2(i,1,j+1))
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "VSTRESS", AA, Asize)
#  endif
#  if defined BULK_FLUXES || defined ECOSIM || defined ATM_PRESS
!-----------------------------------------------------------------------
!     MSLP       Surface atmospheric pressure (Pa).
!     Use the hypsometric equation to reduce 
!     surface pressure to mean sea level pressure.
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%PSFC(i,j)*                                        &
     &           exp((9.81*grid%ht(i,j))/                               &
     &           (287.0*grid%T2(i,j)*(1.0+0.61*grid%Q2(i,j))))
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "MSLP", AA, Asize)
#  endif
#  if defined BULK_FLUXES || defined ECOSIM || \
     (defined SHORTWAVE && defined ANA_SRFLUX)
!-----------------------------------------------------------------------
!     RELH       Surface air relative humidity (-).
!
      ij=0
      DO j=js,je
        DO i=is,ie
!
!         Calculate 2-m pressure using hypsometric equation. 
!         Assume temp at 2m = temp at 0m.
!
          cff1 = grid%PSFC(i,j) / (exp((9.81*2.0)/(287.0*grid%T2(i,j))))
!
!         Compute specific humidity using the 2-m mixing ratio and 2-m pressure.
!
          rnum = grid%Q2(i,j)*cff1
          rden  = (grid%Q2(i,j)*(1.-0.622)+0.622)
          cff2 = rnum/rden                         ! e is the specific humidity
!
!         Compute saturation specific humidity using Bolton equation 10.
!
          c04 = 17.67*(grid%T2(i,j)-273.15)
          c05 = (grid%T2(i,j)-273.15) + 243.5
          cff3  = 6.112*exp(c04/c05)
!
          ij=ij+1
          AA(ij)=cff2/cff3
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "RELH", AA, Asize)
!-----------------------------------------------------------------------
!     T2         Surface 2m air temperature (Convert to C).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%T2(i,j)-273.15
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "T2", AA, Asize)
#  endif
!-----------------------------------------------------------------------
!     U10        U-Wind speed at 10 m (m s-1).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%U10(i,j)
        END DO
      END DO
#  if defined BULK_FLUXES || defined ECOSIM
      CALL AttrVect_importRAttr (atm2ocn_AV, "U10", AA, Asize)
#  endif
!-----------------------------------------------------------------------
!     V10        V-Wind speed at 10 m (m s-1).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%V10(i,j)
        END DO
      END DO
#  if defined BULK_FLUXES || defined ECOSIM
      CALL AttrVect_importRAttr (atm2ocn_AV, "V10", AA, Asize) 
#  endif
#  ifdef CLOUDS
!-----------------------------------------------------------------------
!     CLDFRA     Cloud fraction (--, 0-1.0).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%CLDFRA(i,1,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "CLDFRA", AA, Asize)
#  endif
#  if !defined ANA_RAIN && defined EMINUSP
!-----------------------------------------------------------------------
!     RAIN       Precipitation (Convert to m s-1).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=0.001*(grid%RAINCV(i,j)+grid%RAINNCV(i,j))/grid%dt
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "RAIN", AA, Asize)
#  endif
#  if defined EMINUSP
!-----------------------------------------------------------------------
!     EVAP      Evaporation (kg/m2 to Convert to m s-1).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
!         AA(ij)=0.001*(grid%SFCEVP(i,j))/grid%dt
          AA(ij)=0.001*(grid%QFX(i,j))
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2ocn_AV, "EVAP", AA, Asize)
#  endif
!-----------------------------------------------------------------------
!  Send fields to ocean model.
!
      CALL MCT_SEND (atm2ocn_AV,RoutWRFtoROMS,MyError)
      IF (MYRANK.EQ.0) THEN
        WRITE (*,*) '== WRF sent atm fields to ROMS'
      ENDIF
      IF (MyError.ne.0) THEN
        WRITE (*,*) 'coupling send fail atm_coupler, error= ', MyError
        CALL finalize_atm_coupling
      END IF
!
!  Schedule receiving fields from ocean model.
!
        CALL MCT_Recv (ocn2atm_AV,RoutWRFtoROMS,MyError)
        IF (MYRANK.EQ.0) THEN
          WRITE (*,*) '== WRF recvd ocean fields'
        END IF
        IF (MyError.ne.0) THEN
          WRITE (*,*) 'coupling fail wrfcplr, MyStatus= ', MyError
          CALL finalize_atm_coupling
        END IF
!
!  SST (Convert to K).
!
      CALL AttrVect_exportRAttr (ocn2atm_AV, "SST", AA, Asize)
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
!         IF (AA(ij).gt.0.10) THEN
          IF (AA(ij).ne.0.0) THEN
              grid%sst(i,j)=(AA(ij)+273.15)*(1-grid%landmask(i,j))+     &
     &                       grid%sst(i,j)*grid%landmask(i,j)
          END IF
        END DO
      END DO
# endif
# if defined SWAN_COUPLING
!-----------------------------------------------------------------------
!  Exchange fields with SWAN.
!-----------------------------------------------------------------------
!
!  Receive fields from wave model.
!
        CALL MCT_Recv (wav2atm_AV,RoutWRFtoSWAN,MyError)
        IF (MYRANK.EQ.0) THEN
          WRITE (*,*) '== WRF recvd wave fields'
        END IF
        IF (MyError.ne.0) THEN
          WRITE (*,*) 'coupl fail wrfcplr, MyStatus= ', MyError
          CALL finalize_atm_coupling
        END IF
!
!  Hwave.
!
      CALL AttrVect_exportRAttr (wav2atm_AV, "HSIGN", AA, Asize)
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          grid%hwave(i,j)=MAX(0.0,AA(ij))*(1-grid%landmask(i,j))
        END DO
      END DO
!
!  Lwave.
!
      CALL AttrVect_exportRAttr (wav2atm_AV, "WLENP", AA, Asize)
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          grid%lwavep(i,j)=AA(ij)*(1-grid%landmask(i,j))
        END DO
      END DO
!
!  Pwave_top.
!
      CALL AttrVect_exportRAttr (wav2atm_AV, "RTP", AA, Asize)
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          grid%pwave(i,j)=MAX(1.0,AA(ij)*(1-grid%landmask(i,j)))
        END DO
      END DO
!
!-----------------------------------------------------------------------
!  Send U10 and V10 to SWAN.
!-----------------------------------------------------------------------
!     U10        U-Wind speed at 10 m (m s-1).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%U10(i,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2wav_AV, "U10", AA, Asize)
!-----------------------------------------------------------------------
!     V10        V-Wind speed at 10 m (m s-1).
!
      ij=0
      DO j=js,je
        DO i=is,ie
          ij=ij+1
          AA(ij)=grid%V10(i,j)
        END DO
      END DO
      CALL AttrVect_importRAttr (atm2wav_AV, "V10", AA, Asize)
!
      CALL MCT_SEND (atm2wav_AV,RoutWRFtoSWAN,MyError)
      IF (MYRANK.EQ.0) THEN
        WRITE (*,*) '== WRF sent atm fields to SWAN'
      ENDIF
      IF (MyError.ne.0) THEN
        WRITE (*,*) 'coupling send fail atm_coupler, error= ', MyError
        CALL finalize_atm_coupling
      END IF
# endif
!
!  Deallocate communication arrays.
!
      deallocate (AA)
      RETURN
      END SUBROUTINE atm2ocn_coupling

      SUBROUTINE finalize_atm_coupling
!
!=======================================================================
!                                                                    ===
!  This routines terminates execution during coupling error.         ===
!                                                                    ===
!=======================================================================
!
      implicit none
!
!  Local variable declarations.
!
      integer :: MyStatus
!
!-----------------------------------------------------------------------
!  Terminate MPI execution environment.
!-----------------------------------------------------------------------
!
      CALL Router_clean (RoutWRFtoROMS)
      CALL AttrVect_clean (atm2ocn_AV)
      CALL AttrVect_clean (ocn2atm_AV)
      CALL GlobalSegMap_clean (GSMapWRF)
      CALL MCTWorld_clean ()

      END SUBROUTINE finalize_atm_coupling
#endif
      END MODULE atm_coupler_mod
