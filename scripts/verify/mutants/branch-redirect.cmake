# =============================================================================
# Negative control for T-10 (G-27) - the branch target must keep its own PC.
#
# P2 aligned the decoder PC with the returned instruction (`pc_id <= pc_fetch`).
# Reverting that line to the current `pc` reintroduces the one-instruction
# misalignment: a branch at 0xa0 targets 0x53c instead of 0x538, the fail-path
# `slli` is skipped and rv32ui-p-and reports the corrupted testnum.
# =============================================================================

set(MUTANT_FILE "rtl/instruction_fetch.sv")
set(MUTANT_FIND "pc_id <= pc_fetch;")
set(MUTANT_REPLACE "pc_id <= pc; // negative control: one-instruction PC misalignment")
set(MUTANT_WHY "the decoder sees the next instruction's PC, so a branch target is +4 (G-27)")

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
