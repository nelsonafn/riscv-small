# =============================================================================
# Negative control for T-12 (G-20) - a negative branch offset must be signed.
#
# P3b adds the full sign-extended `imm`; slicing `imm[20:0]` zero-extends a
# negative offset and sends the branch to 0x2001ec-family. The rv32ui-p-beq
# prologue loops on `beq ra,sp,0x94` at 0x98 (imm=-4) and times out.
# =============================================================================

set(MUTANT_FILE "rtl/jump_decision.sv")
set(MUTANT_FIND "jump_addr = base_addr + imm;")
set(MUTANT_REPLACE "jump_addr = base_addr + imm[20:0]; // negative control: zero-extended offset")
set(MUTANT_WHY "a negative branch/jump offset is zero-extended (G-20)")

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
