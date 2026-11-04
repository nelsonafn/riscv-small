# =============================================================================
# scripts/verify/common.cmake - the one shared library of the verification gates
#
# Included by regress.cmake, coverage.cmake, sanity.cmake, negative_control.cmake
# and signoff_check.cmake, in configure mode and in `cmake -P` mode. It defines
# functions and two path variables; it never declares a target.
#
#   riscv_manifest_rows(OUT <tests.tsv>)        one row: T-id|uvm_test|wp|frs|timeout|red|extra
#   riscv_manifest_extra(OUT <row>)             the optional 7th column (`sanity:<image>`)
#   riscv_manifest_sanity_images(OUT <manifest>) images named by the 7th column
#   riscv_manifest_sanity_targets(OUT <manifest>) `compile_sanity_<image>` for each
#   riscv_junit_rows(OUT <junit.xml>)           CTest verdicts: T-id|pass|fail|timeout|skip|class
#   riscv_tree_digest(OUT <dir>)                sha256 over the .sv/.svh content
#   riscv_tree_digests(OUT_RTL OUT_TB <root>)   the RTL/TB pair every gate records
#   riscv_bootstrap_build(<log>)                ./configure when build/Makefile is absent
#   riscv_ctest_run(<junit> <workdir> LOG <log> [ENV ...] [SELECT ...])
#   riscv_xsim_command(OUT ...)                 the one `bash -c` xsim command string
#
# Everything that was copied once per gate lives here. A gate module declares
# only what is its own: its selection, its artefacts and its verdict.
# =============================================================================

if(DEFINED RISCV_COMMON_INCLUDED)
    return()
endif()
set(RISCV_COMMON_INCLUDED TRUE)

# `ctest --output-junit` is the runner contract; one check for every gate.
if(CMAKE_VERSION VERSION_LESS 3.21)
    message(FATAL_ERROR "the verification gates need CMake >= 3.21 for `ctest --output-junit` (found ${CMAKE_VERSION})")
endif()

