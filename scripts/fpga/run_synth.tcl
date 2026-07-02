# ==============================================================================
# Script: run_synth.tcl
# Description: Automates project synthesis in Vivado
# Usage: vivado -mode batch -source scripts/fpga/run_synth.tcl
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

# 3. Run Synthesis
puts "INFO: Resetting previous synthesis runs..."
reset_run synth_1

puts "INFO: Launching synthesis run (synth_1)..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 4. Validate Status
set run_status [get_property STATUS [get_runs synth_1]]
set run_progress [get_property PROGRESS [get_runs synth_1]]
puts "INFO: Synthesis Status: $run_status ($run_progress)"

if {$run_progress ne "100%"} {
    error "ERROR: Synthesis did not complete successfully!"
}

puts "SUCCESS: Synthesis completed successfully!"
close_project
