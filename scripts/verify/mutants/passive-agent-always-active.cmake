# =============================================================================
# Negative control for T-09 (WP-4b) - the passive topology must be observable.
#
# T-09 sets is_active=UVM_PASSIVE and requires the agent to build the monitor
# only. Removing the guard makes the agent build the driver (and sequencer) in
# passive mode; the test must fail with a UVM error. This gives check 11 a
# reproducible red for a configuration-only test, instead of a one-off log.
# =============================================================================

set(MUTANT_FILE "tb/env/agents/riscv_small_agent/riscv_small_agent.sv")
set(MUTANT_FIND "    if (is_active == UVM_ACTIVE) begin")
set(MUTANT_REPLACE "    if (1'b1) begin // negative control: UVM_PASSIVE ignored")
set(MUTANT_WHY "the agent builds the driver/sequencer even when is_active=UVM_PASSIVE")

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
