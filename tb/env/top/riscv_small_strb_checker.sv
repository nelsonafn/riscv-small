`ifndef RISCV_SMALL_STRB_CHECKER
`define RISCV_SMALL_STRB_CHECKER

// ============================================================================
// riscv_small_strb_checker
//
// FR-11 checker: every write the MONITOR observed must carry byte strobes that
// agree with the access width the DUT reported on data_rd_wr_ctrl.
//
//   width 2'b00 (byte)      exactly one strobe bit set
//   width 2'b01 (halfword)  4'b0011 or 4'b1100
//   width 2'b10 (word)      4'b1111
//
// A zero strobe on a write, or a width outside those three, is a uvm_error
// [STRB_WIDTH] naming the address, the width and the strobe: it would let a
// store silently write nothing, or write bytes it did not claim.
//
// It is a subscriber on the monitor, so it judges what the DUT did and never
// the instruction that caused it. It is built in both the directed and the
// image (sanity) environment: the image path is where SB/SH traffic actually
// happens, and the check must not depend on the reference model being present.
// There is no FIFO and no blocking get(): write() only counts and judges, and
// report_phase prints the tally, so it can never stall an image run.
//
// Author: Nelson Alves nelsonafn@gmail.com
// ============================================================================
class riscv_small_strb_checker extends uvm_subscriber #(riscv_small_transaction);
  `uvm_component_utils(riscv_small_strb_checker)

  int unsigned write_count = 0;      // observed writes, the denominator
  int unsigned violation_count = 0;  // writes whose strobe disagreed with the width

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void write(riscv_small_transaction t);
    logic [3:0] strb;
    logic [1:0] width;
    bit         ok;

    // Reads have no strobes and no width contract: they are not checked.
    if (!t.op_is_data_write) return;

    write_count++;
    strb  = t.captured_data_wr_strb[3:0];
    width = t.captured_data_wr_ctrl[1:0];

    case (width)
      2'b00: ok = (strb inside {4'b0001, 4'b0010, 4'b0100, 4'b1000});
      2'b01: ok = (strb inside {4'b0011, 4'b1100});
      2'b10: ok = (strb == 4'b1111);
      default: ok = 1'b0;
    endcase

    if (!ok) begin
      violation_count++;
      `uvm_error("STRB_WIDTH",
        $sformatf("[STRB_WIDTH #%0d] store strobe/width mismatch: addr=0x%0h width=2'b%02b strobe=4'b%04b",
          violation_count, t.captured_data_addr, width, strb))
    end
  endfunction: write

  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("FR-11 store strobe/width: %0d write(s) checked, %0d violation(s)",
        write_count, violation_count),
      UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_strb_checker

`endif
