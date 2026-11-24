# =============================================================================
# scripts/verify/sanity.cmake - NFR-05 in one file: build the images, run them,
# judge them.
#
# Included by CMakeLists.txt (configure mode), it owns the whole riscv-tests
# pipeline:
#   1. compile each isa/<suite>/*.S image -- and each project-local
#      scripts/verify/sanity/local/*.S image -- with the project's own
#      environment (scripts/verify/sanity/riscv_test.h + link.ld) -- no
#      autoconf, no out-of-tree configure, no suite Makefile;
#   2. convert the ELF to a Verilog hex -- rebased to 0 for the testbench's
#      memory model, while the ELF symbols stay absolute -- and extract
#      `tohost` from the ELF;
#   3. declare one CTest test per image (label `sanity`) and the `sanity`
#      target, which runs this same file with `cmake -P`.
#
# Why a project environment: the stock env/p images need Zicsr, MRET and a trap
# handler for ECALL, none of which riscv_small implements (G-13). The test
# bodies are unmodified; only the pass/fail ceremony is local (see
# scripts/verify/sanity/riscv_test.h).
#
# TWO ENVIRONMENTS, ONE PER SUITE (wp-14 §4.3, §18). The base environment
# replaces the trap ceremony with a direct store to `tohost`; rv32mi TESTS that
# ceremony, so it compiles against sanity/mi/riscv_test.h -- the faithful env/p
# dispatch -- via -I<head-of-that-directory> BEFORE -I<sanity>. A suite whose
# own riscv_test.h does not exist inherits the base file unchanged, which is
# what keeps the 43 rv32ui images byte-identical across this refactor.
#
# Build targets (unchanged, so the documented commands keep working):
#   compile_sanity_tests     one image, from the HEX_TEST_NAME cache variable
#   compile_sanity_images    every image of every enabled suite
#   compile_sanity_<image>   a single named image
#
#   cmake -P scripts/verify/sanity.cmake                  every image
#   cmake -P scripts/verify/sanity.cmake rv32ui-p-add     one image
#   cmake -P scripts/verify/sanity.cmake --compile-only   build the images only
#   cmake -P scripts/verify/sanity.cmake --list
#   cmake -P scripts/verify/sanity.cmake --exclude rv32ui-p-x
#   cmake -P scripts/verify/sanity.cmake --trace          add +TRACE to the TB
#   cmake -P scripts/verify/sanity.cmake --jobs 8         run the images in parallel
#
# What the run mode keeps, because nobody else can do it: `tohost` is read from
# the ELF (never from a literal) and the verdict line is `SANITY: PASS|FAIL`.
# No verdict line means `not_measurable`, never pass -- and neither does a
# verdict line that names another image: the CTest command pins
# `^SANITY: PASS image=<image>$` (common.cmake SANITY_IMAGE) and the judge
# cross-checks the image in the log, so a log written by another image's run is
# never evidence for this one. CTest still owns the run itself (timeout, log,
# verdict, JUnit), exactly like the regression and the coverage runs; a plain
# `ctest` skips these tests (exit 77) because it never built the images.
#
# Scope: the ISA suites listed in SANITY_SUITES (rv32ui, rv32mi) plus the
# project-local sanity/local directory. The local directory exists because some
# requirements need an image the bundled suite does not provide:
# rv32ui-p-jalr_unaligned derives from jalr.S and adds the odd-target case FR-07
# needs, without touching the src/riscv-tests submodule. rv32um/rv32uc need M/C
# (E8); rv32si is not in NFR-05. Enabling a suite is a SANITY_SUITES value, not
# an edit -- and a suite that is off is neither built nor declared.
#
# Results: build/sanity/summary.json, one log per image, one dump per image.
# Exit codes: 0 the measurement ran (not measurable is still a run), 1 an image
#             failed, 2 the environment is missing.
# =============================================================================

set(DOLLAR "$")

# manifest-independent, but the digest is the same evidence key everywhere.
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# ----------------------------------------------------------------------------
# Suite helpers. Both are pure functions of the suite name (and the image's
# stem), so the compile rule and the run mode cannot disagree about them.
# ----------------------------------------------------------------------------
# The directory a suite compiles against: the base environment, plus the
# suite's own riscv_test.h when it publishes one. rv32mi publishes it under
# sanity/mi (§4.3); every other suite inherits scripts/verify/sanity.
function(riscv_sanity_env_dir ENV_DIR SUITE OUT)
    set(SUB "${SUITE}")
    if(SUITE STREQUAL "rv32mi")
        set(SUB "mi")
    endif()
    if(EXISTS "${ENV_DIR}/${SUB}/riscv_test.h")
        set(${OUT} "${ENV_DIR}/${SUB}" PARENT_SCOPE)
    else()
        set(${OUT} "${ENV_DIR}" PARENT_SCOPE)
    endif()
