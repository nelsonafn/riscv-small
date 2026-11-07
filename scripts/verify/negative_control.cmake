# =============================================================================
# negative_control.cmake - prove that a test fails on the defect it covers.
#
#   cmake -P scripts/verify/negative_control.cmake                every mutant
#   cmake -P scripts/verify/negative_control.cmake --test T-06    one test
#   cmake -P scripts/verify/negative_control.cmake --wp 7         every mutant of a WP
#   cmake -P scripts/verify/negative_control.cmake --list
#   cmake -P scripts/verify/negative_control.cmake --shards 8     eight shards, concurrently
#   cmake -P scripts/verify/negative_control.cmake --shard 1/8 --mt 2
#                                                                 one shard, run by hand
#   cmake -P scripts/verify/negative_control.cmake --jobs 8       accepted, a no-op alias
#
# --wp N selects the manifest rows whose `wp` column is N and whose `red` cell
# is `mutant:<name>` (the same rows check 11 audits); rows with `red=no` are
# skipped, exactly as in the full run. `--test` and `--wp` are exclusive: a
# gate that guessed which one won would run the wrong evidence.
#
# A "red" run recorded in the past cannot be trusted: it lives in build/, so
# `rm -rf build` erases it, and it cannot be regenerated once the RTL is fixed.
# Instead, every test that claims to cover a defect names its mutant in
# scripts/verify/mutants.tsv: the row holds the one-line source change that
# reintroduces the defect. This runner copies the tree into
# build/mutants/<T-id>/, applies the mutant there, runs the test and requires a
# UVM failure. The repository is never edited and nothing depends on history.
#
# Shards: one mutant is a private copy of the tree plus a full compile, an
# elaboration and one simulation, so N mutants are N times minutes of mostly
# serial work. `--shards N` splits the selection into N disjoint shards and runs
# them as N background processes: selected row k (0-based) is owned by shard
# (k mod N) + 1, so the union over N shards is exactly the serial selection --
# no row dropped, no row duplicated, and no row executed twice. `--shard i/N`
# runs one shard; `--shards 1` (the default) is the serial run, unchanged.
#
# The merge re-reads the evidence instead of adding exit codes: every selected
# T-id must have a build/red/<T-id>/results.json written by this run (the
# selected evidence is removed before any shard starts, so a stale file can
# never stand in for a shard that died), and every shard's log must report the
# count the master partitioned to it. A shard that exits non-zero, a shard that
# silently owns nothing, and a shard that reports fewer detections than it was
# given are all a failed verdict.
#
# --mt N lowers the xelab thread budget of each mutant's own elaboration. The
# build hardcodes `--mt 16` for one elaboration; N shards would then ask for
# 16*N threads on a 24-core box and spend their time fighting each other. The
# shard patches its own disposable copy of CMakeLists.txt (never the
# repository), and the patch aborts if the literal is not there any more, so a
# build change cannot silently restore the oversubscription.
#
# Results: build/red/<T-id>/results.json, read by signoff_check check 11.
# Shard logs: build/signoff/negative-control.<i>.log, written by the master.
# Exit codes: 0 every mutant was detected, 1 a mutant passed (the test has no
#             teeth) or the run failed for another reason, 2 environment error.
# =============================================================================
cmake_minimum_required(VERSION 3.21)

include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(MANIFEST "${ROOT}/scripts/verify/tests.tsv")
set(MUTANT_TABLE "${ROOT}/scripts/verify/mutants.tsv")
set(OUT "${BUILD}/red")
set(SIGNOFF "${BUILD}/signoff")
set(SELF "${CMAKE_CURRENT_LIST_FILE}")
set(DOLLAR "$")

