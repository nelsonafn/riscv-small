# =============================================================================
# scripts/verify/common.cmake - the one shared library of the verification gates
#
# Included by regress.cmake, coverage.cmake, sanity.cmake, negative_control.cmake
# and signoff_check.cmake, in configure mode and in `cmake -P` mode. It defines
# functions, two path variables and the `VERIFY_JOBS` cache default; it never
# declares a target.
#
#   riscv_tsv_rows(OUT <file>)                  rows of a tab-separated table, `|`-joined
#   riscv_tsv_cell(OUT <row> <index>)           one cell; `;` restored, spaces kept
#   riscv_manifest_rows(OUT <tests.tsv>)        one row: T-id|uvm_test|wp|frs|timeout|red|extra
#   riscv_manifest_extra(OUT <row>)             the optional 7th column (`sanity:<image>`)
#   riscv_manifest_wp_tests(OUT <manifest> <wp>) T-ids owned by a work package
#   riscv_manifest_sanity_images(OUT <manifest>) images named by the 7th column
#   riscv_manifest_sanity_targets(OUT <manifest> [TESTS <T-id>...])
#                                               `compile_sanity_<image>` for each selected row
#   riscv_junit_rows(OUT <junit.xml>)           CTest verdicts: T-id|pass|fail|timeout|skip|class
#   riscv_tree_digest(OUT <dir>)                sha256 over the .sv/.svh content
#   riscv_tree_digests(OUT_RTL OUT_TB <root>)   the RTL/TB pair every gate records
#   riscv_bootstrap_build(<log>)                ./configure when build/Makefile is absent
#   riscv_ctest_run(<junit> <workdir> LOG <log> [JOBS <n>] [ENV ...] [SELECT ...])
#   riscv_test_run_dir(OUT_VAR <name>)          build/runs/<name> with xsim.dir symlinked
#   riscv_parallel_jobs(OUT_VAR <raw>)          validate `--jobs`, default 1
#   riscv_xsim_command(OUT ...)                 the one `bash -c` xsim command string
#                                               (`SANITY_IMAGE` pins the verdict line)
#   riscv_mutant_names(OUT <mutants.tsv>)       the `name` column of the catalogue
#   riscv_patch_once(<file> <find> <replace> <why> [<label>])
#                                               exact single-occurrence text patch
#   riscv_mutant_apply(<tree> <name> <tsv>)     every row named <name>, in table order
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

# --- parallel verification ---------------------------------------------------
# The one default every gate target uses. It is a cache variable so ./configure
# fixes a sensible value, and the target command lines read VERIFY_JOBS at make
# time (`--jobs $${VERIFY_JOBS:-<default>}`), so `VERIFY_JOBS=12 make regress`
# needs no re-configure. A --jobs inside *_ARGS comes later on the argv and
# wins: `jobs` is a one-value keyword and cmake_parse_arguments keeps the last
# value it sees.
if(NOT CMAKE_SCRIPT_MODE_FILE)
    include(ProcessorCount)
    ProcessorCount(RISCV_VERIFY_CORES)
    if(RISCV_VERIFY_CORES EQUAL 0)
        set(RISCV_VERIFY_CORES 1)
    endif()
    # Measured on the 24-core reference machine: 8 jobs 23.1 s, 12 jobs
    # 20.9 s for the 39-test regression (16/24 measured 18.2/15.7 s but the
    # default is bounded to keep one suite's peak well inside the machine).
    if(RISCV_VERIFY_CORES GREATER 12)
        set(RISCV_VERIFY_CORES 12)
    endif()
    set(VERIFY_JOBS "${RISCV_VERIFY_CORES}" CACHE STRING
        "Parallel ctest jobs for the verification targets (make-time override: VERIFY_JOBS=N make regress)")
endif()

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

# --- tab-separated tables ----------------------------------------------------
# One reader for every data file the gates own (tests.tsv, mutants.tsv). A row
# comes back as `field|field|...` because `;` is CMake's list separator;
# riscv_tsv_cell() is the only accessor and it restores the `;`, so a cell may
# contain a SystemVerilog statement. It reads through riscv_read_lines, not
# file(STRINGS), which splits a line at every non-ASCII byte.
function(riscv_tsv_rows OUT_VAR FILE)
    if(NOT EXISTS "${FILE}")
        message(FATAL_ERROR "table not found: ${FILE}")
    endif()
    riscv_read_lines(LINES "${FILE}")
    set(ROWS "")
    foreach(LINE IN LISTS LINES)
        string(REGEX REPLACE "\r$" "" LINE "${LINE}")
        if(LINE MATCHES "^[ \t]*(#|$)")
            continue()
        endif()
        # Leading spaces are data (a mutated SV line carries its indentation).
        string(REPLACE "\t" "|" ROW "${LINE}")
        list(APPEND ROWS "${ROW}")
    endforeach()
    set(${OUT_VAR} "${ROWS}" PARENT_SCOPE)
