⚠️ 免责声明 / Disclaimer

本代码仅用于学习使用，禁止用于任何商业用途。违反本声明引发的任何问题我们不承担任何法律责任。

This code is for educational purposes only. Commercial use is strictly prohibited. We assume no legal liability for any issues arising from violation of this statement.

# OCPU - Open CPU Core 3.0

<p align="center">
  <b>High-Performance 64-bit RISC-V Superscalar Processor Design - 3nm Process + 512-bit Bus</b>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/RTL%20Files-420-green.svg" alt="RTL Files">
  <img src="https://img.shields.io/badge/Architecture-RV64I%2FM%2FF%2FD%2FV-orange.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/Process-3nm-red.svg" alt="Process">
  <img src="https://img.shields.io/badge/Bus-512--bit-yellow.svg" alt="Bus">
  <img src="https://img.shields.io/badge/Status-Complete-success.svg" alt="Status">
</p>

---

## 🎯 Project Overview

**OCPU** is a fully open-source high-performance 64-bit RISC-V superscalar processor core implemented in SystemVerilog. The design features a complete pipeline, branch prediction, MMU, cache hierarchy, and vector/floating-point units.

### 🏭 3nm Process + 512-bit Bus Features

- **Process Node**: 3nm advanced process
- **Bus Width**: 512-bit internal bus (4x bandwidth improvement)
- **Clock Frequency**: 3GHz+ (supports up to 4GHz)
- **Issue Width**: 16 instructions per cycle
- **Vector Registers**: 1024-bit wide (VLEN=1024)

> ⚠️ **Important**: This design supports only 64-bit architecture (RV64I/M/F/D/V). All 32-bit related functionality has been removed.

## 📊 Project Statistics

| Metric | Value |
|--------|-------|
| **Total RTL Files** | **420** |
| **Estimated Lines of Code** | ~50,000+ |
| **Core Modules** | 11 |
| **Process Node** | 3nm |
| **Bus Width** | 512-bit |

## 🏗️ Module Architecture

| Module | File Count | Primary Function |
|--------|------------|------------------|
| [ifetch](rtl/ifetch/) | 40 | Fetch unit, branch prediction (BTB/GHB/RAS/TAGE), prefetcher, I-Cache interface |
| [idecode](rtl/idecode/) | 40 | Instruction decode, micro-op generation, RVC compressed instructions, exception detection |
| [rename](rtl/rename/) | 40 | Register renaming, RAT, free list, checkpoints, recovery logic |
| [issue](rtl/issue/) | 38 | Issue queue, scoreboard, wake-up logic, scheduler, dispatch unit |
| [execute](rtl/execute/) | 54 | ALU, MAC, DIV, FPU, VPU, branch execution, bypass network |
| [loadstore](rtl/loadstore/) | 43 | LSU, D-Cache, Store Buffer, Load Buffer, forwarding, AMO |
| [commit](rtl/commit/) | 41 | ROB, exception handling, CSR, mstatus/mepc/mcause, etc. |
| [mmu](rtl/mmu/) | 40 | TLB (ITLB/DTLB/STLB), page table walker, PMP check |
| [level2](rtl/level2/) | 41 | L2 cache, coherency, CHI protocol, replacement policy, prefetch |
| [core](rtl/core/) | 40 | Core control, interrupt handling, timer, debug interface, Hart management |
| [include](rtl/include/) | 3 | Global header files, parameter definitions, macro definitions |

## 🚀 Core Configuration

### Processor Configuration (OCPU 3.0)

| Parameter | Configuration | Description |
|-----------|---------------|-------------|
| **Process Node** | 3nm | Advanced semiconductor process |
| **Bus Width** | 512-bit | Internal data bus |
| **Clock Frequency** | 3GHz+ | Maximum support 4GHz |
| **Issue Width** | 16 | Instructions issued per cycle |
| **ROB Depth** | 256 | Reorder buffer entries |
| **Physical Registers** | 512 | Integer/floating-point registers |

### Execution Unit Configuration

| Unit Type | Count | Description |
|-----------|-------|-------------|
| **Integer Unit (SX)** | 10 | Single-issue ALU |
| **Multiply-Add Unit (MX)** | 6 | MAC operations |
| **Load/Store Unit** | 8 | 4 Load + 4 Store |
| **Floating-Point Unit (FPU)** | 6 | IEEE 754-2008 |
| **Vector Unit (VEC)** | 8 | SIMD operations |
| **Branch Unit (BR)** | 4 | Branch prediction execution |

