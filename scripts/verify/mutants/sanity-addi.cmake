# =============================================================================
# Negative control for T-08 (NFR-05) - the harness must notice a broken core.
#
# `rv32ui-p-simple` has no test case: it executes `li gp,1; sw gp,tohost`, so
# the whole verdict rests on ADDI producing 1 and the store reaching `tohost`.
# Making ALU_ADD ignore its second operand turns `li gp,1` into `li gp,0`. It
# also breaks the `la t5,tohost` (AUIPC+ADDI), so the store never reaches the
# watched address: the harness must report `SANITY: TIMEOUT` and raise a UVM
# error. Detection is `status=fail` plus `uvm_errors>0`, not a case number.
#
# Applied by scripts/verify/negative_control.cmake to a disposable copy of the
# tree:  cmake -DSCRATCH=<copy> -P scripts/verify/mutants/sanity-addi.cmake
# The repository is never edited.
# =============================================================================

set(MUTANT_FILE "rtl/alu.sv")
set(MUTANT_FIND "alu_result = alu_data1.s_data + alu_data2.s_data;")
set(MUTANT_REPLACE "alu_result = alu_data1.s_data; // negative control: ADD ignores the second operand")
set(MUTANT_WHY "ADDI/ADD ignore their second operand, so `li gp,1` writes 0 and the pass store writes 0")

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