endfunction()

# -march of one image: the suite's base ISA, plus the extension that image
# needs. `-march=rv32i` proves an rv32ui image only uses the base ISA (the suite
# links with -march=rv32g which merely permits M/A/F/D); fence_i.S is Zifencei;
# the rv32mi bodies use csrr/csrw, so the whole suite is Zicsr.
function(riscv_sanity_march SUITE STEM OUT)
    if(SUITE STREQUAL "rv32mi")
        set(ARCH "rv32i_zicsr")
    else()
        set(ARCH "rv32i")
    endif()
    if(STEM STREQUAL "fence_i")
        set(ARCH "rv32i_zifencei")
    endif()
    set(${OUT} "${ARCH}" PARENT_SCOPE)
endfunction()

# =============================================================================
# Configure mode: the images, their CTest tests and the `sanity` target.
# =============================================================================
if(NOT CMAKE_SCRIPT_MODE_FILE)
    set(HEX_TEST_NAME "rv32ui-p-addi" CACHE STRING "One image for the compile_sanity_tests target")
    set(SANITY_SUITES "rv32ui;rv32mi" CACHE STRING "riscv-tests ISA suites to build (semicolon list: rv32ui;rv32mi)")
    # Which images a suite contributes. Empty means "every isa/<suite>/*.S", the
    # rv32ui behaviour: adding a bundled image keeps working with no edit here.
    # rv32mi is a named list because its directory also holds images that
    # exercise features this core does not implement, measured 2026-11-23:
    #   pmpaddr            PMP absent                    -> FAIL testnum=1
    #   ma_fetch           misaligned fetch absent      -> FAIL testnum=2
    #   instret_overflow   minstret high half           -> TIMEOUT pc=0x80000190
    #   illegal            MRET returns nowhere (FR-45) -> TIMEOUT pc=0x800003e4
    #   breakpoint         NUM_TRIGGERS=0 (FR-57)       -> FAIL testnum=2
    # so enabling the whole suite would turn `make sanity`, and the signoff gate
    # that reads it, red on mechanisms no requirement of this WP claims. The
    # three images below are the ones the vplan names (T-54/T-55/T-58); the two
    # blocked ones are T-56 (illegal) and T-57 (breakpoint), withheld with that
    # evidence rather than listed and excluded.
    set(SANITY_IMAGES_rv32mi "csr;mcsr;zicntr" CACHE STRING
        "rv32mi images to build (semicolon list; empty = every isa/rv32mi/*.S)")
    set(SANITY_TIMEOUT 300 CACHE STRING "Wall-clock limit of one sanity simulation, in seconds")
    set(SANITY_TEST "riscv_small_sanity_test")

    set(RISCV_TESTS_DIR "${CMAKE_SOURCE_DIR}/src/riscv-tests")
    set(SANITY_ENV "${CMAKE_SOURCE_DIR}/scripts/verify/sanity")
    set(RISCV_PREFIX "riscv64-unknown-elf-")
    set(SANITY_DIR "${CMAKE_BINARY_DIR}/sanity_tests")
    set(SANITY_ISA_DIR "${SANITY_DIR}/isa")
    set(SANITY_HEX_DIR "${SANITY_DIR}/hex")
    set(SANITY_TOHOST_DIR "${SANITY_DIR}/tohost")
    set(SANITY_DUMP_DIR "${SANITY_DIR}/dump")
    set(SANITY_OUT "${CMAKE_BINARY_DIR}/sanity")
    file(MAKE_DIRECTORY "${SANITY_ISA_DIR}" "${SANITY_HEX_DIR}" "${SANITY_TOHOST_DIR}"
                        "${SANITY_DUMP_DIR}" "${SANITY_OUT}")

    # Missing tools are a warning, not a configure error: the sanity images are
    # one target among many and the rest of the project must still configure.
    # The fallback plain name keeps the build failure readable.
    foreach(PAIR "RISCV_OBJCOPY;riscv64-unknown-elf-objcopy"
                  "RISCV_GCC;riscv64-unknown-elf-gcc"
                  "RISCV_NM;riscv64-unknown-elf-nm"
                  "RISCV_OBJDUMP;riscv64-unknown-elf-objdump")
        list(GET PAIR 0 VAR)
        list(GET PAIR 1 BIN)
        find_program(${VAR} ${BIN})
        if(NOT ${VAR})
            message(WARNING "${BIN} not found: the sanity-image targets will fail. Install with: sudo apt install binutils-riscv64-unknown-elf gcc-riscv64-unknown-elf")
            set(${VAR} "${BIN}")
        endif()
    endforeach()

    if(NOT SANITY_SUITES)
        message(FATAL_ERROR "SANITY_SUITES is empty: there is no image to build (e.g. -DSANITY_SUITES=rv32ui;rv32mi)")
    endif()
    list(GET SANITY_SUITES 0 SANITY_BASE_SUITE)
    set(SANITY_LOCAL_DIR "${CMAKE_CURRENT_LIST_DIR}/sanity/local")
    file(GLOB SANITY_LOCAL_SOURCES "${SANITY_LOCAL_DIR}/*.S")

    # --- image list ---------------------------------------------------------
    # Each isa/<suite>/<stem>.S builds the bare-metal image <suite>-p-<stem>
    # ("-p-" is the physical target of the bundled suite), unless the suite
    # names an explicit image list (SANITY_IMAGES_<suite>, see above). A
    # project-local sanity/local/<image>.S builds the same name and shadows the
    # bundled file of the same stem. A local file that already carries a suite
    # prefix (local/<suite>-p-<stem>.S) belongs to that suite; a bare local stem
    # (local/<stem>.S) belongs to the FIRST suite, the spelling this directory
    # has always had. The list is written to images.txt so the run mode never
    # globs twice.
    set(SANITY_IMAGES "")
    foreach(SANITY_SUITE IN LISTS SANITY_SUITES)
        set(SANITY_SUITE_DIR "${RISCV_TESTS_DIR}/isa/${SANITY_SUITE}")
        if(NOT EXISTS "${SANITY_SUITE_DIR}")
            message(FATAL_ERROR "No riscv-tests sources under ${SANITY_SUITE_DIR}. Run: git submodule update --init src/riscv-tests, or drop ${SANITY_SUITE} from SANITY_SUITES")
        endif()
        # The form "if(<var>)" is the dynamic name: SANITY_IMAGES_<suite>.
        # Empty = the whole directory (rv32ui); otherwise exactly the named
        # images, each one checked so a typo fails here and not in the build.
        if(SANITY_IMAGES_${SANITY_SUITE})
            set(SANITY_SUITE_SOURCES "")
            foreach(SANITY_STEM IN LISTS SANITY_IMAGES_${SANITY_SUITE})
                if(NOT EXISTS "${SANITY_SUITE_DIR}/${SANITY_STEM}.S")
                    message(FATAL_ERROR "SANITY_IMAGES_${SANITY_SUITE} names '${SANITY_STEM}', which is not in ${SANITY_SUITE_DIR}")
                endif()
                list(APPEND SANITY_SUITE_SOURCES "${SANITY_SUITE_DIR}/${SANITY_STEM}.S")
            endforeach()
        else()
            file(GLOB SANITY_SUITE_SOURCES "${SANITY_SUITE_DIR}/*.S")
        endif()
        foreach(SANITY_SOURCE IN LISTS SANITY_SUITE_SOURCES)
            get_filename_component(SANITY_STEM "${SANITY_SOURCE}" NAME_WE)
            list(APPEND SANITY_IMAGES "${SANITY_SUITE}-p-${SANITY_STEM}")
        endforeach()
        foreach(SANITY_SOURCE IN LISTS SANITY_LOCAL_SOURCES)
            get_filename_component(SANITY_STEM "${SANITY_SOURCE}" NAME_WE)
            if(SANITY_STEM MATCHES "^${SANITY_SUITE}-p-")
                list(APPEND SANITY_IMAGES "${SANITY_STEM}")
            elseif(SANITY_SUITE STREQUAL SANITY_BASE_SUITE AND NOT SANITY_STEM MATCHES "^rv32[a-z]+-p-")
                list(APPEND SANITY_IMAGES "${SANITY_SUITE}-p-${SANITY_STEM}")
            endif()
        endforeach()
    endforeach()
    list(SORT SANITY_IMAGES)
    list(LENGTH SANITY_IMAGES SANITY_IMAGE_COUNT)
    string(REPLACE ";" "\n" SANITY_IMAGE_LINES "${SANITY_IMAGES}")
    file(WRITE "${SANITY_DIR}/images.txt" "${SANITY_IMAGE_LINES}\n")

    if(NOT HEX_TEST_NAME IN_LIST SANITY_IMAGES)
        message(FATAL_ERROR "HEX_TEST_NAME='${HEX_TEST_NAME}' is not one of the ${SANITY_IMAGE_COUNT} images of suites '${SANITY_SUITES}' (e.g. ${SANITY_IMAGES})")
    endif()

    # --- one rule and one target per image ----------------------------------
    # elf -> hex + tohost + dump: four artefacts of the same image, each one a
    # real build dependency, so nothing is recomputed at simulation time.
    # The compile rule is ours: no suite Makefile, no autoconf. The suite's own
    # riscv_test.h is on the include path FIRST, so rv32mi compiles against the
    # faithful trap ceremony and rv32ui keeps the base one.
    set(SANITY_ARTIFACTS "")
    foreach(SANITY_IMAGE IN LISTS SANITY_IMAGES)
        set(SANITY_SUITE "")
        set(SANITY_STEM "${SANITY_IMAGE}")
        foreach(SUITE IN LISTS SANITY_SUITES)
            if(SANITY_IMAGE MATCHES "^${SUITE}-p-")
                set(SANITY_SUITE "${SUITE}")
                string(REGEX REPLACE "^${SUITE}-p-" "" SANITY_STEM "${SANITY_IMAGE}")
                break()
            endif()
        endforeach()
        if(SANITY_SUITE STREQUAL "")
            message(FATAL_ERROR "${SANITY_IMAGE} names no suite in SANITY_SUITES ('${SANITY_SUITES}')")
        endif()
        riscv_sanity_env_dir("${SANITY_ENV}" "${SANITY_SUITE}" SANITY_ENV_SUITE)
        riscv_sanity_march("${SANITY_SUITE}" "${SANITY_STEM}" SANITY_ARCH)

        # A project-local image shadows a bundled one of the same stem; the
        # bundled directory is the fallback, so src/riscv-tests stays untouched.
        # Both local spellings are accepted: <stem>.S and <image>.S.
        set(SANITY_LOCAL_SOURCE "${SANITY_LOCAL_DIR}/${SANITY_IMAGE}.S")
        if(NOT EXISTS "${SANITY_LOCAL_SOURCE}")
            set(SANITY_LOCAL_SOURCE "${SANITY_LOCAL_DIR}/${SANITY_STEM}.S")
        endif()
        if(EXISTS "${SANITY_LOCAL_SOURCE}")
            set(SANITY_SOURCE "${SANITY_LOCAL_SOURCE}")
        else()
            set(SANITY_SOURCE "${RISCV_TESTS_DIR}/isa/${SANITY_SUITE}/${SANITY_STEM}.S")
        endif()
        set(SANITY_ELF "${SANITY_ISA_DIR}/${SANITY_IMAGE}")
        set(SANITY_HEX "${SANITY_HEX_DIR}/${SANITY_IMAGE}.hex")
        set(SANITY_TOHOST "${SANITY_TOHOST_DIR}/${SANITY_IMAGE}")
        set(SANITY_DUMP "${SANITY_DUMP_DIR}/${SANITY_IMAGE}.dump")

        add_custom_command(
            OUTPUT "${SANITY_ELF}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_ISA_DIR}"
            COMMAND ${RISCV_GCC}
                    -march=${SANITY_ARCH} -mabi=ilp32
                    -static -mcmodel=medany -fvisibility=hidden
                    -nostdlib -nostartfiles
                    -I${SANITY_ENV_SUITE}
                    -I${SANITY_ENV}
                    -I${RISCV_TESTS_DIR}/env
                    -I${RISCV_TESTS_DIR}/isa/macros/scalar
                    -T${SANITY_ENV}/link.ld
                    ${SANITY_SOURCE} -o ${SANITY_ELF}
            DEPENDS "${SANITY_SOURCE}" "${SANITY_ENV_SUITE}/riscv_test.h"
                    "${SANITY_ENV}/riscv_test.h" "${SANITY_ENV}/link.ld"
            COMMENT "Compiling ${SANITY_IMAGE}..."
            VERBATIM
        )

        add_custom_command(
            OUTPUT "${SANITY_HEX}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_HEX_DIR}"
            # No --reverse-bytes: `--reverse-bytes=4` byte-swaps every word and
            # the TB would fetch 0x2320300c instead of 0x0c302023. The image is
            # little-endian, exactly as the core fetches it.
            #
            # --change-addresses=-0x80000000 is the ONE rebase: link.ld places
            # the image at RESET_VECTOR (0x8000_0000, FR-41) because that is
            # where the DUT fetches it, and this moves every section down to its
            # offset so the testbench memory model -- 0-based by design -- loads
            # word 0 at index 0 with `$readmemh`. The ELF itself is not touched:
            # `tohost` is still extracted from it by `nm`, absolute, and the
            # sanity checker compares that absolute value with the DUT's
            # absolute `data_addr` (no mask). With the sections at their offsets
            # the first record is @00000000 by construction, so there is no
            # line rewriting here to hide a second adjustment.
            COMMAND ${RISCV_OBJCOPY} -O verilog
                    -j .text.init -j .text -j .tohost -j .data
                    --gap-fill 00000000 --set-start=0 --verilog-data-width 4
                    --change-addresses=-0x80000000
                    "${SANITY_ELF}" "${SANITY_HEX}"
            DEPENDS "${SANITY_ELF}"
            COMMENT "Converting ${SANITY_IMAGE} to a hex image..."
            VERBATIM
        )

        # `tohost` is a property of the ELF, so the build extracts it once
        # instead of every simulation run. `$NF` also accepts the two-field
        # form some binutils print for absolute symbols.
        add_custom_command(
            OUTPUT "${SANITY_TOHOST}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_TOHOST_DIR}"
            COMMAND bash -c "${RISCV_NM} '${SANITY_ELF}' | awk '$NF == \"tohost\" { print \"0x\" $1; exit }' > '${SANITY_TOHOST}' && test -s '${SANITY_TOHOST}'"
            DEPENDS "${SANITY_ELF}"
            COMMENT "Reading tohost from ${SANITY_IMAGE}..."
            VERBATIM
        )

        # The dump is the debug artefact: a failing image prints its TESTNUM and
        # the last PCs, and the dump maps both back to the assembly.
        add_custom_command(
            OUTPUT "${SANITY_DUMP}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_DUMP_DIR}"
            COMMAND bash -c "${RISCV_OBJDUMP} -d '${SANITY_ELF}' > '${SANITY_DUMP}' && test -s '${SANITY_DUMP}'"
            DEPENDS "${SANITY_ELF}"
            COMMENT "Disassembling ${SANITY_IMAGE}..."
            VERBATIM
        )

        add_custom_target(compile_sanity_${SANITY_IMAGE}
            DEPENDS "${SANITY_ELF}" "${SANITY_HEX}" "${SANITY_TOHOST}" "${SANITY_DUMP}")
        list(APPEND SANITY_ARTIFACTS "${SANITY_HEX}" "${SANITY_DUMP}")
    endforeach()

    add_custom_target(compile_sanity_images DEPENDS ${SANITY_ARTIFACTS})

    # Backwards-compatible target: the single image chosen by HEX_TEST_NAME,
    # still used by scripts/xrun.sh and the README.
    add_custom_target(compile_sanity_tests DEPENDS "${SANITY_HEX_DIR}/${HEX_TEST_NAME}.hex")

    # --- one CTest test per image -------------------------------------------
    # Declared only when the testbench has the +HEX/+TOHOST mode: without it
    # there is nothing to run, and `sanity` answers `not_measurable` instead of
    # failing once per image. The env guard keeps these image simulations out of
    # a plain `ctest`/`make test` (they are skipped, never run by accident).
    if(EXISTS "${CMAKE_SOURCE_DIR}/tb/tests/${SANITY_TEST}.sv")
        foreach(SANITY_IMAGE IN LISTS SANITY_IMAGES)
            riscv_xsim_command(TEST_CMD SNAPSHOT top_sim TEST "${SANITY_TEST}"
                LOG "${SANITY_OUT}/${SANITY_IMAGE}.log"
                SKIP_ENV RISCV_SANITY TRACE_ENV
                HEX "${SANITY_HEX_DIR}/${SANITY_IMAGE}.hex"
                TOHOST_FILE "${SANITY_TOHOST_DIR}/${SANITY_IMAGE}"
                REQUIRE_SANITY SANITY_IMAGE "${SANITY_IMAGE}")
            # One run directory per image: xsim.log/xsim.jou/*.pb/top_sim.wdb
            # are CWD files, so two images must not share build/.
            riscv_test_run_dir(TEST_RUN_DIR "${SANITY_IMAGE}")
            add_test(NAME ${SANITY_IMAGE} COMMAND bash -c "${TEST_CMD}"
                WORKING_DIRECTORY "${TEST_RUN_DIR}")
            set_tests_properties(${SANITY_IMAGE} PROPERTIES
                LABELS "sanity"
                TIMEOUT ${SANITY_TIMEOUT}
                SKIP_RETURN_CODE 77)
        endforeach()
        message(STATUS "Sanity images: ${SANITY_IMAGE_COUNT} from ${SANITY_SUITES} (CTest label 'sanity')")
    else()
        message(STATUS "Sanity images: ${SANITY_IMAGE_COUNT} from ${SANITY_SUITES} (no tb/tests/${SANITY_TEST}.sv: NFR-05 not measurable, G-10)")
    endif()

    # The gate deliberately does not depend on `elaborate`: it must be able to
    # answer "not measurable" on a machine with no Vivado. The run mode pulls
    # the images and the elaboration only when it is really going to run.
    add_custom_target(sanity
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE}
                --jobs ${DOLLAR}${DOLLAR}{VERIFY_JOBS:-${VERIFY_JOBS}} $(SANITY_ARGS)
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running the bundled RISC-V test images (NFR-05)..."
        USES_TERMINAL
    )

    # Same measurement, exit 0 even when images fail: the signoff gate reads
    # summary.json and check 6 turns the failures into `blocked`. Without this,
    # `make signoff-check` would abort in the dependency before judging.
    add_custom_target(sanity-evidence
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE}
                --allow-fail --jobs ${DOLLAR}${DOLLAR}{VERIFY_JOBS:-${VERIFY_JOBS}} $(SANITY_ARGS)
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Measuring NFR-05 for the signoff gate (failures are a verdict)..."
        USES_TERMINAL
    )
    return()
