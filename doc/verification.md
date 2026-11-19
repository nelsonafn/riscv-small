# Verification Status

Traceability and honest status. The specification states the requirement; this file states what proves it.

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.12 |
| Baseline | `doc/spec.md` v0.8.5 (RISC-V ISA v20260120; RISC-V Debug Specification v1.0); `rtl_digest` `sha256:b914f2e1...` and `tb_digest` `sha256:066dce85...`; the 46 manifest tests are green at that digest (2026-11-18, WP-11 regression) |
| Implements | [spec.md](spec.md) |

## Tests

| ID | Test | Scope | Status |
|---|---|---|---|
| T-01 | `riscv_small_basic_load_store_test` | LW/SW through the pipeline | implemented |
| T-02 | `riscv_small_corner_test` | corner load/store addresses | implemented |
| T-06 | `riscv_small_subword_access_test` | `LB`/`LBU` at offsets 0-3 and `LH`/`LHU` at offsets 0 and 2 of one word; each loaded register is stored so the value crosses the data port | verified (`FR-12`) |
| T-07 | — | not issued; the ID is retired (T-06 → T-08) | retired |
| T-08 | `riscv_small_sanity_test` | `+HEX`/`+TOHOST`: a bundled `rv32ui-p-*` image runs until it stores to `tohost`; 41 of the 42 bundled images pass (42 of 43 runs, the extra being the project-local `jalr_unaligned`), triage in `doc/measurements/NFR-05-riscv-tests.md` | verified (`NFR-05` measured) |
| T-10 | `riscv_small_sanity_test` | `sanity:rv32ui-p-and`; branch-target redirect (`G-27`) and branch operands | verified (`FR-08`) |
| T-11 | `riscv_small_sanity_test` | `sanity:rv32ui-p-addi`; operand forwarding (`G-26`) | verified (`FR-16`) |
| T-12 | `riscv_small_sanity_test` | `sanity:rv32ui-p-beq`; signed branch offset (`G-20`) | verified (`FR-08`) |
| T-13 | `riscv_small_sanity_test` | `sanity:rv32ui-p-sb`; byte lanes and `data_wr_strb` (`G-08`) | verified (`FR-11`) |
| T-14 | `riscv_small_sanity_test` | `sanity:rv32ui-p-sh`; halfword lane and the `4'b0011` pair (`G-08`) | verified (`FR-11`) |
| T-15 | `riscv_small_sanity_test` | `sanity:rv32ui-p-st_ld`; store then read back, with `G-30` behind it | verified (`FR-11`) |
| T-16 | `riscv_small_sanity_test` | `sanity:rv32ui-p-ld_st`; the branch decided against an unresolved load (`G-30`) | verified (`FR-17`) |
| T-17 | `riscv_small_sanity_test` | `sanity:rv32ui-p-jalr`; the indirect target and its `rs1` forwarding (`G-07`, `G-31`) | partial (`FR-07`) |
| T-18 | `riscv_small_sanity_test` | `sanity:rv32ui-p-jal`; link value and target | verified (`FR-06`) |
| T-19..T-22 | `riscv_small_sanity_test` | `sanity:rv32ui-p-blt`/`-bge`/`-bltu`/`-bgeu`; the four signed/unsigned branch conditions | verified (`FR-08`) |
| T-23..T-25, T-28 | `riscv_small_sanity_test` | `sanity:rv32ui-p-slti`/`-sltiu`/`-xori`/`-andi`; the four remaining immediates | verified (`FR-02`) |
| T-26, T-27 | `riscv_small_sanity_test` | `sanity:rv32ui-p-srli`/`-srai`; the logical/arithmetic shift pair | verified (`FR-03`) |
| T-29..T-36 | `riscv_small_sanity_test` | `sanity:rv32ui-p-sub`/`-sll`/`-slt`/`-sltu`/`-xor`/`-srl`/`-sra`/`-or`; the eight remaining R-type operations | verified (`FR-01`) |
| T-37 | `riscv_small_sanity_test` | `sanity:rv32ui-p-jalr_unaligned`; a **project-local** image (`scripts/verify/sanity/local/`) with an odd `JALR` target — the only test of `FR-07`'s bit-0 mask | partial (`FR-07`) |
| T-38 | `riscv_small_sanity_test` | `sanity:rv32ui-p-bne`; the sixth branch condition | verified (`FR-08`) |
| T-39 | `riscv_small_sanity_test` | `sanity:rv32ui-p-ori` | verified (`FR-02`) |
| T-40 | `riscv_small_sanity_test` | `sanity:rv32ui-p-slli` | verified (`FR-03`) |
| T-41 | `riscv_small_sanity_test` | `sanity:rv32ui-p-lui` | verified (`FR-04`) |
| T-42 | `riscv_small_sanity_test` | `sanity:rv32ui-p-auipc` | verified (`FR-05`) |
| T-43 | `riscv_small_sanity_test` | `sanity:rv32ui-p-add`; the `ADD` result, which `T-01` only issued as a NOP | verified (`FR-01`) |
| T-44 | `riscv_small_monitor_model_test` | the model runs off the monitor only, no program port; 72 commits for 72 instructions | implemented (WP-8; `G-28` closed) |
| T-45 | `riscv_small_branch_model_test` | a taken branch: 10 commits for 12 fetches, the two skipped `pc` never retire | implemented (WP-8; `G-28` closed) |
| T-46 | `riscv_small_skip3_model_test` | a taken branch that skips 3 instructions (`0x08` -> `0x18`, 12 words placed, 9 executed, 3 skipped): 9 commits for 11 fetches; proves the front end discards a fixed 2 words and the checker's claim 6 is a per-pc set (`RETIRE_FETCH_LOST`), claim 7 gated | implemented (WP-9; `G-28`) |
| T-47 | `riscv_small_sanity_test` | `spike:rv32ui-p-add`; commit trace (`+RETIRE_LOG`) compared instruction by instruction against Spike (`--log-commits`): 459/459 commits cut at `0x8000057c`; mutant `alu-ignore-rs2` | implemented (WP-9; `G-04` narrowed) |
| T-48 | `riscv_small_sanity_test` | `spike:rv32ui-p-beq`; commit trace compared against Spike: 285/285 commits cut at `0x8000035c`; mutant `negative-branch` | implemented (WP-9; `G-04` narrowed) |
| T-49 | `riscv_small_sanity_test` | `spike:rv32ui-p-st_ld`; commit trace compared against Spike: 477/477 commits cut at `0x80000784`; mutant `store-lane-offset` | implemented (WP-9; `G-04` narrowed) |
| T-50 | `riscv_small_reset_vector_test` | the first fetch after reset, observed by `riscv_small_reset_checker` and compared with the elaborated `RESET_VECTOR` (default `0x80000000`); mutant `reset-vector-zero` | implemented (WP-11; `G-33` closed) |
| T-09 | `riscv_small_passive_test` | `is_active=UVM_PASSIVE`: driver and sequencer are absent, the monitor is present; no DUT stimulus | implemented (passive topology) |
| T-03 | CSR and trap test | the `FR-50` map, `misa`, `mepc`/`mcause`/`mtval`, `mscratch`; its reset-vector clause is observed by `T-50` (WP-11), so this test is not that evidence | deferred (`G-13`) |
| T-04 | timer and interrupt test | `mtip`/`meip`/`msip`, `mie`/`mip`/`mstatus`, entry stack, priority | deferred (`G-14`) |
| T-05 | debug test | hart-side run control, abstract commands, program buffer, triggers, single step, the `dbg_auth` strap; needs a Debug Module model | deferred (`G-23`) |

## Traceability

