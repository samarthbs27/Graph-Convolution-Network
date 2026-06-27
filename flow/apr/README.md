# GCN/flow/apr — Cadence Innovus APR Scripts

Cadence Innovus 23.12 place-and-route flow for the GCN accelerator.
ASAP7 predictive 7nm PDK, RVT cells, TT/0.7V/25C nominal corner.

| File | Purpose |
|---|---|
| `innovus_flow.tcl` | Full RTL-to-GDS APR flow — source inside Innovus or run via `innovus -batch` |
| `user_config.tcl.template` | Template for per-run parameters (`clk_period`, `util_target`, `aspect_ratio`, `core_margin`, `cong_effort`) |
| `Default.globals` | Server-specific design init (LEF, netlist, MMMC paths) — not in repo |
| `Default.view` | MMMC timing corners and SDC — not in repo |
| `user_config.tcl` | Active run config — written automatically by `run_sweep.py`, not in repo |

For server setup, sweep execution, and report transfer instructions see
`docs/server_setup.md` in the companion [PPA-Pilot](https://github.com/samarthbs27/PPA-Pilot) repository.
