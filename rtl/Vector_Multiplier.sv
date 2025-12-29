module Vector_Multiplier
  #(parameter FEATURE_COLS = 96,
    parameter FEATURE_WIDTH = 5,
    parameter WEIGHT_WIDTH = 5,
    parameter DOT_PROD_WIDTH = 16
)
(
  input  logic [FEATURE_WIDTH-1:0] feature_row [0:FEATURE_COLS-1],
  input  logic [WEIGHT_WIDTH-1:0]  weight_col [0:FEATURE_COLS-1],
  output logic [DOT_PROD_WIDTH-1:0] dot_product
);

  // Intermediate signals for partial products
  // 5-bit × 5-bit = 10-bit product (unsigned multiplication)
  logic [9:0] partial_products [0:FEATURE_COLS-1];
  
  // Accumulator for summing (needs extra bits to prevent overflow)
  logic [DOT_PROD_WIDTH-1:0] sum;

  // Step 1: Compute all 96 parallel multiplications
  always_comb begin
    for (int i = 0; i < FEATURE_COLS; i++) begin
      partial_products[i] = feature_row[i] * weight_col[i];
    end
  end

  // Step 2: Sum all partial products using tree reduction
  always_comb begin
    sum = '0;  // Initialize to 0
    for (int i = 0; i < FEATURE_COLS; i++) begin
      sum = sum + partial_products[i];
    end
  end

  // Output assignment
  assign dot_product = sum;

endmodule