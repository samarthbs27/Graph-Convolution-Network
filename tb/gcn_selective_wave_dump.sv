// Selective VCD dumping - only key signals for debugging
module dump_selective;
  initial begin
    $dumpfile("gcn_selective.vcd");
    
    // Dump testbench top-level signals
    $dumpvars(1, GCN_TB);
    
    // Dump DUT top-level signals
    $dumpvars(1, GCN_TB.GCN_DUT);
    
    // Dump Transformation Block key signals
    $dumpvars(0, GCN_TB.GCN_DUT.transformation_block_inst.fsm_inst.current_state);
    $dumpvars(0, GCN_TB.GCN_DUT.transformation_block_inst.done_trans);
    $dumpvars(0, GCN_TB.GCN_DUT.transformation_block_inst.feature_count);
    $dumpvars(0, GCN_TB.GCN_DUT.transformation_block_inst.weight_count);
    
    // Dump Combination Block key signals
    $dumpvars(0, GCN_TB.GCN_DUT.combination_block_inst.fsm_inst.current_state);
    $dumpvars(0, GCN_TB.GCN_DUT.combination_block_inst.done_comb);
    $dumpvars(0, GCN_TB.GCN_DUT.combination_block_inst.coo_address);
    $dumpvars(0, GCN_TB.GCN_DUT.combination_block_inst.src_index);
    $dumpvars(0, GCN_TB.GCN_DUT.combination_block_inst.dst_index);
    
    // Dump Argmax Block key signals
    $dumpvars(0, GCN_TB.GCN_DUT.argmax_block_inst.current_state);
    $dumpvars(0, GCN_TB.GCN_DUT.argmax_block_inst.done);
    $dumpvars(0, GCN_TB.GCN_DUT.argmax_block_inst.row_counter);
    $dumpvars(0, GCN_TB.GCN_DUT.argmax_block_inst.max_addi_answer);
    
    $display("Selective VCD dumping enabled: gcn_selective.vcd");
  end
endmodule
