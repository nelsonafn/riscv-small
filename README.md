# riscv-small
Five stage RISC-V core for embedded application.

## Implementation Status

- [x] Conception
- [x] Microarchitecture
- [x] RTL Design
- [ ] TB environment
- [ ] Testcases
- [ ] Functional Verification
- [ ] RTL signoff 
      
# How to run
Go inside build and do Vivado or Vits source 
```
$ source /opt/Xilinx/Vitis/2024.1/settings64.sh 
or
$ source /opt/Xilinx/Vivado/2024.1/.settings64-Vivado.sh 
```

Run the xrun script
```
$ ../bin/xrun.sh 
```

# Tests

To run the tests install riscv-gnu-toolchain

https://github.com/riscv-collab/riscv-gnu-toolchain

Remember of
```
$ export RISCV=/opt/riscv"
```

Install it with support to multilib like.
```
$ ./configure --prefix=$RISCV --enable-multilib
```
Make sure you have installed riscv64-unknown-elf

Then, install the risc tools

https://github.com/riscv-software-src/riscv-tools



Update submodule 
```
$ cd riscv-pk/
$ git checkout master
$ cd ..
```

```
$ cd riscv-isa-sim/
$ git checkout v1.1.0
$ cd ..
```

```
$ cd ../riscv-tests/
$ git checkout master
$ git submodule update --init --recursive
$ cd ..
```
Used submodules 
+530af85d83781a3dae31a4ace84a573ec255fefa riscv-isa-sim (v1.1.0)
 7c3db437d8d3b6961f8eb2931792eaea1c469ff3 riscv-opcodes (remotes/origin/confprec-99-g7c3db43)
 35eed36ffdd082f5abfc16d4cc93511f6e225284 riscv-openocd (v20180629-198-g35eed36ff)
+0d3339c73e8401a6dcfee2f0b97f6f52c81181c6 riscv-pk (v1.0.0-85-g0d3339c)
+bd050de178cb1ffcfaae6bf1c79e6e640600b22f riscv-tests (heads/master)



```
$ riscv64-unknown-elf-objcopy -O verilog -j .text -j .text.startup -j .text.init -j .data \
--gap-fill 00000000 --reverse-bytes=4 isa/rv32ui-p-addi -v --verilog-data-width 4  rv32ui-p-addi.hex
```
