# SDC constraints for GCN accelerator
# ASAP7 predictive 7nm PDK, RVT cells, TT/0.7V/25C
#
# This is the human-editable constraints template.
# DC's write_sdc generates a verbose version (GCN.<period>.syn.sdc)
# with per-port driving cells and loads — that file feeds Innovus.
# Edit clock_period_ps here to sweep different timing targets.

set clock_period_ps 1400

create_clock -name clk -period $clock_period_ps [get_ports clk]

set_clock_uncertainty   0.01 [get_clocks clk]
set_clock_transition    0.1  [get_clocks clk]

set_max_fanout 16 [current_design]

set_driving_cell -lib_cell INVx3_ASAP7_75t_R [all_inputs]

set_input_delay  0.100 [all_inputs]  -clock clk
remove_input_delay -clock clk [get_ports clk]
set_output_delay 0.100 [all_outputs] -clock clk

set_load 0.010 [all_outputs]

set_wire_load_mode "segmented"

# IO hold analysis is a system-level concern for an IP block.
# Exempt input and output ports from hold checks; reg2reg hold is fully constrained.
set_false_path -hold -from [remove_from_collection [all_inputs] [get_port clk]]
set_false_path -hold -to [all_outputs]
