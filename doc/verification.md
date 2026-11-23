# Verification Status

Traceability and honest status. The specification states the requirement; this file states what proves it.

| Field | Value |
|---|---|
| Status | draft |
| Version | v0.12 |
| Baseline | `doc/spec.md` v0.8.8 (RISC-V ISA v20260120; RISC-V Debug Specification v1.0); `rtl_digest` `sha256:2e91301d...` and `tb_digest` `sha256:0091e260...`; the 50 manifest tests are green at that digest (2026-11-21, WP-14 regression) |
| Implements | [spec.md](spec.md) |

## Tests

| ID | Test | Scope | Status |
|---|---|---|---|
| T-01 | `riscv_small_basic_load_store_test` | LW/SW through the pipeline | implemented |
| T-02 | `riscv_small_corner_test` | corner load/store addresses | implemented |
| T-03 | `riscv_small_csr_test` | the machine-mode CSR map and the trap path: the six `Zicsr` forms on `mscratch` with the `rd=x0`/`rs1=x0` cases, every implemented address read, absent and read-only writes trapping, `misa` from the build parameters, `mhartid` from the `hart_id` input, `cycle`/`instret` as views of the machine counters (written, then read back), `mtvec` programmed to a non-default vector, and seven causes (11, 3, 2 ×5) whose handler returns to `mepc+4`; the model derives the expected cause from `trap_inst` and the scoreboard compares `rd`, the value and the `(mepc, mcause)` pair | verified (WP-14) |
| T-06 | `riscv_small_subword_access_test` | `LB`/`LBU` at offsets 0-3 and `LH`/`LHU` at offsets 0 and 2 of one word; each loaded register is stored so the value crosses the data port | verified (`FR-12`) |
| T-07 | — | not issued; the ID is retired (T-06 → T-08) | retired |
| T-08 | `riscv_small_sanity_test` | `+HEX`/`+TOHOST`: a bundled `rv32ui-p-*` image runs until it stores to `tohost`; 42 of the 42 bundled images pass (43 of 43 runs, the extra being the project-local `jalr_unaligned`), triage in `doc/measurements/NFR-05-riscv-tests.md` | verified (`NFR-05` measured) |
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
| T-51 | `riscv_small_halfword_lane_test` | `LH`/`LHU`/`SH` at halfword offset 1 (the odd offset that stays inside the word); the scoreboard compares the loaded value and the store's address/strobes/lane data against the ISS | verified (`FR-11`, `FR-12`; `G-34` closed) |
| T-52 | `riscv_small_sanity_test` | `sanity:rv32ui-p-ma_data`; the 54 RV32 cases of the misaligned-access image, which now split into two word-aligned beats; mutant `no-misaligned-split` | verified (`FR-42`; `G-22` closed) |
| T-53 | `riscv_small_store_grant_test` | a store with the grant withheld for two cycles; `riscv_small_store_grant_checker` requires the access to complete in a grant cycle; mutant `store-grant-ignored` | verified (`FR-38`; `G-18` closed) |
| T-09 | `riscv_small_passive_test` | `is_active=UVM_PASSIVE`: driver and sequencer are absent, the monitor is present; no DUT stimulus | implemented (passive topology) |
| T-04 | timer and interrupt test | `mtip`/`meip`/`msip`, `mie`/`mip`/`mstatus`, entry stack, priority | deferred (`G-14`) |
| T-05 | debug test | hart-side run control, abstract commands, program buffer, triggers, single step, the `dbg_auth` strap; needs a Debug Module model | deferred (`G-23`) |

## Traceability

