module da_synop

   use module_domain, only : domain

   use da_control, only : obs_qc_pointer,max_ob_levels,missing_r, missing_data, &
      check_max_iv_print, check_max_iv_unit, v_interp_p, v_interp_h, &
      check_max_iv, missing, max_error_uv, max_error_t, rootproc, &
      max_error_p,max_error_q, sfc_assi_options, no_buddies, fails_error_max, &
      fails_buddy_check, check_buddy, check_buddy_print, check_buddy_unit, &
      buddy_weight , max_buddy_uv, max_buddy_t, max_buddy_p, max_buddy_rh, &
      max_stheight_diff,test_dm_exact, anal_type_verify, &
      kts,kte,kms,kme,sfc_assi_options_1,sfc_assi_options_2 , &
      trace_use_dull, synop, max_ext_its,qcstat_conv_unit,ob_vars
    
   use da_define_structures, only : maxmin_type, iv_type, y_type, jo_type, &
      bad_data_type, x_type, number_type, bad_data_type
   use da_interpolation, only : da_to_zk, &
      da_interp_lin_3d,da_interp_lin_3d_adj, &
      da_interp_lin_2d, da_interp_lin_2d_adj
   use da_par_util1, only : da_proc_sum_int
   use da_par_util, only : da_proc_stats_combine, &
      da_deallocate_global_synop, da_to_global_synop
   use da_physics, only : da_sfc_pre, da_transform_xtopsfc, &
      da_transform_xtopsfc_adj
   use da_statistics, only : da_stats_calculate
   use da_tools, only : da_max_error_qc, da_residual, da_obs_sfc_correction, &
                        da_buddy_qc, da_convert_zk
   use da_tracing, only : da_trace_entry, da_trace_exit

   ! The "stats_synop_type" is ONLY used locally in da_synop:

   type residual_synop1_type
      real          :: u                        ! u-wind.
      real          :: v                        ! v-wind.
      real          :: t                        ! temperature
      real          :: p                        ! pressure
      real          :: q                        ! specific humidity
   end type residual_synop1_type

   type maxmin_synop_stats_type
      type (maxmin_type)         :: u, v, t, p, q
   end type maxmin_synop_stats_type

   type stats_synop_type
      type (maxmin_synop_stats_type)  :: maximum, minimum
      type (residual_synop1_type)     :: average, rms_err
   end type stats_synop_type

contains

#include "da_ao_stats_synop.inc"
#include "da_jo_and_grady_synop.inc"
#include "da_jo_synop_uvtq.inc"
#include "da_residual_synop.inc"
#include "da_oi_stats_synop.inc"
#include "da_print_stats_synop.inc"
#include "da_transform_xtoy_synop.inc"
#include "da_transform_xtoy_synop_adj.inc"
#include "da_get_innov_vector_synop.inc"
#include "da_check_max_iv_synop.inc"
#include "da_calculate_grady_synop.inc"
#include "da_check_buddy_synop.inc"

end module da_synop

