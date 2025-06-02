## Running a Simple Test

To run a basic simulation of the RISC-V core, use the provided script from the `build` directory:

```sh
$ ../bin/xrun.sh -g
```

To launch the simulation with waveform viewing enabled (using the pre-configured `top_sim.wcfg` file):

```sh
$ ../bin/xrun.sh -g -view top_sim.wcfg
```

- `-g` enables the graphical mode.
- `-view top_sim.wcfg` loads the waveform configuration, allowing you to inspect signals such as pipeline stages, instruction/data memory, and control signals.

> **Note:** Ensure you have Vivado/Vitis environment sourced and all dependencies installed as described in the main [README.md](../README.md).