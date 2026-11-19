# ==============================================================================
# Script: run_impl.tcl
# Description: Runs implementation and bitstream generation on the project's
#              top. The project, the top and the build directory are arguments;
#              the script names no product.
#
# Usage: vivado -mode batch -source scripts/fpga/run_impl.tcl \
#            -tclargs <project> <top> <build_dir>
# ==============================================================================

if {[llength $argv] < 3} {
    error "usage: run_impl.tcl <project> <top> <build_dir>"
}
lassign $argv project_name top_name build_dir

set script_dir [file normalize [file dirname [info script]]]
set project_file [file join $build_dir "fpga" "${project_name}.xpr"]
if {![file exists $project_file]} {
    error "ERROR: project not found: $project_file (run create_fpga first)"
}
open_project $project_file

puts "INFO: implementing top: $top_name"

set_property top $top_name [current_fileset]
reset_run impl_1

# A block synthesised out of context has no package pins, so the bitstream DRC
# would stop on unconstrained I/O that does not describe this design. The
# pre-hook downgrades exactly those, and nothing else.
set drc_hook [file join $script_dir "drc_warnings.tcl"]
if {[file exists $drc_hook]} {
    set_property STEPS.WRITE_BITSTREAM.TCL.PRE $drc_hook [get_runs impl_1]
}

puts "INFO: launching impl_1"
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set run_status [get_property STATUS [get_runs impl_1]]
set run_progress [get_property PROGRESS [get_runs impl_1]]
puts "INFO: impl_1 status: $run_status ($run_progress)"

if {$run_progress ne "100%"} {
    close_project
    error "ERROR: implementation did not complete for $top_name ($run_status)"
}

puts "IMPL_SUMMARY: top=$top_name status=$run_status"
puts "SUCCESS: implementation completed for $top_name"
close_project
