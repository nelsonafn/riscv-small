# =============================================================================
# scripts/verify/regress.cmake - the regression, declared once and run by CTest.
#
# One file, two modes, so the build graph and the evidence layer cannot disagree
# about what a test is:
#
#   configure mode (included by CMakeLists.txt)
#       declares one CTest test per line of scripts/verify/tests.tsv -- name,
#       command, timeout, labels -- and the `regress` target that runs this same
#       file with `cmake -P`;
#
#   run mode (`cmake -P`, reached through `make regress`)
#       runs the selection through CTest and writes the evidence the signoff
#       gate audits.
#
#   cmake -P scripts/verify/regress.cmake --list
#   cmake -P scripts/verify/regress.cmake --wave 0
#   cmake -P scripts/verify/regress.cmake --test T-06 --record red --wave 0
#
# Division of labour -- each fact is defined once, where it already lived:
#   CTest     test name (T-id), command, timeout, labels, selection (-R/-L),
#             verdict (--output-junit);
#   the build ./configure and `elaborate` (the `regress` target depends on it);
#   this file the run directory, rtl_digest/tb_digest, results.json +
#             summary.md and --record red (some selected test must fail).
#
# Exit codes: 0 expectation met; 1 expectation not met or usage/build error.
# =============================================================================

if(CMAKE_VERSION VERSION_LESS 3.21)
    message(FATAL_ERROR "regress.cmake needs CMake >= 3.21 for `ctest --output-junit` (found ${CMAKE_VERSION})")
endif()

set(DOLLAR "$")

# Manifest rows, JUnit rows and the content digest are shared with
# coverage.cmake and signoff_check.cmake: one implementation each.
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# =============================================================================
# Configure mode: declare the tests and the target, then leave.
# =============================================================================
if(NOT CMAKE_SCRIPT_MODE_FILE)
    enable_testing()

    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/regress")
    riscv_manifest_rows(ROWS "${CMAKE_SOURCE_DIR}/scripts/verify/tests.tsv")

    if(NOT SEED)
        set(SEED 1)
    endif()

    set(MANIFEST_TESTS "")
    foreach(ROW IN LISTS ROWS)
        string(REPLACE "|" ";" FIELDS "${ROW}")
        list(GET FIELDS 0 TID)
        list(GET FIELDS 1 TEST_CLASS)
        list(GET FIELDS 2 TEST_WAVE)
        list(GET FIELDS 3 TEST_FRS)
        list(GET FIELDS 4 TEST_TIMEOUT)

        # The verdict is the testbench's own `UVM_RESULT:` line, never xsim's
        # exit code: xsim returns 0 even with UVM_ERRORs. The log stays on disk
        # as evidence; CTest only sees the grep.
        set(TEST_LOG "${CMAKE_BINARY_DIR}/regress/${TID}.log")
        add_test(NAME ${TID}
            COMMAND bash -c "xsim top_sim --R --testplusarg UVM_TESTNAME=${TEST_CLASS} --testplusarg NO_COLOR --sv_seed ${DOLLAR}{SEED:-${SEED}} > ${TEST_LOG} 2>&1 && grep -q '^UVM_RESULT: PASS' ${TEST_LOG}"
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")

        # Labels are the selection keys and the class carrier: run mode filters
        # with -R (T-id) and -L (wave/class) and reads the class back from the
        # JUnit label, so it never parses tests.tsv a second time.
        string(REPLACE "," ";" TEST_LABELS "${TEST_FRS}")
        list(APPEND TEST_LABELS "${TID}" "wave${TEST_WAVE}" "class:${TEST_CLASS}")
        set_tests_properties(${TID} PROPERTIES
            TIMEOUT ${TEST_TIMEOUT}
            LABELS "${TEST_LABELS}")
        list(APPEND MANIFEST_TESTS "${TID}")
    endforeach()
    message(STATUS "Verification tests from tests.tsv: ${MANIFEST_TESTS}")

    # Elaboration belongs to the build system, so the target depends on it and
    # run mode asks the build system again: a direct `cmake -P` can never
    # simulate a stale snapshot. `$(REGRESS_ARGS)` is a make variable, e.g.
    # `make regress REGRESS_ARGS="--wave 0"`.
    add_custom_target(regress
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE} $(REGRESS_ARGS)
        DEPENDS elaborate
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running the regression and recording evidence (results.json)..."
        USES_TERMINAL
    )
    return()
endif()

# =============================================================================
# Run mode: select, run, record.
# =============================================================================
get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")

# --- arguments ---------------------------------------------------------------
# `foreach(RANGE 3 2)` counts *down* when there is no argument, reading the
# script path from CMAKE_ARGV2 and reporting it as an option: guard the range.
set(ARGS "")
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        string(REGEX REPLACE "^--" "" ARG "${CMAKE_ARGV${I}}")
        list(APPEND ARGS "${ARG}")
    endforeach()
