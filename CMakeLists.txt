################################################################################
# Copyright 2026 Nelson Alves Ferreira Neto
# All Rights Reserved Worldwide
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, 
# this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice, 
# this list of conditions and the following disclaimer in the documentation 
# and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
################################################################################
#
# File: CMakeLists.txt
#
# Description: This file is the main CMake configuration script for building and
# simulating the riscv-small project. It defines a dynamic build system that:
#   - Parses SystemVerilog header files (.svh) and packages in `.srclist` files.
#   - Uses Vivado Simulator (`xvlog`, `xelab`, `xsim`) for compilation and simulation.
#   - Establishes independent library dependencies to prevent elaboration errors.
#   - Dynamically creates standard `sim` and `gui` simulation targets as well as
#     targets for each individual test case specified in `tb/tests/*_test.sv`.
#
# Maintainer: Nelson Alves <nelsonafn@gmail.com>
#
################################################################################

cmake_minimum_required(VERSION 3.10)
project(AdderTemplate NONE)

# ==============================================================================
# 1. Options / Variables
# ==============================================================================
# Configuration parameters for specifying simulation parameters. 
# These variables can be overridden from the command line using -D<VAR>=<VALUE>.
# Example: cmake -DTOP_NAME=riscv_small_tb -DTEST_NAME=my_test ..
set(TOP_NAME "adder_tb_top" CACHE STRING "Specify the exact top module name to be simulated")
set(TEST_NAME "adder_basic_test" CACHE STRING "Specify the default UVM or SystemVerilog test name to run")
set(VIVADO_PARMS "--R" CACHE STRING "Pass extra Vivado parameters for xsim (e.g. --R for run all)")

# ==============================================================================
# 2. Environment Validation
# ==============================================================================
# Verify if the Vivado toolchain is properly loaded and initialized.
# This prevents obscure errors later in the compilation/simulation steps.
if(NOT DEFINED ENV{XILINX_VIVADO})
    message(FATAL_ERROR "XILINX_VIVADO environment variable is not set. Ensure you have sourced settings64.sh! Look at scripts/setup.sh for more info. Fix it, source it, and try again. $ source scripts/setup.sh")
endif()

# Convert VIVADO_PARMS into a list format.
# This ensures that multiple spaces or separate arguments aren't incorrectly grouped as a single string during execution.
separate_arguments(VIVADO_PARMS_LIST UNIX_COMMAND "${VIVADO_PARMS}")

# Log the active simulation configuration settings for user visibility.
message(STATUS "--------------------------------------------------")
message(STATUS "  Simulation Configuration:")
message(STATUS "  - Top Module     : ${TOP_NAME}")
message(STATUS "  - Test Name      : ${TEST_NAME}")
message(STATUS "  - Seed           : ${SEED}")
message(STATUS "  - Vivado Params  : ${VIVADO_PARMS}")
message(STATUS "--------------------------------------------------")

# ==============================================================================
# 3. Global Variables
# ==============================================================================
# Global properties and variables to track state across recursive CMake function calls.
# This tracks all processed target sources and compiled libraries.
set(PROCESSED_SRCLISTS "" CACHE INTERNAL "Tracks processed .srclist files to avoid infinite recursion")
set_property(GLOBAL PROPERTY ALL_COMPILE_TARGETS "")
set_property(GLOBAL PROPERTY ALL_SIM_LIBS "")

