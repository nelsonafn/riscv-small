# =============================================================================
# Negative control for T-06 (FR-12) - the defect the test must catch.
#
# The pre-fix core ignored the low address bits and always extended the byte at
# the highest address, so 8 of the 12 T-06 cases stored the wrong value. Pinning
# the lane to 3 reproduces exactly that: a sub-word load from offset 0..2 takes
# the wrong byte or halfword.
#
# Applied by scripts/verify/negative_control.cmake to a disposable copy of the
# tree:  cmake -DSCRATCH=<copy> -P scripts/verify/mutants/T-06.cmake
# The repository is never edited.
# =============================================================================

set(MUTANT_FILE "rtl/memory_access.sv")
set(MUTANT_FIND "assign ld_lane = alu_wb.u_data[1:0];")
set(MUTANT_REPLACE "assign ld_lane = 2'b11; // negative control: lane never selected")
set(MUTANT_WHY "the sub-word lane is not selected from the address (pre-fix FR-12)")

if(NOT SCRATCH)
    message(FATAL_ERROR "mutant: pass -DSCRATCH=<tree copy>")
endif()

set(PATH "${SCRATCH}/${MUTANT_FILE}")
if(NOT EXISTS "${PATH}")
    message(FATAL_ERROR "mutant: ${PATH} does not exist")
endif()

file(READ "${PATH}" TEXT)
string(REPLACE "${MUTANT_FIND}" "" STRIPPED "${TEXT}")
string(LENGTH "${TEXT}" LEN_FULL)
string(LENGTH "${STRIPPED}" LEN_STRIPPED)
string(LENGTH "${MUTANT_FIND}" LEN_NEEDLE)
math(EXPR COUNT "(${LEN_FULL} - ${LEN_STRIPPED}) / ${LEN_NEEDLE}")

if(NOT COUNT EQUAL 1)
    message(FATAL_ERROR "mutant: '${MUTANT_FIND}' occurs ${COUNT} time(s) in ${MUTANT_FILE}; the mutant is stale")
endif()

string(REPLACE "${MUTANT_FIND}" "${MUTANT_REPLACE}" MUTATED "${TEXT}")
file(WRITE "${PATH}" "${MUTATED}")
message(STATUS "mutant: ${MUTANT_FILE} <- ${MUTANT_WHY}")
