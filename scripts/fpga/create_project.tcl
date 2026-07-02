# ==============================================================================
# Script: create_project.tcl
# Description: Automates Vivado project creation for CV-QKD Top-Level SoC RTL IP
# Usage: vivado -mode batch -source scripts/fpga/create_project.tcl
# Created by Nelson Alves Ferreira Neto (nelson.neto@fieb.org.br)
# ==============================================================================

# 1. Define paths relative to the script's location (Tcl Best Practice)
set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ".." ".."]]

# 2. Project configuration variables
set project_name  "cvqkd_topsoc"
set target_board  ""                                  ;# Generic part configuration
set fallback_part "xczu3eg-sbva484-1-i"               ;# Standard Zynq UltraScale+ MPSoC (Free License)
set build_dir     [file join $root_dir "build" "fpga"]

# Create build directory if it doesn't exist
file mkdir $build_dir

# 3. Handle Custom Board Files (RFSoC 4x2 BSP Submodule)
# Check for local board file paths inside the workspace submodule
set bsp_board_files [file join $root_dir "submodules" "RFSoC4x2-BSP" "board_files"]

if {[file exists $bsp_board_files]} {
    # Dynamically point Vivado to our custom board repository
    set_param board.repoPaths [list $bsp_board_files]
    puts "INFO: Configured board.repoPaths with: $bsp_board_files"
} else {
    puts "WARNING: Board files directory not found at '$bsp_board_files'."
}

# 4. Create or Open the Vivado Project
set project_file [file join $build_dir "${project_name}.xpr"]
if {[file exists $project_file]} {
    puts "INFO: Project already exists. Opening existing project: $project_file"
    open_project $project_file
} else {
    puts "INFO: Creating new Vivado project at: $project_file"
    create_project $project_name $build_dir -part $fallback_part

    # Set project-level board repository path so it scans immediately
    if {[file exists $bsp_board_files]} {
        set_property board_part_repo_paths [list $bsp_board_files] [current_project]
    }

    # Apply board part if recognized by Vivado
    if {[get_boards -quiet $target_board] ne ""} {
        set_property board_part $target_board [current_project]
        puts "INFO: Project configured with Board Part: $target_board"
    } else {
        puts "WARNING: Board part '$target_board' was not found in Vivado's board database."
        puts "         Project remains configured with the raw device part: [get_property part [current_project]]"
        puts "         To use the board configuration, make sure the submodule is initialized and updated:"
        puts "         git submodule update --init --recursive"
    }

    # Set project properties (e.g., target language is Verilog)
    set_property target_language Verilog [current_project]
    set_property simulator_language Mixed [current_project]
}

# 5. Add Design Sources (RTL)
# Add files from the main rtl/ directory
set rtl_files [glob -nocomplain [file join $root_dir "rtl" "*.{v,sv,vhd}"]]
if {[llength $rtl_files] > 0} {
    add_files $rtl_files
    puts "INFO: Added RTL source files: $rtl_files"
}

# Add files from submodules (recursive search under submodules/*/rtl/)
set submodule_rtl [glob -nocomplain [file join $root_dir "submodules" "*" "rtl" "*.{v,sv,vhd}"]]
if {[llength $submodule_rtl] > 0} {
    add_files $submodule_rtl
    puts "INFO: Added submodule RTL files: $submodule_rtl"
}

# Ensure all Verilog files (.v) are compiled as SystemVerilog in Vivado
set verilog_files [get_files -filter {FILE_TYPE == "Verilog"}]
if {[llength $verilog_files] > 0} {
    set_property file_type SystemVerilog $verilog_files
    puts "INFO: Set file type of Verilog files to SystemVerilog: $verilog_files"
}

# 6. Add Constraints (.xdc)
set constraint_files [glob -nocomplain [file join $root_dir "fpga" "constraints" "*.xdc"]]
if {[llength $constraint_files] > 0} {
    add_files -fileset constrs_1 $constraint_files
    puts "INFO: Added constraint files: $constraint_files"
}

# 7. Read/Import Xilinx IPs (.xci)
set ip_files [glob -nocomplain [file join $root_dir "fpga" "ip" "*" "*.xci"]]
if {[llength $ip_files] > 0} {
    read_ip $ip_files
    puts "INFO: Imported Xilinx IPs: $ip_files"
}

# 8. Update compile order automatically
update_compile_order -fileset sources_1

puts "SUCCESS: Vivado project created successfully at: [file join $build_dir ${project_name}.xpr]"
