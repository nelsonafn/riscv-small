# =============================================================================
# Negative control for T-11 (G-26) - the EX result must be forwardable.
#
# P3 assigned `alu_ex = alu_result`; it is the EX source of the jump/ALU
# forwarding. Leaving it X reintroduces the missing forward: the immediately
# preceding instruction's value does not reach the next consumer, and
# rv32ui-p-addi fails after the first forwarded case.
# =============================================================================

set(MUTANT_FILE "rtl/execution.sv")
set(MUTANT_FIND "assign alu_ex = alu_result;")
set(MUTANT_REPLACE "assign alu_ex = 'x; // negative control: EX forward source missing")
set(MUTANT_WHY "the EX-stage forward source is unknown, so the predecessor's value is lost (G-26)")

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
