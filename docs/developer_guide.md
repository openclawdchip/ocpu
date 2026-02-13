# Developer Guide

## Overview

This guide provides information for developers who want to contribute to or extend the OCPU project.

## Development Environment

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 4.200+ | Simulation |
| Python | 3.8+ | Scripts |
| Make | 4.0+ | Build system |
| GTKWave | 3.3+ | Waveform viewer |

### Optional Tools

| Tool | Purpose |
|------|---------|
| VCS | Advanced simulation |
| Vivado | FPGA synthesis |
| Verdi | Debug and waveform |

### Setup Development Environment

```bash
# Clone repository
git clone https://github.com/openclawchip/ocpu/ocpu.git
cd ocpu

# Run setup script
./scripts/setup.sh

# Verify installation
make -C sim check
```

## Project Structure

```
ocpu/
├── rtl/              # RTL source code
│   ├── include/     # Global headers
│   ├── core/        # Core control
│   ├── ifetch/      # Instruction fetch
│   ├── idecode/     # Instruction decode
│   ├── rename/      # Register rename
│   ├── issue/       # Issue unit
│   ├── execute/     # Execution units
│   ├── loadstore/   # Load/store unit
│   ├── commit/      # Commit unit
│   ├── mmu/         # Memory management
│   └── level2/      # L2 cache
├── tb/              # Testbenches
├── sim/             # Simulation scripts
├── fpga/            # FPGA synthesis
├── scripts/         # Utility scripts
└── docs/            # Documentation
```

## Coding Standards

### SystemVerilog Style

1. **File Organization**
```systemverilog
//=========================================================================
// Module: ocpu_<module_name>
// Description: Brief description
// Author: Name
// Date: YYYY-MM-DD
// Version: 1.0
//=========================================================================

`include "ocpu_header.sv"

module ocpu_module_name #(
    parameter PARAM1 = default_value,
    parameter PARAM2 = default_value
) (
    // Clock and reset
    input  wire clk,
    input  wire reset_n,
    
    // Input ports
    input  wire [WIDTH-1:0] data_in,
    
    // Output ports
    output reg  [WIDTH-1:0] data_out
);

  // Parameter validation
  // Local declarations
  // Combinational logic
  // Sequential logic

endmodule
```

2. **Naming Conventions**
   - Modules: `ocpu_<name>.sv` (lowercase)
   - Parameters: `OCPU_<NAME>` (uppercase)
   - Signals: `signal_name` (lowercase)
   - Clocks: `clk`, `clk_<name>`
   - Resets: `reset_n` (active low)

3. **Comments**
   - Use `//` for single-line comments
   - Use `/* */` for multi-line comments
   - Document every module, port, and parameter

## Adding New Features

### 1. Adding a New Module

1. Create module file in appropriate directory:
```bash
touch rtl/<module>/ocpu_<new_module>.sv
```

2. Implement module following coding standards

3. Add to simulation:
```makefile
# Add to sim/Makefile RTL_SOURCES
```

4. Create testbench:
```bash
touch tb/tb_<new_module>.sv
```

5. Add documentation to `docs/modules/`

### 2. Adding a New Instruction

1. Update decoder in `rtl/idecode/`
2. Add execution logic in `rtl/execute/`
3. Update scoreboard in `rtl/issue/`
4. Add test case in `sim/tests/`

## Testing

### Unit Tests

```bash
# Run specific module test
cd sim
make test MODULE=ifetch

# Run with waveform
cd sim
make run MODULE=ifetch WAVES=1
```

### Integration Tests

```bash
# Run RISC-V compliance tests
cd sim
make test_compliance

# Run all tests
cd sim
make test_all
```

### Coverage

```bash
# Generate coverage report
cd sim
make coverage

# View report
firefox coverage/html/index.html
```

## Debugging

### Using GTKWave

```bash
cd sim
make run WAVES=1
gtkwave waves/dump.vcd &
```

### Common Issues

1. **Simulation hangs**
   - Check for combinatorial loops
   - Verify clock generation
   - Check reset sequence

2. **Wrong results**
   - Verify testbench stimulus
   - Check data endianness
   - Review pipeline stages

3. **Synthesis fails**
   - Check for unsupported constructs
   - Verify constraints
   - Review timing paths

## Performance Tuning

### Critical Path Analysis

```bash
cd fpga
make impl
# Review timing reports in reports/timing.rpt
```

### Optimization Techniques

1. **Pipeline balancing**
   - Equalize stage delays
   - Add pipeline registers if needed

2. **Resource sharing**
   - Share multipliers/dividers
   - Time-multiplex resources

3. **Memory optimization**
   - Use block RAM efficiently
   - Optimize cache parameters

## Contribution Workflow

1. **Fork and clone**
```bash
git clone https://github.com/openclawdchip/ocpu/ocpu.git
cd ocpu
```

2. **Create branch**
```bash
git checkout -b feature/new-feature
```

3. **Make changes**
   - Follow coding standards
   - Add tests
   - Update documentation

4. **Test locally**
```bash
make test_all
make lint
```

5. **Commit and push**
```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/new-feature
```

6. **Create Pull Request**
   - Fill PR template
   - Link related issues
   - Request review

## Release Process

1. Update version number
2. Update CHANGELOG.md
3. Create release tag
4. Build release package
5. Upload to GitHub

## Resources

- [RISC-V Spec](https://riscv.org/specifications/)
- [SystemVerilog LRM](https://ieeexplore.ieee.org/document/8299595)
- [Verilator Manual](https://verilator.org/guide/latest/)

## Getting Help

- GitHub Issues: Bug reports and feature requests
- Discussions: General questions
- Email: xiao.lin@ia.ac.cn

---

Thank you for contributing to OCPU!