# --- arguments ---------------------------------------------------------------
set(REQUESTED "")
set(WP "")
set(DO_LIST FALSE)
set(JOBS_ARG "")
set(SHARD "")
set(SHARDS "1")
set(MT "")
# A while loop, not foreach: an option consumes the next argv element, and
# `foreach(I RANGE ...)` reassigns I at every iteration, so the skipped value
# would come back as a positional argument (measured: `--wp 7` then parsed "7"
# as a T-id). Each occurrence of `--test` appends, so `--test T-06 --test T-08`
# names two tests, which is what the master uses to replay its selection.
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    set(I 3)
    while(I LESS_EQUAL LAST_ARG)
        set(ARG "${CMAKE_ARGV${I}}")
        if(ARG STREQUAL "--list")
            set(DO_LIST TRUE)
        elseif(ARG STREQUAL "--test" OR ARG STREQUAL "--wp" OR ARG STREQUAL "--jobs"
               OR ARG STREQUAL "--shard" OR ARG STREQUAL "--shards" OR ARG STREQUAL "--mt")
            math(EXPR I "${I} + 1")
            if(I GREATER LAST_ARG)
                message(FATAL_ERROR "${ARG} needs a value")
            endif()
            set(VALUE "${CMAKE_ARGV${I}}")
            if(ARG STREQUAL "--test")
                list(APPEND REQUESTED "${VALUE}")
            elseif(ARG STREQUAL "--wp")
                set(WP "${VALUE}")
            elseif(ARG STREQUAL "--jobs")
                set(JOBS_ARG "${VALUE}")
            elseif(ARG STREQUAL "--shard")
                set(SHARD "${VALUE}")
            elseif(ARG STREQUAL "--mt")
                set(MT "${VALUE}")
            else()
                set(SHARDS "${VALUE}")
            endif()
        elseif(ARG MATCHES "^-")
            message(FATAL_ERROR "unknown option '${ARG}'")
        else()
            list(APPEND REQUESTED "${ARG}")
        endif()
        math(EXPR I "${I} + 1")
    endwhile()
endif()

if(REQUESTED AND NOT WP STREQUAL "")
    message(FATAL_ERROR "--test and --wp are exclusive selections; pass one of them")
endif()
if(NOT WP STREQUAL "" AND NOT WP MATCHES "^[0-9][0-9a-z]*$")
    message(FATAL_ERROR "--wp must be a work-package id such as 0, 7 or 4b, got '${WP}'")
endif()

# Accepted for the shared gate interface: `--jobs` used to be the only
# parallelism option and never had an effect here (every mutant runs exactly one
# test). It stays accepted so an old command line does not break, and the
# parallelism lives in `--shards`, one process per shard.
riscv_parallel_jobs(NC_JOBS "${JOBS_ARG}")

if(NOT SHARDS MATCHES "^[1-9][0-9]*$")
    message(FATAL_ERROR "--shards must be a positive integer, got '${SHARDS}'")
endif()

# The geometry of *this* process: `--shard i/N` runs one shard, anything else
# runs the whole selection (serial when --shards is 1, master when it is > 1).
set(SHARD_INDEX 1)
set(SHARD_COUNT 1)
if(NOT SHARD STREQUAL "")
    if(NOT SHARD MATCHES "^([1-9][0-9]*)/([1-9][0-9]*)$")
        message(FATAL_ERROR "--shard must be i/N such as 1/8, got '${SHARD}'")
    endif()
    set(SHARD_INDEX "${CMAKE_MATCH_1}")
    set(SHARD_COUNT "${CMAKE_MATCH_2}")
    if(SHARD_INDEX GREATER SHARD_COUNT)
        message(FATAL_ERROR "--shard ${SHARD}: the index must not exceed the count")
    endif()
    if(NOT SHARDS STREQUAL "1")
        message(FATAL_ERROR "--shard and --shards are exclusive: --shards spawns shards, it is not itself one")
    endif()
endif()

if(NOT MT STREQUAL "" AND NOT MT MATCHES "^[1-9][0-9]*$")
    message(FATAL_ERROR "--mt must be a positive integer, got '${MT}'")
endif()
# A sharded run means N concurrent elaborations, so the build's own `--mt 16`
# is the wrong budget. Serial keeps the build default (no patch, no surprise).
if(MT STREQUAL "" AND (SHARDS GREATER 1 OR SHARD_COUNT GREATER 1))
    set(MT 2)
endif()

# --- selection: every manifest row whose red column names a mutant -----------
# The catalogue is read once. A name no row defines must fail here, before any
# tree is copied: otherwise the gate would run the unmutated RTL and report a
# typo as a test without teeth.
riscv_mutant_names(CATALOGUE "${MUTANT_TABLE}")

riscv_manifest_rows(ROWS "${MANIFEST}")
# The work-package selection is one manifest read, shared with the regression's
# image filter: a WP owns the rows whose `wp` column names it.
set(WP_TESTS "")
if(NOT WP STREQUAL "")
    riscv_manifest_wp_tests(WP_TESTS "${MANIFEST}" "${WP}")
