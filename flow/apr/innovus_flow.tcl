# Cadence Innovus APR flow for GCN accelerator
# ASAP7 predictive 7nm PDK, RVT cells, TT/0.7V/25C nominal corner
#
# Prerequisites:
#   1. Source setup_env_cadence.csh in a separate XTerm first
#   2. Create GCN/flow/user_config.tcl from user_config.tcl.template
#   3. Run DC synthesis to produce GCN.<clk_period>.syn.v and .syn.sdc
#
# Run from your APR work directory on the server:
#   innovus> source innovus_flow.tcl
#
# Or step through interactively — each saveDesign is a recovery point.

# ---- Timing unit ---------------------------------------------------
# ASAP7 Liberty files express delays in picoseconds.
setLibraryUnit -time 1ps

# ---- Load design ---------------------------------------------------
source ./Default.globals
init_design

# Explicitly activate the MMMC analysis views.
set_analysis_view \
  -setup [list default_setup_view] \
  -hold  [list default_hold_view]

# Exempt IO ports from hold analysis.
set_interactive_constraint_modes {common}
set_false_path -hold -from [remove_from_collection [all_inputs] [get_port clk]]
set_false_path -hold -to [all_outputs]
set_interactive_constraint_modes {}

# ---- Run directory ------------------------------------------------
# All outputs for this run go into a single self-contained directory.
# Name encodes the two sweep knobs so runs never overwrite each other.
#   run_1400_u50  → 1.4 ns clock, 50% utilization
#   run_0800_u65  → 0.8 ns clock, 65% utilization
#
# To send results to your local machine after a run:
#   tar -czf run_${clk_period}_u${util_pct}_reports.tar.gz \
#       runs/run_${clk_period}_u${util_pct}/reports/ \
#       runs/run_${clk_period}_u${util_pct}/CTS/clock_trees.rpt \
#       runs/run_${clk_period}_u${util_pct}/CTS/skew_groups.rpt
# (Exclude checkpoints/ and GDS/ from the tar — large files not needed for parsing)

set util_pct [expr {int($util_target * 100)}]
set ar_int   [expr {int($aspect_ratio * 100)}]
set run_dir  "./runs/run_${clk_period}_u${util_pct}_ar${ar_int}_${cong_effort}"

# Netlist-swap runs (netlist_period != clk_period) get a _nl<period> suffix
# so they never overwrite the matching normal run.
if {[info exists netlist_period] && $netlist_period != $clk_period} {
    append run_dir "_nl${netlist_period}"
}

# ---- Create output directories ------------------------------------
file mkdir ${run_dir}/checkpoints
file mkdir ${run_dir}/reports/timing/preCTS
file mkdir ${run_dir}/reports/timing/postRoute
file mkdir ${run_dir}/reports/timing/postRoute_preOpt
file mkdir ${run_dir}/reports/power
file mkdir ${run_dir}/CTS/timing
file mkdir ${run_dir}/GDS

# ---- Floorplan -----------------------------------------------------
floorPlan -site asap7sc7p5t -r $aspect_ratio $util_target \
  $core_margin $core_margin $core_margin $core_margin
saveDesign ${run_dir}/checkpoints/GCN_${clk_period}.floorplan.enc

# ---- Power network -------------------------------------------------
globalNetConnect VDD -type pgpin -pin VDD -inst * -module {}
globalNetConnect VSS -type pgpin -pin VSS -inst * -module {}

# ---- Tap cells -----------------------------------------------------
addWellTap -cell TAPCELL_ASAP7_75t_R \
  -cellInterval 7.6 -inRowOffset 2 -prefix WELLTAP

# ---- Power ring ----------------------------------------------------
addRing -nets {VDD VSS} -around default_power_domain -center 1 \
  -width 1.224 -spacing 0.5 \
  -layer {left M3 right M3 bottom M2 top M2}

