⚠️ 免责声明 / Disclaimer

本代码仅用于学习使用，禁止用于任何商业用途。违反本声明引发的任何问题我们不承担任何法律责任。

This code is for educational purposes only. Commercial use is strictly prohibited. We assume no legal liability for any issues arising from violation of this statement.

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
- **⚡ 高性能**: 16发射超标量，256-entry ROB，44个执行单元
- **🔧 纯64位**: RV64I/M/F/D/V完整支持，无32位兼容负担
- **📊 向量扩展**: RISC-V Vector v1.0，1024-bit VLEN
- **💾 存储层次**: 256KB L1-I / 64KB L1-D / 4MB L2
- **🤖 Agent原生**: 支持Agent实时代码生成与执行

---

## 🏗️ 架构概览

### 人类模式 (Human Mode)

传统OOO乱序执行架构，优化单线程性能：

```
┌─────────────────────────────────────────────────────────────┐
│  16-wide Fetch  →  Decode  →  Rename  →  Issue  →  Execute  │
│  256KB L1-I        16-wide     512 PREG    OOO      44 EU    │
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
│  Task Descriptor → Code Generator → Static Scheduler → SRAM │
│  (128-bit)          (Real-time)     (Deterministic)         │
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
├── rtl/                      # RTL源代码 (420+ SystemVerilog文件)
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
│   ├── core/                 # 核心控制 (40文件)
│   └── agent_mode/           # Agent模式 (4文件)
├── docs/                     # 文档
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

| 文档 | 描述 | 大小 |
|------|------|------|
| [OCPU_TRM_3.0.md](OCPU_TRM_3.0.md) | 技术参考手册 (完整) | 26KB |
| [DUAL_MODE_ARCHITECTURE_v4.0.md](DUAL_MODE_ARCHITECTURE_v4.0.md) | 双模架构设计 | 19KB |
| [DIDT_PLAN_3.0.md](DIDT_PLAN_3.0.md) | 验证测试计划 | 21KB |
| [docs/architecture.md](docs/architecture.md) | 架构概述 | - |
| [docs/developer_guide.md](docs/developer_guide.md) | 开发者指南 | - |
| [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) | 项目总结 | - |

---

## 🔬 技术规格

### 处理器核心

| 参数 | 人类模式 | Agent模式 |
|------|----------|-----------|
| 架构 | RV64G + Vector | Agent专用 |
| 发射宽度 | 16 | 16 |
| ROB深度 | 256 | N/A (静态) |
| 物理寄存器 | 512 + 256 | 64专用 |
| 执行单元 | 44 | 16 ALU |
| 浮点单元 | 6 FPU | N/A |
| 向量单元 | 8 VPU (1024-bit) | N/A |

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

## 🧪 验证状态

### 已完成

- [x] 人类模式RTL完整实现 (420文件)
- [x] Agent模式RTL实现 (4文件)
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

---

<p align="center">
  <strong>OCPU - 面向未来的开放处理器</strong><br>
  Human Mode 🤝 Agent Mode
</p>
