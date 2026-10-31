# =============================================================================
# scripts/verify/sanity.cmake - NFR-05 in one file: build the images, run them,
# judge them.
#
# Included by CMakeLists.txt (configure mode), it owns the whole riscv-tests
# pipeline:
#   1. compile each isa/rv32ui/*.S image with the project's own environment
#      (scripts/verify/sanity/riscv_test.h + link.ld) -- no autoconf, no
#      out-of-tree configure, no suite Makefile;
#   2. convert the ELF to a Verilog hex and extract `tohost` from the ELF;
#   3. declare one CTest test per image (label `sanity`) and the `sanity`
#      target, which runs this same file with `cmake -P`.
#
# Why a project environment: the stock env/p images need Zicsr, MRET and a trap
# handler for ECALL, none of which riscv_small implements (G-13). The test
# bodies are unmodified; only the pass/fail ceremony is local (see
# scripts/verify/sanity/riscv_test.h).
#
# Build targets (unchanged, so the documented commands keep working):
#   compile_sanity_tests     one image, from the HEX_TEST_NAME cache variable
#   compile_sanity_images    every rv32ui-p-* image
#   compile_sanity_<image>   a single named image
#
#   cmake -P scripts/verify/sanity.cmake                  every image
#   cmake -P scripts/verify/sanity.cmake rv32ui-p-add     one image
#   cmake -P scripts/verify/sanity.cmake --compile-only   build the images only
#   cmake -P scripts/verify/sanity.cmake --list
#   cmake -P scripts/verify/sanity.cmake --exclude rv32ui-p-x
#   cmake -P scripts/verify/sanity.cmake --trace          add +TRACE to the TB
#
# What the run mode keeps, because nobody else can do it: `tohost` is read from
# the ELF (never from a literal) and the verdict line is `SANITY: PASS|FAIL`.
# No verdict line means `not_measurable`, never pass. CTest still owns the run
# itself (timeout, log, verdict, JUnit), exactly like the regression and the
# coverage runs; a plain `ctest` skips these tests (exit 77) because it never
# built the images.
#
# Scope: only isa/rv32ui. rv32mi needs CSR/trap (E6/E7), rv32um/rv32uc need
# M/C (E8); rv32si is not in NFR-05. The glob is a one-line change when those
# requirements land.
#
# Results: build/sanity/summary.json, one log per image, one dump per image.
# Exit codes: 0 the measurement ran (not measurable is still a run), 1 an image
#             failed, 2 the environment is missing.
# =============================================================================

if(CMAKE_VERSION VERSION_LESS 3.21)
    message(FATAL_ERROR "sanity.cmake needs CMake >= 3.21 for `ctest --output-junit` (found ${CMAKE_VERSION})")
endif()

set(DOLLAR "$")

# manifest-independent, but the digest is the same evidence key everywhere.
include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)