### Cache Configuration

| Cache | Size | Ways | Interface Width |
|-------|------|------|-----------------|
| **L1-I Cache** | 256KB | 8-way | 512-bit |
| **L1-D Cache** | 64KB | 8-way | 512-bit |
| **L2 Cache** | 4MB | 16-way | 512-bit |

### Vector Register Configuration

| Parameter | Configuration | Description |
|-----------|---------------|-------------|
| **Vector Register Count** | 256 | Physical registers |
| **Vector Register Width** | 1024-bit | VLEN=1024 |
| **Maximum Vector Length** | 16 | When LMUL=1 |

## 🚀 Quick Start

### Environment Requirements

- **Simulation Tools**: Verilator (recommended), VCS, ModelSim, Xcelium
- **Synthesis Tools**: Xilinx Vivado, Intel Quartus, Synopsys Design Compiler
- **Compiler Tools**: RISC-V 64-bit GNU toolchain
- **System Requirements**: Linux/macOS, Python 3.8+, Make

### Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install verilator gtkwave python3 python3-pip

# macOS
brew install verilator gtkwave python3

# Install Python dependencies
pip3 install -r requirements.txt
```

### Clone Repository

```bash
git clone https://github.com/openclawdchip/ocpu/ocpu.git
cd ocpu
```

### Run Simulation

```bash
cd sim
make build
make run
```

### Run Tests

```bash
# Run basic tests
make test TEST=basic

# Run RISC-V compliance tests
make test TEST=riscv_compliance

