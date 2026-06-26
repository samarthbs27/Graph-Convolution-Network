# RTL Source Files

SystemVerilog implementation of the GCN accelerator. All modules are synthesizable
and parameterized. Compiled with Synopsys Design Compiler V-2023.12 targeting ASAP7 RVT cells.

## Module Hierarchy

```
GCN (top)
├── Transformation_Block
│   ├── Transformation_FSM     # FSM controlling weight/feature read sequencing
│   ├── Matrix_FM_WM_Memory    # Feature and weight matrix storage
│   ├── Scratch_Pad            # Intermediate dot-product accumulation
│   ├── Vector_Multiplier      # 96-wide parallel MAC datapath
│   └── Counter                # Weight and feature column counters
├── Combination_Block
│   ├── Combination_FSM        # FSM controlling COO adjacency walk
│   ├── COO_Address_Counter    # Sparse edge address generation
│   ├── COO_Decoder            # COO row/col decode
│   ├── Matrix_FM_WM_ADJ_Memory # Adjacency-weighted feature accumulation
│   └── Vector_adder           # Element-wise addition across neighbors
└── Argmax                     # Per-node maximum class selection
```

## Key Parameters (set in GCN.sv)

| Parameter | Default | Description |
|---|---|---|
| `FEATURE_COLS` | 96 | Features per node (MAC datapath width) |
| `FEATURE_ROWS` | 6 | Number of graph nodes |
| `WEIGHT_COLS` | 3 | Output classes |
| `FEATURE_WIDTH` | 5 | Input data bit width |
| `WEIGHT_WIDTH` | 5 | Weight bit width |
| `DOT_PROD_WIDTH` | 16 | Dot product accumulator width |

## RTL Fix Notes

`Transformation_FSM.sv` was rewritten to eliminate 9 inferred DHLx1 latches.
Root cause: `always_comb` block had no default output assignments and no `default`
case, leaving states 6–7 of a 3-bit enum unhandled. Fix matches `Combination_FSM.sv`
style — defaults at top, each state overrides only what changes.
