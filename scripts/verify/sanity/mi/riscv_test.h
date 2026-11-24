// =============================================================================
// scripts/verify/sanity/mi/riscv_test.h - the riscv-tests environment for the
// rv32mi images.
//
// rv32mi tests the MACHINE TRAP CEREMONY, so it cannot be built with
// ../riscv_test.h: that environment replaces the ceremony with a direct store
// to `tohost` because the SYSTEM group used to be a no-operation (G-13), and an
// image built that way would skip exactly the behaviour it measures.
//
// This file is the `env/p` ceremony, kept as published:
//   * `_start` jumps to `reset_vector`, which zeroes the registers, programs
//     `mtvec` with `trap_vector`, enters the body through `MRET` and leaves
//     `mepc` pointing at the first body instruction;
//   * the handler at `trap_vector` reads `mcause` and dispatches: an `ECALL`
//     from `RVTEST_PASS`/`RVTEST_FAIL` reaches `write_tohost`, which stores
//     TESTNUM in `tohost` and parks -- the protocol the suite defines, and the
//     one the testbench's sanity checker judges;
//   * an `mtvec_handler` defined by the test body wins over `other_exception`,
//     so an image can return from a trap with its own `MRET`.
//
// What is NOT here, and why. env/p also programs the PMP, `satp`, `mnstatus`
// and delegates traps through `medeleg`/`mideleg` (`INIT_PMP`, `INIT_SATP`,
// `INIT_RNMI`, `DELEGATE_NO_TRAPS`) and delegates to `stvec` when an
// `stvec_handler` exists. None of those CSRs exists in this core: the address
// map of FR-50 implements the machine group only, and an access to `pmpcfg0`,
// `satp`, `mnstatus`, `medeleg` or `mideleg` raises illegal-instruction by
// design (NUM_TRIGGERS/PMP/S are absent features, not a defect). Running that
// prologue through this core would trap in `reset_vector` and the image would
// never reach its body. The omissions are therefore the ceremony's *setup*,
// never its trap path: `mtvec`, `mepc`, `mcause`, `MRET`, `ECALL` and the
// `tohost` store are all here, and the test bodies are unmodified.
//
// Keep this file free of CSRs outside the implemented map. `fence` is RV32I;
// the suite is built with -march=rv32i_zicsr because the bodies use csrr/csrw.
// =============================================================================

#ifndef RISCV_SMALL_MI_TEST_H
#define RISCV_SMALL_MI_TEST_H

#include "encoding.h"

// The suite writes RVTEST_RV32U/RV64U before RVTEST_CODE_BEGIN, and every
// image in the corpus writes RVTEST_RV64M (or RVTEST_RV64S) itself.
// `init` runs in `reset_vector` before MRET: the M-mode init sets
// mstatus.MPP = M, which is where the core already is. The S-mode spellings
// are deliberately absent: an image that asks for S-mode must fail in the
// assembler, loudly, instead of being silently run in M-mode.
#define RVTEST_RV32U  .macro init; .endm
#define RVTEST_RV64U  RVTEST_RV32U

#define RVTEST_ENABLE_MACHINE                                                  \
  li a0, MSTATUS_MPP;                                                          \
  csrs mstatus, a0

#define RVTEST_RV32M  .macro init; RVTEST_ENABLE_MACHINE; .endm
#define RVTEST_RV64M  RVTEST_RV32M

// x1..x31 = 0. x0 is hardwired; the test macro then loads TESTNUM with 0.
#define INIT_XREG                                                              \
  li x1,0;  li x2,0;  li x3,0;  li x4,0;  li x5,0;  li x6,0;  li x7,0;         \
  li x8,0;  li x9,0;  li x10,0; li x11,0; li x12,0; li x13,0; li x14,0;        \
  li x15,0; li x16,0; li x17,0; li x18,0; li x19,0; li x20,0; li x21,0;        \
  li x22,0; li x23,0; li x24,0; li x25,0; li x26,0; li x27,0; li x28,0;        \
  li x29,0; li x30,0; li x31,0;

#define RISCV_MULTICORE_DISABLE                                                \
  csrr a0, mhartid;                                                            \
  1: bnez a0, 1b

