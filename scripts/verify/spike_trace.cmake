# =============================================================================
# scripts/verify/spike_trace.cmake - the DUT against an external reference.
#
# WP-9 (G-04). Each selected manifest row is executed TWICE -- in the DUT and in
# Spike -- and the two commit traces are compared instruction by instruction.
# The Spike side is the reference: `--log-commits` prints one line per retired
# instruction, so a test that agrees with it agrees with an implementation this
# project did not write. This is an architectural-state comparison, not a cycle
# comparison: the pipeline is invisible here by construction.
#
# One file, two modes, like the other gates:
#
#   configure mode (included by CMakeLists.txt)
#       declares one CTest test per `spike:<image>` row of tests.tsv (label
#       `spike`): the xsim run with +RETIRE_LOG, then Spike, then
#       scripts/verify/spike/normalize.py, then scripts/verify/spike/compare.py.
#       The comparator's exit code decides the test, AND the `^UVM_RESULT: PASS`
#       grep of riscv_xsim_command() must still hold -- a DUT that diverges from
#       Spike but also fails its own checker is not a pass either way;
#
#   run mode (`cmake -P`, reached through `make spike-trace`)
#       builds the snapshot and the images, runs the selection through CTest and
#       publishes build/spike/runs/<stamp>/results.json from the comparator's own
#       JSON, so the evidence says which commit diverged, not just "a test
#       failed".
#
#   cmake -P scripts/verify/spike_trace.cmake
#   cmake -P scripts/verify/spike_trace.cmake --test T-47
#   cmake -P scripts/verify/spike_trace.cmake --jobs 3 --out /tmp/spike-run
#
# --- why the test is declared here and not by regress.cmake -------------------
# A plain tests.tsv row becomes a riscv_xsim_command() test whose only assertion
# is `^UVM_RESULT: PASS`. A `T-47` row declared that way would re-run rv32ui-p-add
# and assert nothing new -- exactly the assertion-free duplication G-11
# criticises. So the trace comparison IS the test: this module declares the name,
# and regress.cmake leaves it free (declaring it twice is a hard CTest error).
# The regression still counts it, because `ctest -LE "^(cov|sanity)$"` does not
# exclude the `spike` label.
#
# --- the cut rule (derived here, implemented in compare.py) -------------------
# Spike does not stop at the `tohost` store: the pass epilogue ends in `j .`, so
# its log carries thousands of identical commits afterwards. Both traces are cut
# at the FIRST commit whose pc is a `<tohost>` store pc, inclusive. Each sanity
# dump carries TWO such stores (the `fail` and the `pass` epilogue) and only the
# pass one executes, so the cut is a SET: the pcs are derived from
# build/sanity_tests/dump/<image>.dump at run time -- every line whose objdump
# COMMENT names <tohost>, not the operand, because st_ld stores through
# `sw gp,144(t5) # 800 <tohost>`. A set that matches nothing fails the test; it
# can never pass an empty comparison. Measured 2026-11-17: add 0x568/0x574,
# beq 0x348/0x354, st_ld 0x774/0x784.
#
# --- what this comparison does NOT prove --------------------------------------
# The canonical line is `<pc> <rd|-> <val|-> <inst>`. A store contributes no
# register write, so its address and data are not in the trace (normalize.py
# drops the `mem` suffix on purpose): a store that writes the wrong bytes to the
# right address with the right register state remains invisible here. That is a
# property of the compared state, not a limitation to be fixed by adding a
# field -- the DUT's own strb checker and the image's software verdict cover it.
# The consequence for the manifest is recorded per row: the red cell is a mutant
# that makes the TRACES diverge, so the comparison itself is what catches it.
# A mutant of the store data path is not detectable here and is not claimed for
# this test (measured, `store-width-cast`: the trace stayed identical 477/477 and
# the test failed on the DUT's own `UVM_RESULT: FAIL`, i.e. on the sanity
# checker's teeth, not on this comparison's).
#
# Spike comes from scripts/verify/spike/build_spike.sh (out of tree, configured
# with --enable-commitlog). This file does not build it: a missing binary fails
# the test with that path in the message, never a pass.
#
# --- the reference is identified, not assumed --------------------------------
# A trace compared against "whatever Spike was installed that day" cannot be
# reproduced from this repository, so the pin is read from build_spike.sh -- the
# one place it lives, parsed at configure time, and a parse failure is a
# FATAL_ERROR naming the file, not a silently weaker guard. Every test then
# asserts identity before it runs Spike: build/spike/version.txt must exist,
# carry `commit=`, and equal that pin. Missing, empty or different -> the TEST
# exits 1 naming build_spike.sh, the same shape as the missing-binary guard, so
# the comparison can never be reported as a pass against an unknown reference.
# results.json records that verified commit and nothing else.
#
# Artefacts: build/spike/runs/<stamp>/results.json + summary.md (per test: the
# compared counts, cut index, cut pc and cut set, and the first divergence).
# Exit codes: 0 every selected trace matched; 1 a divergence, a timeout, a skip
# or missing evidence; 2 usage.
# =============================================================================