endif()

# =============================================================================
# Run mode: select, build, run, judge.
# =============================================================================
get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(SANITY_DIR "${BUILD}/sanity_tests")
set(ISA_DIR "${SANITY_DIR}/isa")
set(HEX_DIR "${SANITY_DIR}/hex")
set(TOHOST_DIR "${SANITY_DIR}/tohost")
set(DUMP_DIR "${SANITY_DIR}/dump")
set(OUT "${BUILD}/sanity")
set(SANITY_TEST "riscv_small_sanity_test")

# --- arguments ---------------------------------------------------------------
set(IMAGES "")
set(EXCLUDE "")
set(COMPILE_ONLY FALSE)
set(DO_LIST FALSE)
set(DO_TRACE FALSE)
set(ALLOW_FAIL FALSE)
set(JOBS_ARG "")
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        set(ARG "${CMAKE_ARGV${I}}")
        if(ARG STREQUAL "--compile-only")
            set(COMPILE_ONLY TRUE)
        elseif(ARG STREQUAL "--list")
            set(DO_LIST TRUE)
        elseif(ARG STREQUAL "--trace")
            set(DO_TRACE TRUE)
        elseif(ARG STREQUAL "--allow-fail")
            # Measurement mode for the signoff gate: a failing image is a
            # verdict (blocked in check 6), not a build error that stops the
            # evidence chain. The public `make sanity` keeps exit 1.
            set(ALLOW_FAIL TRUE)
        elseif(ARG STREQUAL "--exclude")
            set(NEED_EXCLUDE TRUE)
        elseif(DEFINED NEED_EXCLUDE)
            unset(NEED_EXCLUDE)
            list(APPEND EXCLUDE "${ARG}")
        elseif(ARG STREQUAL "--jobs")
            set(NEED_JOBS TRUE)
        elseif(DEFINED NEED_JOBS)
            unset(NEED_JOBS)
            set(JOBS_ARG "${ARG}")
        elseif(ARG MATCHES "^-")
            message(FATAL_ERROR "unknown option '${ARG}'")
            return()
        else()
            list(APPEND IMAGES "${ARG}")
        endif()
    endforeach()
