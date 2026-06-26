# Testbenches

Functional verification testbenches using Cadence VCS. Run all commands from the
project root (`pd-closurelab-ppa-pilot/`) so that `./Data/` resolves correctly.

## Command Files

| File | Tests |
|---|---|
| `command_gcn.txt` | Full GCN top-level simulation |
| `command_transform.txt` | Transformation block only |
| `command_combination.txt` | Combination block only |
| `command_argmax.txt` | Argmax module only |

## Running Simulation

```bash
# Full GCN (run from project root)
vcs -timescale=1ns/100ps -sverilog $(cat tb/command_gcn.txt)
./simv

# Transformation block only
vcs -timescale=1ns/100ps -sverilog $(cat tb/command_transform.txt)
./simv
```

## Post-Synthesis / Post-APR Simulation

`GCN_TB_post_syn_apr.sv` is a gate-level simulation testbench template.
Before use:
1. Set `HALF_CLOCK_CYCLE` to match your clock (e.g., `700` for 1.4 ns clock in ps units)
2. Replace `MODIFY_YOUR_PATH_HERE` with absolute path to `Data/`
3. Compile with gate-level netlist (`GDS/GCN_<period>.apr.v`) and ASAP7 cell models

## Test Data

Input vectors live in `Data/`:
- `feature_data.txt` — 6×96 feature matrix (binary)
- `weight_data.txt` — 96×3 weight matrix (binary)
- `coo_data.txt` — sparse adjacency in COO format
- `gold_address.txt` — expected argmax class per node
