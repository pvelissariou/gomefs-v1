;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%% PROJECT RELATED PARAMETERS
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;-------------------------------------------------
; Project setup
@proj_common

dirsep

COMPILE_OPT IDL2

; Initialize the project
; ----- projectROOT (CAST_ROOT)
if (n_elements(CAST_ROOT) ne 0) then begin
  projectROOT = strcompress(CAST_ROOT, /REMOVE_ALL)
  if (projectROOT eq '') then begin
    projectROOT = strcompress(getenv('CAST_ROOT'), /REMOVE_ALL)
  endif
endif else begin
  projectROOT = strcompress(getenv('CAST_ROOT'), /REMOVE_ALL)
endelse

if (projectROOT eq '') then begin
  message, 'IDL proj_setup: the environment variable CAST_ROOT is not set, aborting ...'
endif
; -----

; ----- projectBATH (CAST_BATH)
if (n_elements(CAST_BATH) ne 0) then begin
  projectBATH = strcompress(CAST_BATH, /REMOVE_ALL)
  if (projectBATH eq '') then begin
    projectBATH = strcompress(getenv('CAST_BATH'), /REMOVE_ALL)
  endif
endif else begin
  projectBATH = strcompress(getenv('CAST_BATH'), /REMOVE_ALL)
endelse
projectBATH = (projectBATH ne '') $
                ? projectBATH $
                : FilePath('bath', Root_Dir = projectROOT, SUBDIRECTORY = 'Data')
; -----

; ----- projectPLOTS (CAST_PLOTS)
if (n_elements(CAST_PLOTS) ne 0) then begin
  projectPLOTS = strcompress(CAST_PLOTS, /REMOVE_ALL)
  if (projectPLOTS eq '') then begin
    projectPLOTS = strcompress(getenv('CAST_PLOTS'), /REMOVE_ALL)
  endif
endif else begin
  projectPLOTS = strcompress(getenv('CAST_PLOTS'), /REMOVE_ALL)
endelse
projectPLOTS = (projectPLOTS ne '') $
                ? projectPLOTS $
                : FilePath('plots', Root_Dir = projectROOT)
; -----

; ----- projectOUT (CAST_OUT)
if (n_elements(CAST_OUT) ne 0) then begin
  projectOUT = strcompress(CAST_OUT, /REMOVE_ALL)
  if (projectOUT eq '') then begin
    projectOUT = strcompress(getenv('CAST_OUT'), /REMOVE_ALL)
  endif
endif else begin
  projectOUT = strcompress(getenv('CAST_OUT'), /REMOVE_ALL)
endelse
projectOUT = (projectOUT ne '') $
              ? projectOUT $
              : FilePath('Output', Root_Dir = projectROOT)
; -----

proj_init, root_dir = projectROOT, $
           bath_dir = projectBATH, $
           plot_dir = projectPLOTS, $
           out_dir  = projectOUT
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


MODEL_ID = 'GoM-CRMS'
MODEL_TITLE = 'Forecast'
map_proj   = 'Mercator'
map_coords = [ 18.00, -98.00, 32.00, -76.40 ]


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%% GoM-CRMS GLOBAL VARIABLES
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; ----------
; If Global or Regional HYCOM data are used in all calculations
; like, init/boundary conditions.
; USE_GLOBAL_HYCOM_DATA > 0 implies that global HYCOM data are used.
USE_GLOBAL_HYCOM_DATA = 1
;USE_GLOBAL_HYCOM_DATA = 0

HYCOM_ID = (USE_GLOBAL_HYCOM_DATA gt 0) ? 'GLBHC' : 'REGHC'

; ----------
; This is the average earth radius as defined in HYCOM
; We use this here to define the defaults for all model
; calculations.
;Always use double precision
EARTH_RADIUS = 6371001.0D

; ----------
; Missing data fill method to be used
; fill_meth = 1  : use the boxcar averaging method to fill the missing data
; fill_meth = 2  : use the 5-point laplacian filter smoothing method to fill
;                  the missing data
; fill_meth = 3  :
fill_meth = 1

meth_boxcar  = (fill_meth eq 1) ? 1 : 0
meth_flap    = (fill_meth eq 2) ? 1 : 0

; ----------
; Vertical interpolation method to be used
; vint_meth = 1  : interpolate vertically using a least squares quadratic fit
; vint_meth = 2  : interpolate vertically using a quadratic fit
; vint_meth = 3  : interpolate vertically using cubic splines
; vint_meth <= 0 : interpolate vertically using linear interpolation
vint_meth = 3

