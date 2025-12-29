`timescale 1ps/100fs

module Combination_Block_TB
  #(parameter FEATURE_ROWS = 6,
    parameter WEIGHT_COLS = 3,
    parameter DOT_PROD_WIDTH = 16,
    parameter FEATURE_WIDTH = $clog2(FEATURE_ROWS),
    parameter COO_NUM_OF_COLS = 6,
    parameter COO_BW = $clog2(COO_NUM_OF_COLS),
    parameter HALF_CLOCK_CYCLE = 5
)
();

  // ========================================================================
  // Testbench Signals
  // ========================================================================
  logic clk;
  logic reset;
  logic done_trans;
  logic [COO_BW-1:0] coo_in [0:1];
  logic [DOT_PROD_WIDTH-1:0] fm_wm_row_data [0:WEIGHT_COLS-1];
  logic [FEATURE_WIDTH-1:0] read_row;
  
  logic [COO_BW-1:0] coo_address;
  logic [FEATURE_WIDTH-1:0] read_fm_wm_row;
  logic done_comb;
  logic [DOT_PROD_WIDTH-1:0] adj_fm_wm_row [0:WEIGHT_COLS-1];

  // ========================================================================
  // Test Data Storage
  // ========================================================================
  
  // FM_WM matrix (from Transformation Block output)
  logic [DOT_PROD_WIDTH-1:0] fm_wm_matrix [0:FEATURE_ROWS-1][0:WEIGHT_COLS-1];
  
  // COO adjacency matrix (edge list) - 1-indexed
  logic [COO_BW-1:0] coo_matrix [0:1][0:COO_NUM_OF_COLS-1];
  
  // Golden reference for ADJ_FM_WM
  logic [DOT_PROD_WIDTH-1:0] golden_adj_fm_wm [0:FEATURE_ROWS-1][0:WEIGHT_COLS-1];

  // Test status
  integer error_count = 0;
  integer test_count = 0;

  // ========================================================================
  // Load Test Data
  // ========================================================================
  initial begin
    $display("\n========================================");
    $display("Loading test data");
    $display("========================================\n");
    
    // Initialize FM_WM matrix (output from Feature × Weight)
    fm_wm_matrix[0][0] = 11488; fm_wm_matrix[0][1] = 0;     fm_wm_matrix[0][2] = 0;
    fm_wm_matrix[1][0] = 6684;  fm_wm_matrix[1][1] = 0;     fm_wm_matrix[1][2] = 0;
    fm_wm_matrix[2][0] = 7687;  fm_wm_matrix[2][1] = 6093;  fm_wm_matrix[2][2] = 0;
    fm_wm_matrix[3][0] = 7687;  fm_wm_matrix[3][1] = 9853;  fm_wm_matrix[3][2] = 8976;
    fm_wm_matrix[4][0] = 0;     fm_wm_matrix[4][1] = 6684;  fm_wm_matrix[4][2] = 8976;
    fm_wm_matrix[5][0] = 0;     fm_wm_matrix[5][1] = 6093;  fm_wm_matrix[5][2] = 6093;
    
    // COO matrix: Row 0 = sources, Row 1 = destinations (1-indexed!)
    // Based on gold expectations and GCN_TB concatenation
    coo_matrix[0][0] = 3'd1; coo_matrix[1][0] = 3'd2;  // Node 0 ? Node 1
    coo_matrix[0][1] = 3'd2; coo_matrix[1][1] = 3'd3;  // Node 1 ? Node 2
    coo_matrix[0][2] = 3'd3; coo_matrix[1][2] = 3'd4;  // Node 2 ? Node 3
    coo_matrix[0][3] = 3'd4; coo_matrix[1][3] = 3'd5;  // Node 3 ? Node 4
    coo_matrix[0][4] = 3'd4; coo_matrix[1][4] = 3'd6;  // Node 3 ? Node 5
    coo_matrix[0][5] = 3'd5; coo_matrix[1][5] = 3'd6;  // Node 4 ? Node 5
    
    // Golden ADJ_FM_WM (expected after aggregation)
    golden_adj_fm_wm[0][0] = 0;     golden_adj_fm_wm[0][1] = 0;     golden_adj_fm_wm[0][2] = 0;
    golden_adj_fm_wm[1][0] = 11488; golden_adj_fm_wm[1][1] = 0;     golden_adj_fm_wm[1][2] = 0;
    golden_adj_fm_wm[2][0] = 6684;  golden_adj_fm_wm[2][1] = 0;     golden_adj_fm_wm[2][2] = 0;
    golden_adj_fm_wm[3][0] = 7687;  golden_adj_fm_wm[3][1] = 6093;  golden_adj_fm_wm[3][2] = 0;
    golden_adj_fm_wm[4][0] = 7687;  golden_adj_fm_wm[4][1] = 9853;  golden_adj_fm_wm[4][2] = 8976;
    golden_adj_fm_wm[5][0] = 7687;  golden_adj_fm_wm[5][1] = 16537; golden_adj_fm_wm[5][2] = 17952;
    
    display_loaded_data();
  end

  // ========================================================================
  // FM_WM Data Provider
  // ========================================================================
  always_comb begin
    if (read_fm_wm_row < FEATURE_ROWS) begin
      fm_wm_row_data = fm_wm_matrix[read_fm_wm_row];
    end
    else begin
      fm_wm_row_data = '{default: '0};
    end
  end

  // ========================================================================
  // COO Data Provider - Mimics GCN_TB concatenation
  // ========================================================================
  always_comb begin
    if (coo_address < COO_NUM_OF_COLS) begin
      // This concatenation matches GCN_TB.sv line 106
      // coo_in = {coo_matrix[0], coo_matrix[1]}
      // Upper bits (coo_in[1]) = coo_matrix[0] = sources
      // Lower bits (coo_in[0]) = coo_matrix[1] = destinations
      coo_in[1] = coo_matrix[1][coo_address];  // Destination
      coo_in[0] = coo_matrix[0][coo_address];  // Source
    end
    else begin
      coo_in[0] = '0;
      coo_in[1] = '0;
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
    $display("\n? ERROR: Simulation timeout!");
    $finish;
  end

  // ========================================================================
  // Test Sequence
  // ========================================================================
  initial begin
    // Initialize
    done_trans = 0;
    reset = 1;
    read_row = 0;
    
    $display("\n========================================");
    $display("Starting Combination Block Test");
    $display("========================================\n");
    
    // Reset
    repeat(3) @(posedge clk);
    reset = 0;
    
    // Signal transformation complete
    repeat(2) @(posedge clk);
    done_trans = 1;
    
    // Wait for combination to complete
    wait (done_comb === 1'b1);
    
    $display("\n========================================");
    $display("Combination Complete!");
    $display("========================================\n");
    
    // Verify results
    repeat(2) @(posedge clk);
    verify_results();
    
    print_test_summary();
    
    $finish;
  end

  // ========================================================================
  // DUT Instantiation
  // ========================================================================
  Combination_Block #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .COO_NUM_OF_COLS(COO_NUM_OF_COLS),
    .COO_BW(COO_BW),
    .FEATURE_WIDTH(FEATURE_WIDTH),
    .COO_ADDRESS_WIDTH(COO_BW)
  ) dut (
    .clk(clk),
    .reset(reset),
    .done_trans(done_trans),
    .coo_in(coo_in),
    .fm_wm_row_data(fm_wm_row_data),
    .read_row(read_row),
    
    .coo_address(coo_address),
    .read_fm_wm_row(read_fm_wm_row),
    .done_comb(done_comb),
    .adj_fm_wm_row(adj_fm_wm_row)
  );

  // ========================================================================
  // Display Functions
  // ========================================================================
  task display_loaded_data();
    integer i;
    
    $display("FM_WM Matrix (Feature × Weight):");
    $display("         Col0      Col1      Col2");
    $display("------------------------------------");
    for (i = 0; i < FEATURE_ROWS; i++) begin
      $display("Row%0d:  %6d    %6d    %6d", 
               i, fm_wm_matrix[i][0], fm_wm_matrix[i][1], fm_wm_matrix[i][2]);
    end
    
    $display("\nCOO Edges (1-indexed):");
    $display("Edge  Source  Dest");
    $display("--------------------");
    for (i = 0; i < COO_NUM_OF_COLS; i++) begin
      $display(" %0d      %0d      %0d", i, coo_matrix[0][i], coo_matrix[1][i]);
    end
    
    $display("\nExpected ADJ_FM_WM (Golden):");
    $display("         Col0      Col1      Col2");
    $display("------------------------------------");
    for (i = 0; i < FEATURE_ROWS; i++) begin
      $display("Row%0d:  %6d    %6d    %6d", 
               i, golden_adj_fm_wm[i][0], golden_adj_fm_wm[i][1], golden_adj_fm_wm[i][2]);
    end
  endtask

  // ========================================================================
  // Verify Results
  // ========================================================================
  task verify_results();
    integer i, j;
    logic [DOT_PROD_WIDTH-1:0] dut_value;
    logic [DOT_PROD_WIDTH-1:0] golden_value;
    
    $display("Verifying Results...\n");
    $display("Row  Col  DUT_Value  Golden_Value  Status");
    $display("---------------------------------------------");
    
    for (i = 0; i < FEATURE_ROWS; i++) begin
      read_row = i;
      @(posedge clk);
      #1;
      
      for (j = 0; j < WEIGHT_COLS; j++) begin
        test_count = test_count + 1;
        dut_value = adj_fm_wm_row[j];
        golden_value = golden_adj_fm_wm[i][j];
        
        if (dut_value === golden_value) begin
          $display(" %0d    %0d    %6d       %6d        PASS", i, j, dut_value, golden_value);
        end
        else begin
          $display(" %0d    %0d    %6d       %6d        FAIL <<<", i, j, dut_value, golden_value);
          error_count = error_count + 1;
        end
      end
    end
    $display("---------------------------------------------");
  endtask

  // ========================================================================
  // Test Summary
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
      $display("STATUS: ALL TESTS PASSED! ?");
    end
    else begin
      $display("STATUS: TESTS FAILED! ?");
    end
    $display("========================================\n");
  endtask

endmodule
