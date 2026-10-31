# =============================================================================
# signoff_check.cmake - the release gate (A-09 / Q-11) as an exit code.
#
#   cmake -P scripts/verify/signoff_check.cmake                release (1-11)
#   cmake -P scripts/verify/signoff_check.cmake --wp 0        work-package gate
#   cmake -P scripts/verify/signoff_check.cmake --no-docs
#
# Checks
#   1  docs-check + docs-figs-check
#   2  spec.md x verification.md: same FR set, same status
#   3  every `verified` FR names a T-id in the manifest and in tb/tests/
#   4  no open question, no expired assumption
#   5  latest regression: 0 fail, 0 timeout, digest matches, age <= 7 days
#   6  sanity images (NFR-05)                        release only
#   7  coverage merge + bins, at the current digest   both modes
#   8  doc/measurements/NFR-01..04 present and dated  release only
#   9  NFR-07 lint evidence                           release only
#  10  A-09: every FR `verified`                      release only
#  11  every work-package test has a red run at an older digest
#
# Never edits anything. Writes build/signoff/report.md.
#
# Two modes, like the other gates: included by CMakeLists.txt it declares the
# `signoff-check` target with the evidence it audits as dependencies; with
# `cmake -P` it only audits, so a clean tree answers "blocked" without building
# anything (and without needing the EDA environment).
#
# Exit codes: 0 signoff-ready, 1 blocked, 2 the gate itself could not run.
# =============================================================================

# Including this file must not raise the caller's policy floor (CMakeLists.txt
# targets 3.10); script mode is where the newer policies apply.
if(CMAKE_SCRIPT_MODE_FILE)
    cmake_minimum_required(VERSION 3.21)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# =============================================================================
# Configure mode: the gate, and the evidence it audits as dependencies.
# =============================================================================
if(NOT CMAKE_SCRIPT_MODE_FILE)
    # The negative control proves that each test fails on the defect it covers,
    # by rebuilding a disposable copy of the tree with that defect. It is part
    # of the chain on purpose: `rm -rf build` must not be able to erase the
    # evidence, and a fresh machine must be able to produce it.
    add_custom_target(negative-control
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/negative_control.cmake
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Proving every work-package test fails on its mutant..."
        USES_TERMINAL
    )
    add_custom_target(signoff-check
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE} $(SIGNOFF_ARGS)
        DEPENDS regress coverage sanity-evidence negative-control
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running the signoff gate (A-09)..."
        USES_TERMINAL
    )
    return()
endif()

get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(OUT "${BUILD}/signoff")
set(SPEC "${ROOT}/doc/spec.md")
set(VERIF "${ROOT}/doc/verification.md")
set(QUESTIONS "${ROOT}/doc/spec-questions.md")
set(MANIFEST "${ROOT}/scripts/verify/tests.tsv")
set(MAX_AGE_DAYS 7)

# The same argument style as regress/coverage: options without their `--`.
set(ARGS "")
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        if("${CMAKE_ARGV${I}}" MATCHES "^--")
            # Option tokens only: `no-docs` -> `no_docs`, so the variable the
            # parser creates is addressable without a hyphen. Values are left
            # alone (a work-package number, a T-id).
            string(REGEX REPLACE "^--" "" ARG "${CMAKE_ARGV${I}}")
            string(REPLACE "-" "_" ARG "${ARG}")
        else()
            set(ARG "${CMAKE_ARGV${I}}")
        endif()
        list(APPEND ARGS "${ARG}")
    endforeach()
