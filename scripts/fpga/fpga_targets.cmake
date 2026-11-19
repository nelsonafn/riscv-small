# ==============================================================================
# File: fpga_targets.cmake
# Description: CMake targets for the Xilinx Vivado flow, parametrised so the
#              same scripts drive any top in this repository.
#
# The top, the project name, the part and the source list are inputs, not
# literals: they come from the cache variables declared next to TOP_NAME in
# CMakeLists.txt. The source list is expanded from `srclist/<top>.srclist`,
# which is the same set of files the simulation compiles and the regression
# verifies -- never a glob over rtl/, because rtl/ also holds modules that are
# not part of the DUT.
# ==============================================================================

# Expand a .srclist into the SystemVerilog files it names, recursively.
# Reads the same files the build reads; it does not re-implement the build's
# library/target creation, which has side effects and exposes no file list.
function(_riscv_srclist_expand OUT_VAR SRCLIST)
    if(NOT EXISTS "${SRCLIST}")
        message(FATAL_ERROR "riscv_srclist_expand: no such srclist: ${SRCLIST}")
    endif()
    file(STRINGS "${SRCLIST}" _lines)
    set(_files "")
    foreach(_line IN LISTS _lines)
        string(STRIP "${_line}" _line)
        if(_line STREQUAL "" OR _line MATCHES "^#")
            continue()
        endif()
        if(_line MATCHES "\\+incdir\\+")
            continue()
        elseif(_line MATCHES "\\.srclist$")
            _riscv_srclist_expand(_sub "${CMAKE_SOURCE_DIR}/${_line}")
            list(APPEND _files ${_sub})
        elseif(_line MATCHES "\\.(sv|svh)$")
            list(APPEND _files "${CMAKE_SOURCE_DIR}/${_line}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _files)
    set(${OUT_VAR} "${_files}" PARENT_SCOPE)
endfunction()

function(riscv_srclist_files OUT_VAR TOP)
    _riscv_srclist_expand(_files "${CMAKE_SOURCE_DIR}/srclist/${TOP}.srclist")
    set(${OUT_VAR} "${_files}" PARENT_SCOPE)
endfunction()

# --- the source list this flow synthesises -----------------------------------
riscv_srclist_files(FPGA_SOURCES "${FPGA_TOP}")
list(LENGTH FPGA_SOURCES FPGA_SOURCE_COUNT)
if(FPGA_SOURCE_COUNT EQUAL 0)
    message(FATAL_ERROR "fpga_targets: srclist/${FPGA_TOP}.srclist names no SystemVerilog file")
endif()
set(FPGA_FILELIST "${CMAKE_BINARY_DIR}/fpga/${FPGA_TOP}.files")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/fpga")
file(WRITE "${FPGA_FILELIST}" "")
foreach(_src IN LISTS FPGA_SOURCES)
    file(APPEND "${FPGA_FILELIST}" "${_src}\n")
endforeach()
message(STATUS "  - FPGA top       : ${FPGA_TOP} (${FPGA_SOURCE_COUNT} file(s) from srclist)")
message(STATUS "  - FPGA project   : ${FPGA_PROJECT_NAME} on ${FPGA_PART}")

set(FPGA_PROJECT_FILE "${CMAKE_BINARY_DIR}/fpga/${FPGA_PROJECT_NAME}.xpr")
set(FPGA_SRC_DIR "${CMAKE_SOURCE_DIR}/scripts/fpga")

# Every target below builds the project first when it is missing, so a single
# command works from a clean build/.
set(FPGA_ENSURE_PROJECT
    COMMAND ${CMAKE_COMMAND} -E echo "Vivado project: ${FPGA_PROJECT_FILE}"
)

add_custom_target(create_fpga
    COMMAND vivado -mode batch -notrace
            -source ${FPGA_SRC_DIR}/create_project.tcl
            -tclargs ${FPGA_PROJECT_NAME} ${FPGA_TOP} ${FPGA_PART}
                     ${FPGA_FILELIST} ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Creating/updating the Vivado project for ${FPGA_TOP}..."
    USES_TERMINAL
)

add_custom_target(open_fpga
    COMMAND test -f ${FPGA_PROJECT_FILE} || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado ${FPGA_PROJECT_FILE} &
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Opening the Vivado project in the GUI..."
    USES_TERMINAL
)

# The linter runs standalone: it needs the source list, not the project.
add_custom_target(lint_fpga
    COMMAND vivado -mode batch -notrace
            -source ${FPGA_SRC_DIR}/run_lint.tcl
            -tclargs ${FPGA_TOP} ${FPGA_FILELIST} ${FPGA_PART}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running the RTL linter on ${FPGA_TOP}..."
    USES_TERMINAL
)

add_custom_target(synth_fpga
    COMMAND test -f ${FPGA_PROJECT_FILE} || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado -mode batch -notrace
            -source ${FPGA_SRC_DIR}/run_synth.tcl
            -tclargs ${FPGA_PROJECT_NAME} ${FPGA_TOP} ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Synthesising ${FPGA_TOP} on ${FPGA_PART}..."
    USES_TERMINAL
)

add_custom_target(impl_fpga
    COMMAND test -f ${FPGA_PROJECT_FILE} || ${CMAKE_COMMAND} --build . --target create_fpga
    COMMAND vivado -mode batch -notrace
            -source ${FPGA_SRC_DIR}/run_impl.tcl
            -tclargs ${FPGA_PROJECT_NAME} ${FPGA_TOP} ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Implementing ${FPGA_TOP} on ${FPGA_PART}..."
    USES_TERMINAL
)
add_dependencies(impl_fpga synth_fpga)
