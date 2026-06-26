# GCN Accelerator Physical Design Closure Report

**Design:** GCN (Graph Convolution Network) Accelerator  
**PDK:** ASAP7 predictive 7nm (22b synthesis cells, 27_R LEF, 201020 SEQ Liberty)  
**Synthesis tool:** Synopsys Design Compiler  
**APR tool:** Cadence Innovus 23.12  
**Target clock:** 1400 ps (714 MHz)  
**Status:** Baseline run complete — setup timing clean, hold nearly clean, 9,054 DRC violations (expected baseline)

---

## Tool/PDK Disclosure

Synthesis uses the `asap7sc7p5t_22b` DB family (`170906` dated, from `/apps/share64/rocky8/asap7/asap7-20250127/asap7sc7p5t_28/db/`). This is the older generation of ASAP7 standard cells.

APR uses:
- Tech LEF: `asap7_tech_4x_201209.lef`
- Cell LEF: `asap7sc7p5t_27_R_4x_201211.lef` (must match the `22b` synthesis cell family)
- Liberty (timing): `22b`-compatible NLDM libs — `INVBUF/AO/OA/SIMPLE` from the `28` NLDM directory, `SEQ` from `asap7sc7p5t_SEQ_RVT_TT_nldm_201020.lib`
- RC corner: `qrcTechFile_typ03_scaled4xV06`

> **Note on library version mismatch:** The course tutorial specifies `asap7sc7p5t_28` LEF and `220123` SEQ lib. These are the `28`-family files that match a synthesis flow using `set_dont_touch_network` (which produces `DHLx1` latches). Our synthesis omits `set_dont_touch_network` to get proper `ASYNC_DFFHx1_ASAP7_75t_R` flip-flops. Those cells only exist in the `22b` Liberty (`201020` SEQ lib) and `27_R` LEF — hence the deliberate divergence from the course defaults.

---

## SDC Constraints Summary

- Clock: `clk`, period 1400 ps
- Input delay: 0.1 ns (all data inputs)
- Output delay: 0.1 ns (all data outputs)
- Clock uncertainty: 0.01 ns
- Max fanout: 16
- Driving cell: `INVx3_ASAP7_75t_R`

---

## CTS Debugging Chain

### Problem 1: IMPCCOPT-2004 — No clock trees defined

**Symptom:** `create_ccopt_clock_tree_spec` found zero clock sinks. `report_net -net clk` showed 0 sink pins.

**Root cause (Layer 1): `set_dont_touch_network $clk_port` in `synth.tcl`**  
DC interpreted `always_ff @(posedge clk or posedge reset)` with a "don't touch clock" constraint as needing reimplemented as level-sensitive logic: it mapped sequential cells to `DHLx1_ASAP7_75t_R` (D High Latch) with a `NAND2xp33_ASAP7_75t_R` clock gate. `DHLx1` CLK pins are not edge-triggered — Innovus never recognized them as clock tree sinks.

**Fix:** Removed `set_dont_touch_network $clk_port` from `synth.tcl`. DC then correctly maps to `ASYNC_DFFHx1_ASAP7_75t_R` (async-reset D flip-flop) with a direct `.CLK(clk)` connection. Re-synthesis produced 1087 `ASYNC_DFFHx1` instances (plus 9 residual `DHLx1` latches for an FSM reset path).

**Root cause (Layer 2): Wrong SEQ Liberty in `Default.view`**  
`Default.view` referenced `asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib` (the `28`-family lib). That lib does not contain `ASYNC_DFFHx1_ASAP7_75t_R`. Innovus silently black-boxed all 1087 flip-flops — `get_db insts -if {.base_cell.name == "ASYNC_DFFHx1"}` returned 0 even though `grep -c "ASYNC_DFFHx1"` on the netlist returned 1087. Black-boxed cells have no timing pins, `is_sequential == false`, and no CLK connectivity, so the clock had 0 sinks.

**Confirmed:** `grep "cell (ASYNC_DFFHx1"` found zero hits in `220123.lib` and a valid hit in `asap7sc7p5t_SEQ_RVT_TT_nldm_201020.lib`.

**Fix:** Copied `asap7sc7p5t_SEQ_RVT_TT_nldm_201020.lib` (from `lab4/APR/`) to the APR directory and updated `Default.view` to reference it. This is the `22b`-compatible SEQ Liberty — the correct match for `22b` synthesis.

---

### Problem 2: IMPCCOPT-1146 — Clock tree contains instances which cannot be used

**Symptom:** Clock tree `clk` now found (1087 sinks), but `ccopt_design` refuses to run. Error: `ASYNC_DFFHx1_ASAP7_75t_R is cant_use for the following reasons: missing LEF data`.

