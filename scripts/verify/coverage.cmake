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
#   cmake -P scripts/verify/coverage.cmake --jobs 8
#
# Why these are CTest tests: a coverage run is the same test against another
# snapshot, so timeout, the `UVM_RESULT:` verdict, the log and the JUnit XML are
# the regression's contract, not a second implementation of it. A plain `ctest`
# skips them (exit 77 -> SKIP_RETURN_CODE) because it never built that snapshot;
# the coverage target asks for them with RISCV_COVERAGE=1.
#
# Functional coverage is measured, not code-read: `coverpoints`, the bin counts
# and the uncovered bin names come from parsing xcrg's text report, per
# coverpoint and per bin. A report with zero coverpoints is `missing_bins`, a
# signoff blocker; a report that has a CoverPoint Tables section but yields no
# bin is a fatal parse error, never a silently published 0/0.
#
# --require-bins <cp.bin[,cp.bin]> (repeatable) turns the measurement into a
# gate for a work package: every named bin must be present in the report and
# covered (at least one hit). A bin absent from the report and a bin that exists
# with zero hits are reported separately; both are exit 1, and the transcript
# lands in build/require-bins-red.log, outside the report directory that every
# run recreates, so the evidence of one failure survives the next run.
#
# Every summary.json records the requested list (`required`, empty when no list
# was given) and the outcome of the bar (`require_bins`: none/ok/absent/
# uncovered/mixed), apart from `status`, which reports the measurement only: a
# failed --require-bins leaves `status: measured` and says why in `require_bins`.
#
# The A-09 bar is published apart from the report sum: `bar_covered`/`bar_total`
# count only `cp_inst` (one bin per decoded instruction) and `cp_width` (one per
# memory width). `cp_lane`/`cp_dir`/`cp_subword_lane` are extra evidence that
# predates the bar, so they stay in `bins_covered`/`bins_total` and out of the
# bar. The counts come from the parsed coverpoint rows, never from a hard-coded
# 37/3: a covergroup change moves the bar instead of keeping a stale constant. A
# missing bar coverpoint makes the bar unmeasurable (`bar_total: 0`, status
# `missing_bins`, a reason naming it) instead of a plausible-looking 0.
#
# Bin names are data, not syntax: `\` and `"` are JSON-escaped on the way into
# summary.json, because xcrg prints escaped identifiers verbatim (`\and`) and an
# unusual bin name must not invalidate the report.
#
# Results: build/cov_db/ (per-test databases), build/cov_report/summary.json and
#          the xcrg text report. The instrumented snapshot lives apart from
#          `top_sim`, so a coverage run no longer invalidates the regression's.
#
# Exit codes: 0 measured; 1 not measured (absent report, no coverpoint, or a
# failed --require-bins). CMake script mode has no other failure code, and
# `make` reports any failed recipe as 2 on top of it.
# =============================================================================

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

        # Optional 7th column: the same `sanity:<image>` contract as the
        # regression. Without it the sanity class has no +HEX and dies with a
        # UVM_FATAL in the instrumented snapshot.
        riscv_manifest_extra(TEST_IMAGE "${ROW}")
        set(TEST_LOG "${COV_REPORT}/${TID}.log")
        if(TEST_IMAGE STREQUAL "")
            riscv_xsim_command(TEST_CMD SNAPSHOT top_sim_cov TEST "${TEST_CLASS}"
                LOG "${TEST_LOG}" SEED "${SEED}" SKIP_ENV RISCV_COVERAGE
                COV_DB_DIR "${COV_DB}" COV_DB_NAME "cov_${TID}")
        else()
            set(TEST_HEX "${CMAKE_BINARY_DIR}/sanity_tests/hex/${TEST_IMAGE}.hex")
            set(TEST_TOHOST "${CMAKE_BINARY_DIR}/sanity_tests/tohost/${TEST_IMAGE}")
            riscv_xsim_command(TEST_CMD SNAPSHOT top_sim_cov TEST "${TEST_CLASS}"
                LOG "${TEST_LOG}" SEED "${SEED}" SKIP_ENV RISCV_COVERAGE
                COV_DB_DIR "${COV_DB}" COV_DB_NAME "cov_${TID}"
                HEX "${TEST_HEX}" TOHOST_FILE "${TEST_TOHOST}"
                REQUIRE_SANITY SANITY_IMAGE "${TEST_IMAGE}")
        endif()
        # A private run directory: the coverage database is already absolute
        # (--cov_db_dir ${COV_DB}), only the files xsim writes into the CWD move
        # there, so `ctest -j` cannot cross two tests' logs.
        riscv_test_run_dir(TEST_RUN_DIR "COV-${TID}")
        add_test(NAME COV-${TID} COMMAND bash -c "${TEST_CMD}"
            WORKING_DIRECTORY "${TEST_RUN_DIR}")
        set_tests_properties(COV-${TID} PROPERTIES
            TIMEOUT ${TEST_TIMEOUT}
            SKIP_RETURN_CODE 77
            LABELS "cov;${TID};wp${TEST_WP};class:${TEST_CLASS}")
        list(APPEND COV_TESTS "COV-${TID}")
    endforeach()
    message(STATUS "Coverage tests: ${COV_TESTS}")

    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE}
                --jobs ${DOLLAR}${DOLLAR}{VERIFY_JOBS:-${VERIFY_JOBS}} $(COVERAGE_ARGS)
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
cmake_parse_arguments(R "" "seed;format;jobs" "test;require-bins" ${ARGS})
if(R_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unknown option(s): ${R_UNPARSED_ARGUMENTS}")
endif()

# 1 is the historical behaviour: a direct `cmake -P` is serial. The gate
# targets pass --jobs from VERIFY_JOBS; a later --jobs in COVERAGE_ARGS wins.
riscv_parallel_jobs(JOBS "${R_jobs}")

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

# --require-bins is repeatable and CSV: `--require-bins a --require-bins b` and
# `--require-bins "a,b"` mean the same list. Each entry is `<coverpoint>.<bin>`,
# the same fully-qualified name summary.json publishes.
set(REQUIRE_BINS "")
foreach(ITEM IN LISTS R_require-bins)
    string(REPLACE "," ";" CSV_ENTRIES "${ITEM}")
    foreach(ENTRY IN LISTS CSV_ENTRIES)
        string(STRIP "${ENTRY}" ENTRY)
        if(NOT ENTRY STREQUAL "")
            list(APPEND REQUIRE_BINS "${ENTRY}")
        endif()
    endforeach()
endforeach()
list(REMOVE_DUPLICATES REQUIRE_BINS)

# --- selection: the CTest filters, on the coverage-labelled tests -------------
set(CTEST_SELECT -L "^cov$")
if(R_test)
    list(JOIN R_test "|" PATTERN)
    list(APPEND CTEST_SELECT -R "^COV-(${PATTERN})$")
endif()

# --- chain: ./configure -> elaborate_cov ------------------------------------
file(MAKE_DIRECTORY "${BUILD}/regress")
riscv_bootstrap_build("${BUILD}/regress/configure.log")

# The sanity test needs its image before CTest runs COV-T-08; build it next to
# the instrumented snapshot, exactly like the regression does. Only the images
# of the selected tests are built: `--test T-13` runs COV-T-13 alone, so the
# other images would be built for nobody.
set(BUILD_TARGETS elaborate_cov)
riscv_manifest_sanity_targets(SANITY_TARGETS "${ROOT}/scripts/verify/tests.tsv"
    TESTS ${R_test})
list(APPEND BUILD_TARGETS ${SANITY_TARGETS})
list(REMOVE_DUPLICATES BUILD_TARGETS)

message(STATUS "building ${BUILD_TARGETS} through the build system")
execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${BUILD}" --target ${BUILD_TARGETS}
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
riscv_ctest_run("${COV_REPORT}/junit.xml" "${BUILD}"
    LOG "${COV_REPORT}/ctest.log"
    JOBS "${JOBS}"
    ENV RISCV_COVERAGE=1 "SEED=${SEED}"
    SELECT ${CTEST_SELECT})

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

# Functional coverage is the report, not the collector source. Three regions
# carry the facts:
#   `Instance <inst> Cover Point Details` -> one row per coverpoint: name, table
#       tag, expected/uncovered/covered bins;
#   `Cover Point Table for Inst : <inst>, Variable :, <cp>` -> the `Uncovered
#       bins` and `Covered bins` lists of `<bin> ,<hits> ,<atleast> ,`;
#   `Coverage Score :, <pct>`, already parsed above.
# Bins are published fully qualified as `<coverpoint>.<bin>`: a bare bin name is
# ambiguous as soon as a second covergroup exists.
set(IN_DETAILS FALSE)
set(IN_BINS "")
set(CURRENT_CP "")
set(N_COVERPOINTS 0)
set(BINS_TOTAL 0)
set(BINS_COVERED 0)
set(COVERED_BINS "")
set(UNCOVERED_BINS "")
set(REPORT_BINS "")
set(BAR_COVERPOINTS "cp_inst;cp_width")
set(BAR_SEEN "")
set(BAR_COVERED 0)
set(BAR_TOTAL 0)

file(STRINGS "${REPORT_FILE}" REPORT_LINES)
foreach(LINE IN LISTS REPORT_LINES)
    # Region gates: a row is a coverpoint row only inside the details table, and
    # a bin row only inside an Uncovered/Covered bins list.
    if(LINE MATCHES "Cover Point Details")
        set(IN_DETAILS TRUE)
        set(IN_BINS "")
    elseif(LINE MATCHES "CoverPoint Tables")
        set(IN_DETAILS FALSE)
        set(IN_BINS "")
    endif()

    if(LINE MATCHES "Cover Point Table for Inst")
        string(REGEX REPLACE ".*Variable[ \t]*:,[ \t]*([A-Za-z_][A-Za-z0-9_]*).*"
            "\\1" CURRENT_CP "${LINE}")
        set(IN_BINS "")
    elseif(LINE MATCHES "^[ \t]*Uncovered bins")
        set(IN_BINS "uncovered")
    elseif(LINE MATCHES "^[ \t]*Covered bins")
        set(IN_BINS "covered")
    elseif(LINE MATCHES "^[ \t]*Summary")
        set(IN_BINS "")
    endif()

    # `cp_width ,cg_mem_obj.cg_mem_cp_width,3 ,1 ,2 ,66.6667 ,...`
    if(IN_DETAILS AND LINE MATCHES "^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*,([^,]*),([ \t]*[0-9]+)[ \t]*,([ \t]*[0-9]+)[ \t]*,([ \t]*[0-9]+)[ \t]*,([ \t]*[0-9.]+)")
        set(CP_NAME "${CMAKE_MATCH_1}")
        string(STRIP "${CMAKE_MATCH_3}" CP_EXPECTED)
        string(STRIP "${CMAKE_MATCH_5}" CP_COVERED)
        math(EXPR BINS_TOTAL "${BINS_TOTAL} + ${CP_EXPECTED}")
        math(EXPR BINS_COVERED "${BINS_COVERED} + ${CP_COVERED}")
        math(EXPR N_COVERPOINTS "${N_COVERPOINTS} + 1")
        # The A-09 bar adds up only the coverpoints that define it.
        list(FIND BAR_COVERPOINTS "${CP_NAME}" BAR_CP_INDEX)
        if(NOT BAR_CP_INDEX EQUAL -1)
            list(APPEND BAR_SEEN "${CP_NAME}")
            math(EXPR BAR_COVERED "${BAR_COVERED} + ${CP_COVERED}")
            math(EXPR BAR_TOTAL "${BAR_TOTAL} + ${CP_EXPECTED}")
        endif()
    endif()

    # `      word_w      ,0           ,1           ,`
    # The name is everything up to the first comma: explicit bins are
    # identifiers, auto-bins are not (`[0]`), and dropping one silently would
    # under-report `uncovered`.
    if(IN_BINS AND LINE MATCHES "^[ \t]*([^,]+)[ \t]*,([ \t]*[0-9]+)[ \t]*,([ \t]*[0-9]+)[ \t]*,")
        if(NOT CURRENT_CP STREQUAL "")
            string(STRIP "${CMAKE_MATCH_1}" BIN_NAME)
            set(QBIN "${CURRENT_CP}.${BIN_NAME}")
            list(APPEND REPORT_BINS "${QBIN}")
            if(IN_BINS STREQUAL "uncovered")
                list(APPEND UNCOVERED_BINS "${QBIN}")
            else()
                list(APPEND COVERED_BINS "${QBIN}")
            endif()
        endif()
    endif()
endforeach()
list(LENGTH REPORT_BINS N_REPORT_BINS)

# Failure-loud: a report that has the section but parses to no bin means the
# format moved, not that the design is fully uncovered.
string(FIND "${REPORT_TEXT}" "CoverPoint Tables" COVERPOINT_TABLES)
if(NOT COVERPOINT_TABLES EQUAL -1 AND N_REPORT_BINS EQUAL 0)
    message(FATAL_ERROR "coverage report ${REPORT_FILE} has a CoverPoint Tables section but no bin was parsed; refusing to publish 0/0 (xcrg format changed?)")
endif()

# Not a failure: ignored/illegal bins can legitimately change the count. But a
# partial parse (some bin rows lost) must leave a trace instead of silently
# shortening `uncovered`. bins_parsed records it in summary.json.
if(NOT N_REPORT_BINS EQUAL BINS_TOTAL)
    message(WARNING "coverage report ${REPORT_FILE}: parsed ${N_REPORT_BINS} bin row(s) but the coverpoint tables expect ${BINS_TOTAL}; `uncovered` may be incomplete")
endif()

set(STATUS "measured")
set(REASON "")
if(N_COVERPOINTS EQUAL 0)
    set(STATUS "missing_bins")
    set(REASON "the xcrg report has no coverpoint: functional coverage is not measured (NFR-06)")
endif()

# The A-09 bar is cp_inst + cp_width, derived from the parsed rows. A missing
# coverpoint makes the bar unmeasurable rather than a bar that looks measured.
set(BAR_MISSING "")
foreach(BAR_CP IN LISTS BAR_COVERPOINTS)
    list(FIND BAR_SEEN "${BAR_CP}" BAR_SEEN_INDEX)
    if(BAR_SEEN_INDEX EQUAL -1)
        list(APPEND BAR_MISSING "${BAR_CP}")
    endif()
endforeach()
if(BAR_MISSING)
    set(BAR_COVERED 0)
    set(BAR_TOTAL 0)
    set(STATUS "missing_bins")
    string(REPLACE ";" ", " BAR_MISSING_TEXT "${BAR_MISSING}")
    if(REASON STREQUAL "")
        set(REASON "A-09 bar coverpoint(s) missing from the xcrg report: ${BAR_MISSING_TEXT}; the cp_inst + cp_width bar is unmeasurable (NFR-06)")
    else()
        string(APPEND REASON "; A-09 bar coverpoint(s) missing: ${BAR_MISSING_TEXT}")
    endif()
endif()

# JSON string escaping per bin name. xcrg prints escaped identifiers verbatim,
# so a bin can legitimately contain `\` or `"`; serialising the name is the
# parser's job, not the collector's naming luck, and an unusual name must not
# turn into invalid JSON (and therefore a broken gate).
list(LENGTH UNCOVERED_BINS N_UNCOVERED_BINS)
set(UNCOVERED_ENTRIES "")
foreach(BIN_NAME IN LISTS UNCOVERED_BINS)
    string(REPLACE "\\" "\\\\" BIN_JSON "${BIN_NAME}")
    string(REPLACE "\"" "\\\"" BIN_JSON "${BIN_JSON}")
    list(APPEND UNCOVERED_ENTRIES "\"${BIN_JSON}\"")
endforeach()
if(UNCOVERED_ENTRIES)
    list(JOIN UNCOVERED_ENTRIES ", " UNCOVERED_JSON)
    set(UNCOVERED_JSON "[ ${UNCOVERED_JSON} ]")
else()
    set(UNCOVERED_JSON "[]")
endif()

riscv_tree_digests(RTL_DIGEST TB_DIGEST "${ROOT}")
string(REPLACE ";" "\", \"" DB_JSON "${DB_NAMES}")
string(TIMESTAMP STAMP "%Y-%m-%dT%H:%M:%SZ" UTC)

# --- --require-bins: present AND covered, two distinct failures --------------
# A bin absent from the report is a coverage-model gap (the covergroup never
# declared it); a bin present with zero hits is a stimulus/closure gap.
# Collapsing them would hide which one a work package faces.
set(REQUIRE_ABSENT "")
set(REQUIRE_UNCOVERED "")
foreach(ENTRY IN LISTS REQUIRE_BINS)
    list(FIND REPORT_BINS "${ENTRY}" BIN_INDEX)
    if(BIN_INDEX EQUAL -1)
        list(APPEND REQUIRE_ABSENT "${ENTRY}")
    else()
        list(FIND COVERED_BINS "${ENTRY}" COVERED_INDEX)
        if(COVERED_INDEX EQUAL -1)
            list(APPEND REQUIRE_UNCOVERED "${ENTRY}")
        endif()
    endif()
endforeach()
list(LENGTH REQUIRE_BINS N_REQUIRED)
list(LENGTH REQUIRE_ABSENT N_ABSENT)
list(LENGTH REQUIRE_UNCOVERED N_UNCOVERED)

# The outgoing verdict of the bar, published next to the measurement. `none`
# means the run did not ask for a bin; otherwise it names the worst outcome, so
# a green-looking summary can never hide a failed --require-bins.
if(N_REQUIRED EQUAL 0)
    set(REQUIRE_STATE "none")
elseif(N_ABSENT GREATER 0 AND N_UNCOVERED GREATER 0)
    set(REQUIRE_STATE "mixed")
elseif(N_ABSENT GREATER 0)
    set(REQUIRE_STATE "absent")
elseif(N_UNCOVERED GREATER 0)
    set(REQUIRE_STATE "uncovered")
else()
    set(REQUIRE_STATE "ok")
endif()

# The requested list goes into summary.json as an array (empty when no list was
# given), JSON-escaped like the bin names: the name is data, not syntax.
set(REQUIRED_ENTRIES "")
foreach(ENTRY IN LISTS REQUIRE_BINS)
    string(REPLACE "\\" "\\\\" ENTRY_JSON "${ENTRY}")
    string(REPLACE "\"" "\\\"" ENTRY_JSON "${ENTRY_JSON}")
    list(APPEND REQUIRED_ENTRIES "\"${ENTRY_JSON}\"")
endforeach()
if(REQUIRED_ENTRIES)
    list(JOIN REQUIRED_ENTRIES ", " REQUIRED_JSON)
    set(REQUIRED_JSON "[ ${REQUIRED_JSON} ]")
else()
    set(REQUIRED_JSON "[]")
endif()

set(REQUIRE_FAILURE "")
set(ABSENT_TEXT "")
set(UNCOVERED_TEXT "")
if(N_ABSENT GREATER 0 OR N_UNCOVERED GREATER 0)
    string(REPLACE ";" ", " ABSENT_TEXT "${REQUIRE_ABSENT}")
    string(REPLACE ";" ", " UNCOVERED_TEXT "${REQUIRE_UNCOVERED}")
    if(N_ABSENT GREATER 0)
        string(APPEND REQUIRE_FAILURE "bin(s) absent from the report: ${ABSENT_TEXT}")
    endif()
    if(N_UNCOVERED GREATER 0)
        if(NOT REQUIRE_FAILURE STREQUAL "")
            string(APPEND REQUIRE_FAILURE "; ")
        endif()
        string(APPEND REQUIRE_FAILURE "bin(s) present with zero hits: ${UNCOVERED_TEXT}")
    endif()
    # Written after the parse, so it can never quote a stale measurement. The
    # path is outside build/cov_report/, which every run recreates: a failure
    # leaves build/require-bins-red.log and the next run does not erase it.
    file(WRITE "${BUILD}/require-bins-red.log" "coverage --require-bins: FAIL
report:      ${REPORT_FILE}
coverpoints: ${N_COVERPOINTS}
bins:        ${BINS_COVERED}/${BINS_TOTAL} (percentages ${PERCENTAGES})
required:    ${REQUIRE_BINS}
absent from the report: ${ABSENT_TEXT}
present but uncovered:  ${UNCOVERED_TEXT}
require_bins: ${REQUIRE_STATE}
rtl_digest:  ${RTL_DIGEST}
tb_digest:   ${TB_DIGEST}
")
endif()

file(WRITE "${COV_REPORT}/summary.json" "{
  \"kind\": \"coverage\",
  \"status\": \"${STATUS}\",
  \"reason\": \"${REASON}\",
  \"rtl_digest\": \"${RTL_DIGEST}\",
  \"tb_digest\": \"${TB_DIGEST}\",
  \"required\": ${REQUIRED_JSON},
  \"require_bins\": \"${REQUIRE_STATE}\",
  \"recorded\": \"${STAMP}\",
  \"seed\": ${SEED},
  \"databases\": [ \"${DB_JSON}\" ],
  \"merged\": \"build/cov_merged/merged\",
  \"report\": \"${REPORT_FILE}\",
  \"coverpoints\": ${N_COVERPOINTS},
  \"bins_covered\": ${BINS_COVERED},
  \"bins_total\": ${BINS_TOTAL},
  \"bins_parsed\": ${N_REPORT_BINS},
  \"bar_covered\": ${BAR_COVERED},
  \"bar_total\": ${BAR_TOTAL},
  \"uncovered\": ${UNCOVERED_JSON},
  \"percentages\": \"${PERCENTAGES}\"
}
")

message(STATUS "report:  ${REPORT_FILE}")
message(STATUS "summary: build/cov_report/summary.json")
message("COVERAGE status=${STATUS} coverpoints=${N_COVERPOINTS} bins=${BINS_COVERED}/${BINS_TOTAL} bar=${BAR_COVERED}/${BAR_TOTAL} percentages=${PERCENTAGES}")
if(N_REQUIRED GREATER 0 AND REQUIRE_FAILURE STREQUAL "")
    message(STATUS "require-bins: ${N_REQUIRED} bin(s) present and covered")
endif()

if(NOT STATUS STREQUAL "measured")
    message(FATAL_ERROR "${REASON}")
endif()
if(NOT REQUIRE_FAILURE STREQUAL "")
    message(FATAL_ERROR "--require-bins: ${REQUIRE_FAILURE}; transcript build/require-bins-red.log, report ${REPORT_FILE}")
endif()
