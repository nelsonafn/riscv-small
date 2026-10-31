# riscv-small
Five-stage RISC-V core for embedded applications.

## Implementation Status

- [x] Conception
- [x] Microarchitecture
- [x] RTL Design
- [x] TB environment (UVM agent, scoreboard, reference model, coverage)
- [x] Testcases (loads/stores, sub-word access)
- [ ] Functional Verification (in progress, driven by work packages)
- [ ] RTL signoff

The flow is documented in [Verification and signoff](#verification-and-signoff); the current verdict is always in
`build/signoff/report.md`.

## How to run

### Step 1: Set up the environment
Before running the simulation, you must source the required Xilinx tools (Vivado or Vitis). This injects the EDA toolpaths into your current terminal instance.

```bash
$ source /opt/Xilinx/Vivado/2024.1/settings64.sh
# or, if your install lives under Vitis:
$ source /opt/Xilinx/Vitis/2024.1/settings64.sh
```

### Step 2: Configure the Build
This project uses CMake to automate the Vivado simulation flow (`xvlog`, `xelab`, `xsim`). You generate an isolated `build/` directory using the provided wrapper script.

```bash
# Sets up the default simulation environment
$ ./configure
```
Under the hood, this parses your SV files, generates dependency trees via stamp files (so they only recompile when modified), and creates dynamically bound Make targets.

#### Custom Defaults Configuration
If you want to bake a different default test sequence into the generated Makefiles:
```bash
$ ./configure --top <top_name> --test <test_name>
```

### Step 3: Run the simulation
Because of the smart wrapper generated in the project root, you have several ways to trigger the simulations cleanly!

#### Option A: Running from the Project Root (Smart Proxy)
You do not need to `cd build/`. You can immediately execute targets from the root, and it will intentionally forward your requests into CMake. It allows you to inject individual test names via spaces.

- **`make compile`**: Explicitly compiles the SV source code (`xvlog`) without running simulation.
- **`make elaborate`**: Elaborates the compiled design into a simulation snapshot (`xelab`) without running simulation.
- **`make sim`**: Runs the default test (`riscv_small_basic_load_store_test`) silently in terminal.
- **`make gui`**: Opens Vivado XSim GUI using your defined waveform layout.
- **`make sim_<test_name>`**: Injects the test dynamically (e.g. `make sim_riscv_small_corner_test`) replacing defaults.
- **`make gui_<test_name>`**: Injects the test dynamically into the GUI directly (e.g. `make gui_riscv_small_corner_test`).

#### Option B: Running from inside the `build/` directory
When inside the strictly generated CMake target directory, you can utilize the auto-generated target configurations. (Note: spaces denote multiple targets inside native Make!)

```bash
$ cd build/
```
- **`make sim`**: Runs the default test configured.
- **`make elaborate`**: Explicitly compiles the library code (`xlog`) without running simulation.
- **`make compile_sanity_tests`**: Compiles native RISC-V structural tests (e.g. `rv32ui-p-addi`) inside the `src/riscv-tests` submodule and extracts the raw memory `.hex` payload for simulations.
- **`make <test_name>`**: Runs a specific test dynamically discovered natively (e.g. `make rv32ui-p-addi`).
- **`make sim_<test_name>`**: Explicitly runs the auto-generated test strictly in SIM terminal mode.
- **`make gui_<test_name>`**: Explicitly runs the auto-generated test natively triggering the Vivado GUI.

#### Option C: Legacy Workflow Wrapper
If you are strictly used to Xilinx environments parsing raw arguments, we provide a reverse-compatible wrapper that automatically triggers CMake and GNU Make behind the scenes.

```bash
$ scripts/xrun.sh --name_of_test riscv_small_corner_test
```
*(Runs completely self-contained from anywhere in the project tree.)*

### Step 4: Clean Build
To clean the entire build cache (safe compilation reset):
```bash
$ make clean
```

### Summary of Configure Arguments
| Variable | Default Value | Description |
|---|---|---|
| `--top` | `riscv_small_tb` | Specifies the top-level testbench module to load in elaboration. |
| `--test` | `riscv_small_basic_load_store_test` | The UVM test name passed directly to `+UVM_TESTNAME` in `xsim`. |
| `--vivado` | `--R` | Passes arbitrary flags natively to the simulation engine. (Setting `--g` turns on GUI mode) |


## Verification and signoff

The testbench is a UVM environment (`tb/`) that plays the role of the instruction and data memories. The regression
is declared once, in `scripts/verify/tests.tsv`, and every gate is a CMake target that pulls its own chain, so the
same command works from the project root or from inside `build/`.

| Command | What it does |
|---|---|
| `make regress` | runs the manifest through CTest, writes `build/regress/<run>/results.json` (per-test log, `rtl_digest`, `tb_digest`) |
| `make regress REGRESS_ARGS="--test T-06"` | one test |
| `make coverage` | builds an instrumented snapshot, runs the manifest tests and merges the databases with `xcrg` into `build/cov_report/summary.json` |
| `make sanity` | runs the 42 bundled `rv32ui-p-*` images through the core and records `build/sanity/summary.json` (`NFR-05`); 1/42 pass today, the failures are triaged in `doc/measurements/NFR-05-riscv-tests.md` |
| `make negative-control` | rebuilds each covered defect and proves the test fails on it (`build/red/<T-id>/results.json`) |
| `make signoff-check` | the release gate: all 11 checks, report in `build/signoff/report.md` |
| `make signoff-check SIGNOFF_ARGS="--wp 0"` | the gate of one work package: checks 1-5, 7 and 11 (6 and 8-10 are release evidence, reported as `skipped`) |

A **work package (WP)** is one closed increment of requirements: `.opencode/plan/wp-<n>-<slug>.md` holds its scope, its
test plan and its acceptance. WP-0 (sub-word load lane, `FR-12`), WP-2 (gate parser), WP-3 (negative control), WP-4 (sanity harness) and
WP-4b (sanity architecture) are closed; WP-4c (`G-27`/`G-26`) is next; WP-1 (CSR/`Zicsr`/trap entry) is drafted.

### What the signoff gate means

The gate never pretends to pass. It answers with an exit code and a report:

- `signoff-ready` (exit `0`) when every check that applies to the mode is green;
- `blocked` (exit `1`) when a check fails or evidence is missing;
- exit `2` when the gate itself could not run.

`not-measurable` is a blocker, never a pass. The release gate is expected to stay `blocked` until every requirement is
`verified` (`A-09`) and `NFR-05`/`NFR-07` can be measured. `NFR-05` is now **measured** (1 of 42 images pass); the
remaining failures are `G-26`, `G-27`, `G-07`, `G-20`, `G-08`, `G-15` and `FR-42`.

### Why "red" evidence is reproducible

Test-first is a process rule: the test must fail before the fix exists. A *stored* failing log is history — it dies
with `rm -rf build`, cannot be regenerated once the RTL is fixed, and does not exist on a fresh machine. So the gate
does not trust it. Instead, every test that covers a defect carries the defect it must catch:

`scripts/verify/mutants/<name>.cmake` reintroduces the defect as a one-line change. `make negative-control` copies the
tree into `build/mutants/<T-id>/`, applies the mutant there, runs the test and requires a UVM failure, then publishes
`build/red/<T-id>/results.json`; check 11 reads that result. The repository is never edited, nothing depends on stored
history, and `rm -rf build` is always safe — the next gate reintroduces the defect and proves the test again.

If a test passes on its mutant, the gate fails with `the test does not catch this defect`: that is a test without
teeth, not a tooling problem.

## Logging and Debugging

The project features a **Colored UVM Report Server** that enhances the readability of simulation logs by using ANSI colors and a structured column format.

### Log Format
Messages are formatted for maximum density and clarity:
`SEVERITY @ TIME [| FILE(LINE)] | [ID] MESSAGE`

*   **SEVERITY**: ANSI-colored (Green for INFO, Yellow for WARNING, Red for ERROR/FATAL).
*   **TIME**: Raw simulation time (e.g., `@ 1000000`).
*   **FILE(LINE)**: Only appears during **ERROR/FATAL** or when using high verbosity (`+UVM_VERBOSITY=UVM_FULL`).
*   **ID**: The UVM component hierarchy or message tag.

### Clean Logs (CI/CD and Post-processing)
If you need to redirect the output to a file without ANSI escape codes, use the `SIM_ARGS` environment variable to pass extra arguments to `xsim` at runtime:
```bash
$ SIM_ARGS="--testplusarg NO_COLOR" make sim
```

### Runtime Simulation Arguments
The `SIM_ARGS` environment variable lets you inject any extra `xsim` arguments without reconfiguring:
```bash
# Disable colored output
$ SIM_ARGS="--testplusarg NO_COLOR" make sim

# Show FILE(LINE) on every message (high verbosity)
$ SIM_ARGS="--testplusarg UVM_VERBOSITY=UVM_FULL" make sim

# Combine multiple plusargs
$ SIM_ARGS="--testplusarg UVM_VERBOSITY=UVM_FULL --testplusarg NO_COLOR" make sim

# Works with individual test targets too
$ SIM_ARGS="--testplusarg NO_COLOR" make sim_riscv_small_corner_test
```

## Important Information

1. **Tool Versions**:
   - Ensure you are using Vivado or Vitis version 2024.1 or later for compatibility with the scripts and UVM libraries.

2. **Directory Structure**:
   - Maintain the directory structure as provided in the repository to ensure the scripts and source lists function correctly.

3. **Debugging Tips**:
   - Use the `--vivado "--g"` option to open the GUI for debugging.
   - **Clickable Links**: When a message is ERROR/FATAL, the `file(line)` column is shown. `Ctrl+Click` on it to jump to the code.
   - **Verbosity**: To see exactly where *every* message comes from, use `SIM_ARGS="--testplusarg UVM_VERBOSITY=UVM_FULL" make sim`.
   - **Filtering**: Use `grep` to isolate specific components: `make sim 2>&1 | grep "SCOREBOARD"`.

4. **Extending the Template**:
   - To add new tests, create sequences in `tb/tests/sequence_lib/` and include them in `tb/tests/sequence_lib/riscv_small_seq_list_pkg.sv` and `tb/tests/riscv_small_test_list_pkg.sv`.
   - To add standalone shared components (like interfaces), map them to an `.srclist` module to build them as an independent library.
   - For additional coverage, extend the collector in `tb/env/top/riscv_small_coverage.sv` and the bin map in `doc/verification.md`.

5. **Support**:
   - For questions or issues, contact the maintainer at `nelsonafn@gmail.com`.

6. **License**:
   - This project is distributed under the BSD license. Refer to the `LICENSE` file for details.

## Install cmake
sudo apt install cmake

## Compiling RISC-V Sanity Tests
The project features a submodule containing the official RISC-V ISA test-suite. We've automated its compilation natively into CMake!

**1. Install embedded GCC cross-compiler requirements:**
Unlike heavy cross-builds, you only require the standard GCC embedded utility packages natively available in your apt repository! Note: This safely replaces the need to manually build the `riscv-gnu-toolchain` from source.
```bash
$ sudo apt update
$ sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

**2. Execute the integrated CMake target:**
Each `src/riscv-tests/isa/rv32ui/*.S` is compiled directly by CMake with the project environment
`scripts/verify/sanity/riscv_test.h` + `link.ld` -- no `autoconf`, no out-of-tree suite Makefile, nothing written
inside the `src/riscv-tests` submodule. The project environment replaces the suite's `ECALL`/trap pass/fail
ceremony (which `riscv_small` does not implement, `G-13`) with a direct store to `tohost`; the test bodies are
unmodified.
```bash
$ make compile_sanity_tests            # HEX_TEST_NAME=rv32ui-p-addi
$ make compile_sanity_rv32ui-p-add     # one image
$ make compile_sanity_images           # every rv32ui-p-* image
```

**3. Test Payload:**
The ELF, hex, `tohost` address and disassembly are written to `build/sanity_tests/{isa,hex,tohost,dump}/<image>`.
The test reads `+HEX`, the sequence builds the program item, the driver is the memory BFM and the
`riscv_small_sanity_checker` decides from the monitor. `make sanity` runs all 42 images; each run ends with
`SANITY: PASS` or `SANITY: FAIL testnum=<n>` (a missing store is `SANITY: TIMEOUT`). The current baseline is 1/42; the
triage is in `doc/measurements/NFR-05-riscv-tests.md`, and the release gate reports it as `blocked` until the images
pass.