One row per functional requirement of `doc/spec.md` §4. Each row was derived in three passes: read the clause,
locate it in `rtl/`, then ask whether `tb/` observes it. `verified` needs a test that compares a value; `T-01` and `T-06` do, through the reference model/scoreboard
(`LW`/`SW`) and the directed sub-word checks, `T-02` adds no stimulus
(`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), and `T-08` measures `NFR-05` and is the store-data-forwarding evidence (`FR-18`).
`verified` therefore lags `implemented`: the `implemented` rows outside the `LW`/`SW`/sub-word subset wait on `G-04`
(the in-testbench model executes the load/store subset and publishes only `SW` predictions, while the WP-9 Spike commit-trace comparison covers three images and omits store address/data, `x0` writes and bus-protocol properties) (`NFR-05` is 43 of 43 since WP-13, so no sanity failure remains). A row is `partial` when the clause
executes but a named gap shows it wrong for part of its domain — five rows, `FR-07`, `FR-21` (`G-35`), `FR-24`
(`G-38`), `FR-41` and `FR-50` (`G-39`); the
`deferred` rows keep the status of `doc/spec.md` §4 because the capability is absent, not because the intent is
doubtful.

The `Test` column names the manifest test (`scripts/verify/tests.tsv`) that is evidence for the row; `—` means no
test exercises it yet. That is the same statement as `no test (G-04)` in the evidence column, and it does not by
itself make a row `deferred`: `deferred` is about the capability, not about the test.

| Requirement | Test | Evidence | Status |
|---|---|---|---|
| FR-01 R-type ALU ops | `T-43`, `T-10`, `T-29`..`T-36`, `T-47` | `rtl/instruction_decode.sv:458-464`, `rtl/alu.sv:53-92`; every operation of the family has an image that reads its result: `ADD` `T-43` (and `T-47`, 459/459 committed instructions compared against Spike), `AND` `T-10`, `SUB` `T-29`, `SLL` `T-30`, `SLT` `T-31`, `SLTU` `T-32`, `XOR` `T-33`, `SRL` `T-34`, `SRA` `T-35`, `OR` `T-36`; each fails on a mutant — `alu-ignore-rs2` for nine of them and `alu-or-to-and`/`shift-left-zero` where they apply; `AND`'s isolating proof is `rv32ui-p-and`'s own self-check, because `T-10`'s manifest mutant is `branch-redirect` | verified |
| FR-02 immediate ALU ops | `T-11`, `T-23`..`T-25`, `T-28`, `T-39` | `rtl/instruction_decode.sv:444-457`, `rtl/instruction_decode.sv:245`, `rtl/riscv_definitions_pkg.sv:272`; `ADDI` `T-11`, `SLTI` `T-23`, `SLTIU` `T-24`, `XORI` `T-25`, `ANDI` `T-28`, `ORI` `T-39`; each fails on its mutant (`imm-zero` for the first five, `alu-or-to-and` for `ori`) | verified |
| FR-03 shift-immediate ops | `T-26`, `T-27`, `T-40` | `rtl/instruction_decode.sv:444-457`, `rtl/alu.sv:57-81`; `SRLI` `T-26`, `SRAI` `T-27`, `SLLI` `T-40`; mutants `imm-zero` and `shift-left-zero` | verified |
| FR-04 LUI upper immediate | `T-41` | `rtl/instruction_decode.sv:265-270`, `rtl/instruction_decode.sv:382-387`; `T-41` (`rv32ui-p-lui`) reads the upper immediate back; mutant `lui-ignores-imm` | verified |
| FR-05 AUIPC PC-relative | `T-42` | `rtl/instruction_decode.sv:388-394`, `rtl/alu.sv:54-55`; `T-42` (`rv32ui-p-auipc`) reads the pc-relative value back; mutant `auipc-no-pc` | verified |
| FR-06 JAL link and target | `T-18` | `rtl/instruction_decode.sv:278-285`, `rtl/jump_decision.sv:98-112`, `rtl/instruction_fetch.sv:108-127`; `T-18` (`rv32ui-p-jal`) checks the link value and the target; mutant `jal-offset-zero` | verified |
| FR-07 JALR indirect target | `T-17`, `T-37` | `rtl/instruction_decode.sv:287-295`, `rtl/jump_decision.sv:115-116` clears bit 0 when `base_addr_sel == RS1`, and `rtl/control.sv:152` forwards `rs1` for `cond_jump \|\| jalr` (`G-31`, closed 2026-11-05). `T-17` (`rv32ui-p-jalr`) and `T-37` (`rv32ui-p-jalr_unaligned`, an **odd** target — the only test of the mask) pass, and mutants `jalr-no-forward`/`jalr-keep-bit0` fail them. **`partial`:** the second clause of the acceptance — a target whose bit 1 is set must raise instruction-address-misaligned (cause 0) — has no implementation, because there is no trap path (`G-13`, epic `E6`); the core would fetch the unaligned word. Designer decision of 2026-11-05: the requirement stands as written, so the row does not promote | partial |
| FR-08 six conditional branches | `T-10`, `T-12`, `T-19`..`T-22`, `T-38`, `T-48` | `rtl/instruction_decode.sv:253-256`, `rtl/jump_decision.sv:117-164`; `BEQ` `T-10`/`T-12` (and `T-48`, 285/285 committed instructions compared against Spike), `BNE` `T-38`, `BLT` `T-19`, `BGE` `T-20`, `BLTU` `T-21`, `BGEU` `T-22`; mutants `branch-redirect`/`negative-branch`/`branch-always-taken`. `IALIGN=32` target-alignment arm still owed by `G-06`/`FR-44` | verified |
| FR-09 LW load word | `T-01`, `T-44`..`T-46`, `T-49` | `rtl/instruction_decode.sv:301-314`, `rtl/memory_access.sv:144-146`; `T-01` (`tb/env/top/riscv_small_scoreboard.sv:102-105`), `T-44`..`T-46` (retire-fed model), and `T-49` (`st_ld` commit trace 477/477 against Spike) | verified |
| FR-10 SW store word | `T-01`, `T-44`..`T-46`, `T-49` | `rtl/instruction_decode.sv:315-326`, `rtl/execution.sv:104-131`, `rtl/riscv_small.sv:330-332`; `T-01` (`tb/env/top/riscv_small_scoreboard.sv:102-105`), `T-44`..`T-46` (retire-fed model), and `T-49` (`st_ld` commit trace 477/477 against Spike; store address/data stay on the ISS scoreboard) | verified |
| FR-11 SB and SH lane select | `T-13`, `T-14`, `T-15`, `T-49` | `rtl/execution.sv:207-243` places `rs2` in the addressed lane and drives `data_wr_strb` (`4'b0001 << addr[1:0]` for `SB`, `4'b0011 << addr[1:0]` for `SH`, `4'b1111 << addr[1:0]` for the first beat of a crossing `SW`); `rtl/riscv_small.sv:173` decodes the width with `access_size(rd_wr_ctrl)`. `T-13` (`rv32ui-p-sb`), `T-14` (`sh`), `T-15` (`st_ld`) and `T-49` pass, and **`T-51` observes the odd halfword offset (1) in both directions** — which this row was *not* observing before WP-13: the lane was halfword-granular and offset 1 wrote bytes 0-1 (`G-34`, opened and closed 2026-11-19). Mutants `store-lane-offset`/`store-strb-all`/`store-width-cast` and `halfword-lane-ignore-bit0` are detected, and `riscv_small_strb_checker` asserts strobe↔width coherence in both agent modes, per beat for a split access (`FR-42`). `G-08` closed, `G-22` closed 2026-11-19 | verified |
| FR-12 LB LH LBU LHU extend | `T-06`, `T-49` | `rtl/memory_access.sv:78-96` selects the lane from `alu_wb[1:0]`, `:130-155` extends it from the loaded word by indexed part-select; `T-06` drives 12 loads (`LB`/`LBU` at 4 offsets, `LH`/`LHU` at 2) and the scoreboard compares the stored value against the ISS. **`T-51` adds the odd halfword offset (1)**, which this row was not observing before WP-13: `16 * ld_lane[1]` ignored `addr[0]` and `LH`@1 read bytes 0-1 (`G-34`, closed 2026-11-19). `T-49` (477 commits against Spike) corroborates the loads of `st_ld`. Mutant `halfword-lane-ignore-bit0` | verified |
| FR-13 effective data address | — | `rtl/instruction_decode.sv:245-248`, `rtl/execution.sv:138-175`, `rtl/misaligned_split.sv:124`; no test (`G-04`). The WP-9 trace comparison cannot serve: the canonical line omits store address/data, so `-2048`/`+2047` on the data port are unobservable there | implemented |
| FR-14 x0 reads zero | — | `rtl/reg_file.sv:64-89`, `rtl/reg_file.sv:100-103`; no test (`G-04`). The WP-9 dump suppresses `rd`/value when the destination is `x0`, so a spurious `x0` write is invisible in the trace | implemented |
| FR-15 write-read same cycle | — | `rtl/reg_file.sv:71-73`, `rtl/reg_file.sv:83-85`; no test (`G-04`). Observable in principle through the WP-9 trace (a wrong read would diverge), but no test builds the back-to-back pair as its subject | implemented |
| FR-16 arithmetic forwarding | `T-11` | `rtl/control.sv:232-265`, `rtl/execution.sv:138-175`; `T-11` (`rv32ui-p-addi`) and the mutant `forward-rs1`; the `rs2`/distance-2 cells are unexercised (`G-04`) | verified |
| FR-17 load result to consumer | `T-16` | `rtl/control.sv:152-172`, `rtl/control.sv:232-265`; both gaps that kept it `partial` are closed — `G-19` by WP-6 (the register file keeps its own `clk_en_wb`) and `G-30` by WP-7 (`branch_op_stall` suppresses a redirect decided against an unresolved load). `T-16` (`rv32ui-p-ld_st`) is the image whose dependent branch failed on the stale value; mutant `branch-taken-stale` | verified |
| FR-18 store data forwarding | `T-08` | `rtl/execution.sv:177-194`, `rtl/control.sv:254-265`; `T-08` (`li gp,1; sw gp,tohost`) and the mutant `sanity-addi` | verified |
| FR-19 branch operand forwarding | `T-48` | `rtl/instruction_decode.sv:163-182`, `rtl/control.sv:137-191`; `G-26` closed. `T-48` (`spike:rv32ui-p-beq`, 285/285 commits against Spike) corroborates that branch decisions match an independent ISS, but it does not build the 0/1/2-distance matrix the acceptance asks for (`G-04`) | implemented |
| FR-20 one fetch address per cycle | — | `rtl/instruction_fetch.sv:76`, `rtl/instruction_fetch.sv:108-127`; no test (`G-04`). A fetch-port protocol property, never visible in a commit trace | implemented |
| FR-21 load waits for data_ready | — | `rtl/control.sv:309-320` stalls only while the load's write-back slot is present (`mux_sel_rd_wb`), which covers a grant withheld for **one** cycle. **A grant withheld for two or more cycles is lost:** the load is presented for one cycle and the stall acts one cycle later, when the request is already off the bus — measured as a deadlock by `verif-author` when the testbench memory withheld the grant on reads (`G-35`, opened 2026-11-19). The acceptance cell names "immediately" and "one cycle late", which are the observed cases; the requirement's sentence asks for completion only on the ready, which is not implemented for the longer hold. Also in `G-04` | partial |
| FR-22 exception discards fetch | T-03 | `rtl/control.sv:353` emits `trap_valid` for one cycle per trap (`:340-359`), and `:294` flushes IF/ID again one cycle later (`trap_taken_q`, `:98`/`:119-123`) so the fetch already accepted before the redirect is discarded — the first WP-14 version observed 4 of the 6 traps its program then carried and lost the rest to that fetch. `T-03` observes 7/7. **The external arm is unobserved**: `T-03` never asserts `exception[3:0]`, so the row stays `implemented` (`G-37`) | implemented |
| FR-23 mepc and mcause | T-03 | `rtl/csr_file.sv:134-159` reads `mepc`/`mcause` and `:205-237` writes them at the trap. `T-03`'s handler reads both and returns to `mepc + 4`, so a wrong address or cause fails the run. WARL write/read-back is unexercised (`G-37`) | verified |
| FR-24 illegal-instruction trap | T-03 | `rtl/instruction_decode.sv:283-365` (`proc_legality`) raises cause 2 on an unknown opcode, a reserved `funct3`/`funct7`, an absent CSR address (`csr_implemented`, `rtl/riscv_definitions_pkg.sv:367`) and a write to a read-only one (`csr_read_only`, `:387`); `T-03` observes each. **Reserved `SYSTEM` configurations (`ECALL`/`EBREAK` with non-zero `rd`/`rs1`) still retire** — a divergence the model mirrors, so no test can see it (`G-38`) | partial |
| FR-25 ECALL and EBREAK trap | T-03 | `rtl/instruction_decode.sv:283-365` carries cause 11 for `ECALL` and 3 for `EBREAK`; `T-03` observes both, with `mepc` at the instruction itself and neither retiring. The debug branch is vacuous without debug mode (`G-23`) | verified |
| FR-26 FENCE ordering | — | `rtl/instruction_decode.sv:465-467`; decoded as no-operation; no test (`G-06`) | deferred |
| FR-27 cache-line fetch burst | — | `rtl/instruction_fetch.sv:76-101`; one word address per cycle, no last-beat signal; no test (`G-15`) | deferred |
| FR-28 hold outstanding fetch | — | `rtl/control.sv:298-301`, `rtl/instruction_fetch.sv:108-127`; PC advances with the grant withheld; no test (`G-09`, `G-15`) | deferred |
| FR-29 mtvec direct mode | T-03 | `rtl/csr_file.sv:103` drives `mtvec_base = {mtvec_q[31:2], 2'b00}` and `rtl/control.sv:355` redirects to it on `trap_valid`. `T-03` programs a non-default vector computed with `AUIPC`+`ADDI`, and the handler's commits land there. `MODE` >= 2 legalisation and a second vector value are unexercised (`G-37`) | verified |
| FR-30 mtvec vectored mode | — | `rtl/control.sv:332`; constant vector, no mode field; no test (`G-01`, `G-14`) | deferred |
| FR-31 fence.i invalidates cache | — | `rtl/instruction_decode.sv:465-467`; no-operation, no cache; no test (`G-06`, `G-15`) | deferred |
| FR-32 mhartid report | T-03 | `rtl/csr_file.sv:134-159` returns the `hart_id` input (`rtl/riscv_small.sv:55-56`) and a write to 0xF14 traps. `T-03` drives `hart_id = 5`, reads 5 and traps on the write. The identifier sweep needs `NUM_HARTS` > 1 (`G-16`) | verified |
| FR-33 per-hart behaviour | — | `rtl/riscv_small.sv:38-62`; single hart, no hart-count parameter; no test (`G-16`) | deferred |
| FR-34 configuration invariance | — | `rtl/riscv_small.sv:38-62`; no configuration parameters; no test (`G-15`, `G-16`) | deferred |
| FR-35 Zaamo and Zalrsc | — | `rtl/riscv_definitions_pkg.sv:133-187`, `rtl/instruction_decode.sv:341-347`; no A encodings; no test (`G-16`) | deferred |
| FR-36 machine software interrupt | — | `rtl/riscv_small.sv:48`; only the level-sensitive exception input; no test (`G-14`, `G-16`) | deferred |
| FR-37 misa advertises extensions | T-03 | `misa_value` (`rtl/riscv_definitions_pkg.sv:412-421`) composes `MXL`, `I` and the `ENABLE_A`/`ENABLE_M`/`ENABLE_C` parameters, with no literal. `T-03` reads `0x4000_0100` and observes a write accepted, ignored and not trapping. **One configuration is observed** (`G-37`) | verified |
| FR-38 store waits for grant | `T-53` | `rtl/control.sv:309`: `if (!data_ready && (mux_sel_rd_wb \|\| data_wr_en_ma))` holds the store **in MA**, the stage that presents it on `data_wr`/`data_addr`/`data_wr_strb`, so it leaves only in a cycle the memory grants it. `T-53` withholds the grant for two cycles and observes `2 write(s) published, 2 waited more than one cycle, 2 with a grant cycle, 0 accepted before the grant`; the scoreboard is green on the same run (the fields were always right — only the completion was wrong), so the protocol checker is the verdict. Mutant `store-grant-ignored`. `G-18` closed 2026-11-19 | verified |
| FR-39 machine timer interrupt | — | `rtl/riscv_small.sv:48`; no interrupt input and no timer; no test (`G-14`) | deferred |
| FR-40 machine external interrupt | — | `rtl/riscv_small.sv:48`; no external interrupt path; no test (`G-14`) | deferred |
| FR-41 reset behaviour | `T-50` | `rtl/instruction_fetch.sv:83` and `rtl/control.sv:116` hardcodes `or negedge rst_n`; there is no de-assertion synchroniser and no reset-style macro in `rtl/` (`G-21`). **The reset-vector clause is now implemented:** `RESET_VECTOR` is a parameter of `riscv_small` (default `32'h8000_0000`, the spec's §5.2 value) and `rtl/instruction_fetch.sv:110` resets `pc` to it (`G-33`, closed 2026-11-18). `T-50` observes the first fetch after reset and fails on the `reset-vector-zero` mutant. **`partial` for two reasons:** the synchronised release is still absent (`G-21`), and the acceptance's "two different values of the parameter in two builds" arm is **not demonstrated** — `T-50` runs with the default, where `pc <= RESET_VECTOR` and `pc <= 32'h8000_0000` are indistinguishable, and the second elaboration is deferred (WP-11 §9.1) | partial |
| FR-42 misaligned split | `T-52` | `rtl/misaligned_split.sv` (new module, `u_misaligned_split`): `split_needed = access_ma && (({1'b0, lane_ma} + bytes_ma) > 3'd4)`, beat 1 at the access address, beat 2 at `(addr & ~3) + 4` with the high-bytes strobe `(4'b0001 << spill) - 1` and the operand rotated out of the first beat's lanes; the load's two answers are merged into an aligned word before extension (`rtl/memory_access.sv:84-106`). `T-52` runs `rv32ui-p-ma_data`, whose 54 RV32 cases cover `lh`/`lhu`@31, `lw`@1/2/3 and @29/30/31, `sw`@1/2/3, and the image prints `SANITY: PASS`; mutant `no-misaligned-split` fails it at `testnum=3`. `G-22` closed 2026-11-19 | verified |
| FR-43 `M` extension | — | `rtl/instruction_decode.sv:341-347` ignores every function bit but bit 5, so the `M` group aliases onto the base ALU (`G-06`); no test (`G-04`) | deferred |
| FR-44 `C` and `IALIGN=16` | — | `rtl/instruction_decode.sv:46` takes a 32-bit `inst` and `:254` decodes on the opcode field, so no 16-bit parcel is formed and a 32-bit instruction spanning two fetched words is not assembled (`G-06`); no test (`G-04`) | deferred |
| FR-45 `MRET` | — | `rtl/instruction_decode.sv:351-353` decodes the SYSTEM group as a no-operation; there is no `MRET` decode and no `mepc`/`mstatus` (`G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-46 `WFI` | — | `rtl/instruction_decode.sv:351-353` decodes the whole SYSTEM group as a no-operation, so `WFI` currently retires as a legal no-op by accident; there is no `mstatus.TW` and no CSR file, which is what the row still needs (`G-13`); no test (`G-04`) | deferred |
| FR-47 `Zicsr` instructions | T-03 | `rtl/instruction_decode.sv:468-480` decodes the six forms (`csrOpType_e`, `rtl/riscv_definitions_pkg.sv:286`) and `rtl/csr_file.sv:166-178` applies the read-modify-write. `T-03` exercises all six on `mscratch`, including `CSRRW` with `rd=x0` and `CSRRS` with `rs1=x0`; `cp_csr_op` 6/6 | verified |
| FR-48 interrupt entry and priority | — | `rtl/control.sv:332-345` hardcodes the trap vector and ties the cause to zero; there is no `mstatus`/`mie`/`mip` and no interrupt input (`G-01`, `G-02`, `G-13`, `G-14`); no test (`G-04`) | deferred |
| FR-49 `Zicntr` | T-03 | `rtl/csr_file.sv:114-116` and `:125-127` make `cycle`/`cycleh` a view of `mcycle` and `instret`/`instreth` of `minstret + valid_ma + valid_wb` as one 64-bit quantity; `time`/`timeh` are `mtime`. `T-03` writes each machine counter and reads the view back (the second red), and traps on a write to a view. **`instret` not counting `ECALL`/`EBREAK` is observed only as 'they never retire'** (`G-37`) | verified |
| FR-50 CSR file and map | T-03 | the map is one table in `rtl/riscv_definitions_pkg.sv:330-424` — `csr_implemented` (`:367`), `csr_read_only` (`:387`, `addr[11:10]==2'b11`) and `csr_write_mask` (`:395`) — consumed by the decoder and by `rtl/csr_file.sv:134-159`. `T-03` walks it: implemented addresses read, absent and read-only writes trap with `mepc` at the `CSR*`; `cp_csr_group` 5/5. **`FR-50` is `partial` on `G-39`**: `instret` 0xC02 is not a view of `minstret` 0xB02 as built. **`rv32mi-p-mcsr` did not run** (no `rv32mi` environment) and the `NUM_TRIGGERS` > 0 window is not taken (`G-37`) | partial |
| FR-51 `mscratch` | T-03 | `rtl/csr_file.sv:205-237` stores `mscratch` at 0x340 with no side effect; `T-03` reaches it with all six forms and observes the reset value 0 on the first read. The handler returns with `JALR`, not `MRET` (`FR-45` deferred) | verified |
| FR-52 `mtval` | T-03 | `rtl/csr_file.sv:166-178` masks writes to `mtval` to zero (`csr_write_mask`, `rtl/riscv_definitions_pkg.sv:395`) and no trap writes it. `T-03` reads 0, writes `0xFFFF_FFFF` without a trap, and reads 0 again after the traps | verified |
| FR-53 debug mode | — | the top has no debug port (`rtl/riscv_small.sv:51-62`), no debug mode and no `dcsr`/`dpc`/`dscratch`; the SYSTEM group is a no-operation (`rtl/instruction_decode.sv:351-353`) (`G-23`); no test (`G-04`) | deferred |
| FR-54 run control | — | no `dbg_*` port on the DUT (`rtl/riscv_small.sv:51-62`) and no debug state to control (`G-23`); no test (`G-04`) | deferred |
| FR-55 abstract commands | — | no debug port, no CSR file and no command channel (`rtl/riscv_small.sv:51-62`, `rtl/instruction_decode.sv:351-353`) (`G-23`); no test (`G-04`) | deferred |
| FR-56 program buffer | — | the fetch path takes instructions only from the instruction-memory port (`rtl/instruction_fetch.sv`), so a second instruction source does not exist (`G-23`); no test (`G-04`) | deferred |
| FR-57 `Sdtrig` triggers | — | no trigger unit and no `tselect`/`tdata`/`tinfo` decoding (`rtl/instruction_decode.sv:351-353`) (`G-24`); no test (`G-04`) | deferred |
| FR-58 single step | — | no debug mode to re-enter (`G-23`); no test (`G-04`) | deferred |
| FR-59 `dbg_auth` strap | — | no debug port, so there is nothing for the strap to gate (`rtl/riscv_small.sv:51-62`) (`G-23`); no test (`G-04`) | deferred |

## Coverage bins

`A-09`/`Q-11` fix the functional-coverage bar: **one bin per instruction that `doc/spec.md` §4.1 says
`rtl/instruction_decode.sv` decodes today, plus one per memory width — 40 bins**. The two no-operation rows of
that table (`FENCE`/`FENCE.I`, and `ECALL`/`EBREAK`/`CSR*`) carry no bin, because the RTL decodes them as
no-operations (`G-06`, `G-13`); a word outside the decoded subset decodes to a sentinel that names no bin, so it
is counted by nothing. The collector is `riscv_small_coverage` (`tb/env/top/riscv_small_coverage.sv`), a
subscriber to the monitor; it never samples the driver, the sequence or the reference model. Since WP-8 the
monitor also publishes retire events on the same port; the collector filters them out before sampling
`cg_mem`, so a retire cannot hit a lane or direction bin with zeroed data fields. A bin is still a fetch.

Measured 2026-11-21 by `make coverage`, which runs **47** of the 50 manifest rows — the three `spike:` rows (`T-47`..`T-49`) are
skipped by design — at RTL `sha256:2e91301d…` and TB `sha256:0091e260…`: **40 of the 40 bar bins** and **66 of the 66 report bins** over 9 coverpoints, `uncovered` empty,
`percentages=100`. `cp_inst` 37 of 37, `cp_width` 3 of 3, `cg_mem` 13 of 13, `cg_beat` 2 of 2, and WP-14's `cg_csr`
`cp_csr_op` 6 of 6 and `cp_csr_group` 5 of 5 with `cp_trap_cause` 3 of 3. This closes `G-03`; it does
**not** close `A-09`, which needs every **phase-1** `FR` row `verified`. `G-28` is closed by WP-8, but the bins are still
fetch-based.

Two limits still apply to every row. A hit is a **fetch**, not a retire: `if_id_flush` (`rtl/control.sv:283-287`)
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
| `cp_beat.split_beat1` | beat 1 of a split access | `FR-42` | `T-52` | hit (63×) |
| `cp_beat.split_beat2` | beat 2 of a split access | `FR-42` | `T-52` | hit (63×) |

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

| # | Check | Fails when | 2026-11-21 |
|---|---|---|---|
| 1 | `make docs-check`, `make docs-figs-check` | exit != 0 | ok |
| 2 | `spec.md` x this file: same FR set, same status | count or status diverge | ok |
| 3 | every `verified` row names a `T-xx` in `scripts/verify/tests.tsv` and a file in `tb/tests/` | ghost test | ok |
| 4 | no open question, no expired `A-xx` | a `Q` open, or an `A-xx` past its due date | ok |
| 5 | latest `build/regress/*/results.json` | `fail`/`timeout` > 0, stale `rtl_digest`, older than 7 days | ok |
| 6 | `build/sanity/summary.json` (`NFR-05`) | absent, not measured, or any image fails | ok — **43 of 43 pass**, measured 2026-11-19 at RTL `sha256:f84ea86b…` and TB `sha256:7860d1b0…` (`rv32ui-p-ma_data` passes since WP-13). Note the **check** is about the measured images: `NFR-05` itself stays `partial`, because its `shall` names four suite legs and only the `rv32ui` one is measured (`rv32um`/`rv32uc`/`rv32mi` are owed by `FR-43`/`FR-44`/`FR-24`) |
| 7 | `build/cov_report/summary.json` (`NFR-06`) | merge absent, no coverpoint, or measured at an older `rtl_digest` | ok (**66/66** bins over 9 coverpoints, bar 40/40, 100 %, `uncovered` empty — `cp_beat` added by WP-13) |
| 8 | `doc/measurements/NFR-01..04-*.md` | a file is missing, has no method or no date | ok (4 files with method and date) |
| 9 | `doc/measurements/NFR-07-*.md` | absent, or its Result still says `not measurable` (`G-05`) | ok — **0 latches, 0 loops** measured 2026-11-18 on `xczu3eg-sbva484-1-i` with Vivado 2024.1 (4069 cells, 1405 flip-flops) |
| 10 | `A-09`: the **phase-1** `FR` set `verified` | any **phase-1** `FR` is not `verified` | blocked (**24 of 47** phase-1 rows); 12 rows are outside the bar by phase (`FR-32`..`FR-36` phase 2, `FR-53`..`FR-59` debug); release-blocker gaps `G-04`, `G-11` |
| 11 | negative control: every WP test fails on the mutant it carries | no mutant run, or the test passes on the mutant | ok (48 rows: `T-03`, `T-06`, `T-08`..`T-15`, `T-16`..`T-53`) |

The work-package gate runs checks 1-5, 7 and 11. Checks 6 and 8-10 are release evidence and are reported as `skipped` in a
WP. Check 7 runs in both modes on purpose: a WP that changes behaviour without re-measuring coverage has no
evidence that its new bins were exercised, and a coverage merge older than the current `rtl_digest` is reported as
stale.

Exit codes: `0` `signoff-ready`, `1` `blocked`, `2` the gate could not run. The gate is **blocked** on 2026-11-21
and must stay blocked: the release-blocker gaps are `G-04` and `G-11` — `rv32ui-p-ma_data` passes since WP-13 and is no longer among them — and the four `TBD` non-functional targets
plus them leave **23 of the 47 phase-1 rows** unverified (`A-09`, re-scoped to a phase bar on 2026-11-19). The bar is read from `doc/spec.md`, never copied here: `A-09` carries a `Gate input — outside the bar:` line naming the 12 rows the bar does not cover, and `signoff_check.cmake` blocks if that line is missing rather than quietly falling back to "every `FR`". A gate that passes here is a broken gate.

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
| G-01 | **closed 2026-11-21 by WP-14**: `trap_addr` was the constant `1000`. The trap now enters at `mtvec.BASE` — `rtl/csr_file.sv:103` drives `mtvec_base = {mtvec_q[31:2], 2'b00}` and `rtl/control.sv:355` redirects to it — and `T-03` programs a non-default vector. **Narrowed to `FR-30`**: vectored mode is `E7`'s | traps land where software points them; only direct mode exists, so `FR-30` stays `deferred` | designer | 2026-12-31 |
| G-02 | **closed 2026-11-21 by WP-14**: `scause` was tied to zero in a register nothing read. `mcause` is architectural and written at the trap (`rtl/csr_file.sv:205-237`), and `T-03` reads it in the handler for seven distinct causes | a handler can tell the causes apart; `FR-48`'s interrupt causes remain `E7`'s | designer | 2026-11-21 |
| G-03 | **closed 2026-11-06 by WP-7**: the `A-09` bar is full. `cg_inst`/`cp_inst` (`tb/env/top/riscv_small_coverage.sv:194-236`) declares one bin per instruction of `spec.md` §4.1 and the monitor samples every accepted fetch; WP-5 reached 17/40, WP-6 21/40, and WP-7's nineteen images took it to **40 of 40** (`cp_inst` 37/37, `cp_width` 3/3, `cg_mem` 13/13), `uncovered` empty. The path is in the section "Coverage bins" | closed; the bins are hit, so `NFR-06` has no open bin. `G-28` still bounds what a hit means — a bin is a fetch, not a retire | verification lead | closed 2026-11-06 |
| G-04 | Reference model and scoreboard cover only LW/SW (the in-testbench model executes the load/store subset and publishes only `SW` predictions) — **narrowed 2026-11-07 (WP-8)** and **narrowed again 2026-11-18 (WP-9):** `make spike-trace` (`T-47`..`T-49`) now compares the DUT's committed instruction trace (`+RETIRE_LOG`: `pc`, `rd`, value, instruction word) against Spike (`--log-commits`) for three images (`add` 459/459 @`0x8000057c`, `beq` 285/285 @`0x8000035c`, `st_ld` 477/477 @`0x80000784`). What remains is the four-item residual: (1) store address and data are omitted from the canonical line (`mem` suffix dropped; measured: `store-width-cast` gives an identical 477/477 trace on `st_ld`), (2) `rd = x0` writes are suppressed in the dump by construction (`FR-14`), (3) bus-protocol properties (`FR-20`, `FR-21`) never appear in a commit trace, and (4) only 3 of the 43 sanity images are trace-compared | the six as-built requirements outside `LW`/`SW` (`FR-13`, `FR-14`, `FR-15`, `FR-19`, `FR-20`, `FR-21`) still cannot become `verified`, so the `Q-11` bar ("every **phase-1** `FR` row `verified`", `A-09`) cannot be met — a **release blocker** | verification lead | 2026-12-31 |
| G-05 | No timing, area, or power measurement exists. **Narrowed 2026-11-18 by WP-12:** `NFR-07` is measured — the synthesis/lint flow was generalised and now runs on this core, reporting **0 inferred latches and 0 combinational loops** over 4069 cells and 1405 flip-flops on `xczu3eg-sbva484-1-i` (`doc/measurements/NFR-07-lint.md`). What remains is timing, area and power: `NFR-01`..`NFR-04` are untouched by a latch count, and no frequency is recorded (`A-08`, `Q-08`) | `NFR-01` to `NFR-04` still cannot be verified; `NFR-07` no longer waits on this row. The measurement covers **one part** and the only buildable configuration — of §5.2's eight parameters only `RESET_VECTOR` is honoured, so a configuration that becomes buildable later needs its own run before inheriting the zero | designer | 2026-12-31 |
| G-06 | **Narrowed 2026-11-21 by WP-14.** Unimplemented encodings used to execute as no-operations. `rtl/instruction_decode.sv:283-365` now raises cause 2 on an unknown opcode and a reserved `funct3`/`funct7`, and `MRET`/`WFI` are legal no-ops. What remains is capability, not policing: `RV32M`, `RV32C` and `FENCE`'s ordering | `FR-43`, `FR-44` and `FR-26` stay `deferred`; a wrong encoding traps instead of vanishing | designer | 2026-12-31 |
| G-07 | **closed 2026-11-05 by WP-7**: `JALR` did not clear bit 0 of its target. `rtl/jump_decision.sv:115-116` now masks `& ~32'h1` when `base_addr_sel == RS1` (the `JALR` case only; `JAL` and branches keep every address bit). Closing it also exposed `G-31` | closed; `T-17` (`rv32ui-p-jalr`) and `T-37` (`rv32ui-p-jalr_unaligned`, an odd target) pass, and the mutant `jalr-keep-bit0` makes `T-37` fetch `pc=0xc1` and fail `testnum=3`. `FR-07` stays `partial` for its other clause (`G-13`) | designer | closed 2026-11-05 |
| G-08 | **closed 2026-11-05 by WP-6**: sub-word stores drove one lane whatever `data_addr[1:0]` said, because `data_wr` was `rs2` unshifted (`rtl/execution.sv:157-174` before the fix). The load half was closed earlier by `FR-12`/`T-06`. The store now lane-places the value and asserts `data_wr_strb` (`rtl/execution.sv:207-243`). | closed; `T-13` (`sb`), `T-14` (`sh`) and `T-15` (`st_ld`) pass, and the mutants `store-lane-offset`/`store-strb-all` fail them | designer | closed 2026-11-05 |
| G-09 | No fetch stall exists: while the fetch grant is withheld only the IF/ID registers are flushed (`rtl/control.sv:121`) and the program counter keeps advancing unless IF/ID is held (`rtl/instruction_fetch.sv:108-127`) | reframed in v0.2: this is no longer a doubt about the memory contract (`A-03` is retired) but the **prerequisite for the instruction cache**, because a cache miss must be able to hold the program counter for many cycles; `FR-28` is the requirement that closes it | designer | 2026-12-31 |
| G-10 | **closed 2026-10-30 by WP-4**: the sanity flow now compiles each `rv32ui-p-*` with the project environment (`scripts/verify/sanity/`), extracts `tohost` from the ELF and runs it through `riscv_small_sanity_test` with `+HEX`/`+TOHOST`. The sequence reads the image with `$readmemh` and builds the program item. | `NFR-05` was **measured** at the time of closure (41 of 42 bundled pass, `FR-42` failing); it is 42 of 42 since WP-13 on 2026-11-19 | verification lead | closed 2026-10-30 |
| G-11 | `T-02` adds no stimulus: `riscv_small_corner_seq::body()` only calls `super.body()` (`tb/tests/sequence_lib/riscv_small_corner_seq.sv:31`), so it repeats `T-01` | no requirement can cite `T-02`; boundary values are untested, so the coverage leg of the `Q-11` bar rests on `T-01` alone — a **release blocker** | verification lead | 2026-12-31 |
| G-12 | The top-level `clk_en` gates only the trap-state registers and `branch_taken_q` (`rtl/riscv_small.sv:364`, `rtl/control.sv:116-121`, `:339`), while stage enables are generated inside `rtl/control.sv`; the port is described as a global clock enable but does not gate the pipeline | `C-02` is a description of the port, not a promise; integrators cannot pause the core with `clk_en` | designer | 2026-12-31 |
| G-13 | **Narrowed 2026-11-21 by WP-14.** The CSR file, the six `Zicsr` forms and the trap path exist (`rtl/csr_file.sv`, `rtl/instruction_decode.sv:468-480`); what remains is the instruction-address-misaligned cause, which needs a fetch that can report the offending address | `FR-26`, `FR-27`, `FR-28`, `FR-45` and `FR-48` stay `deferred`; every CSR row of `F-09` is now `verified` | designer | 2026-12-31 |
| G-14 | No machine-mode interrupt subsystem: the only trap request is the level-sensitive `exception` input (`rtl/riscv_small.sv:48`), with no `mip`/`mie`, no timer, and no external controller interface | `FR-39`, `FR-40`, `FR-36`, `FR-48`, and the vectored mode of `FR-30`, stay `deferred`; `D-01`'s preemption cannot be demonstrated | designer | 2026-12-31 |
| G-15 | No instruction cache and no line-based fetch: `rtl/instruction_fetch.sv:76-101` drives one word address per cycle with no burst and no last-beat signal, and neither `ICACHE_BYTES` nor `ICACHE_LINE` exists. **Re-attributed 2026-11-05:** `rv32ui-p-fence_i` was failing on `G-31` (an unforwarded `JALR` `rs1`), not here and not on the `G-07` mask — every `jalr` in `src/riscv-tests/isa/rv64ui/fence_i.S:27`, `:41`, `:57`, `:60` targets an aligned label, so the mask is a no-op there and the image now **passes**; on a cacheless core `fence.i` is correctly a no-operation | `FR-27`, `FR-28`, `FR-31`, `FR-34` stay `deferred`; §5.2 of the specification is a target, not a description of the RTL; `NFR-02`'s condition cannot be met. It is **not** an `NFR-05` failure any more | designer | 2026-12-31 |
| G-16 | No multi-hart support: the top is a single hart (`rtl/riscv_small.sv:38-62`) with no hart-identity input, no `NUM_HARTS`, no `A` encodings (`rtl/riscv_definitions_pkg.sv:133-187`) and no software interrupt | `FR-32`, `FR-33`, `FR-35`, `FR-36` stay `deferred`; the `MCU_SMP` configuration of §5.2 cannot be built | designer | 2026-12-31 |
| G-17 | No decision log: `doc/decisions.md` does not exist, so `D-01` to `D-11` live in `doc/spec.md` §0.1 | decisions are not indexed beside the requirements they justify, and a superseded decision has nowhere to be retired | designer | 2026-12-31 |
| G-18 | **closed 2026-11-19 by WP-13.** Stores did not wait for the data grant: the stall condition guarded on `mux_sel_rd_wb` alone — i.e. it required a load destination — so a store asserted its strobe for one cycle whatever `data_ready` did and a withholding memory lost it. The condition now covers `data_wr_en_ma` and the store is held **in MA** (`rtl/control.sv:309`). | closed; `T-53` observes `2 waited / 2 granted / 0 accepted before the grant` and the mutant `store-grant-ignored` fails it. `FR-38` is `verified`. The read half of the same defect is `G-35` | designer | closed 2026-11-19 |
| G-19 | **closed 2026-11-05 by WP-6**: a load-use insertion cleared `id_ex_clk_en`, which was also the register file's clock enable (`rtl/instruction_decode.sv:222-231`, `rtl/riscv_small.sv:208`, `rtl/reg_file.sv:99`), so the write-back of a younger instruction was dropped. `instruction_decode` now takes `clk_en_wb` (the global `clk_en`) for `u_reg_file`, and the ID/EX register keeps `id_ex_clk_en`. | closed; before the fix `x4` was written 3 times against 33308 for `x5` in `T-13`, after it 39 against 39 (`build/regress/2026-11-05T17-39-54Z` and `…18-37-01Z`), and `rv32ui-p-lb`/`-lbu` went green | designer | closed 2026-11-05 |
| G-29 | **closed 2026-11-05 by WP-6**: `pc_fetch` was gated by `if_id_clk_en` while the external instruction memory kept answering the held address, so on a load-use release the IF/ID register captured `pc_id` from one address and `inst_id` from another (`0x254` decoded with the word of `0x258`); the fix is `assign inst_addr = clk_en ? pc : pc_fetch;` (`rtl/instruction_fetch.sv:76`), which re-requests the address whose word is on the bus during the freeze. | closed; `T-13`/`T-14` green and 11/11 regression, where before the fix they timed out at `pc=0x24c`; the rejected variant, which aligned the pair but dropped `0x254`, is what showed that the request must be held rather than the delay line. The same defect was **manufacturing a false PASS** in `rv32ui-p-ld_st` (stale PC at `0xa4` → target `0xee4` → `<pass>` → `tohost=1`), which is why that image flipped from pass to fail when this closed | verification lead | closed 2026-11-05 |
| G-30 | **closed 2026-11-05 by WP-7**: a load-use freeze evaluated the branch with the load result unresolved, so `branch_taken` redirected to a stale target and `branch_taken_q` flushed a valid fetch. `rtl/control.sv:114` declares `branch_op_stall`, set by exactly the six `data_rd_en_ma`/`data_rd_en_ex` freeze arms and **not** by `data_ready`/`inst_ready`; it gates the current-cycle redirect (`:268`) and the registered echo (`:108`). `branch-taken-stale` reverts only the echo, because reverting `:268` alone was measured **not** to reproduce the failure (the branch re-evaluates and recovers); `:268` is therefore proven by reading, not by a mutant. Found 2026-11-05 by WP-6 once `G-29` stopped masking it | closed; `T-16` (`rv32ui-p-ld_st`) passes, and the mutant `branch-taken-stale` — which must revert the **registered echo**, not the current-cycle gate — reproduces `testnum=2 value=5` | verification lead | closed 2026-11-05 |
| G-31 | `JALR`'s `rs1` was never forwarded: the jump-compare forward mux was gated on `cond_jump` only, so a `JALR` immediately after its producer compared a stale register value and went to the wrong target. Found by the WP-7 red — `T-17` re-ran identically after the bit-0 mask was added, which showed the mask was not the reason it failed | closed in the same WP: `rtl/control.sv:152` opens the forward for `cond_jump \|\| jalr`, and `rtl/instruction_decode.sv:289` exports `jalr` (two new ports, catalogued in `uarch.md` §4). Evidence: `T-17` green, mutant `jalr-no-forward`. Never released, so it was never a blocker | verification lead | closed 2026-11-05 |
| G-32 | **closed 2026-11-07 by WP-8.** The monitor sampled `inst_addr` and `inst_data` in the same `@(posedge clk)` while the driver answered with `OUTPUT_DELAY` after the edge, so the published fetch pair was `(address t, word t-1)`; and on the data port it published once per cycle the enable was high instead of once per accepted handshake. The monitor now correlates by **handshake**: an outstanding-request queue pushes on the request and pops on the response, so the pair is exact at any latency. | closed for the fetch port; `FETCH_PAIR` is green on the six tests that configure a program image (`T-01`, `T-02`, `T-06`, `T-44`, `T-45`, `T-46`; the other 39 print `NONE compared`), and the mechanism survives a cache or a wait state. The **data port is documented, not fixed** — with the flat port no rule is correct, because `data_ready` is a level the driver echoes while the core holds the enable; it needs the req/rsp form of `E8`/`G-18` | verification lead | closed 2026-11-07 |
| G-33 | **Closed 2026-11-18 by WP-11.** No `RESET_VECTOR` parameter and a hardcoded reset to `0`: `rtl/instruction_fetch.sv` wrote `pc <= 'b0` and the identifier appeared nowhere under `rtl/`, while `FR-41`, `Q-33` and the spec's §5.2 table specify a build-time parameter defaulting to `0x8000_0000`, so the first fetch left at `0x0`. Found while documenting the WP-9 reference model — it had been invisible because **both** harness legs worked around it: `scripts/verify/sanity/link.ld` linked every image at `0x0` *because* the DUT reset there, and `scripts/verify/spike/build_spike.sh` remapped the reference to the same base. WP-11 added the parameter to `riscv_small` (default `32'h8000_0000`), propagated it to `instruction_fetch`, and made `rtl/instruction_fetch.sv:110` reset `pc` to it; the harness moved to the spec's address (`link.ld` at `0x80000000`, hex rebased by `objcopy` so `tohost` needs no mask), and the three Spike flags `-m0:0x40000`, `--no-dm` and `--disable-dtb` disappeared with the low base | closed for what the evidence covers: `T-50` observes the first fetch after reset and fails on the `reset-vector-zero` mutant, so the parameter exists and the reset consumes it. **Parameter configurability is NOT demonstrated** — `T-50` runs with the default, where `pc <= RESET_VECTOR` and `pc <= 32'h8000_0000` are indistinguishable and no mutant separates them; the acceptance's "two different values in two builds" arm needs a second elaboration, deferred by the designer on 2026-11-18 with its cost and reasoning in `.opencode/plan/wp-11-reset-vector.md` §9.1. `FR-41` therefore stays `partial`, also for `G-21`. Not a `Q-11` blocker — the `G-21` precedent | designer | closed 2026-11-18 |
| G-34 | **Opened and closed 2026-11-19 by WP-13.** The halfword lane ignored `addr[0]`: `rtl/memory_access.sv` read `data.u_data[16 * ld_lane[1] +: 16]` and `rtl/execution.sv` strobed `4'b0011 << {addr[1], 1'b0}`, both halfword-granular, so `LH`/`LHU`/`SH` at offset 1 used bytes 0-1 instead of 1-2. Invisible until now because every halfword case in the corpus — `rv32ui-p-sh` at `0, 2, 4, 6, -6, -4, -2` and `T-06` at `0` and `2` — used an even offset; `rv32ui-p-ma_data` uses `1`. | closed in the same work package; `T-51` observes both directions and the mutant `halfword-lane-ignore-bit0` (two rows, load and store) fails it. `FR-11` and `FR-12` were overclaimed before this row existed and now carry the odd offset as evidence | verification lead | closed 2026-11-19 |
| G-35 | **Opened 2026-11-19 by WP-13. Open.** A read whose grant is withheld for **two or more** cycles is lost: the load is presented on the data port for one cycle and the stall at `rtl/control.sv` acts one cycle later, when the request is already off the bus, so the load latches an unknown value and the pipeline deadlocks — measured by `verif-author` while the testbench memory withheld the grant on reads. `FR-21`'s sentence asks for completion only when the memory reports the data ready; its acceptance cell names only "immediately" and "one cycle late", which are the working cases. | `FR-21` is `partial`. Closing it needs the read's completion to be observable later than one cycle after presentation — the request/response form of the data port (`E8`), the same change `G-18` closed for stores and `G-32`'s data half still wants | designer | 2026-12-31 |
| G-36 | **Opened 2026-11-19 by the WP-13 signoff audit. Open.** The scoreboard does not require every observed data write to be compared. `run_phase` takes one monitor publication and then blocks on one model prediction (`tb/env/top/riscv_small_scoreboard.sv:93-101`), and the model publishes one prediction per retired store. A split store is **two** publications against one prediction, so the pairing shifts by one for the rest of the run — or, when it is the last store, the second publication never gets a partner and the `forever` loop is killed at the end of the test. `check_phase` raises `RM_NO_PREDICTION` only when `pred_count == 0` (`:144`), and `report_phase` **prints** `obs_count` against `pass_count + fail_count` without failing when they differ (`:156-164`), so a run can end green with a publication never compared. Latent: no test reaches it today — every model-mode test stores at a word-aligned address (`tb/tests/sequence_lib/riscv_small_basic_load_store_seq.sv:52,97`, both address generators `* 4`, and `T-06` stays inside a word) and the crossing images are `sanity:` rows with no model. WP-13 made the trigger normal rather than exceptional: a crossing store is two publications by construction, and the split is currently judged by `T-52` and `riscv_small_strb_checker`, not by the scoreboard | A future directed crossing store would desynchronise the pairing; today the split's only oracles are the image's `tohost` and the beat rules of the strobe checker. `FR-42` does not rest on this — the scoreboard is not the oracle for a crossing access | verification lead | next WP: skip beat 2 in the scoreboard or publish per beat from the model, and add a non-vacuity guard that `obs_count == pass_count + fail_count` |
| G-37 | **Opened 2026-11-21 by WP-14. Open.** The rows the CSR/trap package promoted are verified on their main acceptance clause, and these arms are unexercised: `FR-22`'s external `exception[3:0]` request (`T-03` never asserts the pin, which is why that row is `implemented` and not `verified`); `FR-23`'s WARL write and read-back; `FR-29`'s `MODE >= 2` legalisation and a second vector value; `FR-32`'s identifier sweep, which needs `NUM_HARTS` > 1 (`G-16`); `FR-37`'s non-default configurations; `FR-49`'s `instret` across a trapping `ECALL`/`EBREAK` pair, observed only as "they never retire"; `FR-50`'s `rv32mi-p-mcsr`, **which did not run** — there is no `rv32mi` environment — and its `NUM_TRIGGERS` > 0 window; `FR-52`'s external-request read and handler-fetch-through-`mepc`; and `D12`, a trap raised while a split beat holds the pipeline, which is structural in `rtl/control.sv:353` and observed by nothing | rows are `verified` on the clause their test observes and on no more; nothing here contradicts a promoted row, but no promoted row may claim these arms | verification lead | 2026-12-31 |
| G-38 | **Opened 2026-11-21 by WP-14. Open.** `ECALL` and `EBREAK` with a non-zero `rd` or `rs1` are reserved encodings and must raise cause 2; the RTL accepts them and **the reference model mirrors it**, so no test can see the divergence. Found by `rtl-implementer` reading the spec against the model it was handed | `FR-24` is `partial` rather than `verified`; a test written from the current model would inherit the defect, so the model must be corrected first | designer | 2026-12-31 |
| G-39 | **Opened 2026-11-21 by the WP-14 documentation pass. Open.** `minstret` and `instret` are one architectural counter — `instret` is a read-only alias of `minstret` (vol. II sec. 2.1.1.10) — and they read **different values**: `rtl/csr_file.sv:147`/`:149` return the raw `minstret_q`, while `:152`/`:155` return `instret_view = minstret_q + valid_ma + valid_wb` (`:125-127`). `mcycle`/`cycle` do not have the problem because both read `mcycle_view`. The module's own comment and the reference model assume the aliasing, and no test reads `minstret`, so nothing caught it | a read of 0xB02 and a read of 0xC02 at the same point disagree by the instructions in flight. **`FR-50`'s "read-only views" clause is therefore not met as built** | verification lead | 2026-12-31 |
| G-20 | **closed 2026-11-04 by WP-4c**: `rtl/jump_decision.sv:111` added `imm[20:0]`, zero-extending a negative offset; the fix is `base_addr + imm` (the `imm` is already sign-extended by `imm_gen`). | closed; `T-12`/`rv32ui-p-beq`, the branch images and `FR-08` pass | designer | closed 2026-11-04 |
| G-21 | Reset is asynchronous on both edges: every DUT module hardcodes `or negedge rst_n` (`rtl/instruction_fetch.sv:83`, `rtl/control.sv:114`) and there is no de-assertion synchroniser and no `ASYNC_RESET`-style macro selection. `D-09` and `FR-41` require async assertion with a synchronised release | the release edge is asynchronous, so a de-assertion that arrives close to a clock edge can release different registers on different edges; the FPGA synchronous-reset variant cannot be built at all | designer | 2026-12-31 |
| G-22 | **closed 2026-11-19 by WP-13.** Narrowed by WP-6 to the misaligned split alone: an access crossing a word boundary was issued as one unaligned transaction, with no second beat, address increment or strobe recomputation. `rtl/misaligned_split.sv` now detects the crossing by size (`addr[1:0] + bytes > 4`), issues beat 1 at the access address and beat 2 at `(addr & ~3) + 4`, recomputes the strobes as the low bytes of the access followed by its high bytes, and merges a load's two answers before extension. | closed; `T-52` runs `rv32ui-p-ma_data` to `SANITY: PASS` over its 54 RV32 cases, and the mutant `no-misaligned-split` fails it at `testnum=3`. `FR-42` is `verified` | designer | closed 2026-11-19 |
| G-23 | No debug subsystem: the DUT has no debug port, no debug mode, no `dcsr`/`dpc`/`dscratch` and no abstract-command or program-buffer path (`rtl/riscv_small.sv:51-62`, `rtl/instruction_decode.sv:351-353`) | `FR-53` to `FR-56`, `FR-58` and `FR-59` stay `deferred`, and `T-05` cannot exist until a Debug Module model is built | designer | 2026-12-31 |
| G-24 | No trigger unit: `tselect`/`tdata1`..`tdata3`/`tinfo` are not decoded and no address or data comparator exists (`rtl/instruction_decode.sv:351-353`) | `FR-57` stays `deferred`; breakpoints and watchpoints cannot be observed in any configuration | designer | 2026-12-31 |
| G-25 | **closed 2026-10-30 by WP-4**: the MA forward block in `rtl/control.sv:263-263` forced `alu_src2` to the store data, so a store's address became `rs1 + rs2` instead of `rs1 + imm` (`sw gp,tohost` went to `0x1`). The fix gates `alu_src2` on `alu_src2_ex == RS2` and keeps `storage_src` for the store data (`rtl/control.sv:260`). | closed; `T-08` and `rv32ui-p-simple` pass | verification lead | closed 2026-10-30 |
| G-26 | **closed 2026-11-04 by WP-4c**: the branch/jump forward mux `jmp_src1`/`jmp_src2` was unconnected (`rtl/riscv_small.sv:219-220`) and `alu_ex`, the EX forward source, was undriven (`rtl/execution.sv:276`); the ALU forward itself was functional. | closed; `T-10`/`T-11`, the `add`/`addi`/`and` images and the mutants pass; `FR-16`/`FR-18` verified, `FR-19` implemented | verification lead | closed 2026-11-04 |
| G-27 | **closed 2026-11-04 by WP-4c**: the decoder PC was one instruction ahead of `inst_data` (`pc_id <= pc`) and the redirect had one flush too few; `pc_fetch` (`rtl/instruction_fetch.sv:76-101`) and `branch_taken_q` (`rtl/control.sv:116-122`, `:274-276`) fix it. | closed; `T-10`/`rv32ui-p-and` and the fail-path `testnum` pass; `FR-08` | designer | closed 2026-11-04 |
| G-28 | **closed 2026-11-07 by WP-8.** There was no retire/commit observation: the only instruction-level visibility was the fetch, and `if_id_flush` could discard an instruction the monitor had already published. The core now carries `valid`, `pc` and the instruction word to WB (`rtl/instruction_fetch.sv` `valid_id` -> `instruction_decode.sv` `valid_ex` -> `execution.sv` `valid_ma` -> `memory_access.sv` `valid_wb`), and a `bind` probe (`riscv_small_retire_if`, `tb/riscv_small_interface.sv`) publishes `(pc, inst, rd, wdata)` on `valid_wb && ma_wb_clk_en`. The reference model consumes **only** the monitor, and `program_port`/`rm_export`/`publish_program()` are deleted (`grep` empty). | closed; `T-44` (72 commits for 72 instructions), `T-45` (10 commits for 12 fetches, 2 instructions skipped) and `T-46` (WP-9 P1: 9 commits for 11 fetches when a branch skips 3 instructions, replacing the coincidental count equality with a per-pc set claim plus a gated count claim) pass, and the mutant `retire-every-slot` fails them while the store comparison still passes — proof that the retire checker, not the SW comparison, has the teeth. **Limit kept:** a `cp_inst` bin is still a fetch; coverage has not been migrated to the retire stream | verification lead | closed 2026-11-07 |

## Notes

- `T-01`..`T-03`, `T-06`, `T-08`..`T-15`, `T-16`..`T-53` are the tests in `scripts/verify/tests.tsv`; `T-04`
  and `T-05` are v0.7 targets with no implementation yet (`G-14`, `G-23`).
- WP-7 history: the 39 manifest tests were green at `rtl_digest` `sha256:3541dfb8…` and `tb_digest` `sha256:ae4e6c79…` (2026-11-06,
  the WP-7 regression, `build/regress/2026-11-06T02-17-17Z`): `T-01`/`T-02`/`T-06` directed, `T-08`..`T-43` one image
  each, `T-09` the passive topology. `NFR-05` was **measured** at the time of that work package at 41 of the 42 bundled images — 42 of 43 runs, the
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
  instruction bin into a named test, so the `A-09` bar went 21/40 → **40/40** and `NFR-05` 38 → **41 of 42 bundled (42 of 42 since WP-13)
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
- WP-14 built the machine-mode privileged half. `rtl/csr_file.sv` (new) carries the `FR-50` map, one table
  living in `rtl/riscv_definitions_pkg.sv:330-424` so the decoder and the file cannot disagree; `rtl/instruction_decode.sv:283-365`
  becomes one legality table that raises cause 2 on an unknown opcode, a reserved `funct3`/`funct7`, an absent CSR
  address and a write to a read-only one, and carries cause 11 for `ECALL` and 3 for `EBREAK`. A trap enters at
  `mtvec.BASE` and costs **two** IF/ID flushes: the first version observed 4 of the 7 traps and lost two to the
  fetch that entered ID behind the handler, and `trap_taken_q` now echoes the trap the way `branch_taken_q` echoes
  a jump. Evidence: `T-03`, red first at RTL `766cf5a1…` and red **again** at `1410ffdf…` when `cycle`/`instret`
  were not the views of `mcycle`/`minstret` the `FR-50` acceptance requires — the model returned 0 and the test
  expected 0, so test and oracle agreed with each other and both were wrong. Green in a **50/50** regression at
  RTL `sha256:2e91301d…` and TB `sha256:0091e260…`; `cg_csr` adds `cp_csr_op` 6/6, `cp_csr_group` 5/5 and
  `cp_trap_cause` 3/3 (report bins 52 → 66, the `A-09` bar still 40/40). The phase-1 bar moves 16 → **24 of 47**.
  `FR-22` stays `implemented` and `FR-24` `partial` with their arms in `G-37`/`G-38`; `G-01` and `G-02` close, and
  `G-06`/`G-13` narrow to the extensions and the fetch cause. The WP's own acceptance was **not** met in two
  places and the gate could not see it: no `rv32mi` environment exists, so `rv32mi-p-mcsr` never ran, and no
  directed test raises a trap with `split_stall` high. Both are `G-37`.
- WP-13 made a crossing access two word-aligned beats and closed the two defects that hid behind it. `rtl/misaligned_split.sv`
  (new) detects the crossing by size (`addr[1:0] + bytes > 4`), issues beat 1 at the access address and beat 2 at
  `(addr & ~3) + 4`, recomputes the strobes as the low bytes of the access followed by its high bytes, and merges a load's two answers before extension;
  `rtl/control.sv` holds the store **in MA** until the grant (`FR-38`, `G-18`) and freezes the pipeline while a beat is
  outstanding. Two further corrections were forced by the work: the **halfword lane ignored `addr[0]`** in both
  directions (`G-34`) — invisible because every halfword case in the corpus used an even offset — and a **flush fired
  while the pipeline was held by a beat**, clearing the load behind a store and letting a branch compare a stale
  register. Evidence: `T-51` (odd halfword offset, both directions), `T-52` (`rv32ui-p-ma_data` to `SANITY: PASS` over
  its 54 RV32 cases) and `T-53` (grant withheld for two cycles); `make regress` **49/49**, `make sanity` **43/43**,
  `make coverage` **52/52** bins with the `A-09` bar at **40/40**, `make negative-control` **47/47**, at RTL
  `sha256:f84ea86b…` and TB `sha256:7860d1b0…`. `G-18`, `G-22` and `G-34` close; the read half of the same data-port
  defect opens as **`G-35`** and leaves `FR-21` `partial`.
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
- Functional coverage exists in three covergroups in `tb/env/top/riscv_small_coverage.sv`, all sampled from the
  monitor: `cg_mem` (`cp_width`, `cp_lane`, `cp_dir`, `cp_subword_lane`), since WP-5 `cg_inst`/`cp_inst` with
  one bin per instruction of `spec.md` §4.1, and since WP-13 `cg_beat` (`cp_beat.split_beat1`/`split_beat2`,
  sampled per beat of a crossing access). The 2026-11-06 WP-7 merge over the 39 manifest tests was **50 of 50
  report bins** and **40 of 40 against the `A-09` bar** (`cp_inst` 37/37, `cp_width` 3/3, `cg_mem` 13/13);
  WP-13 added the two `cp_beat` bins and WP-14 the six `cg_csr` coverpoints, so the current report is **66 of 66**
  over 9 coverpoints and **40 of 40**, `uncovered` empty, `xcrg` score 100 %. The per-bin witness is in "Coverage bins". Evidence:
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
