# =============================================================================
# negative_control.cmake - prove that a test fails on the defect it covers.
#
#   cmake -P scripts/verify/negative_control.cmake                every mutant
#   cmake -P scripts/verify/negative_control.cmake --test T-06    one test
#   cmake -P scripts/verify/negative_control.cmake --list
#
# A "red" run recorded in the past cannot be trusted: it lives in build/, so
# `rm -rf build` erases it, and it cannot be regenerated once the RTL is fixed.
# Instead, every test that claims to cover a defect carries its mutant in
# scripts/verify/mutants/<name>.cmake: the one-line source change that
# reintroduces the defect. This runner copies the tree into
# build/mutants/<T-id>/, applies the mutant there, runs the test and requires a
# UVM failure. The repository is never edited and nothing depends on history.
#
# Results: build/red/<T-id>/results.json, read by signoff_check check 11.
# Exit codes: 0 every mutant was detected, 1 a mutant passed (the test has no
#             teeth) or the run failed for another reason, 2 environment error.
# =============================================================================
cmake_minimum_required(VERSION 3.21)

include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(MANIFEST "${ROOT}/scripts/verify/tests.tsv")
set(MUTANT_DIR "${ROOT}/scripts/verify/mutants")
set(OUT "${BUILD}/red")

# --- arguments ---------------------------------------------------------------
set(REQUESTED "")
set(DO_LIST FALSE)
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        set(ARG "${CMAKE_ARGV${I}}")
        if(ARG STREQUAL "--list")
            set(DO_LIST TRUE)
        elseif(ARG STREQUAL "--test")
            math(EXPR I "${I} + 1")
            list(APPEND REQUESTED "${CMAKE_ARGV${I}}")
        elseif(ARG MATCHES "^-")
            message(FATAL_ERROR "unknown option '${ARG}'")
        else()
            list(APPEND REQUESTED "${ARG}")
        endif()
    endforeach()
endif()

# --- selection: every manifest row whose red column names a mutant -----------
riscv_manifest_rows(ROWS "${MANIFEST}")
set(SELECTED "")
foreach(ROW IN LISTS ROWS)
    string(REPLACE "|" ";" FIELDS "${ROW}")
    list(LENGTH FIELDS NF)
    if(NF LESS 6)
        continue()
    endif()
    list(GET FIELDS 0 TID)
    list(GET FIELDS 5 RED)
    if(NOT RED MATCHES "^mutant:(.+)$")
        continue()
    endif()
    set(NAME "${CMAKE_MATCH_1}")
    if(REQUESTED AND NOT TID IN_LIST REQUESTED)
        continue()
    endif()
    list(APPEND SELECTED "${TID}|${NAME}")
endforeach()

if(DO_LIST)
    foreach(ENTRY IN LISTS SELECTED)
        string(REPLACE "|" ";" CELL "${ENTRY}")
        list(GET CELL 0 TID)
        list(GET CELL 1 NAME)
        message("${TID}  mutant=${NAME}")
    endforeach()
    return()
endif()

if(NOT SELECTED)
    message(STATUS "negative control: no mutant selected (nothing to prove)")
    return()
endif()

find_program(XSIM_BIN xsim)
if(NOT XSIM_BIN)
    message(FATAL_ERROR "xsim not on PATH: source the EDA environment first (scripts/setup.sh)")
endif()

file(MAKE_DIRECTORY "${OUT}")

# --- run each mutant on a disposable copy of the tree ------------------------
set(N_DETECTED 0)
foreach(ENTRY IN LISTS SELECTED)
    string(REPLACE "|" ";" CELL "${ENTRY}")
    list(GET CELL 0 TID)
    list(GET CELL 1 NAME)

    set(MUTANT "${MUTANT_DIR}/${NAME}.cmake")
    if(NOT EXISTS "${MUTANT}")
        message(FATAL_ERROR "${TID} names mutant '${NAME}', but ${MUTANT} does not exist")
    endif()

    set(SCRATCH "${BUILD}/mutants/${TID}")
    file(REMOVE_RECURSE "${SCRATCH}")
    file(MAKE_DIRECTORY "${SCRATCH}")

    # Copy only what the build needs. `src` is a symlink: the sanity module only
    # globs it at configure time. A real copy (not hard links) matters: the
    # mutant writes the file, and a hard link would edit the repository.
    file(COPY "${ROOT}/rtl" "${ROOT}/tb" "${ROOT}/srclist" "${ROOT}/scripts"
              "${ROOT}/CMakeLists.txt" "${ROOT}/configure" DESTINATION "${SCRATCH}")
    file(CREATE_LINK "${ROOT}/src" "${SCRATCH}/src" SYMBOLIC)

    execute_process(
        COMMAND ${CMAKE_COMMAND} "-DSCRATCH=${SCRATCH}" -P "${MUTANT}"
        RESULT_VARIABLE RC OUTPUT_FILE "${SCRATCH}/mutant.log" ERROR_FILE "${SCRATCH}/mutant.log")
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "${TID}: mutant '${NAME}' could not be applied; see build/mutants/${TID}/mutant.log")
    endif()

    message(STATUS "negative control: running ${TID} against mutant '${NAME}'")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P "${SCRATCH}/scripts/verify/regress.cmake"
                --test "${TID}" --record red --out "${SCRATCH}/build/red"
        WORKING_DIRECTORY "${SCRATCH}"
        RESULT_VARIABLE RC
        TIMEOUT 1800
        OUTPUT_FILE "${SCRATCH}/negative.log"
        ERROR_FILE "${SCRATCH}/negative.log")

    set(RESULT "${SCRATCH}/build/red/results.json")
    if(NOT EXISTS "${RESULT}")
        message(FATAL_ERROR "${TID}: the mutant run produced no results.json (build failure?); see build/mutants/${TID}/negative.log")
    endif()

    file(READ "${RESULT}" JSON)
    if(NOT JSON MATCHES "\"record\": \"red\"")
        message(FATAL_ERROR "${TID}: the mutant run was not recorded as red")
    endif()
    if(NOT JSON MATCHES "\"id\": \"${TID}\", \"test\": \"[^\"]*\", \"status\": \"(fail|timeout)\"")
        message(FATAL_ERROR "${TID} PASSED on mutant '${NAME}': the test does not catch this defect (see build/mutants/${TID})")
    endif()
    if(NOT JSON MATCHES "\"uvm_errors\": [1-9]")
        message(FATAL_ERROR "${TID} failed on mutant '${NAME}' without a UVM error; a build or tool failure is not a verdict")
    endif()

    file(MAKE_DIRECTORY "${OUT}/${TID}")
    file(COPY "${RESULT}" DESTINATION "${OUT}/${TID}")
    if(EXISTS "${SCRATCH}/build/regress/${TID}.log")
        file(COPY "${SCRATCH}/build/regress/${TID}.log" DESTINATION "${OUT}/${TID}")
    endif()

    math(EXPR N_DETECTED "${N_DETECTED} + 1")
    message(STATUS "NEGATIVE ${TID} detected on mutant '${NAME}'")
    file(REMOVE_RECURSE "${SCRATCH}")
endforeach()

list(LENGTH SELECTED N_SELECTED)
message("NEGATIVE CONTROL pass=${N_DETECTED} fail=0 (every selected test fails on its mutant)")