# ---- Special route (power straps) ----------------------------------
sroute \
  -connect {blockPin padPin padRing corePin floatingStripe} \
  -nets {VDD VSS} \
  -layerChangeRange {M1 M3} \
  -blockPinTarget {nearestTarget} \
  -padPinPortConnect {allPort oneGeom} \
  -padPinTarget {nearestTarget} \
  -corePinTarget {firstAfterRowEnd} \
  -floatingStripeTarget {blockring padring ring stripe ringpin blockpin followpin} \
  -allowJogging 1 \
  -crossoverViaLayerRange {M1 Pad} \
  -allowLayerChange 1 \
  -blockPin useLef \
  -targetViaLayerRange {M1 Pad}

# ---- Pin assignment ------------------------------------------------
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixedPin 1 -fixOverlap 1 -spreadDirection clockwise \
  -edge 3 -layer 2 -spreadType side \
  -pin {clk reset start}
setPinAssignMode -pinEditInBatch false

getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixedPin 1 -fixOverlap 1 -spreadDirection clockwise \
  -edge 3 -layer 2 -spreadType side \
  -pin {data_in[*]}
setPinAssignMode -pinEditInBatch false

getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixedPin 1 -fixOverlap 1 -spreadDirection clockwise \
  -edge 0 -layer 2 -spreadType side \
  -pin {coo_in[*]}
setPinAssignMode -pinEditInBatch false

getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixedPin 1 -fixOverlap 1 -spreadDirection clockwise \
  -edge 1 -layer 2 -spreadType side \
  -pin {enable_read done coo_address[*] read_address[*] max_addi_answer[*]}
setPinAssignMode -pinEditInBatch false

# ---- Placement -----------------------------------------------------
setPlaceMode -place_global_timing_effort medium
setPlaceMode -place_global_reorder_scan false
setPlaceMode -place_global_cong_effort $cong_effort
place_opt_design
saveDesign ${run_dir}/checkpoints/GCN_${clk_period}.placed.enc

# ---- Pre-CTS optimization ------------------------------------------
optDesign -preCTS
timeDesign -preCTS -expandedViews -outDir ${run_dir}/reports/timing/preCTS/

# ---- Clock Tree Synthesis (CTS) ------------------------------------
setDesignMode -bottomRoutingLayer 1 -topRoutingLayer 10
setNanoRouteMode -route_with_via_in_pin true

set_ccopt_property buffer_cells {BUFx2_ASAP7_75t_R BUFx3_ASAP7_75t_R BUFx4_ASAP7_75t_R BUFx4f_ASAP7_75t_R BUFx5_ASAP7_75t_R BUFx6f_ASAP7_75t_R BUFx8_ASAP7_75t_R BUFx10_ASAP7_75t_R BUFx12_ASAP7_75t_R BUFx12f_ASAP7_75t_R BUFx16f_ASAP7_75t_R BUFx24_ASAP7_75t_R HB1xp67_ASAP7_75t_R HB2xp67_ASAP7_75t_R}
set_ccopt_property inverter_cells {INVxp33_ASAP7_75t_R INVxp67_ASAP7_75t_R INVx1_ASAP7_75t_R INVx2_ASAP7_75t_R INVx3_ASAP7_75t_R INVx4_ASAP7_75t_R INVx5_ASAP7_75t_R INVx6_ASAP7_75t_R INVx8_ASAP7_75t_R INVx11_ASAP7_75t_R INVx13_ASAP7_75t_R}
set_ccopt_property target_max_trans 100ps
set_ccopt_property target_skew 30ps

foreach_in_collection inst [get_db insts -if {.base_cell.name == "DHLx1_ASAP7_75t_R"}] {
    set_db $inst .dont_touch true
}

clock_opt_design -outDir ${run_dir}/CTS/
saveDesign ${run_dir}/checkpoints/GCN_${clk_period}.cts.enc

timeDesign -postCTS -expandedViews       -outDir ${run_dir}/CTS/timing/
report_ccopt_clock_trees -filename ${run_dir}/CTS/clock_trees.rpt
report_ccopt_skew_groups -filename ${run_dir}/CTS/skew_groups.rpt

