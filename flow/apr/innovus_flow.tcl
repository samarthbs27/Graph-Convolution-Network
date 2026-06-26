# Cadence Innovus APR flow for GCN accelerator
# ASAP7 predictive 7nm PDK, RVT cells, TT/0.7V/25C nominal corner
#
# Prerequisites:
#   1. Source setup_env_cadence.csh in a separate XTerm first
#   2. Create GCN/flow/user_config.tcl from user_config.tcl.template
#   3. Run DC synthesis to produce GCN.1400.syn.v and GCN.1400.syn.sdc
#
# Run from your APR work directory on the server:
#   innovus> source innovus_flow.tcl
#
# Or step through interactively — each saveDesign is a recovery point.

# ---- Timing unit ---------------------------------------------------
# ASAP7 Liberty files express delays in picoseconds.
setLibraryUnit -time 1ps

# ---- Load design ---------------------------------------------------
# Default.globals: sources user_config.tcl (your server paths), then
#   sets init_lef_file (tech + cell LEF), init_verilog (gate netlist),
#   init_mmmc_file (Default.view — timing corners and SDC).
# init_design: reads all of the above into the Innovus database.
source ./Default.globals
init_design

# Explicitly activate the MMMC analysis views.
# Default.view's set_analysis_view runs inside Innovus's MMMC reader and
# does not always persist as the active view for subsequent commands.
# Without this, timeDesign shows 0 paths and set_propagated_clock errors
# with TCLCMD-1048 ("no constraint mode is enabled").
set_analysis_view \
  -setup [list default_setup_view] \
  -hold  [list default_hold_view]

# Exempt IO ports from hold analysis — hold at ports is a system-level concern.
# reg2reg hold is fully constrained and has +0.132 ns slack.
# set_interactive_constraint_modes is required in Innovus MMMC mode to direct
# SDC timing-exception commands to the active constraint mode.
set_interactive_constraint_modes {common}
set_false_path -hold -from [remove_from_collection [all_inputs] [get_port clk]]
set_false_path -hold -to [all_outputs]
set_interactive_constraint_modes {}

# ---- Create output directories ------------------------------------
# Must exist before any report or save command references them.
file mkdir ./checkpoints
file mkdir ./reports/timing/preCTS
file mkdir ./reports/timing/postRoute
file mkdir ./reports/power
file mkdir ./CTS/timing
file mkdir ./GDS

# ---- Floorplan -----------------------------------------------------
# Defines the physical die: core area, utilization, and IO margins.
#
# -site asap7sc7p5t: the standard cell row site from the tech LEF
# -r 1: aspect ratio H/W = 1 (square die)
# 0.5: core utilization — 50% of core area filled with standard cells.
#      Higher (>70%) causes routing congestion. Lower (<40%) wastes area.
#      50% is a safe conservative starting point.
# 5 5 5 5: margins in microns from core boundary to IO boundary
#           (left right bottom top)
floorPlan -site asap7sc7p5t -r 1 0.5 5 5 5 5
saveDesign ./checkpoints/GCN_${clk_period}.floorplan.enc

# ---- Power network -------------------------------------------------
# Before routing power, tell Innovus which global nets are power/ground.
# Every VDD pin of every instance maps to global VDD; same for VSS.
globalNetConnect VDD -type pgpin -pin VDD -inst * -module {}
globalNetConnect VSS -type pgpin -pin VSS -inst * -module {}

# ---- Tap cells -----------------------------------------------------
# ASAP7 (like all bulk CMOS) requires tap cells to prevent latch-up.
# Latch-up: a parasitic thyristor in the substrate latches on and pulls
# excessive current, potentially destroying the chip. Tap cells provide
# local substrate/well contacts that quench this path.
# -cellInterval 7.6: one tap every 7.6um along each cell row
# -inRowOffset 2: first tap at 2um from the start of each row
addWellTap -cell TAPCELL_ASAP7_75t_R \
  -cellInterval 7.6 -inRowOffset 2 -prefix WELLTAP

# ---- Power ring ----------------------------------------------------
# Creates a VDD/VSS ring around the core on M2 (horizontal sides) and
# M3 (vertical sides). This ring is the main power delivery spine —
# everything else connects back to it.
# -width 1.224: ring wire width in microns
# -spacing 0.5: gap between VDD ring and VSS ring
addRing -nets {VDD VSS} -around default_power_domain -center 1 \
  -width 1.224 -spacing 0.5 \
  -layer {left M3 right M3 bottom M2 top M2}

# ---- Special route (power straps) ----------------------------------
# Routes from the power ring down to the VDD/VSS pins of every standard
# cell via follow-pin routes inside each row. Without this, cells have
# no power connection even though the ring exists.
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
# Convention: all inputs on west (edge 3), all outputs on east (edge 1).
# If inputs are too numerous to fit on west alone, overflow control
# signals (clk, reset, start) to north (edge 2) or south (edge 0).
#
# Edge numbering:
#   0 = south, 1 = east, 2 = north, 3 = west
# -layer 2: M2 metal for pin shapes
# -spreadType side: distribute pins evenly along the specified edge

