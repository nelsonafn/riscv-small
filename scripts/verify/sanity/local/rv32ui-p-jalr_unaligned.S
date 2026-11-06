# See LICENSE for license details.

#*****************************************************************************
# rv32ui-p-jalr_unaligned.S
#-----------------------------------------------------------------------------
#
# Adaptation of src/riscv-tests/isa/rv64ui/jalr.S for riscv-small, adding the
# odd-target case the bundled image never exercises. FR-07 requires a JALR
# target of (rs1 + imm) with bit 0 cleared; rv32ui-p-jalr only jumps to aligned
# labels, so it cannot observe that mask. Test 2 below is the bundled test,
# unchanged; Test 3 jumps to target_3 + 1 and checks the link value from the
# aligned target. The remaining bundled JALR cases stay covered by
# rv32ui-p-jalr (T-17).
#

#include "riscv_test.h"
#undef RVTEST_RV64U
#define RVTEST_RV64U RVTEST_RV32U

#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Test 2: Basic test (unchanged from rv64ui/jalr.S)
  #-------------------------------------------------------------

test_2:
  li  TESTNUM, 2
  li  t0, 0
  la  t1, target_2

  jalr t0, t1, 0
linkaddr_2:
  j fail

target_2:
  la  t1, linkaddr_2
  bne t0, t1, fail

  #-------------------------------------------------------------
  # Test 3: Basic test with an odd target
  #
  # target_3 is 4-byte aligned; t1 = target_3 + 1. JALR must clear bit 0, so
  # the core fetches target_3 and the link value is linkaddr_3. A core that
  # keeps bit 0 continues at an odd PC: the word at (target_3 + 1) is still
  # target_3's word in a word-addressed memory, but the PC-relative `la` below
  # then computes linkaddr_3 + 1 and the branch sends the image to fail.
  #-------------------------------------------------------------

test_3:
  li  TESTNUM, 3
  li  t0, 0
  la  t1, target_3
  addi t1, t1, 1

  jalr t0, t1, 0
linkaddr_3:
  j fail

  .align 2
target_3:
  la  t1, linkaddr_3
  bne t0, t1, fail

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
