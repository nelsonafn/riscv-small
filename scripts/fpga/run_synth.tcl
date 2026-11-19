# ==============================================================================
# Script: run_synth.tcl
# Description: Runs synthesis on the project's top. The project, the top and the
#              build directory are arguments; the script names no product.
#
# Usage: vivado -mode batch -source scripts/fpga/run_synth.tcl \
#            -tclargs <project> <top> <build_dir>
# ==============================================================================

if {[llength $argv] < 3} {
    error "usage: run_synth.tcl <project> <top> <build_dir>"
}
lassign $argv project_name top_name build_dir

set project_file [file join $build_dir "fpga" "${project_name}.xpr"]
if {![file exists $project_file]} {
    error "ERROR: project not found: $project_file (run create_fpga first)"
}
open_project $project_file

puts "INFO: synthesising top: $top_name"

# The design is synthesised out of context: it is a block, not a bonded part.
set_property top $top_name [current_fileset]
catch {set_property top_file "" [current_fileset]}
reset_run synth_1

puts "INFO: launching synth_1"
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
set run_progress [get_property PROGRESS [get_runs synth_1]]
puts "INFO: synth_1 status: $run_status ($run_progress)"

if {$run_progress ne "100%"} {
    close_project
    error "ERROR: synthesis did not complete for $top_name ($run_status)"
}

# Report the numbers a timing/area measurement needs, without inventing them.
catch {
    set wns [get_property SLACK [get_timing_paths -delay_type max]]
    puts "SYNTH_SUMMARY: top=$top_name wns=$wns status=$run_status"
}

puts "SUCCESS: synthesis completed for $top_name"
close_project