// env/p is written for RV64 and RV32 alike; this build is RV32 only.
#if __riscv_xlen == 64
# define CHECK_XLEN li a0, 1; slli a0, a0, 31; bgez a0, 1f; RVTEST_PASS; 1:
#else
# define CHECK_XLEN li a0, 1; slli a0, a0, 31; bltz a0, 1f; RVTEST_PASS; 1:
#endif

// No interrupts are enabled by any image in this corpus (mie stays 0 and
// mstatus.MIE is cleared), so the interrupt half of the handler is the suite's
// own "we do not know how to handle this".
#define INTERRUPT_HANDLER j other_exception

#define EXTRA_INIT
#define EXTRA_INIT_TIMER
#define EXTRA_DATA

//-----------------------------------------------------------------------
// Begin Macro
//-----------------------------------------------------------------------
#define RVTEST_CODE_BEGIN                                                      \
  .section .text.init;                                                         \
  .align 6;                                                                    \
  .weak stvec_handler;                                                         \
  .weak mtvec_handler;                                                         \
  .globl _start;                                                               \
_start:                                                                        \
  /* reset vector */                                                           \
  j reset_vector;                                                              \
  .align 2;                                                                    \
trap_vector:                                                                   \
  /* test whether the test came from pass/fail */                              \
  csrr t5, mcause;                                                             \
  li t6, CAUSE_USER_ECALL;                                                     \
  beq t5, t6, write_tohost;                                                    \
  li t6, CAUSE_SUPERVISOR_ECALL;                                               \
  beq t5, t6, write_tohost;                                                    \
  li t6, CAUSE_MACHINE_ECALL;                                                  \
  beq t5, t6, write_tohost;                                                    \
  /* if an mtvec_handler is defined, jump to it */                             \
  la t5, mtvec_handler;                                                        \
  beqz t5, 1f;                                                                 \
  jr t5;                                                                       \
  /* was it an interrupt or an exception? */                                   \
1:  csrr t5, mcause;                                                           \
  bgez t5, handle_exception;                                                   \
  INTERRUPT_HANDLER;                                                           \
handle_exception:                                                              \
  /* we don't know how to handle whatever the exception was */                 \
other_exception:                                                               \
  /* some unhandlable exception occurred */                                    \
1:  ori TESTNUM, TESTNUM, 1337;                                                \
write_tohost:                                                                  \
  /* TESTNUM == 1 is PASS; any other value carries the failing case */         \
  sw TESTNUM, tohost, t5;                                                      \
  sw zero, tohost + 4, t5;                                                     \
  j write_tohost;                                                              \
reset_vector:                                                                  \
  INIT_XREG;                                                                   \
  RISCV_MULTICORE_DISABLE;                                                     \
  li TESTNUM, 0;                                                               \
  la t0, trap_vector;                                                          \
  csrw mtvec, t0;                                                              \
  CHECK_XLEN;                                                                  \
  csrwi mstatus, 0;                                                            \
  init;                                                                        \
  EXTRA_INIT;                                                                  \
  EXTRA_INIT_TIMER;                                                            \
  la t0, 1f;                                                                   \
  csrw mepc, t0;                                                               \
  csrr a0, mhartid;                                                            \
  mret;                                                                        \
1:

//-----------------------------------------------------------------------
// End Macro
//-----------------------------------------------------------------------
#define RVTEST_CODE_END unimp

//-----------------------------------------------------------------------
// Pass/Fail Macro
//-----------------------------------------------------------------------
#define TESTNUM gp

#define RVTEST_PASS                                                            \
  fence;                                                                       \
  li TESTNUM, 1;                                                               \
  li a7, 93;                                                                   \
  li a0, 0;                                                                    \
  ecall

#define RVTEST_FAIL                                                            \
  fence;                                                                       \
1:  beqz TESTNUM, 1b;                                                           \
  sll TESTNUM, TESTNUM, 1;                                                     \
  or TESTNUM, TESTNUM, 1;                                                      \
  li a7, 93;                                                                   \
  addi a0, TESTNUM, 0;                                                         \
  ecall

//-----------------------------------------------------------------------
// Data Section Macro
//-----------------------------------------------------------------------
#define RVTEST_DATA_BEGIN                                                      \
  EXTRA_DATA;                                                                  \
  .pushsection .tohost,"aw",@progbits;                                         \
  .align 6; .global tohost; tohost: .dword 0; .size tohost, 8;                 \
  .align 6; .global fromhost; fromhost: .dword 0; .size fromhost, 8;           \
  .popsection;                                                                 \
  .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
