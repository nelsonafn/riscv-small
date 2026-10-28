# =============================================================================
# regress.cmake - run the manifest tests through CTest and record the evidence.
#
#   cmake -P scripts/verify/regress.cmake --list
#   cmake -P scripts/verify/regress.cmake --all
#   cmake -P scripts/verify/regress.cmake --test T-01
#   cmake -P scripts/verify/regress.cmake --wave 0
#   cmake -P scripts/verify/regress.cmake --test T-06 --record red --wave 0
#
# Execution is CTest's job: CMakeLists.txt §12 declares one CTest test per line
# of scripts/verify/tests.tsv (name = T-id, timeout and wave/requirement labels
# from the manifest), and the test command greps the testbench's
# `UVM_RESULT: PASS` line because xsim exits 0 even when the run fails.
#
# What is left here is what CTest cannot do:
#   - a run directory per invocation, with the per-test logs and ctest.log;
#   - rtl_digest/tb_digest, so a result is tied to the code it ran against;
#   - results.json + summary.md, the artefacts the signoff gate reads;
#   - --record red, the test-first evidence (at least one test must fail).
#
# Exit codes: 0 expectation met, 1 expectation not met, 2 usage/build error.
# =============================================================================
cmake_minimum_required(VERSION 3.21)

get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(MANIFEST "${ROOT}/scripts/verify/tests.tsv")

set(DO_LIST FALSE)
set(SELECT "")
set(WAVE "")
set(SEED "1")
set(CONFIG_NAME "default")
set(SIM_ARGS "")
set(RECORD "green")
set(OUT "")
set(NO_ELABORATE FALSE)

math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    set(NEXT "")
    foreach(I RANGE 3 ${LAST_ARG})
        set(ARG "${CMAKE_ARGV${I}}")
        if(NEXT STREQUAL "test")
            list(APPEND SELECT "${ARG}")
            set(NEXT "")
        elseif(NEXT STREQUAL "wave")
            set(WAVE "${ARG}")
            set(NEXT "")
        elseif(NEXT STREQUAL "seed")
            set(SEED "${ARG}")
            set(NEXT "")
        elseif(NEXT STREQUAL "config")
            set(CONFIG_NAME "${ARG}")
            set(NEXT "")
        elseif(NEXT STREQUAL "sim-args")
            set(SIM_ARGS "${ARG}")
            set(NEXT "")
        elseif(NEXT STREQUAL "record")
            set(RECORD "${ARG}")
            set(NEXT "")
        elseif(NEXT STREQUAL "out")
            set(OUT "${ARG}")
            set(NEXT "")
        elseif(ARG STREQUAL "--list")
            set(DO_LIST TRUE)
        elseif(ARG STREQUAL "--all")
            set(SELECT "__ALL__")
        elseif(ARG STREQUAL "--no-elaborate")
            set(NO_ELABORATE TRUE)
        elseif(ARG STREQUAL "--test" OR ARG STREQUAL "--wave" OR ARG STREQUAL "--seed"
               OR ARG STREQUAL "--config" OR ARG STREQUAL "--sim-args"
               OR ARG STREQUAL "--record" OR ARG STREQUAL "--out")
            string(SUBSTRING "${ARG}" 2 -1 NEXT)
        elseif(ARG MATCHES "^-")
            message(FATAL_ERROR "unknown option '${ARG}'")
            return()
        else()
            list(APPEND SELECT "${ARG}")
        endif()
    endforeach()
endif()

if(NOT EXISTS "${MANIFEST}")
    message(FATAL_ERROR "manifest not found: scripts/verify/tests.tsv")
endif()

# --- manifest ----------------------------------------------------------------
file(STRINGS "${MANIFEST}" MANIFEST_LINES)
set(IDS "")
set(CLASSES "")
set(WAVES "")
set(FRSS "")
set(TIMEOUTS "")
foreach(LINE IN LISTS MANIFEST_LINES)
    if(LINE MATCHES "^#" OR LINE STREQUAL "")
        continue()
    endif()
    string(REPLACE "\t" ";" FIELDS "${LINE}")
    list(GET FIELDS 0 F_ID)
    list(GET FIELDS 1 F_CLASS)
    list(GET FIELDS 2 F_WAVE)
    list(GET FIELDS 3 F_FRS)
    list(GET FIELDS 4 F_TMO)
    list(APPEND IDS "${F_ID}")
    list(APPEND CLASSES "${F_CLASS}")
    list(APPEND WAVES "${F_WAVE}")
    list(APPEND FRSS "${F_FRS}")
    list(APPEND TIMEOUTS "${F_TMO}")