set(DOLLAR "$")

# In `cmake -P` mode nothing has set the policy surface (the top-level
# CMakeLists.txt is not read), and IN_LIST would be parsed as a plain
# argument. 3.21 is already the floor common.cmake enforces for
# `ctest --output-junit`; the included build has its own policy version.
if(CMAKE_SCRIPT_MODE_FILE)
    cmake_minimum_required(VERSION 3.21)
endif()

# Manifest rows, JUnit verdicts, the content digest and the one xsim command
# string: the same implementation regress.cmake, coverage.cmake and
# signoff_check.cmake use, in both modes.
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# The reference commit, from its single source of truth. build_spike.sh is the
# only file that pins it: a second copy here is how a pin drifts silently, so it
# is parsed out of that script instead of being repeated.
function(riscv_spike_pinned_commit OUT_VAR SCRIPT)
    if(NOT EXISTS "${SCRIPT}")
        message(FATAL_ERROR "spike: ${SCRIPT} not found: the pinned reference commit cannot be read")
    endif()
    file(READ "${SCRIPT}" SCRIPT_TEXT)
    # Prepend a newline so the match is anchored to a line start and the first
    # line of the file is covered too.
    set(SCRIPT_TEXT "\n${SCRIPT_TEXT}")
    if(NOT SCRIPT_TEXT MATCHES "\nSPIKE_COMMIT=\"([0-9a-f]+)\"")
        message(FATAL_ERROR "spike: ${SCRIPT} has no SPIKE_COMMIT=\"<sha>\" assignment: the pinned reference commit cannot be read")
    endif()
    set(PIN "${CMAKE_MATCH_1}")
    string(LENGTH "${PIN}" PIN_LEN)
    if(NOT PIN_LEN EQUAL 40)
        message(FATAL_ERROR "spike: ${SCRIPT} pins SPIKE_COMMIT=\"${PIN}\", which is not a 40-hex commit")
    endif()
    set(${OUT_VAR} "${PIN}" PARENT_SCOPE)
endfunction()

