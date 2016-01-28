/*
**-----------------------------------------------------------------------------
**  MODELS TO USE
**-----------------------------------------------------------------------------
*/


/* ---------- ROMS MODEL ---------- */
#define ROMS_MODEL
/*#define ROMS_FULL_ANA_FORCING*/

/* ---------- WRF MODEL ---------- */
#define WRF_MODEL
/*#define ATM2OCN_FLUXES*/

/* ---------- WRF MODEL ---------- */
/*#define  SWAN_MODEL*/


#if (defined(ROMS_MODEL) && (defined(WRF_MODEL)  || defined(SWAN_MODEL))) || \
    (defined(WRF_MODEL)  && (defined(ROMS_MODEL) || defined(SWAN_MODEL))) || \
    (defined(SWAN_MODEL) && (defined(ROMS_MODEL) || defined(WRF_MODEL)))
#  define MCT_LIB
#  if defined(ROMS_MODEL) && defined(WRF_MODEL)
#    define MCT_INTERP_OC2AT
#  endif
#  if defined(ROMS_MODEL) && defined(SWAN_MODEL)
#    define MCT_INTERP_OC2WV
#  endif
#  if defined(WRF_MODEL) && defined(SWAN_MODEL)
#    define MCT_INTERP_WV2AT
#  endif
#endif


/*---------- GENERAL ROMS OPTIONS ----------*/
#  define SOLVE3D
#  define SPHERICAL
#  define MASKING
/*#  undef PERFECT_RESTART*/

/*---------- OPTIONS FOR MOMENTUM EQUATIONS ----------*/
#  define UV_ADV
#  define UV_COR
#  define UV_QDRAG
/*#  define UV_VIS2*/
#  define MIX_GEO_UV
/*#  define MIX_S_UV*/
#  define DJ_GRADPS
/*#  define DJ_GRADP*/
/*#  define UV_PSOURCE*/

/*---------- OPTIONS FOR TRACER EQUATIONS ----------*/
#  define TS_MPDATA
#  define TS_DIF2
#  define MIX_ISO_TS
#  define SALINITY
#  define NONLIN_EOS
/*#  define TS_PSOURCE*/

/*---------- MODEL FORCING ----------*/
#define BULK_FLUXES
/*#define LONGWAVE*/       /* ROMS calculates the net long wave radiation */
/*#define ALBEDO*/         /* Use the albedo equation */
#undef  LONGWAVE_OUT   /* Outgoing long wave is not needed */
#define SOLAR_SOURCE   /* Short wave decay with depth */
#define EMINUSP        /* Rain/Evaporation, if ON undefine ANA_SSFLUX */
#undef  ANA_RAIN
#define ANA_SSFLUX
#define ANA_BSFLUX     /* Bottom fluxes */
#define ANA_BTFLUX

/*---------- TURBULENCE CLOSURE ----------*/
#  undef  GLS_MIXING
#  define MY25_MIXING

#  if defined(GLS_MIXING) || defined(MY25_MIXING)
#    define KANTHA_CLAYSON
#    define N2S2_HORAVG
#  endif

/*---------- OPTIONS FOR LATERAL BOUNDARY CONDITIONS ----------*/
#  define RADIATION_2D
#  define ADD_FSOBC
#  define ADD_M2OBC

#  define M2CLIMATOLOGY
#  define M3CLIMATOLOGY
#  define TCLIMATOLOGY 
#  define ZCLIMATOLOGY 

#  define M2CLM_NUDGING
#  define M3CLM_NUDGING
#  define TCLM_NUDGING 
#  define ZCLM_NUDGING 

/* ===== Eastern boundary ===== */
/*#  undef EAST_VOLCONS*/ 
#  define EAST_FSCHAPMAN
#  define EAST_FSNUDGING
#  define EAST_M2FLATHER  
#  define EAST_M2NUDGING
#  define EAST_M3NUDGING
#  define EAST_M3RADIATION
#  define EAST_TNUDGING
#  define EAST_TRADIATION
/*#  undef EAST_KRADIATION*/

/* ===== Western boundary ===== */
/*#  undef WEST_VOLCONS*/
#  define WESTERN_WALL

/* ===== Northern boundary ==== */
/*#  undef NORTH_VOLCONS*/
#  define NORTH_FSCHAPMAN
#  define NORTH_FSNUDGING
#  define NORTH_M2FLATHER
#  define NORTH_M2NUDGING
#  define NORTH_M3NUDGING
#  define NORTH_M3RADIATION
#  define NORTH_TNUDGING
#  define NORTH_TRADIATION
/*#  undef NORTH_KRADIATION*/

/* ===== Southern boundary ==== */
/*#  undef SOUTH_VOLCONS*/
#  define SOUTH_FSCHAPMAN
#  define SOUTH_FSNUDGING
#  define SOUTH_M2FLATHER
#  define SOUTH_M2NUDGING
#  define SOUTH_M3NUDGING
#  define SOUTH_M3RADIATION
#  define SOUTH_TNUDGING
#  define SOUTH_TRADIATION
/*#  undef SOUTH_KRADIATION*/
