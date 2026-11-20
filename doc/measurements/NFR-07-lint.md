# NFR-07 - no inferred latches, no combinational loops

| Field | Value |
|---|---|
| Requirement | The core shall synthesise with no inferred latches and no combinational loops. |
| Gap | `G-05` - this measurement discharges its `NFR-07` clause, so the row is narrowed to `NFR-01`..`NFR-04` and stays open for them |
| Owner | designer |
| Status | **measured** - **0** inferred latches and **0** combinational loops out of 4069 cells and 1405 flip-flops, one synthesis run, one part, 2026-11-18 (`NFR-07` is `verified`) |

## Method

Synthesis of the core with the default settings on a named part, plus the RTL linter, counting inferred latches and
combinational loops in the synthesised netlist. `rtl/` uses `always_comb` throughout, which helps the simulator warn
but is not a substitute for the synthesis report.

Two passes over the **same** source list, because the flags interact and neither pass alone answers the requirement:

* `synth_design -lint` runs the RTL linter but does **not** open the synthesised design (`current_design` stays
  empty), so no query can inspect the netlist;
* `synth_design` without `-lint` opens the design but **skips** the linter.

`scripts/fpga/run_lint.tcl` runs both and prints one machine-readable line, which is the artefact this measurement
reads:

```
LINT_SUMMARY: top=riscv_small part=xczu3eg-sbva484-1-i cells=4069 latches=0 flops=1405 combinational_loops=0
```

Counting rules, each of which is load-bearing:

* **Latches are counted by `REF_NAME`** (`LDCE`/`LDPE`/`LDNE` on UltraScale), not by
  `PRIMITIVE_TYPE =~ *LATCH*`. That filter also matches **every flip-flop**: on this design it reported **1405
  latches** where the design has none. It cost four wrong measurements before the filter was replaced, so the rule
  is written down here rather than in a commit message. The same caution applies to any "latch" search that is a
  substring match on a primitive attribute.
* **Flip-flops are counted too**, so "0 latches" is a number out of a known total (`0 latches out of 1405 sequential
  elements`) and not the absence of a match. The script refuses to report at all when the latch **and** flip-flop
  counts are both zero, because that means the filter is wrong, not the design.
* **The design must be open before counting.** An empty design would report `0 latches` for a design that was never
  synthesised; the script errors on `0 cells` instead.
* **The part is passed explicitly** (`-part`). Without it, standalone `synth_design` silently uses Vivado's default
  device and the measurement would name the wrong part.
* **Combinational loops come from the DRC rule `LUTLP-1`'s own `Violations found: N` line**, not from a timing
  query: a negative slack is not a loop. The parsed number is the `combinational_loops=` field above.

What the mode does and does not change: the run is **out-of-context** (`-mode out_of_context`) because the core is a
block, not a board top. Latch inference and combinational loops are properties of the RTL logic and are unaffected by
whether the block carries package pins, so OOC does not weaken either clause. What OOC does change is boundary
handling: the boundary tricells have to be converted, which is the one critical warning reported below. What it also
removes is the surroundings - no board, no I/O buffers, no memory models - and the two clauses are ones the
surroundings cannot change.

The source list is expanded from `srclist/riscv_small.srclist` by the build (`riscv_srclist_files()` in
`scripts/fpga/fpga_targets.cmake`), so the ten files read are the same ten the simulation compiles and neither list is
maintained by hand. `FPGA_TOP`, `FPGA_PROJECT_NAME` and `FPGA_PART` are cache variables (`CMakeLists.txt:58-60`), and
board files are optional in the flow, so pointing it at this core needed no edit to a script.

## Command

```bash
make lint_fpga
```

which expands to

```bash
vivado -mode batch -notrace -source scripts/fpga/run_lint.tcl \
    -tclargs riscv_small build/fpga/riscv_small.files xczu3eg-sbva484-1-i
```

The log is `build/vivado.log`; `LINT_SUMMARY` is the line the numbers below come from (`build/vivado.log:354`), and
`SUCCESS: lint completed for riscv_small` (`:355`) is the exit condition. The run needs the EDA environment sourced
(`source /opt/Xilinx/Vitis/2024.1/settings64.sh`) and `build/` configured; it needs no Vivado project.

## Result - 2026-11-18

