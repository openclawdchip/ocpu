# OCPU Technical Reference Manual (TRM)
# OCPU技术参考手册

**Version**: 3.0  
**Document ID**: OCPU-TRM-3.0  
**Release Date**: 2026-02-13  
**Process**: 3nm  
**Bus Width**: 512-bit

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Processor Overview](#2-processor-overview)
3. [Microarchitecture](#3-microarchitecture)
4. [Memory Model](#4-memory-model)
5. [Register Set](#5-register-set)
6. [Instruction Set](#6-instruction-set)
7. [Memory Management](#7-memory-management)
8. [Interrupts and Exceptions](#8-interrupts-and-exceptions)
9. [Cache Architecture](#9-cache-architecture)
10. [Bus Interface](#10-bus-interface)
11. [Power Management](#11-power-management)
12. [Debug Support](#12-debug-support)
13. [Performance Monitoring](#13-performance-monitoring)
14. [Implementation Details](#14-implementation-details)
15. [Electrical Specifications](#15-electrical-specifications)
16. [Appendix](#16-appendix)

---

## 1. Introduction

### 1.1 Document Purpose

This Technical Reference Manual (TRM) provides comprehensive technical information about the OCPU processor, including its architecture, programming model, memory organization, and implementation details.

### 1.2 Intended Audience

This document is intended for:
- System architects designing SoCs with OCPU
- Software developers writing low-level code
- Hardware engineers integrating OCPU
- Verification engineers testing implementations

### 1.3 Document Conventions

- **3nm**: Process technology node
- **512-bit**: Internal bus width
- **16-issue**: Maximum instructions issued per cycle
- **VLEN=1024**: Vector register length

### 1.4 Related Documents

- [Architecture Overview](docs/architecture.md)
- [Configuration Guide](CONFIG_UPGRADE_3.0.md)
- [Module Design Documents](docs/modules/)

---

## 2. Processor Overview

### 2.1 Key Features

| Feature | Specification |
|---------|---------------|
| **Architecture** | RISC-V RV64I/M/F/D/V |
| **Process Node** | 3nm |
| **Clock Frequency** | 3GHz+ (up to 4GHz) |
| **Issue Width** | 16 instructions/cycle |
| **Pipeline Depth** | 10 stages |
| **Execution Model** | Out-of-Order (OOO) |
| **Physical Registers** | 512 (integer/float), 256 (vector) |
| **ROB Depth** | 256 entries |
| **Vector Length** | 1024-bit (VLEN=1024) |

### 2.2 Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              OCPU 3.0 Block Diagram                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐│
│   │   IFetch     │───▶│   Decode     │───▶│   Rename     │───▶│   Issue      ││
│   │   (40 files) │    │   (40 files) │    │   (40 files) │    │   (38 files) ││
│   │   256KB L1I  │    │   16-wide    │    │   512 PREG   │    │   16-wide    ││
│   └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘│
│          │                                                      │              │
│          │              ┌───────────────────────────────────────┘              │
│          │              ▼                                                      │
│          │     ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│          │     │   Execute    │◀───│   LoadStore  │◀───│   Commit     │       │
│          │     │   (54 files) │    │   (43 files) │    │   (41 files) │       │
│          │     │   10 SX      │    │   8 LSU      │    │   256 ROB    │       │
│          │     │   6 MX       │    │   64KB L1D   │    │   16-wide    │       │
│          │     │   6 FPU      │    └──────────────┘    └──────────────┘       │
│          │     │   8 VPU      │            │                                    │
│          │     └──────────────┘            ▼                                    │
│          │                       ┌──────────────┐    ┌──────────────┐          │
│          │                       │   L2 Cache   │◀───│    MMU       │          │
│          │                       │   (41 files) │    │   (40 files) │          │
│          │                       │   4MB        │    │   Sv39       │          │
│          └──────────────────────▶│   16-way     │    │   3-level    │          │
│                                  └──────────────┘    └──────────────┘          │
│                                         │                                      │
│                                         ▼                                      │
│                                  ┌──────────────┐                              │
│                                  │   Core Ctrl  │                              │
│                                  │   (40 files) │                              │
│                                  │   Timer      │                              │
│                                  │   Interrupt  │                              │
│                                  └──────────────┘                              │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Performance Specifications

| Metric | Value | Conditions |
|--------|-------|------------|
| **Peak IPC** | ~12-14 | Ideal conditions |
| **Sustained IPC** | 8-10 | Typical workload |
| **Memory Bandwidth** | 64 GB/s | @ 1GHz, 512-bit bus |
| **FP Throughput** | 192 GFLOPS | @ 3GHz, 6 FPUs |
| **Vector Throughput** | 3 TFLOPS | @ 3GHz, 8 VPUs |
| **Power Consumption** | TBD | @ 3GHz, typical load |

---

## 3. Microarchitecture

### 3.1 Pipeline Stages

| Stage | Name | Description | Latency |
|-------|------|-------------|---------|
| IF1-IF2 | Instruction Fetch | Generate PC, access ITLB | 2 cycles |
| IC1-IC2 | I-Cache Access | Access 256KB L1-I | 2 cycles |
| PD | Pre-decode | Branch prediction, instruction alignment | 1 cycle |
| ID | Decode | Decode to micro-ops | 1 cycle |
| RN | Rename | Register renaming | 1 cycle |
| DI | Dispatch | Insert to issue queues | 1 cycle |
| IS | Issue | Select and issue to execution units | 1 cycle |
| EX | Execute | Execution units | 1-6 cycles |
| WB | Writeback | Write results to register file | 1 cycle |
| CT | Commit | Commit to architectural state | 1 cycle |

### 3.2 Execution Units

| Unit Type | Count | Latency | Throughput |
|-----------|-------|---------|------------|
| **SX (Simple ALU)** | 10 | 1 cycle | 10/cycle |
| **MX (MAC)** | 6 | 3 cycles | 6/cycle |
| **FPU (Float)** | 6 | 4 cycles | 6/cycle |
| **VPU (Vector)** | 8 | 6 cycles | 8/cycle |
| **LSU (Load/Store)** | 8 | 2-3 cycles | 8/cycle |
| **BR (Branch)** | 4 | 1 cycle | 4/cycle |
| **DIV (Divide)** | 2 | Variable | 2/cycle |

### 3.3 Issue Queues

| Queue | Depth | Issue Width | Description |
|-------|-------|-------------|-------------|
| **SXQ** | 40 | 10 | Integer instructions |
| **MXQ** | 32 | 6 | Multiply-accumulate |
| **LSQ** | 48 | 8 | Load/Store |
| **BXQ** | 32 | 4 | Branches |
| **VXQ** | 48 | 8 | Vector instructions |

---

## 4. Memory Model

### 4.1 Physical Address Space

```
┌────────────────────────────────────────────────────────────────┐
│                  52-bit Physical Address Space                  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  0x0000_0000_0000_0000 ─┬─▶ I/O Region (4GB)                  │
│                         │   (0x0000_0000 to 0xFFFF_FFFF)       │
│                         │                                      │
│  0x0000_0001_0000_0000 ─┼─▶ Reserved                          │
│                         │                                      │
│  0x0000_8000_0000_0000 ─┼─▶ Main Memory (2TB)                 │
│                         │   (0x8000_0000_0000 to               │
│                         │    0x000F_FFFF_FFFF_FFFF)             │
│                         │                                      │
│  0x0010_0000_0000_0000 ─┼─▶ Reserved                          │
│                         │                                      │
│  0xFFFF_FFFF_FFFF_FFFF ─┴─▶ End of Address Space               │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 4.2 Virtual Memory

- **Sv39**: 39-bit virtual address
- **Levels**: 3-level page table walk
- **Page Sizes**: 4KB, 2MB, 1GB
- **ASID**: 16-bit Address Space ID

### 4.3 Memory Types

| Memory Type | Cacheable | Coherent | Description |
|-------------|-----------|----------|-------------|
| **Normal** | Yes | Yes | Regular memory |
| **Device** | No | No | MMIO regions |
| **Strongly-ordered** | No | N/A | System control |

---

## 5. Register Set

### 5.1 Integer Registers (X0-X31)

| Register | ABI Name | Description |
|----------|----------|-------------|
| X0 | zero | Hardwired zero |
| X1 | ra | Return address |
| X2 | sp | Stack pointer |
| X3 | gp | Global pointer |
| X4 | tp | Thread pointer |
| X5-X7 | t0-t2 | Temporary registers |
| X8 | s0/fp | Saved register / Frame pointer |
| X9 | s1 | Saved register |
| X10-X11 | a0-a1 | Function arguments / Return values |
| X12-X17 | a2-a7 | Function arguments |
| X18-X27 | s2-s11 | Saved registers |
| X28-X31 | t3-t6 | Temporary registers |

### 5.2 Floating-Point Registers (F0-F31)

| Register | ABI Name | Description |
|----------|----------|-------------|
| F0-F7 | ft0-ft7 | FP temporaries |
| F8-F9 | fs0-fs1 | FP saved registers |
| F10-F11 | fa0-fa1 | FP arguments / Return values |
| F12-F17 | fa2-fa7 | FP arguments |
| F18-F27 | fs2-fs11 | FP saved registers |
| F28-F31 | ft8-ft11 | FP temporaries |

### 5.3 Vector Registers (V0-V31)

- **VLEN**: 1024 bits
- **Physical Registers**: 256
- **LMUL**: 1, 2, 4, 8
- **SEW**: 8, 16, 32, 64

### 5.4 Control and Status Registers (CSRs)

#### Machine Level CSRs

| CSR | Address | Description |
|-----|---------|-------------|
| mstatus | 0x300 | Machine status |
| misa | 0x301 | ISA and extensions |
| medeleg | 0x302 | Exception delegation |
| mideleg | 0x303 | Interrupt delegation |
| mie | 0x304 | Interrupt enable |
| mtvec | 0x305 | Trap handler base address |
| mcounteren | 0x306 | Counter enable |
| mscratch | 0x340 | Scratch register |
| mepc | 0x341 | Exception program counter |
| mcause | 0x342 | Exception cause |
| mtval | 0x343 | Trap value |
| mip | 0x344 | Interrupt pending |
| mcycle | 0xB00 | Cycle counter |
| minstret | 0xB02 | Instructions retired |
| mhpmcounter3-31 | 0xB03-0xB1F | Performance counters |

#### Supervisor Level CSRs

| CSR | Address | Description |
|-----|---------|-------------|
| sstatus | 0x100 | Supervisor status |
| sie | 0x104 | Interrupt enable |
| stvec | 0x105 | Trap handler base |
| scounteren | 0x106 | Counter enable |
| sscratch | 0x140 | Scratch register |
| sepc | 0x141 | Exception PC |
| scause | 0x142 | Exception cause |
| stval | 0x143 | Trap value |
| sip | 0x144 | Interrupt pending |
| satp | 0x180 | Page table base |

---

## 6. Instruction Set

### 6.1 Supported Extensions

| Extension | Version | Description |
|-----------|---------|-------------|
| **RV64I** | 2.1 | Base integer (64-bit) |
| **M** | 2.0 | Integer multiplication/division |
| **A** | 2.1 | Atomic instructions |
| **F** | 2.2 | Single-precision floating-point |
| **D** | 2.2 | Double-precision floating-point |
| **V** | 1.0 | Vector operations |
| **Zicsr** | 2.0 | CSR instructions |
| **Zifencei** | 2.0 | Instruction fence |
| **Zicbom** | 1.0 | Cache block management |

### 6.2 Instruction Formats

```
R-type:  | funct7 | rs2 | rs1 | funct3 | rd | opcode |
I-type:  | imm[11:0] | rs1 | funct3 | rd | opcode |
S-type:  | imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode |
B-type:  | imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode |
U-type:  | imm[31:12] | rd | opcode |
J-type:  | imm[20|10:1|11|19:12] | rd | opcode |
V-type:  | funct6 | vm | vs2 | vs1 | funct3 | vd | opcode |
```

---

## 7. Memory Management

### 7.1 Address Translation

```
┌─────────────────────────────────────────────────────────────────┐
│                    Virtual to Physical Translation               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Virtual Address (39-bit):                                       │
│  ┌────────┬────────┬────────┬────────┐                          │
│  │ VPN[2] │ VPN[1] │ VPN[0] │ offset │                          │
│  │ 9-bit  │ 9-bit  │ 9-bit  │ 12-bit │                          │
│  └────────┴────────┴────────┴────────┘                          │
│       │         │         │                                      │
│       ▼         ▼         ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Page Table Walk (3-level):                              │    │
│  │  Level 2 (Root) → Level 1 → Level 0 → Physical Page      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Physical Address (52-bit):                                      │
│  ┌────────────────────────────────┬────────┐                    │
│  │ PPN (Physical Page Number)     │ offset │                    │
│  │ 40-bit                         │ 12-bit │                    │
│  └────────────────────────────────┴────────┘                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 TLB Organization

| TLB | Entries | Page Sizes | Description |
|-----|---------|------------|-------------|
| **ITLB** | 64 | 4KB, 2MB, 1GB | Instruction TLB |
| **DTLB** | 64 | 4KB, 2MB, 1GB | Data TLB |
| **STLB** | 64 | 4KB, 2MB, 1GB | Secondary TLB |

### 7.3 Memory Protection

- **PMP**: 16 Physical Memory Protection regions
- ** PMA**: Physical Memory Attributes
- **Access Types**: Read, Write, Execute, User, Supervisor, Machine

---

## 8. Interrupts and Exceptions

### 8.1 Exception Causes

| Cause Code | Name | Description |
|------------|------|-------------|
| 0 | Instruction address misaligned | PC not aligned |
| 1 | Instruction access fault | Page/access fault on fetch |
| 2 | Illegal instruction | Unrecognized instruction |
| 3 | Breakpoint | EBREAK instruction |
| 4 | Load address misaligned | Unaligned load address |
| 5 | Load access fault | Page/access fault on load |
| 6 | Store/AMO address misaligned | Unaligned store address |
| 7 | Store/AMO access fault | Page/access fault on store |
| 8 | Environment call from U-mode | ECALL from user |
| 9 | Environment call from S-mode | ECALL from supervisor |
| 11 | Environment call from M-mode | ECALL from machine |
| 12 | Instruction page fault | Page fault on instruction |
| 13 | Load page fault | Page fault on load |
| 15 | Store/AMO page fault | Page fault on store |

### 8.2 Interrupt Sources

| Interrupt | Code | Description |
|-----------|------|-------------|
| **Software** | 0-2 | Software-generated |
| **Timer** | 4-6 | Timer interrupt |
| **External** | 8-10 | External interrupt |
| **Local** | 16+ | Implementation-defined |

### 8.3 Trap Handling

```
Trap Entry:
1. Save current privilege mode
2. Save current PC to mepc (or sepc)
3. Set mcause (or scause) to trap cause
4. Set mtval (or stval) to trap-specific info
5. Switch to trap handler privilege mode
6. Jump to mtvec (or stvec) handler address

Trap Return (MRET/SRET):
1. Restore privilege mode
2. Restore PC from mepc (or sepc)
3. Resume execution
```

---

## 9. Cache Architecture

### 9.1 Cache Hierarchy

| Level | Size | Associativity | Line Size | Interface |
|-------|------|---------------|-----------|-----------|
| **L1-I** | 256KB | 8-way | 64B | 512-bit |
| **L1-D** | 64KB | 8-way | 64B | 512-bit |
| **L2** | 4MB | 16-way | 64B | 512-bit |

### 9.2 Cache Line Format

```
┌─────────────────────────────────────────────────────────────────┐
│                      Cache Line (64 bytes)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Data: 64 bytes (512 bits)                                      │
│                                                                  │
│  Tag: 46-bit physical address tag                               │
│                                                                  │
│  State: MESI (2-bit)                                            │
│    - M: Modified                                                │
│    - E: Exclusive                                               │
│    - S: Shared                                                  │
│    - I: Invalid                                                 │
│                                                                  │
│  LRU: 4-bit (for 16-way)                                        │
│                                                                  │
│  Dirty: 1-bit (for write-back)                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 9.3 Coherency Protocol

- **Protocol**: MESI
- **Snooping**: Directory-based snooping
- **Write Policy**: Write-back, Write-allocate
- **Replacement**: Pseudo-LRU

---

## 10. Bus Interface

### 10.1 AXI5-CHI Interface

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| **REQFLIT** | 128-bit | Outbound | Request flit |
| **RSPFLIT** | 64-bit | Inbound | Response flit |
| **DATFLIT** | 512-bit | Bidirectional | Data flit |
| **SNPFLIT** | 88-bit | Inbound | Snoop flit |

### 10.2 Transaction Types

| Transaction | Description |
|-------------|-------------|
| **ReadNoSnp** | Non-snooping read |
| **ReadOnce** | Snooping read, no allocate |
| **ReadShared** | Snooping read, to Shared |
| **ReadUnique** | Snooping read, to Unique |
| **WriteNoSnp** | Non-snooping write |
| **WriteUnique** | Snooping write, no allocate |
| **WriteLineUnique** | Snooping write full line |

---

## 11. Power Management

### 11.1 Power Domains

| Domain | Voltage | Components |
|--------|---------|------------|
| **Core** | 0.5V-0.85V | Integer units |
| **FPU** | 0.5V-0.85V | Floating-point |
| **Vector** | 0.5V-0.85V | Vector units |
| **Cache** | 0.5V-0.85V | L1/L2 caches |
| **System** | 0.5V-0.85V | MMU, interconnect |

### 11.2 Power States

| State | Description | Wake-up Latency |
|-------|-------------|-----------------|
| **RUN** | Full operation | - |
| **IDLE** | Clock gated | <1us |
| **RET** | Retention | <10us |
| **OFF** | Power off | <100us |

### 11.3 Dynamic Voltage Frequency Scaling (DVFS)

| Level | Voltage | Frequency | Power |
|-------|---------|-----------|-------|
| P0 | 0.85V | 4.0GHz | 100% |
| P1 | 0.75V | 3.0GHz | 60% |
| P2 | 0.65V | 2.0GHz | 35% |
| P3 | 0.55V | 1.0GHz | 15% |
| P4 | 0.50V | 0.5GHz | 8% |

---

## 12. Debug Support

### 12.1 Debug Features

- **JTAG Interface**: IEEE 1149.1 compliant
- **Debug Mode**: Halt and single-step
- **Breakpoints**: 8 hardware breakpoints
- **Watchpoints**: 4 data watchpoints
- **Program Buffer**: 16-entry program buffer

### 12.2 Debug CSRs

| CSR | Address | Description |
|-----|---------|-------------|
| dcsr | 0x7B0 | Debug control and status |
| dpc | 0x7B1 | Debug PC |
| dscratch0 | 0x7B2 | Debug scratch 0 |
| dscratch1 | 0x7B3 | Debug scratch 1 |

---

## 13. Performance Monitoring

### 13.1 Performance Counters

| Counter | Event | Description |
|---------|-------|-------------|
| **mcycle** | Cycle | Core clock cycles |
| **minstret** | InstRet | Instructions retired |
| **mhpmcounter3** | Branch | Branch instructions |
| **mhpmcounter4** | BranchMiss | Branch mispredictions |
| **mhpmcounter5** | Load | Load instructions |
| **mhpmcounter6** | Store | Store instructions |
| **mhpmcounter7** | I-CacheMiss | L1-I cache misses |
| **mhpmcounter8** | D-CacheMiss | L1-D cache misses |
| **mhpmcounter9** | L2Miss | L2 cache misses |

### 13.2 PMU Events

| Event ID | Event | Description |
|----------|-------|-------------|
| 0x0001 | CPU_CYCLES | Core clock cycles |
| 0x0002 | INST_RETIRED | Instructions retired |
| 0x0003 | INST_SPEC | Instructions speculatively executed |
| 0x0004 | BR_RETIRED | Branch instructions retired |
| 0x0005 | BR_MISPRED | Branch mispredictions |
| 0x0006 | MEM_ACCESS | Memory accesses |
| 0x0007 | L1I_CACHE | L1-I cache accesses |
| 0x0008 | L1I_CACHE_MISS | L1-I cache misses |
| 0x0009 | L1D_CACHE | L1-D cache accesses |
| 0x000A | L1D_CACHE_MISS | L1-D cache misses |

---

## 14. Implementation Details

### 14.1 RTL Statistics

| Metric | Value |
|--------|-------|
| **RTL Files** | 420 |
| **Code Lines** | ~50,000+ |
| **Modules** | 11 core + 400+ sub |
| **Gates (est.)** | TBD |
| **Area (est.)**  | TBD |

### 14.2 Timing Parameters

| Parameter | Value |
|-----------|-------|
| **Clock Period** | 250ps (4GHz) - 333ps (3GHz) |
| **Setup Time** | TBD |
| **Hold Time** | TBD |
| **I/O Delay** | TBD |

---

## 15. Electrical Specifications

### 15.1 Operating Conditions

| Parameter | Min | Typ | Max | Units |
|-----------|-----|-----|-----|-------|
| **VDD** | 0.50 | 0.75 | 0.85 | V |
| **Temperature** | -40 | 25 | 125 | °C |
| **Frequency** | 0.5 | 3.0 | 4.0 | GHz |

### 15.2 Power Estimates

| Mode | Power | Conditions |
|------|-------|------------|
| **Peak** | TBD | All units active @ 4GHz |
| **Typical** | TBD | Average workload @ 3GHz |
| **Idle** | TBD | Clock gated |
| **Sleep** | TBD | Retention mode |

---

## 16. Appendix

### A. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-13 | Initial release, 7nm, 128-bit bus |
| 2.0 | 2026-02-13 | Performance upgrade, 16-issue, 512KB L2 |
| **3.0** | **2026-02-13** | **3nm process, 512-bit bus, 4MB L2** |

### B. Related Specifications

- RISC-V Instruction Set Manual
- RISC-V Privileged Architecture
- RISC-V Vector Extension
- AMBA 5 CHI Architecture

### C. Glossary

| Term | Definition |
|------|------------|
| **ASID** | Address Space ID |
| **BTB** | Branch Target Buffer |
| **CSR** | Control and Status Register |
| **DVFS** | Dynamic Voltage and Frequency Scaling |
| **FPU** | Floating-Point Unit |
| **GHB** | Global History Buffer |
| **MMU** | Memory Management Unit |
| **MSHR** | Miss Status Handling Register |
| **PMP** | Physical Memory Protection |
| **RAT** | Register Alias Table |
| **ROB** | Reorder Buffer |
| **TLB** | Translation Lookaside Buffer |
| **VPU** | Vector Processing Unit |

---

**Document Revision**: 3.0  
**Release Date**: 2026-02-13  
**Process Technology**: 3nm  
**Bus Architecture**: 512-bit

---

© 2026 OCPU Project. All rights reserved.