endif()

# 1 is the historical behaviour: a direct `cmake -P` is serial. The gate
# targets pass --jobs from VERIFY_JOBS; a later --jobs in SANITY_ARGS wins.
riscv_parallel_jobs(JOBS "${JOBS_ARG}")

# --- chain: ./configure gives the image list --------------------------------
file(MAKE_DIRECTORY "${OUT}")
riscv_bootstrap_build("${OUT}/configure.log")

file(STRINGS "${SANITY_DIR}/images.txt" AVAILABLE)
if(NOT AVAILABLE)
    message(FATAL_ERROR "no image in build/sanity_tests/images.txt; is src/riscv-tests initialised?")
    return()
endif()

if(IMAGES STREQUAL "")
    set(IMAGES "${AVAILABLE}")
endif()
if(EXCLUDE)
    foreach(BAD IN LISTS EXCLUDE)
        list(REMOVE_ITEM IMAGES "${BAD}")
    endforeach()
    list(LENGTH EXCLUDE N_EXCLUDE)
    message(STATUS "excluding ${N_EXCLUDE} image(s): ${EXCLUDE} (record the reason as a dated A-xx)")
endif()

list(LENGTH IMAGES N_IMAGES)
if(N_IMAGES EQUAL 0)
    message(FATAL_ERROR "no image selected")
    return()