# ==============================================================================
# 4. Helper Function: compile_xvlog_library
# ==============================================================================
# Consolidates the common logic for creating an xvlog compilation target 
# with the appropriate stamp file and dependencies. This allows generalizing 
# compilation for both standard sourcelists and isolated packages.
# ==============================================================================
function(compile_xvlog_library TARGET_LIB SV_FILES LOCAL_XVLOG_LIBS TARGET_DEPENDENCIES LOCAL_XVLOG_INCDIRS)
    set(TARGET_NAME "compile_${TARGET_LIB}")
    
    # Handle cases where there are no standalone .sv modules, only dependencies.
    if(NOT SV_FILES)
        if(TARGET_DEPENDENCIES)
            add_custom_target(${TARGET_NAME})
            add_dependencies(${TARGET_NAME} ${TARGET_DEPENDENCIES})
            set_property(GLOBAL APPEND PROPERTY ALL_COMPILE_TARGETS "${TARGET_NAME}")
        endif()
        return()
    endif()

    set(STAMP_FILE "${CMAKE_BINARY_DIR}/${TARGET_LIB}.stamp")
    
    # Broaden dependencies to include all .sv and .svh files in the same directories.
    # We use CONFIGURE_DEPENDS so CMake knows to re-check these directories if files are added/removed.
    set(ALL_DEPENDS ${SV_FILES})
    foreach(SV_FILE IN LISTS SV_FILES)
        get_filename_component(SV_DIR "${SV_FILE}" DIRECTORY)
        file(GLOB DIR_SVS CONFIGURE_DEPENDS "${SV_DIR}/*.sv" "${SV_DIR}/*.svh")
        list(APPEND ALL_DEPENDS ${DIR_SVS})
    endforeach()

    # Also include files from the include directories to catch all `includes
    foreach(INC_FLAG_OR_DIR IN LISTS LOCAL_XVLOG_INCDIRS)
        if(NOT INC_FLAG_OR_DIR STREQUAL "-i")
            file(GLOB_RECURSE INC_SVS CONFIGURE_DEPENDS "${INC_FLAG_OR_DIR}/*.sv" "${INC_FLAG_OR_DIR}/*.svh")
            list(APPEND ALL_DEPENDS ${INC_SVS})
        endif()
    endforeach()

    # xvlog has no dependency graph of its own: a library that links another one
    # must be recompiled when that library changes, otherwise its .sdb keeps the
    # old interface ("needs to be re-saved since ... changed" from xelab/xsim).
    # The stamp of every dependency takes part in this library's freshness.
    foreach(DEP_TARGET IN LISTS TARGET_DEPENDENCIES)
        if(DEP_TARGET MATCHES "^compile_(.+)$")
            list(APPEND ALL_DEPENDS "${CMAKE_BINARY_DIR}/${CMAKE_MATCH_1}.stamp")
        endif()
    endforeach()

    if(ALL_DEPENDS)
        list(REMOVE_DUPLICATES ALL_DEPENDS)
    endif()
    
    # Prepare xvlog parameters mapping the exact required libraries using the -L flag
    set(LOCAL_XVLOG_ARGS "-L" "uvm")
    if(LOCAL_XVLOG_INCDIRS)
        list(APPEND LOCAL_XVLOG_ARGS ${LOCAL_XVLOG_INCDIRS})
    endif()
    get_property(GLOBAL_SIM_LIBS GLOBAL PROPERTY ALL_SIM_LIBS)
    if(GLOBAL_SIM_LIBS)
        list(REMOVE_DUPLICATES GLOBAL_SIM_LIBS)
        foreach(LIB_NAME IN LISTS GLOBAL_SIM_LIBS)
            list(APPEND LOCAL_XVLOG_ARGS "-L" "${LIB_NAME}")
        endforeach()
    endif()

    # In EDA flows, using a stamp file with an add_custom_command ensures that the
    # compilation only runs when the `.sv` dependencies are newer than the stamp file.
    # This gives `make` a discrete file (`.stamp`) to check timestamps against.
    add_custom_command(
        OUTPUT "${STAMP_FILE}"
        COMMAND xvlog -work ${TARGET_LIB} ${LOCAL_XVLOG_ARGS} -sv ${SV_FILES}
        COMMAND touch "${STAMP_FILE}"
        DEPENDS ${ALL_DEPENDS}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Compiling ${TARGET_LIB}..."
        VERBATIM
    )
    
    # The custom target just drives the creation of the stamp file
    add_custom_target(${TARGET_NAME} DEPENDS "${STAMP_FILE}")
    
    # Apply sub-dependencies (either packages or nested srclists)
    if(TARGET_DEPENDENCIES)
        add_dependencies(${TARGET_NAME} ${TARGET_DEPENDENCIES})
    endif()
    
    # Register this compilation target globally
    set_property(GLOBAL APPEND PROPERTY ALL_COMPILE_TARGETS "${TARGET_NAME}")
    set_property(GLOBAL APPEND PROPERTY ALL_STAMP_FILES "${STAMP_FILE}")
endfunction()

