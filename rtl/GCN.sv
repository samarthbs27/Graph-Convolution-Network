module GCN
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
    parameter MAX_ADDRESS_WIDTH = 2,
    parameter NUM_OF_NODES = 6,			 
    parameter COO_NUM_OF_COLS = 6,			
    parameter COO_NUM_OF_ROWS = 2,			
    parameter COO_BW = $clog2(COO_NUM_OF_COLS)	
)
(
  input logic clk,	// Clock
  input logic reset,	// Reset 
  input logic start,
  input logic [WEIGHT_WIDTH-1:0] data_in [0:WEIGHT_ROWS-1], //FM and WM Data
  input logic [COO_BW - 1:0] coo_in [0:1], //row 0 and row 1 of the COO Stream

  output logic [COO_BW - 1:0] coo_address, // The column of the COO Matrix 
  output logic [ADDRESS_WIDTH-1:0] read_address, // The Address to read the FM and WM Data
  output logic enable_read, // Enabling the Read of the FM and WM Data
  output logic done, // Done signal indicating that all the calculations have been completed
  output logic [MAX_ADDRESS_WIDTH - 1:0] max_addi_answer [0:FEATURE_ROWS - 1] // The answer to the argmax and matrix multiplication 
); 

  // ========================================================================
  // Internal Signals - Inter-block connections
  // ========================================================================
  
  // Convert unpacked coo_in from testbench to packed for internal use
  logic [2*COO_BW-1:0] coo_in_packed;
  assign coo_in_packed = {coo_in[0], coo_in[1]};  // Pack: {row0, row1}
  
  // Transformation Block outputs
  logic done_trans;
  logic [DOT_PROD_WIDTH-1:0] fm_wm_row_out [0:WEIGHT_COLS-1];
  
  // Combination Block outputs
  logic done_comb;
  logic [DOT_PROD_WIDTH-1:0] adj_fm_wm_row [0:WEIGHT_COLS-1];
  logic [COUNTER_FEATURE_WIDTH-1:0] read_fm_wm_row;  // From Combination to Transformation
  
  // Argmax Block outputs
  logic [COUNTER_FEATURE_WIDTH-1:0] read_adj_row;  // From Argmax to Combination

  // ========================================================================
  // Module Instantiations
  // ========================================================================

  // ------------------------------------------------------------------------
  // TRANSFORMATION BLOCK
  // Computes: FM_WM = Feature Matrix (6×96) × Weight Matrix (96×3)
  // ------------------------------------------------------------------------
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
  ) transformation_block_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .data_in(data_in),
    .read_row(read_fm_wm_row),          // From Combination Block
    
    .read_address(read_address),        // To testbench
    .enable_read(enable_read),          // To testbench
    .done_trans(done_trans),            // To Combination Block
    .fm_wm_row_out(fm_wm_row_out)       // To Combination Block
  );

  // ------------------------------------------------------------------------
  // COMBINATION BLOCK
  // Computes: ADJ_FM_WM = Adjacency (COO format) × FM_WM
  // ------------------------------------------------------------------------
  Combination_Block #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .COO_NUM_OF_COLS(COO_NUM_OF_COLS),
    .COO_BW(COO_BW),
    .FEATURE_WIDTH(COUNTER_FEATURE_WIDTH),
    .COO_ADDRESS_WIDTH($clog2(COO_NUM_OF_COLS)),
    .UNDIRECTED(1)                      // Use undirected graph (A + A^T)
  ) combination_block_inst (
    .clk(clk),
    .reset(reset),
    .done_trans(done_trans),            // From Transformation Block
    .coo_in(coo_in_packed),             // Packed COO data (converted internally)
    .fm_wm_row_data(fm_wm_row_out),     // From Transformation Block
    .read_row(read_adj_row),            // From Argmax Block
    
    .coo_address(coo_address),          // To testbench
    .read_fm_wm_row(read_fm_wm_row),    // To Transformation Block
    .done_comb(done_comb),              // To Argmax Block
    .adj_fm_wm_row(adj_fm_wm_row)       // To Argmax Block
  );

  // ------------------------------------------------------------------------
  // ARGMAX BLOCK
  // Computes: For each node, find which column has maximum value
  // ------------------------------------------------------------------------
  Argmax_Block #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .MAX_ADDRESS_WIDTH(MAX_ADDRESS_WIDTH),
    .FEATURE_WIDTH(COUNTER_FEATURE_WIDTH)
  ) argmax_block_inst (
    .clk(clk),
    .reset(reset),
    .done_comb(done_comb),              // From Combination Block
    .adj_fm_wm_row(adj_fm_wm_row),      // From Combination Block
    
    .read_row(read_adj_row),            // To Combination Block
    .done(done),                        // To testbench
    .max_addi_answer(max_addi_answer)   // To testbench (final output!)
  );

endmodule