endif()
set(SELECTED "")
set(REFERENCED "")
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
    if(NOT NAME IN_LIST CATALOGUE)
        message(FATAL_ERROR "${TID} names mutant '${NAME}', but ${MUTANT_TABLE} has no such row")
    endif()
    list(APPEND REFERENCED "${NAME}")
    if(REQUESTED AND NOT TID IN_LIST REQUESTED)
        continue()
    endif()
    if(NOT WP STREQUAL "")
        list(FIND WP_TESTS "${TID}" WP_INDEX)
        if(WP_INDEX EQUAL -1)
            continue()
        endif()
    endif()
    list(APPEND SELECTED "${TID}|${NAME}")
endforeach()

# The serial selection, kept for the partition report and the shard split.
set(SELECTION "${SELECTED}")
list(LENGTH SELECTION N_ALL)

# Who owns what: entry k (0-based) belongs to shard (k mod N) + 1. The rule is
# the only definition of the partition, used by the master (to know what to
# expect from each shard) and by the shard (to know what to run).
function(riscv_nc_partition OUT_VAR ENTRIES COUNT INDEX)
    set(OWNED "")
    set(K 0)
    math(EXPR WANT "${INDEX} - 1")
    foreach(ENTRY IN LISTS ENTRIES)
        math(EXPR MOD "${K} % ${COUNT}")
        if(MOD EQUAL WANT)
            list(APPEND OWNED "${ENTRY}")
        endif()
        math(EXPR K "${K} + 1")
    endforeach()
    set(${OUT_VAR} "${OWNED}" PARENT_SCOPE)
endfunction()

riscv_nc_partition(SELECTED "${SELECTION}" "${SHARD_COUNT}" "${SHARD_INDEX}")
list(LENGTH SELECTED N_SELECTED)

if(DO_LIST)
    riscv_tsv_rows(MUTANT_ROWS "${MUTANT_TABLE}")
    foreach(ENTRY IN LISTS SELECTED)
        string(REPLACE "|" ";" CELL "${ENTRY}")
        list(GET CELL 0 TID)
        list(GET CELL 1 NAME)
        set(FILE "")
        set(WHY "")
        foreach(MROW IN LISTS MUTANT_ROWS)
            riscv_tsv_cell(MNAME "${MROW}" 0)
            if(MNAME STREQUAL NAME)
                riscv_tsv_cell(FILE "${MROW}" 1)
                riscv_tsv_cell(WHY "${MROW}" 4)
            endif()
        endforeach()
        message("${TID}  mutant=${NAME}  ${FILE}  ${WHY}")
    endforeach()
    if(SHARD_COUNT GREATER 1)
        # The union check lives in the count: N shards that each report their
        # share must add up to the serial selection, and nothing else may.
        message(STATUS "negative control: shard ${SHARD_INDEX}/${SHARD_COUNT} selects ${N_SELECTED} of ${N_ALL} mutant(s)")
    endif()
    # A row nothing selects is dead weight or a test that lost its red run.
    foreach(NAME IN LISTS CATALOGUE)
        if(NOT NAME IN_LIST REFERENCED)
            message(STATUS "negative control: ${NAME} is in the catalogue but no test names it")
        endif()
    endforeach()
    return()
endif()

if(NOT SELECTED)
    if(SHARD_COUNT GREATER 1)
        # A shard with nothing to do is legitimate (N > rows) but it must say
        # so: the master checks this line against the share it partitioned.
        message("NEGATIVE CONTROL shard ${SHARD_INDEX}/${SHARD_COUNT} pass=0 fail=0 (no row is owned by this shard)")
        return()
    endif()
    message(STATUS "negative control: no mutant selected (nothing to prove)")
    return()
endif()

if(NOT WP STREQUAL "")
    message(STATUS "negative control: work package ${WP} selects ${N_ALL} mutant(s)")
endif()

