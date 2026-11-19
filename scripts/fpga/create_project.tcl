# ==============================================================================
# Script: create_project.tcl
# Description: Creates or refreshes the Vivado project for one top of this
#              repository. Everything specific to a product -- project name,
#              top, part, source list, board files -- arrives as an argument,
#              so the same script drives any top.
#
# Usage: vivado -mode batch -source scripts/fpga/create_project.tcl \
#            -tclargs <project> <top> <part> <filelist> <build_dir> <root_dir>
#
#   <filelist>  one absolute .sv/.svh path per line, expanded by
#               riscv_srclist_files() in scripts/fpga/fpga_targets.cmake from
#               srclist/<top>.srclist -- the same files the simulation compiles.
# ==============================================================================

# 1. Arguments
if {[llength $argv] < 6} {
    error "usage: create_project.tcl <project> <top> <part> <filelist> <build_dir> <root_dir>"
}
lassign $argv project_name top_name part filelist build_dir root_dir

set output_dir [file join $build_dir "fpga"]
set project_file [file join $output_dir "${project_name}.xpr"]

puts "INFO: project    = $project_name"
puts "INFO: top        = $top_name"
puts "INFO: part       = $part"
puts "INFO: filelist   = $filelist"

file mkdir $output_dir

# The source list is the contract with the build: refuse to synthesise
# something the simulation never compiled.
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
puts "INFO: [llength $rtl_files] source file(s) from the srclist expansion"

# 2. Project
if {[file exists $project_file]} {
    puts "INFO: opening existing project: $project_file"
    open_project $project_file
} else {
    puts "INFO: creating project: $project_file"
    create_project $project_name $output_dir -part $part
    set_property target_language Verilog [current_project]
    set_property simulator_language Mixed [current_project]
}

# 3. Board files are optional: a repository that does not ship them still
#    synthesises on the raw part.
set bsp_board_files [file join $root_dir "submodules"]
if {[file exists $bsp_board_files]} {
    set boards [glob -nocomplain [file join $bsp_board_files "*" "board_files"]]
    if {[llength $boards] > 0} {
        set_param board.repoPaths $boards
        set_property board_part_repo_paths $boards [current_project]
        puts "INFO: board repository paths: $boards"
    }
} else {
    puts "INFO: no board files in this repository; using the raw part $part"
}

# 4. Design sources -- exactly the filelist, nothing globbed
add_files -norecurse $rtl_files
puts "INFO: added [llength $rtl_files] source file(s)"

# SystemVerilog must not be inferred from the extension order
set verilog_files [get_files -quiet -filter {FILE_TYPE == "Verilog"}]
if {[llength $verilog_files] > 0} {
    set_property file_type SystemVerilog $verilog_files
}

# 5. Constraints and IP are optional directories
foreach {dir fileset kind} [list "fpga/constraints" "constrs_1" "xdc" \
                                 "fpga/ip" "" "xci"] {
    set pattern [file join $root_dir $dir "*" "*.$kind"]
    set found [glob -nocomplain $pattern]
    if {[llength $found] > 0} {
        if {$kind eq "xdc"} {
            add_files -fileset $fileset $found
        } else {
            read_ip $found
        }
        puts "INFO: added $kind: $found"
    }
}

update_compile_order -fileset sources_1
puts "INFO: project ready: $project_file"
close_project
