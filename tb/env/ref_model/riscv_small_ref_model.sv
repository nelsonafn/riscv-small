//------------------------------------------------------------------------------
// Reference model: architectural state fed by the monitor's retire and trap
//------------------------------------------------------------------------------
// The model is an ISS for the load/store subset (G-04) plus the machine-mode
// CSR file and the trap entry (WP-14, E6). It executes the instruction the
// RETIRE event carries, in its own register file, its own data memory and its
// own CSR file, and it applies the trap the TRAP event carries to that same
// state. It publishes three kinds of prediction:
//
//   store        one per retired store -- the byte address, the byte strobes and
//                the lane-placed data word the data port must carry (WP-6..13);
//   retire       one per retire event, saying whether the instruction writes its
//                destination register, with which value, or -- for an encoding
//                that must trap -- that it must not have retired at all
//                (FR-24/FR-47/FR-50: a *CSR* the configuration does not
//                implement, a write to a read-only address, an unallocated
//                encoding);
//   trap         one per trap event, carrying the cause DERIVED FROM
//                `trap_inst` (illegal -> 2, EBREAK -> 3, ECALL -> 11) so the
//                scoreboard can compare a prediction against the cause the core
//                took instead of repeating it (wp-14 §4.2).
//
// Why the trap event is an input at all: the instruction that traps is flushed
// before write-back and never retires, so a model fed only by retire is blind
// to exactly the event the trap path implements. Inferring it from a pc
// discontinuity does not work either -- a jump produces the same discontinuity.
//
// The model is a STREAMING ISS: it executes each observation in the order the
// monitor publishes it, so the publication order IS the architectural order
// (WP-14b, audit blocker 1). The monitor guarantees it -- the instruction
// retiring in WB is older than the one trapping in ID in the same cycle, so the
// commit is published before the trap. A model that reordered on its own would
// need a buffer and a flush trigger, and the last trap of a run would be replayed
// by nothing.
//
// Two oracle defects corrected here, and one divergence recorded:
//   - `cycle`/`cycleh` and `instret`/`instreth` are VIEWS of the machine
//     counters, not separate registers (FR-50; vol. II §2.1.1.10). A write to
//     `mcycle`/`mcycleh`/`minstret`/`minstreth` changes what the read-only
//     aliases return, and a low half written as 0xFFFF_FFFF carries into the
//     high half, which is what makes the high half predictable without the
//     model ever counting a clock. `time`/`timeh` were already the `mtime`
//     view and are unchanged.
//   - CSRRS/CSRRC/CSRRSI/CSRRCI suppress their write when the source field is
//     x0/0 -- the REGISTER SPECIFIER, never the VALUE (vol. I, Zicsr). A
//     non-x0 register holding zero still writes, so a `csrrs` from it to a
//     read-only address still raises illegal-instruction.
//   - RECORDED, NOT FIXED: `system_cause` treats every funct3 = 000 SYSTEM
//     encoding as ECALL/EBREAK/MRET/WFI whatever its rd/rs1 fields hold, while
//     the spec makes an ECALL/EBREAK encoding with non-zero rd or rs1 reserved
//     and therefore illegal. The core mirrors this model, so no test in this
//     work package can tell the two apart: the divergence is known and
//     unexercised, and belongs to the work package that owns the reserved
//     SYSTEM encodings.
//
// What the model does NOT receive:
//   - the program (no program feed, no analysis FIFO, no export of its own).
//     Only the monitor feeds it, through `mon_export` (C-16, AGENTS.md
//     responsibility 9).
//   - any transaction from the driver or the sequence.
//   - `mtime` or `hart_id` as configuration (D13). They arrive on every retire
//     and every trap event, as the MONITOR observed them; the model predicts
//     `time`/`timeh` (FR-49) and `mhartid` (FR-32) from those observations. A
//     config_db value would be a second source of truth and would let a DUT
//     that reads a constant pass.
//   - the external trap request as configuration. The `exception[3:0]` value a
//     trap was taken with arrives on the trap event (`obs_exception`), sampled
//     by the monitor off the DUT's own input pin; a legal instruction that
//     trapped took the PLATFORM's cause (FR-22, Q-35), and the model derives
//     the expected cause from that observation, never from the test's schedule.
//
// What it DOES receive as configuration:
//   - riscv_small_program_image, once, for the initial content of its data
//     memory. That is the "initial state" of the machine, not a stream: it is
//     read lazily on the first retire event, because the sequence fills it in
//     run_phase, after every build_phase has run.
//   - `isa_a`/`isa_m`/`isa_c`, the extension set of the built configuration
//     `misa` must advertise (FR-37). This is a property of the MACHINE the
//     model represents, not an observation: the DUT has no ENABLE_A parameter
//     to observe, and the requirement says `misa` reports what the build
//     executes. Both default to 0, which is the RV32I-only build of this WP.
//
// Why retire and not fetch: `if_id_flush` discards an instruction the monitor
// already saw accepted, so a fetch-driven model executes what the core never
// retired (G-28). The retire event is self-contained -- it carries the
// instruction word -- so there is no pc -> word table and no fetch pairing to
// get wrong.
//
// Why it runs in a passive agent: there is no run_phase at all. Every
// observation is consumed in the analysis write() function, so the model never
// blocks on a FIFO and never needs a sequencer or a driver to exist.
//
// Author: Nelson Alves nelsonafn@gmail.com
//------------------------------------------------------------------------------

`ifndef RISCV_SMALL_REF_MODEL
`define RISCV_SMALL_REF_MODEL

