# ==============================================================================
# RISC-V Sanity Tests Compilation
# ==============================================================================
# Description: This script owns everything needed to turn the bundled riscv-tests
# sources into the Verilog hex memory images the testbench consumes:
#
#   1. initialise the src/riscv-tests submodule;
#   2. configure the suite out-of-tree in build/sanity_tests/ (the submodule is
#      never polluted);
#   3. build one ELF per image;
#   4. convert each ELF to a hex with objcopy and rewrite the first line to the
#      @00000000 address marker the simulator already expects.
#
# Targets:
#   compile_sanity_tests    one image, named by the HEX_TEST_NAME cache variable
#                           (kept for scripts/xrun.sh and the documented usage)
#   compile_sanity_images   every rv32ui-p-* image, one CMake target each
#   compile_sanity_<image>  a single named image, e.g. compile_sanity_rv32ui-p-add
#
# Outputs: build/sanity_tests/isa/<image> (ELF) and
#          build/sanity_tests/hex/<image>.hex (memory image).
#
# Running and judging the images is cmake -P scripts/verify/sanity.cmake (CMake target
# `sanity`); this file does not simulate, and it does not decide pass/fail.
# ==============================================================================

set(HEX_TEST_NAME "rv32ui-p-addi" CACHE STRING "Specify the exact test name from riscv-tests/isa to convert")
set(RISCV_TESTS_DIR "${CMAKE_SOURCE_DIR}/src/riscv-tests")
set(RISCV_PREFIX "riscv64-unknown-elf-")
set(SANITY_DIR "${CMAKE_BINARY_DIR}/sanity_tests")
set(SANITY_ISA_DIR "${SANITY_DIR}/isa")
set(SANITY_HEX_DIR "${SANITY_DIR}/hex")
file(MAKE_DIRECTORY "${SANITY_ISA_DIR}" "${SANITY_HEX_DIR}")

# Required tools. Fail at configure time, where the message is actionable.
find_program(RISCV_OBJCOPY riscv64-unknown-elf-objcopy)
if(NOT RISCV_OBJCOPY)
    message(FATAL_ERROR "riscv64-unknown-elf-objcopy not found! Please install the required binutils using: sudo apt install binutils-riscv64-unknown-elf")
endif()

find_program(AUTOCONF autoconf)
if(NOT AUTOCONF)
    message(FATAL_ERROR "autoconf not found! Please install it using: sudo apt install autoconf")
endif()

find_program(RISCV_GCC riscv64-unknown-elf-gcc)
if(NOT RISCV_GCC)
    message(FATAL_ERROR "riscv64-unknown-elf-gcc not found! Please install it using: sudo apt install gcc-riscv64-unknown-elf")
endif()

# --- image list ---------------------------------------------------------------
# Each isa/rv32ui/<stem>.S builds the bare-metal image rv32ui-p-<stem>
# ("-p-" is the physical target of the bundled suite).
file(GLOB SANITY_SOURCES "${RISCV_TESTS_DIR}/isa/rv32ui/*.S")
if(NOT SANITY_SOURCES)
    message(FATAL_ERROR "No riscv-tests sources under ${RISCV_TESTS_DIR}/isa/rv32ui. Run: git submodule update --init src/riscv-tests")
endif()

set(SANITY_IMAGES "")
foreach(SANITY_SOURCE IN LISTS SANITY_SOURCES)
    get_filename_component(SANITY_STEM "${SANITY_SOURCE}" NAME_WE)
    list(APPEND SANITY_IMAGES "rv32ui-p-${SANITY_STEM}")
endforeach()
list(SORT SANITY_IMAGES)
list(LENGTH SANITY_IMAGES SANITY_IMAGE_COUNT)

if(NOT HEX_TEST_NAME IN_LIST SANITY_IMAGES)
    message(FATAL_ERROR "HEX_TEST_NAME='${HEX_TEST_NAME}' is not one of the ${SANITY_IMAGE_COUNT} bundled images (e.g. ${SANITY_IMAGES})")
endif()

# --- configure the suite once -------------------------------------------------
# The suite Makefile is the output, so configure runs again only when the
# out-of-tree Makefile disappears.
add_custom_command(
    OUTPUT "${SANITY_DIR}/Makefile"
    COMMAND git submodule update --init --recursive "${RISCV_TESTS_DIR}"
    COMMAND "${RISCV_TESTS_DIR}/configure" --srcdir "${RISCV_TESTS_DIR}"
    WORKING_DIRECTORY "${SANITY_DIR}"
    COMMENT "Configuring riscv-tests out-of-tree..."
    USES_TERMINAL
    VERBATIM
)

# --- one rule and one target per image ----------------------------------------
set(SANITY_HEX_FILES "")
foreach(SANITY_IMAGE IN LISTS SANITY_IMAGES)
    set(SANITY_ELF "${SANITY_ISA_DIR}/${SANITY_IMAGE}")
    set(SANITY_HEX "${SANITY_HEX_DIR}/${SANITY_IMAGE}.hex")

    add_custom_command(
        OUTPUT "${SANITY_ELF}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_ISA_DIR}"
        COMMAND make -C "${SANITY_DIR}" XLEN=32 RISCV_PREFIX="${RISCV_PREFIX}" RISCV_PREFIX_VAR="${SANITY_IMAGE}" isa
        DEPENDS "${SANITY_DIR}/Makefile"
        WORKING_DIRECTORY "${SANITY_DIR}"
        COMMENT "Building ${SANITY_IMAGE}..."
        VERBATIM
    )

    add_custom_command(
        OUTPUT "${SANITY_HEX}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_HEX_DIR}"
        COMMAND ${RISCV_OBJCOPY} -O verilog
                -j .text -j .text.startup -j .text.init -j .data
                --gap-fill 00000000 --set-start=0 --reverse-bytes=4
                --verilog-data-width 4
                "${SANITY_ELF}" "${SANITY_HEX}"
        COMMAND sed -i.bak "1 s/.*/@00000000/" "${SANITY_HEX}"
        COMMAND ${CMAKE_COMMAND} -E remove "${SANITY_HEX}.bak"
        DEPENDS "${SANITY_ELF}"
        WORKING_DIRECTORY "${SANITY_DIR}"
        COMMENT "Converting ${SANITY_IMAGE} to a hex image..."
        VERBATIM
    )

    add_custom_target(compile_sanity_${SANITY_IMAGE} DEPENDS "${SANITY_HEX}")
    list(APPEND SANITY_HEX_FILES "${SANITY_HEX}")
endforeach()

add_custom_target(compile_sanity_images DEPENDS ${SANITY_HEX_FILES})

# Backwards-compatible target: the single image chosen by HEX_TEST_NAME.
add_custom_target(compile_sanity_tests DEPENDS "${SANITY_HEX_DIR}/${HEX_TEST_NAME}.hex")
