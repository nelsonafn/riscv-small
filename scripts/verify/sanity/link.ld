/* =============================================================================
 * scripts/verify/sanity/link.ld - image layout for the riscv_small sanity run.
 *
 * The DUT resets to PC = 0 and the testbench loads the image at word 0, so the
 * entry section has to live at address 0. The suite's env/p/link.ld links at
 * 0x80000000 and the flow then rewrites the first hex line to @00000000; the
 * symbols (notably `tohost`) keep their 0x8000_xxxx value, so the harness would
 * have to mask the address. Linking at 0 makes the ELF, the hex and the
 * `nm`-extracted `tohost` agree without a mask.
 *
 * Layout: text first (the entry is the first word), then .tohost, then .data.
 * .tohost is placed right after .text so the hex has no 4 KiB hole between the
 * code and the store target. `.bss` stays last and is not part of the image:
 * the testbench's memory model returns zero for words it never loaded.
 * ========================================================================== */

OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  .text      : { *(.text) }
  . = ALIGN(8);
  .tohost    : { *(.tohost) }
  .data      : { *(.data) *(.sdata) }
  .bss       : { *(.bss) *(.sbss) *(COMMON) }
  _end = .;
}
