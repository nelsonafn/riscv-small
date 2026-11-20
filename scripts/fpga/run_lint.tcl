# ==============================================================================
# Script: run_lint.tcl
# Description: Lints and inspects the synthesized netlist of one top of this
#              repository, in a standalone session (no Vivado project needed).
#
# Usage: vivado -mode batch -source scripts/fpga/run_lint.tcl \
#            -tclargs <top> <filelist> <part>
#
# Two synthesis passes, because the flags interact:
#
#   * `synth_design -lint` runs the RTL linter but does NOT open the synthesized
#     design (`current_design` stays empty), so no query can inspect it;
#   * `synth_design` without `-lint` opens the design (`design_1`) but skips the
#     linter.
#
# Neither pass alone answers NFR-07, which asks for both "no inferred latches"
# (a property of the netlist) and the linter's own report.
#
# Counting rules, each learned the hard way in this work package:
#
#   * latches are counted by REF_NAME (LDCE/LDPE/LDNE on UltraScale), NOT by
#     `PRIMITIVE_TYPE =~ *LATCH*`, which also matches every flip-flop: that
#     filter reported 1405 for a design with zero latches;
#   * flops are counted too, so "0 latches" is a number out of a known total
#     rather than the absence of a match;
#   * the design must be open before counting: an empty design is not "zero
#     latches", it is no measurement, so the script errors instead;
#   * `-part` is passed explicitly. Without it standalone synth_design silently
#     uses Vivado's default device, and the measurement would name the wrong one;
#   * combinational loops come from the DRC rule LUTLP-1's own "Violations
#     found: N" line, not from a timing query (negative slack is not a loop).
# ==============================================================================

if {[llength $argv] < 3} {
    error "usage: run_lint.tcl <top> <filelist> <part>"
}
lassign $argv top_name filelist part

if {![file exists $filelist]} {
    error "ERROR: filelist not found: $filelist (run ./configure first)"
}
set fp [open $filelist r]
set rtl_files {}
foreach line [split [read $fp] "\n"] {
    set line [string trim $line]
    if {$line ne ""} { lappend rtl_files $line }
}
close $fp
if {[llength $rtl_files] == 0} {
    error "ERROR: the filelist $filelist names no source file"
}

foreach f $rtl_files { read_verilog -sv $f }
puts "INFO: read [llength $rtl_files] source file(s) from the srclist expansion"
puts "INFO: linting top: $top_name on part: $part"

# --- pass 1: the linter ------------------------------------------------------
catch { close_design }
if {[catch {synth_design -top $top_name -part $part -mode out_of_context -lint} lint_err]} {
    puts "LINT: synth_design -lint reported: $lint_err"
    set lint_exit 1
} else {
    set lint_exit 0
}

# --- pass 2: the netlist -----------------------------------------------------
catch { close_design }
if {[catch {synth_design -top $top_name -part $part -mode out_of_context} synth_err]} {
    puts "LINT: synth_design reported: $synth_err"
    error "ERROR: synthesis failed for $top_name; the netlist cannot be inspected"
}

set cells [llength [get_cells -hier -quiet]]
if {$cells == 0} {
    error "ERROR: the synthesized design is not open (0 cells); refusing to report a latch count"
}

set latches 0
foreach prim {LDCE LDPE LDNE} {
    incr latches [llength [get_cells -hier -quiet -filter "REF_NAME == $prim"]]
}
set flops 0
foreach prim {FDRE FDSE FDCE FDPE} {
    incr flops [llength [get_cells -hier -quiet -filter "REF_NAME == $prim"]]
}
if {[expr {$latches + $flops}] == 0} {
    error "ERROR: no sequential primitive matched (latches+flops=0 of $cells cells); the counting filter is wrong, not the design"
}

# Combinational loops: the DRC rule's own violation count.
set loops "not_measured"
if {[catch {
    set drc [report_drc -quiet -checks LUTLP-1 -return_string]
    # Print the block, so "Violations found: 0" is readable from the log the
    # document cites instead of existing only in a variable.
    foreach line [split $drc "\n"] {
        if {[string match "*Violations found:*" $line] || [string match "*LUTLP-1*" $line]} {
            puts "LINT_DRC: [string trim $line]"
        }
    }
    if {[regexp {Violations found:\s+(\d+)} $drc -> n]} {
        set loops $n
    } else {
        puts "LINT: report_drc returned no 'Violations found' line; combinational loops are not measurable here"
    }
} err]} {
    puts "LINT: LUTLP-1 unavailable in this design stage: $err"
}

puts "LINT_SUMMARY: top=$top_name part=$part cells=$cells latches=$latches flops=$flops combinational_loops=$loops"

if {$lint_exit} {
    error "ERROR: the RTL linter reported errors for $top_name"
}
puts "SUCCESS: lint completed for $top_name"
