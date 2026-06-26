# GCN Accelerator — RTL-to-GDS Physical Design Closure

**ASIC physical design implementation of a sparse Graph Convolutional Network (GCN) accelerator
from RTL to GDSII using Cadence Innovus and the ASAP7 predictive 7nm PDK.**

This is Project 1 of a two-part physical design portfolio.
Project 2 (ML-guided PPA sweep automation) lives in the companion
[PPA-Pilot](https://github.com/samarthbs27/PPA-Pilot) repository.

---

## Design Overview

The GCN accelerator classifies nodes in a sparse graph using a single-layer graph convolution:

```
Input Graph (6 nodes, 96 features/node, COO adjacency)
        │
        ▼
┌─────────────────────┐     ┌─────────────────────┐     ┌──────────────┐
│   TRANSFORMATION    │────►│    COMBINATION      │────►│    ARGMAX    │
│  Feature × Weight   │     │  Graph Aggregation  │     │  Node Class  │
│  96-wide parallel   │     │  COO-format sparse  │     │  per node    │
│  MAC datapath       │     │  adjacency walk     │     │              │
└─────────────────────┘     └─────────────────────┘     └──────────────┘
        │
        └── ~63 clock cycles end-to-end for 6-node graph
```

| Parameter | Value |
|---|---|
| Nodes | 6 |
| Features per node | 96 |
| Output classes | 3 |
| Datapath width | 5-bit input, 16-bit dot product |
| Adjacency format | COO (sparse) |

---

## Physical Design Flow

```
SystemVerilog RTL
      │
      ▼  dc_shell (Synopsys Design Compiler V-2023.12)
Synthesized Netlist + SDC
      │
      ▼  innovus (Cadence Innovus 23.12)
Floorplan → Power Grid → Tap Cells → Pin Assignment
      │
      ▼
Global Placement → Pre-CTS Opt → CTS → Post-CTS Opt
      │
      ▼
NanoRoute → Post-Route Opt (OCV) → SPEF Extraction
      │
      ▼
Post-Route STA · Power Report · DRC · GDS/DEF/SPEF
```

**PDK:** ASAP7 predictive 7nm PDK, RVT standard-cell library, TT/0.7V/25C corner

---

## Repository Structure

```
GCN/
├── rtl/                    # SystemVerilog source (14 modules)
├── tb/                     # Testbenches and VCS command files
├── constraints/
│   └── GCN.sdc             # Human-editable SDC template
├── flow/
│   ├── synth/synth.tcl     # Design Compiler synthesis script
│   ├── apr/innovus_flow.tcl # Cadence Innovus APR script
│   ├── apr/Default.globals  # Innovus initialization
│   ├── apr/Default.view     # MMMC timing corner setup
│   └── user_config.tcl.template  # Server path config (gitignored when filled)
├── reports/
│   └── raw/
│       ├── baseline/        # First end-to-end run (with RTL bugs, no antenna fix)
│       └── optimized_02/    # Final 714 MHz closure result
├── docs/
│   └── closure_report.md   # Closure narrative with before/after metrics
├── Data/                   # Simulation input vectors (feature, weight, COO, gold)
└── images/                 # Layout screenshots, congestion maps
```

---

## Quickstart

### Prerequisites

- Synopsys Design Compiler (V-2023.12 or later)
- Cadence Innovus (23.12 or later)
- ASAP7 PDK installed at `/apps/share64/rocky8/asap7/`
- Cadence VCS for simulation

### 1. Configure paths

```bash
cp flow/user_config.tcl.template flow/user_config.tcl
# Edit user_config.tcl: set project_home, rtl_dir, synth_out_dir, clk_period
```

### 2. Run simulation (functional verification)

```bash
# From project root
vcs -timescale=1ns/100ps -sverilog $(cat tb/command_gcn.txt)
./simv
```

### 3. Run synthesis

```bash
# From synthesis work directory
dc_shell -f flow/synth/synth.tcl -output_log_file syn.log
```

Output: `synthesis/GCN.<period>.syn.v` and `synthesis/GCN.<period>.syn.sdc`

### 4. Run APR

```bash
# From APR work directory
innovus -init flow/apr/innovus_flow.tcl
# Or interactively: innovus> source flow/apr/innovus_flow.tcl
```

Output: `checkpoints/`, `reports/`, `GDS/GCN_<period>.gds`

---

## Baseline vs Optimized Results (714 MHz / 1.4 ns)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Clock period | 1.400 ns | 1.400 ns | — |
| Setup WNS | +0.093 ns | +0.094 ns | clean |
| Setup violations | 0 | 0 | clean |
| Hold WNS | −0.001 ns | +0.134 ns | closed |
| Hold violations | 3 | **0** | −3 |
| DHLx1 inferred latches | 9 | **0** | RTL fix |
| Antenna DRC violations | unknown | **0** | fixed |
| Geometry DRC | 9,054 | 8,872 | −182 |
| Cell area | 21,409 µm² | 21,022 µm² | −1.8% |
| Instance count | 10,520 | 10,140 | −3.6% |
| Total power | 3.156 mW | 3.134 mW | −0.7% |
| Core density | 52.6% | 51.8% | — |

### What changed

1. **RTL fix** — `Transformation_FSM.sv` `always_comb` had no default outputs and
   no `default` case, causing Design Compiler to infer 9 DHLx1 level-sensitive latches.
   Fixed by adding default output assignments at the top of the block and an explicit
   `default: next_state = START` case. Verified by re-simulation before re-synthesis.

2. **Antenna fixing enabled** — `setNanoRouteMode -route_detail_fix_antenna true`
   eliminated all antenna DRC violations. Geometry DRC (M2 off-grid, V3/V5 enclosure)
   is a known ASAP7/NanoRoute open-source flow limitation.

3. **IO hold exemption** — `set_false_path -hold` on input/output ports removed 3
   spurious IO hold violations. reg2reg hold slack is +0.134 ns with 0 violations.

---

## Artifacts

| Artifact | Path (on server) |
|---|---|
| Synthesized netlist | `synthesis/GCN.1400.syn.v` |
| SDC constraints | `synthesis/GCN.1400.syn.sdc` |
| Routed DEF | `apr/checkpoints/GCN_1400.final.enc` |
| GDS | `apr/GDS/GCN_1400.gds` |
| SPEF | `apr/GDS/GCN_1400.spef` |
| Gate-level netlist | `apr/GDS/GCN_1400.apr.v` |
| Timing reports | `apr/reports/timing/postRoute/` |
| Power report | `apr/reports/power/power.rpt` |
| DRC report | `apr/reports/drc.rpt` |
| Baseline raw reports | `reports/raw/baseline/` |
| Optimized raw reports | `reports/raw/optimized_02/` |

---

## Known Limitations

- **Geometry DRC (8,872):** M2 off-grid and V3/V5 enclosure violations are inherent
  to NanoRoute routing against ASAP7's aggressive spacing rules. Full DRC signoff
  requires Calibre with the complete ASAP7 DRC deck.
- **Max-fanout DRVs (~120 nets):** 96-wide scratchpad enable signals exceed the
  SDC `set_max_fanout 16` limit. DC inserts buffer trees but Innovus re-optimizes
  placement and partially collapses them. Does not affect timing (setup WNS > 0).
- **Single corner:** ASAP7 open PDK ships TT libraries only. A real flow would use
  SS libs for setup and FF libs for hold in MMMC.
- **Power activity:** Power reported at default 0.2 toggle rate (no VCD).

---

## References

- [ASAP7 PDK](https://github.com/The-OpenROAD-Project/asap7)
- [Cadence Innovus Documentation](https://support.cadence.com)
- [PPA-Pilot — ML-guided PPA sweep automation](https://github.com/samarthbs27/PPA-Pilot)
