# riscv-small
Five-stage RISC-V core for embedded applications.

## Implementation Status

- [x] Conception
- [x] Microarchitecture
- [x] RTL Design
- [ ] TB environment
- [ ] Testcases
- [ ] Functional Verification
- [ ] RTL signoff

## How to run

### Step 1: Set up the environment
Before running the simulation, you must source the required Xilinx tools (Vivado or Vitis). This injects the EDA toolpaths into your current terminal instance.

```bash
$ source /opt/Xilinx/Vitis/2024.1/settings64.sh 
# or
$ source /opt/Xilinx/Vivado/2024.1/.settings64-Vivado.sh 
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

- **`make compile`**: Explicitly compiles the library code (`xlog`) without running simulation.
- **`make elaborate`**: Explicitly compiles the library code (`xlog`) without running simulation.
- **`make sim`**: Runs the default test configuration (e.g. `adder_basic_test`) silently in terminal.
- **`make gui`**: Opens Vivado XSim GUI using your defined waveform layout.
- **`make sim_<test_name>`**: Injects the test dynamically (e.g. `make sim_adder_corner_test`) replacing defaults.
- **`make gui_<test_name>`**: Injects the test dynamically into the GUI directly (e.g. `make gui_adder_corner_test`).

#### Option B: Running from inside the `build/` directory
When inside the strictly generated CMake target directory, you can utilize the auto-generated target configurations.

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
$ bin/xrun.sh --name_of_test adder_corner_test
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
| `--top` | `adder_tb_top` | Specifies the top-level testbench module to load in elaboration. |
| `--test` | `adder_basic_test` | The UVM test name passed directly to `+UVM_TESTNAME` in `xsim`. |
| `--vivado` | `--R` | Passes arbitrary flags natively to the simulation engine. (Setting `--g` turns on GUI mode) |


## Important Information

1. **Tool Versions**:
   - Ensure you are using Vivado or Vitis version 2024.1 or later for compatibility with the scripts and UVM libraries.

2. **Directory Structure**:
   - Maintain the directory structure as provided in the repository to ensure the scripts and source lists function correctly.

3. **Debugging Tips**:
   - Use the `--vivado "--g"` option to open the GUI for debugging.
   - Check the `build/` directory for logs and intermediate files if issues arise during simulation.

4. **Extending Tests**:
   - To add new tests, configure standard UVM sequences inside your `tb/` folder or leverage the standard riscv-tests definitions inside `src/riscv-tests`. 

5. **Support**:
   - For questions or issues, contact the maintainer at `nelsonafn@gmail.com`.

6. **License**:
   - This project is distributed under the BSD license. Refer to the `LICENSE` file for details.

## Compiling RISC-V Sanity Tests
The project features a submodule containing the official RISC-V ISA test-suite. We've automated its compilation natively into CMake!

**1. Install Linux GCC Cross-Compiler requirements:**
Unlike heavy cross-builds, you only require the standard GCC utility packages available in your apt repository! Note: This replaces the need to build the `riscv-gnu-toolchain` manually.
```bash
$ sudo apt update
$ sudo apt install autoconf gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
```

**2. Execute the integrated CMake target:**
Once in your build folder, you can recursively pull the submodule, compile the tests via GNU make, and parse the payload out cleanly.
```bash
$ cd build/
$ make compile_sanity_tests
```

**3. Test Payload:**
The generated instruction payload will be automatically placed into your build directory: `build/rv32ui-p-addi.hex`. You can invoke it immediately using the dynamic Make test configurations!
