# =============================================================================
# sanity.cmake - run the bundled riscv-tests images against the DUT (NFR-05).
#
#   cmake -P scripts/verify/sanity.cmake                  every rv32ui-p-* image
#   cmake -P scripts/verify/sanity.cmake rv32ui-p-add     one image
#   cmake -P scripts/verify/sanity.cmake --compile-only   build the images only
#   cmake -P scripts/verify/sanity.cmake --list
#   cmake -P scripts/verify/sanity.cmake --exclude rv32ui-p-x
#
# Building the images is not done here: scripts/compile_sanity_tests.cmake owns
# the suite configuration, the per-image ELF and the objcopy/address-marker
# conversion, and this script drives it through the target compile_sanity_images.
# Running and judging is what is left:
#   1. read the `tohost` address from the ELF (never from a literal);
#   2. run xsim with +HEX/+TOHOST through riscv_small_sanity_test;
#   3. require the line `SANITY: PASS` / `SANITY: FAIL <testnum>`.
# No verdict line means `not_measurable`, never pass.
#
# Results: build/sanity/summary.json and one log per image.
#
# Exit codes: 0 all passed, 1 a failure, 2 not measurable or a build error.
# =============================================================================
cmake_minimum_required(VERSION 3.21)

get_filename_component(ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(BUILD "${ROOT}/build")
set(SANITY_TEST "riscv_small_sanity_test")
set(SANITY_DIR "${BUILD}/sanity_tests")
set(HEX_DIR "${SANITY_DIR}/hex")
set(ISA_DIR "${SANITY_DIR}/isa")
set(OUT "${BUILD}/sanity")
set(IMAGES "")
set(EXCLUDE "")
set(COMPILE_ONLY FALSE)
set(DO_LIST FALSE)
set(EXPLICIT FALSE)

# --- arguments ---------------------------------------------------------------
math(EXPR LAST_ARG "${CMAKE_ARGC} - 1")
if(CMAKE_ARGC GREATER 3)
    foreach(I RANGE 3 ${LAST_ARG})
        set(ARG "${CMAKE_ARGV${I}}")
        if(ARG STREQUAL "--compile-only")
            set(COMPILE_ONLY TRUE)
        elseif(ARG STREQUAL "--list")
            set(DO_LIST TRUE)
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
            set(EXPLICIT TRUE)
        endif()
    endforeach()
endif()

# --- image discovery ---------------------------------------------------------
# isa/rv32ui/addi.S builds the image rv32ui-p-addi ("-p-" = physical target of
# the bundled suite). Same glob as scripts/compile_sanity_tests.cmake: if the two
# ever disagree, the build target fails loudly instead of simulating a missing
# file.
file(GLOB SANITY_SOURCES "${ROOT}/src/riscv-tests/isa/rv32ui/*.S")
set(AVAILABLE "")
foreach(SRC IN LISTS SANITY_SOURCES)
    get_filename_component(STEM "${SRC}" NAME_WE)
    list(APPEND AVAILABLE "rv32ui-p-${STEM}")
endforeach()
list(SORT AVAILABLE)

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
    message(FATAL_ERROR "no rv32ui-p-* image found; is the src/riscv-tests submodule initialised?")
    return()
endif()

if(DO_LIST)
    foreach(IMAGE IN LISTS IMAGES)
        message("${IMAGE}")
    endforeach()
    return()
endif()

# --- digests, shared by every artefact ---------------------------------------
function(sanity_tree_digest OUT_VAR DIR)
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

sanity_tree_digest(RTL_DIGEST "${ROOT}/rtl")
sanity_tree_digest(TB_DIGEST "${ROOT}/tb")
string(TIMESTAMP STAMP "%Y-%m-%dT%H:%M:%SZ" UTC)

file(MAKE_DIRECTORY "${OUT}")

function(write_not_measurable REASON)
    string(REPLACE ";" ",\n" IMAGES_JSON "${IMAGE_ROWS}")
file(WRITE "${OUT}/summary.json" "{
  \"kind\": \"sanity\",
  \"status\": \"not_measurable\",
  \"reason\": \"${REASON}\",
  \"test\": \"${SANITY_TEST}\",
  \"rtl_digest\": \"${RTL_DIGEST}\",
  \"tb_digest\": \"${TB_DIGEST}\",
  \"recorded\": \"${STAMP}\",
  \"images\": []
}
")
    message("SANITY not measurable: ${REASON}")
endfunction()

# --- build (reuses the build system) -----------------------------------------
function(build_images)
    if(NOT EXISTS "${BUILD}/Makefile")
        message(FATAL_ERROR "build/ is not configured; run ./configure first")
    endif()
    message(STATUS "building the images through the CMake target compile_sanity_images")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" --build "${BUILD}" --target compile_sanity_images
        RESULT_VARIABLE RC
        OUTPUT_FILE "${OUT}/build.log"
        ERROR_FILE "${OUT}/build.log")
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "compile_sanity_images failed; see build/sanity/build.log")
    endif()
endfunction()

# --compile-only is about the images, not the testbench: it must work before
# the +HEX mode exists, because building the images is its prerequisite.
if(COMPILE_ONLY)
    build_images()
    message(STATUS "images ready in build/sanity_tests/hex")
    return()
