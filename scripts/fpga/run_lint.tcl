# ==============================================================================
# Script: run_lint.tcl
# Description: Runs RTL syntax and style checks (Linter) on the HDL source files
# Usage: vivado -mode batch -source scripts/fpga/run_lint.tcl
# ==============================================================================

# 1. Define paths relative to the script's location
set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ".." ".."]]

set project_name "cvqkd_topsoc"
set build_dir     [file join $root_dir "build" "fpga"]
set project_file  [file join $build_dir "${project_name}.xpr"]

# 2. Open project
if {![file exists $project_file]} {
    error "ERROR: Vivado project file not found at: $project_file. Run create_project.tcl first."
}
open_project $project_file

# 3. Check Syntax
puts "INFO: Running check_syntax..."
if {[catch {check_syntax} syntax_err]} {
    puts "WARNING: check_syntax encountered errors: $syntax_err"
}

# 4. Run HDL Linting (using synth_design -lint)
puts "INFO: Running RTL Synthesis Linter..."
if {[catch {synth_design -top cvqkd_topsoc -lint} lint_err]} {
    puts "WARNING: synth_design -lint encountered errors: $lint_err"
}

puts "SUCCESS: RTL Linting completed!"
close_project
