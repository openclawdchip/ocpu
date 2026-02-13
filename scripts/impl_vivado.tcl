# Vivado Implementation TCL Script
# Usage: vivado -mode batch -source impl_vivado.tcl -tclargs <top_module> <build_dir> <report_dir>

set top_module [lindex $argv 0]
set build_dir  [lindex $argv 1]
set report_dir [lindex $argv 2]

puts "========================================"
puts "OCPU FPGA Implementation"
puts "========================================"
puts "Top Module: $top_module"
puts "Build Dir: $build_dir"
puts "Report Dir: $report_dir"
puts ""

# Open checkpoint
open_checkpoint ${build_dir}/post_synth.dcp

# Run optimization
puts "Running optimization..."
opt_design

# Run placement
puts "Running placement..."
place_design

# Run physical optimization
puts "Running physical optimization..."
phys_opt_design

# Run routing
puts "Running routing..."
route_design

# Generate reports
puts ""
puts "Generating reports..."
report_utilization -file ${report_dir}/utilization_impl.rpt -hierarchy
report_timing_summary -file ${report_dir}/timing_impl.rpt -delay_type min_max
report_route_status -file ${report_dir}/route_status.rpt
report_drc -file ${report_dir}/drc.rpt

# Save checkpoint
write_checkpoint -force ${build_dir}/post_route.dcp

puts ""
puts "========================================"
puts "Implementation Complete"
puts "========================================"
puts "Reports generated in: $report_dir"
puts "Checkpoint saved: ${build_dir}/post_route.dcp"
puts ""

close_project