# ==============================================================================
# 5. Parsing Function: create_library_from_srclist
# ==============================================================================
# This function dynamically parses a source list (.srclist) line by line.
# 
#  Logic Flow:
#  1. Reads `.srclist` to retrieve SystemVerilog files, packages, and sub-lists.
#  2. If a sub-list (.srclist) is found, it evaluates it recursively, creating a dependent library.
#  3. If a package (.svh/.sv) is found, it compiles the package into an independent, shared library 
#     ensuring it can be used efficiently across other modules without duplication/elaboration loops.
#  4. If a standard `.sv` module is found, it bundles it with other SV files into the main target library.
#  5. Finally, uses the helper compile_xvlog_library to abstract away custom commands.
#
# Parameters:
#  - SRCLIST_PATH: The absolute path to the `.srclist` file to parse.
#  - TARGET_LIB: The logical name of the library (e.g., 'work', 'my_module_lib') being created.
# ==============================================================================
function(create_library_from_srclist SRCLIST_PATH TARGET_LIB)
    # Stop recursion if the list was already parsed.
    if("${SRCLIST_PATH}" IN_LIST PROCESSED_SRCLISTS)
        return()
    endif()
    set(PROCESSED_SRCLISTS "${PROCESSED_SRCLISTS};${SRCLIST_PATH}" CACHE INTERNAL "")

    # Tell CMake to re-run configuration automatically if this srclist is modified.
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${SRCLIST_PATH}")

    if(NOT EXISTS "${SRCLIST_PATH}")
        message(FATAL_ERROR "Source list not found: ${SRCLIST_PATH}")
    endif()

    file(STRINGS "${SRCLIST_PATH}" LINES)
    
    # Local variables for current library compilation
    set(SV_FILES "")
    set(TARGET_DEPENDENCIES "")
    set(LOCAL_XVLOG_LIBS "")
    set(LOCAL_XVLOG_INCDIRS "")

    foreach(LINE IN LISTS LINES)
        # Remove trailing comments and strip whitespaces
        string(REGEX REPLACE "#.*$" "" LINE "${LINE}")
        string(STRIP "${LINE}" LINE)
        if(LINE STREQUAL "")
            continue() # Skip empty lines
        endif()

        if(LINE MATCHES "^\\+incdir\\+(.*)$")
            list(APPEND LOCAL_XVLOG_INCDIRS "-i" "${CMAKE_SOURCE_DIR}/${CMAKE_MATCH_1}")

        elseif(LINE MATCHES "\\.srclist$" OR LINE MATCHES "pkg\\.svh?$")
            # For both sub-lists and packages, we create an independent library target
            # and inherit it as a dependency for the current parent module list.
            get_filename_component(CHILD_BASE_NAME "${LINE}" NAME_WE)
            set(CHILD_LIB "${CHILD_BASE_NAME}_lib")
            
            if(LINE MATCHES "\\.srclist$")
                # Recursively parse the target directory based on srclist structure
                create_library_from_srclist("${CMAKE_SOURCE_DIR}/${LINE}" "${CHILD_LIB}")
            else()
                # Packages shouldn't be parsed, simply compile them structurally using the helper.
                # We pass the accumulated LOCAL_XVLOG_LIBS and TARGET_DEPENDENCIES so it can resolve prior packages.
                get_property(COMPILED_PKGS GLOBAL PROPERTY PROCESSED_PKGS)
                if(NOT "${CHILD_LIB}" IN_LIST COMPILED_PKGS)
                    set_property(GLOBAL APPEND PROPERTY PROCESSED_PKGS "${CHILD_LIB}")
                    compile_xvlog_library("${CHILD_LIB}" "${CMAKE_SOURCE_DIR}/${LINE}" "${LOCAL_XVLOG_LIBS}" "${TARGET_DEPENDENCIES}" "${LOCAL_XVLOG_INCDIRS}")
                endif()
            endif()
            
            # Sub-library now acts as a dependency/linked object towards main compilation tree
            list(APPEND TARGET_DEPENDENCIES "compile_${CHILD_LIB}")
            set_property(GLOBAL APPEND PROPERTY ALL_SIM_LIBS "${CHILD_LIB}")
            list(APPEND LOCAL_XVLOG_LIBS "${CHILD_LIB}")

        else()
            # Standard SystemVerilog file (.sv)
            list(APPEND SV_FILES "${CMAKE_SOURCE_DIR}/${LINE}")
        endif()
    endforeach()

    # Compile the aggregated files for this srclist using the common helper function
    compile_xvlog_library("${TARGET_LIB}" "${SV_FILES}" "${LOCAL_XVLOG_LIBS}" "${TARGET_DEPENDENCIES}" "${LOCAL_XVLOG_INCDIRS}")
    