endif()
cmake_parse_arguments(R "all;list" "wave;seed;record;out;config" "test" ${ARGS})
if(R_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unknown option(s): ${R_UNPARSED_ARGUMENTS}")
endif()

set(SEED "${R_seed}")
if(NOT SEED)
    set(SEED "$ENV{SEED}")   # `SEED=42 make regress`, the documented override
endif()
if(NOT SEED)
    set(SEED 1)
endif()
if(NOT SEED MATCHES "^[0-9]+$")
    message(FATAL_ERROR "--seed must be an unsigned integer, got '${SEED}'")
endif()

set(RECORD "${R_record}")
if(NOT RECORD)
    set(RECORD green)
endif()
if(NOT RECORD MATCHES "^(green|red)$")
    message(FATAL_ERROR "--record must be 'green' or 'red', got '${RECORD}'")
endif()

set(CONFIG_NAME "${R_config}")
if(NOT CONFIG_NAME)
    set(CONFIG_NAME default)
endif()

# --- selection: CTest's own filters, nothing re-implemented -------------------
# The coverage tests (label `cov`) are these same tests against an instrumented
# snapshot: they belong to `make coverage`, never to the regression.
set(CTEST_SELECT -LE "^cov$")
if(R_test)
    list(JOIN R_test "|" PATTERN)
    list(APPEND CTEST_SELECT -R "^(${PATTERN})$")
endif()
if(NOT "${R_wave}" STREQUAL "")
    list(APPEND CTEST_SELECT -L "^wave${R_wave}$")
endif()

# --- chain: ./configure -> elaborate ----------------------------------------
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

if(R_list)
    execute_process(COMMAND ${CMAKE_CTEST_COMMAND} -N ${CTEST_SELECT}
        WORKING_DIRECTORY "${BUILD}" RESULT_VARIABLE RC)
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "ctest -N failed")
    endif()
    return()
endif()

message(STATUS "elaborating through the build system")
execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${BUILD}" --target elaborate
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE RC
    OUTPUT_FILE "${BUILD}/regress/elaborate.log"
    ERROR_FILE "${BUILD}/regress/elaborate.log")
if(NOT RC EQUAL 0)
    message(FATAL_ERROR "elaboration failed (is the EDA environment sourced?); see build/regress/elaborate.log")
endif()

# --- run directory and digests -----------------------------------------------
set(OUT "${R_out}")
if(NOT OUT)
    string(TIMESTAMP STAMP "%Y-%m-%dT%H-%M-%SZ" UTC)
    set(OUT "${BUILD}/regress/${STAMP}")
endif()
file(MAKE_DIRECTORY "${OUT}")
file(RELATIVE_PATH OUT_REL "${ROOT}" "${OUT}")

# A result is tied to the code it ran against by content, not by commit: the
# project forbids automatic commits, so the digest is the evidence key.
riscv_tree_digest(RTL_DIGEST "${ROOT}/rtl")
riscv_tree_digest(TB_DIGEST "${ROOT}/tb")
string(TIMESTAMP STARTED "%Y-%m-%dT%H:%M:%SZ" UTC)

# --- run: one ctest invocation, verdict from the JUnit report ---------------
message(STATUS "running the selection through ctest")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env "SEED=${SEED}"
            ${CMAKE_CTEST_COMMAND} --output-junit "${OUT}/junit.xml" ${CTEST_SELECT}
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE CTEST_RC
    OUTPUT_FILE "${OUT}/ctest.log"
    ERROR_FILE "${OUT}/ctest.log")

if(NOT EXISTS "${OUT}/junit.xml")
    message(FATAL_ERROR "ctest produced no JUnit report; see ${OUT_REL}/ctest.log")
endif()
riscv_junit_rows(ROWS "${OUT}/junit.xml")
if(NOT ROWS)
    message(FATAL_ERROR "no test matched the selection; see ${OUT_REL}/ctest.log")
endif()

function(count_in OUT_VAR TEXT PATTERN)
    set(N 0)
    if(TEXT MATCHES "${PATTERN}")
        set(N "${CMAKE_MATCH_1}")
    endif()
    set(${OUT_VAR} "${N}" PARENT_SCOPE)
endfunction()

set(N_PASS 0)
set(N_FAIL 0)
set(N_TIMEOUT 0)
set(TEST_ROWS "")