# =============================================================================
# Configure mode: declare one CTest test per `spike:<image>` row.
# =============================================================================
if(NOT CMAKE_SCRIPT_MODE_FILE)
    if(NOT SEED)
        set(SEED 1)
    endif()

    # The Spike invocation, kept in sync with scripts/verify/spike/build_spike.sh:
    # 256 KiB at address 0 (below the CLINT), debug module and DTB ROM off, RV32I
    # only. -m0:0x40000 is the same window as the testbench's memory model.
    set(RISCV_SPIKE_BIN "${CMAKE_BINARY_DIR}/spike/install/bin/spike")
    set(RISCV_SPIKE_FLAGS "--no-dm --disable-dtb -m0:0x40000 --isa=rv32i")

    # The identity each test asserts: the pin, parsed from build_spike.sh (never
    # copied here), and the file the build records it in.
    riscv_spike_pinned_commit(SPIKE_COMMIT_PIN "${CMAKE_SOURCE_DIR}/scripts/verify/spike/build_spike.sh")
    set(RISCV_SPIKE_VERSION "${CMAKE_BINARY_DIR}/spike/version.txt")

    # The cut set: the pcs of every instruction whose objdump comment names
    # <tohost>. A bracket argument so the awk program is literal (`$1`, `#` and
    # the quotes are for awk, not for CMake).
    set(RISCV_TOHOST_AWK [=[/^[[:space:]]*[0-9a-f]+:.*#[^#]*<tohost>[[:space:]]*$/ { pc = $1; gsub(/:/, "", pc); printf "%s0x%s", sep, pc; sep = "," }]=])

    set(RISCV_SPIKE_SCRIPTS "${CMAKE_SOURCE_DIR}/scripts/verify/spike")
    set(RISCV_SANITY_DIR "${CMAKE_BINARY_DIR}/sanity_tests")
    set(SPIKE_LOG_DIR "${CMAKE_BINARY_DIR}/regress")
    file(MAKE_DIRECTORY "${SPIKE_LOG_DIR}")

    # One command string per test: the DUT simulation with the commit dump on,
    # then the reference and the comparison, every step appending to the same
    # log the regression copies into its evidence. Two things are deliberate:
    #
    #   * the comparison runs even when the DUT's own verdict failed. The xsim
    #     command ends in `&& grep ^UVM_RESULT: PASS`, and chaining the
    #     comparator behind it would short-circuit exactly when a mutant makes
    #     the image report a failure -- the run would then never say whether the
    #     TRACES diverged, which is the only thing this test is for. The xsim
    #     status is captured instead and both verdicts must hold at the end.
    #   * `set -o pipefail` makes `python3 compare.py ... | tee -a log` return
    #     the comparator's status instead of tee's -- without it a divergence
    #     would look like a success.
    function(riscv_spike_trace_command OUT_VAR TID IMAGE TEST_CLASS TEST_LOG RETIRE_LOG RUN_DIR)
        set(D "$")
        set(XSIM_CMD "")
        riscv_xsim_command(XSIM_CMD SNAPSHOT top_sim TEST "${TEST_CLASS}"
            LOG "${TEST_LOG}" SEED "${SEED}"
            HEX "${RISCV_SANITY_DIR}/hex/${IMAGE}.hex"
            TOHOST_FILE "${RISCV_SANITY_DIR}/tohost/${IMAGE}"
            REQUIRE_SANITY SANITY_IMAGE "${IMAGE}"
            PLUSARGS --testplusarg "RETIRE_LOG=${RETIRE_LOG}")

        # `$?` must be read BEFORE `set -o pipefail`: the `set` builtin itself
        # succeeds, so a capture placed after it always sees 0 and the DUT's
        # own verdict would be silently ignored (measured: a mutant with 31
        # UVM_ERRORs passed the trace test).
        set(TAIL " ; { XSIM_RC=${D}?; set -o pipefail; ")
        string(APPEND TAIL
            "test -x '${RISCV_SPIKE_BIN}' || { echo \"spike: missing ${RISCV_SPIKE_BIN}: run scripts/verify/spike/build_spike.sh\" | tee -a '${TEST_LOG}'; exit 1; }; "
            # Identity, not presence: a trace compared against an unidentified
            # Spike is not evidence, so this fails the TEST before Spike runs.
            "VERSION_FILE='${RISCV_SPIKE_VERSION}'; "
            "test -f \"${D}VERSION_FILE\" || { echo 'spike: missing build/spike/version.txt: the reference cannot be identified -- run scripts/verify/spike/build_spike.sh' | tee -a '${TEST_LOG}'; exit 1; }; "
            "BUILT_COMMIT=${D}(sed -n 's/^commit=//p' \"${D}VERSION_FILE\" | head -1); "
            "test -n \"${D}BUILT_COMMIT\" || { echo 'spike: build/spike/version.txt records no commit= line: the reference cannot be identified -- run scripts/verify/spike/build_spike.sh' | tee -a '${TEST_LOG}'; exit 1; }; "
            "test \"${D}BUILT_COMMIT\" = '${SPIKE_COMMIT_PIN}' || { echo \"spike: build/spike/version.txt records commit=${D}BUILT_COMMIT, expected ${SPIKE_COMMIT_PIN} -- run scripts/verify/spike/build_spike.sh\" | tee -a '${TEST_LOG}'; exit 1; }; "
            "test -f '${RISCV_SANITY_DIR}/isa/${IMAGE}' || { echo 'spike: missing ELF build/sanity_tests/isa/${IMAGE}: build the compile_sanity_${IMAGE} target' | tee -a '${TEST_LOG}'; exit 1; }; "
            "test -f '${RISCV_SANITY_DIR}/dump/${IMAGE}.dump' || { echo 'spike: missing dump build/sanity_tests/dump/${IMAGE}.dump: build the compile_sanity_${IMAGE} target' | tee -a '${TEST_LOG}'; exit 1; }; "
            # The cut set is data derived from the ELF, so it is derived at run
            # time: a configure on a fresh tree has no dump yet.
            "CUTPCS=${D}(awk '${RISCV_TOHOST_AWK}' '${RISCV_SANITY_DIR}/dump/${IMAGE}.dump'); "
            "test -n \"${D}CUTPCS\" || { echo 'spike: build/sanity_tests/dump/${IMAGE}.dump names no <tohost> store: no cut set, no comparison' | tee -a '${TEST_LOG}'; exit 1; }; "
            "echo \"SPIKE: ${TID} image=${IMAGE} cut-pcs=${D}CUTPCS dut=${RETIRE_LOG}\" | tee -a '${TEST_LOG}'; "
            "'${RISCV_SPIKE_BIN}' ${RISCV_SPIKE_FLAGS} --log=spike.log --log-commits '${RISCV_SANITY_DIR}/isa/${IMAGE}' 2>&1 | tee -a '${TEST_LOG}' "
            "&& python3 '${RISCV_SPIKE_SCRIPTS}/normalize.py' spike-log spike.log spike.trace 2>&1 | tee -a '${TEST_LOG}' "
            # The digests travel in the environment, so a plain `ctest -R T-47`
            # still runs and the gate's evidence names the tree it measured.
            "&& python3 '${RISCV_SPIKE_SCRIPTS}/compare.py' --dut '${RETIRE_LOG}' --spike spike.trace "
            "--cut-pcs \"${D}CUTPCS\" --out '${RUN_DIR}/spike-results.json' "
            "--rtl-digest \"${D}{SPIKE_RTL_DIGEST:-}\" --tb-digest \"${D}{SPIKE_TB_DIGEST:-}\" "
            "--spike-commit \"${D}BUILT_COMMIT\" 2>&1 | tee -a '${TEST_LOG}'; "
            "CMP_RC=${D}?; "
            "echo \"SPIKE: ${TID} xsim_rc=${D}XSIM_RC compare_rc=${D}CMP_RC\" | tee -a '${TEST_LOG}'; "
            "test ${D}XSIM_RC -eq 0 && test ${D}CMP_RC -eq 0; }")
        set(${OUT_VAR} "${XSIM_CMD}${TAIL}" PARENT_SCOPE)
    endfunction()

    riscv_manifest_rows(ROWS "${CMAKE_SOURCE_DIR}/scripts/verify/tests.tsv")
    set(SPIKE_TESTS "")
    set(SPIKE_IMAGES "")
    foreach(ROW IN LISTS ROWS)
        riscv_manifest_spike_image(IMAGE "${ROW}")
        if(IMAGE STREQUAL "")
            continue()
        endif()
        string(REPLACE "|" ";" FIELDS "${ROW}")
        list(GET FIELDS 0 TID)
        list(GET FIELDS 1 TEST_CLASS)
        list(GET FIELDS 2 TEST_WP)
        list(GET FIELDS 3 TEST_FRS)
        list(GET FIELDS 4 TEST_TIMEOUT)

        # The DUT trace: the monitor's canonical dump (+RETIRE_LOG, WP-9 P2).
        # It lives in the test's private run directory, next to the Spike log
        # and the comparator's JSON, so `ctest -j` cannot cross two tests.
        riscv_test_run_dir(RUN_DIR "${TID}")
        set(RETIRE_LOG "${RUN_DIR}/retire.log")
        set(TEST_LOG "${SPIKE_LOG_DIR}/${TID}.log")
        riscv_spike_trace_command(TEST_CMD "${TID}" "${IMAGE}" "${TEST_CLASS}"
            "${TEST_LOG}" "${RETIRE_LOG}" "${RUN_DIR}")

        add_test(NAME ${TID} COMMAND bash -c "${TEST_CMD}"
            WORKING_DIRECTORY "${RUN_DIR}")
        # Labels are the selection keys and the class carrier, exactly as in
        # regress.cmake; `spike` is what `make spike-trace` selects, and what
        # regress's `-LE "^(cov|sanity)$"` deliberately does not exclude.
        string(REPLACE "," ";" TEST_LABELS "${TEST_FRS}")
        list(APPEND TEST_LABELS "${TID}" "wp${TEST_WP}" "class:${TEST_CLASS}" "spike")
        set_tests_properties(${TID} PROPERTIES
            TIMEOUT ${TEST_TIMEOUT}
            LABELS "${TEST_LABELS}")
        list(APPEND SPIKE_TESTS "${TID}")
        list(APPEND SPIKE_IMAGES "${IMAGE}")
    endforeach()
    list(REMOVE_DUPLICATES SPIKE_IMAGES)

    if(NOT SPIKE_TESTS)
        # Nothing to run is stated, never silently accepted: the gate target
        # below would then pass without comparing anything.
        message(STATUS "Spike trace: no manifest row carries a `spike:<image>` column")
        add_custom_target(spike-trace
            COMMAND ${CMAKE_COMMAND} -E echo "spike-trace: no `spike:<image>` row in scripts/verify/tests.tsv"
            COMMAND ${CMAKE_COMMAND} -E false
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            COMMENT "Spike trace comparison (no test selected)..."
            USES_TERMINAL
        )
        return()
    endif()

    # The images are build artefacts of the sanity module; the snapshot belongs
    # to the build system. This target asks for both, so `make spike-trace`
    # never simulates an image or a snapshot that was never produced.
    set(SPIKE_DEPENDS elaborate)
    foreach(IMAGE IN LISTS SPIKE_IMAGES)
        list(APPEND SPIKE_DEPENDS "compile_sanity_${IMAGE}")
    endforeach()

    add_custom_target(spike-trace
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE}
                --jobs ${DOLLAR}${DOLLAR}{VERIFY_JOBS:-${VERIFY_JOBS}} $(SPIKE_TRACE_ARGS)
        DEPENDS ${SPIKE_DEPENDS}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Comparing the DUT's commit trace against Spike (WP-9)..."
        USES_TERMINAL
    )
    message(STATUS "Spike trace tests (CTest label 'spike'): ${SPIKE_TESTS}")
    return()
endif()

# =============================================================================
# Run mode: build, run the selection, publish the comparator's verdict.
# =============================================================================
get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(MANIFEST "${ROOT}/scripts/verify/tests.tsv")

# --- arguments ---------------------------------------------------------------
set(ARGS "")
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        string(REGEX REPLACE "^--" "" ARG "${CMAKE_ARGV${I}}")
        list(APPEND ARGS "${ARG}")
    endforeach()
endif()
cmake_parse_arguments(S "list" "out;jobs" "test" ${ARGS})
if(S_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "unknown option(s): ${S_UNPARSED_ARGUMENTS}")
endif()

riscv_parallel_jobs(JOBS "${S_jobs}")

set(SEED "$ENV{SEED}")
if(NOT SEED)
    set(SEED 1)
endif()
if(NOT SEED MATCHES "^[0-9]+$")
    message(FATAL_ERROR "--seed must be an unsigned integer, got '${SEED}'")
endif()

# --- selection: the `spike` label, restricted by --test ----------------------
riscv_manifest_rows(ROWS "${MANIFEST}")
set(ALL_TESTS "")
set(ROW_IMAGES "")
foreach(ROW IN LISTS ROWS)
    riscv_manifest_spike_image(IMAGE "${ROW}")
    if(IMAGE STREQUAL "")
        continue()
    endif()
    riscv_tsv_cell(TID "${ROW}" 0)
    list(APPEND ALL_TESTS "${TID}")
    list(APPEND ROW_IMAGES "${TID}|${IMAGE}")
endforeach()

set(SELECTED "")
if(S_test)
    foreach(TID IN LISTS S_test)
        if(NOT TID IN_LIST ALL_TESTS)
            message(FATAL_ERROR "${TID} is not a `spike:<image>` row of ${MANIFEST}")
        endif()
        list(APPEND SELECTED "${TID}")
    endforeach()
else()
    set(SELECTED ${ALL_TESTS})
endif()

if(NOT SELECTED)
    message(FATAL_ERROR "no `spike:<image>` row in ${MANIFEST}: there is no trace to compare")
endif()

set(CTEST_SELECT -L "^spike$")
list(JOIN SELECTED "|" PATTERN)
list(APPEND CTEST_SELECT -R "^(${PATTERN})$")

# --- chain: ./configure -> elaborate + the images of the selection -----------
set(SPIKE_LOG_DIR "${BUILD}/regress")
file(MAKE_DIRECTORY "${SPIKE_LOG_DIR}")
riscv_bootstrap_build("${SPIKE_LOG_DIR}/configure.log")

if(S_list)
    execute_process(COMMAND ${CMAKE_CTEST_COMMAND} -N ${CTEST_SELECT}
        WORKING_DIRECTORY "${BUILD}" RESULT_VARIABLE RC)
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "ctest -N failed")
    endif()
    return()
endif()

# The image targets come from the same selected-rows collector the regression
# uses, so `--test T-47` builds rv32ui-p-add and nothing else.
set(BUILD_TARGETS elaborate)
riscv_manifest_sanity_targets(IMAGE_TARGETS "${MANIFEST}" TESTS ${SELECTED})
list(APPEND BUILD_TARGETS ${IMAGE_TARGETS})
list(REMOVE_DUPLICATES BUILD_TARGETS)
message(STATUS "building ${BUILD_TARGETS} through the build system")
execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${BUILD}" --target ${BUILD_TARGETS}
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE RC
    OUTPUT_FILE "${BUILD}/spike/build.log"
    ERROR_FILE "${BUILD}/spike/build.log")
