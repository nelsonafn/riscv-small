# =============================================================================
# scripts/verify/coverage.cmake - coverage (NFR-06), declared once, run by CTest
#
# One file, two modes, exactly like regress.cmake:
#
#   configure mode (included by CMakeLists.txt)
#       - declares the instrumented snapshot `top_sim_cov` through the same
#         `add_elaborate_target()` that builds `top_sim`, so the xelab command
#         line exists once, in CMakeLists.txt;
#       - declares one CTest test per manifest line (`COV-T-01`, label `cov`):
#         the regression's simulation command plus the coverage database flags;
#       - declares the `coverage` target that runs this file with `cmake -P`.
#
#   run mode (`cmake -P`, reached through `make coverage`)
#       selects the tests, merges the databases with xcrg and publishes
#       build/cov_report/summary.json.
#
#   cmake -P scripts/verify/coverage.cmake
#   cmake -P scripts/verify/coverage.cmake --test T-01 --seed 42
#
# Why these are CTest tests: a coverage run is the same test against another
# snapshot, so timeout, the `UVM_RESULT:` verdict, the log and the JUnit XML are
# the regression's contract, not a second implementation of it. A plain `ctest`
# skips them (exit 77 -> SKIP_RETURN_CODE) because it never built that snapshot;
# the coverage target asks for them with RISCV_COVERAGE=1.
#
# Functional coverage is code-read: the collector must contain at least one
# coverpoint. An empty covergroup makes it `missing_bins`, a signoff blocker.
#
# Results: build/cov_db/ (per-test databases), build/cov_report/summary.json and
#          the xcrg text report. The instrumented snapshot lives apart from
#          `top_sim`, so a coverage run no longer invalidates the regression's.
#
# Exit codes: 0 measured, 1 measured but no coverpoint, 2 not measurable.
# =============================================================================

if(CMAKE_VERSION VERSION_LESS 3.21)
    message(FATAL_ERROR "coverage.cmake needs CMake >= 3.21 for `ctest --output-junit` (found ${CMAKE_VERSION})")
endif()

set(DOLLAR "$")

# manifest rows, JUnit rows and the content digest: the same implementation
# regress.cmake and signoff_check.cmake use, in both modes.
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# =============================================================================
# Configure mode: declare the instrumented snapshot, the tests and the target.
# =============================================================================
if(NOT CMAKE_SCRIPT_MODE_FILE)
    if(NOT SEED)
        set(SEED 1)
    endif()

    set(COV_DB_ELAB "${CMAKE_BINARY_DIR}/cov_db_elab")
    set(COV_DB "${CMAKE_BINARY_DIR}/cov_db")
    set(COV_REPORT "${CMAKE_BINARY_DIR}/cov_report")
    file(MAKE_DIRECTORY "${COV_DB_ELAB}" "${COV_DB}" "${COV_REPORT}")

    # The snapshot is the only difference from `elaborate`: same function, same
    # command line, coverage flags appended by the caller.
    add_elaborate_target(elaborate_cov top_sim_cov
        --cc_type sbct --cc_libs
        --cov_db_dir ${COV_DB_ELAB} --cov_db_name cov_elab)

    riscv_manifest_rows(ROWS "${CMAKE_SOURCE_DIR}/scripts/verify/tests.tsv")
    set(COV_TESTS "")
    foreach(ROW IN LISTS ROWS)
        string(REPLACE "|" ";" FIELDS "${ROW}")
        list(GET FIELDS 0 TID)
        list(GET FIELDS 1 TEST_CLASS)
        list(GET FIELDS 2 TEST_WP)
        list(GET FIELDS 4 TEST_TIMEOUT)

        add_test(NAME COV-${TID}
            COMMAND bash -c "test -n \"${DOLLAR}RISCV_COVERAGE\" || exit 77; xsim top_sim_cov --R --testplusarg UVM_TESTNAME=${TEST_CLASS} --testplusarg NO_COLOR --sv_seed ${DOLLAR}{SEED:-${SEED}} --cov_db_dir ${COV_DB} --cov_db_name cov_${TID} > ${COV_REPORT}/${TID}.log 2>&1 && grep -q '^UVM_RESULT: PASS' ${COV_REPORT}/${TID}.log"
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
        set_tests_properties(COV-${TID} PROPERTIES
            TIMEOUT ${TEST_TIMEOUT}
            SKIP_RETURN_CODE 77
            LABELS "cov;${TID};wp${TEST_WP};class:${TEST_CLASS}")
        list(APPEND COV_TESTS "COV-${TID}")
    endforeach()
    message(STATUS "Coverage tests: ${COV_TESTS}")

    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE} $(COVERAGE_ARGS)
        DEPENDS elaborate_cov
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Measuring and merging coverage with xcrg (NFR-06)..."
        USES_TERMINAL
    )
    return()