One row per functional requirement of `doc/spec.md` §4. Each row was derived in three passes: read the clause,
locate it in `rtl/`, then ask whether `tb/` observes it. `verified` needs a test that compares a value; `T-01` and `T-06` do, through the reference model/scoreboard
(`LW`/`SW`) and the directed sub-word checks, `T-02` adds no stimulus
(`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), and `T-08` measures `NFR-05` and is the store-data-forwarding evidence (`FR-18`).
`verified` therefore lags `implemented`: the `implemented` rows outside the `LW`/`SW`/sub-word subset wait on `G-04`
(the in-testbench model executes the load/store subset and publishes only `SW` predictions, while the WP-9 Spike commit-trace comparison covers three images and omits store address/data, `x0` writes and bus-protocol properties) or on the one remaining sanity failure (`FR-42`). A row is `partial` when the clause
executes but a named gap shows it wrong for part of its domain — three rows, `FR-07`, `FR-22`
and `FR-41`; the
`deferred` rows keep the status of `doc/spec.md` §4 because the capability is absent, not because the intent is
doubtful.

The `Test` column names the manifest test (`scripts/verify/tests.tsv`) that is evidence for the row; `—` means no
test exercises it yet. That is the same statement as `no test (G-04)` in the evidence column, and it does not by
itself make a row `deferred`: `deferred` is about the capability, not about the test.

| Requirement | Test | Evidence | Status |
|---|---|---|---|
| FR-01 R-type ALU ops | `T-43`, `T-10`, `T-29`..`T-36`, `T-47` | `rtl/instruction_decode.sv:341-347`, `rtl/alu.sv:52-92`; every operation of the family has an image that reads its result: `ADD` `T-43` (and `T-47`, 459/459 committed instructions compared against Spike), `AND` `T-10`, `SUB` `T-29`, `SLL` `T-30`, `SLT` `T-31`, `SLTU` `T-32`, `XOR` `T-33`, `SRL` `T-34`, `SRA` `T-35`, `OR` `T-36`; each fails on a mutant — `alu-ignore-rs2` for nine of them and `alu-or-to-and`/`shift-left-zero` where they apply; `AND`'s isolating proof is `rv32ui-p-and`'s own self-check, because `T-10`'s manifest mutant is `branch-redirect` | verified |
| FR-02 immediate ALU ops | `T-11`, `T-23`..`T-25`, `T-28`, `T-39` | `rtl/instruction_decode.sv:327-340`, `rtl/instruction_decode.sv:225-229`, `rtl/riscv_definitions_pkg.sv:276-282`; `ADDI` `T-11`, `SLTI` `T-23`, `SLTIU` `T-24`, `XORI` `T-25`, `ANDI` `T-28`, `ORI` `T-39`; each fails on its mutant (`imm-zero` for the first five, `alu-or-to-and` for `ori`) | verified |
| FR-03 shift-immediate ops | `T-26`, `T-27`, `T-40` | `rtl/instruction_decode.sv:330-336`, `rtl/alu.sv:56-81`; `SRLI` `T-26`, `SRAI` `T-27`, `SLLI` `T-40`; mutants `imm-zero` and `shift-left-zero` | verified |
| FR-04 LUI upper immediate | `T-41` | `rtl/instruction_decode.sv:265-270`, `rtl/instruction_decode.sv:237-239`; `T-41` (`rv32ui-p-lui`) reads the upper immediate back; mutant `lui-ignores-imm` | verified |
| FR-05 AUIPC PC-relative | `T-42` | `rtl/instruction_decode.sv:271-277`, `rtl/alu.sv:53-55`; `T-42` (`rv32ui-p-auipc`) reads the pc-relative value back; mutant `auipc-no-pc` | verified |
| FR-06 JAL link and target | `T-18` | `rtl/instruction_decode.sv:278-285`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:108-127`; `T-18` (`rv32ui-p-jal`) checks the link value and the target; mutant `jal-offset-zero` | verified |
| FR-07 JALR indirect target | `T-17`, `T-37` | `rtl/instruction_decode.sv:287-295`, `rtl/jump_decision.sv:115-116` clears bit 0 when `base_addr_sel == RS1`, and `rtl/control.sv:135` forwards `rs1` for `cond_jump \|\| jalr` (`G-31`, closed 2026-11-05). `T-17` (`rv32ui-p-jalr`) and `T-37` (`rv32ui-p-jalr_unaligned`, an **odd** target — the only test of the mask) pass, and mutants `jalr-no-forward`/`jalr-keep-bit0` fail them. **`partial`:** the second clause of the acceptance — a target whose bit 1 is set must raise instruction-address-misaligned (cause 0) — has no implementation, because there is no trap path (`G-13`, epic `E6`); the core would fetch the unaligned word. Designer decision of 2026-11-05: the requirement stands as written, so the row does not promote | partial |
| FR-08 six conditional branches | `T-10`, `T-12`, `T-19`..`T-22`, `T-38`, `T-48` | `rtl/instruction_decode.sv:297-300`, `rtl/jump_decision.sv:117-164`; `BEQ` `T-10`/`T-12` (and `T-48`, 285/285 committed instructions compared against Spike), `BNE` `T-38`, `BLT` `T-19`, `BGE` `T-20`, `BLTU` `T-21`, `BGEU` `T-22`; mutants `branch-redirect`/`negative-branch`/`branch-always-taken`. `IALIGN=32` target-alignment arm still owed by `G-06`/`FR-44` | verified |
| FR-09 LW load word | `T-01`, `T-44`..`T-46`, `T-49` | `rtl/instruction_decode.sv:301-314`, `rtl/memory_access.sv:109-111`; `T-01` (`tb/env/top/riscv_small_scoreboard.sv:102-105`), `T-44`..`T-46` (retire-fed model), and `T-49` (`st_ld` commit trace 477/477 against Spike) | verified |
| FR-10 SW store word | `T-01`, `T-44`..`T-46`, `T-49` | `rtl/instruction_decode.sv:315-326`, `rtl/execution.sv:101-128`, `rtl/riscv_small.sv:223-224`; `T-01` (`tb/env/top/riscv_small_scoreboard.sv:102-105`), `T-44`..`T-46` (retire-fed model), and `T-49` (`st_ld` commit trace 477/477 against Spike; store address/data stay on the ISS scoreboard) | verified |
| FR-11 SB and SH lane select | `T-13`, `T-14`, `T-15`, `T-49` | `rtl/execution.sv:202-225` places `rs2` in the addressed lane and drives `data_wr_strb` (`4'b0001 << addr[1:0]` for `SB`, `4'b0011 << {addr[1],1'b0}` for `SH`, `4'b1111` for `SW`); `rtl/riscv_small.sv:133` decodes the width with `access_size(rd_wr_ctrl)` (`rtl/riscv_definitions_pkg.sv:276-283`), so `2'b10` is reachable. `T-13` (`rv32ui-p-sb`), `T-14` (`sh`), `T-15` (`st_ld`) and `T-49` (`spike:rv32ui-p-st_ld`, 477/477 commits against Spike) pass, the mutants `store-lane-offset`/`store-strb-all`/`store-width-cast` are detected, and `riscv_small_strb_checker` asserts strobe↔width coherence in both agent modes. `G-08` closed, `G-22` narrowed to the split (`FR-42`) | verified |
| FR-12 LB LH LBU LHU extend | `T-06`, `T-49` | `rtl/memory_access.sv:74-75` selects the lane from `alu_wb[1:0]`, `:103-117` extends it from `data.u_data` by indexed part-select; `T-06` drives 12 loads (`LB`/`LBU` at 4 offsets, `LH`/`LHU` at 2) and the scoreboard compares the stored value against the ISS; `T-49` compares 477 committed instructions against Spike, 49 of which are loads (13 `LB`, 6 `LBU`, 12 `LH`, 6 `LHU`, 12 `LW`), so their register values are checked instruction by instruction | verified |
| FR-13 effective data address | — | `rtl/instruction_decode.sv:225-248`, `rtl/execution.sv:133-172`, `rtl/riscv_small.sv:134`; no test (`G-04`). The WP-9 trace comparison cannot serve: the canonical line omits store address/data, so `-2048`/`+2047` on the data port are unobservable there | implemented |
| FR-14 x0 reads zero | — | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103`; no test (`G-04`). The WP-9 dump suppresses `rd`/value when the destination is `x0`, so a spurious `x0` write is invisible in the trace | implemented |
| FR-15 write-read same cycle | — | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85`; no test (`G-04`). Observable in principle through the WP-9 trace (a wrong read would diverge), but no test builds the back-to-back pair as its subject | implemented |
| FR-16 arithmetic forwarding | `T-11` | `rtl/control.sv:215-263`, `rtl/execution.sv:133-172`; `T-11` (`rv32ui-p-addi`) and the mutant `forward-rs1`; the `rs2`/distance-2 cells are unexercised (`G-04`) | verified |
| FR-17 load result to consumer | `T-16` | `rtl/control.sv:135-168`, `rtl/control.sv:215-263`; both gaps that kept it `partial` are closed — `G-19` by WP-6 (the register file keeps its own `clk_en_wb`) and `G-30` by WP-7 (`branch_op_stall` suppresses a redirect decided against an unresolved load). `T-16` (`rv32ui-p-ld_st`) is the image whose dependent branch failed on the stale value; mutant `branch-taken-stale` | verified |
| FR-18 store data forwarding | `T-08` | `rtl/execution.sv:177-194`, `rtl/control.sv:237-263`; `T-08` (`li gp,1; sw gp,tohost`) and the mutant `sanity-addi` | verified |
| FR-19 branch operand forwarding | `T-48` | `rtl/instruction_decode.sv:143-182`, `rtl/control.sv:122-191`; `G-26` closed. `T-48` (`spike:rv32ui-p-beq`, 285/285 commits against Spike) corroborates that branch decisions match an independent ISS, but it does not build the 0/1/2-distance matrix the acceptance asks for (`G-04`) | implemented |
| FR-20 one fetch address per cycle | — | `rtl/instruction_fetch.sv:76`, `rtl/instruction_fetch.sv:108-127`; no test (`G-04`). A fetch-port protocol property, never visible in a commit trace | implemented |
| FR-21 load waits for data_ready | — | `rtl/control.sv:287-293`; no test (`G-04`). A handshake property, never visible in a commit trace | implemented |
| FR-22 exception discards fetch | — | `rtl/control.sv:276-279`, `rtl/instruction_fetch.sv:119-121`; no test (`G-04`); vector hardcoded to 1000 (`G-01`) | partial |
| FR-23 mepc and mcause | — | `rtl/control.sv:299-311`; trap state unreadable, no CSR port; no test (`G-01`, `G-02`, `G-13`) | deferred |
| FR-24 illegal-instruction trap | — | `rtl/instruction_decode.sv:254-263`, `rtl/instruction_decode.sv:343`; decode falls through to no-write; no test (`G-06`, `G-13`) | deferred |
| FR-25 ECALL and EBREAK trap | — | `rtl/instruction_decode.sv:351-353`; decoded as no-operation; no test (`G-06`, `G-13`) | deferred |
| FR-26 FENCE ordering | — | `rtl/instruction_decode.sv:348-350`; decoded as no-operation; no test (`G-06`) | deferred |
| FR-27 cache-line fetch burst | — | `rtl/instruction_fetch.sv:76-101`; one word address per cycle, no last-beat signal; no test (`G-15`) | deferred |
| FR-28 hold outstanding fetch | — | `rtl/control.sv:282-285`, `rtl/instruction_fetch.sv:108-127`; PC advances with the grant withheld; no test (`G-09`, `G-15`) | deferred |
| FR-29 mtvec direct mode | — | `rtl/control.sv:297`, `rtl/instruction_decode.sv:351-353`; constant vector, no CSR write; no test (`G-01`, `G-13`) | deferred |
| FR-30 mtvec vectored mode | — | `rtl/control.sv:297`; constant vector, no mode field; no test (`G-01`, `G-14`) | deferred |
| FR-31 fence.i invalidates cache | — | `rtl/instruction_decode.sv:348-353`; no-operation, no cache; no test (`G-06`, `G-15`) | deferred |
| FR-32 mhartid report | — | `rtl/riscv_small.sv:45-62`; no CSR and no hart-identity input; no test (`G-13`, `G-16`) | deferred |
| FR-33 per-hart behaviour | — | `rtl/riscv_small.sv:38-62`; single hart, no hart-count parameter; no test (`G-16`) | deferred |
| FR-34 configuration invariance | — | `rtl/riscv_small.sv:38-62`; no configuration parameters; no test (`G-15`, `G-16`) | deferred |
| FR-35 Zaamo and Zalrsc | — | `rtl/riscv_definitions_pkg.sv:129-187`, `rtl/instruction_decode.sv:341-347`; no A encodings; no test (`G-16`) | deferred |
| FR-36 machine software interrupt | — | `rtl/riscv_small.sv:48`; only the level-sensitive exception input; no test (`G-14`, `G-16`) | deferred |
| FR-37 misa advertises extensions | — | `rtl/instruction_decode.sv:351-353`; no CSR file; no test (`G-13`, `G-16`) | deferred |
| FR-38 store waits for grant | — | `rtl/control.sv:288`; stall also requires a load destination; no test (`G-18`) | deferred |
| FR-39 machine timer interrupt | — | `rtl/riscv_small.sv:48`; no interrupt input and no timer; no test (`G-14`) | deferred |
| FR-40 machine external interrupt | — | `rtl/riscv_small.sv:48`; no external interrupt path; no test (`G-14`) | deferred |
| FR-41 reset behaviour | `T-50` | `rtl/instruction_fetch.sv:83` and `rtl/control.sv:101` hardcode `or negedge rst_n`; there is no de-assertion synchroniser and no reset-style macro in `rtl/` (`G-21`). **The reset-vector clause is now implemented:** `RESET_VECTOR` is a parameter of `riscv_small` (default `32'h8000_0000`, the spec's §5.2 value) and `rtl/instruction_fetch.sv:110` resets `pc` to it (`G-33`, closed 2026-11-18). `T-50` observes the first fetch after reset and fails on the `reset-vector-zero` mutant. **`partial` for two reasons:** the synchronised release is still absent (`G-21`), and the acceptance's "two different values of the parameter in two builds" arm is **not demonstrated** — `T-50` runs with the default, where `pc <= RESET_VECTOR` and `pc <= 32'h8000_0000` are indistinguishable, and the second elaboration is deferred (WP-11 §9.1) | partial |
| FR-42 misaligned split | — | `rtl/riscv_small.sv:134` issues one access per instruction from `alu_ma`; there is no second beat, no address increment and no strobe recomputation (`G-22`); no test (`G-04`) | deferred |
| FR-43 `M` extension | — | `rtl/instruction_decode.sv:341-347` ignores every function bit but bit 5, so the `M` group aliases onto the base ALU (`G-06`); no test (`G-04`) | deferred |
| FR-44 `C` and `IALIGN=16` | — | `rtl/instruction_decode.sv:46` takes a 32-bit `inst` and `:254` decodes on the opcode field, so no 16-bit parcel is formed and a 32-bit instruction spanning two fetched words is not assembled (`G-06`); no test (`G-04`) | deferred |
| FR-45 `MRET` | — | `rtl/instruction_decode.sv:351-353` decodes the SYSTEM group as a no-operation; there is no `MRET` decode and no `mepc`/`mstatus` (`G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-46 `WFI` | — | `rtl/instruction_decode.sv:351-353` decodes the whole SYSTEM group as a no-operation, so `WFI` currently retires as a legal no-op by accident; there is no `mstatus.TW` and no CSR file, which is what the row still needs (`G-13`); no test (`G-04`) | deferred |
| FR-47 `Zicsr` instructions | — | `rtl/instruction_decode.sv:351-353` decodes CSR encodings as a no-operation; no CSR file and no CSR port (`G-13`); no test (`G-04`) | deferred |
| FR-48 interrupt entry and priority | — | `rtl/control.sv:276-311` hardcodes the trap vector and ties the cause to zero; there is no `mstatus`/`mie`/`mip` and no interrupt input (`G-01`, `G-02`, `G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-49 `Zicntr` | — | no CSR port and no CSR instruction, so `cycle`/`time`/`instret` are unreachable (`rtl/instruction_decode.sv:351-353`, `G-13`); no test (`G-04`) | deferred |
| FR-50 CSR file and map | — | no CSR file and no `CSR*` decoding: the whole SYSTEM opcode group is a no-operation (`rtl/instruction_decode.sv:351-353`) and the top has no CSR read or write port (`rtl/riscv_small.sv:45-62`) (`G-13`); no test (`G-04`) | deferred |
| FR-51 `mscratch` | — | no CSR file and no `CSR*` decoding (`rtl/instruction_decode.sv:351-353`, `rtl/riscv_small.sv:45-62`), so 0x340 is unreachable (`G-13`); no test (`G-04`) | deferred |
| FR-52 `mtval` | — | no CSR file and no `CSR*` decoding (`rtl/instruction_decode.sv:351-353`), and the cause the trap logic registers is tied to zero (`rtl/control.sv:299-311`) (`G-13`); no test (`G-04`) | deferred |
| FR-53 debug mode | — | the top has no debug port (`rtl/riscv_small.sv:45-62`), no debug mode and no `dcsr`/`dpc`/`dscratch`; the SYSTEM group is a no-operation (`rtl/instruction_decode.sv:351-353`) (`G-23`); no test (`G-04`) | deferred |
| FR-54 run control | — | no `dbg_*` port on the DUT (`rtl/riscv_small.sv:45-62`) and no debug state to control (`G-23`); no test (`G-04`) | deferred |
| FR-55 abstract commands | — | no debug port, no CSR file and no command channel (`rtl/riscv_small.sv:45-62`, `rtl/instruction_decode.sv:351-353`) (`G-23`); no test (`G-04`) | deferred |
| FR-56 program buffer | — | the fetch path takes instructions only from the instruction-memory port (`rtl/instruction_fetch.sv`), so a second instruction source does not exist (`G-23`); no test (`G-04`) | deferred |
| FR-57 `Sdtrig` triggers | — | no trigger unit and no `tselect`/`tdata`/`tinfo` decoding (`rtl/instruction_decode.sv:351-353`) (`G-24`); no test (`G-04`) | deferred |
| FR-58 single step | — | no debug mode to re-enter (`G-23`); no test (`G-04`) | deferred |
| FR-59 `dbg_auth` strap | — | no debug port, so there is nothing for the strap to gate (`rtl/riscv_small.sv:45-62`) (`G-23`); no test (`G-04`) | deferred |

## Coverage bins

`A-09`/`Q-11` fix the functional-coverage bar: **one bin per instruction that `doc/spec.md` §4.1 says
`rtl/instruction_decode.sv` decodes today, plus one per memory width — 40 bins**. The two no-operation rows of
that table (`FENCE`/`FENCE.I`, and `ECALL`/`EBREAK`/`CSR*`) carry no bin, because the RTL decodes them as
no-operations (`G-06`, `G-13`); a word outside the decoded subset decodes to a sentinel that names no bin, so it
is counted by nothing. The collector is `riscv_small_coverage` (`tb/env/top/riscv_small_coverage.sv`), a
subscriber to the monitor; it never samples the driver, the sequence or the reference model. Since WP-8 the
monitor also publishes retire events on the same port; the collector filters them out before sampling
`cg_mem`, so a retire cannot hit a lane or direction bin with zeroed data fields. A bin is still a fetch.

Measured 2026-11-18 by `make coverage`, which runs **43** of the 46 manifest rows — the three `spike:` rows (`T-47`..`T-49`) are skipped by design in `scripts/verify/coverage.cmake`, because they are the trace comparison and the images they run are already measured by `T-43`/`T-12`/`T-15` — at RTL `sha256:b914f2e1…` and TB
`sha256:066dce85…`: **40 of the 40 bar bins** and **50 of the 50 report bins**, `uncovered` empty,
`percentages=100`. `cp_inst` is 37 of 37, `cp_width` 3 of 3, and `cg_mem` 13 of 13. This closes `G-03`; it does
**not** close `A-09`, which needs every `FR` row `verified`. `G-28` is closed by WP-8, but the bins are still
fetch-based.

Two limits still apply to every row. A hit is a **fetch**, not a retire: `if_id_flush` (`rtl/control.sv:263-268`)
discards an instruction the monitor has already published, so a bin proves the class was **accepted on the fetch
handshake** (`inst_rd_en && inst_ready`) — it does not prove it entered IF/ID, and it does not prove it retired
(`G-28`, closed by WP-8; the collector has not been migrated to the retire stream). And a hit verifies no `FR` on its own — the in-testbench model executes the load/store subset and publishes only `SW` predictions while the Spike trace comparator runs on three images (`G-04`),
so the `FR` column says what a bin *could* witness. The `Witness` column names the test that fills the bin and
that must fail on the bin's mutant.

| Bin | Instruction / width | `FR` it can support | Witness | 2026-11-18 |
|---|---|---|---|---|
| `cp_inst.lui` | `LUI` | `FR-04` | `T-41` | hit |
| `cp_inst.auipc` | `AUIPC` | `FR-05` | `T-42` | hit |
| `cp_inst.jal` | `JAL` | `FR-06` | `T-18` | hit |
| `cp_inst.jalr` | `JALR` | `FR-07` | `T-17`, `T-37` | hit |
| `cp_inst.beq` | `BEQ` | `FR-08` | `T-10`, `T-12` | hit |
| `cp_inst.bne` | `BNE` | `FR-08` | `T-38` | hit |
| `cp_inst.blt` | `BLT` | `FR-08` | `T-19` | hit |
| `cp_inst.bge` | `BGE` | `FR-08` | `T-20` | hit |
| `cp_inst.bltu` | `BLTU` | `FR-08` | `T-21` | hit |
| `cp_inst.bgeu` | `BGEU` | `FR-08` | `T-22` | hit |
| `cp_inst.lb` | `LB` | `FR-12` | `T-06` | hit |
| `cp_inst.lh` | `LH` | `FR-12` | `T-06` | hit |
| `cp_inst.lw` | `LW` | `FR-09` | `T-01` | hit |
| `cp_inst.lbu` | `LBU` | `FR-12` | `T-06` | hit |
| `cp_inst.lhu` | `LHU` | `FR-12` | `T-06` | hit |
| `cp_inst.sb` | `SB` | `FR-11` | `T-13` | hit |
| `cp_inst.sh` | `SH` | `FR-11` | `T-14` | hit |
| `cp_inst.sw` | `SW` | `FR-10` | `T-01` | hit |
| `cp_inst.addi` | `ADDI` | `FR-02` | `T-11` | hit |
| `cp_inst.slli` | `SLLI` | `FR-03` | `T-40` | hit |
| `cp_inst.slti` | `SLTI` | `FR-02` | `T-23` | hit |
| `cp_inst.sltiu` | `SLTIU` | `FR-02` | `T-24` | hit |
| `cp_inst.xori` | `XORI` | `FR-02` | `T-25` | hit |
| `cp_inst.srli` | `SRLI` | `FR-03` | `T-26` | hit |
| `cp_inst.srai` | `SRAI` | `FR-03` | `T-27` | hit |
| `cp_inst.ori` | `ORI` | `FR-02` | `T-39` | hit |
| `cp_inst.andi` | `ANDI` | `FR-02` | `T-28` | hit |
| `cp_inst.add` | `ADD` | `FR-01` | `T-43` | hit |
| `cp_inst.sub` | `SUB` | `FR-01` | `T-29` | hit |
| `cp_inst.sll` | `SLL` | `FR-01` | `T-30` | hit |
| `cp_inst.slt` | `SLT` | `FR-01` | `T-31` | hit |
| `cp_inst.sltu` | `SLTU` | `FR-01` | `T-32` | hit |
| `cp_inst.xor_` | `XOR` | `FR-01` | `T-33` | hit |
| `cp_inst.srl` | `SRL` | `FR-01` | `T-34` | hit |
| `cp_inst.sra` | `SRA` | `FR-01` | `T-35` | hit |
| `cp_inst.or_` | `OR` | `FR-01` | `T-36` | hit |
| `cp_inst.and_` | `AND` | `FR-01` | `T-10` | hit |
| `cp_width.byte_w` | byte access | `FR-11`, `FR-12` | `T-06`, `T-13` | hit |
| `cp_width.half_w` | halfword access | `FR-11`, `FR-12` | `T-06`, `T-14` | hit |
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

| # | Check | Fails when | 2026-11-18 |
|---|---|---|---|
| 1 | `make docs-check`, `make docs-figs-check` | exit != 0 | ok |
| 2 | `spec.md` x this file: same FR set, same status | count or status diverge | ok |
| 3 | every `verified` row names a `T-xx` in `scripts/verify/tests.tsv` and a file in `tb/tests/` | ghost test | ok |
| 4 | no open question, no expired `A-xx` | a `Q` open, or an `A-xx` past its due date | ok |
| 5 | latest `build/regress/*/results.json` | `fail`/`timeout` > 0, stale `rtl_digest`, older than 7 days | ok |
| 6 | `build/sanity/summary.json` (`NFR-05`) | absent, not measured, or any image fails | blocked (42 of 43 pass — 41 of the 42 bundled images plus the local `jalr_unaligned`; the one failure is `ma_data`, `FR-42`) |
| 7 | `build/cov_report/summary.json` (`NFR-06`) | merge absent, no coverpoint, or measured at an older `rtl_digest` | ok (50/50 bins, bar 40/40, 100 %, `uncovered` empty) |
| 8 | `doc/measurements/NFR-01..04-*.md` | a file is missing, has no method or no date | ok (4 files with method and date) |
| 9 | `doc/measurements/NFR-07-*.md` | absent (no synthesis lint flow, `G-05`) | not measurable |
| 10 | `A-09`: every FR `verified` | any FR is not `verified` | blocked (14/59; release-blocker gaps `G-04`, `G-11`) |
| 11 | negative control: every WP test fails on the mutant it carries | no mutant run, or the test passes on the mutant | ok (44 rows: `T-06`, `T-08`..`T-15`, `T-16`..`T-50`) |

The work-package gate runs checks 1-5, 7 and 11. Checks 6 and 8-10 are release evidence and are reported as `skipped` in a
WP. Check 7 runs in both modes on purpose: a WP that changes behaviour without re-measuring coverage has no
evidence that its new bins were exercised, and a coverage merge older than the current `rtl_digest` is reported as
stale.

Exit codes: `0` `signoff-ready`, `1` `blocked`, `2` the gate could not run. The gate is **blocked** on 2026-11-18
and must stay blocked: the release-blocker gaps are `G-04` and `G-11`, joined by the `rv32ui-p-ma_data` failure under `NFR-05`/`FR-42`, and the four `TBD` non-functional targets
plus them leave **45 of 59** requirements unverified (`A-09`). A gate that passes here is a broken gate.

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
2026-11-04 and measures `G-19` for the first time. `G-28` was the first row opened against the **verification
environment** rather than the RTL: `Q-43`/`C-16` (2026-11-04) required the reference model to run off the monitor and
to survive in a passive agent, and the core published no retire/commit observation, so the only instruction-level
visibility was a fetch that `if_id_flush` can discard. The two consequences — a coverage bin a flushed fetch could
satisfy, and a model fed by the sequence — were one missing signal. **WP-8 closed it on 2026-11-07** (row `G-28`
below): the retire observation exists and the model consumes only the monitor.

The `Owner` and `Target` columns are the commitments of `A-09`, confirmed by the designer on 2026-10-28 under
`Q-12`: the designer owns the spec and ISA gaps, the verification lead owns the DV gaps, and every target is
2026-12-31. They are commitments, not proposals.

| ID | Gap | Impact | Owner | Target |
|---|---|---|---|---|
| G-01 | `trap_addr` is hardcoded to 1000 (`rtl/control.sv:297`); v0.2 sets the target as the `mtvec` CSR with direct and vectored modes (`FR-29`, `FR-30`) | traps always land at the same address, and the vector cannot be changed by software | designer | 2026-12-31 |
| G-02 | `scause` is tied to zero (`rtl/control.sv:307`); v0.2 sets the target as `mcause` per the ratified privileged specification (`FR-23`) | no trap cause reported, so a handler cannot tell a timer tick from an illegal instruction | designer | 2026-12-31 |
| G-03 | **closed 2026-11-06 by WP-7**: the `A-09` bar is full. `cg_inst`/`cp_inst` (`tb/env/top/riscv_small_coverage.sv:194-236`) declares one bin per instruction of `spec.md` §4.1 and the monitor samples every accepted fetch; WP-5 reached 17/40, WP-6 21/40, and WP-7's nineteen images took it to **40 of 40** (`cp_inst` 37/37, `cp_width` 3/3, `cg_mem` 13/13), `uncovered` empty. The path is in the section "Coverage bins" | closed; the bins are hit, so `NFR-06` has no open bin. `G-28` still bounds what a hit means — a bin is a fetch, not a retire | verification lead | closed 2026-11-06 |
| G-04 | Reference model and scoreboard cover only LW/SW (the in-testbench model executes the load/store subset and publishes only `SW` predictions) — **narrowed 2026-11-07 (WP-8)** and **narrowed again 2026-11-18 (WP-9):** `make spike-trace` (`T-47`..`T-49`) now compares the DUT's committed instruction trace (`+RETIRE_LOG`: `pc`, `rd`, value, instruction word) against Spike (`--log-commits`) for three images (`add` 459/459 @`0x8000057c`, `beq` 285/285 @`0x8000035c`, `st_ld` 477/477 @`0x80000784`). What remains is the four-item residual: (1) store address and data are omitted from the canonical line (`mem` suffix dropped; measured: `store-width-cast` gives an identical 477/477 trace on `st_ld`), (2) `rd = x0` writes are suppressed in the dump by construction (`FR-14`), (3) bus-protocol properties (`FR-20`, `FR-21`) never appear in a commit trace, and (4) only 3 of the 43 sanity images are trace-compared | the six as-built requirements outside `LW`/`SW` (`FR-13`, `FR-14`, `FR-15`, `FR-19`, `FR-20`, `FR-21`) still cannot become `verified`, so the `Q-11` bar ("every `FR` row `verified`") cannot be met — a **release blocker** | verification lead | 2026-12-31 |
| G-05 | No timing, area, or power measurement exists | `NFR-01` to `NFR-04` and `NFR-07` cannot be verified; no frequency or part is recorded (`A-08`, `Q-08`) | designer | 2026-12-31 |
| G-06 | Unimplemented encodings execute as no-operations: unknown opcodes and RV32M aliases fall through the decode default (`rtl/instruction_decode.sv:254-263`, `rtl/instruction_decode.sv:343`), `FENCE` is an empty case (`rtl/instruction_decode.sv:348-350`) and `ECALL`/`EBREAK`/CSR are an empty case (`rtl/instruction_decode.sv:351-353`) | no illegal-instruction trap; `FR-24`, `FR-25`, `FR-26` stay `deferred`; `M` and `C` cannot be claimed in phase 1. Since `Q-05` (2026-10-28) every unimplemented encoding must trap, so this is a conformance blocker, not a scope choice; `FR-24`, `FR-25`, `FR-43` and `FR-44` stay `deferred` for lack of the trap; the `FENCE` half is the separate phase-1 row `FR-26`, blocked only by the decoder (`Q-15` was answered on 2026-10-28) | designer | 2026-12-31 |
| G-07 | **closed 2026-11-05 by WP-7**: `JALR` did not clear bit 0 of its target. `rtl/jump_decision.sv:115-116` now masks `& ~32'h1` when `base_addr_sel == RS1` (the `JALR` case only; `JAL` and branches keep every address bit). Closing it also exposed `G-31` | closed; `T-17` (`rv32ui-p-jalr`) and `T-37` (`rv32ui-p-jalr_unaligned`, an odd target) pass, and the mutant `jalr-keep-bit0` makes `T-37` fetch `pc=0xc1` and fail `testnum=3`. `FR-07` stays `partial` for its other clause (`G-13`) | designer | closed 2026-11-05 |
| G-08 | **closed 2026-11-05 by WP-6**: sub-word stores drove one lane whatever `data_addr[1:0]` said, because `data_wr` was `rs2` unshifted (`rtl/execution.sv:157-174` before the fix). The load half was closed earlier by `FR-12`/`T-06`. The store now lane-places the value and asserts `data_wr_strb` (`rtl/execution.sv:202-225`). | closed; `T-13` (`sb`), `T-14` (`sh`) and `T-15` (`st_ld`) pass, and the mutants `store-lane-offset`/`store-strb-all` fail them | designer | closed 2026-11-05 |
| G-09 | No fetch stall exists: while the fetch grant is withheld only the IF/ID registers are flushed (`rtl/control.sv:272-275`) and the program counter keeps advancing unless IF/ID is held (`rtl/instruction_fetch.sv:108-127`) | reframed in v0.2: this is no longer a doubt about the memory contract (`A-03` is retired) but the **prerequisite for the instruction cache**, because a cache miss must be able to hold the program counter for many cycles; `FR-28` is the requirement that closes it | designer | 2026-12-31 |
| G-10 | **closed 2026-10-30 by WP-4**: the sanity flow now compiles each `rv32ui-p-*` with the project environment (`scripts/verify/sanity/`), extracts `tohost` from the ELF and runs it through `riscv_small_sanity_test` with `+HEX`/`+TOHOST`. The sequence reads the image with `$readmemh` and builds the program item. | `NFR-05` is **measured** (41 of 42 bundled pass); the one remaining failure is `FR-42` | verification lead | closed 2026-10-30 |
| G-11 | `T-02` adds no stimulus: `riscv_small_corner_seq::body()` only calls `super.body()` (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), so it repeats `T-01` | no requirement can cite `T-02`; boundary values are untested, so the coverage leg of the `Q-11` bar rests on `T-01` alone — a **release blocker** | verification lead | 2026-12-31 |
| G-12 | The top-level `clk_en` gates only the trap-state registers and `branch_taken_q` (`rtl/riscv_small.sv:260`, `rtl/control.sv:105`, `:304`), while stage enables are generated inside `rtl/control.sv`; the port is described as a global clock enable but does not gate the pipeline | `C-02` is a description of the port, not a promise; integrators cannot pause the core with `clk_en` | designer | 2026-12-31 |
| G-13 | No CSR file and no CSR instruction: `CSR*` is decoded as a no-operation (`rtl/instruction_decode.sv:351-353`) and the trap state registers are unreadable (`rtl/control.sv:299-310`) | `FR-23`, `FR-24`, `FR-25`, `FR-29`, `FR-30`, `FR-32`, `FR-37`, `FR-45` to `FR-47`, `FR-49` to `FR-52`, and `Zicsr`/`Zicntr` in `§7.1`, stay `deferred` | designer | 2026-12-31 |
| G-14 | No machine-mode interrupt subsystem: the only trap request is the level-sensitive `exception` input (`rtl/riscv_small.sv:48`), with no `mip`/`mie`, no timer, and no external controller interface | `FR-39`, `FR-40`, `FR-36`, `FR-48`, and the vectored mode of `FR-30`, stay `deferred`; `D-01`'s preemption cannot be demonstrated | designer | 2026-12-31 |
| G-15 | No instruction cache and no line-based fetch: `rtl/instruction_fetch.sv:76-101` drives one word address per cycle with no burst and no last-beat signal, and neither `ICACHE_BYTES` nor `ICACHE_LINE` exists. **Re-attributed 2026-11-05:** `rv32ui-p-fence_i` was failing on `G-31` (an unforwarded `JALR` `rs1`), not here and not on the `G-07` mask — every `jalr` in `src/riscv-tests/isa/rv64ui/fence_i.S:27`, `:41`, `:57`, `:60` targets an aligned label, so the mask is a no-op there and the image now **passes**; on a cacheless core `fence.i` is correctly a no-operation | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 of the specification is a target, not a description of the RTL; `NFR-02`'s condition cannot be met. It is **not** an `NFR-05` failure any more | designer | 2026-12-31 |
| G-16 | No multi-hart support: the top is a single hart (`rtl/riscv_small.sv:38-62`) with no hart-identity input, no `NUM_HARTS`, no `A` encodings (`rtl/riscv_definitions_pkg.sv:129-187`) and no software interrupt | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; the `MCU_SMP` configuration of §5.2 cannot be built | designer | 2026-12-31 |
| G-17 | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-11` live in `doc/spec.md` §0.1 | decisions are not indexed beside the requirements they justify, and a superseded decision has nowhere to be retired | designer | 2026-12-31 |
| G-18 | Stores do not wait for the data grant: the stall condition at `rtl/control.sv:288` also requires a load destination, so a store asserts its strobe for one cycle whatever `data_ready` does | `FR-38` stays `deferred`; the store contract is the testbench's, which grants every access immediately, so the difference is invisible today | designer | 2026-12-31 |
| G-19 | **closed 2026-11-05 by WP-6**: a load-use insertion cleared `id_ex_clk_en`, which was also the register file's clock enable (`rtl/instruction_decode.sv:202-211`, `rtl/riscv_small.sv:161`, `rtl/reg_file.sv:99`), so the write-back of a younger instruction was dropped. `instruction_decode` now takes `clk_en_wb` (the global `clk_en`) for `u_reg_file`, and the ID/EX register keeps `id_ex_clk_en`. | closed; before the fix `x4` was written 3 times against 33308 for `x5` in `T-13`, after it 39 against 39 (`build/regress/2026-11-05T17-39-54Z` and `…18-37-01Z`), and `rv32ui-p-lb`/`-lbu` went green | designer | closed 2026-11-05 |
| G-29 | **closed 2026-11-05 by WP-6**: `pc_fetch` was gated by `if_id_clk_en` while the external instruction memory kept answering the held address, so on a load-use release the IF/ID register captured `pc_id` from one address and `inst_id` from another (`0x254` decoded with the word of `0x258`); the fix is `assign inst_addr = clk_en ? pc : pc_fetch;` (`rtl/instruction_fetch.sv:76`), which re-requests the address whose word is on the bus during the freeze. | closed; `T-13`/`T-14` green and 11/11 regression, where before the fix they timed out at `pc=0x24c`; the rejected variant, which aligned the pair but dropped `0x254`, is what showed that the request must be held rather than the delay line. The same defect was **manufacturing a false PASS** in `rv32ui-p-ld_st` (stale PC at `0xa4` → target `0xee4` → `<pass>` → `tohost=1`), which is why that image flipped from pass to fail when this closed | verification lead | closed 2026-11-05 |
| G-30 | **closed 2026-11-05 by WP-7**: a load-use freeze evaluated the branch with the load result unresolved, so `branch_taken` redirected to a stale target and `branch_taken_q` flushed a valid fetch. `rtl/control.sv:99` declares `branch_op_stall`, set by exactly the six `data_rd_en_ma`/`data_rd_en_ex` freeze arms and **not** by `data_ready`/`inst_ready`; it gates the current-cycle redirect (`:266`) and the registered echo (`:106`). `branch-taken-stale` reverts only the echo, because reverting `:266` alone was measured **not** to reproduce the failure (the branch re-evaluates and recovers); `:266` is therefore proven by reading, not by a mutant. Found 2026-11-05 by WP-6 once `G-29` stopped masking it | closed; `T-16` (`rv32ui-p-ld_st`) passes, and the mutant `branch-taken-stale` — which must revert the **registered echo**, not the current-cycle gate — reproduces `testnum=2 value=5` | verification lead | closed 2026-11-05 |
| G-31 | `JALR`'s `rs1` was never forwarded: the jump-compare forward mux was gated on `cond_jump` only, so a `JALR` immediately after its producer compared a stale register value and went to the wrong target. Found by the WP-7 red — `T-17` re-ran identically after the bit-0 mask was added, which showed the mask was not the reason it failed | closed in the same WP: `rtl/control.sv:135` opens the forward for `cond_jump \|\| jalr`, and `rtl/instruction_decode.sv:289` exports `jalr` (two new ports, catalogued in `uarch.md` §4). Evidence: `T-17` green, mutant `jalr-no-forward`. Never released, so it was never a blocker | verification lead | closed 2026-11-05 |
| G-32 | **closed 2026-11-07 by WP-8.** The monitor sampled `inst_addr` and `inst_data` in the same `@(posedge clk)` while the driver answered with `OUTPUT_DELAY` after the edge, so the published fetch pair was `(address t, word t-1)`; and on the data port it published once per cycle the enable was high instead of once per accepted handshake. The monitor now correlates by **handshake**: an outstanding-request queue pushes on the request and pops on the response, so the pair is exact at any latency. | closed for the fetch port; `FETCH_PAIR` is green on the six tests that configure a program image (`T-01`, `T-02`, `T-06`, `T-44`, `T-45`, `T-46`; the other 39 print `NONE compared`), and the mechanism survives a cache or a wait state. The **data port is documented, not fixed** — with the flat port no rule is correct, because `data_ready` is a level the driver echoes while the core holds the enable; it needs the req/rsp form of `E8`/`G-18` | verification lead | closed 2026-11-07 |
| G-33 | **Closed 2026-11-18 by WP-11.** No `RESET_VECTOR` parameter and a hardcoded reset to `0`: `rtl/instruction_fetch.sv` wrote `pc <= 'b0` and the identifier appeared nowhere under `rtl/`, while `FR-41`, `Q-33` and the spec's §5.2 table specify a build-time parameter defaulting to `0x8000_0000`, so the first fetch left at `0x0`. Found while documenting the WP-9 reference model — it had been invisible because **both** harness legs worked around it: `scripts/verify/sanity/link.ld` linked every image at `0x0` *because* the DUT reset there, and `scripts/verify/spike/build_spike.sh` remapped the reference to the same base. WP-11 added the parameter to `riscv_small` (default `32'h8000_0000`), propagated it to `instruction_fetch`, and made `rtl/instruction_fetch.sv:110` reset `pc` to it; the harness moved to the spec's address (`link.ld` at `0x80000000`, hex rebased by `objcopy` so `tohost` needs no mask), and the three Spike flags `-m0:0x40000`, `--no-dm` and `--disable-dtb` disappeared with the low base | closed for what the evidence covers: `T-50` observes the first fetch after reset and fails on the `reset-vector-zero` mutant, so the parameter exists and the reset consumes it. **Parameter configurability is NOT demonstrated** — `T-50` runs with the default, where `pc <= RESET_VECTOR` and `pc <= 32'h8000_0000` are indistinguishable and no mutant separates them; the acceptance's "two different values in two builds" arm needs a second elaboration, deferred by the designer on 2026-11-18 with its cost and reasoning in `.opencode/plan/wp-11-reset-vector.md` §9.1. `FR-41` therefore stays `partial`, also for `G-21`. Not a `Q-11` blocker — the `G-21` precedent | designer | closed 2026-11-18 |
| G-20 | **closed 2026-11-04 by WP-4c**: `rtl/jump_decision.sv:111` added `imm[20:0]`, zero-extending a negative offset; the fix is `base_addr + imm` (the `imm` is already sign-extended by `imm_gen`). | closed; `T-12`/`rv32ui-p-beq`, the branch images and `FR-08` pass | designer | closed 2026-11-04 |
| G-21 | Reset is asynchronous on both edges: every DUT module hardcodes `or negedge rst_n` (`rtl/instruction_fetch.sv:83`, `rtl/control.sv:101`) and there is no de-assertion synchroniser and no `ASYNC_RESET`-style macro selection. `D-09` and `FR-41` require async assertion with a synchronised release | the release edge is asynchronous, so a de-assertion that arrives close to a clock edge can release different registers on different edges; the FPGA synchronous-reset variant cannot be built at all | designer | 2026-12-31 |
| G-22 | **narrowed 2026-11-05 by WP-6 to the misaligned split.** The byte strobes exist: `data_wr_strb[3:0]` is driven from the store lane (`rtl/execution.sv:202-225`, `rtl/riscv_small.sv:62`) and checked by `riscv_small_strb_checker`. What remains is that an access crossing a word boundary is not split: `data_addr` is still `alu_ma` (`rtl/riscv_small.sv:134`), so `FR-42`'s two word-aligned beats are not issued. | the strobe half is closed; the split half keeps `A-05`'s EEI guarantee unmet for a cross-word access (`SH` at an odd address, `SW` off-word), owned by `FR-42` (`E8`) | designer | 2026-12-31 |
| G-23 | No debug subsystem: the DUT has no debug port, no debug mode, no `dcsr`/`dpc`/`dscratch` and no abstract-command or program-buffer path (`rtl/riscv_small.sv:45-62`, `rtl/instruction_decode.sv:351-353`) | `FR-53` to `FR-56`, `FR-58` and `FR-59` stay `deferred`, and `T-05` cannot exist until a Debug Module model is built | designer | 2026-12-31 |
| G-24 | No trigger unit: `tselect`/`tdata1`..`tdata3`/`tinfo` are not decoded and no address or data comparator exists (`rtl/instruction_decode.sv:351-353`) | `FR-57` stays `deferred`; breakpoints and watchpoints cannot be observed in any configuration | designer | 2026-12-31 |
| G-25 | **closed 2026-10-30 by WP-4**: the MA forward block in `rtl/control.sv:246-263` forced `alu_src2` to the store data, so a store's address became `rs1 + rs2` instead of `rs1 + imm` (`sw gp,tohost` went to `0x1`). The fix gates `alu_src2` on `alu_src2_ex == RS2` and keeps `storage_src` for the store data (`rtl/control.sv:238-241`). | closed; `T-08` and `rv32ui-p-simple` pass | verification lead | closed 2026-10-30 |
| G-26 | **closed 2026-11-04 by WP-4c**: the branch/jump forward mux `jmp_src1`/`jmp_src2` was unconnected (`rtl/riscv_small.sv:172-173`) and `alu_ex`, the EX forward source, was undriven (`rtl/execution.sv:241`); the ALU forward itself was functional. | closed; `T-10`/`T-11`, the `add`/`addi`/`and` images and the mutants pass; `FR-16`/`FR-18` verified, `FR-19` implemented | verification lead | closed 2026-11-04 |
| G-27 | **closed 2026-11-04 by WP-4c**: the decoder PC was one instruction ahead of `inst_data` (`pc_id <= pc`) and the redirect had one flush too few; `pc_fetch` (`rtl/instruction_fetch.sv:76-101`) and `branch_taken_q` (`rtl/control.sv:101-108`, `:271-274`) fix it. | closed; `T-10`/`rv32ui-p-and` and the fail-path `testnum` pass; `FR-08` | designer | closed 2026-11-04 |
| G-28 | **closed 2026-11-07 by WP-8.** There was no retire/commit observation: the only instruction-level visibility was the fetch, and `if_id_flush` could discard an instruction the monitor had already published. The core now carries `valid`, `pc` and the instruction word to WB (`rtl/instruction_fetch.sv` `valid_id` -> `instruction_decode.sv` `valid_ex` -> `execution.sv` `valid_ma` -> `memory_access.sv` `valid_wb`), and a `bind` probe (`riscv_small_retire_if`, `tb/riscv_small_interface.sv`) publishes `(pc, inst, rd, wdata)` on `valid_wb && ma_wb_clk_en`. The reference model consumes **only** the monitor, and `program_port`/`rm_export`/`publish_program()` are deleted (`grep` empty). | closed; `T-44` (72 commits for 72 instructions), `T-45` (10 commits for 12 fetches, 2 instructions skipped) and `T-46` (WP-9 P1: 9 commits for 11 fetches when a branch skips 3 instructions, replacing the coincidental count equality with a per-pc set claim plus a gated count claim) pass, and the mutant `retire-every-slot` fails them while the store comparison still passes — proof that the retire checker, not the SW comparison, has the teeth. **Limit kept:** a `cp_inst` bin is still a fetch; coverage has not been migrated to the retire stream | verification lead | closed 2026-11-07 |

## Notes

- `T-01`, `T-02`, `T-06`, `T-08`..`T-15`, `T-16`..`T-50` are the tests in `scripts/verify/tests.tsv`; `T-03`,
  `T-04` and `T-05` are v0.7 targets with no implementation yet (`G-04`, `G-13`, `G-14`, `G-23`).
- WP-7 history: the 39 manifest tests were green at `rtl_digest` `sha256:3541dfb8…` and `tb_digest` `sha256:ae4e6c79…` (2026-11-06,
  the WP-7 regression, `build/regress/2026-11-06T02-17-17Z`): `T-01`/`T-02`/`T-06` directed, `T-08`..`T-43` one image
  each, `T-09` the passive topology. `NFR-05` is **measured** at 41 of the 42 bundled images — 42 of 43 runs, the
  extra being the project-local `rv32ui-p-jalr_unaligned` — (`doc/measurements/NFR-05-riscv-tests.md`), not
  `verified`; the only failure is `ma_data` (`FR-42`). `T-02` still repeats `T-01` (`G-11`).
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
  quoted in the `G-19`/`G-29`/`G-30` rows.
- WP-7 closed the RV32I surface. `G-07` (`JALR` bit 0) and `G-30` (a branch decided against an unresolved load)
  are fixed and tested, and the red for `T-17` exposed a third defect, `G-31`: `JALR`'s `rs1` was never forwarded,
  so the mask alone changed nothing. Nineteen images (`T-19`..`T-36`, plus `T-38`..`T-43`) turned every remaining
  instruction bin into a named test, so the `A-09` bar went 21/40 → **40/40** and `NFR-05` 38 → **41 of 42 bundled
  images**. Closing `G-29` in WP-6 had already shown that `rv32ui-p-ld_st` passed falsely; with `G-30` fixed it
  passes genuinely, and `rv32ui-p-fence_i` passed once `G-31` landed (its `jalr`s are aligned, so the `G-07` mask is a no-op there), which is why `G-15` is no longer an
  `NFR-05` failure. The only failing image is `ma_data` (`FR-42`, owned by `E8`). `FR-07` stays `partial`: the
  bit-0 clause is verified, the misaligned-fetch clause of its acceptance is not implemented (`G-13`, epic `E6`).
- WP-8 closed `G-28` and `G-32` and satisfied `C-16`. The core now pipelines `valid`, `pc` and the instruction
  word to WB — `valid_id` is born at IF/ID precisely so a flushed fetch cannot retire as a phantom at `pc=0` — and
  a `bind` probe publishes a retire event on `valid_wb && ma_wb_clk_en`. The reference model consumes **only** the
  monitor and keeps its own architectural state; `riscv_small_program_image` (pc→word plus the initial data
  memory) is the only program input and it is configuration, not a transaction. `program_port`, `rm_export` and
  `publish_program()` are deleted. Evidence: `T-44` 72 commits for 72 instructions; `T-45` **10 commits for 12
  fetches**, the difference exactly the two instructions a taken branch discarded, with neither skipped `pc`
  retiring — and the mutant `retire-every-slot` fails both while the store comparison still passes, which is what
  proves the retire checker has the teeth. Two BFM defects surfaced while measuring and were fixed: it answered a
  fetch during reset, and it left `inst_ready` high after the program ended (the core fetched and retired past it).
  A `cp_inst` bin is still a **fetch**; the retire stream is not yet a coverage source.
- WP-11 implemented the reset vector and removed the last non-standard platform choice. `RESET_VECTOR`
  is a parameter of `riscv_small` (default `32'h8000_0000`, the §5.2 value) propagated to `instruction_fetch`,
  and `rtl/instruction_fetch.sv:110` resets `pc` to it; the harness moved with it — `scripts/verify/sanity/link.ld`
  links at `0x80000000`, `sanity.cmake` rebases the hex with `objcopy --change-addresses=-0x80000000` so `tohost`
  needs no mask, the driver indexes `(addr - MEM_BASE) >> 2`, and the three Spike flags (`-m0:0x40000`, `--no-dm`,
  `--disable-dtb`) disappeared because they existed only for the low base. Spike now runs as
  `--isa=rv32i --log=… --log-commits`; with the device tree enabled it boots through its own ROM at `0x1000`
  first, so `normalize.py` drops that prefix **by address** (`--entry`, from the sanity dump) and fails if the
  payload is never reached. Evidence: `T-50` red first (`pc=0x0` against `0x80000000`) then green; its `reset-vector-zero` mutant is caught by the checker's `[RESET_VECTOR]`, not by a timeout, mutant
  `reset-vector-zero`; `make regress` **46/46**, `make spike-trace` 3/3 at `0x80000xxx`, `make negative-control`
  **44/44**, sanity 42/43 (`ma_data`, `testnum=1` unchanged), coverage 50/50 + 40/40 at RTL `sha256:b914f2e1…`
  and TB `sha256:066dce85…`. **`G-33` closes with a stated limit:** the parameter exists and the reset consumes
  it, but configurability is unproven — `T-50` uses the default, where `pc <= RESET_VECTOR` and
  `pc <= 32'h8000_0000` are indistinguishable. The second elaboration is deferred (WP-11 §9.1), so `FR-41`
  stays `partial` for that arm and for `G-21`.
- WP-9 added Spike (`riscv-software-src/riscv-isa-sim` commit `11848099…`, `berkeley-softfloat-3` `07ebd29d…`,
  banner `Spike RISC-V ISA Simulator 1.1.1-dev`) as an external reference model (`make spike-trace`,
  `scripts/verify/spike_trace.cmake`). P1 fixed a testbench defect in `riscv_small_retire_checker`: `T-46`
  (a branch at `0x08` -> `0x18` skipping 3 instructions) proved the front end discards a fixed **2** fetched words
  on a taken branch regardless of jump distance (11 fetches, 9 commits), so the unconditional equality
  `fetch_count == retire_count + |skip_pc|` failed when `|skip_pc| != 2`; claim 6 is now a per-pc set check
  (`[RETIRE_FETCH_LOST]`) and claim 7 is gated on single-fetch straight-line/forward-skip runs. P2 added
  `+RETIRE_LOG=<file>` to `riscv_small_monitor` (canonical line `0x<pc:08x> <xN|-> <0xval|-> 0x<inst:08x>`,
  `-`/`-` when `rd0_wr_en_wb == 0` or `rd0_addr_wb == 0`, plus an 8-cycle `RETIRE_DRAIN` in `riscv_small_sanity_test`
  when the dump is on so the `tohost` store commits). P3/P4 built Spike out-of-tree (`scripts/verify/spike/build_spike.sh`,
  invoked with `--no-dm --disable-dtb -m0:0x40000 --isa=rv32i --log-commits`) and added `normalize.py` and
  `compare.py` (`--selftest` 13/13), cutting both traces inclusively at the first committed `<tohost>` store pc
  from the two-epilogue cut set. `T-47` (`rv32ui-p-add`, 459/459 @`0x8000057c`, mutant `alu-ignore-rs2`), `T-48`
  (`beq`, 285/285 @`0x8000035c`, `negative-branch`) and `T-49` (`st_ld`, 477/477 @`0x80000784`, `store-lane-offset`) are
  green, taking `make regress` to **46/46** at RTL `sha256:b914f2e1…` and TB `sha256:066dce85…`. `G-04` is
  **narrowed, not closed**: the canonical trace omits store address/data (`store-width-cast` produces an identical
  477/477 trace on `st_ld`), suppresses `rd = x0` (`FR-14`), carries no bus-protocol timing (`FR-20`, `FR-21`), and
  covers 3 of 43 images, so no `FR` status changes. **Documenting the reference exposed `G-33`:** the spec's
  `RESET_VECTOR` (build input, default `0x8000_0000`) does not exist in `rtl/`, which resets to `0` — and both
  harness legs had been masking it, since the images are linked at `0x0` and Spike is remapped to the same base.
- The sanity harness is UVM-separated (WP-4b): the test reads `+HEX`/`+TOHOST`/`+MAX_CYCLES`/`+TRACE`; the sequence builds the
  program item (`program_addr[]`/`program_data[]`); the driver is a memory BFM and never reads a plusarg, decodes
  `tohost` or raises a verdict error; the monitor publishes fetch **and** data; `riscv_small_sanity_checker` owns
  `SANITY`/`uvm_error`; the test owns the objection and the timeout. The CTest command pins
  `^SANITY: PASS image=<image>$` and the summary rejects a log naming another image (`not_measurable`). The agent honors `is_active` (active =
  driver+sequencer+monitor; passive = monitor only). `drv2rm_port`, `program_port`, `rm_export` and
  `publish_program()` were **removed by WP-8** (`grep` empty in `tb/` and `scripts/`): the model consumes only the
  monitor, so `C-16` is met and `G-28` is closed. `T-44`/`T-45` are the retire evidence; `T-09` still proves the
  passive *topology* only, because it drives no program, and `T-08` exercises the active path.
- `T-09` was red first against the pre-`is_active` TB (`uvm_errors=2`, driver and sequencer built in passive
  mode) and the mutant `passive-agent-always-active` re-proves it at `build/red/T-09/results.json` (`status=fail`,
  `uvm_errors=2`); it is green in the 8/8 regression at TB `sha256:f542affd…` after the `is_active` change.
- The sanity run found `G-25` (store address, fixed), `G-26` (operand forwarding), `G-27` (branch-target first
  instruction skipped) and `G-20` (unsigned branch offset); WP-4c closes the last three, and the 8 remaining
  failures are grouped in `doc/measurements/NFR-05-riscv-tests.md`.
- Functional coverage exists in two covergroups in `tb/env/top/riscv_small_coverage.sv`, both sampled from the
  monitor: `cg_mem` (`cp_width`, `cp_lane`, `cp_dir`, `cp_subword_lane`) and, since WP-5, `cg_inst`/`cp_inst`
  with one bin per instruction of `spec.md` §4.1. The 2026-11-06 WP-7 merge over the 39 manifest tests is
  **50 of 50 report bins** and **40 of 40 against the `A-09` bar** (`cp_inst` 37/37, `cp_width` 3/3, `cg_mem`
  13/13), `uncovered` empty, `xcrg` score 100 %. The per-bin witness is in "Coverage bins". Evidence:
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