# Control inputs on west
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixedPin 1 -fixOverlap 1 -spreadDirection clockwise \
  -edge 3 -layer 2 -spreadType side \
  -pin {clk reset start}
setPinAssignMode -pinEditInBatch false

# Data inputs on west (below control signals) and overflow to south
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

# All outputs on east
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixedPin 1 -fixOverlap 1 -spreadDirection clockwise \
  -edge 1 -layer 2 -spreadType side \
  -pin {enable_read done coo_address[*] read_address[*] max_addi_answer[*]}
setPinAssignMode -pinEditInBatch false

# ---- Placement -----------------------------------------------------
# place_opt_design: global placement followed by placement optimization.
# At this stage the clock is ideal (zero-skew) — real skew comes after CTS.
# -place_global_timing_effort medium: balanced runtime vs timing QoR
# -place_global_cong_effort low: start low; raise to high if routing fails
setPlaceMode -place_global_timing_effort medium
setPlaceMode -place_global_reorder_scan false
setPlaceMode -place_global_cong_effort low
place_opt_design
saveDesign ./checkpoints/GCN_${clk_period}.placed.enc

# ---- Pre-CTS optimization ------------------------------------------
# Setup optimization pass before clock tree exists.
# Fixes hold/setup violations assuming ideal clock — gives the router
# a better starting point and reduces post-CTS rework.
optDesign -preCTS
timeDesign -preCTS -expandedViews -outDir ./reports/timing/preCTS/

# ---- Clock Tree Synthesis (CTS) ------------------------------------
# Builds the physical clock distribution network: a tree of buffers
# and inverters that delivers clk from source to every flip-flop with
# minimum skew (arrival time difference between flip-flops).
#
# Why specify cells explicitly?
# Innovus selects from this list to size the clock tree. A curated list
# of ASAP7 RVT BUF/INV variants prevents it from picking unsuitable cells.
#
# target_skew 30ps: max allowed clock arrival difference across all FFs.
# target_max_trans 100ps: max allowed clock signal rise/fall time.
# Tighter skew and transition = better hold margin but more clock buffers.
setDesignMode -bottomRoutingLayer 1 -topRoutingLayer 10
setNanoRouteMode -route_with_via_in_pin true

set_ccopt_property buffer_cells {BUFx2_ASAP7_75t_R BUFx3_ASAP7_75t_R BUFx4_ASAP7_75t_R BUFx4f_ASAP7_75t_R BUFx5_ASAP7_75t_R BUFx6f_ASAP7_75t_R BUFx8_ASAP7_75t_R BUFx10_ASAP7_75t_R BUFx12_ASAP7_75t_R BUFx12f_ASAP7_75t_R BUFx16f_ASAP7_75t_R BUFx24_ASAP7_75t_R HB1xp67_ASAP7_75t_R HB2xp67_ASAP7_75t_R}
set_ccopt_property inverter_cells {INVxp33_ASAP7_75t_R INVxp67_ASAP7_75t_R INVx1_ASAP7_75t_R INVx2_ASAP7_75t_R INVx3_ASAP7_75t_R INVx4_ASAP7_75t_R INVx5_ASAP7_75t_R INVx6_ASAP7_75t_R INVx8_ASAP7_75t_R INVx11_ASAP7_75t_R INVx13_ASAP7_75t_R}
set_ccopt_property target_max_trans 100ps
set_ccopt_property target_skew 30ps

# Innovus 23.x IMPCCOPT-1146 fix: exclude the 9 DHLx1 (level-sensitive latch)
# CLK sinks from CTS. These FSM latches are driven through a NAND2 clock gate;
# Innovus 23.x CCOpt rejects NAND2 as an invalid clock tree cell.
# The original course script predates this strict check (ran on older Innovus).
# Do NOT set_propagated_clock before clock_opt_design — that causes CCOpt to trace
# through NAND2 gating paths and triggers IMPCCOPT-1146 on those paths.
foreach_in_collection inst [get_db insts -if {.base_cell.name == "DHLx1_ASAP7_75t_R"}] {
    set_db $inst .dont_touch true
}

clock_opt_design -outDir ./CTS/
saveDesign ./checkpoints/GCN_${clk_period}.cts.enc

# CTS reports — skew and insertion delay are key PPA metrics
timeDesign -postCTS -expandedViews       -outDir ./CTS/timing/
report_ccopt_clock_trees -filename ./CTS/clock_trees.rpt
report_ccopt_skew_groups -filename ./CTS/skew_groups.rpt

# ---- Post-CTS optimization -----------------------------------------
# After CTS, real clock skew is known. Skew shifts flip-flop arrival
# times, which typically creates new hold violations (data arrives
# before the capturing clock edge). Fix hold first, then setup —
# hold fixes add delay buffers which can worsen setup if done after.
optDesign -postCTS -hold
optDesign -postCTS -setup

