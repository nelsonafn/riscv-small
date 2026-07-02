set all_parts [get_parts]
puts "TOTAL_PARTS: [llength $all_parts]"

set families [list]
foreach p $all_parts {
    set fam [get_property FAMILY $p]
    if {[lsearch -exact $families $fam] == -1} {
        lappend families $fam
    }
}
puts "FAMILIES: $families"

# Print first 20 parts
puts "FIRST_20_PARTS:"
for {set i 0} {$i < 20 && $i < [llength $all_parts]} {incr i} {
    puts [lindex $all_parts $i]
}