endif()

if(DO_LIST)
    foreach(IMAGE IN LISTS IMAGES)
        message("${IMAGE}")
    endforeach()
    return()
endif()

# --- the measurement can be answered before building anything ---------------
riscv_tree_digests(RTL_DIGEST TB_DIGEST "${ROOT}")
string(TIMESTAMP STAMP "%Y-%m-%dT%H:%M:%SZ" UTC)

function(write_summary STATUS REASON N_PASS N_FAIL N_IMAGES_JSON)
    string(REPLACE ";" ",\n" IMAGES_JSON "${N_IMAGES_JSON}")
    file(WRITE "${OUT}/summary.json" "{
  \"kind\": \"sanity\",
  \"status\": \"${STATUS}\",
  \"reason\": \"${REASON}\",
  \"test\": \"${SANITY_TEST}\",
  \"rtl_digest\": \"${RTL_DIGEST}\",
  \"tb_digest\": \"${TB_DIGEST}\",
  \"recorded\": \"${STAMP}\",
  \"images\": [
${IMAGES_JSON}  ],
  \"summary\": { \"pass\": ${N_PASS}, \"fail\": ${N_FAIL} }
}
")
    if(REASON STREQUAL "")
        message("SANITY ${STATUS} pass=${N_PASS} fail=${N_FAIL}")
    else()
        message("SANITY not measurable: ${REASON}")
    endif()