if(NOT RC EQUAL 0)
    message(FATAL_ERROR "elaboration/image build failed (is the EDA environment sourced?); see build/spike/build.log")
endif()

# --- run directory and digests -----------------------------------------------
set(OUT "${S_out}")
if(NOT OUT)
    string(TIMESTAMP STAMP "%Y-%m-%dT%H-%M-%SZ" UTC)
    set(OUT "${BUILD}/spike/runs/${STAMP}")
endif()
file(MAKE_DIRECTORY "${OUT}")
file(RELATIVE_PATH OUT_REL "${ROOT}" "${OUT}")

riscv_tree_digests(RTL_DIGEST TB_DIGEST "${ROOT}")

# The recorded commit is the verified one or nothing: results.json may not name
# a reference this run could not identify. A mismatch is fatal here, not a
# warning: the commit baked into the CTest command was parsed at configure time,
# so editing SPIKE_COMMIT without re-running ./configure leaves the tests
# asserting the old pin against a newly built binary -- they would pass against
# the wrong reference and this file would publish "spike_commit": "". A gate may
# fail, it may not pass with an unidentified reference.
riscv_spike_pinned_commit(SPIKE_COMMIT_PIN "${ROOT}/scripts/verify/spike/build_spike.sh")
set(SPIKE_COMMIT "")
set(RECORDED_COMMIT "")
if(EXISTS "${BUILD}/spike/version.txt")
    file(READ "${BUILD}/spike/version.txt" VERSION_TEXT)
    if(VERSION_TEXT MATCHES "commit=([0-9a-f]+)")
        set(RECORDED_COMMIT "${CMAKE_MATCH_1}")
    endif()
