module Transformation_Block
  #(parameter FEATURE_COLS = 96,
    parameter WEIGHT_ROWS = 96,
    parameter FEATURE_ROWS = 6,
    parameter WEIGHT_COLS = 3,
    parameter FEATURE_WIDTH = 5,
    parameter WEIGHT_WIDTH = 5,
    parameter DOT_PROD_WIDTH = 16,
    parameter ADDRESS_WIDTH = 13,
    parameter COUNTER_WEIGHT_WIDTH = $clog2(WEIGHT_COLS),
    parameter COUNTER_FEATURE_WIDTH = $clog2(FEATURE_ROWS)
)
(
  input  logic clk,
  input  logic reset,
  input  logic start,
  input  logic [WEIGHT_WIDTH-1:0] data_in [0:WEIGHT_ROWS-1],  // From external memory
  input  logic [COUNTER_FEATURE_WIDTH-1:0] read_row,          // From Combination Block
  
  output logic [ADDRESS_WIDTH-1:0] read_address,              // To external memory
  output logic enable_read,                                    // To external memory
  output logic done_trans,                                     // To Combination Block
  output logic [DOT_PROD_WIDTH-1:0] fm_wm_row_out [0:WEIGHT_COLS-1]  // To Combination Block
);

  // ========================================================================
  // Internal Signals
  // ========================================================================
  
  // Counter outputs
  logic [COUNTER_WEIGHT_WIDTH-1:0] weight_count;
  logic [COUNTER_FEATURE_WIDTH-1:0] feature_count;
  
  // FSM control signals
  logic enable_write_fm_wm_prod;
  logic enable_scratch_pad;
  logic enable_weight_counter;
  logic enable_feature_counter;
  logic read_feature_or_weight;
  
  // Scratchpad signals
  logic [WEIGHT_WIDTH-1:0] weight_col_out [0:WEIGHT_ROWS-1];
  
  // Vector Multiplier output
  logic [DOT_PROD_WIDTH-1:0] dot_product;


  // ========================================================================
  // Address Generation Logic
  // ========================================================================
  
  // Generate read addresses based on counter values and control signal
  // Weight addresses: 0, 1, 2 (for weight columns 0, 1, 2)
  // Feature addresses: 0x200-0x205 (512-517 decimal)
  
  always_comb begin
    if (read_feature_or_weight == 1'b0) begin
      // Reading weight matrix (0x0 - 0xFF range)
      read_address = {{(ADDRESS_WIDTH-COUNTER_WEIGHT_WIDTH){1'b0}}, weight_count};
    end
    else begin
      // Reading feature matrix (0x200 - 0x2FF range)
      // Base address: 0x200 = 512 decimal = 13'b0_0010_0000_0000
      read_address = 13'h200 + {{(ADDRESS_WIDTH-COUNTER_FEATURE_WIDTH){1'b0}}, feature_count};
    end
  end


  // ========================================================================
  // Module Instantiations
  // ========================================================================

  // ------------------------------------------------------------------------
  // Control FSM
  // ------------------------------------------------------------------------
  Transformation_FSM #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .COUNTER_WEIGHT_WIDTH(COUNTER_WEIGHT_WIDTH),
    .COUNTER_FEATURE_WIDTH(COUNTER_FEATURE_WIDTH)
  ) fsm_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .weight_count(weight_count),
    .feature_count(feature_count),
    
    .enable_write_fm_wm_prod(enable_write_fm_wm_prod),
    .enable_read(enable_read),
    .enable_scratch_pad(enable_scratch_pad),
    .enable_weight_counter(enable_weight_counter),
    .enable_feature_counter(enable_feature_counter),
    .read_feature_or_weight(read_feature_or_weight),
    .done(done_trans)
  );

  // ------------------------------------------------------------------------
  // Weight Counter (0 to 2)
  // ------------------------------------------------------------------------
  Counter #(
    .COUNT_WIDTH(COUNTER_WEIGHT_WIDTH),
    .MAX_COUNT(WEIGHT_COLS - 1)
  ) weight_counter_inst (
    .clk(clk),
    .reset(reset),
    .enable(enable_weight_counter),
    .count(weight_count)
  );

  // ------------------------------------------------------------------------
  // Feature Counter (0 to 5)
  // ------------------------------------------------------------------------
  Counter #(
    .COUNT_WIDTH(COUNTER_FEATURE_WIDTH),
    .MAX_COUNT(FEATURE_ROWS - 1)
  ) feature_counter_inst (
    .clk(clk),
    .reset(reset),
    .enable(enable_feature_counter),
    .count(feature_count)
  );

  // ------------------------------------------------------------------------
  // Scratchpad (Weight Column Storage)
  // ------------------------------------------------------------------------
  Scratch_Pad #(
    .WEIGHT_ROWS(WEIGHT_ROWS),
    .WEIGHT_WIDTH(WEIGHT_WIDTH)
  ) scratchpad_inst (
    .clk(clk),
    .reset(reset),
    .write_enable(enable_scratch_pad),
    .weight_col_in(data_in),
    .weight_col_out(weight_col_out)
  );

  // ------------------------------------------------------------------------
  // Vector Multiplier (Combinational Dot Product)
  // ------------------------------------------------------------------------
  Vector_Multiplier #(
    .FEATURE_COLS(FEATURE_COLS),
    .FEATURE_WIDTH(FEATURE_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH)
  ) vector_mult_inst (
    .feature_row(data_in),
    .weight_col(weight_col_out),
    .dot_product(dot_product)
  );

  // ------------------------------------------------------------------------
  // Matrix FM_WM Memory (Result Storage)
  // ------------------------------------------------------------------------
  Matrix_FM_WM_Memory #(
    .FEATURE_ROWS(FEATURE_ROWS),
    .WEIGHT_COLS(WEIGHT_COLS),
    .DOT_PROD_WIDTH(DOT_PROD_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .WEIGHT_WIDTH(COUNTER_WEIGHT_WIDTH),
    .FEATURE_WIDTH(COUNTER_FEATURE_WIDTH)
  ) result_memory_inst (
    .clk(clk),
    .rst(reset),
    .write_row(feature_count),
    .write_col(weight_count),
    .read_row(read_row),
    .wr_en(enable_write_fm_wm_prod),
    .fm_wm_in(dot_product),
    .fm_wm_row_out(fm_wm_row_out)
  );

endmodule