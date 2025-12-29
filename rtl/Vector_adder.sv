module Vector_Adder_3
  #(parameter WEIGHT_COLS = 3,
    parameter DOT_PROD_WIDTH = 16
)
(
  input  logic [DOT_PROD_WIDTH-1:0] vector_a [0:WEIGHT_COLS-1],  // First vector
  input  logic [DOT_PROD_WIDTH-1:0] vector_b [0:WEIGHT_COLS-1],  // Second vector
  output logic [DOT_PROD_WIDTH-1:0] vector_sum [0:WEIGHT_COLS-1] // Sum vector
);

  // Combinational parallel addition
  // Add corresponding elements of both vectors
  always_comb begin
    for (int i = 0; i < WEIGHT_COLS; i++) begin
      vector_sum[i] = vector_a[i] + vector_b[i];
    end
  end

endmodule