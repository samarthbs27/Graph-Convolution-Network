module Argmax_Block
  #(parameter FEATURE_ROWS = 6,
    parameter WEIGHT_COLS = 3,
    parameter DOT_PROD_WIDTH = 16,
    parameter MAX_ADDRESS_WIDTH = 2,  // $clog2(3) = 2 bits for indices 0,1,2
    parameter FEATURE_WIDTH = $clog2(FEATURE_ROWS)
)
(
  input  logic clk,
  input  logic reset,
  input  logic done_comb,                                        // Start signal from Combination Block
  input  logic [DOT_PROD_WIDTH-1:0] adj_fm_wm_row [0:WEIGHT_COLS-1],  // One row from Combination Block
  
  output logic [FEATURE_WIDTH-1:0] read_row,                     // Which row to read from Combination Block
  output logic done,                                             // Argmax complete
  output logic [MAX_ADDRESS_WIDTH-1:0] max_addi_answer [0:FEATURE_ROWS-1]  // Final output (column indices)
);

  // ========================================================================
  // Internal Signals
  // ========================================================================
  
  // Row counter - which row we're currently processing
  logic [FEATURE_WIDTH-1:0] row_counter;
  
  // FSM states
  typedef enum logic [1:0] {
    IDLE,
    PROCESS_ROW,
    INCREMENT_ROW,
    DONE
  } state_t;
  
  state_t current_state, next_state;
  
  // Maximum column index for current row (combinational)
  logic [MAX_ADDRESS_WIDTH-1:0] max_column_index;

  // ========================================================================
  // Row Counter
  // ========================================================================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      row_counter <= '0;
    end
    else if (current_state == INCREMENT_ROW) begin
      if (row_counter == FEATURE_ROWS - 1) begin
        row_counter <= '0;  // Wrap (though we'll be in DONE state)
      end
      else begin
        row_counter <= row_counter + 1'b1;
      end
    end
  end

  // ========================================================================
  // Argmax Comparator (Combinational)
  // Finds which of the 3 columns has the maximum value
  // Returns 0-indexed column number (0, 1, or 2)
  // ========================================================================
  always_comb begin
    // Compare all three values and determine the index of maximum
    // Priority: if equal values, choose lower index (0 > 1 > 2)
    
    if (adj_fm_wm_row[0] >= adj_fm_wm_row[1] && adj_fm_wm_row[0] >= adj_fm_wm_row[2]) begin
      // Column 0 is maximum
      max_column_index = 2'b00;
    end
    else if (adj_fm_wm_row[1] >= adj_fm_wm_row[2]) begin
      // Column 1 is maximum
      max_column_index = 2'b01;
    end
    else begin
      // Column 2 is maximum
      max_column_index = 2'b10;
    end
  end

  // ========================================================================
  // Output Row Address (tells Combination Block which row to read)
  // ========================================================================
  assign read_row = row_counter;

  // ========================================================================
  // FSM State Register
  // ========================================================================
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      current_state <= IDLE;
    else
      current_state <= next_state;
  end

  // ========================================================================
  // FSM Next State Logic and Outputs
  // ========================================================================
  always_comb begin
    // Default outputs
    next_state = current_state;
    done = 1'b0;

    case (current_state)
      
      IDLE: begin
        if (done_comb) begin
          next_state = PROCESS_ROW;
        end
      end

      PROCESS_ROW: begin
        // In this state:
        // - row_counter addresses Combination Block
        // - adj_fm_wm_row contains the data
        // - max_column_index is computed combinationally
        // - Store result in max_addi_answer array
        
        next_state = INCREMENT_ROW;
      end

      INCREMENT_ROW: begin
        // Check if we've processed all rows
        if (row_counter == FEATURE_ROWS - 1) begin
          next_state = DONE;
        end
        else begin
          next_state = PROCESS_ROW;
        end
      end

      DONE: begin
        done = 1'b1;
        next_state = DONE;  // Stay in DONE
      end

      default: begin
        next_state = IDLE;
      end

    endcase
  end

  // ========================================================================
  // Store Results in Output Array
  // ========================================================================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      for (int i = 0; i < FEATURE_ROWS; i++) begin
        max_addi_answer[i] <= '0;
      end
    end
    else if (current_state == PROCESS_ROW) begin
      // Store the max column index for current row
      max_addi_answer[row_counter] <= max_column_index;
    end
  end

endmodule
