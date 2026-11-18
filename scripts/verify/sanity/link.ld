/* =============================================================================
 * scripts/verify/sanity/link.ld - image layout for the riscv_small sanity run.
 *
 * The image is linked where the DUT fetches it: RESET_VECTOR, default
 * 0x8000_0000 (FR-41, Q-33). That is also where the suite's own env/p/link.ld
 * links, so an ELF built here runs on Spike with no remapping.
 *
 * The testbench's memory model is still 0-based. The rebase happens in the hex
 * conversion (scripts/verify/sanity.cmake): `objcopy --change-addresses=
 * -0x80000000` moves every section down to an offset, so word 0 of the hex is
 * word 0 of the model, while every ELF symbol -- notably `tohost` -- keeps its
 * absolute 0x8000_xxxx value. The sanity checker compares that `nm`-extracted
 * `tohost` with the DUT's absolute `data_addr`, without a mask.
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
  . = 0x80000000;
  .text.init : { *(.text.init) }
  .text      : { *(.text) }
  . = ALIGN(8);
  .tohost    : { *(.tohost) }
  .data      : { *(.data) *(.sdata) }
  .bss       : { *(.bss) *(.sbss) *(COMMON) }
  _end = .;
}