endfunction()

# ==============================================================================
# 6. Build Flow Implementation
# ==============================================================================

# Start parsing the design hierarchy starting from the top module's srclist.
# The resultant library is assigned the default 'work' name.
set(PROCESSED_SRCLISTS "" CACHE INTERNAL "")
create_library_from_srclist("${CMAKE_SOURCE_DIR}/srclist/${TOP_NAME}.srclist" "work")

# Gather all identified compilation targets and used libraries generated recursively above.
get_property(COMPILE_TARGETS GLOBAL PROPERTY ALL_COMPILE_TARGETS)
get_property(SIM_LIBS GLOBAL PROPERTY ALL_SIM_LIBS)

# Format library flags for Xelab linker/elaborator (-L lib1 -L lib2 ...)
set(XELAB_LIBS "")
if(SIM_LIBS)
    list(REMOVE_DUPLICATES SIM_LIBS)
    foreach(LIB_NAME IN LISTS SIM_LIBS)
        list(APPEND XELAB_LIBS "-L" "${LIB_NAME}")
    endforeach()
endif()

# Define the overarching `compile` target that triggers the compilation of all .sv files.
if(COMPILE_TARGETS)
    add_custom_target(compile DEPENDS ${COMPILE_TARGETS})
else()
    add_custom_target(compile COMMENT "No sources to compile.")
endif()

# ==============================================================================
# 7. Elaboration and Simulation Targets
# ==============================================================================

# Elaborate target: links the compiled units into a simulated snapshot ('top_sim') using xelab.
get_property(ALL_STAMP_FILES GLOBAL PROPERTY ALL_STAMP_FILES)
string(REPLACE ";" " " STAMP_LIST "${ALL_STAMP_FILES}")
# The snapshot is discarded whenever a compiled library is newer than the marker
# written at the end of the last successful elaboration. Comparing against the
# snapshot *directory* does not work: a simulation writes into it, so its mtime
# is always newer than the stamps and a stale snapshot survives a library change
# ("needs to be re-saved since ... changed" from xsim).
add_custom_target(elaborate
    COMMAND bash -c "for s in ${STAMP_LIST}; do if [ ! -f xsim.dir/.elaborated ] || [ \"$s\" -nt xsim.dir/.elaborated ]; then echo \"Library $s updated. Cleaning snapshot to force full elaboration.\"; rm -rf xsim.dir/top_sim; break; fi; done"
    COMMAND xelab ${TOP_NAME} -L uvm ${XELAB_LIBS} --timescale 1ns/1ps -s top_sim --debug typical --mt 16 --incr $(ELAB_ARGS)
    COMMAND ${CMAKE_COMMAND} -E touch xsim.dir/.elaborated
    DEPENDS compile ${ALL_STAMP_FILES}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Elaborating design snapshot (top_sim)..."
    VERBATIM
)

set(DOLLAR "$")
set(LBRACE "{")
set(RBRACE "}")

# Primary 'sim' target: executes the simulation engine headlessly in CLI (xsim)
# Usage: SIM_ARGS="--testplusarg MY_ARG=1" make sim
#        TEST_NAME=my_test make sim
add_custom_target(sim
    COMMAND xsim top_sim ${VIVADO_PARMS_LIST} --testplusarg UVM_TESTNAME=${DOLLAR}${DOLLAR}${LBRACE}TEST_NAME:-${TEST_NAME}${RBRACE} --sv_seed ${DOLLAR}${DOLLAR}${LBRACE}SEED:-${SEED}${RBRACE} $(SIM_ARGS)
    DEPENDS elaborate
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running standard simulation in CLI..."
    USES_TERMINAL
)

# 'gui' target: executes the simulation engine visually in Vivado's GUI
add_custom_target(gui
    COMMAND xsim top_sim --gui --view ../scripts/${TOP_NAME}_sim.wcfg --testplusarg UVM_TESTNAME=${DOLLAR}${DOLLAR}${LBRACE}TEST_NAME:-${TEST_NAME}${RBRACE} --sv_seed ${DOLLAR}${DOLLAR}${LBRACE}SEED:-${SEED}${RBRACE} $(SIM_ARGS)
    DEPENDS elaborate
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Opening simulation in Vivado GUI..."
    USES_TERMINAL
)