# --- the verdict of one mutant ----------------------------------------------
# Three callers ask the same question -- the serial run, a shard after its own
# run, the master after the merge -- so the predicate is defined once. The
# mutant must have produced a red record *and* a UVM error: a build failure or a
# tool crash is missing evidence, never a detected defect.
function(riscv_nc_judge OUT_VAR TID NAME RESULT)
    set(PROBLEM "")
    if(NOT EXISTS "${RESULT}")
        set(PROBLEM "${TID}: no results.json for mutant '${NAME}' (build failure or a shard that never ran it)")
    else()
        file(READ "${RESULT}" JSON)
        if(NOT JSON MATCHES "\"record\": \"red\"")
            set(PROBLEM "${TID}: the mutant run was not recorded as red")
        elseif(NOT JSON MATCHES "\"id\": \"${TID}\", \"test\": \"[^\"]*\", \"status\": \"(fail|timeout)\"")
            set(PROBLEM "${TID} PASSED on mutant '${NAME}': the test does not catch this defect")
        elseif(NOT JSON MATCHES "\"uvm_errors\": [1-9]")
            set(PROBLEM "${TID}: failed on mutant '${NAME}' without a UVM error; a build or tool failure is not a verdict")
        endif()
    endif()
    set(${OUT_VAR} "${PROBLEM}" PARENT_SCOPE)
endfunction()

# Evidence is regenerated, never reused: the orchestrator removes the selected
# artefacts first, so "the file is there" can only mean "this run wrote it".
function(riscv_nc_clear_evidence ENTRIES)
    foreach(ENTRY IN LISTS ${ENTRIES})
        string(REPLACE "|" ";" CELL "${ENTRY}")
        list(GET CELL 0 TID)
        file(REMOVE_RECURSE "${OUT}/${TID}")
        file(REMOVE "${OUT}/${TID}.log")
    endforeach()
endfunction()