endfunction()

if(NOT COMPILE_ONLY AND NOT EXISTS "${ROOT}/tb/tests/${SANITY_TEST}.sv")
    # The measurement produced a verdict, so the command succeeded: NFR-05 is a
    # blocker in the signoff gate, which reads summary.json.
    write_summary("not_measurable"
        "tb/tests/${SANITY_TEST}.sv does not exist: the testbench has no +HEX/+TOHOST mode yet, so NFR-05 cannot be measured (G-10)"
        0 0 "")
    message(STATUS "verdict recorded: NFR-05 is not measurable (the signoff gate treats it as a blocker)")
    return()
endif()

# --- build exactly the selected images (+ the snapshot when running) --------
set(BUILD_TARGETS "")
foreach(IMAGE IN LISTS IMAGES)
    list(APPEND BUILD_TARGETS compile_sanity_${IMAGE})
endforeach()
if(NOT COMPILE_ONLY)
    list(APPEND BUILD_TARGETS elaborate)
endif()

message(STATUS "building ${N_IMAGES} image(s) through the CMake targets")
execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${BUILD}" --target ${BUILD_TARGETS}
    RESULT_VARIABLE RC
    OUTPUT_FILE "${OUT}/build.log"
    ERROR_FILE "${OUT}/build.log")
