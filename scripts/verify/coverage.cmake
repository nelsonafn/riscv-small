# =============================================================================
# coverage.cmake - elaborate and simulate with coverage, merge with xcrg (NFR-06).
#
#   cmake -P scripts/verify/coverage.cmake
#   cmake -P scripts/verify/coverage.cmake --test T-01 --seed 42
#
# The build system is reused, not reimplemented:
#   - elaboration runs the `elaborate` target with ELAB_ARGS carrying the
#     coverage flags, because an instrumented snapshot is a different build of
#     the same sources;
#   - the test list comes from scripts/verify/tests.tsv, the same file that
#     declares the CTest tests.
#
# Functional coverage is code-read: the collector must contain at least one
# coverpoint. An empty covergroup makes it `missing_bins`, which is a signoff
# blocker, not a pass.
#
# Results: build/cov_db/ (databases), build/cov_report/summary.json and the
#          xcrg text report.
#
# Exit codes: 0 measured, 1 measured but no coverpoint, 2 not measurable.
# =============================================================================
cmake_minimum_required(VERSION 3.21)

get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(MANIFEST "${ROOT}/scripts/verify/tests.tsv")
set(COV_DB_DIR "${BUILD}/cov_db")
set(COV_MERGED "${BUILD}/cov_merged")
set(COV_REPORT "${BUILD}/cov_report")
set(SEED "1")
set(FORMAT "text")
set(REQUESTED "")

math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        set(ARG "${CMAKE_ARGV${I}}")
        if(ARG STREQUAL "--seed")
            math(EXPR I "${I} + 1")
            set(SEED "${CMAKE_ARGV${I}}")
        elseif(ARG STREQUAL "--format")
            math(EXPR I "${I} + 1")
            set(FORMAT "${CMAKE_ARGV${I}}")
        elseif(ARG STREQUAL "--test")
            math(EXPR I "${I} + 1")
            list(APPEND REQUESTED "${CMAKE_ARGV${I}}")
        elseif(ARG MATCHES "^-")
            message(FATAL_ERROR "unknown option '${ARG}'")
            return()
        else()
            list(APPEND REQUESTED "${ARG}")
        endif()
    endforeach()
endif()

if(NOT EXISTS "${BUILD}/Makefile")
    message(FATAL_ERROR "build/ is not configured; run ./configure first")
endif()

# --- manifest ----------------------------------------------------------------
file(STRINGS "${MANIFEST}" MANIFEST_LINES)
set(TEST_IDS "")
set(TEST_CLASSES "")
foreach(LINE IN LISTS MANIFEST_LINES)
    if(LINE MATCHES "^#" OR LINE STREQUAL "")
        continue()
    endif()
    string(REPLACE "\t" ";" FIELDS "${LINE}")
    list(GET FIELDS 0 TID)
    list(GET FIELDS 1 TCLASS)
    list(APPEND TEST_IDS "${TID}")
    list(APPEND TEST_CLASSES "${TCLASS}")
endforeach()

set(RUN_IDS "")
if(REQUESTED)
    foreach(WANT IN LISTS REQUESTED)
        set(FOUND FALSE)
        foreach(TID IN LISTS TEST_IDS)
            if(WANT STREQUAL TID)
                list(APPEND RUN_IDS "${TID}")
                set(FOUND TRUE)
            endif()
        endforeach()
        if(NOT FOUND)
            message(FATAL_ERROR "'${WANT}' is not a T-id in scripts/verify/tests.tsv")
            return()
        endif()
    endforeach()
else()
    set(RUN_IDS "${TEST_IDS}")
endif()

string(REPLACE ";" "|" JOINED_IDS "${RUN_IDS}")

# --- functional coverage is code-read ----------------------------------------
file(READ "${ROOT}/tb/env/top/riscv_small_coverage.sv" COV_SOURCE)
string(REGEX MATCHALL "coverpoint" COV_POINTS "${COV_SOURCE}")
list(LENGTH COV_POINTS N_COVERPOINTS)

file(MAKE_DIRECTORY "${COV_DB_DIR}" "${COV_REPORT}")

# --- elaborate with coverage (reuses the elaborate target) -------------------
set(ELAB_FLAGS "--cc_type sbct --cc_libs --cov_db_dir ${COV_DB_DIR} --cov_db_name cov_elab_seed${SEED}")
message(STATUS "elaborating with coverage")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env "ELAB_ARGS=${ELAB_FLAGS}"
            "${CMAKE_COMMAND}" --build "${BUILD}" --target elaborate
    RESULT_VARIABLE RC
    OUTPUT_FILE "${BUILD}/coverage_elaborate.log"
    ERROR_FILE "${BUILD}/coverage_elaborate.log")
if(NOT RC EQUAL 0)
    message(FATAL_ERROR "coverage elaboration failed; see build/coverage_elaborate.log")
endif()

# --- simulate ----------------------------------------------------------------
set(DB_NAMES "")
foreach(TID IN LISTS RUN_IDS)
    list(FIND TEST_IDS "${TID}" IDX)
    list(GET TEST_CLASSES ${IDX} TCLASS)
    set(DB "cov_${TID}_seed${SEED}")
    list(APPEND DB_NAMES "${DB}")
    set(LOG "${COV_REPORT}/${TID}.log")
    message(STATUS "running ${TID} with coverage db '${DB}'")
    execute_process(
        COMMAND xsim top_sim --R
                --testplusarg "UVM_TESTNAME=${TCLASS}"
                --testplusarg NO_COLOR
                --sv_seed "${SEED}"
                --cov_db_dir "${COV_DB_DIR}" --cov_db_name "${DB}"
        WORKING_DIRECTORY "${BUILD}"
        TIMEOUT 600
        RESULT_VARIABLE RC
        OUTPUT_FILE "${LOG}" ERROR_FILE "${LOG}")
    file(READ "${LOG}" LOG_TEXT)
    if(LOG_TEXT MATCHES "UVM_RESULT: FAIL")
        message(FATAL_ERROR "${TID} failed under coverage; see build/cov_report/${TID}.log")
    endif()
endforeach()

# --- merge -------------------------------------------------------------------
set(MERGE_ARGS "")
foreach(DB IN LISTS DB_NAMES)
    list(APPEND MERGE_ARGS -cov_db_dir "${COV_DB_DIR}" -cov_db_name "${DB}")
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

set(STATUS "measured")
set(REASON "")
if(N_COVERPOINTS EQUAL 0)
    set(STATUS "missing_bins")
    set(REASON "tb/env/top/riscv_small_coverage.sv has no coverpoint: functional coverage is not measured (NFR-06)")
endif()

function(cov_tree_digest OUT_VAR DIR)
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

cov_tree_digest(RTL_DIGEST "${ROOT}/rtl")
cov_tree_digest(TB_DIGEST "${ROOT}/tb")
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

# The instrumented snapshot must not leak into a plain regression: drop it so the
# next `make elaborate` rebuilds without coverage flags.
file(REMOVE_RECURSE "${BUILD}/xsim.dir/top_sim")
file(REMOVE "${BUILD}/xsim.dir/.elaborated")

message(STATUS "report:  ${REPORT_FILE}")
message(STATUS "summary: build/cov_report/summary.json")
message("COVERAGE status=${STATUS} coverpoints=${N_COVERPOINTS} percentages=${PERCENTAGES}")

if(NOT STATUS STREQUAL "measured")
    message(FATAL_ERROR "${REASON}")
endif()