# =============================================================================
# Master: --shards N > 1. Split, spawn the shards, then audit the evidence.
# =============================================================================
if(SHARDS GREATER 1 AND SHARD STREQUAL "")
    if(N_ALL LESS SHARDS)
        message(STATUS "negative control: ${N_ALL} mutant(s) for ${SHARDS} shards; the extra shards own nothing")
    endif()

    # Per-shard share, from the one partition rule. The sum is the serial
    # selection by construction; assert it anyway, because a partition that
    # loses a row would look exactly like a fast run.
    set(EXPECTED "")
    set(EXPECTED_TOTAL 0)
    set(SPLIT_TEXT "")
    foreach(I RANGE 1 ${SHARDS})
        riscv_nc_partition(SHARE "${SELECTION}" "${SHARDS}" "${I}")
        list(LENGTH SHARE N_SHARE)
        list(APPEND EXPECTED "${N_SHARE}")
        math(EXPR EXPECTED_TOTAL "${EXPECTED_TOTAL} + ${N_SHARE}")
        string(APPEND SPLIT_TEXT " ${I}:${N_SHARE}")
    endforeach()
    if(NOT EXPECTED_TOTAL EQUAL N_ALL)
        message(FATAL_ERROR "shard partition lost rows: ${EXPECTED_TOTAL} of ${N_ALL} selected mutants are owned")
    endif()
    message(STATUS "negative control: ${N_ALL} mutant(s) across ${SHARDS} shard(s):${SPLIT_TEXT}")

    # Only the master clears the whole selection: if it died halfway, the missing
    # files are the failure. A shard also clears its own share, so a direct
    # `--shard i/N` is honest too.
    riscv_nc_clear_evidence(SELECTION)
    file(MAKE_DIRECTORY "${SIGNOFF}" "${OUT}")

    # Leading spaces: the fragment is appended to the shard's argv, and a
    # missing separator would fuse `1/3` and `--wp` into one token.
    set(SELECT_TEXT "")
    if(NOT WP STREQUAL "")
        set(SELECT_TEXT " --wp ${WP}")
    else()
        foreach(TID IN LISTS REQUESTED)
            string(APPEND SELECT_TEXT " --test ${TID}")
        endforeach()
    endif()
    set(MT_ARG "")
    if(NOT MT STREQUAL "")
        set(MT_ARG " --mt ${MT}")
    endif()

    # N background processes, one wait per pid: a bare `wait` returns the status
    # of the last job only, which is exactly the "a dead shard looks healthy"
    # bug. Previous shard logs go first: a log from a 16-shard run must not sit
    # next to this run's twelve as if it belonged to it.
    file(GLOB STALE_LOGS "${SIGNOFF}/negative-control.[0-9]*.log")
    if(STALE_LOGS)
        file(REMOVE ${STALE_LOGS})
    endif()
    set(SCRIPT "")
    set(WAITS "")
    foreach(I RANGE 1 ${SHARDS})
        set(LOG "${SIGNOFF}/negative-control.${I}.log")
        string(APPEND SCRIPT
            "'${CMAKE_COMMAND}' -P '${SELF}' --shard ${I}/${SHARDS}${SELECT_TEXT}${MT_ARG}"
            " > '${LOG}' 2>&1 & NC_P${I}=${DOLLAR}!; ")
        string(APPEND WAITS "wait ${DOLLAR}NC_P${I} || NC_RC=1; ")
    endforeach()
    message(STATUS "negative control: running ${SHARDS} shard(s) concurrently")
    execute_process(
        COMMAND bash -c "${SCRIPT}${WAITS}exit ${DOLLAR}{NC_RC:-0}"
        WORKING_DIRECTORY "${ROOT}"
        RESULT_VARIABLE MERGE_RC
        OUTPUT_FILE "${SIGNOFF}/negative-control.master.log"
        ERROR_FILE "${SIGNOFF}/negative-control.master.log")

    # The merge: an exit code per shard, the count each shard says it detected,
    # and the evidence itself. None of the three is redundant -- a shard can exit
    # 0 having run nothing, and a stale results.json can outlive a dead shard.
    set(PROBLEMS "")
    if(NOT MERGE_RC EQUAL 0)
        list(APPEND PROBLEMS "a shard exited non-zero (see build/signoff/negative-control.<i>.log)")
    endif()
    set(K 0)
    foreach(COUNT IN LISTS EXPECTED)
        math(EXPR I "${K} + 1")
        math(EXPR K "${K} + 1")
        set(LOG "${SIGNOFF}/negative-control.${I}.log")
        if(NOT EXISTS "${LOG}")
            list(APPEND PROBLEMS "shard ${I}/${SHARDS}: no log (the process never started)")
            continue()
        endif()
        file(READ "${LOG}" TEXT)
        if(NOT TEXT MATCHES "NEGATIVE CONTROL shard ${I}/${SHARDS} pass=${COUNT} fail=0")
            # No semicolon: CMake would split the entry into two list items.
            list(APPEND PROBLEMS "shard ${I}/${SHARDS}: log does not report pass=${COUNT} (expected ${COUNT} mutant(s)), see ${LOG}")
        else()
            message(STATUS "negative control: shard ${I}/${SHARDS} detected ${COUNT}/${COUNT}")
        endif()
    endforeach()

    set(N_DETECTED 0)
    foreach(ENTRY IN LISTS SELECTION)
        string(REPLACE "|" ";" CELL "${ENTRY}")
        list(GET CELL 0 TID)
        list(GET CELL 1 NAME)
        riscv_nc_judge(PROBLEM "${TID}" "${NAME}" "${OUT}/${TID}/results.json")
        if(PROBLEM)
            # The judge's text carries a semicolon; a bare list(APPEND) would
            # split it into two problems and count the failure twice.
            string(REPLACE ";" "," PROBLEM "${PROBLEM}")
            list(APPEND PROBLEMS "${PROBLEM}")
        else()
            math(EXPR N_DETECTED "${N_DETECTED} + 1")
            message(STATUS "NEGATIVE ${TID} detected on mutant '${NAME}'")
        endif()
    endforeach()

    list(LENGTH PROBLEMS N_PROBLEMS)
    if(N_PROBLEMS GREATER 0)
        list(JOIN PROBLEMS "\n  - " TEXT)
        message("NEGATIVE CONTROL pass=${N_DETECTED} fail=${N_PROBLEMS} shards=${SHARDS} (the merge is not clean)")
        message(FATAL_ERROR "negative control failed:\n  - ${TEXT}")
    endif()
    message("NEGATIVE CONTROL pass=${N_DETECTED} fail=0 shards=${SHARDS} (every selected test fails on its mutant)")
    return()
endif()

# =============================================================================
# Runner: the serial selection (shard 1/1) or one shard.
# =============================================================================
find_program(XSIM_BIN xsim)
if(NOT XSIM_BIN)
    message(FATAL_ERROR "xsim not on PATH: source the EDA environment first (scripts/setup.sh)")
endif()