# ---- Routing -------------------------------------------------------
# Routes all remaining signal nets. CTS already routed the clock nets.
# -route_fix_clock_nets: preserves the CTS result, does not re-route clock
# -route_with_timing_driven: router considers timing slack while routing
# -route_with_si_driven false: skip signal integrity (SI/crosstalk) driven
#   routing for now — adds runtime; enable for final signoff closure
setNanoRouteMode -route_with_via_in_pin    true
setNanoRouteMode -route_fix_clock_nets     true
setNanoRouteMode -route_detail_fix_antenna true
setNanoRouteMode -route_with_timing_driven true
setNanoRouteMode -route_detail_end_iteration default
setNanoRouteMode -route_with_si_driven     false
routeDesign -globalDetail
saveDesign ./checkpoints/GCN_${clk_period}.routed.enc

# ---- Post-route optimization ---------------------------------------
# OCV (On-Chip Variation) mode applies derating factors to account for
# within-die process variation — the same wire/cell can be slightly faster
# or slower at different locations. This is the standard mode for
# post-route timing sign-off.
# Fix hold before setup — hold buffers can introduce setup violations
# if setup is fixed first.
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute -hold
optDesign -postRoute -setup

# ---- Post-route timing reports -------------------------------------
# These are the closure metrics: WNS, TNS, violating path count.
# WNS (Worst Negative Slack) and TNS (Total Negative Slack) are the
# primary numbers for the resume and closure report.
timeDesign -postRoute       -expandedViews -outDir ./reports/timing/postRoute/
timeDesign -postRoute -hold -expandedViews -outDir ./reports/timing/postRoute/

# ---- Power report --------------------------------------------------
# Breaks down power into three components:
#   Internal power: capacitance charging inside cells (dominant)
#   Switching power: toggling on output nets
#   Leakage power: static sub-threshold current (small at 7nm typical)
# Uses default 0.2 toggle rate if no VCD activity file is provided.
report_power -outfile ./reports/power/power.rpt

# ---- Area and utilization ------------------------------------------
redirect ./reports/area.rpt { report_area }

# ---- Congestion report ---------------------------------------------
# Overflow = routing demand exceeds routing supply in a grid cell.
# High overflow = DRC errors from routing. Report before adding fillers
# so the congestion map is not distorted by filler cell obstructions.
redirect ./reports/congestion.rpt { reportCongestion -hotspot -overflow }

# ---- Filler cells --------------------------------------------------
# Fill empty gaps between standard cells. Filler cells have no logic —
# they maintain N-well continuity and meet density rules.
# Must be added LAST, after all optimization, because they block placement
# changes. Exclude them from netlists (hence -excludeCellInst later).
getFillerMode -quiet
addFiller -cell {FILLERxp5_ASAP7_75t_R FILLER_ASAP7_75t_R} -prefix FILLER
saveDesign ./checkpoints/GCN_${clk_period}.filled.enc

# ---- Physical verification ----------------------------------------
# verifyConnectivity: checks all nets are fully connected (no opens/shorts)
# verify_drc: checks layout against PDK design rules (spacing, width, etc.)
redirect ./reports/connectivity.rpt { verifyConnectivity }
redirect ./reports/drc.rpt          { verify_drc }

# ---- Parasitic extraction ------------------------------------------
# SPEF (Standard Parasitic Exchange Format): extracted RC values for
# every net in the routed layout. Used for:
#   1. Post-route STA in Tempus/PrimeTime (more accurate than Innovus internal)
#   2. Power analysis with activity annotation
#   3. Proving signoff-quality extraction was performed
rcOut -spef ./GDS/GCN_${clk_period}.spef

# ---- Post-route netlists -------------------------------------------
# Simulation netlist (no power/ground pins — for VCS/Xcelium simulation)
saveNetlist ./GDS/GCN_${clk_period}.apr.v \
  -excludeLeafCell \
  -excludeCellInst {FILLERxp5_ASAP7_75t_R FILLER_ASAP7_75t_R}

# LVS netlist (with power/ground pins — needed to run LVS against GDS)
saveNetlist ./GDS/GCN_${clk_period}.apr_pg.v \
  -includePowerGround \
  -excludeLeafCell \
  -excludeCellInst {FILLERxp5_ASAP7_75t_R FILLER_ASAP7_75t_R}

# ---- GDS export ----------------------------------------------------
# GDSII is the final layout format sent to a fab (or used for signoff).
# -mapFile: maps Innovus layer names to GDS layer/datatype numbers
# -units 4000: GDS database units per micron for 4x scaled ASAP7
streamOut ./GDS/GCN_${clk_period}.gds \
  -mapFile /apps/share64/rocky8/asap7/asap7-20250127/asap7_pdk_r1p7/cdslib/asap7_TechLib_10/asap7_fromAPR_08b.layermap \
  -libName GCN \
  -units 4000 \
  -mode ALL

# ---- Summary and final save ----------------------------------------
summaryReport -outfile ./reports/summary.rpt
saveDesign ./checkpoints/GCN_${clk_period}.final.enc