endif()
if(RECORDED_COMMIT STREQUAL SPIKE_COMMIT_PIN)
    set(SPIKE_COMMIT "${RECORDED_COMMIT}")
elseif(RECORDED_COMMIT STREQUAL "")
    message(FATAL_ERROR "spike: build/spike/version.txt names no commit=, so the reference cannot be identified: run scripts/verify/spike/build_spike.sh and re-run ./configure (the CTest command baked the pin at configure time)")
else()
    message(FATAL_ERROR "spike: build/spike/version.txt records commit=${RECORDED_COMMIT}, but this build's tests assert ${SPIKE_COMMIT_PIN}: the reference is not the pinned one -- run scripts/verify/spike/build_spike.sh, then re-run ./configure so the CTest command and results.json name the same commit")
endif()

# Evidence is regenerated, never reused: a comparator JSON from an earlier run
# must not stand in for a test this run never executed.
foreach(TID IN LISTS SELECTED)
    file(REMOVE "${BUILD}/runs/${TID}/spike-results.json")
endforeach()

string(TIMESTAMP STARTED "%Y-%m-%dT%H:%M:%SZ" UTC)

# --- run: one ctest invocation, verdict from the JUnit report ----------------
message(STATUS "running ${SELECTED} through ctest (label 'spike')")
riscv_ctest_run("${OUT}/junit.xml" "${BUILD}"
    LOG "${OUT}/ctest.log"
    JOBS "${JOBS}"
    ENV "SEED=${SEED}" "SPIKE_RTL_DIGEST=${RTL_DIGEST}" "SPIKE_TB_DIGEST=${TB_DIGEST}"
    SELECT ${CTEST_SELECT})

