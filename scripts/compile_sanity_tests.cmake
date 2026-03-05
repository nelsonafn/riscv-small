# ==============================================================================
# RISC-V Sanity Tests Compilation Target
# ==============================================================================
# Description: This CMake script defines a dynamic target capable of initializing
# the riscv-tests submodule, configuring the build space, making the suite, and 
# outputting the specific `.hex` memory maps needed for structural simulation.
# ==============================================================================

set(HEX_TEST_NAME "rv32ui-p-addi" CACHE STRING "Specify the exact test name from riscv-tests/isa to convert")
set(RISCV_TESTS_DIR "${CMAKE_SOURCE_DIR}/src/riscv-tests")
set(OUTPUT_HEX "${CMAKE_BINARY_DIR}/${HEX_TEST_NAME}.hex")

# First, check if the required objcopy tool is present
find_program(RISCV_OBJCOPY riscv64-linux-gnu-objcopy)
if(NOT RISCV_OBJCOPY)
    message(FATAL_ERROR "riscv64-linux-gnu-objcopy not found! Please install the required binutils using: sudo apt install binutils-riscv64-linux-gnu")
endif()

# Check for autoconf
find_program(AUTOCONF autoconf)
if(NOT AUTOCONF)
    message(FATAL_ERROR "autoconf not found! Please install it using: sudo apt install autoconf")
endif()

# Check for GCC RISC-V Cross Compiler
find_program(RISCV_GCC riscv64-linux-gnu-gcc)
if(NOT RISCV_GCC)
    message(FATAL_ERROR "riscv64-linux-gnu-gcc not found! Please install it using: sudo apt install gcc-riscv64-linux-gnu")
endif()

add_custom_target(compile_sanity_tests
    # 1. Update the riscv-tests submodule
    COMMAND git submodule update --init --recursive
    
    # 2. Configure the tests (requires RISCV toolchain in the environment variable $RISCV)
    COMMAND autoconf
    COMMAND ./configure
    
    # 3. Compile the tests using make (focus on 32-bit tests for RISC-V Small)
    COMMAND make XLEN=32 RISCV_PREFIX=riscv64-linux-gnu-
    
    # 4. Generate the HEX format from the compiled ELF using the standard objcopy
    COMMAND riscv64-linux-gnu-objcopy -O verilog -j .text -j .text.startup -j .text.init -j .data 
        --gap-fill 00000000 --set-start=0 --reverse-bytes=4 
        "${RISCV_TESTS_DIR}/isa/${HEX_TEST_NAME}" 
        -v --verilog-data-width 4 
        "${OUTPUT_HEX}"
        
    # 5. Fix the first line to be the precise address marker for the Vivado simulator
    COMMAND sed -i.bak "1 s/.*/@00000000/" "${OUTPUT_HEX}"
    
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/src/riscv-tests"
    COMMENT "Building test suite and generating memory map for: ${HEX_TEST_NAME}..."
    USES_TERMINAL
)