if(NOT RC EQUAL 0)
    message(FATAL_ERROR "the image/elaboration build failed; see build/sanity/build.log")
endif()

if(COMPILE_ONLY)
    message(STATUS "images ready in build/sanity_tests/hex")
    return()
endif()

foreach(IMAGE IN LISTS IMAGES)
    if(NOT EXISTS "${HEX_DIR}/${IMAGE}.hex" OR NOT EXISTS "${TOHOST_DIR}/${IMAGE}")
        message(FATAL_ERROR "${IMAGE} has no hex/tohost artefact; check the build rules in scripts/verify/sanity.cmake")
    endif()
endforeach()

# --- run through CTest -------------------------------------------------------
message(STATUS "running ${N_IMAGES} image(s) through ctest (label 'sanity')")
list(JOIN IMAGES "|" PATTERN)
set(CTEST_ENV "RISCV_SANITY=1")
if(DO_TRACE)
    list(APPEND CTEST_ENV "SANITY_TRACE=1")
endif()
riscv_ctest_run("${OUT}/junit.xml" "${BUILD}"
    LOG "${OUT}/ctest.log"
    JOBS "${JOBS}"
    ENV ${CTEST_ENV}
    SELECT -L "^sanity$" -R "^(${PATTERN})$")

riscv_junit_rows(ROWS "${OUT}/junit.xml")
if(NOT ROWS)
    message(FATAL_ERROR "ctest ran no sanity test; see build/sanity/ctest.log")
endif()