# Define simulation artifacts natively to automatically get wiped out upon running `make clean`.
set_directory_properties(PROPERTIES ADDITIONAL_CLEAN_FILES 
    "xsim.dir;xvlog.log;xvlog.pb;xelab.log;xelab.pb;xsim.log;xsim.jou;webtalk_pn.xml;webtalk.jou;xsim_webtalk.tcl;xsim.covdb;top_sim.wdb;tr_db.log;*.stamp;*.hex"
)

# ==============================================================================
# 8. Dynamic Native Targets For Individually Assigned Tests
# ==============================================================================
# Finds all default UVM or plain systemverilog structural tests locally configured.
# Gives the user the capacity to call `make sim_<test_name>` without specifying standard CMAKE flags.
file(GLOB TEST_FILES "${CMAKE_SOURCE_DIR}/tb/tests/*_test.sv")
foreach(TEST_FILE IN LISTS TEST_FILES)
    get_filename_component(INDIVIDUAL_TEST_NAME "${TEST_FILE}" NAME_WE)
    
    # Explicit CLI explicit simulator target specific to test structure
    add_custom_target(sim_${INDIVIDUAL_TEST_NAME}
        COMMAND xsim top_sim ${VIVADO_PARMS_LIST} --testplusarg UVM_TESTNAME=${INDIVIDUAL_TEST_NAME} --sv_seed ${DOLLAR}${DOLLAR}${LBRACE}SEED:-${SEED}${RBRACE} $(SIM_ARGS)
        DEPENDS elaborate
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Running explicit simulation in CLI view: ${INDIVIDUAL_TEST_NAME}..."
        USES_TERMINAL
    )
    
    # Create a wrapper target for exactly this test name (Standard Mode)
    # This acts as an alias so users can invoke either `make sim_my_test` or `make my_test`
    add_custom_target(${INDIVIDUAL_TEST_NAME} DEPENDS sim_${INDIVIDUAL_TEST_NAME})
    
    # Explicit GUI explicit simulator target specific to test structure
    add_custom_target(gui_${INDIVIDUAL_TEST_NAME}
        COMMAND xsim top_sim --gui --view ../scripts/${TOP_NAME}_sim.wcfg --testplusarg UVM_TESTNAME=${INDIVIDUAL_TEST_NAME} --sv_seed ${DOLLAR}${DOLLAR}${LBRACE}SEED:-${SEED}${RBRACE} $(SIM_ARGS)
        DEPENDS elaborate
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Opening explicitly designed GUI simulation: ${INDIVIDUAL_TEST_NAME}..."
        USES_TERMINAL
    )
endforeach()

# ==============================================================================
# 9. External Targets (Tests compilation)
# ==============================================================================
# Injects the separate logic to sync and compile external RISC-V tests
include(${CMAKE_SOURCE_DIR}/scripts/compile_sanity_tests.cmake)

# ==============================================================================
# 10. FPGA Vivado Project Targets
# ==============================================================================
# Targets to automate Vivado project creation and opening the graphical UI.
include(${CMAKE_SOURCE_DIR}/scripts/fpga/fpga_targets.cmake)

# ==============================================================================
# 11. Documentation Targets
# ==============================================================================
# Render and validate documentation figures. See doc/figs/README.md.

add_custom_target(docs-figs
    COMMAND ${CMAKE_SOURCE_DIR}/scripts/docs/figs.sh --all
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Rendering documentation figures..."
    USES_TERMINAL
)

add_custom_target(docs-figs-check
    COMMAND ${CMAKE_SOURCE_DIR}/scripts/docs/figs.sh --check
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Checking documentation figures are up to date..."
    USES_TERMINAL
)

add_custom_target(docs-check
    COMMAND ${CMAKE_SOURCE_DIR}/scripts/docs/check_md.sh
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Checking documentation consistency..."
    USES_TERMINAL
)