endforeach()

function(field_of OUT_VAR LIST_VAR KEY)
    set(VALUES ${${LIST_VAR}})
    list(FIND IDS "${KEY}" IDX)
    if(IDX LESS 0)
        set(${OUT_VAR} "" PARENT_SCOPE)
    else()
        list(GET VALUES ${IDX} VALUE)
        set(${OUT_VAR} "${VALUE}" PARENT_SCOPE)
    endif()
endfunction()

if(DO_LIST)
    message("ID     UVM TEST                                 WAVE REQUIREMENTS     TIMEOUT")
    foreach(ID IN LISTS IDS)
        field_of(CLASS "CLASSES" "${ID}")
        field_of(WV "WAVES" "${ID}")
        field_of(FRS "FRSS" "${ID}")
        field_of(TMO "TIMEOUTS" "${ID}")
        message("${ID}   ${CLASS}   ${WV}   ${FRS}   ${TMO}s")
    endforeach()
    return()
endif()

if(NOT RECORD STREQUAL "green" AND NOT RECORD STREQUAL "red")
    message(FATAL_ERROR "--record must be 'green' or 'red', got '${RECORD}'")
    return()
endif()
if(NOT SEED MATCHES "^[0-9]+$")
    message(FATAL_ERROR "--seed must be an unsigned integer, got '${SEED}'")
    return()
endif()

# --- selection ---------------------------------------------------------------
list(LENGTH IDS N_MANIFEST)
set(RUN_IDS "")
if(SELECT STREQUAL "__ALL__" OR SELECT STREQUAL "")
    set(RUN_IDS "${IDS}")
else()
    foreach(WANT IN LISTS SELECT)
        set(ID "${WANT}")
        if(NOT WANT MATCHES "^T-")
            list(FIND CLASSES "${WANT}" IDX)
            if(IDX LESS 0)
                message(FATAL_ERROR "'${WANT}' is neither a T-id nor a manifest test name")
                return()
            endif()
            list(GET IDS ${IDX} ID)
        endif()
        list(FIND IDS "${ID}" IDX)
        if(IDX LESS 0)
            message(FATAL_ERROR "'${ID}' is not in scripts/verify/tests.tsv")
            return()
        endif()
        list(APPEND RUN_IDS "${ID}")
    endforeach()
endif()

if(NOT WAVE STREQUAL "")
    set(KEPT "")
    foreach(ID IN LISTS RUN_IDS)
        field_of(WV "WAVES" "${ID}")
        if(WV STREQUAL WAVE)
            list(APPEND KEPT "${ID}")
        endif()
    endforeach()
    if(KEPT STREQUAL "")
        message(FATAL_ERROR "no test of wave '${WAVE}' in scripts/verify/tests.tsv")
        return()
    endif()
    set(RUN_IDS "${KEPT}")
endif()

list(LENGTH RUN_IDS N_RUN)
if(N_RUN EQUAL 0)
    message(FATAL_ERROR "no test selected")
    return()
endif()

foreach(ID IN LISTS RUN_IDS)
    field_of(CLASS "CLASSES" "${ID}")
    if(NOT EXISTS "${ROOT}/tb/tests/${CLASS}.sv")
        message(FATAL_ERROR "${ID} names '${CLASS}', but tb/tests/${CLASS}.sv does not exist")
        return()
    endif()
endforeach()

# --- preconditions -----------------------------------------------------------
if(NO_ELABORATE)
    if(NOT EXISTS "${BUILD}/xsim.dir/top_sim")
        message(FATAL_ERROR "--no-elaborate needs build/xsim.dir/top_sim; run 'make elaborate' first")
        return()
    endif()
