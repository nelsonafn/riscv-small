# Verification Status

Traceability and honest status. The specification states the requirement; this file states what proves it.

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.10 |
| Baseline | `doc/spec.md` v0.7.9 (RISC-V ISA v20260120; RISC-V Debug Specification v1.0); `rtl_digest` `sha256:f48ab029...` and `tb_digest` `sha256:ae4e6c79...`; the eleven manifest tests are green at that digest (2026-11-05, WP-6 regression) |
| Implements | [spec.md](spec.md) |

## Tests

| ID | Test | Scope | Status |
|---|---|---|---|
| T-01 | `riscv_small_basic_load_store_test` | LW/SW through the pipeline | implemented |
| T-02 | `riscv_small_corner_test` | corner load/store addresses | implemented |
| T-06 | `riscv_small_subword_access_test` | `LB`/`LBU` at offsets 0-3 and `LH`/`LHU` at offsets 0 and 2 of one word; each loaded register is stored so the value crosses the data port | verified (`FR-12`) |
| T-07 | — | not issued; the ID is retired (T-06 → T-08) | retired |
| T-08 | `riscv_small_sanity_test` | `+HEX`/`+TOHOST`: a bundled `rv32ui-p-*` image runs until it stores to `tohost`; 38/42 pass, triage in `doc/measurements/NFR-05-riscv-tests.md` | implemented (`NFR-05` measured) |
| T-10 | `riscv_small_sanity_test` | `sanity:rv32ui-p-and`; branch-target redirect (`G-27`) and branch operands | implemented (`FR-08`) |
| T-11 | `riscv_small_sanity_test` | `sanity:rv32ui-p-addi`; operand forwarding (`G-26`) | implemented (`FR-16`) |
| T-12 | `riscv_small_sanity_test` | `sanity:rv32ui-p-beq`; signed branch offset (`G-20`) | implemented (`FR-08`) |
| T-13 | `riscv_small_sanity_test` | `sanity:rv32ui-p-sb`; byte lanes and `data_wr_strb` (`G-08`) | implemented (`FR-11`) |
| T-14 | `riscv_small_sanity_test` | `sanity:rv32ui-p-sh`; halfword lane and the `4'b0011` pair (`G-08`) | implemented (`FR-11`) |
| T-15 | `riscv_small_sanity_test` | `sanity:rv32ui-p-st_ld`; store then read back, with `G-30` behind it | implemented (`FR-11`) |
| T-09 | `riscv_small_passive_test` | `is_active=UVM_PASSIVE`: driver and sequencer are absent, the monitor is present; no DUT stimulus | implemented (passive topology) |
| T-03 | CSR and trap test | the `FR-50` map, `misa`, `mepc`/`mcause`/`mtval`, `mscratch`, the reset vector | deferred (`G-13`) |
| T-04 | timer and interrupt test | `mtip`/`meip`/`msip`, `mie`/`mip`/`mstatus`, entry stack, priority | deferred (`G-14`) |
| T-05 | debug test | hart-side run control, abstract commands, program buffer, triggers, single step, the `dbg_auth` strap; needs a Debug Module model | deferred (`G-23`) |

## Traceability