# =============================================================================
# Configure mode: the images, their CTest tests and the `sanity` target.
# =============================================================================
if(NOT CMAKE_SCRIPT_MODE_FILE)
    set(HEX_TEST_NAME "rv32ui-p-addi" CACHE STRING "One image for the compile_sanity_tests target")
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

    if(NOT EXISTS "${RISCV_TESTS_DIR}/isa/rv32ui")
        message(FATAL_ERROR "No riscv-tests sources under ${RISCV_TESTS_DIR}/isa/rv32ui. Run: git submodule update --init src/riscv-tests")
    endif()

    # --- image list ---------------------------------------------------------
    # Each isa/rv32ui/<stem>.S builds the bare-metal image rv32ui-p-<stem>
    # ("-p-" is the physical target of the bundled suite). The list is written
    # to images.txt so the run mode never globs the sources a second time.
    file(GLOB SANITY_SOURCES "${RISCV_TESTS_DIR}/isa/rv32ui/*.S")
    set(SANITY_IMAGES "")
    foreach(SANITY_SOURCE IN LISTS SANITY_SOURCES)
        get_filename_component(SANITY_STEM "${SANITY_SOURCE}" NAME_WE)
        list(APPEND SANITY_IMAGES "rv32ui-p-${SANITY_STEM}")
    endforeach()
    list(SORT SANITY_IMAGES)
    list(LENGTH SANITY_IMAGES SANITY_IMAGE_COUNT)
    string(REPLACE ";" "\n" SANITY_IMAGE_LINES "${SANITY_IMAGES}")
    file(WRITE "${SANITY_DIR}/images.txt" "${SANITY_IMAGE_LINES}\n")

    if(NOT HEX_TEST_NAME IN_LIST SANITY_IMAGES)
        message(FATAL_ERROR "HEX_TEST_NAME='${HEX_TEST_NAME}' is not one of the ${SANITY_IMAGE_COUNT} bundled images (e.g. ${SANITY_IMAGES})")
    endif()

    # --- one rule and one target per image ----------------------------------
    # elf -> hex + tohost + dump: four artefacts of the same image, each one a
    # real build dependency, so nothing is recomputed at simulation time.
    # The compile rule is ours: no suite Makefile, no autoconf. `-march=rv32i`
    # proves the image only uses the base ISA (the suite links with -march=rv32g
    # which merely permits M/A/F/D). `fence_i.S` is Zifencei.
    set(SANITY_ARTIFACTS "")
    foreach(SANITY_IMAGE IN LISTS SANITY_IMAGES)
        set(SANITY_STEM "${SANITY_IMAGE}")
        string(REGEX REPLACE "^rv32ui-p-" "" SANITY_STEM "${SANITY_STEM}")
        set(SANITY_SOURCE "${RISCV_TESTS_DIR}/isa/rv32ui/${SANITY_STEM}.S")
        set(SANITY_ELF "${SANITY_ISA_DIR}/${SANITY_IMAGE}")
        set(SANITY_HEX "${SANITY_HEX_DIR}/${SANITY_IMAGE}.hex")
        set(SANITY_TOHOST "${SANITY_TOHOST_DIR}/${SANITY_IMAGE}")
        set(SANITY_DUMP "${SANITY_DUMP_DIR}/${SANITY_IMAGE}.dump")

        set(SANITY_ARCH "rv32i")
        if(SANITY_STEM STREQUAL "fence_i")
            set(SANITY_ARCH "rv32i_zifencei")
        endif()

        add_custom_command(
            OUTPUT "${SANITY_ELF}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_ISA_DIR}"
            COMMAND ${RISCV_GCC}
                    -march=${SANITY_ARCH} -mabi=ilp32
                    -static -mcmodel=medany -fvisibility=hidden
                    -nostdlib -nostartfiles
                    -I${SANITY_ENV}
                    -I${RISCV_TESTS_DIR}/env
                    -I${RISCV_TESTS_DIR}/isa/macros/scalar
                    -T${SANITY_ENV}/link.ld
                    ${SANITY_SOURCE} -o ${SANITY_ELF}
            DEPENDS "${SANITY_SOURCE}" "${SANITY_ENV}/riscv_test.h" "${SANITY_ENV}/link.ld"
            COMMENT "Compiling ${SANITY_IMAGE}..."
            VERBATIM
        )

        add_custom_command(
            OUTPUT "${SANITY_HEX}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${SANITY_HEX_DIR}"
            # No --reverse-bytes: `--reverse-bytes=4` byte-swaps every word and
            # the TB would fetch 0x2320300c instead of 0x0c302023. The image is
            # little-endian, exactly as the core fetches it.
            COMMAND ${RISCV_OBJCOPY} -O verilog
                    -j .text.init -j .text -j .tohost -j .data
                    --gap-fill 00000000 --set-start=0 --verilog-data-width 4
                    "${SANITY_ELF}" "${SANITY_HEX}"
            COMMAND sed -i.bak "1 s/.*/@00000000/" "${SANITY_HEX}"
            COMMAND ${CMAKE_COMMAND} -E remove "${SANITY_HEX}.bak"
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
    # failing 42 times. The env guard keeps these 42 simulations out of a plain
    # `ctest`/`make test` (they are skipped, never run by accident).
    if(EXISTS "${CMAKE_SOURCE_DIR}/tb/tests/${SANITY_TEST}.sv")
        foreach(SANITY_IMAGE IN LISTS SANITY_IMAGES)
            add_test(NAME ${SANITY_IMAGE}
                COMMAND bash -c "test -n \"${DOLLAR}RISCV_SANITY\" || exit 77; TRACE=\"\"; if [ -n \"${DOLLAR}SANITY_TRACE\" ]; then TRACE=\"--testplusarg TRACE\"; fi; xsim top_sim --R --testplusarg UVM_TESTNAME=${SANITY_TEST} --testplusarg HEX=${SANITY_HEX_DIR}/${SANITY_IMAGE}.hex --testplusarg TOHOST=$(cat ${SANITY_TOHOST_DIR}/${SANITY_IMAGE}) --testplusarg NO_COLOR ${DOLLAR}TRACE > ${SANITY_OUT}/${SANITY_IMAGE}.log 2>&1 && grep -q '^SANITY: PASS' ${SANITY_OUT}/${SANITY_IMAGE}.log"
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
            set_tests_properties(${SANITY_IMAGE} PROPERTIES
                LABELS "sanity"
                TIMEOUT ${SANITY_TIMEOUT}
                SKIP_RETURN_CODE 77)
        endforeach()
        message(STATUS "Sanity images: ${SANITY_IMAGE_COUNT} (CTest label 'sanity')")
    else()
        message(STATUS "Sanity images: ${SANITY_IMAGE_COUNT} (no tb/tests/${SANITY_TEST}.sv: NFR-05 not measurable, G-10)")
    endif()

    # The gate deliberately does not depend on `elaborate`: it must be able to
    # answer "not measurable" on a machine with no Vivado. The run mode pulls
    # the images and the elaboration only when it is really going to run.
    add_custom_target(sanity
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE} $(SANITY_ARGS)
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running the bundled RISC-V test images (NFR-05)..."
        USES_TERMINAL
    )

    # Same measurement, exit 0 even when images fail: the signoff gate reads
    # summary.json and check 6 turns the failures into `blocked`. Without this,
    # `make signoff-check` would abort in the dependency before judging.
    add_custom_target(sanity-evidence
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE} --allow-fail $(SANITY_ARGS)
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
        elseif(ARG MATCHES "^-")
            message(FATAL_ERROR "unknown option '${ARG}'")
            return()
        else()
            list(APPEND IMAGES "${ARG}")
        endif()
    endforeach()
endif()

# --- chain: ./configure gives the image list --------------------------------
file(MAKE_DIRECTORY "${OUT}")
if(NOT EXISTS "${BUILD}/Makefile")
    message(STATUS "build/ is not configured; bootstrapping with ./configure")
    execute_process(COMMAND "${ROOT}/configure"
        WORKING_DIRECTORY "${ROOT}"
        RESULT_VARIABLE RC
        OUTPUT_FILE "${OUT}/configure.log" ERROR_FILE "${OUT}/configure.log")
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "bootstrap failed; see build/sanity/configure.log")
    endif()
endif()

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
riscv_tree_digest(RTL_DIGEST "${ROOT}/rtl")
riscv_tree_digest(TB_DIGEST "${ROOT}/tb")
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
set(TRACE_ENV "")
if(DO_TRACE)
    set(TRACE_ENV "SANITY_TRACE=1")
endif()
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env RISCV_SANITY=1 ${TRACE_ENV}
            ${CMAKE_CTEST_COMMAND} --output-junit "${OUT}/junit.xml"
            -L "^sanity$" -R "^(${PATTERN})$"
    WORKING_DIRECTORY "${BUILD}"
    RESULT_VARIABLE CTEST_RC
    OUTPUT_FILE "${OUT}/ctest.log"
    ERROR_FILE "${OUT}/ctest.log")

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

    if(STATUS STREQUAL "pass")
        set(STATUS "pass")
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