# ---- Post-CTS optimization -----------------------------------------
optDesign -postCTS -hold
optDesign -postCTS -setup

# ---- Routing -------------------------------------------------------
setNanoRouteMode -route_with_via_in_pin    true
setNanoRouteMode -route_fix_clock_nets     true
setNanoRouteMode -route_detail_fix_antenna true
setNanoRouteMode -route_with_timing_driven true
setNanoRouteMode -route_detail_end_iteration default
setNanoRouteMode -route_with_si_driven     false
routeDesign -globalDetail
saveDesign ${run_dir}/checkpoints/GCN_${clk_period}.routed.enc

# ---- Post-route timing BEFORE optimization -------------------------
setAnalysisMode -analysisType onChipVariation -cppr both
timeDesign -postRoute       -expandedViews -outDir ${run_dir}/reports/timing/postRoute_preOpt/
timeDesign -postRoute -hold -expandedViews -outDir ${run_dir}/reports/timing/postRoute_preOpt/

# ---- Post-route optimization ---------------------------------------
optDesign -postRoute -hold
optDesign -postRoute -setup

# ---- Post-route timing reports -------------------------------------
timeDesign -postRoute       -expandedViews -outDir ${run_dir}/reports/timing/postRoute/
timeDesign -postRoute -hold -expandedViews -outDir ${run_dir}/reports/timing/postRoute/

# ---- Power report --------------------------------------------------
report_power -outfile ${run_dir}/reports/power/power.rpt

# ---- Area and utilization ------------------------------------------
redirect ${run_dir}/reports/area.rpt { report_area }

# ---- Congestion report ---------------------------------------------
redirect ${run_dir}/reports/congestion.rpt { reportCongestion -hotspot -overflow }

# ---- Filler cells --------------------------------------------------
getFillerMode -quiet
addFiller -cell {FILLERxp5_ASAP7_75t_R FILLER_ASAP7_75t_R} -prefix FILLER
saveDesign ${run_dir}/checkpoints/GCN_${clk_period}.filled.enc

# ---- Physical verification ----------------------------------------
redirect ${run_dir}/reports/connectivity.rpt { verifyConnectivity }
redirect ${run_dir}/reports/drc.rpt          { verify_drc }

# ---- Parasitic extraction ------------------------------------------
rcOut -spef ${run_dir}/GDS/GCN_${clk_period}.spef

# ---- Post-route netlists -------------------------------------------
saveNetlist ${run_dir}/GDS/GCN_${clk_period}.apr.v \
  -excludeLeafCell \
  -excludeCellInst {FILLERxp5_ASAP7_75t_R FILLER_ASAP7_75t_R}

saveNetlist ${run_dir}/GDS/GCN_${clk_period}.apr_pg.v \
  -includePowerGround \
  -excludeLeafCell \
  -excludeCellInst {FILLERxp5_ASAP7_75t_R FILLER_ASAP7_75t_R}

# ---- GDS export ----------------------------------------------------
streamOut ${run_dir}/GDS/GCN_${clk_period}.gds \
  -mapFile /apps/share64/rocky8/asap7/asap7-20250127/asap7_pdk_r1p7/cdslib/asap7_TechLib_10/asap7_fromAPR_08b.layermap \
  -libName GCN \
  -units 4000 \
  -mode ALL

# ---- Summary report ------------------------------------------------
summaryReport -outfile ${run_dir}/reports/summary.rpt
saveDesign ${run_dir}/checkpoints/GCN_${clk_period}.final.enc

puts "====================================================="
puts "Run complete: $run_dir"
puts "To transfer reports to local machine:"
puts "  tar -czf run_${clk_period}_u${util_pct}_ar${ar_int}_${cong_effort}_reports.tar.gz \\"
puts "    ${run_dir}/reports/ \\"
puts "    ${run_dir}/CTS/clock_trees.rpt \\"
puts "    ${run_dir}/CTS/skew_groups.rpt"
puts "====================================================="
