# OCPU Project Top-Level Makefile

.PHONY: all build test sim fpga docs clean help

all: build

# Build everything
build:
	@echo "Building OCPU project..."
	$(MAKE) -C sim build

# Run tests
test:
	@echo "Running tests..."
	$(MAKE) -C sim test_all

# Run specific test
test-%:
	$(MAKE) -C sim run TESTNAME=$*

# Open simulation
sim:
	cd sim && $(MAKE) run

# FPGA synthesis
fpga:
	$(MAKE) -C fpga synth

# FPGA implementation
impl:
	$(MAKE) -C fpga impl

# Generate bitstream
bitstream:
	$(MAKE) -C fpga bitstream

# Run lint check
lint:
	./scripts/lint_check.sh

# Generate statistics
stats:
	./scripts/gen_stats.py rtl/

# Generate documentation
docs:
	cd docs && make html

# Setup development environment
setup:
	./scripts/setup.sh

# Clean everything
clean:
	@echo "Cleaning project..."
	$(MAKE) -C sim clean
	$(MAKE) -C fpga clean
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete

# Deep clean (including build directories)
distclean: clean
	rm -rf sim/build sim/logs sim/waves
	rm -rf fpga/build fpga/reports fpga/bitstream

# Help
help:
	@echo "OCPU Project Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  build       - Build simulation"
	@echo "  test        - Run all tests"
	@echo "  test-<name> - Run specific test (e.g., test-basic)"
	@echo "  sim         - Run simulation"
	@echo "  fpga        - Run FPGA synthesis"
	@echo "  impl        - Run FPGA implementation"
	@echo "  bitstream   - Generate bitstream"
	@echo "  lint        - Run lint check"
	@echo "  stats       - Generate RTL statistics"
	@echo "  docs        - Generate documentation"
	@echo "  setup       - Setup development environment"
	@echo "  clean       - Clean build artifacts"
	@echo "  distclean   - Deep clean including build dirs"
	@echo "  help        - Show this help"
