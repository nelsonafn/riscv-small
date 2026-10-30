# =============================================================================
# scripts/verify/common.cmake - the three facts every gate must read the same way
#
# Included by regress.cmake and coverage.cmake in both modes, and by
# signoff_check.cmake. It only defines functions, so including it never declares
# a target and it is safe in `cmake -P` as well as at configure time.
#
#   riscv_manifest_rows(OUT <tests.tsv>)
#       one row per test: `T-id|uvm_test|wave|requirements|timeout|red`
#
#   riscv_junit_rows(OUT <junit.xml>)
#       one row per executed test: `T-id|pass|fail|timeout|skip|class`
#       (the class travels in the `class:<uvm_test>` label, not in a second
#       read of the manifest)
#
#   riscv_tree_digest(OUT <dir>)
#       `sha256:...` over the .sv/.svh content of a tree -- the evidence key,
#       since the project forbids automatic commits
# =============================================================================

# --- manifest ----------------------------------------------------------------
function(riscv_manifest_rows OUT_VAR MANIFEST)
    if(NOT EXISTS "${MANIFEST}")
        message(FATAL_ERROR "manifest not found: ${MANIFEST}")
    endif()
    file(STRINGS "${MANIFEST}" LINES)
    set(ROWS "")
    foreach(LINE IN LISTS LINES)
        if(LINE MATCHES "^#" OR LINE STREQUAL "")
            continue()
        endif()
        # `|` because `;` is CMake's list separator and the fields are already a
        # list by the time a caller splits them.
        string(REPLACE "\t" "|" ROW "${LINE}")
        list(APPEND ROWS "${ROW}")
    endforeach()
    set(${OUT_VAR} "${ROWS}" PARENT_SCOPE)
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