endif()

# =============================================================================
# Run mode: elaborate through the build system, run, merge, publish.
# =============================================================================
get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(COV_DB "${BUILD}/cov_db")
set(COV_MERGED "${BUILD}/cov_merged")
set(COV_REPORT "${BUILD}/cov_report")

# --- arguments ---------------------------------------------------------------
# `foreach(RANGE 3 2)` counts *down* when there is no argument and would read
# the script path from CMAKE_ARGV2 as an option: guard the range.
set(ARGS "")
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        string(REGEX REPLACE "^--" "" ARG "${CMAKE_ARGV${I}}")
        list(APPEND ARGS "${ARG}")
    endforeach()
endif()
cmake_parse_arguments(R "" "seed;format" "test" ${ARGS})
if(R_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unknown option(s): ${R_UNPARSED_ARGUMENTS}")
endif()

set(SEED "${R_seed}")
if(NOT SEED)
    set(SEED "$ENV{SEED}")
endif()
if(NOT SEED)
    set(SEED 1)
endif()
if(NOT SEED MATCHES "^[0-9]+$")
    message(FATAL_ERROR "--seed must be an unsigned integer, got '${SEED}'")
endif()

set(FORMAT "${R_format}")
if(NOT FORMAT)
    set(FORMAT text)
endif()

# --- selection: the CTest filters, on the coverage-labelled tests -------------
set(CTEST_SELECT -L "^cov$")
if(R_test)
    list(JOIN R_test "|" PATTERN)
    list(APPEND CTEST_SELECT -R "^COV-(${PATTERN})$")
endif()

# --- chain: ./configure -> elaborate_cov ------------------------------------
file(MAKE_DIRECTORY "${BUILD}/regress")
if(NOT EXISTS "${BUILD}/Makefile")
    message(STATUS "build/ is not configured; bootstrapping with ./configure")
    execute_process(
        COMMAND "${ROOT}/configure"
        WORKING_DIRECTORY "${ROOT}"
        RESULT_VARIABLE RC
        OUTPUT_FILE "${BUILD}/regress/configure.log"
        ERROR_FILE "${BUILD}/regress/configure.log")
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "bootstrap failed; see build/regress/configure.log")
    endif()
endif()

message(STATUS "elaborating top_sim_cov through the build system")
execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${BUILD}" --target elaborate_cov
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE RC
    OUTPUT_FILE "${BUILD}/coverage_elaborate.log"
    ERROR_FILE "${BUILD}/coverage_elaborate.log")
if(NOT RC EQUAL 0)
    message(FATAL_ERROR "coverage elaboration failed (is the EDA environment sourced?); see build/coverage_elaborate.log")
endif()

# A database from an older run would be merged as if it were evidence. The
# elaboration database is not touched: it belongs to the snapshot, not to a run.
file(REMOVE_RECURSE "${COV_DB}" "${COV_MERGED}" "${COV_REPORT}")
file(MAKE_DIRECTORY "${COV_DB}" "${COV_REPORT}")

# --- run the tests through CTest --------------------------------------------
message(STATUS "running the coverage-labelled tests")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env RISCV_COVERAGE=1 "SEED=${SEED}"
            ${CMAKE_CTEST_COMMAND} --output-junit "${COV_REPORT}/junit.xml" ${CTEST_SELECT}
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE CTEST_RC
    OUTPUT_FILE "${COV_REPORT}/ctest.log"
    ERROR_FILE "${COV_REPORT}/ctest.log")

riscv_junit_rows(ROWS "${COV_REPORT}/junit.xml")
if(NOT ROWS)
    message(FATAL_ERROR "no coverage test matched the selection; see build/cov_report/ctest.log")
endif()

