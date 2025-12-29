module Combination_Block
  #(parameter FEATURE_ROWS = 6,
    parameter WEIGHT_COLS = 3,
    parameter DOT_PROD_WIDTH = 16,
    parameter COO_NUM_OF_COLS = 6,
    parameter COO_BW = 3,  // $clog2(COO_NUM_OF_COLS+1) for 1-indexed (1-6)
    parameter FEATURE_WIDTH = $clog2(FEATURE_ROWS),
    parameter COO_ADDRESS_WIDTH = $clog2(COO_NUM_OF_COLS),
    parameter bit UNDIRECTED = 1  // 1 for undirected graph (A + A^T), 0 for directed
)
(
  input  logic clk,
  input  logic reset,
  input  logic done_trans,                                      // From Transformation Block
  input  logic [2*COO_BW-1:0] coo_in,                          // Packed COO data {row0, row1}
  input  logic [DOT_PROD_WIDTH-1:0] fm_wm_row_data [0:WEIGHT_COLS-1],  // From Transform Block
  input  logic [FEATURE_WIDTH-1:0] read_row,                   // From Argmax (for reading results)
  
  output logic [COO_ADDRESS_WIDTH-1:0] coo_address,            // To testbench (which COO column)
  output logic [FEATURE_WIDTH-1:0] read_fm_wm_row,             // To Transform Block (which row to read)
  output logic done_comb,                                       // To Argmax
  output logic [DOT_PROD_WIDTH-1:0] adj_fm_wm_row [0:WEIGHT_COLS-1]  // To Argmax
);

  // ========================================================================
  // Internal Signals
  // ========================================================================
  
  // FSM control signals
  logic enable_coo_counter;
  logic enable_write_adj;
  logic swap_src_dst;  // Swap src/dst for reverse edge processing
  
  // COO decoder outputs
  logic [FEATURE_WIDTH-1:0] src_index;   // Source node (0-indexed)
  logic [FEATURE_WIDTH-1:0] dst_index;   // Destination node (0-indexed)
  
  // Muxed indices (swap for reverse edge in undirected mode)
  logic [FEATURE_WIDTH-1:0] read_index;   // Which FM_WM row to read
  logic [FEATURE_WIDTH-1:0] write_index;  // Which ADJ row to write
  
  // Memory signals
  logic [DOT_PROD_WIDTH-1:0] current_adj_value [0:WEIGHT_COLS-1];  // Current aggregation at dst
  logic [DOT_PROD_WIDTH-1:0] new_adj_value [0:WEIGHT_COLS-1];      // Sum to write back
  
  // ========================================================================
  // Index Muxing for Undirected Support
  // ========================================================================
  // Normal (forward):  read FM_WM[src], write ADJ[dst]
  // Reverse (undirected): read FM_WM[dst], write ADJ[src]
  always_comb begin
    if (swap_src_dst) begin
      read_index = dst_index;   // Read destination features
      write_index = src_index;  // Write to source
    end
    else begin
      read_index = src_index;   // Read source features
      write_index = dst_index;  // Write to destination
    end
  end
  
  // Tell Transform Block which row to output
  assign read_fm_wm_row = read_index;

  // ========================================================================
  // Module Instantiations
  // ========================================================================

  // ------------------------------------------------------------------------
  // COO Address Counter - Counts through 6 edges
  // ------------------------------------------------------------------------
  COO_Address_Counter #(
    .COO_NUM_OF_COLS(COO_NUM_OF_COLS),
    .COO_ADDRESS_WIDTH(COO_ADDRESS_WIDTH)
  ) coo_counter_inst (
    .clk(clk),
    .reset(reset),
    .enable(enable_coo_counter),
    .coo_address(coo_address)
  );

  // ------------------------------------------------------------------------
  // COO Decoder - Convert 1-indexed to 0-indexed
  // ------------------------------------------------------------------------
  COO_Decoder #(
    .COO_BW(COO_BW),
    .FEATURE_WIDTH(FEATURE_WIDTH)
  ) coo_decoder_inst (
    .coo_in(coo_in),
    .src_index(src_index),
    .dst_index(dst_index)
  );

  // ------------------------------------------------------------------------
  // Vector Adder - Add source features to destination aggregation
  // ------------------------------------------------------------------------
  Vector_Adder_3 #(
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH)
  ) vector_adder_inst (
    .vector_a(fm_wm_row_data),        // Source node features from Transform Block
    .vector_b(current_adj_value),     // Current aggregation at destination
    .vector_sum(new_adj_value)        // New aggregation to write back
  );

  // Memory read address selection
  logic [FEATURE_WIDTH-1:0] memory_read_address;
  
  // During processing: read from write_index for accumulation (dst in forward, src in reverse)
  // After done: read from Argmax's requested row
  always_comb begin
    if (done_comb) begin
      memory_read_address = read_row;    // Argmax controls read
    end
    else begin
      memory_read_address = write_index; // Read where we'll write (for accumulation)
    end
  end
  
  // ------------------------------------------------------------------------
  // ADJ_FM_WM Memory - Stores aggregated results
  // ------------------------------------------------------------------------
  Matrix_FM_WM_ADJ_Memory #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .WEIGHT_WIDTH($clog2(WEIGHT_COLS)),
    .FEATURE_WIDTH(FEATURE_WIDTH)
  ) adj_memory_inst (
    .clk(clk),
    .rst(reset),
    .write_row(write_index),              // Write to muxed index (dst in forward, src in reverse)
    .read_row(memory_read_address),       // Muxed read address
    .wr_en(enable_write_adj),
    .fm_wm_adj_row_in(new_adj_value),     // Write the sum
    .fm_wm_adj_out(current_adj_value)     // Read output (used for both accumulation and Argmax)
  );
  
  // Output to Argmax
  assign adj_fm_wm_row = current_adj_value;

  // ------------------------------------------------------------------------
  // Combination FSM - Master controller
  // ------------------------------------------------------------------------
  Combination_FSM #(
    .COO_NUM_OF_COLS(COO_NUM_OF_COLS),
    .COO_ADDRESS_WIDTH(COO_ADDRESS_WIDTH),
    .UNDIRECTED(UNDIRECTED)           // Pass through UNDIRECTED parameter
  ) fsm_inst (
    .clk(clk),
    .reset(reset),
    .done_trans(done_trans),
    .coo_address(coo_address),
    .enable_coo_counter(enable_coo_counter),
    .enable_write_adj(enable_write_adj),
    .swap_src_dst(swap_src_dst),      // Receive swap control signal
    .done_comb(done_comb)
  );

endmodule