foreach(ROW IN LISTS ROWS)
    string(REPLACE "|" ";" FIELDS "${ROW}")
    list(GET FIELDS 0 ID)
    list(GET FIELDS 1 STATUS)
    list(GET FIELDS 2 TEST_CLASS)

    # A test that did not run is missing evidence, not a pass.
    if(STATUS STREQUAL "skip")
        set(STATUS "fail")
    endif()

    if(STATUS STREQUAL "pass")
        math(EXPR N_PASS "${N_PASS} + 1")
    elseif(STATUS STREQUAL "timeout")
        math(EXPR N_TIMEOUT "${N_TIMEOUT} + 1")
    else()
        math(EXPR N_FAIL "${N_FAIL} + 1")
    endif()

    # The per-test log the CTest command wrote; keep a copy with the run.
    set(LOG_REF "${OUT_REL}/ctest.log")
    set(LOG_TEXT "")
    if(EXISTS "${BUILD}/regress/${ID}.log")
        file(COPY "${BUILD}/regress/${ID}.log" DESTINATION "${OUT}")
        set(LOG_REF "${OUT_REL}/${ID}.log")
        file(READ "${BUILD}/regress/${ID}.log" LOG_TEXT)
    endif()

    count_in(UVM_ERRORS "${LOG_TEXT}" "UVM_ERROR *: *([0-9]+)")
    count_in(UVM_FATALS "${LOG_TEXT}" "UVM_FATAL *: *([0-9]+)")
    count_in(SB_PASS "${LOG_TEXT}" "PASS *: *([0-9]+)")
    count_in(SB_FAIL "${LOG_TEXT}" "FAIL *: *([0-9]+)")

    if(RECORD STREQUAL "red")
        set(EXPECT "fail")
    else()
        set(EXPECT "pass")
    endif()

    # Field order is a contract: signoff_check matches this literal prefix.
    list(APPEND TEST_ROWS "    { \"id\": \"${ID}\", \"test\": \"${TEST_CLASS}\", \"status\": \"${STATUS}\", \"expect\": \"${EXPECT}\", \"uvm_errors\": ${UVM_ERRORS}, \"uvm_fatals\": ${UVM_FATALS}, \"sb_pass\": ${SB_PASS}, \"sb_fail\": ${SB_FAIL}, \"log\": \"${LOG_REF}\" }")
    message(STATUS "  ${ID} ${STATUS}")
endforeach()

string(TIMESTAMP FINISHED "%Y-%m-%dT%H:%M:%SZ" UTC)
string(REPLACE ";" ",\n" TESTS_JSON "${TEST_ROWS}")

if(NOT "${R_wave}" STREQUAL "")
    set(WAVE_JSON "${R_wave}")
else()
    set(WAVE_JSON "null")
endif()

file(WRITE "${OUT}/results.json" "{
  \"kind\": \"regression\",
  \"wave\": ${WAVE_JSON},
  \"record\": \"${RECORD}\",
  \"runner\": \"ctest\",
  \"config\": { \"name\": \"${CONFIG_NAME}\", \"params\": {}, \"seed\": ${SEED}, \"sim_args\": \"\" },
  \"rtl_digest\": \"${RTL_DIGEST}\",
  \"tb_digest\": \"${TB_DIGEST}\",
  \"started\": \"${STARTED}\",
  \"finished\": \"${FINISHED}\",
  \"tests\": [
${TESTS_JSON}
  ],
  \"summary\": { \"pass\": ${N_PASS}, \"fail\": ${N_FAIL}, \"timeout\": ${N_TIMEOUT} }
}
")

file(WRITE "${OUT}/summary.md" "# Regression ${STARTED}

| Field | Value |
|---|---|
| Record | `${RECORD}` |
| Runner | ctest |
| Wave | ${WAVE_JSON} |
| Config | `${CONFIG_NAME}` |
| Seed | ${SEED} |
| RTL digest | `${RTL_DIGEST}` |
| TB digest | `${TB_DIGEST}` |
| Result | ${N_PASS} pass, ${N_FAIL} fail, ${N_TIMEOUT} timeout |
")

message(STATUS "results: ${OUT_REL}/results.json")
message(STATUS "digest:  RTL ${RTL_DIGEST} TB ${TB_DIGEST}")
message("REGRESS[${RECORD}] pass=${N_PASS} fail=${N_FAIL} timeout=${N_TIMEOUT}")

if(RECORD STREQUAL "red")
    if(N_FAIL GREATER 0 OR N_TIMEOUT GREATER 0)
        message(STATUS "red evidence recorded: at least one selected test does not pass on this RTL")
        return()
    endif()
    message(FATAL_ERROR "--record red, but every selected test passed; the test proves nothing yet")
endif()

if(N_FAIL GREATER 0 OR N_TIMEOUT GREATER 0)
    message(FATAL_ERROR "regression failed")
endif()