if(NOT EXISTS "${OUT}/junit.xml")
    message(FATAL_ERROR "ctest produced no JUnit report; see ${OUT_REL}/ctest.log")
endif()
riscv_junit_rows(JUNIT_ROWS "${OUT}/junit.xml")
if(NOT JUNIT_ROWS)
    message(FATAL_ERROR "no trace test matched the selection; see ${OUT_REL}/ctest.log")
endif()

# --- judge: the JUnit verdict AND the comparator's own JSON ------------------
# CTest says whether the command succeeded; the comparator's JSON says what it
# compared. Both are required: a test that passed without a comparison observed
# nothing, and a stale JSON cannot outlive a failure because it was removed
# above.
set(N_PASS 0)
set(N_FAIL 0)
set(N_TIMEOUT 0)
set(TEST_ROWS "")
set(PROBLEMS "")

foreach(ROW IN LISTS JUNIT_ROWS)
    string(REPLACE "|" ";" FIELDS "${ROW}")
    list(GET FIELDS 0 TID)
    list(GET FIELDS 1 STATUS)

    set(IMAGE "")
    foreach(PAIR IN LISTS ROW_IMAGES)
        string(REPLACE "|" ";" CELL "${PAIR}")
        list(GET CELL 0 ID)
        if(ID STREQUAL TID)
            list(GET CELL 1 IMAGE)
        endif()
    endforeach()

    set(COMPARE_JSON "${BUILD}/runs/${TID}/spike-results.json")
    set(COMPARE_STATUS "")
    set(COMPARE_REASON "")
    set(DUT_COUNT 0)
    set(SPIKE_COUNT 0)
    set(CUT_INDEX "-")
    set(CUT_PC "-")
    set(CUT_PCS "-")
    set(DIVERGENCE "")
    if(EXISTS "${COMPARE_JSON}")
        file(READ "${COMPARE_JSON}" JSON)
        if(JSON MATCHES "\"status\": \"([^\"]*)\"")
            set(COMPARE_STATUS "${CMAKE_MATCH_1}")
        endif()
        if(JSON MATCHES "\"reason\": \"([^\"]*)\"")
            set(COMPARE_REASON "${CMAKE_MATCH_1}")
        endif()
        if(JSON MATCHES "\"dut_count\": ([0-9]+)")
            set(DUT_COUNT "${CMAKE_MATCH_1}")
        endif()
        if(JSON MATCHES "\"spike_count\": ([0-9]+)")
            set(SPIKE_COUNT "${CMAKE_MATCH_1}")
        endif()
        if(JSON MATCHES "\"cut_index\": ([0-9]+)")
            set(CUT_INDEX "${CMAKE_MATCH_1}")
        endif()
        if(JSON MATCHES "\"cut_pc\": \"([^\"]*)\"")
            set(CUT_PC "${CMAKE_MATCH_1}")
        endif()
        # The cut set is a JSON list under its own key; read it from there, not
        # from a loose hex scan of the whole file.
        if(JSON MATCHES "\"cut_pcs\": \\[([^]]*)\\]")
            string(REPLACE "\"" "" CUT_TEXT "${CMAKE_MATCH_1}")
            string(REGEX REPLACE "[ \n\r]+" "" CUT_TEXT "${CUT_TEXT}")
            set(CUT_PCS "${CUT_TEXT}")
        endif()
        if(JSON MATCHES "\"index\": ([0-9]+)")
            set(DIVERGENCE " at commit ${CMAKE_MATCH_1}")
        endif()
    endif()

    # A skip is missing evidence, not a pass (the same rule the regression uses).
    if(STATUS STREQUAL "skip")
        set(STATUS "fail")
    endif()
    if(STATUS STREQUAL "pass" AND NOT COMPARE_STATUS STREQUAL "pass")
        set(STATUS "fail")
        list(APPEND PROBLEMS "${TID}(passed without a comparison; ${COMPARE_JSON} is missing or not a pass)")
    endif()
    if(STATUS STREQUAL "pass" AND DUT_COUNT EQUAL 0)
        set(STATUS "fail")
        list(APPEND PROBLEMS "${TID}(compared zero commits: an empty trace proves nothing)")
    endif()
    if(STATUS STREQUAL "fail")
        math(EXPR N_FAIL "${N_FAIL} + 1")
        if(COMPARE_REASON STREQUAL "")
            list(APPEND PROBLEMS "${TID}(failed; see build/regress/${TID}.log)")
        else()
            list(APPEND PROBLEMS "${TID}(${COMPARE_REASON}${DIVERGENCE}; see build/regress/${TID}.log)")
        endif()
    elseif(STATUS STREQUAL "timeout")
        math(EXPR N_TIMEOUT "${N_TIMEOUT} + 1")
        list(APPEND PROBLEMS "${TID}(timeout: the DUT or Spike never reached the cut pc)")
    elseif(STATUS STREQUAL "pass")
        math(EXPR N_PASS "${N_PASS} + 1")
        message(STATUS "  ${TID} pass compared=${DUT_COUNT}/${SPIKE_COUNT} cut_index=${CUT_INDEX} cut_pc=${CUT_PC} cut_pcs=[${CUT_PCS}]")
    else()
        math(EXPR N_FAIL "${N_FAIL} + 1")
        list(APPEND PROBLEMS "${TID}(${STATUS})")
    endif()

    list(APPEND TEST_ROWS "    { \"id\": \"${TID}\", \"image\": \"${IMAGE}\", \"status\": \"${STATUS}\", \"compare\": \"${COMPARE_STATUS}\", \"reason\": \"${COMPARE_REASON}\", \"dut_count\": ${DUT_COUNT}, \"spike_count\": ${SPIKE_COUNT}, \"cut_index\": \"${CUT_INDEX}\", \"cut_pc\": \"${CUT_PC}\", \"cut_pcs\": \"${CUT_PCS}\", \"log\": \"build/regress/${TID}.log\" }")
