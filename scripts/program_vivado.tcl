# Vivado Programming TCL Script
# Usage: vivado -mode batch -source program_vivado.tcl -tclargs <bitstream_file>

set bitstream_file [lindex $argv 0]

puts "========================================"
puts "OCPU FPGA Programming"
puts "========================================"
puts "Bitstream: $bitstream_file"
puts ""

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -allow_non_jtag

# Get hardware targets
set hw_targets [get_hw_targets -of_objects [get_hw_servers]]
if {[llength $hw_targets] == 0} {
    puts "Error: No hardware targets found"
    exit 1
}

# Open first hardware target
open_hw_target [lindex $hw_targets 0]

# Get hardware devices
set hw_devices [get_hw_devices]
if {[llength $hw_devices] == 0} {
    puts "Error: No hardware devices found"
    exit 1
}

# Program first device
set hw_device [lindex $hw_devices 0]
puts "Programming device: $hw_device"

current_hw_device $hw_device
set_property PROGRAM.FILE $bitstream_file $hw_device
program_hw_devices $hw_device

puts ""
puts "========================================"
puts "Programming Complete"
puts "========================================"
puts ""

close_hw_manager