use_lsquad = (vint_meth eq 1) ? 1 : 0
use_quad   = (vint_meth eq 2) ? 1 : 0
use_spline = (vint_meth eq 3) ? 1 : 0

; ----------
; Reference date for the model simulations (based on global HYCOM)
; This is the date where all time variables are relative to
; REF_TIME = [YEAR, MONTH, DAYOFMONTH, HROFDAY, MINOFHOUR, SECOFMIN]
;REF_TIME = [2009, 12, 31, 0, 0, 0]
REF_TIME = [1900, 12, 31, 0, 0, 0]
REF_YR = REF_TIME[0]
REF_MO = REF_TIME[1]
REF_DA = REF_TIME[2]
REF_HR = REF_TIME[3]
REF_MN = REF_TIME[4]
REF_SC = REF_TIME[5]

REF_DATE = string(REF_YR, REF_MO, REF_DA, REF_HR, REF_MN, REF_SC, $
                  format = '(i4.4, 2("-", i2.2), " ", 2(i2.2, ":"), i2.2)')
REF_JULDAY = julday(REF_MO, REF_DA, REF_YR, REF_HR, REF_MN, REF_SC)
REF_DAYOFYR = fix(julday(1, 1, REF_YR, 0, 0, 0) - REF_JULDAY) + 1
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%% GoM-CRMS ROMS SPECIFIC CONFIGURATION
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;MOD_RESOL =  500 ; in m (0.005 deg. ~ 500 m)
;MOD_RESOL = 1000 ; in m (0.01 deg. ~ 1000 m)
;MOD_RESOL = 2000 ; in m (0.02 deg. ~ 2000 m)
;MOD_RESOL = 3000 ; in m (0.03 deg. ~ 3000 m)
;MOD_RESOL = 4000 ; in m (0.04 deg. ~ 4000 m)
;MOD_RESOL = 5000 ; in m (0.05 deg. ~ 5000 m)
;MOD_RESOL = 6000 ; in m (0.06 deg. ~ 6000 m)
;MOD_RESOL = 7000 ; in m (0.07 deg. ~ 7000 m)
MOD_RESOL = 8000 ; in m (0.08 deg. ~ 8000 m)

gom_resolution, MOD_RESOL

; ----------
; Sigma coordinate definitions
SLAY = 50

;Vtransform  = 1
;Vstretching = 1
Vtransform  = 2
Vstretching = 4

STHETA =  7.0d
BTHETA =  0.4d
TCLINE =  5.0d

T0 = 20.0d
S0 = 35.0d

; ----------
; ROMS lateral boundary conditions
; <= 0 = off
; > 0 = on
;  WEST: BND_DEF[0]
; SOUTH: BND_DEF[1]
;  EAST: BND_DEF[2]
; NORTH: BND_DEF[3]
BND_DEF = [ 0, 1, 1, 1 ]
;BND_DEF = [ 0, 1, 0, 0 ]

; ----------
; 1 = water point mask value (in ROMS, HYCOM)
; 0 = land point mask value (in ROMS, HYCOM)
m_WET = 1
m_DRY = 0
MASK_LND =     0.0 ; mask for land points/elevations
MASK_WET = 99999.0 ; mask for water (ocean) points/depths
MASK_LAK = 99988.0 ; mask for lake points/depths
MASK_RIV = 99977.0 ; mask for river points/depths
MASK_LAG = 99966.0 ; mask for lagoon points/depths

MASK_MIS = 99999.0 ; value for missing/undetermined water depths
MASK_VAL = 99999.0 ; general mask value
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%% GoM-CRMS: ROMS RELATED PARAMETERS
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; ----------
; For GOM data gathering (this bounding box encloses the GOM domain)
;gom_LON_MIN = -98.0050
;gom_LON_MAX = -76.3950
;gom_LAT_MIN =  18.00
;gom_LAT_MAX =  32.00

;gom_LON0 = -101.00
;gom_LAT0 =   15.0
;gom_LON  = 0.5 * (gom_LON_MIN + gom_LON_MAX)
;gom_LAT  = 0.5 * (gom_LAT_MIN + gom_LAT_MAX)
;gom_map_coords = [ gom_LAT_MIN, gom_LON_MIN, gom_LAT_MAX, gom_LON_MAX ]

