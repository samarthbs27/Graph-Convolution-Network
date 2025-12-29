module Combination_FSM
  #(parameter COO_NUM_OF_COLS = 6,
    parameter COO_ADDRESS_WIDTH = $clog2(COO_NUM_OF_COLS),
    parameter bit UNDIRECTED = 1  // 1 for undirected graph (A + A^T), 0 for directed
)
(
  input  logic clk,
  input  logic reset,
  input  logic done_trans,                              // Transformation complete
  input  logic [COO_ADDRESS_WIDTH-1:0] coo_address,     // Current edge being processed
  
  output logic enable_coo_counter,                      // Enable COO address counter
  output logic enable_write_adj,                        // Write to ADJ memory
  output logic swap_src_dst,                            // Swap src/dst for reverse edge
  output logic done_comb                                // Combination complete
);

  typedef enum logic [2:0] {
    IDLE,
    PROCESS_EDGE,      // Process forward edge: ADJ[dst] += FM_WM[src]
    PROCESS_REVERSE,   // Process reverse edge: ADJ[src] += FM_WM[dst] (if UNDIRECTED)
    INCREMENT_COO,
    DONE
  } state_t;

  state_t current_state, next_state;

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
    enable_coo_counter = 1'b0;
    enable_write_adj = 1'b0;
    swap_src_dst = 1'b0;
    done_comb = 1'b0;
    next_state = current_state;

    case (current_state)
      
      IDLE: begin
        if (done_trans) begin
          next_state = PROCESS_EDGE;
        end
        else begin
          next_state = IDLE;
        end
      end

      PROCESS_EDGE: begin
        // Forward edge: ADJ[dst] += FM_WM[src]
        enable_write_adj = 1'b1;
        swap_src_dst = 1'b0;  // Normal: read src, write dst
        
        // If undirected, process reverse edge next
        if (UNDIRECTED) begin
          next_state = PROCESS_REVERSE;
        end
        else begin
          // Directed mode: check if last edge
          if (coo_address == COO_NUM_OF_COLS - 1) begin
            next_state = DONE;
          end
          else begin
            next_state = INCREMENT_COO;
          end
        end
      end

      PROCESS_REVERSE: begin
        // Reverse edge: ADJ[src] += FM_WM[dst]
        // Only executed if UNDIRECTED = 1
        enable_write_adj = 1'b1;
        swap_src_dst = 1'b1;  // Swapped: read dst, write src
        
        // Check if this was the last edge
        if (coo_address == COO_NUM_OF_COLS - 1) begin
          next_state = DONE;
        end
        else begin
          next_state = INCREMENT_COO;
        end
      end

      INCREMENT_COO: begin
        enable_coo_counter = 1'b1;
        next_state = PROCESS_EDGE;
      end

      DONE: begin
        done_comb = 1'b1;
        next_state = DONE;
      end

      default: begin
        next_state = IDLE;
      end

    endcase
  end

endmodule