set(DB_NAMES "")
foreach(ROW IN LISTS ROWS)
    string(REPLACE "|" ";" FIELDS "${ROW}")
    list(GET FIELDS 0 NAME)
    list(GET FIELDS 1 STATUS)
    string(REPLACE "COV-" "" TID "${NAME}")
    if(NOT STATUS STREQUAL "pass")
        message(FATAL_ERROR "${TID} ${STATUS} under coverage; see build/cov_report/${TID}.log")
    endif()
    list(APPEND DB_NAMES "cov_${TID}")
endforeach()
message(STATUS "  ${DB_NAMES}")

# --- merge -------------------------------------------------------------------
set(MERGE_ARGS "")
foreach(DB IN LISTS DB_NAMES)
    list(APPEND MERGE_ARGS -cov_db_dir "${COV_DB}" -cov_db_name "${DB}")
endforeach()

message(STATUS "merging ${DB_NAMES} into build/cov_merged")
execute_process(
    COMMAND xcrg ${MERGE_ARGS}
            -merge_dir "${COV_MERGED}" -merge_db_name merged
            -report_dir "${COV_REPORT}" -report_format "${FORMAT}"
    RESULT_VARIABLE RC
    OUTPUT_FILE "${COV_REPORT}/xcrg.log"
    ERROR_FILE "${COV_REPORT}/xcrg.log")
if(NOT RC EQUAL 0)
    message(FATAL_ERROR "xcrg merge failed; see build/cov_report/xcrg.log")
endif()

# --- publish -----------------------------------------------------------------
set(REPORT_FILE "${COV_REPORT}/functionalCoverageReport/xcrg_func_cov_report.txt")
if(NOT EXISTS "${REPORT_FILE}")
    set(REPORT_FILE "${COV_REPORT}/xcrg.log")
endif()

file(READ "${REPORT_FILE}" REPORT_TEXT)
string(REGEX MATCHALL "Coverage Score[ ]*:,[ ]*[0-9.]+" SCORE_LINES "${REPORT_TEXT}")
set(PERCENTAGES "")
foreach(LINE IN LISTS SCORE_LINES)
    string(REGEX REPLACE ".*,[ ]*" "" VALUE "${LINE}")
    list(APPEND PERCENTAGES "${VALUE}")
endforeach()
if(PERCENTAGES)
    list(REMOVE_DUPLICATES PERCENTAGES)
    list(SORT PERCENTAGES)
    string(REPLACE ";" "," PERCENTAGES "${PERCENTAGES}")
endif()

# Functional coverage is code-read: it is measured only if the collector has a
# coverpoint, whatever xcrg reports for code coverage.
file(READ "${ROOT}/tb/env/top/riscv_small_coverage.sv" COV_SOURCE)
string(REGEX MATCHALL "coverpoint" COV_POINTS "${COV_SOURCE}")
list(LENGTH COV_POINTS N_COVERPOINTS)

set(STATUS "measured")
set(REASON "")
if(N_COVERPOINTS EQUAL 0)
    set(STATUS "missing_bins")
    set(REASON "tb/env/top/riscv_small_coverage.sv has no coverpoint: functional coverage is not measured (NFR-06)")
endif()

riscv_tree_digest(RTL_DIGEST "${ROOT}/rtl")
riscv_tree_digest(TB_DIGEST "${ROOT}/tb")
string(REPLACE ";" "\", \"" DB_JSON "${DB_NAMES}")
string(TIMESTAMP STAMP "%Y-%m-%dT%H:%M:%SZ" UTC)

file(WRITE "${COV_REPORT}/summary.json" "{
  \"kind\": \"coverage\",
  \"status\": \"${STATUS}\",
  \"reason\": \"${REASON}\",
  \"rtl_digest\": \"${RTL_DIGEST}\",
  \"tb_digest\": \"${TB_DIGEST}\",
  \"recorded\": \"${STAMP}\",
  \"seed\": ${SEED},
  \"databases\": [ \"${DB_JSON}\" ],
  \"merged\": \"build/cov_merged/merged\",
  \"report\": \"${REPORT_FILE}\",
  \"coverpoints\": ${N_COVERPOINTS},
  \"percentages\": \"${PERCENTAGES}\"
}
")

message(STATUS "report:  ${REPORT_FILE}")
message(STATUS "summary: build/cov_report/summary.json")
message("COVERAGE status=${STATUS} coverpoints=${N_COVERPOINTS} percentages=${PERCENTAGES}")

if(NOT STATUS STREQUAL "measured")
    message(FATAL_ERROR "${REASON}")
endif()
