# ==============================================================================
# File: fpga_targets.cmake
# Description: Custom CMake targets to automate Xilinx Vivado project flow
# ==============================================================================

# Target to create or refresh the Vivado project
add_custom_target(create_fpga
    COMMAND vivado -mode batch -source ${CMAKE_SOURCE_DIR}/scripts/fpga/create_project.tcl
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Creating/updating Vivado project for RFSoC 4x2..."
    USES_TERMINAL
)

# Target to open the project in GUI mode
add_custom_target(open_fpga
    COMMAND test -f ${CMAKE_BINARY_DIR}/fpga/cvqkd_topsoc.xpr || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado ${CMAKE_BINARY_DIR}/fpga/cvqkd_topsoc.xpr &
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Opening Vivado project in GUI..."
    USES_TERMINAL
)

# Target to run RTL Linter
add_custom_target(lint_fpga
    COMMAND test -f ${CMAKE_BINARY_DIR}/fpga/cvqkd_topsoc.xpr || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado -mode batch -source ${CMAKE_SOURCE_DIR}/scripts/fpga/run_lint.tcl
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running RTL Linter for RFSoC 4x2..."
    USES_TERMINAL
)

# Target to run synthesis
add_custom_target(synth_fpga
    COMMAND test -f ${CMAKE_BINARY_DIR}/fpga/cvqkd_topsoc.xpr || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado -mode batch -source ${CMAKE_SOURCE_DIR}/scripts/fpga/run_synth.tcl
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running synthesis for RFSoC 4x2..."
    USES_TERMINAL
)

# Target to run implementation (place & route)
add_custom_target(impl_fpga
    COMMAND test -f ${CMAKE_BINARY_DIR}/fpga/cvqkd_topsoc.xpr || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado -mode batch -source ${CMAKE_SOURCE_DIR}/scripts/fpga/run_impl.tcl
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running implementation and bitstream generation for RFSoC 4x2..."
    USES_TERMINAL
)
add_dependencies(impl_fpga synth_fpga)