endif()
cmake_parse_arguments(R "release;no_docs" "wp" "" ${ARGS})
if(R_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unknown option(s): ${R_UNPARSED_ARGUMENTS}")
    return()
endif()

# --release is the default (no work package); it stays accepted for symmetry with
# `--wp <n>`, which CMakeLists.txt passes through SIGNOFF_ARGS.
set(WP "${R_wp}")
set(DO_DOCS TRUE)
if(R_no_docs)
    set(DO_DOCS FALSE)
endif()

foreach(F IN ITEMS "${SPEC}" "${VERIF}" "${QUESTIONS}" "${MANIFEST}")
    if(NOT EXISTS "${F}")
        message(FATAL_ERROR "missing document: ${F}")
        return()
    endif()
endforeach()

if(WP STREQUAL "")
    set(RELEASE TRUE)
    set(MODE "release")
else()
    set(RELEASE FALSE)
    set(MODE "work package ${WP}")
endif()

file(MAKE_DIRECTORY "${OUT}")

# --- helpers -----------------------------------------------------------------
# Rows of a Markdown table whose first cell starts with <prefix>: "ID;status".
function(table_rows OUT_VAR FILE PREFIX)
    riscv_read_lines(LINES "${FILE}")
    set(ACC "")
    foreach(LINE IN LISTS LINES)
        if(LINE MATCHES "^\\| ${PREFIX}")
            string(REPLACE "|" ";" CELLS "${LINE}")
            list(GET CELLS 1 ID)
            string(STRIP "${ID}" ID)
            if(ID MATCHES "(${PREFIX}[0-9]+)")
                set(ID "${CMAKE_MATCH_1}")
            endif()
            list(LENGTH CELLS N)
            math(EXPR LAST "${N} - 2")
            list(GET CELLS ${LAST} STATUS)
            string(STRIP "${STATUS}" STATUS)
            string(REPLACE "@SEMI@" "," STATUS "${STATUS}")
            list(APPEND ACC "${ID}::${STATUS}")
        endif()
    endforeach()
    set(${OUT_VAR} "${ACC}" PARENT_SCOPE)
endfunction()

# Normalise "verified (T-06)" -> verified, etc.
function(norm_status IN OUT_VAR)
    set(S "${IN}")
    if(S MATCHES "^verified")
        set(S "verified")
    elseif(S MATCHES "^implemented")
        set(S "implemented")
    elseif(S MATCHES "^partial")
        set(S "partial")
    elseif(S MATCHES "^deferred")
        set(S "deferred")
    endif()
    set(${OUT_VAR} "${S}" PARENT_SCOPE)
endfunction()


function(json_field OUT_VAR FILE KEY)
    if(NOT EXISTS "${FILE}")
        set(${OUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    file(READ "${FILE}" TEXT)
    if(TEXT MATCHES "\"${KEY}\"[ ]*:[ ]*([^,}]+)")
        set(RAW "${CMAKE_MATCH_1}")
        string(STRIP "${RAW}" RAW)
        string(REGEX REPLACE "^\"|\"$" "" RAW "${RAW}")
        string(STRIP "${RAW}" RAW)
        set(${OUT_VAR} "${RAW}" PARENT_SCOPE)
    else()
        set(${OUT_VAR} "" PARENT_SCOPE)
    endif()
endfunction()

# One report row per check. The detail is free text, so sanitise the two
# characters that would break a CMake list (";") or the report table ("\n").
set(ROWS "")
function(add_row ENTRY)
    string(REPLACE "@SEMI@" ";" ENTRY "${ENTRY}")
    string(REPLACE ";" "," ENTRY "${ENTRY}")
    string(REPLACE "\n" " " ENTRY "${ENTRY}")
    if(ROWS STREQUAL "")
        set(ROWS "${ENTRY}" PARENT_SCOPE)
    else()
        set(ROWS "${ROWS};${ENTRY}" PARENT_SCOPE)
    endif()
endfunction()

# Split a stored row back into its four fields, once, for both consumers: the
# report table and the console/next-actions loop. `^0+` turns "06" into "6" and
# leaves "10" alone.
function(row_fields ENTRY)
    string(REPLACE "::" ";" CELL "${ENTRY}")
    list(GET CELL 0 NUM)
    string(REGEX REPLACE "^0+" "" NUM "${NUM}")
    set(ROW_NUM "${NUM}" PARENT_SCOPE)
    list(GET CELL 1 NAME)
    set(ROW_NAME "${NAME}" PARENT_SCOPE)
    list(GET CELL 2 SEV)
    set(ROW_SEV "${SEV}" PARENT_SCOPE)
    list(GET CELL 3 DETAIL)
    set(ROW_DETAIL "${DETAIL}" PARENT_SCOPE)
endfunction()

# --- 1. documentation gates --------------------------------------------------
if(DO_DOCS)
    execute_process(COMMAND "${ROOT}/scripts/docs/check_md.sh"
        RESULT_VARIABLE RC OUTPUT_FILE "${OUT}/docs-check.log" ERROR_FILE "${OUT}/docs-check.log")
    if(RC EQUAL 0)
        add_row("01::docs-check (scripts/docs/check_md.sh)::ok::0 errors")
    else()
        file(READ "${OUT}/docs-check.log" LOG)
        string(REGEX MATCH "ERROR: [^\n]*" FIRST "${LOG}")
        add_row("01::docs-check (scripts/docs/check_md.sh)::blocked::${FIRST}")
    endif()

    execute_process(COMMAND "${ROOT}/scripts/docs/figs.sh" --check
        RESULT_VARIABLE RC OUTPUT_FILE "${OUT}/docs-figs-check.log" ERROR_FILE "${OUT}/docs-figs-check.log")
    if(RC EQUAL 0)
        add_row("01::docs-figs-check (scripts/docs/figs.sh --check)::ok::figures up to date")
    else()
        file(READ "${OUT}/docs-figs-check.log" LOG)
        string(REGEX MATCH "[^\n]*out of date[^\n]*" LAST "${LOG}")
        add_row("01::docs-figs-check (scripts/docs/figs.sh --check)::blocked::${LAST}")
    endif()
else()
    add_row("01::docs checks::skipped::--no-docs")
endif()

# --- 2. spec x verification mirror ------------------------------------------
table_rows(SPEC_ROWS "${SPEC}" "FR-")
table_rows(VERIF_ROWS "${VERIF}" "FR-")

set(SPEC_IDS "")
set(SPEC_STATUS "")
foreach(ROW IN LISTS SPEC_ROWS)
    string(REPLACE "::" ";" CELL "${ROW}")
    list(GET CELL 0 ID)
    list(GET CELL 1 RAW)
    norm_status("${RAW}" NORM)
    list(APPEND SPEC_IDS "${ID}")
    list(APPEND SPEC_STATUS "${NORM}")
endforeach()
set(VERIF_IDS "")
set(VERIF_STATUS "")
foreach(ROW IN LISTS VERIF_ROWS)
    string(REPLACE "::" ";" CELL "${ROW}")
    list(GET CELL 0 ID)
    list(GET CELL 1 RAW)
    norm_status("${RAW}" NORM)
    list(APPEND VERIF_IDS "${ID}")
    list(APPEND VERIF_STATUS "${NORM}")
endforeach()

list(LENGTH SPEC_IDS N_SPEC)
set(MISMATCH "")
foreach(ID IN LISTS SPEC_IDS)
    list(FIND VERIF_IDS "${ID}" IDX)
    if(IDX LESS 0)
        list(APPEND MISMATCH "${ID}(missing)")
    else()
        list(GET SPEC_STATUS ${IDX} S1)
        list(FIND SPEC_IDS "${ID}" SIDX)
        list(GET SPEC_STATUS ${SIDX} S0)
        if(NOT S0 STREQUAL S1)
            list(APPEND MISMATCH "${ID}(spec=${S0},verif=${S1})")
        endif()
    endif()
endforeach()
foreach(ID IN LISTS VERIF_IDS)
    list(FIND SPEC_IDS "${ID}" IDX)
    if(IDX LESS 0)
        list(APPEND MISMATCH "${ID}(extra)")
    endif()
endforeach()

# A parser that quietly reads the wrong cell is worse than no check: every FR
# row must land in the documented status vocabulary (the 35 non-ASCII rows lost
# their last cell before the line reader was fixed), and the categories must
# add up to the row count.
set(FR_STATUS_VOCAB "idea;draft;reviewed;implemented;verified;deferred;partial")
set(N_UNPARSED 0)
set(UNPARSED_ROWS "")
set(CATEGORY_TEXT "")
foreach(CAT IN ITEMS verified implemented partial deferred idea draft reviewed)
    set(C 0)
    foreach(S IN LISTS SPEC_STATUS)
        if(S STREQUAL CAT)
            math(EXPR C "${C} + 1")
        endif()
    endforeach()
    if(C GREATER 0)
        list(APPEND CATEGORY_TEXT "${C} ${CAT}")
    endif()
endforeach()
foreach(ID IN LISTS SPEC_IDS)
    list(FIND SPEC_IDS "${ID}" IDX)
    list(GET SPEC_STATUS ${IDX} S)
    list(FIND FR_STATUS_VOCAB "${S}" VIDX)
    if(VIDX LESS 0)
        math(EXPR N_UNPARSED "${N_UNPARSED} + 1")
        list(APPEND UNPARSED_ROWS "${ID}('${S}')")
    endif()
endforeach()
list(JOIN CATEGORY_TEXT ", " CATEGORY_DETAIL)

if(N_UNPARSED GREATER 0)
    list(JOIN UNPARSED_ROWS " " UTEXT)
    add_row("02::spec x verification FR mirror::blocked::${N_UNPARSED}/${N_SPEC} FR rows have an unparsed status cell: ${UTEXT}")
elseif(MISMATCH)
    list(JOIN MISMATCH " " MISMATCH_TEXT)
    add_row("02::spec x verification FR mirror::blocked::${MISMATCH_TEXT}")
else()
    add_row("02::spec x verification FR mirror::ok::${N_SPEC} FRs (${CATEGORY_DETAIL}), statuses identical")
endif()

# --- 3. verified rows must name a real test ---------------------------------
riscv_read_lines(VERIF_LINES "${VERIF}")
riscv_read_lines(MANIFEST_LINES "${MANIFEST}")
set(GHOST "")
set(N_VERIFIED 0)
foreach(ID IN LISTS SPEC_IDS)
    list(FIND SPEC_IDS "${ID}" IDX)
    list(GET SPEC_STATUS ${IDX} STATUS)
    if(NOT STATUS STREQUAL "verified")
        continue()
    endif()
    math(EXPR N_VERIFIED "${N_VERIFIED} + 1")

    set(ROW_TEXT "")
    foreach(LINE IN LISTS VERIF_LINES)
        if(LINE MATCHES "^\\| ${ID} ")
            set(ROW_TEXT "${LINE}")
        endif()
    endforeach()

    string(REGEX MATCHALL "T-[0-9][0-9]" TIDS "${ROW_TEXT}")
    if(NOT TIDS)
        list(APPEND GHOST "${ID}(no-T-id)")
        continue()
    endif()
    list(REMOVE_DUPLICATES TIDS)
    foreach(TID IN LISTS TIDS)
        set(FOUND FALSE)
        foreach(ML IN LISTS MANIFEST_LINES)
            if(ML MATCHES "^${TID}\t")
                set(FOUND TRUE)
                string(REPLACE "\t" ";" MF "${ML}")
                list(GET MF 1 TCLASS)
                if(NOT EXISTS "${ROOT}/tb/tests/${TCLASS}.sv")
                    list(APPEND GHOST "${ID}(${TID}-no-file)")
                endif()
            endif()
        endforeach()
        if(NOT FOUND)
            list(APPEND GHOST "${ID}(${TID}-not-in-manifest)")
        endif()
    endforeach()
endforeach()

if(GHOST)
    list(JOIN GHOST " " GHOST_TEXT)
    add_row("03::verified FRs name a real test::blocked::${GHOST_TEXT}")
else()
    add_row("03::verified FRs name a real test::ok::${N_VERIFIED} verified row(s) resolve to the manifest")
endif()

# --- 4. ledger: no open question, no expired assumption ---------------------
table_rows(Q_ROWS "${QUESTIONS}" "Q-")
set(OPEN_Q "")
foreach(ROW IN LISTS Q_ROWS)
    string(REPLACE "::" ";" CELL "${ROW}")
    list(GET CELL 0 ID)
    list(GET CELL 1 STATUS)
    string(TOLOWER "${STATUS}" LOW)
    if(LOW MATCHES "^open")
        list(APPEND OPEN_Q "${ID}")
    endif()
endforeach()

string(TIMESTAMP TODAY "%Y-%m-%d" UTC)
set(EXPIRED "")
riscv_read_lines(SPEC_LINES "${SPEC}")
table_rows(A_ROWS "${SPEC}" "A-")
foreach(ROW IN LISTS A_ROWS)
    string(REPLACE "::" ";" CELL "${ROW}")
    list(GET CELL 0 ID)
    list(GET CELL 1 STATUS)
    if(STATUS MATCHES "^confirmed" OR STATUS MATCHES "^superseded" OR STATUS MATCHES "^retired")
        continue()
    endif()
    foreach(LINE IN LISTS SPEC_LINES)
        if(LINE MATCHES "^\\| ${ID} ")
            string(REPLACE "|" ";" LC "${LINE}")
            list(LENGTH LC N)
            if(N GREATER 6)
                list(GET LC 5 DUE)
                string(STRIP "${DUE}" DUE)
                if(DUE MATCHES "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$")
                    if(DUE STRGREATER TODAY)
                    else()
                        list(APPEND EXPIRED "${ID}(due ${DUE})")
                    endif()
                endif()
            endif()
        endif()
    endforeach()
endforeach()

if(OPEN_Q OR EXPIRED)
    list(JOIN OPEN_Q " " OQ)
    list(JOIN EXPIRED " " EX)
    add_row("04::ledger: no open question, no expired assumption::blocked::open: ${OQ}; expired: ${EX}")
else()
    add_row("04::ledger: no open question, no expired assumption::ok::0 open, 0 expired")
endif()

# --- 5. latest regression ----------------------------------------------------
riscv_tree_digest(CURRENT_RTL "${ROOT}/rtl")
file(GLOB RUN_RESULTS "${BUILD}/regress/*/results.json")
set(LATEST "")
set(LATEST_TIME 0)
foreach(F IN LISTS RUN_RESULTS)
    if(WP STREQUAL "")
        set(MATCH TRUE)
    else()
        json_field(W "${F}" "wp")
        if(W STREQUAL "")
            # Evidence recorded before the rename still carries the old key.
            json_field(W "${F}" "wave")
        endif()
        string(STRIP "${W}" W)
        # A full regression (wp = null) covers the work package as well; a run
        # that names another work package does not.
        if(W STREQUAL WP OR W STREQUAL "null")
            set(MATCH TRUE)
        else()
            set(MATCH FALSE)
        endif()
    endif()
    if(MATCH)
        file(TIMESTAMP "${F}" STAMP "%s" UTC)
        if(STAMP GREATER LATEST_TIME)
            set(LATEST_TIME "${STAMP}")
            set(LATEST "${F}")
        endif()
    endif()
endforeach()

if(LATEST STREQUAL "")
    add_row("05::latest regression::blocked::no build/regress/*/results.json; run make regress")
else()
    json_field(FAIL "${LATEST}" "fail")
    json_field(TMO "${LATEST}" "timeout")
    json_field(DIGEST "${LATEST}" "rtl_digest")
    string(TIMESTAMP NOW "%s" UTC)
    math(EXPR AGE_DAYS "(${NOW} - ${LATEST_TIME}) / 86400")

    set(PROBLEMS "")
    if(FAIL GREATER 0)
        list(APPEND PROBLEMS "${FAIL} failing")
    endif()
    if(TMO GREATER 0)
        list(APPEND PROBLEMS "${TMO} timed out")
    endif()
    if(NOT DIGEST STREQUAL CURRENT_RTL)
        list(APPEND PROBLEMS "rtl_digest is stale")
    endif()
    if(AGE_DAYS GREATER MAX_AGE_DAYS)
        list(APPEND PROBLEMS "${AGE_DAYS}d old")
    endif()

    if(PROBLEMS)
        list(JOIN PROBLEMS " " PTEXT)
        add_row("05::latest regression::blocked::${LATEST}: ${PTEXT}")
    else()
        add_row("05::latest regression::ok::${LATEST} (${FAIL} fail, ${AGE_DAYS}d old, digest matches)")
    endif()
endif()

# --- 6, 8, 9, 10: release-only evidence -------------------------------------
if(NOT RELEASE)
    foreach(N IN ITEMS 6 8 9 10)
        if(N LESS 10)
            set(NUM_KEY "0${N}")
        else()
            set(NUM_KEY "${N}")
        endif()
        add_row("${NUM_KEY}::release check ${N}::skipped::work-package gate")
    endforeach()
else()
    # 6. sanity
    set(SAN "${BUILD}/sanity/summary.json")
    if(NOT EXISTS "${SAN}")
        add_row("06::sanity images (NFR-05)::not-measurable::build/sanity/summary.json absent; run make sanity")
    else()
        json_field(ST "${SAN}" "status")
        json_field(REASON "${SAN}" "reason")
        json_field(SAN_RTL "${SAN}" "rtl_digest")
        json_field(SAN_TB "${SAN}" "tb_digest")
        riscv_tree_digest(SAN_TB_NOW "${ROOT}/tb")
        if(NOT SAN_RTL STREQUAL CURRENT_RTL OR NOT SAN_TB STREQUAL SAN_TB_NOW)
            add_row("06::sanity images (NFR-05)::blocked::summary.json is stale (rtl/tb digest); re-run make sanity")
        elseif(ST STREQUAL "measured")
            json_field(SAN_FAIL "${SAN}" "fail")
            if(SAN_FAIL GREATER 0)
                add_row("06::sanity images (NFR-05)::blocked::${SAN_FAIL} image(s) failed")
            else()
                add_row("06::sanity images (NFR-05)::ok::images passed")
            endif()
        else()
            add_row("06::sanity images (NFR-05)::not-measurable::${REASON}")
        endif()
    endif()

    # 8. NFR-01..04 measurements
    set(INCOMPLETE "")
    foreach(NFR IN ITEMS NFR-01 NFR-02 NFR-03 NFR-04)
        file(GLOB M_FILES "${ROOT}/doc/measurements/${NFR}-*.md")
        list(LENGTH M_FILES N_M)
        if(N_M EQUAL 0)
            list(APPEND INCOMPLETE "${NFR}(missing)")
        else()
            list(GET M_FILES 0 M_FILE)
            file(READ "${M_FILE}" M_TEXT)
            string(TOLOWER "${M_TEXT}" M_LOW)
            if(NOT M_LOW MATCHES "method" OR NOT M_TEXT MATCHES "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]")
                list(APPEND INCOMPLETE "${NFR}(no method/date)")
            endif()
        endif()
    endforeach()
    if(INCOMPLETE)
        list(JOIN INCOMPLETE " " ITEXT)
        add_row("08::NFR-01..04 measurements::not-measurable::${ITEXT}")
    else()
        add_row("08::NFR-01..04 measurements::ok::4 files with method and date")
    endif()

    # 9. NFR-07 lint
    file(GLOB LINT_FILES "${ROOT}/doc/measurements/NFR-07-*.md")
    list(LENGTH LINT_FILES N_LINT)
    if(N_LINT EQUAL 0)
        add_row("09::NFR-07 latches/comb loops::not-measurable::no doc/measurements/NFR-07-*.md (G-05)")
    else()
        list(GET LINT_FILES 0 LINT_FILE)
        file(READ "${LINT_FILE}" LINT_TEXT)
        string(TOLOWER "${LINT_TEXT}" LINT_LOW)
        if(LINT_LOW MATCHES "not measurable" OR LINT_LOW MATCHES "not-measurable")
            add_row("09::NFR-07 latches/comb loops::not-measurable::${LINT_FILE}")
        else()
            add_row("09::NFR-07 latches/comb loops::ok::${LINT_FILE}")
        endif()
    endif()

    # 10. A-09
    set(DONE_VERIFIED 0)
    set(BY_STATUS "")
    set(PENDING "")
    foreach(CAT IN ITEMS implemented partial deferred)
        set(C 0)
        foreach(ID IN LISTS SPEC_IDS)
            list(FIND SPEC_IDS "${ID}" IDX)
            list(GET SPEC_STATUS ${IDX} S)
            if(S STREQUAL CAT)
                math(EXPR C "${C} + 1")
                if(C LESS_EQUAL 8)
                    list(APPEND PENDING "${ID}")
                endif()
            endif()
        endforeach()
        if(C GREATER 0)
            list(APPEND BY_STATUS "${CAT}=${C}")
        endif()
    endforeach()
    foreach(ID IN LISTS SPEC_IDS)
        list(FIND SPEC_IDS "${ID}" IDX)
        list(GET SPEC_STATUS ${IDX} S)
        if(S STREQUAL "verified")
            math(EXPR DONE_VERIFIED "${DONE_VERIFIED} + 1")
        endif()
    endforeach()

    set(RELEASE_GAPS "")
    foreach(LINE IN LISTS VERIF_LINES)
        if(LINE MATCHES "^\\| G-")
            string(TOLOWER "${LINE}" LOW)
            if(LOW MATCHES "release blocker")
                string(REPLACE "|" ";" GC "${LINE}")
                list(GET GC 1 GID)
                string(STRIP "${GID}" GID)
                list(APPEND RELEASE_GAPS "${GID}")
            endif()
        endif()
    endforeach()

    if(DONE_VERIFIED LESS N_SPEC)
        list(JOIN BY_STATUS " " BTEXT)
        list(JOIN RELEASE_GAPS " " GTEXT)
        list(JOIN PENDING " " PTEXT)
        add_row("10::A-09: every FR verified::blocked::${DONE_VERIFIED}/${N_SPEC} verified, ${BTEXT}, release-blocker gaps: ${GTEXT}, pending (first 8 per category): ${PTEXT}")
    else()
        add_row("10::A-09: every FR verified::ok::${N_SPEC}/${N_SPEC} verified")
    endif()
endif()

# --- 7. coverage (both modes) ------------------------------------------------
set(COV "${BUILD}/cov_report/summary.json")
if(NOT EXISTS "${COV}")
    add_row("07::coverage merge + bins (NFR-06)::not-measurable::build/cov_report/summary.json absent; run make coverage")
else()
    json_field(COV_ST "${COV}" "status")
    json_field(COV_DIGEST "${COV}" "rtl_digest")
    json_field(COV_POINTS "${COV}" "coverpoints")
    json_field(COV_PCT "${COV}" "percentages")
    json_field(COV_REASON "${COV}" "reason")
    if(NOT COV_ST STREQUAL "measured")
        add_row("07::coverage merge + bins (NFR-06)::blocked::${COV_REASON}")
    elseif(NOT COV_DIGEST STREQUAL CURRENT_RTL)
        add_row("07::coverage merge + bins (NFR-06)::blocked::coverage measured at another digest; re-run make coverage")
    else()
        add_row("07::coverage merge + bins (NFR-06)::ok::coverpoints=${COV_POINTS}, percentages=${COV_PCT}")
    endif()
endif()

# --- 11. work-package negative control (test-first) --------------------------
# A stored red run is history: it dies with `build/` and cannot be regenerated
# on fixed RTL. What is reproducible is that the test fails on its mutant, so
# this check reads build/red/<T-id>/results.json, produced by the
# `negative-control` target that this gate depends on.
if(WP STREQUAL "")
    add_row("11::work-package negative control (test-first)::skipped::checked per work package; see --wp <n>")
else()
    set(NC_PROBLEMS "")
    riscv_manifest_rows(MANIFEST_ROWS "${MANIFEST}")
    foreach(MROW IN LISTS MANIFEST_ROWS)
        string(REPLACE "|" ";" MF "${MROW}")
        list(GET MF 0 TID)
        list(GET MF 2 TW)
        list(LENGTH MF NF)
        set(RED_SPEC "no")
        if(NF GREATER 5)
            list(GET MF 5 RED_SPEC)
        endif()
        if(NOT TW STREQUAL WP OR NOT RED_SPEC MATCHES "^mutant:")
            continue()
        endif()

        set(NC "${BUILD}/red/${TID}/results.json")
        if(NOT EXISTS "${NC}")
            list(APPEND NC_PROBLEMS "${TID}(no-negative-control; run make negative-control)")
            continue()
        endif()
        file(READ "${NC}" NCJSON)
        if(NOT NCJSON MATCHES "\"id\": \"${TID}\", \"test\": \"[^\"]*\", \"status\": \"(fail|timeout)\"")
            list(APPEND NC_PROBLEMS "${TID}(mutant-not-detected)")
        elseif(NOT NCJSON MATCHES "\"uvm_errors\": [1-9]")
            list(APPEND NC_PROBLEMS "${TID}(no-uvm-error-on-mutant)")
        endif()
    endforeach()

    if(NC_PROBLEMS)
        list(JOIN NC_PROBLEMS " " NTEXT)
        add_row("11::work-package negative control (test-first)::blocked::${NTEXT}")
    else()
        add_row("11::work-package negative control (test-first)::ok::every WP test fails on the mutant it carries")
    endif()
endif()

# --- report ------------------------------------------------------------------
list(SORT ROWS)

set(N_BLOCKED 0)
set(N_NOTMEAS 0)
foreach(ROW IN LISTS ROWS)
    string(REPLACE "::" ";" CELL "${ROW}")
    list(GET CELL 2 SEV)
    if(SEV STREQUAL "blocked")
        math(EXPR N_BLOCKED "${N_BLOCKED} + 1")
    elseif(SEV STREQUAL "not-measurable")
        math(EXPR N_NOTMEAS "${N_NOTMEAS} + 1")
    endif()
endforeach()

if(N_BLOCKED GREATER 0 OR N_NOTMEAS GREATER 0)
    set(VERDICT "blocked")
else()
    set(VERDICT "signoff-ready")
endif()

riscv_tree_digest(CURRENT_TB "${ROOT}/tb")
string(TIMESTAMP RECORDED "%Y-%m-%dT%H:%M:%SZ" UTC)

set(REPORT "# Signoff report - ${MODE}

| Field | Value |
|---|---|
| Verdict | **${VERDICT}** |
| Mode | ${MODE} |
| Recorded | ${RECORDED} |
| RTL digest | \`${CURRENT_RTL}\` |
| TB digest | \`${CURRENT_TB}\` |
| Blocked | ${N_BLOCKED} |
| Not measurable | ${N_NOTMEAS} |

## Checks

| # | Check | Severity | Detail |
|---|---|---|---|
")
foreach(ROW IN LISTS ROWS)
    row_fields("${ROW}")
    string(APPEND REPORT "| ${ROW_NUM} | ${ROW_NAME} | ${ROW_SEV} | ${ROW_DETAIL} |\n")
endforeach()
string(APPEND REPORT "
Generated by \`scripts/verify/signoff_check.cmake\`; every severity is derived from a file, a digest or an exit code.
")

file(WRITE "${OUT}/report.md" "${REPORT}")

set(NEXT_ACTIONS "")
foreach(ROW IN LISTS ROWS)
    row_fields("${ROW}")
    message("${ROW_NUM}  ${ROW_NAME}  ${ROW_SEV}")
    if(NOT ROW_SEV STREQUAL "ok" AND NOT ROW_SEV STREQUAL "skipped")
        if(ROW_NUM STREQUAL "5")
            if(WP STREQUAL "")
                list(APPEND NEXT_ACTIONS "make regress                      (records the run check 5 audits)")
            else()
                list(APPEND NEXT_ACTIONS "make regress REGRESS_ARGS=\"--wp ${WP}\"   (records the run check 5 audits)")
            endif()
        elseif(ROW_NUM STREQUAL "11")
            if(WP STREQUAL "")
                list(APPEND NEXT_ACTIONS "record a red run per work package (see the WP plan)")
            else()
                list(APPEND NEXT_ACTIONS "make regress REGRESS_ARGS=\"--test <T-id> --record red --wp ${WP}\"   (test-first evidence)")
            endif()
        elseif(ROW_NUM STREQUAL "7")
            list(APPEND NEXT_ACTIONS "make coverage")
        elseif(ROW_NUM STREQUAL "6")
            list(APPEND NEXT_ACTIONS "make sanity                      (see doc/measurements/NFR-05-riscv-tests.md for the failing images)")
        elseif(ROW_NUM STREQUAL "10")
            list(APPEND NEXT_ACTIONS "close the FR gaps: see doc/verification.md")
        endif()
    endif()
endforeach()

if(NEXT_ACTIONS)
    list(REMOVE_DUPLICATES NEXT_ACTIONS)
    message("")
    message("SIGNOFF needs evidence before it can pass:")
    foreach(ACTION IN LISTS NEXT_ACTIONS)
        message("  - ${ACTION}")
    endforeach()
endif()

message(STATUS "report: build/signoff/report.md")
message("SIGNOFF ${VERDICT} (blocked=${N_BLOCKED} not_measurable=${N_NOTMEAS})")

if(NOT VERDICT STREQUAL "signoff-ready")
    message(FATAL_ERROR "signoff blocked")
endif()