endfunction()

# 0-based cell. An absent column is ""; spaces are never stripped.
function(riscv_tsv_cell OUT_VAR ROW INDEX)
    string(REPLACE "|" ";" CELLS "${ROW}")
    list(LENGTH CELLS N)
    if(N LESS_EQUAL ${INDEX})
        set(${OUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    list(GET CELLS ${INDEX} CELL)
    string(REPLACE "@SEMI@" ";" CELL "${CELL}")
    set(${OUT_VAR} "${CELL}" PARENT_SCOPE)
endfunction()

# --- manifest ----------------------------------------------------------------
# tests.tsv keeps its contract: T-id|uvm_test|wp|requirements|timeout|red|extra
function(riscv_manifest_rows OUT_VAR MANIFEST)
    riscv_tsv_rows(ROWS "${MANIFEST}")
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

# The T-ids of the rows a work package owns (the manifest's `wp` column), so a
# selection is resolved once and every caller -- the regression's image list, the
# negative control's mutant list -- reads the same rows. Empty <wp> is "no
# filter" and returns every T-id.
function(riscv_manifest_wp_tests OUT_VAR MANIFEST WP)
    riscv_manifest_rows(ROWS "${MANIFEST}")
    set(IDS "")
    foreach(ROW IN LISTS ROWS)
        riscv_tsv_cell(TID "${ROW}" 0)
        riscv_tsv_cell(ROW_WP "${ROW}" 2)
        if(WP STREQUAL "" OR ROW_WP STREQUAL WP)
            list(APPEND IDS "${TID}")
        endif()
    endforeach()
    set(${OUT_VAR} "${IDS}" PARENT_SCOPE)
endfunction()

# `TESTS <T-id>...` restricts the list to the rows of the current selection, so a
# `--test T-13` run builds the one image it will simulate instead of every image
# the manifest names. No TESTS keeps the release path exactly as it was: every
# image the manifest names, through riscv_manifest_sanity_images().
function(riscv_manifest_sanity_targets OUT_VAR MANIFEST)
    cmake_parse_arguments(S "" "" "TESTS" ${ARGN})
    if(NOT S_TESTS)
        riscv_manifest_sanity_images(IMAGES "${MANIFEST}")
        set(TARGETS "")
        foreach(IMAGE IN LISTS IMAGES)
            list(APPEND TARGETS "compile_sanity_${IMAGE}")
        endforeach()
        set(${OUT_VAR} "${TARGETS}" PARENT_SCOPE)
        return()
    endif()

    riscv_manifest_rows(ROWS "${MANIFEST}")
    set(TARGETS "")
    foreach(ROW IN LISTS ROWS)
        riscv_tsv_cell(TID "${ROW}" 0)
        list(FIND S_TESTS "${TID}" TID_INDEX)
        if(TID_INDEX EQUAL -1)
            continue()
        endif()
        riscv_manifest_extra(IMAGE "${ROW}")
        if(IMAGE)
            list(APPEND TARGETS "compile_sanity_${IMAGE}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES TARGETS)
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

# One working directory per CTest test. xsim writes xsim.log, xsim.jou, the
# protobuf files, top_sim.wdb and xsim.covdb into the *current* directory, so
# two tests that share build/ overwrite each other's log and the verdict becomes
# a race (measured: `ctest -R '^(T-13|T-14)$' -j2` failed one of the two, and
# which one changed between runs).
#
# The snapshot directory is NOT read-only either: xsim rewrites
# `xsim.dir/<snapshot>/xsim_script.tcl` with the process's own command line (and
# touches xsimcrash.log) on every invocation, so a symlink to the shared
# build/xsim.dir makes two concurrent tests execute each other's argv (measured:
# T-13 and T-14 both loaded the same image and the loser failed only its
# `SANITY: PASS image=` grep). riscv_xsim_command() therefore materialises a
# private snapshot directory per run -- symlinks to the elaborated files, with
# xsim_script.tcl/xsimcrash.log left to the run. Only the run directory itself
# is created here, because the snapshot is built by `elaborate` after configure.
function(riscv_test_run_dir OUT_VAR NAME)
    if(CMAKE_SCRIPT_MODE_FILE)
        message(FATAL_ERROR "riscv_test_run_dir is a configure-mode helper")
    endif()
    set(DIR "${CMAKE_BINARY_DIR}/runs/${NAME}")
    file(MAKE_DIRECTORY "${DIR}")
    set(${OUT_VAR} "${DIR}" PARENT_SCOPE)
endfunction()

# `--jobs N`: every gate accepts it and 1 is the default, so a direct
# `cmake -P` behaves exactly as it did before the option existed. A value
# larger than the number of selected tests is harmless: CTest schedules what it
# has.
function(riscv_parallel_jobs OUT_VAR RAW)
    set(N "${RAW}")
    if(N STREQUAL "")
        set(N 1)
    endif()
    if(NOT N MATCHES "^[1-9][0-9]*$")
        message(FATAL_ERROR "--jobs must be a positive integer, got '${N}'")
    endif()
    set(${OUT_VAR} "${N}" PARENT_SCOPE)
endfunction()

function(riscv_ctest_run JUNIT WORKDIR)
    cmake_parse_arguments(C "" "LOG;JOBS" "ENV;SELECT" ${ARGN})
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "riscv_ctest_run: unknown ${C_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT C_LOG)
        message(FATAL_ERROR "riscv_ctest_run: LOG is required")
    endif()
    # No -j at all for the serial default: the command line is unchanged.
    set(PARALLEL "")
    if(C_JOBS AND C_JOBS GREATER 1)
        set(PARALLEL "-j${C_JOBS}")
    endif()
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env ${C_ENV}
                ${CMAKE_CTEST_COMMAND} ${PARALLEL} --output-junit "${JUNIT}" ${C_SELECT}
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
#   [REQUIRE_SANITY [SANITY_IMAGE <image>]]
# The command always requires `^UVM_RESULT: PASS`; REQUIRE_SANITY adds the
# `^SANITY: PASS` grep. With SANITY_IMAGE that grep is pinned to the image under
# test (`^SANITY: PASS image=<image>$`), so a log written by another image's run
# -- the misattribution hazard of a shared build/ -- can never satisfy this
# test. The hex/tohost paths are read at run time (never hardcoded), and a
# missing image fails with a clear message.
function(riscv_xsim_command OUT_VAR)
    set(DOLLAR "$")
    cmake_parse_arguments(X "REQUIRE_SANITY;TRACE_ENV"
        "SNAPSHOT;TEST;LOG;SEED;SKIP_ENV;HEX;TOHOST_FILE;COV_DB_DIR;COV_DB_NAME;SANITY_IMAGE" "" ${ARGN})
    if(X_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "riscv_xsim_command: unknown ${X_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT X_SNAPSHOT OR NOT X_TEST OR NOT X_LOG)
        message(FATAL_ERROR "riscv_xsim_command: SNAPSHOT, TEST and LOG are required")
    endif()
    if(X_SANITY_IMAGE AND NOT X_REQUIRE_SANITY)
        # Without the sanity grep the pin would be silently ignored.
        message(FATAL_ERROR "riscv_xsim_command: SANITY_IMAGE needs REQUIRE_SANITY")
    endif()

    set(CMD "")
    # Private snapshot: one symlink per elaborated file, and the two files xsim
    # writes inside the snapshot directory belong to this run alone. The test
    # runs in its own working directory (riscv_test_run_dir), so `xsim.dir` is
    # relative to it.
    set(SNAP_SRC "${CMAKE_BINARY_DIR}/xsim.dir/${X_SNAPSHOT}")
    string(APPEND CMD
        # A build configured before this rule may still carry the old whole-dir
        # symlink; remove the link (never its target) before building the tree.
        "if [ -L 'xsim.dir' ]; then rm -f 'xsim.dir'; fi; "
        "mkdir -p 'xsim.dir/${X_SNAPSHOT}'; "
        "if [ -d '${SNAP_SRC}' ]; then "
        "for f in '${SNAP_SRC}'/*; do "
        "ln -sfn \"${DOLLAR}f\" \"xsim.dir/${X_SNAPSHOT}/${DOLLAR}(basename \"${DOLLAR}f\")\"; "
        "done; "
        "fi; "
        "rm -f 'xsim.dir/${X_SNAPSHOT}/xsim_script.tcl' 'xsim.dir/${X_SNAPSHOT}/xsimcrash.log'; ")
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
        if(X_SANITY_IMAGE)
            # The verdict line must name the image under test, not just any image.
            string(APPEND CMD " && grep -q '^SANITY: PASS image=${X_SANITY_IMAGE}${DOLLAR}' ${X_LOG}")
        else()
            string(APPEND CMD " && grep -q '^SANITY: PASS' ${X_LOG}")
        endif()
    endif()
    set(${OUT_VAR} "${CMD}" PARENT_SCOPE)
endfunction()

# --- mutant catalogue --------------------------------------------------------
function(riscv_mutant_names OUT_VAR TABLE)
    riscv_tsv_rows(ROWS "${TABLE}")
    set(NAMES "")
    foreach(ROW IN LISTS ROWS)
        riscv_tsv_cell(N "${ROW}" 0)
        # `if(N)` would be false: N is a named false constant (NO), not a value.
        if(NOT N STREQUAL "")
            list(APPEND NAMES "${N}")
        endif()
    endforeach()
    set(${OUT_VAR} "${NAMES}" PARENT_SCOPE)
endfunction()

# The one mutation mechanism: an exact single-occurrence text replacement. It
# knows nothing about RTL, UVM or tests -- a file and two strings. `find` must
# occur exactly once, or the mutant is stale and the gate aborts (a silent 0- or
# 2-replacement would prove nothing). The optional <label> names the caller in
# the log ("mutant" by default): the negative control also uses this to set the
# elaboration thread budget on its disposable tree, and a line that says
# `mutant:` there would be a lie.
function(riscv_patch_once FILE FIND REPLACE_TEXT WHY)
    set(LABEL "mutant")
    if(ARGN)
        list(GET ARGN 0 LABEL)
    endif()
    if(NOT EXISTS "${FILE}")
        message(FATAL_ERROR "${LABEL}: ${FILE} does not exist")
    endif()
    if(FIND STREQUAL "" OR FIND STREQUAL REPLACE_TEXT)
        message(FATAL_ERROR "${LABEL}: empty or no-op find in ${FILE}; the mutant proves nothing")
    endif()
    file(READ "${FILE}" TEXT)
    string(REPLACE "${FIND}" "" STRIPPED "${TEXT}")
    string(LENGTH "${TEXT}" LEN_FULL)
    string(LENGTH "${STRIPPED}" LEN_STRIPPED)
    string(LENGTH "${FIND}" LEN_NEEDLE)
    math(EXPR COUNT "(${LEN_FULL} - ${LEN_STRIPPED}) / ${LEN_NEEDLE}")
    if(NOT COUNT EQUAL 1)
        message(FATAL_ERROR "${LABEL}: '${FIND}' occurs ${COUNT} time(s) in ${FILE}; the mutation is stale")
    endif()
    string(REPLACE "${FIND}" "${REPLACE_TEXT}" MUTATED "${TEXT}")
    file(WRITE "${FILE}" "${MUTATED}")
    message(STATUS "${LABEL}: ${FILE} <- ${WHY}")
endfunction()

# Apply every row of <table> named <name>, in table order, under <tree>.
function(riscv_mutant_apply TREE NAME TABLE)
    riscv_tsv_rows(ROWS "${TABLE}")
    set(INDEX 0)
    set(HITS 0)
    foreach(ROW IN LISTS ROWS)
        math(EXPR INDEX "${INDEX} + 1")
        riscv_tsv_cell(N "${ROW}" 0)
        if(NOT N STREQUAL NAME)
            continue()
        endif()
        riscv_tsv_cell(F "${ROW}" 1)
        riscv_tsv_cell(S "${ROW}" 2)
        riscv_tsv_cell(R "${ROW}" 3)
        riscv_tsv_cell(W "${ROW}" 4)
        if(F STREQUAL "" OR S STREQUAL "" OR W STREQUAL "")
            message(FATAL_ERROR "${TABLE} row ${INDEX} (${NAME}): file, find and why are required")
        endif()
        riscv_patch_once("${TREE}/${F}" "${S}" "${R}" "${W}")
        math(EXPR HITS "${HITS} + 1")
    endforeach()
    if(HITS EQUAL 0)
        message(FATAL_ERROR "mutant '${NAME}' has no row in ${TABLE}")
    endif()
endfunction()
