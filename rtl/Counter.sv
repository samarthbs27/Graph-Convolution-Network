module Counter
  #(parameter COUNT_WIDTH = 3,           // Width of counter
    parameter MAX_COUNT = 5              // Maximum count value (inclusive)
)
(
  input  logic clk,
  input  logic reset,
  input  logic enable,                   // Count when enabled
  output logic [COUNT_WIDTH-1:0] count   // Current count value
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      count <= '0;                       // Reset to 0
    end
    else if (enable) begin
      if (count == MAX_COUNT) begin
        count <= '0;                     // Wrap around to 0
      end
      else begin
        count <= count + 1'b1;           // Increment
      end
    end
  end

endmodule