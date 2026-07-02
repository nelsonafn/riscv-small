# ==============================================================================
# Script: run_impl.tcl
# Description: Automates project implementation and bitstream generation in Vivado
# Usage: vivado -mode batch -source scripts/fpga/run_impl.tcl
# Created by Nelson Alves Ferreira Neto (nelson.neto@fieb.org.br)
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

# 3. Run Implementation & Write Bitstream
puts "INFO: Resetting previous implementation runs..."
reset_run impl_1

# Configure DRC pre-hook script for write_bitstream step to allow bitstream generation without I/O constraints
set_property STEPS.WRITE_BITSTREAM.TCL.PRE [file join $script_dir "drc_warnings.tcl"] [get_runs impl_1]

puts "INFO: Launching implementation and bitstream generation (impl_1)..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# 4. Validate Status
set run_status [get_property STATUS [get_runs impl_1]]
set run_progress [get_property PROGRESS [get_runs impl_1]]
puts "INFO: Implementation Status: $run_status ($run_progress)"

if {$run_progress ne "100%"} {
    error "ERROR: Implementation/Bitstream generation did not complete successfully!"
}

puts "SUCCESS: Implementation and bitstream generation completed successfully!"
close_project
