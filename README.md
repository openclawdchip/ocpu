⚠️ 免责声明 / Disclaimer

本代码仅用于学习使用，禁止用于任何商业用途。违反本声明引发的任何问题我们不承担任何法律责任。

This code is for educational purposes only. Commercial use is strictly prohibited. We assume no legal liability for any issues arising from violation of this statement.


# OCPU - Open CPU

**OCPU (Open CPU)** is an open-source high-performance RISC-V processor design featuring an innovative dual-mode architecture (Human Mode + Agent Mode), supporting the pure 64-bit RISC-V instruction set architecture (RV64I/M/F/D/V).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![RISC-V](https://img.shields.io/badge/RISC--V-RV64G-blue)](https://riscv.org/)
[![Architecture](https://img.shields.io/badge/Architecture-Dual--Mode-green)]()

---

## 🎯 Project Introduction

OCPU is a future-oriented open-source processor design that combines traditional out-of-order (OOO) execution with modern Agent static scheduling architectures, providing a unified hardware platform for general-purpose computing and AI acceleration.

### Core Features

- **🔄 Dual-Mode Architecture**: Human Mode (OOO) + Agent Mode (Static Scheduling)
- **⚡ High Performance**: 16-issue superscalar, 256-entry ROB, 38 shared execution units
- **🔧 Pure 64-bit**: Full RV64I/M/F/D/V support, no 32-bit compatibility overhead
- **📊 Vector Extensions**: RISC-V Vector v1.0, 1024-bit VLEN
- **💾 Memory Hierarchy**: 256KB L1-I / 64KB L1-D / 4MB L2 (Human) + 512KB SRAM (Agent)
- **🤖 Agent-Native**: Supports Agent real-time code generation and execution
- **🎯 Shared Backend**: Human and Agent modes share execution units, 40% area savings

---

## 🏗️ Architecture Overview

### Shared Execution Backend (v4.1)

Human Mode and Agent Mode **share physical execution units**, maximizing hardware utilization:

```
                    ┌─────────────────────────────┐
                    │    Execution Unit Pool      │
                    │  10 SX + 6 MX + 6 FPU +     │
                    │  8 VPU + 8 LSU = 38 EU      │
┌──────────────────┐│                             │┌──────────────────┐
│   Human Mode     ││      SHARED BACKEND         ││   Agent Mode     │
│  (OOO Frontend)  │◀┤   ┌─────────────────┐     ├▶│ (Static Front)   │
│                  │ │   │ Request Arbiter │     │ │                  │
│  Dynamic Issue   │ │   │ EU Allocation   │     │ │  Static Issue    │
│  ROB-based       │ │   │ Result Collect  │     │ │  Table-based     │
└──────────────────┘│   └─────────────────┘     │└──────────────────┘
                    └─────────────────────────────┘
```

### Human Mode

Traditional out-of-order execution architecture optimized for single-thread performance:

```
┌─────────────────────────────────────────────────────────────┐
│  16-wide Fetch  →  Decode  →  Rename  →  Issue  →  Execute  │
│  256KB L1-I        16-wide     512 PREG    OOO      44 EU    │
│  BTB/GHB/RAS                                              │
└─────────────────────────────────────────────────────────────┘
```

**Specifications**:
- Issue Width: 16
- ROB Depth: 256
- Physical Registers: 512 (scalar) + 256 (vector)
- Execution Units: 10 SX + 6 MX + 6 FPU + 8 VPU + 8 LSU + 4 BR + 2 DIV
- Branch Prediction: BTB 2048 + GHB 8192 + RAS 32 + TAGE

### Agent Mode

Static scheduling architecture for AI and deterministic computing:

```
┌─────────────────────────────────────────────────────────────┐
│  Task Descriptor → Code Generator → Static Scheduler → Shared│
│  (128-bit)          (Real-time)     (Deterministic)  Backend│
└─────────────────────────────────────────────────────────────┘
│                                                              │
│                    Direct SRAM Access                        │
│                 (512KB, 16 Bank, No Cache)                   │
└─────────────────────────────────────────────────────────────┘
```

**Specifications**:
- Static Issue Width: 16
- Schedule Table: 256 entries
- SRAM: 512KB (16 Bank × 32KB)
- Latency: 2-cycle deterministic
- Code Generation: Real-time, no software concept

---

## 📁 Project Structure

```
ocpu/
├── rtl/                      # RTL source code (433+ SystemVerilog files)
│   ├── include/              # Global header files and parameter definitions
│   ├── ifetch/               # Fetch unit (40 files)
│   ├── idecode/              # Decode unit (40 files)
│   ├── rename/               # Rename unit (40 files)
│   ├── issue/                # Issue unit (38 files)
│   ├── execute/              # Execute unit (54 files)
│   ├── loadstore/            # Load/Store unit (43 files)
│   ├── commit/               # Commit unit (41 files)
│   ├── mmu/                  # Memory Management Unit (40 files)
│   ├── level2/               # L2 cache (41 files)
│   ├── core/                 # Core control (43 files)
│   │   ├── ocpu_core_v4.sv              # v4.1 Top level
│   │   ├── ocpu_shared_execute_backend.sv  # Shared execution backend
│   │   ├── ocpu_execution_unit_pool.sv     # Execution unit pool
│   │   └── ocpu_human_mode_frontend.sv     # Human mode frontend
│   └── agent_mode/           # Agent mode (4 files)
├── docs/                     # Documentation (112 files)
│   ├── architecture.md                     # Architecture overview
│   ├── developer_guide.md                  # Developer guide
│   ├── user_guide.md                       # User guide
│   ├── api_reference.md                    # API reference
│   ├── shared_backend_architecture_v4.1.md # v4.1 Shared backend
│   ├── MODULE_DOCUMENTATION_SUMMARY.md     # Documentation index
│   ├── modules/              # Module design documents
│   └── submodules/           # Submodule documents
├── sim/                      # Simulation environment
│   ├── Makefile
│   └── test_program.hex
├── tb/                       # Testbench
│   └── tb_ocpu_core.sv
├── fpga/                     # FPGA synthesis scripts
│   └── Makefile
├── scripts/                  # Utility scripts
│   ├── setup.sh
│   ├── lint_check.sh
│   └── gen_stats.py
├── .github/                  # GitHub configuration
│   ├── workflows/            # CI/CD
│   └── ISSUE_TEMPLATE/       # Issue templates
├── OCPU_TRM_3.0.md          # Technical Reference Manual
├── DUAL_MODE_ARCHITECTURE_v4.0.md  # Dual-mode architecture document
├── DIDT_PLAN_3.0.md         # Verification plan
└── README.md                # This file
```

---

## 🚀 Quick Start

### Requirements

- **Operating System**: Linux (Ubuntu 22.04+ recommended)
- **Simulator**: Verilator (recommended), VCS, ModelSim
- **Synthesis Tools**: Vivado (Xilinx) or Quartus (Intel)
- **Python**: 3.8+ (for scripts)

### Install Dependencies

```bash
# Clone repository
git clone https://github.com/openclawdchip/ocpu/ocpu.git
cd ocpu

# Run setup script
./scripts/setup.sh

# Install Verilator (Ubuntu)
sudo apt-get install verilator
```

### Run Simulation

```bash
cd sim

# Using Verilator (default)
make test

# Using VCS
make test SIM=vcs

# Using ModelSim
make test SIM=modelsim
```

### FPGA Synthesis

```bash
cd fpga

# Xilinx Vivado
make bitstream VENDOR=xilinx

# Intel Quartus
make bitstream VENDOR=intel
```

---

## 📖 Documentation

### Architecture Documents

| Document | Description | Size |
|----------|-------------|------|
| [OCPU_TRM_3.0.md](OCPU_TRM_3.0.md) | Technical Reference Manual (Complete) | 26KB |
| [DUAL_MODE_ARCHITECTURE_v4.0.md](DUAL_MODE_ARCHITECTURE_v4.0.md) | Dual-Mode Architecture Design | 19KB |
| [docs/shared_backend_architecture_v4.1.md](docs/shared_backend_architecture_v4.1.md) | Shared Backend Architecture ★v4.1 | 17KB |
| [DIDT_PLAN_3.0.md](DIDT_PLAN_3.0.md) | Verification Test Plan | 21KB |

### Guides and References

| Document | Description | Size |
|----------|-------------|------|
| [docs/architecture.md](docs/architecture.md) | Architecture Overview | 8KB |
| [docs/developer_guide.md](docs/developer_guide.md) | Developer Guide | 9KB |
| [docs/user_guide.md](docs/user_guide.md) | User Guide ★v4.1 | 9KB |
| [docs/api_reference.md](docs/api_reference.md) | API Reference ★v4.1 | 9KB |
| [docs/MODULE_DOCUMENTATION_SUMMARY.md](docs/MODULE_DOCUMENTATION_SUMMARY.md) | Documentation Index ★v4.1 | 5KB |
| [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) | Project Summary | 7KB |

---

## 🔬 Technical Specifications

### Processor Core

| Parameter | Human Mode | Agent Mode |
|-----------|------------|------------|
| Architecture | RV64G + Vector | Agent-specific |
| Issue Width | 16 | 16 |
| ROB Depth | 256 | N/A (static) |
| Physical Registers | 512 + 256 | 64 dedicated |
| Execution Units | **38 (shared)** | **38 (shared)** |
| Floating-Point Units | 6 FPU | 6 FPU (shared) |
| Vector Units | 8 VPU (1024-bit) | 8 VPU (shared) |

### Memory System

| Level | Size | Associativity | Latency |
|-------|------|---------------|---------|
| L1-I | 256KB | 8-way | 2 cycles |
| L1-D | 64KB | 8-way | 3 cycles |
| L2 | 4MB | 16-way | 10 cycles |
| SRAM (Agent) | 512KB | 16 Bank | 2 cycles |

### Interfaces

| Interface | Protocol | Width |
|-----------|----------|-------|
| System Bus | CHI | 512-bit |
| Debug | JTAG/DMI | - |
| Interrupt | PLIC + CLINT | - |

---

## 🎯 Shared Backend Benefits (v4.1)

| Metric | v4.0 (Separate) | v4.1 (Shared) | Improvement |
|--------|-----------------|---------------|-------------|
| EU Area | 200% | 100% | **50% ↓** |
| Resource Utilization | 60% | 75% | **25% ↑** |
| Peak Performance | 100% | 100% | - |
| Mode Switch Overhead | ~1000 cycles | ~1000 cycles | - |

**Key Innovations**:
- 🏗️ **Three-layer Architecture**: Frontend → Arbitration → Execution
- ⚖️ **Dynamic Arbitration**: Request arbiter allocates EUs to both modes
- 📊 **EU Allocation Table**: Tracks state of all 38 execution units
- 🔄 **Seamless Mode Switch**: Drain → Save → Switch → Restore workflow

## 🧪 Verification Status

### Completed

- [x] Human Mode RTL complete implementation (420 files)
- [x] Agent Mode RTL implementation (4 files)
- [x] **Shared Execution Backend ★v4.1** (4 files)
- [x] **Execution Unit Pool ★v4.1** (38 shared EUs)
- [x] Basic testbench
- [x] Simulation environment (Verilator/VCS/ModelSim)
- [x] FPGA synthesis scripts
- [x] CI/CD workflow

### In Progress

- [ ] UVM verification environment
- [ ] Formal verification
- [ ] FPGA prototype verification
- [ ] Performance benchmark testing

---

## 🤝 Contributing

We welcome all forms of contributions! Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Ways to Contribute

- 🐛 Submit bug reports
- 💡 Propose new feature suggestions
- 🔧 Submit code improvements
- 📖 Improve documentation
- 🧪 Add test cases

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## 🙏 Acknowledgments

- RISC-V International for defining the excellent open instruction set architecture
- The RISC-V community for providing rich toolchains and reference implementations
- All contributors for their efforts and support

---

## 📞 Contact

- **Project Homepage**: https://github.com/openclawdchip/ocpu
- **Issue Tracking**: https://github.com/openclawdchip/ocpu/issues
- **Discussions**: https://github.com/openclawdchip/ocpu/discussions
- **E-mail**: xiao.lin@ia.ac.cn

---

<p align="center">
  <strong>OCPU - Open Processor for the Future</strong><br>
  Human Mode 🤝 Agent Mode
</p>



# OCPU - Open CPU

**OCPU (Open CPU)** 是一个开源的高性能RISC-V处理器设计，采用创新的双模架构（人类模式+Agent模式），支持纯64位RISC-V指令集架构（RV64I/M/F/D/V）。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![RISC-V](https://img.shields.io/badge/RISC--V-RV64G-blue)](https://riscv.org/)
[![Architecture](https://img.shields.io/badge/Architecture-Dual--Mode-green)]()

---

## 🎯 项目简介

OCPU是一个面向未来的开源处理器设计，结合了传统OOO乱序执行和现代Agent静态调度两种架构模式，为通用计算和AI加速提供了统一的硬件平台。

### 核心特性

- **🔄 双模架构**: 人类模式（OOO）+ Agent模式（静态调度）
- **⚡ 高性能**: 16发射超标量，256-entry ROB，38个共享执行单元
- **🔧 纯64位**: RV64I/M/F/D/V完整支持，无32位兼容负担
- **📊 向量扩展**: RISC-V Vector v1.0，1024-bit VLEN
- **💾 存储层次**: 256KB L1-I / 64KB L1-D / 4MB L2 (Human) + 512KB SRAM (Agent)
- **🤖 Agent原生**: 支持Agent实时代码生成与执行
- **🎯 共享后端**: 两种模式共用执行单元，节省40%面积

---

## 🏗️ 架构概览

### 共享执行后端 (v4.1)

人类模式和Agent模式**共用物理执行单元**，最大化硬件利用率：

```
                    ┌─────────────────────────────┐
                    │    Execution Unit Pool      │
                    │  10 SX + 6 MX + 6 FPU +     │
                    │  8 VPU + 8 LSU = 38 EU      │
┌──────────────────┐│                             │┌──────────────────┐
│   Human Mode     ││      SHARED BACKEND         ││   Agent Mode     │
│  (OOO Frontend)  │◀┤   ┌─────────────────┐     ├▶│ (Static Front)   │
│                  │ │   │ Request Arbiter │     │ │                  │
│  Dynamic Issue   │ │   │ EU Allocation   │     │ │  Static Issue    │
│  ROB-based       │ │   │ Result Collect  │     │ │  Table-based     │
└──────────────────┘│   └─────────────────┘     │└──────────────────┘
                    └─────────────────────────────┘
```

### 人类模式 (Human Mode)

传统OOO乱序执行架构，优化单线程性能：

```
┌─────────────────────────────────────────────────────────────┐
│  16-wide Fetch  →  Decode  →  Rename  →  Issue  →  Shared   │
│  256KB L1-I        16-wide     512 PREG    OOO      Backend │
│  BTB/GHB/RAS                                              │
└─────────────────────────────────────────────────────────────┘
```

**规格参数**:
- 发射宽度: 16
- ROB深度: 256
- 物理寄存器: 512 (标量) + 256 (向量)
- 执行单元: 10 SX + 6 MX + 6 FPU + 8 VPU + 8 LSU + 4 BR + 2 DIV
- 分支预测: BTB 2048 + GHB 8192 + RAS 32 + TAGE

### Agent模式 (Agent Mode)

静态调度架构，面向AI和确定性计算：

```
┌─────────────────────────────────────────────────────────────┐
│  Task Descriptor → Code Generator → Static Scheduler → Shared│
│  (128-bit)          (Real-time)     (Deterministic)  Backend│
└─────────────────────────────────────────────────────────────┘
│                                                              │
│                    Direct SRAM Access                        │
│                 (512KB, 16 Bank, No Cache)                   │
└─────────────────────────────────────────────────────────────┘
```

**规格参数**:
- 静态发射宽度: 16
- 调度表: 256条目
- SRAM: 512KB (16 Bank × 32KB)
- 延迟: 2周期确定性
- 代码生成: 实时，无软件概念

---

## 📁 项目结构

```
ocpu/
├── rtl/                      # RTL源代码 (433+ SystemVerilog文件)
│   ├── include/              # 全局头文件和参数定义
│   ├── ifetch/               # 取指单元 (40文件)
│   ├── idecode/              # 解码单元 (40文件)
│   ├── rename/               # 重命名单元 (40文件)
│   ├── issue/                # 发射单元 (38文件)
│   ├── execute/              # 执行单元 (54文件)
│   ├── loadstore/            # 加载存储单元 (43文件)
│   ├── commit/               # 提交单元 (41文件)
│   ├── mmu/                  # 内存管理单元 (40文件)
│   ├── level2/               # L2缓存 (41文件)
│   ├── core/                 # 核心控制 (43文件)
│   │   ├── ocpu_core_v4.sv              # v4.1顶层
│   │   ├── ocpu_shared_execute_backend.sv  # 共享执行后端
│   │   ├── ocpu_execution_unit_pool.sv     # 执行单元池
│   │   └── ocpu_human_mode_frontend.sv     # 人类模式前端
│   └── agent_mode/           # Agent模式 (4文件)
├── docs/                     # 文档 (112个)
│   ├── architecture.md                     # 架构概述
│   ├── developer_guide.md                  # 开发者指南
│   ├── user_guide.md                       # 用户指南
│   ├── api_reference.md                    # API参考
│   ├── shared_backend_architecture_v4.1.md # v4.1共享后端
│   ├── MODULE_DOCUMENTATION_SUMMARY.md     # 文档索引
│   ├── modules/              # 模块设计文档
│   └── submodules/           # 子模块文档
├── sim/                      # 仿真环境
│   ├── Makefile
│   └── test_program.hex
├── tb/                       # 测试平台
│   └── tb_ocpu_core.sv
├── fpga/                     # FPGA综合脚本
│   └── Makefile
├── scripts/                  # 实用脚本
│   ├── setup.sh
│   ├── lint_check.sh
│   └── gen_stats.py
├── .github/                  # GitHub配置
│   ├── workflows/            # CI/CD
│   └── ISSUE_TEMPLATE/       # Issue模板
├── OCPU_TRM_3.0.md          # 技术参考手册
├── DUAL_MODE_ARCHITECTURE_v4.0.md  # 双模架构文档
├── DIDT_PLAN_3.0.md         # 验证计划
└── README.md                # 本文件
```

---

## 🚀 快速开始

### 环境要求

- **操作系统**: Linux (推荐 Ubuntu 22.04+)
- **仿真器**: Verilator (推荐), VCS, ModelSim
- **综合工具**: Vivado (Xilinx) 或 Quartus (Intel)
- **Python**: 3.8+ (用于脚本)

### 安装依赖

```bash
# 克隆仓库
git clone https://github.com/openclawdchip/ocpu/ocpu.git
cd ocpu

# 运行安装脚本
./scripts/setup.sh

# 安装Verilator (Ubuntu)
sudo apt-get install verilator
```

### 运行仿真

```bash
cd sim

# 使用Verilator (默认)
make test

# 使用VCS
make test SIM=vcs

# 使用ModelSim
make test SIM=modelsim
```

### FPGA综合

```bash
cd fpga

# Xilinx Vivado
make bitstream VENDOR=xilinx

# Intel Quartus
make bitstream VENDOR=intel
```

---

## 📖 文档

### 架构文档

| 文档 | 描述 | 大小 |
|------|------|------|
| [OCPU_TRM_3.0.md](OCPU_TRM_3.0.md) | 技术参考手册 (完整) | 26KB |
| [DUAL_MODE_ARCHITECTURE_v4.0.md](DUAL_MODE_ARCHITECTURE_v4.0.md) | 双模架构设计 | 19KB |
| [docs/shared_backend_architecture_v4.1.md](docs/shared_backend_architecture_v4.1.md) | 共享后端架构 ★v4.1 | 17KB |
| [DIDT_PLAN_3.0.md](DIDT_PLAN_3.0.md) | 验证测试计划 | 21KB |

### 指南与参考

| 文档 | 描述 | 大小 |
|------|------|------|
| [docs/architecture.md](docs/architecture.md) | 架构概述 | 8KB |
| [docs/developer_guide.md](docs/developer_guide.md) | 开发者指南 | 9KB |
| [docs/user_guide.md](docs/user_guide.md) | 用户指南 ★v4.1 | 9KB |
| [docs/api_reference.md](docs/api_reference.md) | API参考 ★v4.1 | 9KB |
| [docs/MODULE_DOCUMENTATION_SUMMARY.md](docs/MODULE_DOCUMENTATION_SUMMARY.md) | 文档索引 ★v4.1 | 5KB |
| [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) | 项目总结 | 7KB |

---

## 🔬 技术规格

### 处理器核心

| 参数 | 人类模式 | Agent模式 |
|------|----------|-----------|
| 架构 | RV64G + Vector | Agent专用 |
| 发射宽度 | 16 | 16 |
| ROB深度 | 256 | N/A (静态) |
| 物理寄存器 | 512 + 256 | 64专用 |
| 执行单元 | **38 (共享)** | **38 (共享)** |
| 浮点单元 | 6 FPU | 6 FPU (共享) |
| 向量单元 | 8 VPU (1024-bit) | 8 VPU (共享) |

### 存储系统

| 层级 | 大小 | 关联度 | 延迟 |
|------|------|--------|------|
| L1-I | 256KB | 8-way | 2 cycles |
| L1-D | 64KB | 8-way | 3 cycles |
| L2 | 4MB | 16-way | 10 cycles |
| SRAM (Agent) | 512KB | 16 Bank | 2 cycles |

### 接口

| 接口 | 协议 | 位宽 |
|------|------|------|
| 系统总线 | CHI | 512-bit |
| 调试 | JTAG/DMI | - |
| 中断 | PLIC + CLINT | - |

---

## 🎯 共享后端优势 (v4.1)

| 指标 | v4.0 (分离) | v4.1 (共享) | 改善 |
|------|-------------|-------------|------|
| 执行单元面积 | 200% | 100% | **50% ↓** |
| 资源利用率 | 60% | 75% | **25% ↑** |
| 峰值性能 | 100% | 100% | - |
| 模式切换开销 | ~1000 cycles | ~1000 cycles | - |

**核心创新**:
- 🏗️ **三层架构**: Frontend → Arbitration → Execution
- ⚖️ **动态仲裁**: 请求仲裁器为两种模式分配EU
- 📊 **EU分配表**: 跟踪38个执行单元的使用状态
- 🔄 **无缝模式切换**: Drain → Save → Switch → Restore流程

## 🧪 验证状态

### 已完成

- [x] 人类模式RTL完整实现 (420文件)
- [x] Agent模式RTL实现 (4文件)
- [x] **共享执行后端 ★v4.1** (4文件)
- [x] **执行单元池 ★v4.1** (38个共享EU)
- [x] 基础测试平台
- [x] 仿真环境 (Verilator/VCS/ModelSim)
- [x] FPGA综合脚本
- [x] CI/CD工作流

### 进行中

- [ ] UVM验证环境
- [ ] 形式验证
- [ ] FPGA原型验证
- [ ] 性能基准测试

---

## 🤝 贡献

我们欢迎所有形式的贡献！请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 贡献方式

- 🐛 提交Bug报告
- 💡 提出新功能建议
- 🔧 提交代码改进
- 📖 改进文档
- 🧪 添加测试用例

---

## 📜 许可证

本项目采用 [MIT许可证](LICENSE)。

---

## 🙏 致谢

- RISC-V International 定义了优秀的开放指令集架构
- RISC-V社区提供了丰富的工具链和参考实现
- 所有贡献者的付出和支持

---

## 📞 联系方式

- **项目主页**: https://github.com/openclawdchip/ocpu
- **Issue追踪**: https://github.com/openclawdchip/ocpu/issues
- **讨论区**: https://github.com/openclawdchip/ocpu/discussions
- **E-mail**: xiao.lin@ia.ac.cn

---

<p align="center">
  <strong>OCPU - 面向未来的开放处理器</strong><br>
  Human Mode 🤝 Agent Mode
</p>