else()
    if(NOT EXISTS "${BUILD}/Makefile")
        message(FATAL_ERROR "build/ is not configured; run ./configure first")
        return()
    endif()
endif()
if(NOT EXISTS "${BUILD}/CTestTestfile.cmake")
    message(FATAL_ERROR "no CTest tests in build/; re-run ./configure after changing tests.tsv")
    return()
endif()

if(OUT STREQUAL "")
    string(TIMESTAMP STAMP "%Y-%m-%dT%H-%M-%SZ" UTC)
    set(OUT "${BUILD}/regress/${STAMP}")
endif()
file(MAKE_DIRECTORY "${OUT}")

# --- digests -----------------------------------------------------------------
function(tree_digest OUT_VAR DIR)
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

tree_digest(RTL_DIGEST "${ROOT}/rtl")
tree_digest(TB_DIGEST "${ROOT}/tb")
string(TIMESTAMP STARTED "%Y-%m-%dT%H:%M:%SZ" UTC)

# --- elaborate once (skipped under `make regress`) ---------------------------
if(NO_ELABORATE)
    message(STATUS "using the existing snapshot (elaboration owned by the build system)")
else()
    message(STATUS "elaborating")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" --build "${BUILD}" --target elaborate
        RESULT_VARIABLE RC
        OUTPUT_FILE "${OUT}/elaborate.log" ERROR_FILE "${OUT}/elaborate.log")
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "elaboration failed; see ${OUT}/elaborate.log")
    endif()
endif()

# --- run: one ctest invocation -----------------------------------------------
set(CTEST_ARGS "")
set(ALL_SELECTED FALSE)
if(SELECT STREQUAL "__ALL__" OR SELECT STREQUAL "")
    set(ALL_SELECTED TRUE)
endif()
if(ALL_SELECTED AND WAVE STREQUAL "")
    # every manifest test
else()
    string(REPLACE ";" "|" PATTERN_IDS "${RUN_IDS}")
    list(APPEND CTEST_ARGS -R "^(${PATTERN_IDS})$")
endif()
if(NOT SIM_ARGS STREQUAL "")
    separate_arguments(SIM_ARGS_LIST UNIX_COMMAND "${SIM_ARGS}")
    list(APPEND CTEST_ARGS ${SIM_ARGS_LIST})
endif()

if(NOT CMAKE_CTEST_COMMAND)
    set(CMAKE_CTEST_COMMAND ctest)
endif()

set(CTEST_LOG "${OUT}/ctest.log")
message(STATUS "running ${N_RUN} test(s) through ctest")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env "SEED=${SEED}"
            "${CMAKE_CTEST_COMMAND}" --output-on-failure ${CTEST_ARGS}
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE CTEST_RC
    OUTPUT_FILE "${CTEST_LOG}"
    ERROR_FILE "${CTEST_LOG}")

file(READ "${CTEST_LOG}" CTEST_TEXT)
string(REPLACE "\n" ";" CTEST_LINES "${CTEST_TEXT}")
set(RESULT_LINES "")
foreach(LINE IN LISTS CTEST_LINES)
    if(LINE MATCHES "Test +#[0-9]+: ")
        list(APPEND RESULT_LINES "${LINE}")
    endif()
endforeach()

set(N_PASS 0)
set(N_FAIL 0)
set(N_TIMEOUT 0)
set(TEST_ROWS "")