; ----------
; For the GOM plots
;gomPLOT_LON_MIN = -98.00
;gomPLOT_LON_MAX = -76.40
;gomPLOT_LAT_MIN =  18.00
;gomPLOT_LAT_MAX =  32.00
;PLOT_map_coords = [ gomPLOT_LAT_MIN, gomPLOT_LON_MIN, gomPLOT_LAT_MAX, gomPLOT_LON_MAX ]

;gom_map_proj = 'Mercator'
;gom_mapStruct = VL_GetMapStruct(gom_map_proj, $
;                                CENTER_LATITUDE     = gom_LAT, $
;                                CENTER_LONGITUDE    = gom_LON, $
;                                TRUE_SCALE_LATITUDE = gom_LAT, $
;                                DATUM               = 'Sphere',   $
;                                SEMIMAJOR_AXIS      = EARTH_RADIUS, $
;                                SEMIMINOR_AXIS      = EARTH_RADIUS)
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%% GoM-CRMS PLOTS CONFIGURATION
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
USE_GSHHS_FILE = 'gshhs_h.b'
; If USE_GSHHS_AREA <= 0 then we don't use it in the calculations,
; instead we use gshhs_area that is output from Get_GomGshhs.
; Area is in km^2
USE_GSHHS_AREA = -1.0
;USE_GSHHS_AREA = 0.5

PLOT_TYPE = 'eps'
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;%%%%%%%%%% HYCOM RELATED PARAMETERS
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; Root directory where the GoM derived Global/Regional HYCOM data are stored
hyc_rootDIR  = rootDIR
hyc_plotsDIR = plotDIR

; Strings that identify the use of Global or Regional HYCOM data
;hyc_glstr  = 'gom_GLBHC'
;hyc_glbath = 'gom_GLBHC-bath_GLBa0.08_09.nc'
hyc_glstr  = 'GLBHC'
hyc_glbath = 'GLBHC-bath_GLBa0.08_09.nc'
hyc_rgstr  = 'gom_REGHC'
hyc_rgbath = 'gom_REGHC-bath_GOMl0.04_71.nc'

case 1 of
  (strcmp(HYCOM_ID, 'GLBHC', /FOLD_CASE) eq 1): $
    begin
      hyc_str  = hyc_glstr
      hyc_bath = hyc_glbath
      hyc_bath = FilePath(hyc_bath, Root_Dir = bathDIR)
    end
  (strcmp(HYCOM_ID, 'REGHC', /FOLD_CASE) eq 1): $
    begin
      hyc_str  = hyc_rgstr
      hyc_bath = hyc_rgbath
      hyc_bath = FilePath(hyc_bath, Root_Dir = bathDIR)
    end
  else: $
    begin
      message, 'invalid HYCOM_ID was supplied, please modify in proj_setup'
    end
endcase

; ----------
; For HYCOM data gathering (sets the HYCOM domain to enclose
; the GoM domain)
;hyc_LON_MIN = -100.00
;hyc_LON_MAX =  -74.00
;hyc_LAT_MIN =   16.00
;hyc_LAT_MAX =   34.00

;hyc_LON0 = -101.00
;hyc_LAT0 =   15.0
;hyc_LON  = 0.5 * (hyc_LON_MIN + hyc_LON_MAX)
;hyc_LAT  = 0.5 * (hyc_LAT_MIN + hyc_LAT_MAX)
;hyc_map_coords = [ hyc_LAT_MIN, hyc_LON_MIN, hyc_LAT_MAX, hyc_LON_MAX ]

; ----------
; For HYCOM plots
;hycPLOT_LON_MIN = -100.00
;hycPLOT_LON_MAX =  -74.00
;hycPLOT_LAT_MIN =   16.00
;hycPLOT_LAT_MAX =   34.00
;hycPLOT_map_coords = [ hycPLOT_LAT_MIN, hycPLOT_LON_MIN, hycPLOT_LAT_MAX, hycPLOT_LON_MAX ]

;hyc_map_proj = 'Mercator'
;hyc_mapStruct = VL_GetMapStruct(hyc_map_proj, $
;                                CENTER_LATITUDE     = hyc_LAT, $
;                                CENTER_LONGITUDE    = hyc_LON, $
;                                TRUE_SCALE_LATITUDE = hyc_LAT, $
;                                DATUM               = 'Sphere',   $
;                                SEMIMAJOR_AXIS      = EARTH_RADIUS, $
;                                SEMIMINOR_AXIS      = EARTH_RADIUS)
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
