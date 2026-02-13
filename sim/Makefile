# OCPU Simulation Makefile
# Supports: Verilator, VCS, ModelSim, Xcelium

# Configuration
SIMULATOR ?= verilator
TOP_MODULE ?= ocpu_core_tb
TESTNAME ?= basic

# Directories
RTL_DIR = ../rtl
TB_DIR = ../tb
BUILD_DIR = build
LOG_DIR = logs
WAVE_DIR = waves
COV_DIR = coverage

# RTL Sources
RTL_SOURCES = $(shell find $(RTL_DIR) -name "*.sv" | sort)
TB_SOURCES = $(shell find $(TB_DIR) -name "*.sv" | sort)

# Include directories
INCDIRS = $(RTL_DIR)/include

# Verilator configuration
ifeq ($(SIMULATOR),verilator)
VERILATOR = verilator
VERILATOR_FLAGS = --cc --exe --build --trace \
    -Wno-fatal \
    -Wno-lint \
    -Wall \
    -j 4 \
    -Mdir $(BUILD_DIR) \
    --top-module $(TOP_MODULE) \
    $(addprefix -I,$(INCDIRS))

VERILATOR_CFLAGS = -CFLAGS "-std=c++17 -O2"
VERILATOR_LDFLAGS = -LDFLAGS "-pthread"
endif

# VCS configuration
ifeq ($(SIMULATOR),vcs)
VCS = vcs
VCS_FLAGS = -full64 -sverilog -debug_access+all -kdb -ntb_opts uvm \
    -timescale=1ns/1ps \
    -l $(LOG_DIR)/vcs_compile.log \
    $(addprefix +incdir+,$(INCDIRS)) \
    -Mdir=$(BUILD_DIR)/csrc \
    -o $(BUILD_DIR)/simv
endif

# ModelSim configuration
ifeq ($(SIMULATOR),modelsim)
VSIM = vsim
VLOG = vlog
VLIB = vlib
VMAP = vmap
endif

# Default target
.PHONY: all build run test clean waves coverage

all: build

# Create directories
dirs:
	@mkdir -p $(BUILD_DIR) $(LOG_DIR) $(WAVE_DIR) $(COV_DIR)

# Build simulation
build: dirs
ifeq ($(SIMULATOR),verilator)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_CFLAGS) $(VERILATOR_LDFLAGS) \
		$(RTL_SOURCES) $(TB_SOURCES)
endif
ifeq ($(SIMULATOR),vcs)
	$(VCS) $(VCS_FLAGS) $(RTL_SOURCES) $(TB_SOURCES)
endif
ifeq ($(SIMULATOR),modelsim)
	$(VLIB) $(BUILD_DIR)/work
	$(VMAP) work $(BUILD_DIR)/work
	$(VLOG) -sv $(addprefix +incdir+,$(INCDIRS)) $(RTL_SOURCES) $(TB_SOURCES)
endif

# Run simulation
run: build
ifeq ($(SIMULATOR),verilator)
	./$(BUILD_DIR)/V$(TOP_MODULE) +testname=$(TESTNAME) 2>&1 | tee $(LOG_DIR)/sim_$(TESTNAME).log
endif
ifeq ($(SIMULATOR),vcs)
	./$(BUILD_DIR)/simv +testname=$(TESTNAME) 2>&1 | tee $(LOG_DIR)/sim_$(TESTNAME).log
endif
ifeq ($(SIMULATOR),modelsim)
	$(VSIM) -c -do "run -all; quit" work.$(TOP_MODULE) 2>&1 | tee $(LOG_DIR)/sim_$(TESTNAME).log
endif

# Run tests
test: run

test_basic: dirs
	@echo "Running basic test..."
	$(MAKE) run TESTNAME=basic

test_rv64i: dirs
	@echo "Running RV64I instruction tests..."
	$(MAKE) run TESTNAME=rv64i

test_rv64m: dirs
	@echo "Running RV64M multiply/divide tests..."
	$(MAKE) run TESTNAME=rv64m

test_rv64f: dirs
	@echo "Running RV64F floating-point tests..."
	$(MAKE) run TESTNAME=rv64f

test_rv64d: dirs
	@echo "Running RV64D double-precision tests..."
	$(MAKE) run TESTNAME=rv64d

test_compliance: dirs
	@echo "Running RISC-V compliance tests..."
	$(MAKE) run TESTNAME=compliance

test_all: dirs
	@echo "Running all tests..."
	$(MAKE) test_basic
	$(MAKE) test_rv64i
	$(MAKE) test_rv64m
	# $(MAKE) test_rv64f
	# $(MAKE) test_rv64d

# Generate waves
waves:
	@echo "Opening waveform viewer..."
ifeq ($(SIMULATOR),verilator)
	gtkwave $(WAVE_DIR)/dump.vcd &
endif
ifeq ($(SIMULATOR),vcs)
	verdi -dbdir $(BUILD_DIR)/simv.daidir -ssf $(WAVE_DIR)/waves.fsdb &
endif

# Coverage report
coverage:
ifeq ($(SIMULATOR),verilator)
	verilator_coverage --write-info $(COV_DIR)/coverage.info $(COV_DIR)/coverage.dat
	genhtml $(COV_DIR)/coverage.info --output-directory $(COV_DIR)/html
endif
ifeq ($(SIMULATOR),vcs)
	urg -dir $(COV_DIR)/simv.vdb -format both -report $(COV_DIR)/report
endif

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(LOG_DIR) $(WAVE_DIR) $(COV_DIR)
	rm -f *.log *.vcd *.vpd *.fsdb
	rm -f ucli.key novas.conf verdiLog

# Help
help:
	@echo "OCPU Simulation Makefile"
	@echo ""
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "Targets:"
	@echo "  build          - Build simulation"
	@echo "  run            - Run simulation (default test: basic)"
	@echo "  test           - Run specific test"
	@echo "  test_basic     - Run basic functionality test"
	@echo "  test_rv64i     - Run RV64I instruction tests"
	@echo "  test_rv64m     - Run RV64M multiply/divide tests"
	@echo "  test_compliance- Run RISC-V compliance tests"
	@echo "  test_all       - Run all tests"
	@echo "  waves          - Open waveform viewer"
	@echo "  coverage       - Generate coverage report"
	@echo "  clean          - Clean build artifacts"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  SIMULATOR=verilator|vcs|modelsim  - Select simulator (default: verilator)"
	@echo "  TESTNAME=<name>                   - Specify test name"
	@echo "  TOP_MODULE=<name>                 - Specify top module"
	@echo ""
	@echo "Examples:"
	@echo "  make build SIMULATOR=vcs"
	@echo "  make run TESTNAME=rv64i"
	@echo "  make test_all SIMULATOR=verilator"