foreach(ID IN LISTS RUN_IDS)
    set(STATUS "fail")
    foreach(LINE IN LISTS RESULT_LINES)
        if(LINE MATCHES "Test +#[0-9]+: ${ID}")
            if(LINE MATCHES "\\*\\*\\*Timeout")
                set(STATUS "timeout")
            elseif(LINE MATCHES "\\*\\*\\*Failed")
                set(STATUS "fail")
            elseif(LINE MATCHES "Passed")
                set(STATUS "pass")
            endif()
        endif()
    endforeach()

    if(STATUS STREQUAL "pass")
        math(EXPR N_PASS "${N_PASS} + 1")
    elseif(STATUS STREQUAL "timeout")
        math(EXPR N_TIMEOUT "${N_TIMEOUT} + 1")
    else()
        math(EXPR N_FAIL "${N_FAIL} + 1")
    endif()

    # The CTest command writes its own log; keep it with the run.
    set(SRC_LOG "${BUILD}/regress/${ID}.log")
    if(EXISTS "${SRC_LOG}")
        file(COPY "${SRC_LOG}" DESTINATION "${OUT}")
        set(LOG_REF "build/regress/${STAMP}/${ID}.log")
        file(READ "${SRC_LOG}" LOG_TEXT)
    else()
        set(LOG_REF "build/regress/${STAMP}/ctest.log")
        set(LOG_TEXT "")
    endif()

    set(UVM_ERRORS 0)
    set(UVM_FATALS 0)
    set(SB_PASS 0)
    set(SB_FAIL 0)
    if(LOG_TEXT MATCHES "UVM_ERROR *: *([0-9]+)")
        set(UVM_ERRORS "${CMAKE_MATCH_1}")
    endif()
    if(LOG_TEXT MATCHES "UVM_FATAL *: *([0-9]+)")
        set(UVM_FATALS "${CMAKE_MATCH_1}")
    endif()
    if(LOG_TEXT MATCHES "PASS *: *([0-9]+)")
        set(SB_PASS "${CMAKE_MATCH_1}")
    endif()
    if(LOG_TEXT MATCHES "FAIL *: *([0-9]+)")
        set(SB_FAIL "${CMAKE_MATCH_1}")
    endif()

    if(RECORD STREQUAL "red")
        set(EXPECT "fail")
    else()
        set(EXPECT "pass")
    endif()

    field_of(CLASS "CLASSES" "${ID}")
    list(APPEND TEST_ROWS "    { \"id\": \"${ID}\", \"test\": \"${CLASS}\", \"status\": \"${STATUS}\", \"expect\": \"${EXPECT}\", \"uvm_errors\": ${UVM_ERRORS}, \"uvm_fatals\": ${UVM_FATALS}, \"sb_pass\": ${SB_PASS}, \"sb_fail\": ${SB_FAIL}, \"log\": \"${LOG_REF}\" }")
    message(STATUS "  ${ID} ${STATUS}")
endforeach()

string(TIMESTAMP FINISHED "%Y-%m-%dT%H:%M:%SZ" UTC)
string(REPLACE ";" ",\n" TESTS_JSON "${TEST_ROWS}")

if(WAVE STREQUAL "")
    set(WAVE_JSON "null")
else()
    set(WAVE_JSON "${WAVE}")
endif()

file(WRITE "${OUT}/results.json" "{
  \"kind\": \"regression\",
  \"wave\": ${WAVE_JSON},
  \"record\": \"${RECORD}\",
  \"runner\": \"ctest\",
  \"config\": { \"name\": \"${CONFIG_NAME}\", \"params\": {}, \"seed\": ${SEED}, \"sim_args\": \"${SIM_ARGS}\" },
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
| Record | \`${RECORD}\` |
| Runner | ctest |
| Wave | ${WAVE_JSON} |
| Config | \`${CONFIG_NAME}\` |
| Seed | ${SEED} |
| RTL digest | \`${RTL_DIGEST}\` |
| TB digest | \`${TB_DIGEST}\` |
| Result | ${N_PASS} pass, ${N_FAIL} fail, ${N_TIMEOUT} timeout |
")

message(STATUS "results: build/regress/${STAMP}/results.json")
message(STATUS "digest:  RTL ${RTL_DIGEST} TB ${TB_DIGEST}")
message("REGRESS[${RECORD}] pass=${N_PASS} fail=${N_FAIL} timeout=${N_TIMEOUT}")

if(RECORD STREQUAL "red")
    if(N_FAIL GREATER 0 OR N_TIMEOUT GREATER 0)
        message(STATUS "red evidence recorded: at least one selected test does not pass on this RTL")
        return()
    endif()
    message(FATAL_ERROR "--record red, but every selected test passed; the test proves nothing yet")
    return()
endif()

if(N_FAIL GREATER 0 OR N_TIMEOUT GREATER 0)
    message(FATAL_ERROR "regression failed")
endif()
