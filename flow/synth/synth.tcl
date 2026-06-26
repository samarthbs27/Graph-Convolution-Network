# Synopsys Design Compiler synthesis script for GCN accelerator
# ASAP7 predictive 7nm PDK, RVT cells, TT/0.7V/25C nominal corner
#
# Run from your synthesis work directory on the ASU server:
#   dc_shell -f synth.tcl | tee syn.log
#
# ---- Load user paths (gitignored — contains your server paths) -----
# Copy GCN/flow/user_config.tcl.template to user_config.tcl and fill in.
set _cfg [file join [file dirname [info script]] ../user_config.tcl]
if {[file exists $_cfg]} {
    source $_cfg
} else {
    error "Missing user_config.tcl — copy user_config.tcl.template and fill in your paths."
}
# --------------------------------------------------------------------
set report_dir "$synth_out_dir/DC_reports"
# clk_period comes from user_config.tcl — change it there, not here.
set top_level   "GCN"

# ---- Library setup -------------------------------------------------
set_host_options -max_cores 8

set search_path [list "/apps/share64/rocky8/asap7/asap7-20250127/asap7sc7p5t_28/db/"]

set link_library "* \
  asap7sc7p5t_22b_AO_RVT_TT_170906.db \
  asap7sc7p5t_22b_INVBUF_RVT_TT_170906.db \
  asap7sc7p5t_22b_OA_RVT_TT_170906.db \
  asap7sc7p5t_22b_SEQ_RVT_TT_170906.db \
  asap7sc7p5t_22b_SIMPLE_RVT_TT_170906.db"

set target_library "\
  asap7sc7p5t_22b_AO_RVT_TT_170906.db \
  asap7sc7p5t_22b_INVBUF_RVT_TT_170906.db \
  asap7sc7p5t_22b_OA_RVT_TT_170906.db \
  asap7sc7p5t_22b_SEQ_RVT_TT_170906.db \
  asap7sc7p5t_22b_SIMPLE_RVT_TT_170906.db"

file mkdir $report_dir

# ---- Read RTL ------------------------------------------------------
# glob picks up all .sv files in rtl_dir automatically.
# analyze order doesn't matter — elaborate resolves the hierarchy after.
analyze -format sverilog [glob $rtl_dir/*.sv]

elaborate   $top_level
list_designs
current_design $top_level

# ---- Timing constraints --------------------------------------------
if {[sizeof_collection [get_ports clk]] > 0} {
  set clk_name "clk"
  set clk_port "clk"
  create_clock -name $clk_name -period $clk_period [get_ports $clk_port]
  set_drive 0 [get_clocks $clk_name]
}

set_clock_uncertainty 0.01 [get_clocks $clk_name]
set_clock_transition  0.1  [get_clocks $clk_name]
set_wire_load_mode "segmented"

set typical_input_delay  0.100
set typical_output_delay 0.100
set typical_wire_load    0.010

set_max_fanout 16 $top_level
set_fix_hold [all_clocks]
set_driving_cell -lib_cell INVx3_ASAP7_75t_R [all_inputs]
set_input_delay  $typical_input_delay  [all_inputs]  -clock $clk_name
remove_input_delay -clock $clk_name [find port $clk_port]
set_output_delay $typical_output_delay [all_outputs] -clock $clk_name
set_load $typical_wire_load [all_outputs]

set_false_path -hold -from [remove_from_collection [all_inputs] [get_port $clk_port]]
set_false_path -hold -to [all_outputs]

# Note: set_dont_touch_network is intentionally omitted.
# Using it caused DC to reimplement async-reset FFs (ASYNC_DFFHx1) as
# clock-gated latches (DHLx1 + NAND2), which produces 0 clock tree sinks
# in Innovus and breaks CTS. Without it, DC maps always_ff correctly to
# ASYNC_DFFHx1_ASAP7_75t_R cells with direct CLK connections.

# ---- Check and synthesize ------------------------------------------
check_design
compile_ultra

# ---- Naming rules for tool exchange (prevents HDL keyword clashes) -
define_name_rules asu_naming_rules \
  -allowed {a-zA-Z0-9_} \
  -max_length 256 \
  -reserved_words [list \
    "always" "and" "assign" "begin" "buf" "bufif0" "bufif1" "case" \
    "casex" "casez" "cmos" "deassign" "default" "defparam" "disable" \
    "edge" "else" "end" "endcase" "endfunction" "endmodule" \
    "endprimitive" "endspecify" "endtable" "endtask" "event" "for" \
    "force" "forever" "fork" "function" "highz0" "highz1" "if" \
    "initial" "inout" "input" "integer" "join" "large" "macromodule" \
    "medium" "module" "nand" "negedge" "nmos" "nor" "not" "notif0" \
    "notif1" "or" "output" "pmos" "posedge" "primitive" "pull0" \
    "pull1" "pulldown" "pullup" "rcmos" "reg" "release" "repeat" \
    "rnmos" "rpmos" "rtran" "rtranif0" "rtranif1" "scalered" "small" \
    "specify" "specparam" "strong0" "strong1" "supply0" "supply1" \
    "table" "task" "time" "tran" "tranif0" "tranif1" "tri" "tri0" \
    "tri1" "triand" "trior" "vectored" "wait" "wand" "weak0" "weak1" \
    "while" "wire" "wor" "xnor" "xor" \
    "abs" "access" "after" "alias" "all" "architecture" "array" \
    "assert" "attribute" "block" "body" "buffer" "bus" "component" \
    "configuration" "constant" "disconnect" "downto" "elsif" "entity" \
    "exit" "file" "generate" "generic" "guarded" "in" "is" "label" \
    "library" "linkage" "loop" "map" "mod" "new" "next" "null" "of" \
    "on" "open" "others" "out" "package" "port" "procedure" "process" \
    "range" "record" "register" "rem" "report" "return" "select" \
    "severity" "signal" "subtype" "then" "to" "transport" "type" \
    "units" "until" "use" "variable" "when" "with"] \
  -case_insensitive \
  -last_restricted  "_" \
  -first_restricted "_" \
  -map {{{"*cell*","U"}, {"*-return","RET"}}} \
  -collapse_name_space \
  -equal_ports_nets \
  -inout_ports_equal_nets

change_names -rules asu_naming_rules -verbose -hierarchy

# ---- Write outputs -------------------------------------------------
file mkdir $synth_out_dir
write_file -hierarchy -format verilog -output "${synth_out_dir}/${top_level}.${clk_period}.syn.v"
write_file -hierarchy -format ddc     -output "${synth_out_dir}/${top_level}.ddc"
write_sdf  -context verilog            "${synth_out_dir}/${top_level}.${clk_period}.syn.sdf"
write_sdc                              "${synth_out_dir}/${top_level}.${clk_period}.syn.sdc"

# ---- Reports -------------------------------------------------------
set maxpaths 100
set rpt "${report_dir}/${top_level}.${clk_period}"

check_design                                                            > ${rpt}.rpt
report_area    -hierarchy -designware                                  >> ${rpt}_area.rpt
report_power   -hier -analysis_effort medium                           >> ${rpt}_power.rpt
report_design                                                          >> ${rpt}.rpt
report_cell                                                            >> ${rpt}.rpt
report_port    -verbose                                                >> ${rpt}.rpt
report_compile_options                                                 >> ${rpt}.rpt
report_constraint -all_violators -verbose                              >> ${rpt}_violators.rpt
report_timing  -path full -delay max -max_paths $maxpaths -nworst 100  > ${rpt}_timing.rpt

quit
