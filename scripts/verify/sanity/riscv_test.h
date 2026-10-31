// =============================================================================
// scripts/verify/sanity/riscv_test.h - the riscv-tests environment for
// riscv_small.
//
// The bundled suite builds against env/p, which assumes Zicsr, MRET and a
// machine trap handler: RVTEST_CODE_BEGIN programs mtvec/mstatus and MRET, and
// RVTEST_PASS/RVTEST_FAIL signal through ECALL -> trap_vector -> a store to
// `tohost`. riscv_small decodes the whole SYSTEM opcode group as a no-operation
// (G-13), so an image built with env/p runs its test body and then disappears:
// the ECALL writes nothing and the harness can never see a verdict.
//
// This environment keeps every test body byte-for-byte as published and only
// replaces the ceremony around it:
//   * _start zeroes the registers and falls straight into the test body;
//   * PASS writes 1 to `tohost` and parks;
//   * FAIL writes (TESTNUM << 1) | 1 to `tohost` and parks.
// That is the same protocol the suite defines (tohost == 1 means pass, any
// other value carries the failing TEST_CASE number), only without the trap.
//
// The testbench watches the store to `tohost`, which is a symbol in the ELF and
// reaches it as +TOHOST (never as a literal: link.ld may move it).
//
// Keep this file free of CSR instructions. `fence` is RV32I; `fence.i` is
// Zifencei and only the fence_i image is built with that extension.
// =============================================================================

#ifndef RISCV_SMALL_TEST_H
#define RISCV_SMALL_TEST_H

#include "encoding.h"

// The suite writes RVTEST_RV64U / RVTEST_RV32U before RVTEST_CODE_BEGIN. Both
// only define the empty `init` macro here: there is nothing to initialise.
#define RVTEST_RV32U  .macro init; .endm
#define RVTEST_RV64U  RVTEST_RV32U

// x1..x31 = 0. x0 is hardwired; the test macro then loads TESTNUM with 0.
#define INIT_XREG                                                              \
  li x1,0;  li x2,0;  li x3,0;  li x4,0;  li x5,0;  li x6,0;  li x7,0;         \
  li x8,0;  li x9,0;  li x10,0; li x11,0; li x12,0; li x13,0; li x14,0;        \
  li x15,0; li x16,0; li x17,0; li x18,0; li x19,0; li x20,0; li x21,0;        \
  li x22,0; li x23,0; li x24,0; li x25,0; li x26,0; li x27,0; li x28,0;        \
  li x29,0; li x30,0; li x31,0;

#define RVTEST_CODE_BEGIN                                                      \
  .section .text.init;                                                         \
  .align 6;                                                                    \
  .globl _start;                                                               \
_start:                                                                        \
  INIT_XREG;                                                                   \
  li TESTNUM, 0;                                                               \
  init;                                                                        \
1:

#define RVTEST_CODE_END unimp

#define TESTNUM gp

// sw uses t5 for the symbol address: `sw TESTNUM, tohost, t5` expands to
// `la t5, tohost; sw TESTNUM, 0(t5)`, which stays PC-relative and survives the
// relocation to address 0.
#define RVTEST_PASS                                                            \
  li TESTNUM, 1;                                                               \
  sw TESTNUM, tohost, t5;                                                      \
1: j 1b

#define RVTEST_FAIL                                                            \
  sll TESTNUM, TESTNUM, 1;                                                     \
  ori TESTNUM, TESTNUM, 1;                                                     \
  sw TESTNUM, tohost, t5;                                                      \
1: j 1b

#define RVTEST_DATA_BEGIN                                                      \
  .pushsection .tohost,"aw",@progbits;                                         \
  .align 6; .global tohost; tohost: .dword 0; .size tohost, 8;                 \
  .align 6; .global fromhost; fromhost: .dword 0; .size fromhost, 8;           \
  .popsection;                                                                 \
  .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