**Root cause: LEF/synthesis family mismatch**  
`Default.globals` loaded `asap7sc7p5t_28_R_4x_220121a.lef` — the `28`-family cell LEF. `ASYNC_DFFHx1_ASAP7_75t_R` is a `22b`/`27`-family cell. The `28` LEF has no `MACRO ASYNC_DFFHx1_ASAP7_75t_R` definition. Without physical geometry (pin locations, cell bounding box), CCOpt cannot insert clock tree buffers or route to the cell's CLK pin.

**Confirmed:** `grep "MACRO ASYNC_DFFHx1"` found the cell in `asap7sc7p5t_27_R_4x_201211.lef` and not in `asap7sc7p5t_28_R_4x_220121a.lef`. System path for the `27_R` LEF: `/apps/share64/rocky8/asap7/asap7-20250127/asap7sc7p5t_27/LEF/scaled/asap7sc7p5t_27_R_4x_201211.lef`.

**Fix:** Updated `Default.globals` to load `asap7sc7p5t_27/LEF/scaled/asap7sc7p5t_27_R_4x_201211.lef` instead of `asap7sc7p5t_28/LEF/scaled/asap7sc7p5t_28_R_4x_220121a.lef`.

**Consistent library chain (post-fix):**

| Layer | File | Version | Status |
|---|---|---|---|
| Synthesis DB | `asap7sc7p5t_22b_*_RVT_TT_170906.db` | 22b | ✓ |
| Cell LEF | `asap7sc7p5t_27_R_4x_201211.lef` | 27 (22b-compatible) | ✓ fixed |
| SEQ Liberty | `asap7sc7p5t_SEQ_RVT_TT_nldm_201020.lib` | 22b-compatible | ✓ fixed |
| INVBUF/AO/OA/SIMPLE Liberty | `*nldm_220122/211120*.lib` | 28 | ✓ (no mismatch for combinational cells) |

---

### Other CTS-related changes

**`set_propagated_clock` before `clock_opt_design`:**  
Added originally to suppress `TCLCMD-1048`. Removed after confirming it caused CCOpt to trace through the `NAND2` clock gate (which drives the 9 residual `DHLx1` latch CLK pins), triggering a secondary IMPCCOPT-1146 about the NAND2. CCOpt handles propagated clock internally — no explicit call is needed before `clock_opt_design`.

**`set_dont_touch_network` in synthesis:**  
Intentionally omitted. See Problem 1 above. The course example script included it; omitting it here is the correct behavior for mapping async-reset always_ff blocks to proper DFF cells.

**DHLx1 residual latches:**  
9 `DHLx1_ASAP7_75t_R` instances remain from FSM reset path. These are driven through a `NAND2` clock gate. Marked `.dont_touch true` in CTS to prevent CCOpt from tracing through the NAND2.

---

### Shell redirection `>` not valid in Innovus-sourced scripts

**Symptom:** `invalid command name ">"` when sourcing a script in Innovus interactive mode (`source innovus_flow.tcl`).

**Root cause:** When Innovus executes a `source`-d file it runs through the pure Tcl interpreter, not the Innovus shell. `>` is a shell redirect operator — it does not exist as a Tcl command. It only works when typed interactively at the Innovus `innovus>` prompt (where Innovus wraps it).

**Fix:** Replace all `command > file` with Cadence's Tcl-compatible form:
```tcl
redirect ./reports/area.rpt { report_area }
redirect ./reports/drc.rpt  { verify_drc }
```
Also removed an erroneously added `exit` call (would kill the interactive Innovus session).

---

### `report_timing` syntax incompatibility in Innovus 23.x

**Symptom:** `TCLCMD-168: Invalid max_slack value 'max'` and `TCLCMD-981: Unsupported extra argument '-delay_type'` on `report_timing -delay max` / `report_timing -delay_type max`.

**Root cause:** Innovus 23.x does not support the `-delay max` or `-delay_type max` flags for `report_timing`. Neither matches 23.x syntax.

**Fix:** Removed all `report_timing` calls. `timeDesign -postRoute -expandedViews -outDir` already generates comprehensive WNS/TNS summary files (`.summary.gz`), which are the primary source for closure metrics.

---

## Baseline Run — Complete

Run completed: 2026-06-25. All stages: floorplan → placement → optDesign preCTS → CTS → optDesign postCTS → route → optDesign postRoute → timeDesign → SPEF → GDS.

