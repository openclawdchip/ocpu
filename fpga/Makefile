# FPGA Synthesis Makefile
# Supports: Xilinx Vivado, Intel Quartus

# Configuration
TARGET ?= xilinx
PART ?= xc7k325tffg900-2  # Default: Xilinx Kintex-7
TOP_MODULE ?= ocpu_core

# Directories
RTL_DIR = ../rtl
SCRIPT_DIR = ../scripts
BUILD_DIR = build
REPORT_DIR = reports
BITSTREAM_DIR = bitstream
CONSTRAINTS_DIR = constraints

# Find all RTL sources
RTL_SOURCES = $(shell find $(RTL_DIR) -name "*.sv" | sort)

# Xilinx Vivado settings
ifeq ($(TARGET),xilinx)
VIVADO = vivado
VIVADO_FLAGS = -mode batch -source
VIVADO_TCL = $(SCRIPT_DIR)/synth_vivado.tcl
endif

# Intel Quartus settings
ifeq ($(TARGET),intel)
QUARTUS = quartus_sh
QUARTUS_FLAGS = -t
QUARTUS_TCL = $(SCRIPT_DIR)/synth_quartus.tcl
endif

.PHONY: all synth impl bitstream program clean

all: bitstream

# Create directories
dirs:
	@mkdir -p $(BUILD_DIR) $(REPORT_DIR) $(BITSTREAM_DIR)

# Run synthesis
synth: dirs
ifeq ($(TARGET),xilinx)
	@echo "Running Xilinx Vivado synthesis..."
	$(VIVADO) $(VIVADO_FLAGS) $(VIVADO_TCL) -tclargs \
		$(TOP_MODULE) $(PART) $(RTL_DIR) $(BUILD_DIR) $(REPORT_DIR)
endif
ifeq ($(TARGET),intel)
	@echo "Running Intel Quartus synthesis..."
	$(QUARTUS) $(QUARTUS_FLAGS) $(QUARTUS_TCL) \
		$(TOP_MODULE) $(PART) $(RTL_DIR) $(BUILD_DIR)
endif

# Run implementation
impl: synth
ifeq ($(TARGET),xilinx)
	@echo "Running implementation..."
	$(VIVADO) $(VIVADO_FLAGS) $(SCRIPT_DIR)/impl_vivado.tcl -tclargs \
		$(TOP_MODULE) $(BUILD_DIR) $(REPORT_DIR)
endif

# Generate bitstream
bitstream: impl
ifeq ($(TARGET),xilinx)
	@echo "Generating bitstream..."
	$(VIVADO) $(VIVADO_FLAGS) $(SCRIPT_DIR)/bitstream_vivado.tcl -tclargs \
		$(TOP_MODULE) $(BUILD_DIR) $(BITSTREAM_DIR)
	@echo "Bitstream generated: $(BITSTREAM_DIR)/$(TOP_MODULE).bit"
endif
ifeq ($(TARGET),intel)
	@echo "Generating programming file..."
	quartus_asm $(TOP_MODULE)
	quartus_sta $(TOP_MODULE)
	@echo "Programming file generated: $(TOP_MODULE).sof"
endif

# Program FPGA
program:
ifeq ($(TARGET),xilinx)
	@echo "Programming FPGA..."
	$(VIVADO) $(VIVADO_FLAGS) $(SCRIPT_DIR)/program_vivado.tcl -tclargs \
		$(BITSTREAM_DIR)/$(TOP_MODULE).bit
endif
ifeq ($(TARGET),intel)
	@echo "Programming FPGA..."
	quartus_pgm -c 1 -m JTAG -o "p;$(TOP_MODULE).sof"
endif

# Generate reports
reports: synth
	@echo "Generating reports..."
ifeq ($(TARGET),xilinx)
	@cat $(REPORT_DIR)/utilization.rpt | grep -E "Slice|LUT|FF|BRAM|DSP" || true
	@cat $(REPORT_DIR)/timing.rpt | grep -E "WNS|TNS|WHS" || true
endif

# Clean build artifacts
clean:
	@echo "Cleaning FPGA build artifacts..."
	rm -rf $(BUILD_DIR) $(REPORT_DIR) $(BITSTREAM_DIR)
	rm -f *.jou *.log *.dcp *.bit *.sof
	rm -rf .Xil

# Help
help:
	@echo "FPGA Synthesis Makefile"
	@echo ""
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "Targets:"
	@echo "  synth          - Run synthesis"
	@echo "  impl           - Run implementation"
	@echo "  bitstream      - Generate bitstream"
	@echo "  program        - Program FPGA"
	@echo "  reports        - Generate and display reports"
	@echo "  clean          - Clean build artifacts"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  TARGET=xilinx|intel     - Select target vendor (default: xilinx)"
	@echo "  PART=<part_number>      - Specify FPGA part number"
	@echo "  TOP_MODULE=<name>       - Specify top module name"
	@echo ""
	@echo "Examples:"
	@echo "  make synth TARGET=xilinx PART=xc7k325tffg900-2"
	@echo "  make bitstream TARGET=intel PART=5CSEMA5F31C6"
	@echo "  make program"
