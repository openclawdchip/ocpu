# Vivado Synthesis TCL Script
# Usage: vivado -mode batch -source synth_vivado.tcl -tclargs <top_module> <part> <rtl_dir> <build_dir> <report_dir>

set top_module [lindex $argv 0]
set part       [lindex $argv 1]
set rtl_dir    [lindex $argv 2]
set build_dir  [lindex $argv 3]
set report_dir [lindex $argv 4]

puts "========================================"
puts "OCPU FPGA Synthesis"
puts "========================================"
puts "Top Module: $top_module"
puts "Part: $part"
puts "RTL Dir: $rtl_dir"
puts "Build Dir: $build_dir"
puts "Report Dir: $report_dir"
puts ""

# Create project
create_project ocpu_synth $build_dir -part $part -force

# Set project properties
set_property target_language SystemVerilog [current_project]
set_property default_lib work [current_project]

# Add RTL sources
puts "Adding RTL sources..."
set rtl_files [glob -nocomplain -directory $rtl_dir *.sv */*.sv */*/*.sv]
foreach file $rtl_files {
    if {[file exists $file]} {
        read_verilog -sv $file
        puts "  Added: $file"
    }
}

# Add constraints if exists
set constraints_file "${::env(CONSTRAINTS_DIR)}/${top_module}.xdc"
if {[file exists $constraints_file]} {
    read_xdc $constraints_file
    puts "Added constraints: $constraints_file"
}

# Run synthesis
puts ""
puts "Running synthesis..."
synth_design -top $top_module -part $part

# Generate reports
puts ""
puts "Generating reports..."
report_utilization -file ${report_dir}/utilization.rpt -hierarchy
report_timing_summary -file ${report_dir}/timing.rpt -delay_type max
report_timing -file ${report_dir}/timing_detail.rpt -delay_type max -max_paths 100
report_clock_utilization -file ${report_dir}/clock_util.rpt
report_power -file ${report_dir}/power.rpt

# Save checkpoint
write_checkpoint -force ${build_dir}/post_synth.dcp

puts ""
puts "========================================"
puts "Synthesis Complete"
puts "========================================"
puts "Reports generated in: $report_dir"
puts "Checkpoint saved: ${build_dir}/post_synth.dcp"
puts ""

close_project