| Metric | Value | Notes |
|---|---|---|
| Clock period | 1400 ps (714 MHz) | SDC constraint |
| Setup WNS | **+0.093 ns** | Clean — no violations |
| Setup TNS | **0.000 ns** | Clean |
| Setup violating paths | **0** | Clean |
| Hold WNS | **−0.001 ns** | 3 IO-path violations |
| Hold TNS | **−0.002 ns** | Nearly clean |
| Hold violating paths | **3** | Default (IO) paths only; reg2reg WNS +0.139 ns |
| max_cap violations | 0 | Clean |
| max_tran violations | 0 | Clean |
| max_fanout violations | **122 nets** | Worst net fanout ~73 vs SDC limit 16 |
| Logic cell area | **21,409 um²** | Excludes filler cells |
| Core area | 43,207 um² | |
| Chip area (die) | 47,499 um² | |
| Logic density | **49.55%** | Gate density excl. fillers — matches 50% target |
| Placement density | 52.643% | Including filler cells |
| Instance count (logic) | 10,520 | Excl. ~45,000 filler cells |
| ASYNC_DFFHx1 FFs | 1,087 | Primary sequential elements |
| FAx1 full adders | 2,403 | GCN MAC datapath |
| Total wirelength | 227,245 um | ~227 mm across 10 layers |
| Avg net length | 16.35 um | |
| DRC violations | **9,054** | Geometry rule checks — baseline for ASAP7 open-source |
| Internal power | 1.515 mW (48%) | |
| Switching power | 1.640 mW (52%) | |
| Leakage power | 0.001 mW (0.04%) | |
| Total power | **3.156 mW** | @TT/0.7V/25C, 0.2 toggle rate |
| Clock power | 0.268 mW (8.5%) | clk net only |
| VDD supply | 0.7 V | ASAP7 nominal |

### Baseline observations

**Positive:**
- Setup timing is clean with +93 ps of margin at 714 MHz. This is better than expected for a 50% utilization first pass; suggests the synthesis netlist quality is reasonable.
- Hold is nearly clean — 3 violations at IO paths only (−1 ps worst). reg2reg hold has 139 ps positive slack.
- No max_cap or max_tran violations — signal integrity within bounds.
- 49.55% logic density matches the 50% floorplan target closely.

**Issues for optimization:**

1. **DRC: 9,054 violations.** Baseline for ASAP7 open-source flow with default router settings. Root causes: ASAP7 7.5-track cell abutment generates short-distance antenna/spacing violations on M1/M2. Target for optimization: reduce below 1,000, ideally zero.

2. **Fanout: 122 nets exceed SDC max_fanout=16.** Worst net carries ~73 loads (fanout violation of −57 vs limit). High-fanout nets on data paths (likely weight/feature broadcast busses in the GCN MAC tile) cause this. Optimization levers: `setMaxFanout` in SDC, explicit buffer insertion on high-fanout nets, or restructuring the datapath.

3. **484 no-driven `weight_col_out[*]` nets.** Internal signals (`transformation_block_inst/weight_col_out[0:478]`) are not connected to the top-level outputs. This is an RTL connectivity issue — the weight column output bus is computed internally but not brought out as primary output pins. These dangling nets have no effect on timing but inflate the net count and may contribute to DRC antenna violations on floating wires.

4. **9 residual DHLx1 latches.** Managed by `dont_touch` — CTS skips them. These are FSM reset latches; functionally correct but not ideal for a DFF-only design.

### Artifacts generated (baseline)

| Artifact | Path (server) |
|---|---|
| Post-route netlist | `./GDS/GCN_1400.apr.v` |
| PG netlist (for LVS) | `./GDS/GCN_1400.apr_pg.v` |
| SPEF | `./GDS/GCN_1400.spef` |
| GDSII | `./GDS/GCN_1400.gds` |
| Final checkpoint | `./checkpoints/GCN_1400.final.enc` |
| Setup timing summary | `reports/raw/baseline/GCN_postRoute.summary` |
| Hold timing summary | `reports/raw/baseline/GCN_postRoute_hold.summary` |
| Power report | `reports/raw/baseline/power.rpt` |
| Area report | `reports/raw/baseline/area.rpt` |
| Design summary | `reports/raw/baseline/summary.rpt` |
| DRC report | `./reports/drc.rpt` (server-side) |
| Connectivity report | `./reports/connectivity.rpt` (server-side) |

---

## Known Limitations

- Using `22b` synthesis cells with `28`-family Liberty (INVBUF/AO/OA/SIMPLE). These cells share the same `_ASAP7_75t_R` naming and the timing models are compatible for an educational flow, but in a production flow all libraries would be from the same release.
- LVS not run (would require matching SPICE netlists from the `22b` cell set).
- Single-corner TT/0.7V/25C. No SS/FF MMMC.
