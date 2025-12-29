`timescale 1ps/100fs

module Transformation_Block_TB
  #(parameter FEATURE_COLS = 96,
    parameter WEIGHT_ROWS = 96,
    parameter FEATURE_ROWS = 6,
    parameter WEIGHT_COLS = 3,
    parameter FEATURE_WIDTH = 5,
    parameter WEIGHT_WIDTH = 5,
    parameter DOT_PROD_WIDTH = 16,
    parameter ADDRESS_WIDTH = 13,
    parameter COUNTER_WEIGHT_WIDTH = $clog2(WEIGHT_COLS),
    parameter COUNTER_FEATURE_WIDTH = $clog2(FEATURE_ROWS),
    parameter HALF_CLOCK_CYCLE = 5
)
();

  // ========================================================================
  // File paths for test data
  // ========================================================================
  string feature_filename = "./Data/feature_data.txt";
  string weight_filename = "./Data/weight_data.txt";

  // ========================================================================
  // Testbench Signals
  // ========================================================================
  logic clk;
  logic reset;
  logic start;
  logic [WEIGHT_WIDTH-1:0] data_in [0:WEIGHT_ROWS-1];
  logic [COUNTER_FEATURE_WIDTH-1:0] read_row;
  
  logic [ADDRESS_WIDTH-1:0] read_address;
  logic enable_read;
  logic done_trans;
  logic [DOT_PROD_WIDTH-1:0] fm_wm_row_out [0:WEIGHT_COLS-1];

  // ========================================================================
  // Memory Arrays (loaded from files)
  // ========================================================================
  logic [FEATURE_WIDTH-1:0] feature_matrix_mem [0:FEATURE_ROWS-1][0:FEATURE_COLS-1];
  logic [WEIGHT_WIDTH-1:0] weight_matrix_mem [0:WEIGHT_COLS-1][0:WEIGHT_ROWS-1];
  
  // ========================================================================
  // Golden Reference (Software Computed)
  // ========================================================================
  logic [DOT_PROD_WIDTH-1:0] golden_result [0:FEATURE_ROWS-1][0:WEIGHT_COLS-1];
  
  // ========================================================================
  // Test Status
  // ========================================================================
  integer error_count = 0;
  integer test_count = 0;

  // ========================================================================
  // Load Memory from Files
  // ========================================================================
  initial begin
    $readmemb(feature_filename, feature_matrix_mem);
    $readmemb(weight_filename, weight_matrix_mem);
    $display("========================================");
    $display("Loaded test data from files");
    $display("========================================");
  end

  // ========================================================================
  // Compute Golden Reference (Software Model)
  // ========================================================================
  initial begin
    #1; // Wait for memory to load
    compute_golden_reference();
    $display("========================================");
    $display("Computed golden reference values");
    $display("========================================");
    display_golden_matrix();
  end

  // ========================================================================
  // Memory Model (mimics testbench memory behavior)
  // ========================================================================
  always @(read_address or enable_read) begin
    if (enable_read) begin
      if (read_address >= 13'h200) begin
        // Feature matrix access (0x200 - 0x2FF)
        data_in = feature_matrix_mem[read_address - 13'h200];
      end
      else begin
        // Weight matrix access (0x000 - 0x0FF)
        data_in = weight_matrix_mem[read_address];
      end
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
    #100000;
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
    start = 0;
    reset = 1;
    read_row = 0;
    
    $display("\n========================================");
    $display("Starting Transformation Block Test");
    $display("========================================\n");
    
    // Reset the DUT
    repeat(3) begin
      #(HALF_CLOCK_CYCLE);
      reset = ~reset;
    end
    
    // Start transformation
    #(HALF_CLOCK_CYCLE);
    start = 1;
    #(HALF_CLOCK_CYCLE);
    start = 0;
    
    // Wait for completion
    wait (done_trans === 1'b1);
    
    $display("\n========================================");
    $display("Transformation Complete!");
    $display("========================================\n");
    
    // Verify all results
    #(2*HALF_CLOCK_CYCLE);
    verify_all_results();
    
    // Print summary
    print_test_summary();
    
    $finish;
  end

  // ========================================================================
  // DUT Instantiation
  // ========================================================================
  Transformation_Block #(
    .FEATURE_COLS(FEATURE_COLS),
    .WEIGHT_ROWS(WEIGHT_ROWS),
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .FEATURE_WIDTH(FEATURE_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .COUNTER_WEIGHT_WIDTH(COUNTER_WEIGHT_WIDTH),
    .COUNTER_FEATURE_WIDTH(COUNTER_FEATURE_WIDTH)
  ) dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .data_in(data_in),
    .read_row(read_row),
    .read_address(read_address),
    .enable_read(enable_read),
    .done_trans(done_trans),
    .fm_wm_row_out(fm_wm_row_out)
  );

  // ========================================================================
  // Task: Compute Golden Reference
  // ========================================================================
  task compute_golden_reference();
    integer f, w, i;
    logic [DOT_PROD_WIDTH-1:0] sum;
    logic [9:0] product;
    
    for (f = 0; f < FEATURE_ROWS; f++) begin
      for (w = 0; w < WEIGHT_COLS; w++) begin
        sum = 0;
        for (i = 0; i < FEATURE_COLS; i++) begin
          product = feature_matrix_mem[f][i] * weight_matrix_mem[w][i];
          sum = sum + product;
        end
        golden_result[f][w] = sum;
      end
    end
  endtask

  // ========================================================================
  // Task: Display Golden Matrix
  // ========================================================================
  task display_golden_matrix();
    integer f, w;
    $display("Golden Result Matrix (Feature x Weight):");
    $display("         Col0      Col1      Col2");
    $display("------------------------------------");
    for (f = 0; f < FEATURE_ROWS; f++) begin
      $write("Row%0d:  ", f);
      for (w = 0; w < WEIGHT_COLS; w++) begin
        $write("%6d    ", golden_result[f][w]);
      end
      $write("\n");
    end
    $display("");
  endtask

  // ========================================================================
  // Task: Verify All Results
  // ========================================================================
  task verify_all_results();
    integer f, w;
    logic [DOT_PROD_WIDTH-1:0] dut_value;
    logic [DOT_PROD_WIDTH-1:0] golden_value;
    
    $display("Verifying Results...\n");
    $display("Row  Col  DUT_Value  Golden_Value  Status");
    $display("---------------------------------------------");
    
    for (f = 0; f < FEATURE_ROWS; f++) begin
      // Set read_row to read from DUT memory
      read_row = f;
      #1; // Allow combinational read to settle
      
      for (w = 0; w < WEIGHT_COLS; w++) begin
        test_count = test_count + 1;
        dut_value = fm_wm_row_out[w];
        golden_value = golden_result[f][w];
        
        if (dut_value === golden_value) begin
          $display(" %0d    %0d    %6d      %6d        PASS", 
                   f, w, dut_value, golden_value);
        end
        else begin
          $display(" %0d    %0d    %6d      %6d        FAIL <<<", 
                   f, w, dut_value, golden_value);
          error_count = error_count + 1;
        end
      end
    end
    $display("---------------------------------------------\n");
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
  // Monitor: Display address reads (optional debug)
  // ========================================================================
  initial begin
    if ($test$plusargs("DEBUG")) begin
      $display("\n========================================");
      $display("DEBUG MODE: Monitoring address reads");
      $display("========================================\n");
      
      forever begin
        @(posedge clk);
        if (enable_read) begin
          if (read_address >= 13'h200) begin
            $display("Time %0t: Reading FEATURE[%0d] from address 0x%03h", 
                     $time, read_address - 13'h200, read_address);
          end
          else begin
            $display("Time %0t: Reading WEIGHT[%0d] from address 0x%03h", 
                     $time, read_address, read_address);
          end
        end
      end
    end
  end

  // ========================================================================
  // Monitor: Display state transitions (optional debug)
  // ========================================================================
  initial begin
    if ($test$plusargs("VERBOSE")) begin
      $display("\n========================================");
      $display("VERBOSE MODE: Monitoring completion");
      $display("========================================\n");
      
      @(posedge done_trans);
      $display("Time %0t: Transformation completed!", $time);
    end
  end

endmodule