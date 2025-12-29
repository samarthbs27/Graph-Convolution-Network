`timescale 1ps/100fs

module Argmax_Block_TB
  #(parameter FEATURE_ROWS = 6,
    parameter WEIGHT_COLS = 3,
    parameter DOT_PROD_WIDTH = 16,
    parameter MAX_ADDRESS_WIDTH = 2,
    parameter FEATURE_WIDTH = $clog2(FEATURE_ROWS),
    parameter HALF_CLOCK_CYCLE = 5
)
();

  // ========================================================================
  // Testbench Signals
  // ========================================================================
  logic clk;
  logic reset;
  logic done_comb;
  logic [DOT_PROD_WIDTH-1:0] adj_fm_wm_row [0:WEIGHT_COLS-1];
  
  logic [FEATURE_WIDTH-1:0] read_row;
  logic done;
  logic [MAX_ADDRESS_WIDTH-1:0] max_addi_answer [0:FEATURE_ROWS-1];

  // ========================================================================
  // Test Data - ADJ_FM_WM Matrix (from Combination Block output)
  // ========================================================================
  logic [DOT_PROD_WIDTH-1:0] adj_fm_wm_matrix [0:FEATURE_ROWS-1][0:WEIGHT_COLS-1];
  
  // Initialize with expected values after combination
  initial begin
    // Node 0: [0, 0, 0] -> max at column 0 (all equal, choose lowest)
    adj_fm_wm_matrix[0][0] = 0;
    adj_fm_wm_matrix[0][1] = 0;
    adj_fm_wm_matrix[0][2] = 0;
    
    // Node 1: [11488, 0, 0] -> max at column 0
    adj_fm_wm_matrix[1][0] = 11488;
    adj_fm_wm_matrix[1][1] = 0;
    adj_fm_wm_matrix[1][2] = 0;
    
    // Node 2: [6684, 0, 0] -> max at column 0
    adj_fm_wm_matrix[2][0] = 6684;
    adj_fm_wm_matrix[2][1] = 0;
    adj_fm_wm_matrix[2][2] = 0;
    
    // Node 3: [7687, 6093, 0] -> max at column 0
    adj_fm_wm_matrix[3][0] = 7687;
    adj_fm_wm_matrix[3][1] = 6093;
    adj_fm_wm_matrix[3][2] = 0;
    
    // Node 4: [7687, 9853, 8976] -> max at column 1
    adj_fm_wm_matrix[4][0] = 7687;
    adj_fm_wm_matrix[4][1] = 9853;
    adj_fm_wm_matrix[4][2] = 8976;
    
    // Node 5: [7687, 16537, 17952] -> max at column 2
    adj_fm_wm_matrix[5][0] = 7687;
    adj_fm_wm_matrix[5][1] = 16537;
    adj_fm_wm_matrix[5][2] = 17952;
  end

  // ========================================================================
  // Golden Reference
  // ========================================================================
  logic [MAX_ADDRESS_WIDTH-1:0] golden_max_indices [0:FEATURE_ROWS-1];
  
  initial begin
    golden_max_indices[0] = 2'b00;  // Node 0: column 0
    golden_max_indices[1] = 2'b00;  // Node 1: column 0
    golden_max_indices[2] = 2'b00;  // Node 2: column 0
    golden_max_indices[3] = 2'b00;  // Node 3: column 0 (7687 > 6093 > 0)
    golden_max_indices[4] = 2'b01;  // Node 4: column 1 (9853 > 8976 > 7687)
    golden_max_indices[5] = 2'b10;  // Node 5: column 2 (17952 > 16537 > 7687)
  end

  // ========================================================================
  // Test Status
  // ========================================================================
  integer error_count = 0;
  integer test_count = 0;

  // ========================================================================
  // Provide ADJ_FM_WM Row Data (mimics Combination Block)
  // ========================================================================
  always_comb begin
    if (read_row < FEATURE_ROWS) begin
      adj_fm_wm_row = adj_fm_wm_matrix[read_row];
    end
    else begin
      adj_fm_wm_row = '{default: '0};
    end
  end

  // ========================================================================
  // Clock Generator
  // ========================================================================
  initial begin
    clk = 0;
    forever #(HALF_CLOCK_CYCLE) clk = ~clk;
  end

  // ========================================================================
  // Timeout Watchdog
  // ========================================================================
  initial begin
    #50000;
    $display("\n========================================");
    $display("ERROR: Simulation timeout!");
    $display("========================================");
    $finish;
  end

  // ========================================================================
  // Test Sequence
  // ========================================================================
  initial begin
    // Initialize
    done_comb = 0;
    reset = 1;
    
    $display("\n========================================");
    $display("Starting Argmax Block Test");
    $display("========================================\n");
    
    // Display input matrix
    display_input_matrix();
    
    // Reset the DUT
    repeat(3) begin
      #(HALF_CLOCK_CYCLE);
      reset = ~reset;
    end
    
    // Signal combination complete
    #(2*HALF_CLOCK_CYCLE);
    done_comb = 1;
    
    // Wait for completion
    wait (done === 1'b1);
    
    $display("\n========================================");
    $display("Argmax Complete!");
    $display("========================================\n");
    
    // Verify results
    #(2*HALF_CLOCK_CYCLE);
    verify_results();
    
    // Print summary
    print_test_summary();
    
    $finish;
  end

  // ========================================================================
  // DUT Instantiation
  // ========================================================================
  Argmax_Block #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .MAX_ADDRESS_WIDTH(MAX_ADDRESS_WIDTH),
    .FEATURE_WIDTH(FEATURE_WIDTH)
  ) dut (
    .clk(clk),
    .reset(reset),
    .done_comb(done_comb),
    .adj_fm_wm_row(adj_fm_wm_row),
    .read_row(read_row),
    .done(done),
    .max_addi_answer(max_addi_answer)
  );

  // ========================================================================
  // Task: Display Input Matrix
  // ========================================================================
  task display_input_matrix();
    integer i;
    $display("Input ADJ_FM_WM Matrix:");
    $display("         Col0      Col1      Col2       Expected Argmax");
    $display("-----------------------------------------------------------");
    for (i = 0; i < FEATURE_ROWS; i++) begin
      $display("Node%0d:  %6d    %6d    %6d       Column %0d", 
               i, 
               adj_fm_wm_matrix[i][0], 
               adj_fm_wm_matrix[i][1], 
               adj_fm_wm_matrix[i][2],
               golden_max_indices[i]);
    end
    $display("");
  endtask

  // ========================================================================
  // Task: Verify Results
  // ========================================================================
  task verify_results();
    integer i;
    logic [MAX_ADDRESS_WIDTH-1:0] dut_value;
    logic [MAX_ADDRESS_WIDTH-1:0] golden_value;
    
    $display("Verifying Results...\n");
    $display("Node  DUT_Output  Golden_Output  Values [C0, C1, C2]              Status");
    $display("--------------------------------------------------------------------------------");
    
    for (i = 0; i < FEATURE_ROWS; i++) begin
      test_count = test_count + 1;
      dut_value = max_addi_answer[i];
      golden_value = golden_max_indices[i];
      
      if (dut_value === golden_value) begin
        $display(" %0d       %0d           %0d          [%0d, %0d, %0d]    PASS", 
                 i, dut_value, golden_value,
                 adj_fm_wm_matrix[i][0], adj_fm_wm_matrix[i][1], adj_fm_wm_matrix[i][2]);
      end
      else begin
        $display(" %0d       %0d           %0d          [%0d, %0d, %0d]    FAIL <<<", 
                 i, dut_value, golden_value,
                 adj_fm_wm_matrix[i][0], adj_fm_wm_matrix[i][1], adj_fm_wm_matrix[i][2]);
        error_count = error_count + 1;
      end
    end
    $display("--------------------------------------------------------------------------------\n");
  endtask

  // ========================================================================
  // Task: Print Test Summary
  // ========================================================================
  task print_test_summary();
    $display("\n========================================");
    $display("TEST SUMMARY");
    $display("========================================");
    $display("Total Tests:  %0d", test_count);
    $display("Passed:       %0d", test_count - error_count);
    $display("Failed:       %0d", error_count);
    $display("========================================");
    
    if (error_count == 0) begin
      $display("STATUS: ALL TESTS PASSED! ✓");
    end
    else begin
      $display("STATUS: TESTS FAILED! ✗");
    end
    $display("========================================\n");
  endtask

  // ========================================================================
  // Monitor: Row Processing (optional debug)
  // ========================================================================
  initial begin
    if ($test$plusargs("DEBUG")) begin
      $display("\n========================================");
      $display("DEBUG MODE: Monitoring row processing");
      $display("========================================\n");
      
      @(posedge done_comb);
      
      forever begin
        @(posedge clk);
        if (!done && read_row < FEATURE_ROWS) begin
          $display("Time %0t: Processing Row %0d: [%0d, %0d, %0d] -> Max at column %0d", 
                   $time, read_row,
                   adj_fm_wm_row[0], adj_fm_wm_row[1], adj_fm_wm_row[2],
                   dut.max_column_index);
        end
        if (done) break;
      end
    end
  end

  // ========================================================================
  // Monitor: FSM States (optional debug)
  // ========================================================================
  initial begin
    if ($test$plusargs("VERBOSE")) begin
      $display("\n========================================");
      $display("VERBOSE MODE: Monitoring FSM states");
      $display("========================================\n");
      
      forever begin
        @(posedge clk);
        $display("Time %0t: State=%s, row_counter=%0d, done=%0d", 
                 $time, dut.current_state.name(), dut.row_counter, done);
        if (done) break;
      end
    end
  end

endmodule