file(MAKE_DIRECTORY "${OUT}" "${BUILD}/mutants")
riscv_nc_clear_evidence(SELECTED)

# --- run each mutant on a disposable copy of the tree ------------------------
set(N_DETECTED 0)
foreach(ENTRY IN LISTS SELECTED)
    string(REPLACE "|" ";" CELL "${ENTRY}")
    list(GET CELL 0 TID)
    list(GET CELL 1 NAME)

    set(SCRATCH "${BUILD}/mutants/${TID}")
    file(REMOVE_RECURSE "${SCRATCH}")
    file(MAKE_DIRECTORY "${SCRATCH}")

    # Copy only what the build needs. `src` is a symlink: the sanity module only
    # globs it at configure time. A real copy (not hard links) matters: the
    # mutant writes the file, and a hard link would edit the repository.
    file(COPY "${ROOT}/rtl" "${ROOT}/tb" "${ROOT}/srclist" "${ROOT}/scripts"
              "${ROOT}/CMakeLists.txt" "${ROOT}/configure" DESTINATION "${SCRATCH}")
    file(CREATE_LINK "${ROOT}/src" "${SCRATCH}/src" SYMBOLIC)

    # One mechanism for every mutant: an exact single-occurrence text patch on
    # the copy, which aborts if the row no longer matches the tree. Its `why` is
    # a STATUS line, so the gate output says which defect was rebuilt.
    riscv_mutant_apply("${SCRATCH}" "${NAME}" "${MUTANT_TABLE}")

    # The thread budget belongs to the scratch, never to the repository: N
    # shards elaborate at once, so the build's own budget (--mt 16) would
    # oversubscribe the box. A requested budget equal to the build's own is a
    # no-op, not an error: read the literal, and patch only when it differs. A
    # missing literal is a hard error, not a silent 16 threads.
    if(NOT MT STREQUAL "")
        file(READ "${SCRATCH}/CMakeLists.txt" BUILD_FILE)
        set(BUILD_MT "")
        if(BUILD_FILE MATCHES "--mt ([0-9]+)")
            set(BUILD_MT "${CMAKE_MATCH_1}")
        endif()
        if(BUILD_MT STREQUAL "")
            message(FATAL_ERROR "cannot lower the xelab thread budget: ${SCRATCH}/CMakeLists.txt has no '--mt <n>' literal")
        endif()
        if(NOT MT STREQUAL BUILD_MT)
            riscv_patch_once("${SCRATCH}/CMakeLists.txt" "--mt ${BUILD_MT}" "--mt ${MT}"
                "xelab thread budget ${MT} for ${SHARD_COUNT} concurrent shard(s)" "xelab")
        endif()
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

    riscv_nc_judge(PROBLEM "${TID}" "${NAME}" "${SCRATCH}/build/red/results.json")
    if(PROBLEM)
        message(FATAL_ERROR "${PROBLEM}; see build/mutants/${TID}/negative.log")
    endif()

    set(RESULT "${SCRATCH}/build/red/results.json")
    file(MAKE_DIRECTORY "${OUT}/${TID}")
    file(COPY "${RESULT}" DESTINATION "${OUT}/${TID}")
    if(EXISTS "${SCRATCH}/build/regress/${TID}.log")
        file(COPY "${SCRATCH}/build/regress/${TID}.log" DESTINATION "${OUT}/${TID}")
        # results.json's `log` field is relative to the scratch's build/red;
        # keep a copy at that path too, or the published evidence points nowhere.
        file(COPY "${SCRATCH}/build/regress/${TID}.log" DESTINATION "${OUT}")
    endif()

    math(EXPR N_DETECTED "${N_DETECTED} + 1")
    message(STATUS "NEGATIVE ${TID} detected on mutant '${NAME}'")
    file(REMOVE_RECURSE "${SCRATCH}")
endforeach()

if(SHARD_COUNT GREATER 1)
    # The master reads this line against its own partition, so a shard that ran
    # fewer mutants than it owns cannot be mistaken for a shard with less work.
    message("NEGATIVE CONTROL shard ${SHARD_INDEX}/${SHARD_COUNT} pass=${N_DETECTED} fail=0 (every mutant this shard owns is detected)")
else()
    message("NEGATIVE CONTROL pass=${N_DETECTED} fail=0 (every selected test fails on its mutant)")
endif()