endforeach()

string(TIMESTAMP FINISHED "%Y-%m-%dT%H:%M:%SZ" UTC)
string(REPLACE ";" ",\n" TESTS_JSON "${TEST_ROWS}")

file(WRITE "${OUT}/results.json" "{
  \"kind\": \"spike-trace\",
  \"record\": \"green\",
  \"runner\": \"ctest\",
  \"spike_commit\": \"${SPIKE_COMMIT}\",
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

file(WRITE "${OUT}/summary.md" "# Spike trace comparison ${STARTED}

| Field | Value |
|---|---|
| Runner | ctest (label `spike`) |
| Seed | ${SEED} |
| Spike commit | `${SPIKE_COMMIT}` |
| RTL digest | `${RTL_DIGEST}` |
| TB digest | `${TB_DIGEST}` |
| Result | ${N_PASS} pass, ${N_FAIL} fail, ${N_TIMEOUT} timeout |
")

message(STATUS "results: ${OUT_REL}/results.json")
message(STATUS "digest:  RTL ${RTL_DIGEST} TB ${TB_DIGEST}")
message("SPIKE-TRACE pass=${N_PASS} fail=${N_FAIL} timeout=${N_TIMEOUT}")

if(N_FAIL GREATER 0 OR N_TIMEOUT GREATER 0)
    list(JOIN PROBLEMS "; " TEXT)
    message(FATAL_ERROR "spike trace comparison failed: ${TEXT}")
endif()
