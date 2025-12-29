module COO_Decoder
  #(parameter COO_BW = 3,  // Bit width for each COO field
    parameter FEATURE_WIDTH = 3,  // Bit width for feature row indices
    parameter bit COO_ONE_INDEXED = 1  // 1 if COO uses 1-6, 0 if uses 0-5
)
(
  input  logic [2*COO_BW-1:0] coo_in,            // Packed: {row0, row1}
  output logic [FEATURE_WIDTH-1:0] src_index,    // Source index (0-indexed)
  output logic [FEATURE_WIDTH-1:0] dst_index     // Destination index (0-indexed)
);

  // Extract upper and lower fields from packed input
  // Testbench: coo_in = {coo_matrix_mem[0], coo_matrix_mem[1]}
  // Upper bits [5:3] = row0 = sources
  // Lower bits [2:0] = row1 = destinations
  logic [COO_BW-1:0] upper;
  logic [COO_BW-1:0] lower;
  
  assign upper = coo_in[2*COO_BW-1:COO_BW];  // [5:3] = row0 = sources
  assign lower = coo_in[COO_BW-1:0];         // [2:0] = row1 = destinations
  
  // Convert from 1-indexed to 0-indexed
  always_comb begin
    if (COO_ONE_INDEXED) begin
      src_index = upper - 1'b1;  // row0 (upper) is source
      dst_index = lower - 1'b1;  // row1 (lower) is destination
    end
    else begin
      src_index = upper;  // Already 0-indexed
      dst_index = lower;
    end
  end

endmodule