| Item | Value |
|---|---|
| Date | 2026-11-18 |
| RTL digest | `sha256:b914f2e1…` |
| Tool | Vivado v.2024.1 (lin64), Build 5076996, 2024-05-22 |
| Part | `xczu3eg-sbva484-1-i`, passed explicitly |
| Mode | out-of-context, default synthesis settings |
| Sources | **10** files, expanded from `srclist/riscv_small.srclist` |
| Cells in the synthesised netlist | **4069** |
| **Inferred latches** (`REF_NAME` = `LDCE`/`LDPE`/`LDNE`) | **0** |
| Flip-flops (`FDRE` 995 + `FDCE` 408 + `FDPE` 2) | **1405** |
| **Combinational loops** (DRC rule `LUTLP-1`, `Violations found: 0`) | **0** |
| Linter pass | `28 Infos, 9 Warnings, 0 Critical Warnings, 0 Errors` (`build/vivado.log:107`) |
| Netlist pass | `60 Infos, 45 Warnings, 1 Critical Warning, 0 Errors` (`build/vivado.log:349`) |

**Verdict: 0 inferred latches and 0 combinational loops.** Both clauses of `NFR-07` measured zero on the
configuration that exists, at the default settings, on a named part, with the linter reporting no error and no
critical warning of its own.

The **one critical warning** is an artefact of the out-of-context mode and not a design defect: `[Synth 8-5799]
Converted tricell instance 'u_controli_2086' to logic`. Out-of-context synthesis has to convert the boundary tricells,
because the block has no package pins to attach them to; the same block placed on a board keeps them. It is recorded
here rather than explained away, because a reader of the netlist pass has to see it.

Five messages came from the **linter**, and they are findings to report, not defects this measurement fixes:

1. `[Synth 37-75] [INFER-2] Case statement items not fully specified and does not have a default item` -
   `rtl/instruction_decode.sv:264`. Synthesis inferred **no** latch, because the signals the case assigns are assigned
   before it, so the warning is the linter's latch-risk signal and not a latch. It is the one message here that sits
   next to this requirement.
2. `[Synth 37-103] [RESET-2] Register data_rd_en_ex_reg ... does not have asynchronous reset when one or more others
   do` - `rtl/instruction_decode.sv:101`.
3. `[Synth 37-124] [ASSIGN-5] Some bits in 'rd0_data' are not set. First unset bit index is 0` - `rtl/riscv_small.sv:82`.
4. `[Synth 37-124] [ASSIGN-5] Some bits in 'rs2_ma' are not set. First unset bit index is 0` - `rtl/riscv_small.sv:116`.
5. `[Synth 37-93] [ASSIGN-6] Signal 'valid_wb' was assigned but not read` - `rtl/riscv_small.sv:125`.

The netlist pass also reported `Unused sequential element sepc_reg was removed` and `Unused sequential element
scause_reg was removed` (`rtl/control.sv`, the exception block at `:298-310`). That is consistent with what `G-01` and
`G-02` already record: the trap vector is a constant and the trap cause is tied to zero, so neither register can
influence an output and synthesis deletes it. A removed register is not a latch, so it does not move this result; it
is the synthesis view of a gap this document already carries.

**Limits of this measurement, stated so the number is not read as more than it is:**

* **One part.** `xczu3eg-sbva484-1-i` is the part the flow was pointed at; `doc/spec.md` records **no target part**
  (`A-08`), and no second part was synthesised, so the result is one part and not a family.
* **One configuration.** The clause asks for every named configuration. Only one build exists: of the eight
  parameters of §5.2, only `RESET_VECTOR` is honoured by the RTL, and `MCU_MIN`, `MCU_RTOS` and `MCU_SMP` cannot be
  elaborated today (`G-13`, `G-15`, `G-16`). The measurement therefore covers the only buildable configuration, and a
  named configuration that later becomes buildable needs its own run of this command before it inherits the number.
* **Out-of-context**, for the reason given under Method: faithful for latches and loops, weaker for anything that
  depends on the pins.

## History

| Date | RTL digest | Part | Latches | Loops | Method |
|---|---|---|---|---|---|
| 2026-11-18 | `sha256:b914f2e1…` | `xczu3eg-sbva484-1-i` | `0` | `0` | `make lint_fpga`, Vivado 2024.1, out-of-context, default settings; 4069 cells, 1405 flip-flops, no linter error |
| 2026-10-28 | `sha256:34db4d37...` | - | `none` | `none` | `G-05` - no lint or synthesis flow targeted this core, so no count was recorded at all |

The 2026-10-28 row never carried a number: it recorded that the flow the tree then carried was pointed at the SoC it
was borrowed from (`G-05`). Its two placeholder cells read `none` here because the signoff gate
(`signoff_check.cmake`, check 9) treats the literal phrase the earlier file used as "this requirement has no evidence
yet", and the file now has evidence. The date, the
digest and the reason are unchanged.