`uvm_analysis_imp_decl(_mon)

class riscv_small_ref_model extends uvm_component;

  `uvm_component_utils(riscv_small_ref_model)

  // ---- TLM ports -----------------------------------------------------------
  // Input: everything the monitor publishes (fetch, data, retire, trap). Only
  // the retire and trap events are executed; the rest are ignored by
  // `write_mon`.
  uvm_analysis_imp_mon #(riscv_small_transaction, riscv_small_ref_model) mon_export;
  // Output: store, retire and trap predictions for the Scoreboard. The consumer
  // dispatches by type; store predictions keep their positional 1:1 pairing.
  uvm_analysis_port #(riscv_small_transaction) rm2sb_port;

  // ---- Configuration (not a transaction) -----------------------------------
  riscv_small_program_image image; // initial data memory, or null
  bit isa_a;                       // ENABLE_A = 1, FR-35 implemented (FR-37)
  bit isa_m;                       // FR-43 implemented (FR-37)
  bit isa_c;                       // FR-44 implemented (FR-37)

  // ---- Architectural state -------------------------------------------------
  int          reg_file [32];      // x0 is hardwired to zero
  int          iss_mem  [int];     // data memory, indexed by word address
  bit          mem_initialised;    // the image is copied in once
  int unsigned commit_count;       // retire events executed
  int unsigned pred_count;         // predictions published (all kinds)
  int unsigned store_pred_count;   // store predictions published
  int unsigned retire_pred_count;  // retire predictions published
  int unsigned trap_pred_count;    // trap predictions that expect a trap
  int unsigned must_trap_count;    // instructions that retired but owed a trap
  int unsigned unknown_read_count; // CSR reads whose value the model cannot predict

  // ---- CSR file (FR-50) ----------------------------------------------------
  // Byte-address keyed, exactly as the instruction encodes it. `csr_written`
  // separates a register whose value the model knows from reset (mscratch,
  // FR-51) or because it is read-only (mtval) from one whose reset value the
  // standard leaves UNSPECIFIED (A-04: mtvec, mepc, mcause). A read of the
  // latter is predicted only after the program wrote it. The machine counters
  // are NOT stored here: they have their own 64-bit storage below, because
  // `cycle`/`instret` read it rather than a register of their own.
  bit [31:0] csr_state   [bit [11:0]];
  bit        csr_written [bit [11:0]];

  // ---- Machine counters (FR-50; vol. II §2.1.1.10) --------------------------
  // `mcycle`/`minstret` are 64-bit and `cycle`/`instret` are VIEWS of them, not
  // separate registers. The model never counts clocks, so:
  //   - a high half is a prediction only once the program wrote it
  //     (`*_hi_known`);
  //   - a low half is never a prediction (the model cannot know the cycle, or
  //     the retire, at which the read happened after a write), but a low half
  //     written as 0xFFFF_FFFF carries EXACTLY once into the high half before
  //     the next observation -- which is an architectural consequence of the
  //     write, not a guess;
  //   - `instret`/`minstret` keep the retire count as their prediction only
  //     while the low half was never written (`minstret_lo_written`).
  bit [63:0] mcycle_v;
  bit [63:0] minstret_v;
  bit        mcycle_hi_known;
  bit        minstret_hi_known;
  bit        minstret_lo_written;
  bit        mcycle_wrap;      // a low half of 0xFFFF_FFFF is still due to carry
  bit        minstret_wrap;

  // ---- D13: the DUT's straps as the monitor observed them ------------------
  bit [63:0] mtime_obs;
  bit [3:0]  hart_id_obs;

  // ---- CSR addresses this model names --------------------------------------
  localparam bit [11:0] CSR_MSTATUS    = 12'h300;
  localparam bit [11:0] CSR_MISA       = 12'h301;
  localparam bit [11:0] CSR_MIE        = 12'h304;
  localparam bit [11:0] CSR_MTVEC      = 12'h305;
  localparam bit [11:0] CSR_MSTATUSH   = 12'h310;
  localparam bit [11:0] CSR_MSCRATCH   = 12'h340;
  localparam bit [11:0] CSR_MEPC       = 12'h341;
  localparam bit [11:0] CSR_MCAUSE     = 12'h342;
  localparam bit [11:0] CSR_MTVAL      = 12'h343;
  localparam bit [11:0] CSR_MIP        = 12'h344;
  localparam bit [11:0] CSR_MCYCLE     = 12'hB00;
  localparam bit [11:0] CSR_MINSTRET   = 12'hB02;
  localparam bit [11:0] CSR_MCYCLEH    = 12'hB80;
  localparam bit [11:0] CSR_MINSTRETH  = 12'hB82;
  localparam bit [11:0] CSR_CYCLE      = 12'hC00;
  localparam bit [11:0] CSR_TIME       = 12'hC01;
  localparam bit [11:0] CSR_INSTRET    = 12'hC02;
  localparam bit [11:0] CSR_CYCLEH     = 12'hC80;
  localparam bit [11:0] CSR_TIMEH      = 12'hC81;
  localparam bit [11:0] CSR_INSTRETH   = 12'hC82;
  localparam bit [11:0] CSR_MVENDORID  = 12'hF11;
  localparam bit [11:0] CSR_MARCHID    = 12'hF12;
  localparam bit [11:0] CSR_MIMPID     = 12'hF13;
  localparam bit [11:0] CSR_MHARTID    = 12'hF14;
  localparam bit [11:0] CSR_MCONFIGPTR = 12'hF15;

  // Trap causes of this WP (FR-22, FR-25; wp-14 §2.1).
  localparam bit [3:0] CAUSE_ILLEGAL    = 4'd2;
  localparam bit [3:0] CAUSE_BREAKPOINT = 4'd3;
  localparam bit [3:0] CAUSE_ECALL_M    = 4'd11;

  // ---- Constructor ---------------------------------------------------------
  function new(string name = "riscv_small_ref_model", uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---- Build phase ---------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_export = new("mon_export", this);
    rm2sb_port = new("rm2sb_port", this);
    if (!uvm_config_db#(riscv_small_program_image)::get(this, "", "program_image", image))
      image = null;
    // The extension set of the build `misa` must report (FR-37). Defaults are
    // the RV32I-only build: no A, no M, no C.
    if (!uvm_config_db#(bit)::get(this, "", "isa_a", isa_a)) isa_a = 0;
    if (!uvm_config_db#(bit)::get(this, "", "isa_m", isa_m)) isa_m = 0;
    if (!uvm_config_db#(bit)::get(this, "", "isa_c", isa_c)) isa_c = 0;
    clear_state();
  endfunction

  function void clear_state();
    for (int i = 0; i < 32; i++) reg_file[i] = 0; // x0 is always zero
    iss_mem.delete();
    mem_initialised = 0;
    commit_count = 0;
    pred_count = 0;
    store_pred_count = 0;
    retire_pred_count = 0;
    trap_pred_count = 0;
    must_trap_count = 0;
    unknown_read_count = 0;
    csr_state.delete();
    csr_written.delete();
    mcycle_v = '0;
    minstret_v = '0;
    mcycle_hi_known = 1'b0;
    minstret_hi_known = 1'b0;
    minstret_lo_written = 1'b0;
    mcycle_wrap = 1'b0;
    minstret_wrap = 1'b0;
    // FR-51: mscratch resets to zero -- a project promise for determinism, so
    // the model may start it known. Every other R/W CSR starts unknown and is
    // predicted only after the program wrote it (A-04).
    csr_state[CSR_MSCRATCH] = '0;
    csr_written[CSR_MSCRATCH] = 1'b1;
    mtime_obs = '0;
    hart_id_obs = '0;
  endfunction

  // The image is configuration: read once, at the first commit, so the
  // sequence has already filled it. A reader never sees the memory the driver
  // mutates, and the DUT's own stores update only this model's copy.
  function void init_memory();
    if (mem_initialised) return;
    mem_initialised = 1;
    if (image == null) return;
    foreach (image.data[byte_addr])
      iss_mem[byte_addr >> 2] = image.data[byte_addr];
    `uvm_info(get_full_name(),
      $sformatf("ISS: data memory initialised from the program image (%0d word(s))", image.data_size()),
      UVM_MEDIUM)
  endfunction

  // ---- Observation: the only input -----------------------------------------
  function void write_mon(riscv_small_transaction t);
    // D13: the straps are part of every observation. They are sampled here and
    // nowhere else, so `time`/`timeh`/`mhartid` are predictions from what the
    // DUT was fed, never from what the test configured.
    if (t.op_is_retire || t.op_is_trap) begin
      mtime_obs   = t.obs_mtime;
      hart_id_obs = t.obs_hart_id;
      // The counters advanced since the previous observation -- see the function.
      advance_counters();
    end

    if (t.op_is_trap) begin
      apply_trap(t);
      return;
    end
    if (!t.op_is_retire) return;
    commit_count++;
    execute(t.retire_pc, t.retire_inst);
  endfunction

  // Every observation is separated from the previous one by at least one clock
  // edge, so a low half written as 0xFFFF_FFFF has carried exactly once by the
  // time the next instruction is executed. That is the only way this model can
  // predict `cycleh`/`instreth` after such a write: it knows the carry HAPPENED
  // without ever counting the clocks that produced it. No second carry is
  // possible (2^32 increments), so one advance is all a prediction needs.
  function void advance_counters();
    if (mcycle_wrap) begin
      mcycle_v[63:32] += 32'd1;
      mcycle_wrap = 1'b0;
    end
    if (minstret_wrap) begin
      minstret_v[63:32] += 32'd1;
      minstret_wrap = 1'b0;
    end
  endfunction

  // ==========================================================================
  // Trap entry (FR-22/FR-23/FR-24/FR-25/FR-50)
  // ==========================================================================
  // The model both PREDICTS (the cause, from the instruction word) and APPLIES
  // (mepc/mcause into its own state, which the handler's read-backs are then
  // compared against).
  function void apply_trap(riscv_small_transaction t);
    riscv_small_transaction p;
    bit [3:0] expected;
    bit       external;
    int unsigned n;

    // Priority, mirrored from `proc_trap_priority` (rtl/control.sv): the
    // instruction's OWN cause belongs to the instruction in ID and wins; the
    // platform's request on `exception[3:0]` is the arm taken only when the
    // instruction is legal. The model reads that request from the event
    // (`obs_exception`), never from configuration (D13, FR-22/Q-35): the pin is
    // the platform's stimulus and the monitor observed it.
    expected = trap_cause_of(t.trap_inst);
    external = 1'b0;
    if (expected == 0 && (t.obs_exception != 4'b0000)) begin
      // A legal instruction trapped because the platform asked for it: the cause
      // is the code that was standing on the bus, and the instruction must not
      // have executed (it never retires -- the emit below is the only
      // prediction for it).
      expected = t.obs_exception;
      external = 1'b1;
    end

    p = riscv_small_transaction::type_id::create("pred_trap");
    p.op_is_pred_trap = 1;
    p.pred_pc         = t.trap_pc;
    p.pred_claim      = 1;

    if (expected == 0) begin
      // A legal instruction took a trap: FR-52 (a write to mtval is accepted and
      // ignored) and the `rs1 = x0` clause of FR-50 are the cases a spurious
      // trap would break. The scoreboard turns this into the verdict.
      p.pred_should_trap = 0;
      p.pred_cause       = 0;
      `uvm_info(get_full_name(),
        $sformatf("ISS TRAP @0x%08h inst=0x%08h: the instruction is legal, no trap was expected (observed cause %0d)",
          t.trap_pc, t.trap_inst, t.trap_cause),
        UVM_MEDIUM)
    end else begin
      p.pred_should_trap = 1;
      p.pred_cause       = expected;
      trap_pred_count++;

      // mepc: the trapping instruction itself, mepc[1:0] = 0 (FR-23, IALIGN=32).
      csr_state[CSR_MEPC]   = t.trap_pc & ~32'h3;
      csr_written[CSR_MEPC] = 1'b1;
      // mcause: an exception, so bit 31 is clear (FR-23).
      csr_state[CSR_MCAUSE]   = {28'b0, expected};
      csr_written[CSR_MCAUSE] = 1'b1;
      `uvm_info(get_full_name(),
        $sformatf("ISS TRAP @0x%08h inst=0x%08h: predicted cause %0d (observed %0d, %s), mepc=0x%08h",
          t.trap_pc, t.trap_inst, expected, t.trap_cause,
          external ? "the platform's request on exception[3:0]" : "the instruction's own encoding",
          csr_state[CSR_MEPC]),
        UVM_HIGH)
    end

    pred_count++;
    rm2sb_port.write(p);
  endfunction

  // Expected cause of an instruction, derived from the ENCODING alone. 0 means
  // "this instruction is legal": it must retire, unless the platform is asking
  // for a trap on it, which is `apply_trap`'s external arm and comes from the
  // observation (`obs_exception`), not from this function. This is the
  // prediction the trap-by-trap comparison rests on (wp-14 §4.2): publishing
  // only the cause would leave the model repeating the DUT's value.
  function bit [3:0] trap_cause_of(bit [31:0] inst);
    bit [6:0] opcode = inst[6:0];
    bit [2:0] funct3 = inst[14:12];

    case (opcode)
      7'b0110111, 7'b0010111, 7'b1101111: return 4'd0;           // LUI, AUIPC, JAL
      7'b1100111: return (funct3 == 3'b000) ? 4'd0 : CAUSE_ILLEGAL; // JALR
      7'b1100011: begin                                           // BRANCH
        case (funct3)
          3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: return 4'd0;
          default: return CAUSE_ILLEGAL;                          // 010, 011 reserved
        endcase
      end
      7'b0000011: begin                                           // LOAD
        case (funct3)
          3'b000, 3'b001, 3'b010, 3'b100, 3'b101: return 4'd0;
          default: return CAUSE_ILLEGAL;                          // 011, 110, 111
        endcase
      end
      7'b0100011: begin                                           // STORE
        case (funct3)
          3'b000, 3'b001, 3'b010: return 4'd0;
          default: return CAUSE_ILLEGAL;                          // 011..111
        endcase
      end
      7'b0010011: begin                                           // OP-IMM
        // The shifts are the arm with a funct7 field in RV32: 0000000 for
        // SLLI/SRLI, 0100000 for SRAI. Every other reserved encoding traps
        // (Q-05), so a wrong funct7 is illegal and not silently the shift.
        if (funct3 == 3'b001)
          return (inst[31:25] == 7'b0000000) ? 4'd0 : CAUSE_ILLEGAL;
        if (funct3 == 3'b101)
          return ((inst[31:25] == 7'b0000000) || (inst[31:25] == 7'b0100000)) ? 4'd0 : CAUSE_ILLEGAL;
        return 4'd0;
      end
      7'b0110011: begin                                           // OP
        if (funct3 == 3'b000 || funct3 == 3'b101)
          return ((inst[31:25] == 7'b0000000) || (inst[31:25] == 7'b0100000)) ? 4'd0 : CAUSE_ILLEGAL;
        return (inst[31:25] == 7'b0000000) ? 4'd0 : CAUSE_ILLEGAL;
      end
      // FENCE/FENCE.I: reserved configurations are treated as FENCE (FR-26).
      7'b0001111: return 4'd0;
      7'b1110011: return system_cause(inst);
      // Every other opcode is outside the implemented subset of §4.1 (Q-05).
      default: return CAUSE_ILLEGAL;
    endcase
  endfunction

  // SYSTEM (1110011): ECALL/EBREAK/MRET/WFI by imm, the CSR* group by funct3.
  function bit [3:0] system_cause(bit [31:0] inst);
    bit [2:0]  funct3 = inst[14:12];
    bit [11:0] csr    = inst[31:20];
    bit [4:0]  rs1    = inst[19:15];
    bit        write;

    if (funct3 == 3'b000) begin
      // Known divergence, recorded and unexercised (see the file header): the
      // spec makes an ECALL/EBREAK encoding with a non-zero rd or rs1 field
      // reserved -- illegal-instruction -- and this arm ignores both fields, as
      // the core does. No test in this WP can tell the two apart.
      case (csr)
        12'h000: return CAUSE_ECALL_M;      // ECALL (FR-25)
        12'h001: return CAUSE_BREAKPOINT;   // EBREAK (FR-25)
        // MRET (FR-45) and WFI (FR-46) are carved out of FR-24: neither is an
        // illegal instruction in machine mode, and this WP neither implements
        // MRET's return nor has an interrupt to wake from, so both retire.
        12'h302, 12'h105: return 4'd0;
        default: return CAUSE_ILLEGAL;
      endcase
    end
    if (funct3 == 3'b100) return CAUSE_ILLEGAL;   // no Zicsr op uses funct3 100

    // FR-50: an address the configuration does not implement traps.
    if (!csr_implemented(csr)) return CAUSE_ILLEGAL;

    // FR-47/FR-50: only a WRITE to a read-only address traps. CSRRW/CSRRWI
    // always write; CSRRS/CSRRC/CSRRSI/CSRRCI write only when their source
    // field is not x0/0. The test is the REGISTER SPECIFIER, never the value
    // (vol. I, Zicsr): a non-x0 register holding zero still writes.
    write  = ((funct3 == 3'b001) || (funct3 == 3'b101)) ? 1'b1 : (rs1 != 5'd0);
    if (write && csr_read_only(csr)) return CAUSE_ILLEGAL;

    return 4'd0;
  endfunction

  // FR-50 address map: exactly the addresses of the five groups, with the
  // trigger window absent (NUM_TRIGGERS = 0) and the debug registers absent
  // outside debug mode.
  function bit csr_implemented(bit [11:0] addr);
    case (addr)
      CSR_MSTATUS, CSR_MISA, CSR_MIE, CSR_MTVEC, CSR_MSTATUSH,
      CSR_MSCRATCH, CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MIP,
      CSR_MCYCLE, CSR_MINSTRET, CSR_MCYCLEH, CSR_MINSTRETH,
      CSR_CYCLE, CSR_TIME, CSR_INSTRET, CSR_CYCLEH, CSR_TIMEH, CSR_INSTRETH,
      CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID, CSR_MCONFIGPTR:
        return 1'b1;
      default: begin
        // The performance counters (FR-50): RO zero, and a write to one of them
        // is accepted and ignored because it is a R/W address whose bits are
        // read-only.
        if ((addr >= 12'hB03) && (addr <= 12'hB1F)) return 1'b1;
        if ((addr >= 12'h323) && (addr <= 12'h33F)) return 1'b1;
        return 1'b0;
      end
    endcase
  endfunction

  // FR-50 write rule, read from the ADDRESS: csr[11:10] = 2'b11 is a read-only
  // address, and a write there raises illegal-instruction.
  function bit csr_read_only(bit [11:0] addr);
    return (addr[11:10] == 2'b11);
  endfunction

  // Which bits of a R/W address a write can change (FR-50, vol. II §1.1.1).
  // 0 means the write is accepted, changes nothing and does not trap.
  function bit [31:0] csr_write_mask(bit [11:0] addr);
    case (addr)
      CSR_MISA, CSR_MSTATUSH, CSR_MTVAL, CSR_MIP: return 32'h0;
      default: begin
        if ((addr >= 12'hB03) && (addr <= 12'hB1F)) return 32'h0;
        if ((addr >= 12'h323) && (addr <= 12'h33F)) return 32'h0;
        return 32'hFFFF_FFFF;
      end
    endcase
  endfunction

  // FR-37: misa reports the CONFIGURED extension set, never a literal.
  function bit [31:0] misa_value();
    bit [31:0] v;
    v = 32'h0;
    v[31:30] = 2'b01;      // MXL = 1: RV32
    v[8]     = 1'b1;       // I: always present
    if (isa_m) v[12] = 1'b1;
    if (isa_c) v[2]  = 1'b1;
    if (isa_a) v[0]  = 1'b1;
    return v;
  endfunction

  // Read a CSR. `known` says whether the value is a prediction the scoreboard
  // may compare: a free-running counter is not, and a register whose reset
  // value the standard leaves UNSPECIFIED is only known once the program wrote
  // it (A-04). The caller states the skip instead of comparing a guess.
  function void csr_read(bit [11:0] addr, output bit [31:0] value, output bit known);
    value = 32'h0;
    known = 1'b0;
    case (addr)
      CSR_MISA:      begin value = misa_value();                  known = 1'b1; end
      CSR_MSTATUSH:  begin value = 32'h0;                          known = 1'b1; end
      CSR_MTVAL:     begin value = 32'h0;                          known = 1'b1; end  // FR-52
      CSR_MIP:       begin value = 32'h0;                          known = 1'b1; end  // no interrupt inputs
      CSR_TIME:      begin value = mtime_obs[31:0];                known = 1'b1; end  // FR-49, D13
      CSR_TIMEH:     begin value = mtime_obs[63:32];               known = 1'b1; end
      // FR-50: `instret`/`instreth` are views of `minstret`, `cycle`/`cycleh`
      // of `mcycle` (vol. II §2.1.1.10) -- one counter, two addresses. A low
      // half is never a prediction (the model never sees a clock); a high half
      // is, once the program wrote it, because the low half cannot wrap 2^32
      // times before the next observation.
      CSR_INSTRET, CSR_MINSTRET: begin
        if (minstret_lo_written) begin
          // The program replaced the retire count: the low half now counts
          // from the value it wrote, and the model does not follow it.
          value = 32'h0;
          known = 1'b0;
        end else begin
          // Instructions retired before this one. ECALL/EBREAK never retire, so
          // they are not in `commit_count` to begin with (FR-49).
          value = commit_count - 1;
          known = 1'b1;
        end
      end
      CSR_INSTRETH, CSR_MINSTRETH:
                     begin value = minstret_v[63:32];   known = minstret_hi_known; end
      CSR_CYCLEH, CSR_MCYCLEH:
                     begin value = mcycle_v[63:32];     known = mcycle_hi_known; end
      CSR_MHARTID:   begin value = {28'b0, hart_id_obs};           known = 1'b1; end  // FR-32, D13
      CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MCONFIGPTR:
                     begin value = 32'h0;                          known = 1'b1; end  // FR-50
      // A R/W register whose reset value A-04 leaves UNSPECIFIED: predicted
      // only after the program wrote it.
      CSR_MSTATUS, CSR_MIE, CSR_MTVEC, CSR_MSCRATCH,
      CSR_MEPC, CSR_MCAUSE: begin
        value = csr_state.exists(addr) ? csr_state[addr] : 32'h0;
        known = csr_written.exists(addr);
      end
      default: begin
        // Every remaining implemented address is a read-only-zero performance
        // counter (FR-50).
        value = 32'h0;
        known = csr_implemented(addr);
      end
    endcase
    // `cycle` (0xC00) and `mcycle` (0xB00) are the low halves of the clock
    // counter, which the monitor never publishes: their value is not a
    // prediction this model may make, so the read is reported and not compared.
    if (addr == CSR_CYCLE || addr == CSR_MCYCLE) known = 1'b0;
  endfunction

  // Write a CSR, applying the write mask and the WARL legalisation of FR-29
  // (mtvec.MODE >= 2 -> direct) and FR-23 (mepc[1:0] = 0 while IALIGN = 32).
  // The counters are 64-bit storage with two write ports (one per 32-bit
  // alias): a write to either half keeps the other one, which is what makes
  // `cycle`/`cycleh` change when the program writes `mcycle`.
  function void csr_write(bit [11:0] addr, bit [31:0] value);
    bit [31:0] v;
    v = value & csr_write_mask(addr);
    case (addr)
      CSR_MTVEC: if (v[1:0] >= 2'b10) v[1:0] = 2'b00;
      CSR_MEPC:  v = v & ~32'h3;
      default:   ;
    endcase
    case (addr)
      CSR_MCYCLE: begin
        mcycle_v[31:0] = v;
        // From 0xFFFF_FFFF the next increment carries out of the low half
        // exactly once; `advance_counters()` applies it at the next event.
        mcycle_wrap = (v == 32'hFFFF_FFFF);
      end
      CSR_MCYCLEH: begin
        mcycle_v[63:32] = v;
        mcycle_hi_known = 1'b1;
      end
      CSR_MINSTRET: begin
        minstret_v[31:0] = v;
        minstret_wrap = (v == 32'hFFFF_FFFF);
        minstret_lo_written = 1'b1;
      end
      CSR_MINSTRETH: begin
        minstret_v[63:32] = v;
        minstret_hi_known = 1'b1;
      end
      default: ;
    endcase
    csr_state[addr]   = v;
    csr_written[addr] = 1'b1;
  endfunction

  // ==========================================================================
  // The ISS
  // ==========================================================================
  // Publishes ONE retire prediction for every retire event, so the scoreboard's
  // pairing stays positional and 1:1; `pred_claim` says whether this commit is
  // part of the CSR/trap claim.
  function void execute(bit [31:0] pc, bit [31:0] inst);
    riscv_small_transaction p;
    bit [3:0] cause;

    init_memory();

    p = riscv_small_transaction::type_id::create("pred_retire");
    p.op_is_pred_retire = 1;
    p.pred_pc           = pc;

    cause = trap_cause_of(inst);
    if (cause != 0) begin
      // It retired, so it never trapped: FR-24 (an unallocated encoding must not
      // execute), FR-47/FR-50 (an illegal CSR access must not execute), FR-25
      // (ECALL/EBREAK do not retire). The scoreboard owns the verdict.
      p.pred_claim       = 1;
      p.pred_should_trap = 1;
      p.pred_cause       = cause;
      must_trap_count++;
      retire_pred_count++;
      pred_count++;
      rm2sb_port.write(p);
      `uvm_info(get_full_name(),
        $sformatf("ISS RETIRE @0x%08h inst=0x%08h: it owed cause %0d and retired", pc, inst, cause),
        UVM_MEDIUM)
      return;
    end

    if (is_csr_access(inst)) begin
      csr_exec(pc, inst, p);
      retire_pred_count++;
      pred_count++;
      rm2sb_port.write(p);
      return;
    end

    // Not a CSR access: no claim about rd, but the model still executes the
    // instruction so its own register file is right for the CSR ops that depend
    // on it.
    execute_base(pc, inst);
    retire_pred_count++;
    pred_count++;
    rm2sb_port.write(p);
  endfunction

  function bit is_csr_access(bit [31:0] inst);
    return (inst[6:0] == 7'b1110011) && (inst[14:12] != 3'b000);
  endfunction

  // One legal CSR instruction: predict rd, then apply the read-modify-write to
  // the model's own CSR file (FR-47, FR-50, D4/D5).
  function void csr_exec(bit [31:0] pc, bit [31:0] inst, ref riscv_small_transaction p);
    bit [11:0] csr    = inst[31:20];
    bit [2:0]  funct3 = inst[14:12];
    bit [4:0]  rd     = inst[11:7];
    bit [4:0]  rs1    = inst[19:15];
    bit        is_imm = funct3[2];
    bit [31:0] src    = is_imm ? {27'b0, rs1} : reg_file[rs1];
    bit [31:0] old_v;
    bit        old_known;
    bit        write;

    // D4: CSRRW/CSRRWI with rd = x0 do not read the CSR (no side effect).
    // D5: CSRRS/CSRRC/CSRRSI/CSRRCI with a source FIELD of x0/0 do not write
    // it. The test is the register specifier's encoding, not the value it
    // holds (vol. I, Zicsr): `csrrs x5, mscratch, x7` writes even when x7 = 0.
    write = ((funct3 == 3'b001) || (funct3 == 3'b101)) ? 1'b1 : (rs1 != 5'd0);

    csr_read(csr, old_v, old_known);

    p.pred_claim       = 1;
    p.pred_rd_wr       = (rd != 5'd0);
    p.pred_rd          = rd;
    p.pred_value_known = (rd != 5'd0) && old_known;
    p.pred_wdata       = old_v;
    if (rd != 0 && !old_known) unknown_read_count++;

    if (write) begin
      bit [31:0] new_v;
      case (funct3)
        3'b001, 3'b101: new_v = src;                 // CSRRW / CSRRWI
        3'b010, 3'b110: new_v = old_v | src;         // CSRRS / CSRRSI
        default:        new_v = old_v & ~src;        // CSRRC / CSRRCI
      endcase
      csr_write(csr, new_v);
    end

    // Architecturally the destination register is written with the OLD value.
    if (rd != 0) reg_file[rd] = int'(old_v);

    `uvm_info(get_full_name(),
      $sformatf("ISS CSR @0x%08h csr=0x%03h f3=%0b: x%0d <- 0x%08h (known=%0d)%s",
        pc, csr, funct3, rd, old_v, old_known, write ? ", wrote the CSR" : ", no write"),
      UVM_HIGH)
  endfunction

  // ==========================================================================
  // Base subset: the loads and stores of G-04, plus the register-writing
  // integer instructions the CSR program builds its operands with.
  // ==========================================================================
  function void execute_base(bit [31:0] pc, bit [31:0] inst);
    bit [6:0] opcode = inst[6:0];

    // --- Loads (I-Type, opcode=0000011) -------------------------------------
    // LW, LB, LH, LBU, LHU. The lane comes from the low address bits, which is
    // exactly what FR-12 requires of the DUT: a byte from `8 * lane`, a
    // halfword from the same byte offset (lane 0, 1 or 2 stay inside the word).
    if (opcode == 7'b0000011) begin
      bit [4:0]  rd       = inst[11:7];
      bit [4:0]  rs1      = inst[19:15];
      bit [2:0]  funct3   = inst[14:12];
      bit [11:0] imm      = inst[31:20];
      int        byte_addr = reg_file[rs1] + $signed(imm);
      int        word_addr = byte_addr >> 2;
      bit [1:0]  lane      = byte_addr[1:0];
      bit [31:0] word      = iss_mem.exists(word_addr) ? iss_mem[word_addr] : 0;
      bit [7:0]  b         = word[8 * lane +: 8];
      bit [15:0] h;
      // A halfword at lane 3 spans bytes 3 and 4, i.e. the low byte of the next
      // word. The architectural result is defined whatever the number of bus
      // beats (FR-42 splits it); the model reads the second byte from its own
      // memory, so it predicts the value and not a guess.
      if (lane == 2'd3) begin
        bit [31:0] next_word = iss_mem.exists(word_addr + 1) ? iss_mem[word_addr + 1] : 0;
        h = {next_word[7:0], word[31:24]};
      end else begin
        h = word[8 * lane +: 16];
      end

      if (rd != 0) begin
        case (funct3)
          3'b000:  reg_file[rd] = int'({{24{b[7]}}, b});   // LB
          3'b001:  reg_file[rd] = int'({{16{h[15]}}, h});  // LH
          3'b010:  reg_file[rd] = int'(word);              // LW
          3'b100:  reg_file[rd] = int'({24'b0, b});        // LBU
          3'b101:  reg_file[rd] = int'({16'b0, h});        // LHU
          default: reg_file[rd] = int'(word);              // reserved form
        endcase
        `uvm_info(get_full_name(),
          $sformatf("ISS LD @0x%0h f3=%0b: x%0d <- mem_byte[%0d] (word=0x%0h lane=%0d) = 0x%0h",
            pc, funct3, rd, byte_addr, word, lane, reg_file[rd]),
          UVM_HIGH)
      end

    // --- Stores (S-Type, opcode=0100011) ------------------------------------
    // SB, SH and SW are executed at byte granularity: the lane comes from the
    // low address bits and each byte goes to the word its own address names.
    // Every store publishes exactly ONE prediction, so the Scoreboard's
    // one-prediction-per-observed-write pairing stays 1:1 -- a store the model
    // does not predict would consume the prediction of the next one and turn a
    // value comparison into a stream-shift artefact.
    end else if (opcode == 7'b0100011) begin
      bit [4:0]  rs2      = inst[24:20];
      bit [4:0]  rs1      = inst[19:15];
      bit [2:0]  funct3   = inst[14:12];
      bit [11:0] imm      = {inst[31:25], inst[11:7]};
      int        byte_addr = reg_file[rs1] + $signed(imm);
      int        word_addr = byte_addr >> 2;
      bit [1:0]  lane      = byte_addr[1:0];
      bit [31:0] value     = reg_file[rs2];
      bit [31:0] word;      // the addressed word after the write, for the log
      int        nbytes;

      case (funct3)
        3'b000:  nbytes = 1; // SB
        3'b001:  nbytes = 2; // SH
        3'b010:  nbytes = 4; // SW
        default: nbytes = 4;
      endcase

      // Byte-addressed write: every byte of the access goes to the word its own
      // address names, so a halfword at lane 3 lands in two words exactly as
      // the architecture requires (FR-42 splits it into two beats; the memory
      // result is the same). T-51 is lane 1, which stays inside one word.
      for (int b = 0; b < nbytes; b++) begin
        int        byte_b = byte_addr + b;
        int        word_b = byte_b >> 2;
        bit [1:0]  lane_b = byte_b[1:0];
        bit [31:0] word_prev = iss_mem.exists(word_b) ? iss_mem[word_b] : 0;

        word_prev[8 * lane_b +: 8] = value[8 * b +: 8];
        iss_mem[word_b] = word_prev;
      end
      word = iss_mem.exists(word_addr) ? iss_mem[word_addr] : 0;
      `uvm_info(get_full_name(),
        $sformatf("ISS ST @0x%0h f3=%0b: mem_word[%0d] + lane %0d <- 0x%0h = 0x%0h",
          pc, funct3, word_addr, lane, value, word),
        UVM_HIGH)

      // Publish the prediction the Scoreboard compares against the store the
      // monitor observes on the data port. The prediction is the store
      // CONTRACT the memory BFM already enforces -- byte address, byte strobes,
      // lane-placed data word -- so a halfword at the wrong lane fails with the
      // strobes it actually drove (T-51: 4'b0011 where 4'b0110 is required),
      // not only through the read-back the program performs.
      //
      // ONE PREDICTION PER BEAT (WP-14b, FR-42/G-22). An access whose byte lane
      // plus its width crosses the word boundary is executed as two
      // word-aligned beats (rtl/misaligned_split.sv), and the monitor publishes
      // one event per beat; a single prediction would leave the second beat
      // paired with the NEXT store's prediction and turn a value comparison
      // into a stream shift. Beat 1 carries the suffix that still fits in the
      // word the access starts in, beat 2 the prefix that spills into the next
      // one, at (addr & ~3) + 4 with lanes 0..spill-1 taken from the TOP of the
      // store operand -- the same rule the RTL derives from the width.
      begin
        riscv_small_transaction pred;
        bit [31:0] lane_data;
        bit [3:0]  lane_strb;
        int        spill; // bytes of the access that do not fit in the first word

        spill     = lane + nbytes - 4;
        lane_data = '0;
        lane_strb = '0;
        for (int b = 0; b < nbytes; b++)
          if ((lane + b) < 4) begin
            lane_data[8 * (lane + b) +: 8] = value[8 * b +: 8];
            lane_strb[lane + b] = 1'b1;
          end
        if (funct3 == 3'b010 && spill <= 0) begin
          lane_data = value;
          lane_strb = 4'b1111;
        end

        pred = riscv_small_transaction::type_id::create("pred");
        pred.op_is_data_write      = 1;
        pred.op_is_data_read       = 0;
        pred.captured_data_addr    = byte_addr;
        pred.captured_data_wr      = lane_data;
        pred.captured_data_wr_strb = lane_strb;
        store_pred_count++;
        pred_count++;
        rm2sb_port.write(pred);

        if (spill > 0) begin
          riscv_small_transaction pred2;
          pred2 = riscv_small_transaction::type_id::create("pred_beat2");
          pred2.op_is_data_write      = 1;
          pred2.op_is_data_read       = 0;
          pred2.captured_data_addr    = (byte_addr & ~32'sd3) + 32'sd4;
          pred2.captured_data_wr      = value >> (32 - 8 * lane);
          pred2.captured_data_wr_strb = (4'b0001 << spill) - 4'b0001;
          store_pred_count++;
          pred_count++;
          rm2sb_port.write(pred2);
          `uvm_info(get_full_name(),
            $sformatf("ISS ST SPLIT @0x%0h: beats 0x%0h/4'b%04b and 0x%0h/4'b%04b (lane %0d, %0d byte(s))",
              pc, byte_addr, lane_strb, pred2.captured_data_addr,
              pred2.captured_data_wr_strb, lane, nbytes),
            UVM_HIGH)
        end
      end

    // --- Integer register-writing instructions -----------------------------
    // Executed only so the model's own register file feeds the CSR predictions
    // correctly; no claim is published about their rd (pred_claim stays 0).
    end else if (opcode == 7'b0110111) begin                       // LUI
      bit [4:0] rd = inst[11:7];
      // A concatenation, not `imm << 12`: the size of a shift expression is the
      // size of its left operand, and inst[31:12] is 20 bits wide.
      if (rd != 0) reg_file[rd] = int'({inst[31:12], 12'b0});
    end else if (opcode == 7'b0010111) begin                       // AUIPC
      bit [4:0] rd = inst[11:7];
      if (rd != 0) reg_file[rd] = int'(pc + {inst[31:12], 12'b0});
    end else if (opcode == 7'b0010011) begin                       // OP-IMM
      bit [4:0]  rd  = inst[11:7];
      bit [4:0]  rs1 = inst[19:15];
      bit [2:0]  f3  = inst[14:12];
      bit [31:0] a   = reg_file[rs1];
      bit [31:0] imm = {{20{inst[31]}}, inst[31:20]};
      bit [31:0] r;
      case (f3)
        3'b000:  r = a + imm;
        3'b001:  r = a << inst[24:20];
        3'b010:  r = ($signed(a) < $signed(imm)) ? 32'd1 : 32'd0;
        3'b011:  r = (a < imm) ? 32'd1 : 32'd0;
        3'b100:  r = a ^ imm;
        3'b101:  r = inst[30] ? 32'($signed(a) >>> inst[24:20]) : (a >> inst[24:20]);
        3'b110:  r = a | imm;
        default: r = a & imm;
      endcase
      if (rd != 0) reg_file[rd] = int'(r);
    end else if (opcode == 7'b0110011) begin                       // OP
      bit [4:0]  rd  = inst[11:7];
      bit [4:0]  rs1 = inst[19:15];
      bit [4:0]  rs2 = inst[24:20];
      bit [2:0]  f3  = inst[14:12];
      bit [31:0] a   = reg_file[rs1];
      bit [31:0] b   = reg_file[rs2];
      bit [31:0] r;
      case (f3)
        3'b000:  r = inst[30] ? (a - b) : (a + b);
        3'b001:  r = a << b[4:0];
        3'b010:  r = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
        3'b011:  r = (a < b) ? 32'd1 : 32'd0;
        3'b100:  r = a ^ b;
        3'b101:  r = inst[30] ? 32'($signed(a) >>> b[4:0]) : (a >> b[4:0]);
        3'b110:  r = a | b;
        default: r = a & b;
      endcase
      if (rd != 0) reg_file[rd] = int'(r);
    end else if (opcode == 7'b1101111 || opcode == 7'b1100111) begin // JAL, JALR
      bit [4:0] rd = inst[11:7];
      if (rd != 0) reg_file[rd] = int'(pc + 32'd4);                 // link value
    end
    // Branches, FENCE, MRET/WFI and ECALL/EBREAK retired as no-ops here: none
    // writes a register, and an ECALL/EBREAK that retires is caught above.
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_full_name(),
      $sformatf("ISS: %0d retire event(s) executed, %0d store prediction(s), %0d retire prediction(s), %0d trap prediction(s), %0d instruction(s) retired owing a trap, data image=%0d word(s)%s",
        commit_count, store_pred_count, retire_pred_count, trap_pred_count, must_trap_count,
        (image == null) ? 0 : image.data_size(),
        (image == null) ? " (no program image configured)" : ""),
      UVM_LOW)
    // Stated, not hidden: a CSR read whose value is a free-running counter, or a
    // counter half the program has not written, is reported here and not
    // compared by the scoreboard (see `csr_read`).
    if (unknown_read_count > 0)
      `uvm_info(get_full_name(),
        $sformatf("ISS: %0d CSR read(s) whose value is not a prediction -- a free-running counter half, a counter half never written, or a register whose reset value A-04 leaves UNSPECIFIED: read, reported, NOT compared",
          unknown_read_count),
        UVM_LOW)
  endfunction

endclass : riscv_small_ref_model

`endif