# ==============================================================================
# 12. Verification and Signoff Targets
# ==============================================================================
# The gates are shell scripts under scripts/verify/; what lives here is only the
# wiring, so `make <gate>` (root proxy) and `make -C build <gate>` reach the same
# implementation a CI job would call. Elaboration stays with the build system:
# `regress` depends on `elaborate` and runs the existing snapshot, instead of
# building a second one inside the script.
#
# Every script sources its own EDA environment and exits 2 with an actionable
# message when it cannot judge anything, so these targets never pretend to pass.
#
# Usage:
#   make regress                                        every test in tests.tsv
#   make regress REGRESS_ARGS="--test T-01 --wave 0"
#   make regress REGRESS_ARGS="--record red --wave 0"   test-first evidence
#   make sanity    [SANITY_ARGS="rv32ui-p-add"]
#   make coverage  [COVERAGE_ARGS="--test T-01"]
#   make signoff-check [SIGNOFF_ARGS="--wave 0"]

# --- one CTest test per manifest line ----------------------------------------
# CMake owns what a test is and how it runs: name (T-id), command, timeout and
# labels (wave, requirements). `ctest -L wave0`, `ctest -R T-06`, `ctest -j4`
# and `make test` all work without a wrapper script.
#
# The verdict cannot come from the simulator: xsim exits 0 even with UVM_ERRORs.
# The testbench prints `UVM_RESULT: PASS|FAIL ...` from its report server, so the
# wrapper is a single grep and CTest reports the truth.
enable_testing()
set(VERIFY_MANIFEST "${CMAKE_SOURCE_DIR}/scripts/verify/tests.tsv")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/regress")

if(EXISTS "${VERIFY_MANIFEST}")
    file(STRINGS "${VERIFY_MANIFEST}" MANIFEST_LINES)
    set(MANIFEST_TESTS "")
    foreach(LINE IN LISTS MANIFEST_LINES)
        if(LINE MATCHES "^#" OR LINE STREQUAL "")
            continue()
        endif()
        string(REPLACE "\t" ";" FIELDS "${LINE}")
        list(GET FIELDS 0 TID)
        list(GET FIELDS 1 TEST_CLASS)
        list(GET FIELDS 2 TEST_WAVE)
        list(GET FIELDS 3 TEST_FRS)
        list(GET FIELDS 4 TEST_TIMEOUT)

        set(TEST_LOG "${CMAKE_BINARY_DIR}/regress/${TID}.log")
        add_test(NAME ${TID}
            COMMAND bash -c "xsim top_sim --R --testplusarg UVM_TESTNAME=${TEST_CLASS} --testplusarg NO_COLOR --sv_seed ${DOLLAR}${DOLLAR}{SEED:-${SEED}} > ${TEST_LOG} 2>&1 && grep -q '^UVM_RESULT: PASS' ${TEST_LOG}"
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")

        string(REPLACE "," ";" TEST_LABELS "${TEST_FRS}")
        list(APPEND TEST_LABELS "${TID}" "wave${TEST_WAVE}")
        set_tests_properties(${TID} PROPERTIES
            TIMEOUT ${TEST_TIMEOUT}
            LABELS "${TEST_LABELS}"
            FAIL_REGULAR_EXPRESSION "FAIL")
        list(APPEND MANIFEST_TESTS "${TID}")
    endforeach()
    message(STATUS "Verification tests from tests.tsv: ${MANIFEST_TESTS}")
endif()

# `make regress` = ctest, plus the evidence layer in the adapter. The adapter
# still owns what CTest cannot: the run directory, the digests and results.json.
add_custom_target(regress
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/scripts/verify/regress.cmake --no-elaborate $(REGRESS_ARGS)
    DEPENDS elaborate
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running the regression and recording evidence (results.json)..."
    USES_TERMINAL
)

# sanity.sh decides for itself whether it can run: with no +HEX mode in the
# testbench it records "not measurable" and exits 2, which is an answer, not a
# build failure. It deliberately does not depend on `elaborate`.
add_custom_target(sanity
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/scripts/verify/sanity.cmake $(SANITY_ARGS)
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running the bundled RISC-V test images (NFR-05)..."
    USES_TERMINAL
)

# coverage.sh re-runs `elaborate` with ELAB_ARGS (--cc_type/--cc_libs), because
# an instrumented snapshot is a different build of the same sources.
add_custom_target(coverage
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/scripts/verify/coverage.cmake $(COVERAGE_ARGS)
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Measuring and merging coverage with xcrg (NFR-06)..."
    USES_TERMINAL
)

add_custom_target(signoff-check
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/scripts/verify/signoff_check.cmake $(SIGNOFF_ARGS)
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running the signoff gate (A-09)..."
    USES_TERMINAL
)