get_filename_component(RISCV_VERIFY_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
get_filename_component(RISCV_ROOT "${RISCV_VERIFY_DIR}/../.." ABSOLUTE)

# --- safe line reader --------------------------------------------------------
# file(STRINGS) splits a line at every non-ASCII byte (measured: "emdash—tail"
# becomes two items), and the specification tables put the status in the last
# column -- so 35 of the 59 FR rows lost it. Read the whole file and split on
# newlines only; `;` is CMake's list separator, so neutralise it first.
function(riscv_read_lines OUT_VAR FILE)
    file(READ "${FILE}" TEXT)
    string(REPLACE ";" "@SEMI@" TEXT "${TEXT}")
    string(REPLACE "\n" ";" LINES "${TEXT}")
    set(${OUT_VAR} "${LINES}" PARENT_SCOPE)
endfunction()

# --- manifest ----------------------------------------------------------------
function(riscv_manifest_rows OUT_VAR MANIFEST)
    if(NOT EXISTS "${MANIFEST}")
        message(FATAL_ERROR "manifest not found: ${MANIFEST}")
    endif()
    file(STRINGS "${MANIFEST}" LINES)
    set(ROWS "")
    foreach(LINE IN LISTS LINES)
        if(LINE MATCHES "^#" OR LINE STREQUAL "")
            continue()
        endif()
        # `|` because `;` is CMake's list separator and the fields are already a
        # list by the time a caller splits them.
        string(REPLACE "\t" "|" ROW "${LINE}")
        list(APPEND ROWS "${ROW}")
    endforeach()
    set(${OUT_VAR} "${ROWS}" PARENT_SCOPE)
endfunction()

# The optional 7th column is `sanity:<image>`; anything else is no image.
function(riscv_manifest_extra OUT_VAR ROW)
    set(IMAGE "")
    string(REPLACE "|" ";" FIELDS "${ROW}")
    list(LENGTH FIELDS NF)
    if(NF GREATER 6)
        list(GET FIELDS 6 EXTRA)
        if(EXTRA MATCHES "^sanity:(.+)$")
            set(IMAGE "${CMAKE_MATCH_1}")
        endif()
    endif()
    set(${OUT_VAR} "${IMAGE}" PARENT_SCOPE)
endfunction()

function(riscv_manifest_sanity_images OUT_VAR MANIFEST)
    riscv_manifest_rows(ROWS "${MANIFEST}")
    set(IMAGES "")
    foreach(ROW IN LISTS ROWS)
        riscv_manifest_extra(IMAGE "${ROW}")
        if(IMAGE)
            list(APPEND IMAGES "${IMAGE}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES IMAGES)
    set(${OUT_VAR} "${IMAGES}" PARENT_SCOPE)
endfunction()

function(riscv_manifest_sanity_targets OUT_VAR MANIFEST)
    riscv_manifest_sanity_images(IMAGES "${MANIFEST}")
    set(TARGETS "")
    foreach(IMAGE IN LISTS IMAGES)
        list(APPEND TARGETS "compile_sanity_${IMAGE}")
    endforeach()
    set(${OUT_VAR} "${TARGETS}" PARENT_SCOPE)
endfunction()

# --- CTest's verdict ---------------------------------------------------------
function(riscv_junit_rows OUT_VAR XML_FILE)
    if(NOT EXISTS "${XML_FILE}")
        message(FATAL_ERROR "no JUnit report: ${XML_FILE}")
    endif()
    file(READ "${XML_FILE}" XML)

    # CTest writes labels as `a;b;c` and `;` is also CMake's list separator:
    # neutralise it before splitting, or every label boundary becomes a fake
    # test case (measured: 3 tests became 14 rows).
    string(REPLACE ";" "@" XML "${XML}")
    string(REPLACE "<testcase " ";" CASES "${XML}")
    list(REMOVE_AT CASES 0)

    set(ROWS "")
    foreach(CASE IN LISTS CASES)
        string(REGEX MATCH "name=\"([^\"]*)\"" _ "${CASE}")
        set(ID "${CMAKE_MATCH_1}")

        # status="run" -> pass, "notrun" -> skip (SKIP_RETURN_CODE),
        # <failure message="Timeout"/> -> timeout, anything else -> fail.
        string(REGEX MATCH "status=\"([^\"]*)\"" _ "${CASE}")
        set(STATUS "fail")
        if(CMAKE_MATCH_1 STREQUAL "run")
            set(STATUS "pass")
        elseif(CMAKE_MATCH_1 STREQUAL "notrun")
            set(STATUS "skip")
        elseif(CASE MATCHES "message=\"Timeout\"")
            set(STATUS "timeout")
        endif()

        set(CLASS "")
        string(REGEX MATCH "cmake_labels\" value=\"([^\"]*)\"" _ "${CASE}")
        string(REPLACE "@" ";" LABELS "${CMAKE_MATCH_1}")
        foreach(LABEL IN LISTS LABELS)
            if(LABEL MATCHES "^class:(.+)$")
                set(CLASS "${CMAKE_MATCH_1}")
            endif()
        endforeach()

        # CMP0007: a row ending in an empty field makes `list(GET)` warn.
        if(CLASS STREQUAL "")
            set(CLASS "-")
        endif()
        list(APPEND ROWS "${ID}|${STATUS}|${CLASS}")
    endforeach()
    set(${OUT_VAR} "${ROWS}" PARENT_SCOPE)
endfunction()

# --- content digest ----------------------------------------------------------
function(riscv_tree_digest OUT_VAR DIR)
    file(GLOB_RECURSE FILES "${DIR}/*.sv" "${DIR}/*.svh")
    list(SORT FILES)
    set(ACC "")
    foreach(F IN LISTS FILES)
        file(READ "${F}" CONTENT)
        string(APPEND ACC "${CONTENT}")
    endforeach()
    string(SHA256 H "${ACC}")
    set(${OUT_VAR} "sha256:${H}" PARENT_SCOPE)
endfunction()

function(riscv_tree_digests OUT_RTL OUT_TB ROOT)
    riscv_tree_digest(RTL "${ROOT}/rtl")
    riscv_tree_digest(TB "${ROOT}/tb")
    set(${OUT_RTL} "${RTL}" PARENT_SCOPE)
    set(${OUT_TB} "${TB}" PARENT_SCOPE)
endfunction()

# --- chain and runner --------------------------------------------------------
function(riscv_bootstrap_build LOG)
    if(NOT EXISTS "${RISCV_ROOT}/build/Makefile")
        message(STATUS "build/ is not configured; bootstrapping with ./configure")
        execute_process(
            COMMAND "${RISCV_ROOT}/configure"
            WORKING_DIRECTORY "${RISCV_ROOT}"
            RESULT_VARIABLE RC
            OUTPUT_FILE "${LOG}"
            ERROR_FILE "${LOG}")
        if(NOT RC EQUAL 0)
            message(FATAL_ERROR "bootstrap failed; see ${LOG}")
        endif()
    endif()
endfunction()

function(riscv_ctest_run JUNIT WORKDIR)
    cmake_parse_arguments(C "" "LOG" "ENV;SELECT" ${ARGN})
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "riscv_ctest_run: unknown ${C_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT C_LOG)
        message(FATAL_ERROR "riscv_ctest_run: LOG is required")
    endif()
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env ${C_ENV}
                ${CMAKE_CTEST_COMMAND} --output-junit "${JUNIT}" ${C_SELECT}
        WORKING_DIRECTORY "${WORKDIR}"
        RESULT_VARIABLE RC
        OUTPUT_FILE "${C_LOG}"
        ERROR_FILE "${C_LOG}")
    set(RISCV_CTEST_RC "${RC}" PARENT_SCOPE)
endfunction()

# One command string for every CTest test. Options:
#   SNAPSHOT <top_sim|top_sim_cov>  TEST <uvm class>  LOG <file>
#   [SEED <n>] [SKIP_ENV RISCV_SANITY|RISCV_COVERAGE] [TRACE_ENV]
#   [HEX <hex> TOHOST_FILE <tohost>] [COV_DB_DIR <dir> COV_DB_NAME <name>]
#   [REQUIRE_SANITY]
# The command always requires `^UVM_RESULT: PASS`; REQUIRE_SANITY adds the
# `^SANITY: PASS` grep. The hex/tohost paths are read at run time (never
# hardcoded), and a missing image fails with a clear message.
function(riscv_xsim_command OUT_VAR)
    set(DOLLAR "$")
    cmake_parse_arguments(X "REQUIRE_SANITY;TRACE_ENV"
        "SNAPSHOT;TEST;LOG;SEED;SKIP_ENV;HEX;TOHOST_FILE;COV_DB_DIR;COV_DB_NAME" "" ${ARGN})
    if(X_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "riscv_xsim_command: unknown ${X_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT X_SNAPSHOT OR NOT X_TEST OR NOT X_LOG)
        message(FATAL_ERROR "riscv_xsim_command: SNAPSHOT, TEST and LOG are required")
    endif()

    set(CMD "")
    if(X_TOHOST_FILE)
        string(APPEND CMD "TOHOST=${DOLLAR}(cat ${X_TOHOST_FILE}); ")
    endif()
    if(X_HEX)
        string(APPEND CMD "test -f ${X_HEX} || { echo 'missing ${X_HEX}: build the sanity image first'; exit 1; }; ")
    endif()
    if(X_TRACE_ENV)
        string(APPEND CMD "TRACE=\"\"; if [ -n \"${DOLLAR}SANITY_TRACE\" ]; then TRACE=\"--testplusarg TRACE\"; fi; ")
    endif()
    if(X_SKIP_ENV)
        string(APPEND CMD "test -n \"${DOLLAR}${X_SKIP_ENV}\" || exit 77; ")
    endif()
    string(APPEND CMD "xsim ${X_SNAPSHOT} --R --testplusarg UVM_TESTNAME=${X_TEST} --testplusarg NO_COLOR")
    if(X_SEED)
        # `SEED=42 make regress` sets the env at ctest time; fall back to the
        # configure-time seed. Same contract as the old per-gate string.
        string(APPEND CMD " --sv_seed ${DOLLAR}{SEED:-${X_SEED}}")
    endif()
    if(X_HEX)
        string(APPEND CMD " --testplusarg HEX=${X_HEX} --testplusarg TOHOST=${DOLLAR}TOHOST")
    endif()
    if(X_COV_DB_DIR)
        string(APPEND CMD " --cov_db_dir ${X_COV_DB_DIR} --cov_db_name ${X_COV_DB_NAME}")
    endif()
    if(X_TRACE_ENV)
        string(APPEND CMD " ${DOLLAR}TRACE")
    endif()
    string(APPEND CMD " > ${X_LOG} 2>&1 && grep -q '^UVM_RESULT: PASS' ${X_LOG}")
    if(X_REQUIRE_SANITY)
        string(APPEND CMD " && grep -q '^SANITY: PASS' ${X_LOG}")
    endif()
    set(${OUT_VAR} "${CMD}" PARENT_SCOPE)
endfunction()