One row per functional requirement of `doc/spec.md` §4. Each row was derived in three passes: read the clause,
locate it in `rtl/`, then ask whether `tb/` observes it. `verified` needs a test that compares a value; `T-01` and `T-06` do, through the reference model/scoreboard
(`LW`/`SW`) and the directed sub-word checks, `T-02` adds no stimulus
(`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), and `T-08` measures `NFR-05` and is the store-data-forwarding evidence (`FR-18`).
`verified` therefore lags `implemented`: the `implemented` rows outside the `LW`/`SW`/sub-word subset wait on `G-04`
(the ISS covers only `LW`/`SW`) or on the remaining sanity failures (`G-07`, `G-15`, `G-30`, `FR-42`). A row is `partial` when the clause
executes but a named gap shows it wrong for part of its domain — four rows, `FR-07`, `FR-17`, `FR-22`
and `FR-41`; the
`deferred` rows keep the status of `doc/spec.md` §4 because the capability is absent, not because the intent is
doubtful.

The `Test` column names the manifest test (`scripts/verify/tests.tsv`) that is evidence for the row; `—` means no
test exercises it yet. That is the same statement as `no test (G-04)` in the evidence column, and it does not by
itself make a row `deferred`: `deferred` is about the capability, not about the test.

| Requirement | Test | Evidence | Status |
|---|---|---|---|
| FR-01 R-type ALU ops | — | `rtl/instruction_decode.sv:323-329`, `rtl/alu.sv:52-92`; no test (`G-04`) | implemented |
| FR-02 immediate ALU ops | `T-11` | `rtl/instruction_decode.sv:309-322`, `rtl/instruction_decode.sv:209-213`, `rtl/riscv_definitions_pkg.sv:276-282`; `T-11` (`rv32ui-p-addi`) covers the ADDI case; the rest of the family still has no named test (`G-04`) | verified |
| FR-03 shift-immediate ops | — | `rtl/instruction_decode.sv:312-318`, `rtl/alu.sv:56-81`; no test (`G-04`) | implemented |
| FR-04 LUI upper immediate | — | `rtl/instruction_decode.sv:248-253`, `rtl/instruction_decode.sv:221-223`; no test (`G-04`) | implemented |
| FR-05 AUIPC PC-relative | — | `rtl/instruction_decode.sv:254-260`, `rtl/alu.sv:53-55`; no test (`G-04`) | implemented |
| FR-06 JAL link and target | — | `rtl/instruction_decode.sv:261-268`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:100-113`; `rv32ui-p-jal` passes but no named test observes the link value (`G-04`) | implemented |
| FR-07 JALR indirect target | — | `rtl/instruction_decode.sv:270-277`, `rtl/jump_decision.sv:103-111`; no test (`G-04`); bit 0 not cleared (`G-07`) | partial |
| FR-08 six conditional branches | `T-12` | `rtl/instruction_decode.sv:279-282`, `rtl/jump_decision.sv:117-164`; `T-12` (`rv32ui-p-beq`) and the six branch images pass; `IALIGN=32` target-alignment arm still owed by `G-06`/`FR-44` | verified |
| FR-09 LW load word | `T-01` | `rtl/instruction_decode.sv:283-296`, `rtl/memory_access.sv:97-99`; `T-01`, `tb/env/top/riscv_small_scoreboard.sv:78-79` | verified |
| FR-10 SW store word | `T-01` | `rtl/instruction_decode.sv:297-308`, `rtl/execution.sv:89-108`, `rtl/riscv_small.sv:195-198`; `T-01`, `tb/env/top/riscv_small_scoreboard.sv:78-79` | verified |
| FR-11 SB and SH lane select | `T-13`, `T-14`, `T-15` | `rtl/execution.sv:191-214` places `rs2` in the addressed lane and drives `data_wr_strb` (`4'b0001 << addr[1:0]` for `SB`, `4'b0011 << {addr[1],1'b0}` for `SH`, `4'b1111` for `SW`); `rtl/riscv_small.sv:119` decodes the width with `access_size(rd_wr_ctrl)` (`rtl/riscv_definitions_pkg.sv:276-283`), so `2'b10` is reachable. `T-13` (`rv32ui-p-sb`), `T-14` (`sh`) and `T-15` (`st_ld`) pass, the mutants `store-lane-offset`/`store-strb-all`/`store-width-cast` are detected, and `riscv_small_strb_checker` asserts strobe↔width coherence in both agent modes. `G-08` closed, `G-22` narrowed to the split (`FR-42`) | verified |
| FR-12 LB LH LBU LHU extend | `T-06` | `rtl/memory_access.sv:68-69` selects the lane from `alu_wb[1:0]`, `:91-105` extends it from `data.u_data` by indexed part-select; `T-06` drives 12 loads (`LB`/`LBU` at 4 offsets, `LH`/`LHU` at 2) and the scoreboard compares the stored value against the ISS | verified |
| FR-13 effective data address | — | `rtl/instruction_decode.sv:209-232`, `rtl/execution.sv:113-152`, `rtl/riscv_small.sv:119`; no test (`G-04`) | implemented |
| FR-14 x0 reads zero | — | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103`; no test (`G-04`) | implemented |
| FR-15 write-read same cycle | — | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85`; no test (`G-04`) | implemented |
| FR-16 arithmetic forwarding | `T-11` | `rtl/control.sv:198-244`, `rtl/execution.sv:113-152`; `T-11` (`rv32ui-p-addi`) and the mutant `forward-rs1`; the `rs2`/distance-2 cells are unexercised (`G-04`) | verified |
| FR-17 load result to consumer | — | `rtl/control.sv:131-154`, `rtl/control.sv:198-244`; `G-19` closed by WP-6 (the register file keeps its own `clk_en_wb`, so a load-use freeze no longer drops a write-back); what remains is `G-30`, the branch decided against an unresolved load (`rv32ui-p-ld_st`, `testnum=2`). No named test of the value itself (`G-04`) | partial |
| FR-18 store data forwarding | `T-08` | `rtl/execution.sv:157-174`, `rtl/control.sv:219-244`; `T-08` (`li gp,1; sw gp,tohost`) and the mutant `sanity-addi` | verified |
| FR-19 branch operand forwarding | — | `rtl/instruction_decode.sv:134-173`, `rtl/control.sv:122-191`; `G-26` closed; no named test builds the 0/1/2-distance matrix (`G-04`) | implemented |
| FR-20 one fetch address per cycle | — | `rtl/instruction_fetch.sv:67`, `rtl/instruction_fetch.sv:96-115`; no test (`G-04`) | implemented |
| FR-21 load waits for data_ready | — | `rtl/control.sv:267-273`; no test (`G-04`) | implemented |
| FR-22 exception discards fetch | — | `rtl/control.sv:256-260`, `rtl/control.sv:277`, `rtl/instruction_fetch.sv:107-109`; no test (`G-04`); vector hardcoded to 1000 (`G-01`) | partial |
| FR-23 mepc and mcause | — | `rtl/control.sv:279-290`; trap state unreadable, no CSR port; no test (`G-01`, `G-02`, `G-13`) | deferred |
| FR-24 illegal-instruction trap | — | `rtl/instruction_decode.sv:238-247`, `rtl/instruction_decode.sv:325`; decode falls through to no-write; no test (`G-06`, `G-13`) | deferred |
| FR-25 ECALL and EBREAK trap | — | `rtl/instruction_decode.sv:333-335`; decoded as no-operation; no test (`G-06`, `G-13`) | deferred |
| FR-26 FENCE ordering | — | `rtl/instruction_decode.sv:330-332`; decoded as no-operation; no test (`G-06`) | deferred |
| FR-27 cache-line fetch burst | — | `rtl/instruction_fetch.sv:67-89`; one word address per cycle, no last-beat signal; no test (`G-15`) | deferred |
| FR-28 hold outstanding fetch | — | `rtl/control.sv:262-265`, `rtl/instruction_fetch.sv:96-115`; PC advances with the grant withheld; no test (`G-09`, `G-15`) | deferred |
| FR-29 mtvec direct mode | — | `rtl/control.sv:277`, `rtl/instruction_decode.sv:333-335`; constant vector, no CSR write; no test (`G-01`, `G-13`) | deferred |
| FR-30 mtvec vectored mode | — | `rtl/control.sv:277`; constant vector, no mode field; no test (`G-01`, `G-14`) | deferred |
| FR-31 fence.i invalidates cache | — | `rtl/instruction_decode.sv:330-335`; no-operation, no cache; no test (`G-06`, `G-15`) | deferred |
| FR-32 mhartid report | — | `rtl/riscv_small.sv:41-57`; no CSR and no hart-identity input; no test (`G-13`, `G-16`) | deferred |
| FR-33 per-hart behaviour | — | `rtl/riscv_small.sv:38-58`; single hart, no hart-count parameter; no test (`G-16`) | deferred |
| FR-34 configuration invariance | — | `rtl/riscv_small.sv:38-58`; no configuration parameters; no test (`G-15`, `G-16`) | deferred |
| FR-35 Zaamo and Zalrsc | — | `rtl/riscv_definitions_pkg.sv:129-187`, `rtl/instruction_decode.sv:323-329`; no A encodings; no test (`G-16`) | deferred |
| FR-36 machine software interrupt | — | `rtl/riscv_small.sv:44`; only the level-sensitive exception input; no test (`G-14`, `G-16`) | deferred |
| FR-37 misa advertises extensions | — | `rtl/instruction_decode.sv:333-335`; no CSR file; no test (`G-13`, `G-16`) | deferred |
| FR-38 store waits for grant | — | `rtl/control.sv:268`; stall also requires a load destination; no test (`G-18`) | deferred |
| FR-39 machine timer interrupt | — | `rtl/riscv_small.sv:44`; no interrupt input and no timer; no test (`G-14`) | deferred |
| FR-40 machine external interrupt | — | `rtl/riscv_small.sv:44`; no external interrupt path; no test (`G-14`) | deferred |
| FR-41 reset behaviour | — | `rtl/instruction_fetch.sv:74` and `rtl/control.sv:279` hardcode `or negedge rst_n`; there is no de-assertion synchroniser and no reset-style macro in `rtl/` (`G-21`); no test (`G-04`) | partial |
| FR-42 misaligned split | — | `rtl/riscv_small.sv:120` issues one access per instruction from `alu_ma`; there is no second beat, no address increment and no strobe recomputation (`G-22`); no test (`G-04`) | deferred |
| FR-43 `M` extension | — | `rtl/instruction_decode.sv:323-329` ignores every function bit but bit 5, so the `M` group aliases onto the base ALU (`G-06`); no test (`G-04`) | deferred |
| FR-44 `C` and `IALIGN=16` | — | `rtl/instruction_decode.sv:45` takes a 32-bit `inst` and `:247` decodes on the opcode field, so no 16-bit parcel is formed and a 32-bit instruction spanning two fetched words is not assembled (`G-06`); no test (`G-04`) | deferred |
| FR-45 `MRET` | — | `rtl/instruction_decode.sv:333-335` decodes the SYSTEM group as a no-operation; there is no `MRET` decode and no `mepc`/`mstatus` (`G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-46 `WFI` | — | `rtl/instruction_decode.sv:333-335` decodes the whole SYSTEM group as a no-operation, so `WFI` currently retires as a legal no-op by accident; there is no `mstatus.TW` and no CSR file, which is what the row still needs (`G-13`); no test (`G-04`) | deferred |
| FR-47 `Zicsr` instructions | — | `rtl/instruction_decode.sv:333-335` decodes CSR encodings as a no-operation; no CSR file and no CSR port (`G-13`); no test (`G-04`) | deferred |
| FR-48 interrupt entry and priority | — | `rtl/control.sv:277-290` hardcodes the trap vector and ties the cause to zero; there is no `mstatus`/`mie`/`mip` and no interrupt input (`G-01`, `G-02`, `G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-49 `Zicntr` | — | no CSR port and no CSR instruction, so `cycle`/`time`/`instret` are unreachable (`rtl/instruction_decode.sv:333-335`, `G-13`); no test (`G-04`) | deferred |
| FR-50 CSR file and map | — | no CSR file and no `CSR*` decoding: the whole SYSTEM opcode group is a no-operation (`rtl/instruction_decode.sv:333-335`) and the top has no CSR read or write port (`rtl/riscv_small.sv:41-57`) (`G-13`); no test (`G-04`) | deferred |
| FR-51 `mscratch` | — | no CSR file and no `CSR*` decoding (`rtl/instruction_decode.sv:333-335`, `rtl/riscv_small.sv:41-57`), so 0x340 is unreachable (`G-13`); no test (`G-04`) | deferred |
| FR-52 `mtval` | — | no CSR file and no `CSR*` decoding (`rtl/instruction_decode.sv:333-335`), and the cause the trap logic registers is tied to zero (`rtl/control.sv:279-290`) (`G-13`); no test (`G-04`) | deferred |
| FR-53 debug mode | — | the top has no debug port (`rtl/riscv_small.sv:41-57`), no debug mode and no `dcsr`/`dpc`/`dscratch`; the SYSTEM group is a no-operation (`rtl/instruction_decode.sv:333-335`) (`G-23`); no test (`G-04`) | deferred |
| FR-54 run control | — | no `dbg_*` port on the DUT (`rtl/riscv_small.sv:41-57`) and no debug state to control (`G-23`); no test (`G-04`) | deferred |
| FR-55 abstract commands | — | no debug port, no CSR file and no command channel (`rtl/riscv_small.sv:41-57`, `rtl/instruction_decode.sv:333-335`) (`G-23`); no test (`G-04`) | deferred |
| FR-56 program buffer | — | the fetch path takes instructions only from the instruction-memory port (`rtl/instruction_fetch.sv`), so a second instruction source does not exist (`G-23`); no test (`G-04`) | deferred |
| FR-57 `Sdtrig` triggers | — | no trigger unit and no `tselect`/`tdata`/`tinfo` decoding (`rtl/instruction_decode.sv:333-335`) (`G-24`); no test (`G-04`) | deferred |
| FR-58 single step | — | no debug mode to re-enter (`G-23`); no test (`G-04`) | deferred |
| FR-59 `dbg_auth` strap | — | no debug port, so there is nothing for the strap to gate (`rtl/riscv_small.sv:41-57`) (`G-23`); no test (`G-04`) | deferred |

## Coverage bins

`A-09`/`Q-11` fix the functional-coverage bar: **one bin per instruction that `doc/spec.md` §4.1 says
`rtl/instruction_decode.sv` decodes today, plus one per memory width — 40 bins**. The two no-operation rows of
that table (`FENCE`/`FENCE.I`, and `ECALL`/`EBREAK`/`CSR*`) carry no bin, because the RTL decodes them as
no-operations (`G-06`, `G-13`); a word outside the decoded subset decodes to a sentinel that names no bin, so it
is counted by nothing. The collector is `riscv_small_coverage` (`tb/env/top/riscv_small_coverage.sv`), a
subscriber to the monitor; it never samples the driver, the sequence or the reference model.

Measured 2026-11-05 by `make coverage` over the eleven manifest tests, at RTL `sha256:f48ab029…b9586d` and TB
`sha256:ae4e6c79…8b5764`: **21 of the 40 bar bins** (18 `cp_inst` + 3 `cp_width`), and **31 of the 50 bins** in
the whole report — `cp_lane`, `cp_dir` and `cp_subword_lane` are the other ten, evidence that predates the bar.
31/50 is the report sum and 21/40 is the bar; neither is a closure claim.

Two limits apply to every row. A hit is a **fetch**, not a retire: `if_id_flush` (`rtl/control.sv:246-258`)
discards an instruction the monitor has already published, so a bin proves the class was **accepted on the fetch
handshake** (`inst_rd_en && inst_ready`) — it does not prove it entered IF/ID, and it does not prove it retired
(`G-28`, `E3`). And a hit verifies no `FR` on its own — the reference model still covers only `LW`/`SW` (`G-04`),
so the `FR` column says what a bin *could* witness, never that the requirement is `verified`. The `Expected
witness` column is an expectation; the measurement and the `2026-11-05` column decide. A bin listed `open` names
the epic that owes the stimulus — `E3` (retire observation) and `E4` (RV32I closure, all 19 open bins)
are the epics of `.opencode/plan/macro-plan-verification-to-signoff.md`.

| Bin | Instruction / width | `FR` it can support | Expected witness | 2026-11-05 |
|---|---|---|---|---|
| `cp_inst.lui` | `LUI` | `FR-04` | `T-08` | hit |
| `cp_inst.auipc` | `AUIPC` | `FR-05` | `T-13` | hit |
| `cp_inst.jal` | `JAL` | `FR-06` | `T-08` | hit |
| `cp_inst.jalr` | `JALR` | `FR-07` | — | open — `E4` |
| `cp_inst.beq` | `BEQ` | `FR-08` | `T-12` | hit |
| `cp_inst.bne` | `BNE` | `FR-08` | `T-08` | hit |
| `cp_inst.blt` | `BLT` | `FR-08` | — | open — `E4` |
| `cp_inst.bge` | `BGE` | `FR-08` | — | open — `E4` |
| `cp_inst.bltu` | `BLTU` | `FR-08` | — | open — `E4` |
| `cp_inst.bgeu` | `BGEU` | `FR-08` | — | open — `E4` |
| `cp_inst.lb` | `LB` | `FR-12` | `T-06` | hit |
| `cp_inst.lh` | `LH` | `FR-12` | `T-06` | hit |
| `cp_inst.lw` | `LW` | `FR-09` | `T-01` | hit |
| `cp_inst.lbu` | `LBU` | `FR-12` | `T-06` | hit |
| `cp_inst.lhu` | `LHU` | `FR-12` | `T-06` | hit |
| `cp_inst.sb` | `SB` | `FR-11` | `T-13` | hit |
| `cp_inst.sh` | `SH` | `FR-11` | `T-14` | hit |
| `cp_inst.sw` | `SW` | `FR-10` | `T-01` | hit |
| `cp_inst.addi` | `ADDI` | `FR-02` | `T-11` | hit |
| `cp_inst.slli` | `SLLI` | `FR-03` | `T-08` | hit |
| `cp_inst.slti` | `SLTI` | `FR-02` | — | open — `E4` |
| `cp_inst.sltiu` | `SLTIU` | `FR-02` | — | open — `E4` |
| `cp_inst.xori` | `XORI` | `FR-02` | — | open — `E4` |
| `cp_inst.srli` | `SRLI` | `FR-03` | — | open — `E4` |
| `cp_inst.srai` | `SRAI` | `FR-03` | — | open — `E4` |
| `cp_inst.ori` | `ORI` | `FR-02` | `T-08` | hit |
| `cp_inst.andi` | `ANDI` | `FR-02` | — | open — `E4` |
| `cp_inst.add` | `ADD` | `FR-01` | `T-01` | hit |
| `cp_inst.sub` | `SUB` | `FR-01` | — | open — `E4` |
| `cp_inst.sll` | `SLL` | `FR-01` | — | open — `E4` |
| `cp_inst.slt` | `SLT` | `FR-01` | — | open — `E4` |
| `cp_inst.sltu` | `SLTU` | `FR-01` | — | open — `E4` |
| `cp_inst.xor_` | `XOR` | `FR-01` | — | open — `E4` |
| `cp_inst.srl` | `SRL` | `FR-01` | — | open — `E4` |
| `cp_inst.sra` | `SRA` | `FR-01` | — | open — `E4` |
| `cp_inst.or_` | `OR` | `FR-01` | — | open — `E4` |
| `cp_inst.and_` | `AND` | `FR-01` | `T-10` | hit |
| `cp_width.byte_w` | byte access | `FR-11`, `FR-12` | `T-06` | hit |
| `cp_width.half_w` | halfword access | `FR-11`, `FR-12` | `T-06` | hit |
| `cp_width.word_w` | word access | `FR-09`, `FR-10` | `T-01` | hit |

Three bin names carry a trailing underscore (`and_`, `or_`, `xor_`) because `and`, `or` and `xor` are
SystemVerilog reserved words and an escaped identifier makes `xcrg` print the backslash, which is not valid
JSON in `build/cov_report/summary.json`. They are the only names that differ from the mnemonic.

The bar is executable, not prose: `make coverage COVERAGE_ARGS="--require-bins cp_inst.addi,cp_inst.sb"`
distinguishes a bin **absent from the report** (the covergroup never declared it) from a bin **present with zero
hits** (declared, unstimulated). That is how a work package proves it moved a bin rather than a percentage.

## Signoff gate

`A-09` and `Q-11` fix the bar; `cmake -P scripts/verify/signoff_check.cmake` turns it into an exit code. The target is declared
in `CMakeLists.txt` §12, so `make signoff-check` and `make -C build signoff-check` are the same command. It writes
`build/signoff/report.md`; `make signoff-check SIGNOFF_ARGS="--wp <n>"` runs the work-package subset (checks 1-5,
7 and 11). Check 11 is what makes the work-package gate test-first rather than pass-only, and it is reproducible: every
test with `red = mutant:<name>` is rebuilt against the defect named by the `<name>` row of `scripts/verify/mutants.tsv`
(a disposable copy under `build/mutants/<T-id>/`, patched once by `riscv_patch_once()`) and must fail there. A stored red log is never used, so `rm -rf build` does not
destroy the evidence.

The tests run under CTest: `CMakeLists.txt` §12 declares one CTest test per line of `scripts/verify/tests.tsv`, with
the timeout and the `wp`/requirement labels. The verdict comes from the `UVM_RESULT: PASS` line the testbench
prints, because `xsim` exits `0` even when the run ends with `UVM_ERROR`s.

| # | Check | Fails when | 2026-11-05 |
|---|---|---|---|
| 1 | `make docs-check`, `make docs-figs-check` | exit != 0 | ok |
| 2 | `spec.md` x this file: same FR set, same status | count or status diverge | ok |
| 3 | every `verified` row names a `T-xx` in `scripts/verify/tests.tsv` and a file in `tb/tests/` | ghost test | ok |
| 4 | no open question, no expired `A-xx` | a `Q` open, or an `A-xx` past its due date | ok |
| 5 | latest `build/regress/*/results.json` | `fail`/`timeout` > 0, stale `rtl_digest`, older than 7 days | ok |
| 6 | `build/sanity/summary.json` (`NFR-05`) | absent, not measured, or any image fails | blocked (38/42 pass; `G-07`, `G-15`, `FR-42`, `G-30`) |
| 7 | `build/cov_report/summary.json` (`NFR-06`) | merge absent, no coverpoint, or measured at an older `rtl_digest` | ok (31/50 bins, bar 21/40, `word_w` hit) |
| 8 | `doc/measurements/NFR-01..04-*.md` | a file is missing, has no method or no date | ok (4 files with method and date) |
| 9 | `doc/measurements/NFR-07-*.md` | absent (no synthesis lint flow, `G-05`) | not measurable |
| 10 | `A-09`: every FR `verified` | any FR is not `verified` | blocked (8/59) |
| 11 | negative control: every WP test fails on the mutant it carries | no mutant run, or the test passes on the mutant | ok (T-06, T-08, T-09, T-10, T-11, T-12, T-13, T-14, T-15) |

The work-package gate runs checks 1-5, 7 and 11. Checks 6 and 8-10 are release evidence and are reported as `skipped` in a
WP. Check 7 runs in both modes on purpose: a WP that changes behaviour without re-measuring coverage has no
evidence that its new bins were exercised, and a coverage merge older than the current `rtl_digest` is reported as
stale.

Exit codes: `0` `signoff-ready`, `1` `blocked`, `2` the gate could not run. The gate is **blocked** on 2026-11-05
and must stay blocked: `G-03`, `G-04`, `G-05`, `G-07`, `G-11`, `G-13`, `G-14`, `G-15`, `G-23`, `G-24`, `G-30` and `FR-42`
plus the four `TBD` non-functional targets leave 51 of 59 requirements unverified. A gate that passes here is a broken gate.

Evidence is tied to code by digest, not by commit: `results.json` carries `rtl_digest` and `tb_digest` (sha256 over
the `.sv`/`.svh` content of `rtl/` and `tb/`), because the project forbids automatic commits. A `verified` row whose
test passed at a different digest is not evidence.

## Gaps

Two gaps changed meaning in v0.2: `G-01` and `G-02` now name `mtvec` and `mcause` as their targets, because
the trap vector and the trap cause moved from "unspecified" to "supplied by a CSR" (`D-08`), and `G-09` was
promoted from a doubt about the fetch handshake to the prerequisite for the instruction cache. Six rows are
new: `G-13` to `G-18`.

v0.7 adds `G-23` and `G-24` for the debug subsystem that `FR-53`..`FR-59` require and the RTL does not have.
WP-4 adds `G-25` (store-address forwarding, closed), `G-26` (operand forwarding) and `G-27` (branch-target first
instruction skipped); `G-10` and `G-25` are closed 2026-10-30. WP-4c closes `G-26`, `G-27` and `G-20` on
2026-11-04 and measures `G-19` for the first time. `G-28` is the first row opened against the **verification
environment** rather than the RTL: `Q-43`/`C-16` (2026-11-04) require the reference model to run off the monitor and
to survive in a passive agent, and the core publishes no retire/commit observation, so the only instruction-level
visibility is a fetch that `if_id_flush` can discard. The two consequences — a coverage bin a flushed fetch can
satisfy, and a model fed by the sequence — are one missing signal, owed by `E3`.

The `Owner` and `Target` columns are the commitments of `A-09`, confirmed by the designer on 2026-10-28 under
`Q-12`: the designer owns the spec and ISA gaps, the verification lead owns the DV gaps, and every target is
2026-12-31. They are commitments, not proposals.

| ID | Gap | Impact | Owner | Target |
|---|---|---|---|---|
| G-01 | `trap_addr` is hardcoded to 1000 (`rtl/control.sv:277`); v0.2 sets the target as the `mtvec` CSR with direct and vectored modes (`FR-29`, `FR-30`) | traps always land at the same address, and the vector cannot be changed by software | designer | 2026-12-31 |
| G-02 | `scause` is tied to zero (`rtl/control.sv:287`); v0.2 sets the target as `mcause` per the ratified privileged specification (`FR-23`) | no trap cause reported, so a handler cannot tell a timer tick from an illegal instruction | designer | 2026-12-31 |
| G-03 | Coverage is not closed on the instruction set, though the model now exists: `cg_inst`/`cp_inst` (`tb/env/top/riscv_small_coverage.sv:194-236`) declares one bin per instruction of `spec.md` §4.1 and the monitor samples it on every accepted fetch, WP-5 measured **15 of 37** — **17 of 40** against the `A-09` bar (the section "Coverage bins"). WP-6 took the measurement to **18 of 37** — **21 of 40** against the bar: `cp_inst.sb`, `cp_inst.sh`, `cp_inst.auipc` and `cp_width.word_w` all closed. The 19 open instruction bins are now all `E4` stimulus (`jalr`, four branches, six immediates, eight ALU operations); a hit is a fetch, not a retire (`G-28`, `E3`) | `NFR-06` stays `partial`; `A-09`/`Q-11` require the bar bins to be **hit**, not declared, so this stays a **release blocker** — narrower than before, but not closed | verification lead | 2026-12-31 |
| G-04 | Reference model and scoreboard cover only LW/SW | other opcodes are not checked; the fifteen as-built requirements outside `LW`/`SW` cannot become `verified`, so the `Q-11` bar ("every `FR` row `verified`") cannot be met — a **release blocker** | verification lead | 2026-12-31 |
| G-05 | No timing, area, or power measurement exists | `NFR-01` to `NFR-04` and `NFR-07` cannot be verified; no frequency or part is recorded (`A-08`, `Q-08`) | designer | 2026-12-31 |
| G-06 | Unimplemented encodings execute as no-operations: unknown opcodes and RV32M aliases fall through the decode default (`rtl/instruction_decode.sv:238-247`, `rtl/instruction_decode.sv:325`), `FENCE` is an empty case (`rtl/instruction_decode.sv:330-332`) and `ECALL`/`EBREAK`/CSR are an empty case (`rtl/instruction_decode.sv:333-335`) | no illegal-instruction trap; `FR-24`, `FR-25`, `FR-26` stay `deferred`; `M` and `C` cannot be claimed in phase 1. Since `Q-05` (2026-10-28) every unimplemented encoding must trap, so this is a conformance blocker, not a scope choice; `FR-24`, `FR-25`, `FR-43` and `FR-44` stay `deferred` for lack of the trap; the `FENCE` half is the separate phase-1 row `FR-26`, blocked only by the decoder (`Q-15` was answered on 2026-10-28) | designer | 2026-12-31 |
| G-07 | `JALR` does not clear bit 0 of the target address (`rtl/jump_decision.sv:111`) | non-conformant indirect jump for odd targets; a **release blocker** since `Q-06` (2026-10-28), decided by `FR-07`'s acceptance | designer | 2026-12-31 |
| G-08 | **closed 2026-11-05 by WP-6**: sub-word stores drove one lane whatever `data_addr[1:0]` said, because `data_wr` was `rs2` unshifted (`rtl/execution.sv:157-174` before the fix). The load half was closed earlier by `FR-12`/`T-06`. The store now lane-places the value and asserts `data_wr_strb` (`rtl/execution.sv:191-214`). | closed; `T-13` (`sb`), `T-14` (`sh`) and `T-15` (`st_ld`) pass, and the mutants `store-lane-offset`/`store-strb-all` fail them | designer | closed 2026-11-05 |
| G-09 | No fetch stall exists: while the fetch grant is withheld only the IF/ID registers are flushed (`rtl/control.sv:262-265`) and the program counter keeps advancing unless IF/ID is held (`rtl/instruction_fetch.sv:96-115`) | reframed in v0.2: this is no longer a doubt about the memory contract (`A-03` is retired) but the **prerequisite for the instruction cache**, because a cache miss must be able to hold the program counter for many cycles; `FR-28` is the requirement that closes it | designer | 2026-12-31 |
| G-10 | **closed 2026-10-30 by WP-4**: the sanity flow now compiles each `rv32ui-p-*` with the project environment (`scripts/verify/sanity/`), extracts `tohost` from the ELF and runs it through `riscv_small_sanity_test` with `+HEX`/`+TOHOST`. The testbench has a `$readmemh` memory model. | `NFR-05` is **measured** (38/42 pass); the remaining failures are `G-07`, `G-15`, `G-30` and `FR-42` | verification lead | closed 2026-10-30 |
| G-11 | `T-02` adds no stimulus: `riscv_small_corner_seq::body()` only calls `super.body()` (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), so it repeats `T-01` | no requirement can cite `T-02`; boundary values are untested, so the coverage leg of the `Q-11` bar rests on `T-01` alone — a **release blocker** | verification lead | 2026-12-31 |
| G-12 | The top-level `clk_en` gates only the trap-state registers and `branch_taken_q` (`rtl/riscv_small.sv:225`, `rtl/control.sv:96`, `:284`), while stage enables are generated inside `rtl/control.sv`; the port is described as a global clock enable but does not gate the pipeline | `C-02` is a description of the port, not a promise; integrators cannot pause the core with `clk_en` | designer | 2026-12-31 |
| G-13 | No CSR file and no CSR instruction: `CSR*` is decoded as a no-operation (`rtl/instruction_decode.sv:333-335`) and the trap state registers are unreadable (`rtl/control.sv:279-290`) | `FR-23`, `FR-24`, `FR-25`, `FR-29`, `FR-30`, `FR-32`, `FR-37`, `FR-45` to `FR-47`, `FR-49` to `FR-52`, and `Zicsr`/`Zicntr` in `§7.1`, stay `deferred` | designer | 2026-12-31 |
| G-14 | No machine-mode interrupt subsystem: the only trap request is the level-sensitive `exception` input (`rtl/riscv_small.sv:44`), with no `mip`/`mie`, no timer, and no external controller interface | `FR-39`, `FR-40`, `FR-36`, `FR-48`, and the vectored mode of `FR-30`, stay `deferred`; `D-01`'s preemption cannot be demonstrated | designer | 2026-12-31 |
| G-15 | No instruction cache and no line-based fetch: `rtl/instruction_fetch.sv:67-89` drives one word address per cycle with no burst and no last-beat signal, and neither `ICACHE_BYTES` nor `ICACHE_LINE` exists | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 of the specification is a target, not a description of the RTL; `NFR-02`'s condition cannot be met | designer | 2026-12-31 |
| G-16 | No multi-hart support: the top is a single hart (`rtl/riscv_small.sv:38-58`) with no hart-identity input, no `NUM_HARTS`, no `A` encodings (`rtl/riscv_definitions_pkg.sv:129-187`) and no software interrupt | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; the `MCU_SMP` configuration of §5.2 cannot be built | designer | 2026-12-31 |
| G-17 | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-11` live in `doc/spec.md` §0.1 | decisions are not indexed beside the requirements they justify, and a superseded decision has nowhere to be retired | designer | 2026-12-31 |
| G-18 | Stores do not wait for the data grant: the stall condition at `rtl/control.sv:268` also requires a load destination, so a store asserts its strobe for one cycle whatever `data_ready` does | `FR-38` stays `deferred`; the store contract is the testbench's, which grants every access immediately, so the difference is invisible today | designer | 2026-12-31 |
| G-19 | **closed 2026-11-05 by WP-6**: a load-use insertion cleared `id_ex_clk_en`, which was also the register file's clock enable (`rtl/instruction_decode.sv:195`, `rtl/riscv_small.sv:142`, `rtl/reg_file.sv:99`), so the write-back of a younger instruction was dropped. `instruction_decode` now takes `clk_en_wb` (the global `clk_en`) for `u_reg_file`, and the ID/EX register keeps `id_ex_clk_en`. | closed; before the fix `x4` was written 3 times against 33308 for `x5` in `T-13`, after it 39 against 39 (`build/regress/2026-11-05T17-39-54Z` and `…18-37-01Z`), and `rv32ui-p-lb`/`-lbu` went green | designer | closed 2026-11-05 |
| G-29 | **closed 2026-11-05 by WP-6**: `pc_fetch` was gated by `if_id_clk_en` while the external instruction memory kept answering the held address, so on a load-use release the IF/ID register captured `pc_id` from one address and `inst_id` from another (`0x254` decoded with the word of `0x258`); the fix is `assign inst_addr = clk_en ? pc : pc_fetch;` (`rtl/instruction_fetch.sv:67-71`), which re-requests the address whose word is on the bus during the freeze. | closed; `T-13`/`T-14` green and 11/11 regression, where before the fix they timed out at `pc=0x24c`; the rejected variant, which aligned the pair but dropped `0x254`, is what showed that the request must be held rather than the delay line. | The same defect was **manufacturing a false PASS** in `rv32ui-p-ld_st` (stale PC at `0xa4` → target `0xee4` → `<pass>` → `tohost=1`), which is why that image flipped from pass to fail when this closed | verification lead | closed 2026-11-05 |
| G-30 | A load-use freeze evaluates the branch with the load result unresolved: at `0xa4` in `rv32ui-p-ld_st`, `branch_taken` pulses while `data_ready=0`, and `branch_taken_q` (`rtl/control.sv`) then flushes a valid in-flight fetch (`rtl/control.sv:246-258`); `ma_wb_clk_en` holds the load, not the branch decision. | `rv32ui-p-ld_st` fails with `testnum=2` (`tohost=5`) and is the red for the next WP; `NFR-05` stays `partial`. Found 2026-11-05 by WP-6 once `G-29` stopped masking it | verification lead | 2026-12-31 |
| G-20 | **closed 2026-11-04 by WP-4c**: `rtl/jump_decision.sv:111` added `imm[20:0]`, zero-extending a negative offset; the fix is `base_addr + imm` (the `imm` is already sign-extended by `imm_gen`). | closed; `T-12`/`rv32ui-p-beq`, the branch images and `FR-08` pass | designer | closed 2026-11-04 |
| G-21 | Reset is asynchronous on both edges: every DUT module hardcodes `or negedge rst_n` (`rtl/instruction_fetch.sv:74`, `rtl/control.sv:279`) and there is no de-assertion synchroniser and no `ASYNC_RESET`-style macro selection. `D-09` and `FR-41` require async assertion with a synchronised release | the release edge is asynchronous, so a de-assertion that arrives close to a clock edge can release different registers on different edges; the FPGA synchronous-reset variant cannot be built at all | designer | 2026-12-31 |
| G-22 | **narrowed 2026-11-05 by WP-6 to the misaligned split.** The byte strobes exist: `data_wr_strb[3:0]` is driven from the store lane (`rtl/execution.sv:191-214`, `rtl/riscv_small.sv:58`) and checked by `riscv_small_strb_checker`. What remains is that an access crossing a word boundary is not split: `data_addr` is still `alu_ma` (`rtl/riscv_small.sv:120`), so `FR-42`'s two word-aligned beats are not issued. | the strobe half is closed; the split half keeps `A-05`'s EEI guarantee unmet for a cross-word access (`SH` at an odd address, `SW` off-word), owned by `FR-42` (`E8`) | designer | 2026-12-31 |
| G-23 | No debug subsystem: the DUT has no debug port, no debug mode, no `dcsr`/`dpc`/`dscratch` and no abstract-command or program-buffer path (`rtl/riscv_small.sv:41-57`, `rtl/instruction_decode.sv:333-335`) | `FR-53` to `FR-56`, `FR-58` and `FR-59` stay `deferred`, and `T-05` cannot exist until a Debug Module model is built | designer | 2026-12-31 |
| G-24 | No trigger unit: `tselect`/`tdata1`..`tdata3`/`tinfo` are not decoded and no address or data comparator exists (`rtl/instruction_decode.sv:333-335`) | `FR-57` stays `deferred`; breakpoints and watchpoints cannot be observed in any configuration | designer | 2026-12-31 |
| G-25 | **closed 2026-10-30 by WP-4**: the MA forward block in `rtl/control.sv:228` forced `alu_src2` to the store data, so a store's address became `rs1 + rs2` instead of `rs1 + imm` (`sw gp,tohost` went to `0x1`). The fix gates `alu_src2` on `alu_src2_ex == RS2` and keeps `storage_src` for the store data (`rtl/control.sv:238-241`). | closed; `T-08` and `rv32ui-p-simple` pass | verification lead | closed 2026-10-30 |
| G-26 | **closed 2026-11-04 by WP-4c**: the branch/jump forward mux `jmp_src1`/`jmp_src2` was unconnected (`rtl/riscv_small.sv:152-153`) and `alu_ex`, the EX forward source, was undriven (`rtl/execution.sv:186-190`); the ALU forward itself was functional. | closed; `T-10`/`T-11`, the `add`/`addi`/`and` images and the mutants pass; `FR-16`/`FR-18` verified, `FR-19` implemented | verification lead | closed 2026-11-04 |
| G-27 | **closed 2026-11-04 by WP-4c**: the decoder PC was one instruction ahead of `inst_data` (`pc_id <= pc`) and the redirect had one flush too few; `pc_fetch` (`rtl/instruction_fetch.sv:74-89`) and `branch_taken_q` (`rtl/control.sv:92-99`, `:251-254`) fix it. | closed; `T-10`/`rv32ui-p-and` and the fail-path `testnum` pass; `FR-08` | designer | closed 2026-11-04 |
| G-28 | **No retire/commit observation.** The only instruction-level visibility on the DUT ports is the fetch (`inst_rd_en && inst_ready`, `tb/env/agents/riscv_small_agent/riscv_small_monitor.sv:38-47`); an accepted fetch can still be discarded by `if_id_flush` (`rtl/control.sv:246-258`), so fetch != retire. Opened 2026-11-04 by `Q-43`/`C-16`. | Two consequences, one missing signal: (a) a functional-coverage bin can be satisfied by an instruction the core never executed — WP-5 measures on the fetch and declares the limit; (b) the reference model cannot be driven by the monitor, so it stays fed by `program_port` (`tb/env/top/riscv_small_env.sv:36`, `:86` → `tb/env/ref_model/riscv_small_ref_model.sv:48`), which blocks passive reuse and the Spike seam. Not a release blocker in the `Q-11` sense: it makes the verification weaker than it looks, it does not make a product claim false. | verification lead | 2026-12-31 (`E3`) |

## Notes

- `T-01`, `T-02`, `T-06`, `T-08`, `T-09`, `T-10`, `T-11`, `T-12`, `T-13`, `T-14` and `T-15` are the tests in `scripts/verify/tests.tsv`; `T-03`, `T-04` and `T-05`
  are v0.7 targets with no implementation yet (`G-04`, `G-13`, `G-14`, `G-23`).
- The eleven manifest tests (`T-01`, `T-02`, `T-06`, `T-08`..`T-15`) are green at `rtl_digest` `sha256:f48ab029…` and
  `tb_digest` `sha256:ae4e6c79…` (2026-11-05, the WP-6 regression, `build/regress/2026-11-05T19-24-52Z`): scoreboard
  comparisons on the directed runs, `T-08`/`T-10`/`T-11`/`T-12`/`T-13`/`T-14`/`T-15` `SANITY: PASS`, `T-09` the
  passive topology. `NFR-05` is **measured** at 38/42 (`doc/measurements/NFR-05-riscv-tests.md`), not `verified`.
  `T-02` still repeats `T-01` (`G-11`).
- WP-4c closed `G-27` (branch redirect), `G-26` (branch/jump forward mux and `alu_ex`) and `G-20` (signed branch
  offset); the `T-10`/`T-11`/`T-12` reds and the mutants `branch-redirect`/`forward-rs1`/`negative-branch` are the
  reproducible evidence.
- WP-6 closed `G-08` (store lane and byte strobes, `FR-11`), `G-19` (a load-use freeze no longer drops a
  write-back: the register file has its own `clk_en_wb`) and `G-29` (the IF/ID register captured `pc_id` and
  `inst_id` from different addresses across a stall; `inst_addr` now follows `pc_fetch` while IF/ID is paused).
  It also showed that `rv32ui-p-ld_st` had been passing **falsely** under `G-29`: the stale PC sent the branch to
  `0xee4` instead of `0xee8`, which is the `<pass>` path, and a failing test wrote `tohost=1`. With `G-29` closed
  the image fails honestly under the newly opened `G-30` (a branch decided against an unresolved load), so the
  sanity count went 34 → **38 of 42** while one of the old passes was retired as false. Evidence:
  `T-13`/`T-14`/`T-15` green, `store-lane-offset`/`store-strb-all`/`store-width-cast` mutants, and the traces
  quoted in the `G-19`/`G-29`/`G-30` rows. The four remaining images are `G-07` (`jalr`), `G-15` (`fence_i`),
  `FR-42`/`G-22` (`ma_data`) and `G-30` (`ld_st`); `sb`, `sh` and `st_ld` now pass.
- The sanity harness is UVM-separated (WP-4b): the test reads `+HEX`/`+TOHOST`/`+MAX_CYCLES`/`+TRACE`; the sequence builds the
  program item (`program_addr[]`/`program_data[]`); the driver is a memory BFM and never reads a plusarg, decodes
  `tohost` or raises a verdict error; the monitor publishes fetch **and** data; `riscv_small_sanity_checker` owns
  `SANITY`/`uvm_error`; the test owns the objection and the timeout. The CTest command pins
  `^SANITY: PASS image=<image>$` and the summary rejects a log naming another image (`not_measurable`). The agent honors `is_active` (active =
  driver+sequencer+monitor; passive = monitor only). `drv2rm_port` is gone, but the directed reference model is still
  fed by `program_port` (the sequence, never the driver): that is the deviation `C-16` records and `G-28` names, and
  it is why `T-09` proves the passive *topology* only — a sequence-fed model has nothing to consume there. `T-08`
  exercises the active path.
- `T-09` was red first against the pre-`is_active` TB (`uvm_errors=2`, driver and sequencer built in passive
  mode) and the mutant `passive-agent-always-active` re-proves it at `build/red/T-09/results.json` (`status=fail`,
  `uvm_errors=2`); it is green in the 8/8 regression at TB `sha256:f542affd…` after the `is_active` change.
- The sanity run found `G-25` (store address, fixed), `G-26` (operand forwarding), `G-27` (branch-target first
  instruction skipped) and `G-20` (unsigned branch offset); WP-4c closes the last three, and the 8 remaining
  failures are grouped in `doc/measurements/NFR-05-riscv-tests.md`.
- Functional coverage exists in two covergroups in `tb/env/top/riscv_small_coverage.sv`, both sampled from the
  monitor: `cg_mem` (`cp_width`, `cp_lane`, `cp_dir`, `cp_subword_lane`) and, since WP-5, `cg_inst`/`cp_inst`
  with one bin per instruction of `spec.md` §4.1. The 2026-11-05 WP-6 merge over the eleven manifest tests is
  **31 of 50 report bins**, **21 of 40 against the `A-09` bar** (`cp_inst` 18/37 + `cp_width` 3/3); `cg_mem` is
  **13/13**, and the `xcrg` score, the mean of the two covergroups, is 74.3243 %. The 19 open bins are all `E4`
  stimulus and are listed in "Coverage bins". Evidence:
  `build/cov_report/functionalCoverageReport/xcrg_func_cov_report.txt` at TB `sha256:ae4e6c79…`.
- `T-06` was red first: at `rtl_digest` `sha256:34db4d37…` and `tb_digest` `sha256:47058a92…` it failed 8 of 12
  cases — `LB` and `LBU` at offsets 0, 1 and 2, and `LH`/`LHU` at offset 0 — while `LB`/`LBU` at offset 3 and
  `LH`/`LHU` at offset 2 passed. The old code extended `s_bytes[0]`, and `dataBus_u` declares its byte array as
  `[0:3]`, so index 0 holds bits `[31:24]`: the *highest* byte address always won, which is why the offset-3 cases
  were the ones that survived. That is a stronger red than "nothing works", because a broken harness would fail
  every case. The reproducible proof is the `T-06` mutant (`build/red/T-06/results.json`); the stored run log
  died with `build/`.
- A requirement is `verified` only when a test above exercises it; everything else stays `implemented` or
  `deferred`.
- No test states which configuration of `doc/spec.md` §5.2 it ran in, because no configuration exists yet
  (`G-15`, `G-16`). When parameters land, every regression result must name its configuration (`C-11`).
