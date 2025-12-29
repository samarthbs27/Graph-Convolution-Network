# GCN Hardware Accelerator

**A Graph Convolutional Network (GCN) implemented in SystemVerilog for FPGA**

College project implementing a hardware accelerator for graph neural networks.

---

## What Does It Do?

Takes a graph with 6 nodes and classifies each node into one of 3 categories using:
- Node features (96 values per node)
- Graph structure (which nodes are connected)
- Learned weights

**Example:** Social network where you classify users as "active", "casual", or "inactive" based on their activity and connections.

---

## Architecture

Simple 3-stage pipeline:

```
Stage 1: TRANSFORMATION          Stage 2: COMBINATION           Stage 3: ARGMAX
┌─────────────────────┐         ┌─────────────────────┐       ┌─────────────────────┐
│                     │         │                     │       │                     │
│  Matrix Multiply    │    ──►  │  Graph Aggregation  │  ──►  │  Find Max (Class)   │
│  FM × WM            │         │  Using Adjacency    │       │  Per Node           │
│                     │         │                     │       │                     │
│  ~36 cycles         │         │  ~12 cycles         │       │  ~15 cycles         │
└─────────────────────┘         └─────────────────────┘       └─────────────────────┘
```

**Total:** ~63 clock cycles to classify all 6 nodes

---

## Files

```
rtl/                              # All SystemVerilog source files
├── GCN.sv                       # Top module (main file)
├── Transformation_Block.sv      # Stage 1: Matrix multiplication
├── Combination_Block.sv         # Stage 2: Graph operations  
├── Argmax.sv                    # Stage 3: Classification
└── ... (10 more support files)

docs/                            # Documentation and diagrams
└── (architecture diagrams)
```

---

## Quick Start

### 1. Check Files
Make sure you have all 14 `.sv` files in the `rtl/` folder.

### 2. Compile (ModelSim Example)
```bash
vlog -sv rtl/*.sv
# Should compile without errors
```

### 3. Synthesize (Vivado Example)
```tcl
read_verilog -sv rtl/*.sv
synth_design -top GCN -part xc7a100tcsg324-1
```

---

## Inputs/Outputs

### Inputs
- `clk` - Clock signal
- `reset` - Reset (active high)
- `start` - Start processing
- `data_in[0:95]` - Input data (96 × 5-bit values)
- `coo_in[5:0]` - Graph edge data

### Outputs
- `done` - Processing complete
- `max_addi_answer[0:5]` - Results (6 nodes × 2-bit class)
- `read_address[12:0]` - Memory address
- `enable_read` - Memory read enable

---

## Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| Nodes | 6 | Number of nodes in graph |
| Features | 96 | Features per node |
| Classes | 3 | Output categories (0, 1, or 2) |
| Data Width | 5-bit | Input precision |
| Latency | ~63 cycles | Time to process one graph |

---

## How to Change Graph Size

Edit parameters in `GCN.sv`:

```systemverilog
GCN #(
    .FEATURE_ROWS(10),      // Change to 10 nodes
    .FEATURE_COLS(128),     // Change to 128 features
    .WEIGHT_COLS(5)         // Change to 5 classes
) my_gcn (
    // ... ports
);
```

---

## Resource Usage (Estimated)

For default configuration (6 nodes, 96 features):
- **Flip-Flops:** ~3,000
- **LUTs:** ~12,000  
- **DSP Blocks:** 96 (multipliers)
- **BRAM:** 3-6 blocks

**Fits on:** Xilinx Artix-7, Zynq-7000, Intel Cyclone V

---

## Design Features

✅ **Fully Synthesizable** - Works with Vivado, Quartus, etc.  
✅ **Sparse Graphs** - Efficient COO format  
✅ **Undirected Graphs** - Processes edges both ways  
✅ **Parameterized** - Easy to scale up/down  
✅ **Fixed-Point** - Hardware-efficient arithmetic

---

## Testing

Basic test sequence:
1. Assert `reset` 
2. Load data into memory
3. Set `start = 1`
4. Wait for `done = 1`
5. Read `max_addi_answer` for results

---

## Known Limitations

- Graph size fixed at synthesis (not runtime configurable)
- Works best for small graphs (6-100 nodes)
- Inference only (no training)
- Sequential processing (one graph at a time)


---

## License

MIT License - See LICENSE file


---

**Status:** ✅ Complete and tested  
**Last Updated:** December 2025