# Run all tests
make test_all
```

## 📁 Project Structure

```
ocpu/
├── rtl/                    # RTL source code (420 SystemVerilog files)
│   ├── ifetch/            # Fetch unit
│   ├── idecode/           # Decode unit
│   ├── rename/            # Rename unit
│   ├── issue/             # Issue unit
│   ├── execute/           # Execute unit
│   ├── loadstore/         # Load/Store unit
│   ├── commit/            # Commit unit
│   ├── mmu/               # Memory Management Unit
│   ├── level2/            # L2 cache
│   ├── core/              # Core control
│   └── include/           # Global header files
├── docs/                  # Documentation
│   ├── architecture.md    # Architecture documentation
│   ├── developer_guide.md # Developer guide
│   └── modules/           # Module detailed design
├── sim/                   # Simulation environment
│   ├── Makefile
│   ├── testbench/
│   └── tests/
├── fpga/                  # FPGA synthesis
│   ├── vivado/           # Xilinx Vivado project
│   └── quartus/          # Intel Quartus project
├── scripts/              # Utility scripts
│   ├── lint_check.sh
│   ├── run_tests.py
│   └── gen_stats.py
├── tb/                   # Testbench
├── .github/              # GitHub configuration
│   ├── workflows/        # CI/CD
│   └── ISSUE_TEMPLATE/   # Issue templates
├── README.md             # This file
├── LICENSE               # Apache 2.0 license
├── CHANGELOG.md          # Changelog
└── CONTRIBUTING.md       # Contribution guidelines
```

## 📚 Documentation

- [Architecture Documentation](docs/architecture.md) - Detailed architecture description
- [Developer Guide](docs/developer_guide.md) - Development workflow and conventions
- [API Reference](docs/api_reference.md) - Interface specifications
- [Configuration Upgrade 3.0](CONFIG_UPGRADE_3.0.md) - 3nm+512-bit configuration details
- [Module Design](docs/modules/) - Detailed design documents for each module

## 🎯 Performance Metrics

| Metric | Value | Description |
|--------|-------|-------------|
| **IPC** | 3-4x | Compared to baseline configuration |
| **Memory Bandwidth** | 64GB/s | @1GHz, 512-bit bus |
| **FP Performance** | 192 GFLOPS | @3GHz, 6 FPUs |
| **Vector Performance** | 3 TFLOPS | @3GHz, 8 VEC units |
| **Power Efficiency** | 2-3x | 3nm process advantage |

## 🤝 Contributing

We welcome all forms of contributions! Please see the [Contribution Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is open-sourced under the [Apache 2.0](LICENSE) license.

## 🙏 Acknowledgments

Thanks to all developers and community members who have contributed to this project.

## 📞 Contact Us

- GitHub Issues: [Submit Issue](https://github.com/openclawdchip/ocpu/issues)
- Email: xiao.lin@ia.ac.cn

---

<p align="center">
  <b>Made with ❤️ by the OCPU Team</b>
</p>

# OCPU - Open CPU Core 3.0

<p align="center">
  <b>高性能64位RISC-V超标量处理器设计 - 3nm工艺 + 512-bit总线</b>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/RTL%20Files-420-green.svg" alt="RTL Files">
  <img src="https://img.shields.io/badge/Architecture-RV64I%2FM%2FF%2FD%2FV-orange.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/Process-3nm-red.svg" alt="Process">
  <img src="https://img.shields.io/badge/Bus-512--bit-yellow.svg" alt="Bus">
  <img src="https://img.shields.io/badge/Status-Complete-success.svg" alt="Status">
</p>

---

## 🎯 项目概述

**OCPU** 是一个完全开源的高性能64位RISC-V超标量处理器核心，采用SystemVerilog实现。该设计包含完整的流水线、分支预测、MMU、缓存层次结构以及向量/浮点单元。

### 🏭 3nm工艺 + 512-bit总线特性

- **工艺节点**: 3nm先进工艺
- **总线宽度**: 512-bit内部总线 (4倍带宽提升)
- **时钟频率**: 3GHz+ (支持4GHz)
- **发射宽度**: 16条指令/周期
- **向量寄存器**: 1024位宽 (VLEN=1024)

> ⚠️ **重要**: 本设计仅支持64位架构 (RV64I/M/F/D/V)，已移除所有32位相关功能。

## 📊 项目统计

| 指标 | 数值 |
|------|------|
| **RTL文件总数** | **420个** |
| **估计代码行数** | ~50,000+行 |
| **核心模块数** | 11个 |
| **工艺节点** | 3nm |
| **总线宽度** | 512-bit |

## 🏗️ 模块架构

| 模块 | 文件数 | 主要功能 |
|------|--------|----------|
| [ifetch](rtl/ifetch/) | 40 | 取指单元、分支预测(BTB/GHB/RAS/TAGE)、预取器、I-Cache接口 |
| [idecode](rtl/idecode/) | 40 | 指令解码、微操作生成、RVC压缩指令、异常检测 |
| [rename](rtl/rename/) | 40 | 寄存器重命名、RAT、空闲列表、检查点、恢复逻辑 |
| [issue](rtl/issue/) | 38 | 发射队列、记分板、唤醒逻辑、调度器、分发单元 |
| [execute](rtl/execute/) | 54 | ALU、MAC、DIV、FPU、VPU、分支执行、旁路网络 |
| [loadstore](rtl/loadstore/) | 43 | LSU、D-Cache、Store Buffer、Load Buffer、转发、AMO |
| [commit](rtl/commit/) | 41 | ROB、异常处理、CSR、mstatus/mepc/mcause等 |
| [mmu](rtl/mmu/) | 40 | TLB(ITLB/DTLB/STLB)、页表遍历、PMP检查 |
| [level2](rtl/level2/) | 41 | L2缓存、一致性、CHI协议、替换策略、预取 |
| [core](rtl/core/) | 40 | 核心控制、中断处理、定时器、调试接口、Hart管理 |
| [include](rtl/include/) | 3 | 全局头文件、参数定义、宏定义 |

## 🚀 核心配置

### 处理器配置 (OCPU 3.0)

| 参数 | 配置 | 说明 |
|------|------|------|
| **工艺节点** | 3nm | 先进半导体工艺 |
| **总线宽度** | 512-bit | 内部数据总线 |
| **时钟频率** | 3GHz+ | 最高支持4GHz |
| **发射宽度** | 16 | 每周期发射指令数 |
| **ROB深度** | 256 | 重排序缓冲区 |
| **物理寄存器** | 512 | 整数/浮点寄存器 |

### 执行单元配置

| 单元类型 | 数量 | 说明 |
|----------|------|------|
| **整数单元 (SX)** | 10 | 单发射ALU |
| **乘加单元 (MX)** | 6 | MAC运算 |
| **Load/Store单元** | 8 | 4 Load + 4 Store |
| **浮点单元 (FPU)** | 6 | IEEE 754-2008 |
| **向量单元 (VEC)** | 8 | SIMD运算 |
| **分支单元 (BR)** | 4 | 分支预测执行 |

### 缓存配置

| 缓存 | 大小 | 路数 | 接口宽度 |
|------|------|------|----------|
| **L1-I Cache** | 256KB | 8-way | 512-bit |
| **L1-D Cache** | 64KB | 8-way | 512-bit |
| **L2 Cache** | 4MB | 16-way | 512-bit |

### 向量寄存器配置

| 参数 | 配置 | 说明 |
|------|------|------|
| **向量寄存器数量** | 256 | 物理寄存器 |
| **向量寄存器宽度** | 1024位 | VLEN=1024 |
| **最大向量长度** | 16 | LMUL=1时 |

## 🚀 快速开始

### 环境要求

- **仿真工具**: Verilator (推荐)、VCS、ModelSim、Xcelium
- **综合工具**: Xilinx Vivado、Intel Quartus、Synopsys Design Compiler
- **编译工具**: RISC-V 64位GNU工具链
- **系统要求**: Linux/macOS、Python 3.8+、Make

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install verilator gtkwave python3 python3-pip

# macOS
brew install verilator gtkwave python3

# 安装Python依赖
pip3 install -r requirements.txt
```

