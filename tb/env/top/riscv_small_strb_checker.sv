`ifndef RISCV_SMALL_STRB_CHECKER
`define RISCV_SMALL_STRB_CHECKER

// ============================================================================
// riscv_small_strb_checker
//
// FR-11 checker: every write the MONITOR observed must carry byte strobes that
// agree with the access width the DUT reported on data_rd_wr_ctrl.
//
// A NON-SPLIT ACCESS (captured_data_beats == 1) keeps the rule this checker has
// always had:
//
//   width 2'b00 (byte)      exactly one strobe bit set
//   width 2'b01 (halfword)  4'b0011, 4'b0110 or 4'b1100 -- the three ADJACENT
//                           byte pairs a halfword inside one word can occupy
//   width 2'b10 (word)      4'b1111
//
// The halfword set is the complete one, not just the even lanes: `0110` is the
// halfword at byte offset 1 (G-34, T-51), and a checker that rejected it would
// fail a correct core. What this arm does NOT prove is that the strobes sit at
// the lane the ADDRESS names -- a store at offset 1 driving 4'b0011 is a legal
// halfword pattern and passes here. That anchoring is the reference model's
// prediction (address + strobes + data, riscv_small_scoreboard) and the
// read-back value the program performs.
//
// A SPLIT ACCESS (captured_data_beats == 2, FR-42/G-22) is two word-aligned
// beats, and neither beat may carry `4'b1111` for a crossing word store: beat 1
// is the bytes that fit in the word the access starts in, beat 2 the bytes that
// spill into the next one. An access at lane L with `bytes` (1/2/4) crosses when
// L + bytes > 4, and the two beats are pinned, not merely bounded:
//
//   width_mask      = (1 << bytes) - 1          byte 0001, half 0011, word 1111
//   beat 1 (lane L) = (width_mask << L) & 4'hF  the SUFFIX that fits
//   beat 2 (lane 0) = (1 << spill) - 1          the PREFIX, spill = L + bytes - 4
//   union           = (beat1 >> L) | (beat2 << (4-L)) == width_mask
//
// The union is what makes the pair one access: the suffix alone and the prefix
// alone are both partial by construction, and only their concatenation is the
// width the store claimed. The address is part of the claim too: beat 2 must be
// the next word, (beat1 & ~3) + 4, and both beats must report the same width.
// A beat without its companion is an error ([STRB_SPLIT]): the union was never
// checked, so the access is not evidence. The monitor publishes
// `captured_data_beat` / `captured_data_beats`, so this checker never has to
// infer the beat from the address.
//
// This is deliberately NOT a widened set of accepted strobes: a strobe pinned to
// the wrong lane (mutant `store-lane-offset`, T-13) or one that claims all four
// bytes for a halfword (mutant `store-strb-all`, T-14) still fails, and a split
// beat that is not exactly the suffix (or the prefix) fails too.
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

  int unsigned write_count      = 0; // observed write beats, the denominator
  int unsigned split_beat_count = 0; // write beats belonging to a split access
  int unsigned split_access_count = 0; // split accesses whose two beats were compared
  int unsigned violation_count  = 0; // write beats whose strobe disagreed

  // First beat of the split write in progress. The second beat completes the
  // claim, so the union is checked when it arrives. `b1_lane` is the access's
  // byte lane, which is also beat 1's address lane.
  bit          have_beat1 = 0;
  int          b1_addr   = 0;
  int          b1_width  = 0;
  int          b1_strb   = 0;
  int          b1_lane   = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Width the DUT reported -> the byte mask of the access (byte 0001, half
  // 0011, word 1111). 2'b11 is not a width this core emits; it maps to zero, so
  // it can never match a strobe and the mismatch is reported.
  function automatic bit [3:0] width_mask(logic [1:0] width);
    case (width)
      2'b00: return 4'b0001;
      2'b01: return 4'b0011;
      2'b10: return 4'b1111;
      default: return 4'b0000;
    endcase
  endfunction

  function automatic int unsigned width_bytes(logic [1:0] width);
    case (width)
      2'b00: return 1;
      2'b01: return 2;
      2'b10: return 4;
      default: return 0;
    endcase
  endfunction

  function void violation(string id, string text);
    violation_count++;
    `uvm_error(id, $sformatf("[%s #%0d] %s", id, violation_count, text))
  endfunction

  function void write(riscv_small_transaction t);
    logic [3:0] strb;
    logic [1:0] width;
    logic [3:0] mask;
    logic [3:0] expected;
    logic [3:0] union_mask;
    int unsigned lane;
    int unsigned bytes;
    int          spill;
    bit         ok;

    // Reads have no strobes and no width contract: they are not checked.
    if (!t.op_is_data_write) return;

    write_count++;
    strb  = t.captured_data_wr_strb[3:0];
    width = t.captured_data_wr_ctrl[1:0];
    lane  = t.captured_data_addr[1:0];
    mask  = width_mask(width);
    bytes = width_bytes(width);

    // ---- a non-split access: the rule this checker has always had ----------
    if (t.captured_data_beats != 2) begin
      case (width)
        2'b00: ok = (strb inside {4'b0001, 4'b0010, 4'b0100, 4'b1000});
        2'b01: ok = (strb inside {4'b0011, 4'b0110, 4'b1100});
        2'b10: ok = (strb == 4'b1111);
        default: ok = 1'b0;
      endcase

      if (!ok)
        violation("STRB_WIDTH",
          $sformatf("store strobe/width mismatch: addr=0x%0h width=2'b%02b strobe=4'b%04b beat=%0d/%0d",
            t.captured_data_addr, width, strb,
            t.captured_data_beat, t.captured_data_beats));
      return;
    end

    // ---- a split access: beat 1 is the suffix, beat 2 the prefix -----------
    split_beat_count++;

    if (t.captured_data_beat == 1) begin
      if (have_beat1)
        violation("STRB_SPLIT",
          $sformatf("second beat 1 without a beat 2: previous beat 1 addr=0x%0h strobe=4'b%04b, new beat 1 addr=0x%0h strobe=4'b%04b",
            b1_addr, b1_strb, t.captured_data_addr, strb));

      // The suffix is exact: the bytes of the access that still fit in the word
      // the access starts in. It is never the full mask, because the access
      // crosses; if it is, the beat is a whole word and the split is wrong.
      expected = (mask << lane) & 4'hF;
      ok = (bytes != 0) && (lane + bytes > 4) &&         // it really crosses
           (expected != 4'b0000) && (expected != 4'b1111) &&
           (strb == expected);

      if (!ok)
        violation("STRB_WIDTH",
          $sformatf("split beat 1 is not the suffix of its width: addr=0x%0h lane=%0d width=2'b%02b strobe=4'b%04b expected=4'b%04b beat=1/2",
            t.captured_data_addr, lane, width, strb, expected));

      have_beat1 = 1;
      b1_addr    = t.captured_data_addr;
      b1_width   = t.captured_data_wr_ctrl[1:0];
      b1_strb    = t.captured_data_wr_strb[3:0];
      b1_lane    = lane;
      return;
    end

    if (!have_beat1) begin
      violation("STRB_SPLIT",
        $sformatf("beat 2 without a beat 1: addr=0x%0h width=2'b%02b strobe=4'b%04b beat=%0d/2",
          t.captured_data_addr, width, strb, t.captured_data_beat));
      return;
    end

    union_mask = 0;
    expected   = 0;
    spill      = b1_lane + width_bytes(b1_width[1:0]) - 4;
    if (spill > 0) begin
      expected = (4'b0001 << spill) - 4'b0001;
      // The union is the access: the suffix shifted down to its first byte,
      // concatenated with the prefix shifted up past the word it came from.
      union_mask = (b1_strb[3:0] >> b1_lane) | (strb << (4 - b1_lane));
    end

    ok = (spill > 0) &&                              // beat 1 crossed by definition
         (t.captured_data_beat == 2) &&
         (b1_lane != 0) &&
         (lane == 0) &&                              // beat 2 is word-aligned
         (t.captured_data_addr == ((b1_addr & ~32'h3) + 32'd4)) &&
         (width == b1_width[1:0]) &&
         (strb == expected) &&
         (union_mask == width_mask(b1_width[1:0]));

    if (!ok)
      violation("STRB_WIDTH",
        $sformatf("split beat 2 does not complete beat 1: addr=0x%0h (beat 1 addr=0x%0h) lane=%0d width=2'b%02b/2'b%02b strobe=4'b%04b expected=4'b%04b union=4'b%04b expected=4'b%04b",
          t.captured_data_addr, b1_addr, lane, width, b1_width[1:0], strb,
          expected, union_mask, width_mask(b1_width[1:0])));
    else
      split_access_count++;

    have_beat1 = 0;
  endfunction: write

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    // A split access whose second beat never arrived: the union was never
    // checked, so the access is not evidence. Loud, not silent.
    if (have_beat1) begin
      violation_count++;
      `uvm_error("STRB_SPLIT",
        $sformatf("[STRB_SPLIT #%0d] split access left incomplete at the end of the run: beat 1 addr=0x%0h width=2'b%02b strobe=4'b%04b was never paired with a beat 2",
          violation_count, b1_addr, b1_width[1:0], b1_strb))
    end
  endfunction: check_phase

  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("FR-11 store strobe/width: %0d write beat(s) checked (%0d in %0d split access(es)), %0d violation(s)",
        write_count, split_beat_count, split_access_count, violation_count),
      UVM_LOW)
  endfunction: report_phase

endclass: riscv_small_strb_checker

`endif