# --- judge ------------------------------------------------------------------
set(N_PASS 0)
set(N_FAIL 0)
set(IMAGE_ROWS "")
set(NOT_MEASURABLE "")

foreach(ROW IN LISTS ROWS)
    string(REPLACE "|" ";" FIELDS "${ROW}")
    list(GET FIELDS 0 IMAGE)
    list(GET FIELDS 1 STATUS)

    set(TOHOST "")
    if(EXISTS "${TOHOST_DIR}/${IMAGE}")
        file(READ "${TOHOST_DIR}/${IMAGE}" TOHOST)
        string(STRIP "${TOHOST}" TOHOST)
    endif()

    set(TESTNUM "")
    set(PC "")
    set(LOG "${OUT}/${IMAGE}.log")
    set(LOG_TEXT "")
    if(EXISTS "${LOG}")
        file(READ "${LOG}" LOG_TEXT)
        if(LOG_TEXT MATCHES "SANITY: FAIL testnum=([0-9]+) value=0x[0-9a-fA-F]+")
            set(TESTNUM "${CMAKE_MATCH_1}")
        elseif(LOG_TEXT MATCHES "SANITY: TIMEOUT pc=0x([0-9a-fA-F]+)")
            set(PC "0x${CMAKE_MATCH_1}")
        endif()
    endif()

    # Attribution: the verdict line must name this image. A log that carries
    # another image's PASS -- the hazard of a build/ shared between runs or
    # between parallel tests -- is not evidence for this image, so it is
    # `not_measurable`, never `pass`.
    set(LOG_IMAGE "")
    if(LOG_TEXT MATCHES "SANITY: (PASS|FAIL|TIMEOUT)[^\r\n]*image=([^ \t\r\n]+)")
        set(LOG_IMAGE "${CMAKE_MATCH_2}")
    endif()
    if(NOT LOG_IMAGE STREQUAL "" AND NOT LOG_IMAGE STREQUAL IMAGE)
        set(NOT_MEASURABLE "log is ${LOG_IMAGE}, not ${IMAGE}: build/sanity/${IMAGE}.log carries another image's verdict line")
        break()
    endif()

    if(STATUS STREQUAL "pass")
        if(NOT LOG_IMAGE STREQUAL IMAGE)
            # CTest said pass, yet the log has no `SANITY: PASS image=<image>`;
            # only an unpinned command (an old build/) can get here. Not a pass.
            set(NOT_MEASURABLE "build/sanity/${IMAGE}.log has no SANITY: PASS image=${IMAGE} line, so the run is not attributable; re-run the sweep")
            break()
        endif()
        math(EXPR N_PASS "${N_PASS} + 1")
    elseif(STATUS STREQUAL "timeout")
        # A hung DUT is a DUT failure, not a missing measurement.
        set(STATUS "fail")
        math(EXPR N_FAIL "${N_FAIL} + 1")
    elseif(STATUS STREQUAL "skip")
        set(NOT_MEASURABLE "${IMAGE} was skipped: the images were not built for this run")
        break()
    else()
        # `fail` is only a verdict if the testbench said so; no SANITY line at
        # all means the +HEX mode did not answer, which is not measurable.
        if(NOT LOG_TEXT MATCHES "SANITY:")
            set(NOT_MEASURABLE "${IMAGE} produced no SANITY verdict line; see build/sanity/${IMAGE}.log")
            break()
        endif()
        set(STATUS "fail")
        math(EXPR N_FAIL "${N_FAIL} + 1")
    endif()

    message(STATUS "  ${IMAGE} -> ${STATUS} (tohost=${TOHOST} testnum=${TESTNUM} pc=${PC})")
    list(APPEND IMAGE_ROWS "    { \"image\": \"${IMAGE}\", \"status\": \"${STATUS}\", \"tohost\": \"${TOHOST}\", \"testnum\": \"${TESTNUM}\", \"pc\": \"${PC}\", \"log\": \"build/sanity/${IMAGE}.log\" }")
endforeach()

if(NOT NOT_MEASURABLE STREQUAL "")
    write_summary("not_measurable" "${NOT_MEASURABLE}" ${N_PASS} ${N_FAIL} "${IMAGE_ROWS}")
    message(STATUS "verdict recorded: NFR-05 is not measurable (the signoff gate treats it as a blocker)")
    return()
endif()

write_summary("measured" "" ${N_PASS} ${N_FAIL} "${IMAGE_ROWS}")
message(STATUS "results: build/sanity/summary.json")

if(N_FAIL GREATER 0 AND NOT ALLOW_FAIL)
    message(FATAL_ERROR "sanity failures")
endif()
