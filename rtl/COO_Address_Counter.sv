module COO_Address_Counter
  #(parameter COO_NUM_OF_COLS = 6,
    parameter COO_ADDRESS_WIDTH = $clog2(COO_NUM_OF_COLS)  // 3 bits for 0-5
)
(
  input  logic clk,
  input  logic reset,
  input  logic enable,                              // Enable counting
  output logic [COO_ADDRESS_WIDTH-1:0] coo_address  // Current COO column index
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      coo_address <= '0;
    end
    else if (enable) begin
      if (coo_address == COO_NUM_OF_COLS - 1) begin
        coo_address <= '0;  // Wrap around after processing all edges
      end
      else begin
        coo_address <= coo_address + 1'b1;
      end
    end
  end

endmodule
