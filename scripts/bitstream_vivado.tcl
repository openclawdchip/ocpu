# Vivado Bitstream Generation TCL Script
# Usage: vivado -mode batch -source bitstream_vivado.tcl -tclargs <top_module> <build_dir> <bitstream_dir>

set top_module     [lindex $argv 0]
set build_dir      [lindex $argv 1]
set bitstream_dir  [lindex $argv 2]

puts "========================================"
puts "OCPU Bitstream Generation"
puts "========================================"
puts "Top Module: $top_module"
puts "Build Dir: $build_dir"
puts "Bitstream Dir: $bitstream_dir"
puts ""

# Open checkpoint
open_checkpoint ${build_dir}/post_route.dcp

# Generate bitstream
puts "Generating bitstream..."
write_bitstream -force ${bitstream_dir}/${top_module}.bit

# Generate debug probe file
write_debug_probes -force ${bitstream_dir}/${top_module}.ltx

puts ""
puts "========================================"
puts "Bitstream Generation Complete"
puts "========================================"
puts "Bitstream: ${bitstream_dir}/${top_module}.bit"
puts "Debug probes: ${bitstream_dir}/${top_module}.ltx"
puts ""

close_project