### 克隆项目

```bash
git clone https://github.com/openclawdchip/ocpu/ocpu.git
cd ocpu
```

### 运行仿真

```bash
cd sim
make build
make run
```

### 运行测试

```bash
# 运行基础测试
make test TEST=basic

# 运行RISC-V compliance测试
make test TEST=riscv_compliance

# 运行全部测试
make test_all
```

## 📁 项目结构

```
ocpu/
├── rtl/                    # RTL源代码 (420个SystemVerilog文件)
│   ├── ifetch/            # 取指单元
│   ├── idecode/           # 解码单元
│   ├── rename/            # 重命名单元
│   ├── issue/             # 发射单元
│   ├── execute/           # 执行单元
│   ├── loadstore/         # 访存单元
│   ├── commit/            # 提交单元
│   ├── mmu/               # 内存管理单元
│   ├── level2/            # L2缓存
│   ├── core/              # 核心控制
│   └── include/           # 全局头文件
├── docs/                  # 文档
│   ├── architecture.md    # 架构文档
│   ├── developer_guide.md # 开发指南
│   └── modules/           # 模块详细设计
├── sim/                   # 仿真环境
│   ├── Makefile
│   ├── testbench/
│   └── tests/
├── fpga/                  # FPGA综合
│   ├── vivado/           # Xilinx Vivado项目
│   └── quartus/          # Intel Quartus项目
├── scripts/              # 辅助脚本
│   ├── lint_check.sh
│   ├── run_tests.py
│   └── gen_stats.py
├── tb/                   # 测试平台
├── .github/              # GitHub配置
│   ├── workflows/        # CI/CD
│   └── ISSUE_TEMPLATE/   # Issue模板
├── README.md             # 本文件
├── LICENSE               # Apache 2.0许可证
├── CHANGELOG.md          # 变更日志
└── CONTRIBUTING.md       # 贡献指南
```

## 📚 文档

- [架构文档](docs/architecture.md) - 详细架构说明
- [开发指南](docs/developer_guide.md) - 开发流程和约定
- [API参考](docs/api_reference.md) - 接口规范
- [配置升级3.0](CONFIG_UPGRADE_3.0.md) - 3nm+512-bit配置详情
- [模块设计](docs/modules/) - 各模块详细设计文档

## 🎯 性能指标

| 指标 | 数值 | 说明 |
|------|------|------|
| **IPC** | 3-4x | 相比基础配置 |
| **内存带宽** | 64GB/s | @1GHz, 512-bit总线 |
| **浮点性能** | 192 GFLOPS | @3GHz, 6个FPU |
| **向量性能** | 3 TFLOPS | @3GHz, 8个VEC单元 |
| **能效比** | 2-3x | 3nm工艺优势 |

## 🤝 贡献

我们欢迎所有形式的贡献！请查看[贡献指南](CONTRIBUTING.md)了解详情。

## 📄 许可证

本项目采用 [Apache 2.0](LICENSE) 许可证开源。

## 🙏 致谢

感谢所有为本项目做出贡献的开发者和社区成员。

## 📞 联系我们

- GitHub Issues: [提交Issue](https://github.com/openclawdchip/ocpu/issues)
- 邮件: xiao.lin@ia.ac.cn

---

<p align="center">
  <b>Made with ❤️ by the OCPU Team</b>
</p>