endif()

# Nothing to run without a testbench mode, and building 42 images to then say
# "not measurable" would be wasted work.
if(NOT EXISTS "${ROOT}/tb/tests/${SANITY_TEST}.sv")
    write_not_measurable("tb/tests/${SANITY_TEST}.sv does not exist: the testbench has no +HEX/+TOHOST mode yet, so NFR-05 cannot be measured (G-10)")
    message(FATAL_ERROR "sanity is not measurable")
    return()
endif()

build_images()

foreach(IMAGE IN LISTS IMAGES)
    if(NOT EXISTS "${HEX_DIR}/${IMAGE}.hex" OR NOT EXISTS "${ISA_DIR}/${IMAGE}")
        message(FATAL_ERROR "compile_sanity_images produced no ${IMAGE}; check scripts/compile_sanity_tests.cmake")
    endif()
endforeach()

if(NOT EXISTS "${BUILD}/xsim.dir/top_sim")
    message(STATUS "elaborating")
    execute_process(COMMAND "${CMAKE_COMMAND}" --build "${BUILD}" --target elaborate
                    RESULT_VARIABLE RC OUTPUT_FILE "${OUT}/elaborate.log" ERROR_FILE "${OUT}/elaborate.log")
    if(NOT RC EQUAL 0)
        message(FATAL_ERROR "elaboration failed; see build/sanity/elaborate.log")
    endif()
endif()

# --- run ---------------------------------------------------------------------
set(N_PASS 0)
set(N_FAIL 0)
set(IMAGE_ROWS "")
set(NOT_MEASURABLE "")

foreach(IMAGE IN LISTS IMAGES)
    set(LOG "${OUT}/${IMAGE}.log")

    execute_process(
        COMMAND riscv64-unknown-elf-nm "${ISA_DIR}/${IMAGE}"
        OUTPUT_VARIABLE NM_OUT ERROR_QUIET RESULT_VARIABLE NM_RC)
    if(NOT NM_RC EQUAL 0)
        message(FATAL_ERROR "riscv64-unknown-elf-nm failed for ${IMAGE}; install binutils-riscv64-unknown-elf")
    endif()
    set(TOHOST "")
    string(REPLACE "\n" ";" NM_LINES "${NM_OUT}")
    foreach(LINE IN LISTS NM_LINES)
        if(LINE MATCHES "^([0-9a-fA-F]+) +tohost$")
            set(TOHOST "0x${CMAKE_MATCH_1}")
        endif()
    endforeach()
    if(TOHOST STREQUAL "")
        message(FATAL_ERROR "${IMAGE} has no tohost symbol; cannot decide pass/fail")
    endif()

    message(STATUS "running ${IMAGE} (tohost=${TOHOST})")
    execute_process(
        COMMAND xsim top_sim --R
                --testplusarg "UVM_TESTNAME=${SANITY_TEST}"
                --testplusarg "HEX=${HEX_DIR}/${IMAGE}.hex"
                --testplusarg "TOHOST=${TOHOST}"
                --testplusarg NO_COLOR
        WORKING_DIRECTORY "${BUILD}"
        TIMEOUT 300
        RESULT_VARIABLE RC
        OUTPUT_FILE "${LOG}" ERROR_FILE "${LOG}")

    file(READ "${LOG}" LOG_TEXT)
    set(STATUS "")
    if(LOG_TEXT MATCHES "SANITY: PASS")
        set(STATUS "pass")
        math(EXPR N_PASS "${N_PASS} + 1")
    elseif(LOG_TEXT MATCHES "SANITY: FAIL")
        set(STATUS "fail")
        math(EXPR N_FAIL "${N_FAIL} + 1")
    else()
        set(NOT_MEASURABLE "${IMAGE} produced no SANITY verdict line (rc=${RC}); see build/sanity/${IMAGE}.log")
        break()
    endif()
    message(STATUS "  ${IMAGE} -> ${STATUS}")

    list(APPEND IMAGE_ROWS "    { \"image\": \"${IMAGE}\", \"status\": \"${STATUS}\", \"tohost\": \"${TOHOST}\", \"log\": \"build/sanity/${IMAGE}.log\" }")
endforeach()

if(NOT NOT_MEASURABLE STREQUAL "")
    write_not_measurable("${NOT_MEASURABLE}")
    message(FATAL_ERROR "sanity is not measurable")
    return()
endif()

string(REPLACE ";" ",\n" IMAGES_JSON "${IMAGE_ROWS}")
file(WRITE "${OUT}/summary.json" "{
  \"kind\": \"sanity\",
  \"status\": \"measured\",
  \"test\": \"${SANITY_TEST}\",
  \"rtl_digest\": \"${RTL_DIGEST}\",
  \"tb_digest\": \"${TB_DIGEST}\",
  \"recorded\": \"${STAMP}\",
  \"images\": [
${IMAGES_JSON}  ],
  \"summary\": { \"pass\": ${N_PASS}, \"fail\": ${N_FAIL} }
}
")

message(STATUS "results: build/sanity/summary.json")
message("SANITY pass=${N_PASS} fail=${N_FAIL}")
if(N_FAIL GREATER 0)
    message(FATAL_ERROR "sanity failures")
endif()
