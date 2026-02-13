# OCPU 处理器顶层模块设计文档

---

## 目录

1. [概述](#1-概述)
2. [文件列表](#2-文件列表)
3. [核心顶层模块分析](#3-核心顶层模块分析)
   - 3.1 [ocpu_core.sv](#31-ocpu_coresv)
   - 3.2 [ocpu_cpu.sv](#32-ocpu_cpusv)
   - 3.3 [ocpu_clk_rst.sv](#33-ocpu_clk_rsts)
4. [虚拟CPU包装器](#4-虚拟cpu包装器)
5. [辅助模块分析](#5-辅助模块分析)
6. [时钟域划分](#6-时钟域划分)
7. [复位策略](#7-复位策略)
8. [子系统连接关系](#8-子系统连接关系)
9. [顶层接口定义](#9-顶层接口定义)
10. [总结](#10-总结)

---

## 1. 概述

OCPU 是 基于RISC-V 设计的单核/多核处理器 IP，属于 RV64I 架构的 CPU 核心。本分析涵盖其顶层 SystemVerilog 模块，包括核心顶层、CPU 顶层、时钟复位控制以及相关的辅助模块。

**关键特性**:
- 支持 RISC-V RV64I 架构 (64位基础整数指令集)
- 支持大端/小端模式 (CFGEND)
- CHI (Coherent Hub Interface) 总线接口
- 支持多种电源管理状态
- 集成调试和追踪功能

---

## 2. 文件列表


| 序号 | 文件名 | 类型 | 描述 |
|------|--------|------|------|
| 1 | `ocpu_core.sv` | 顶层 | 核心顶层模块 - 系统集成接口 |
| 2 | `ocpu_cpu.sv` | 核心 | CPU 顶层模块 - 处理器核心逻辑 |
| 3 | `ocpu_clk_rst.sv` | 辅助 | 时钟复位生成模块 |
| 4 | `ocpu_vcpu.sv` | 包装器 | 虚拟 CPU 包装器 - 跨时钟域处理 |
| 5 | `ocpu_reg_rep.sv` | 辅助 | 寄存器复制/重定时模块 |
| 6 | `ocpu_atb_sync_bridge.sv` | 辅助 | ATB (AMBA Trace Bus) 同步桥 |
| 7 | `ocpu_tac_capture.sv` | 仿真 | Tac 追踪捕获模块 |
| 8 | `instruction_decoder.sv` | 仿真 | 指令解码器 (用于仿真) |
| 9 | `instruction_tracer.sv` | 仿真 | 指令追踪器 |
| 10 | `instruction_tracer_defines.sv` | 头文件 | 指令追踪器定义 |
| 11 | `instruction_tracer_include.sv` | 头文件 | 指令追踪器包含文件 |
| 12 | `instruction_tracer_spr.sv` | 仿真 | SPR 追踪器 |
| 13 | `instruction_tracer_top.sv` | 仿真 | 指令追踪器顶层 |

---

## 3. 核心顶层模块

### 3.1 ocpu_core.sv

**模块功能**:  
`ocpu_core` 是整个 OCPU CPU 的顶层集成模块，负责将 CPU 核心与系统级接口连接。它是芯片集成时的主要接口点。

**关键参数**:
```systemverilog
parameter CRYPTO                    = 1;        // 启用加密扩展
parameter CORE_CACHE_PROTECTION     = 1;        // 核心缓存保护
parameter L2_CACHE_SIZE             = 8'b00011111;  // L2缓存大小
parameter L2_TQ_SIZE                = 48;       // L2事务队列大小
parameter CORE_DATA_WIDTH           = 256;      // 核心数据总线宽度
parameter PA_W                      = 40;       // 物理地址宽度
parameter ASYNC_BRIDGE              = 1;        // 异步桥接使能
parameter CPU_SYNC_LEVELS           = 2;        // CPU同步级数
parameter SYS_SYNC_LEVELS           = 2;        // 系统同步级数
```

**时钟接口**:
| 信号名 | 方向 | 描述 |
|--------|------|------|
| `coreclk` | Input | 核心时钟 |
| `sclk` | Input | 系统时钟 |
| `pclk` | Input | APB/调试时钟 |
| `atclk` | Input | ATB追踪时钟 |
| `gicclk` | Input | GIC中断控制器时钟 |
| `periphclk` | Input | 外设时钟 |

**复位接口**:
| 信号名 | 方向 | 描述 |
|--------|------|------|
| `ncpuporeset` | Input | CPU Power-On Reset (低有效) |
| `ncorereset` | Input | 核心复位 (低有效) |
| `nsreset` | Input | 系统复位 (低有效) |
| `npreset` | Input | APB复位 (低有效) |
| `natreset` | Input | ATB复位 (低有效) |
| `ngicreset` | Input | GIC复位 (低有效) |

**CHI总线接口**:  
模块实现了完整的 CHI (Coherent Hub Interface) 协议接口，包括：

1. **TX Request Channel** (`cb_txreq*`)
2. **TX Response Channel** (`cb_txrsp*`)
3. **TX Data Channel** (`cb_txdat*`)
4. **RX Snoop Channel** (`sys_rxsnp*`)
5. **RX Response Channel** (`sys_rxrsp*`)
6. **RX Data Channel** (`sys_rxdat*`)

**电源管理接口**:
| 信号名 | 方向 | 描述 |
|--------|------|------|
| `sys_corepreq_i` | Input | 核心电源状态请求 |
| `sys_corepstate_i[5:0]` | Input | 核心电源状态 |
| `cb_corepaccept_o` | Output | 核心电源状态接受 |
| `cb_corepdeny_o` | Output | 核心电源状态拒绝 |
| `cb_corepactive_o[17:0]` | Output | 核心电源活动指示 |

**中断接口**:
| 信号名 | 方向 | 描述 |
|--------|------|------|
| `sys_nfiq_i` | Input | 快速中断请求 (低有效) |
| `sys_nirq_i` | Input | 中断请求 (低有效) |
| `sys_nvfiq_i` | Input | 虚拟快速中断请求 (低有效) |
| `sys_nvirq_i` | Input | 虚拟中断请求 (低有效) |

**调试接口**:
| 信号名 | 方向 | 描述 |
|--------|------|------|
| `sys_dbgen_i` | Input | 调试使能 |
| `sys_niden_i` | Input | 非侵入式调试使能 |
| `sys_dbgconnected_i` | Input | 调试器连接状态 |
| `cb_nfaultirq_o` | Output | 故障中断 |
| `cb_nerrirq_o` | Output | 错误中断 |

**子模块实例化**:  
核心实例化了 `ocpu_vcpu` 模块作为虚拟 CPU 包装器，负责处理跨时钟域信号同步。

---

### 3.2 ocpu_cpu.sv

**模块功能**:  
`ocpu_cpu` 是实际的 CPU 核心逻辑模块，包含取指、解码、重命名、执行、提交等完整的处理器流水线。

**关键参数**:
```systemverilog
parameter L1_ICACHE_SIZE    = 8'b00000011;  // L1指令缓存大小 (16KB)
parameter L1_DCACHE_SIZE    = 8'b00000011;  // L1数据缓存大小 (16KB)
parameter L2_CACHE_SIZE     = 8'b00011111;  // L2缓存大小
parameter L2_TQ_SIZE        = 48;           // L2事务队列大小
parameter SCU               = 1;            // Snoop Control Unit
parameter CORE_DATA_WIDTH   = 256;          // 核心数据宽度
parameter DOUBLE_PUMPED     = 0;            // 双倍泵浦模式
parameter ELA               = 0;            // 嵌入式逻辑分析仪
```

**架构特性**:
- **4发射超标量**: 支持每个周期发射最多4条微操作 (M0-M3通道)
- **乱序执行**: 支持乱序执行和按序提交
- **重命名寄存器**: 物理寄存器堆支持寄存器重命名
- **多执行单元**: 包括整数单元(SX0/SX1)、向量单元(VX0/VX1)、内存单元(MX/LS)

**主要内部信号** (从代码分析):

1. **控制信号**:
   - `ct_flush`: 流水线冲刷
   - `ct_commit_v`: 提交有效
   - `ct_sample_pstate`: 采样处理器状态

2. **分支预测**:
   - `bx_brn_taken_e2`: 分支 taken
   - `bx_ct_resolve_mispred`: 分支预测错误
   - `bx_ct_resolve_uid`: 分支 UID

3. **异常处理**:
   - `ct_mx_excptn_tgt`: 异常目标
   - `ct_excptn_rtn`: 异常返回
   - `ct_vec_restart`: 向量重启

4. **电源管理**:
   - `cpu_wfireq`: Wait-For-Interrupt 请求
   - `cpu_wfereq`: Wait-For-Event 请求
   - `cpu_intfidle`: 接口空闲
   - `cpu_dbgidle`: 调试空闲

**实例化模块**:  
根据代码分析，`ocpu_cpu` 内部包含以下主要单元：

| 单元 | 描述 |
|------|------|
| `ocpu_reg_rep` | 寄存器复制/重定时 |
| 取指单元 (IF) | 指令获取和解码 |
| 重命名单元 (RN) | 寄存器重命名 |
| 发射单元 (IS) | 指令发射控制 |
| 整数执行单元 (SX0/SX1) | 整数运算 |
| 向量执行单元 (VX0/VX1) | SIMD/浮点运算 |
| 内存执行单元 (LS/MX) | 加载/存储操作 |
| 提交单元 (CT) | 指令提交和异常处理 |

---

### 3.3 ocpu_clk_rst.sv

**模块功能**:  
简单的时钟复位生成模块，负责将低有效复位信号转换为内部高有效复位信号。

**接口定义**:
```systemverilog
input  wire    nwreset,    // 热复位 (低有效)
input  wire    ndbgreset,     // 调试复位 (低有效)  
input  wire    npubreset,     // 发布复位 (低有效)
output wire    reset,         // 内部复位 (高有效)
output wire    poreset,       // Power-On复位 (高有效)
output wire    pubreset       // 发布复位 (高有效)
```

**实现逻辑**:
```systemverilog
assign reset    = ~nwreset;   // 取反生成高有效复位
assign poreset  = ~ndbgreset;
assign pubreset = ~npubreset;
```

**复位策略角色**:  
该模块是复位层次结构的一部分，确保各种复位源正确传递到 CPU 内部。

---

## 4. 虚拟CPU包装器

### ocpu_vcpu.sv

**模块功能**:  
`ocpu_vcpu` 是虚拟 CPU 包装器，位于 `ocpu_core` 和 `ocpu_cpu` 之间。主要功能是处理跨时钟域信号同步，支持异步桥接模式。

**关键参数**:
```systemverilog
parameter NUM_THREADS       = 1;        // 单线程配置
parameter ASYNC_BRIDGE      = 1;        // 异步桥接使能
parameter TXREQ_FIFO_DEPTH  = 6;        // 发送请求FIFO深度
parameter RXSNP_FIFO_DEPTH  = 6;        // 接收Snoop FIFO深度
```

**FIFO接口**:  
模块实现了多组异步 FIFO 用于跨时钟域数据传输：

1. **CHI TX Request FIFO** (`cpu_sys_chi_txreq_*`)
2. **CHI TX Response FIFO** (`cpu_sys_chi_txrsp_*`)
3. **CHI TX Data FIFO** (`cpu_sys_chi_txdat_*`)
4. **CHI RX Snoop FIFO** (`sys_cpu_chi_rxsnp_*`)
5. **CHI RX Response FIFO** (`sys_cpu_chi_rxrsp_*`)
6. **CHI RX Data FIFO** (`sys_cpu_chi_rxdat_*`)
7. **GIC ICC FIFO** (`cpu_sys_gic_icc_*`)
8. **GIC IRI FIFO** (`sys_cpu_gic_iri_*`)
9. **P-Channel TX/RX FIFO** (`cpu_sys_pub_*`, `sys_cpu_pub_*`)
10. **ATB FIFO** (`cpu_sys_atb_*`)

**电源管理桥接**:  
处理 CPU 时钟域和系统时钟域之间的电源管理信号同步：
- Q-Channel 接口用于时钟门控控制
- P-Channel 接口用于电源状态控制

**调试桥接**:  
- 调试请求/响应的跨时钟域同步
- CTI (Cross Trigger Interface) 信号同步

---

## 5. 辅助模块分析

### 5.1 ocpu_reg_rep.sv

**模块功能**:  
寄存器复制/重定时模块，用于跨时钟域信号的稳定采样和流水线化。

**主要功能**:
1. **调试接口重定时**: 对调试相关信号进行两级寄存
2. **APB接口重定时**: 对 APB 总线信号进行流水线处理
3. **PMU事件收集**: 收集性能监控单元 (PMU) 的 75 个事件
4. **时钟门控优化**: 支持条件时钟使能，降低功耗

**PMU事件输出**:
```systemverilog
output reg [74:0]    l2_pmu_events,   // 75个性能监控事件
```

事件包括：
- L1/L2/L3 缓存访问计数
- 总线访问计数
- 预取命中/未命中
- TLB 未命中
- 分支预测统计

### 5.2 ocpu_atb_sync_bridge.sv

**模块功能**:  
ATB (AMBA Trace Bus) 同步桥，用于跨时钟域传输追踪数据。

**主要特性**:
- 2 入口 FIFO 用于数据缓冲
- 支持 ATB 协议 (ATVALID/ATREADY 握手机制)
- 支持同步请求 (SyncReq) 功能
- 支持 Flush 操作

**状态机**:  
模块包含一个 4 状态的状态机处理 Flush 操作：
- `2'b00`: 空闲状态
- `2'b01`: Flush 请求状态
- `2'b10`: Flush 数据传输状态
- `2'b11`: Flush 完成状态

### 5.3 指令追踪模块组

这些模块主要用于仿真和调试：

1. **instruction_tracer_top.sv**: 指令追踪器顶层，连接 CPU 内部信号
2. **instruction_tracer.sv**: 实际追踪逻辑
3. **instruction_tracer_spr.sv**: 特殊寄存器追踪
4. **instruction_decoder.sv**: 指令解码辅助
5. **ocpu_tac_capture.sv**: Tac 格式追踪数据捕获

---

## 6. 时钟域划分

OCPU 设计采用多时钟域架构，以支持灵活的电源管理和性能优化。

### 6.1 时钟域列表

| 时钟域 | 时钟名 | 典型频率 | 用途 |
|--------|--------|----------|------|
| 核心时钟域 | `coreclk` | 1-3 GHz | CPU核心逻辑 |
| 系统时钟域 | `sclk` | 核心时钟或分频 | CHI总线接口 |
| APB时钟域 | `pclk` | 通常较慢 | 调试和配置接口 |
| ATB时钟域 | `atclk` | 可变 | 追踪数据输出 |
| GIC时钟域 | `gicclk` | 独立 | 中断控制器 |
| 外设时钟域 | `periphclk` | 独立 | 外设接口 |

### 6.2 跨时钟域处理

**异步桥接** (`ASYNC_BRIDGE = 1`):
- 使用双端口 FIFO 进行数据传输
- 使用握手机制进行控制信号同步
- 支持指针同步和格雷码编码

**同步级数**:
```systemverilog
parameter CPU_SYNC_LEVELS = 2;  // CPU侧同步级数
parameter SYS_SYNC_LEVELS = 2;  // 系统侧同步级数
```

**Q-Channel接口** (时钟门控控制):
每个时钟域都有独立的 Q-Channel 接口用于动态时钟门控：
- `sys_*clkqreqn_i`: 时钟请求 (低有效)
- `cb_*clkqacceptn_o`: 时钟接受 (低有效)
- `cb_*clkqdeny_o`: 时钟拒绝
- `cb_*clkqactive_o`: 时钟活动指示

---

## 7. 复位策略

### 7.1 复位层次结构

OCPU 采用分层复位策略，确保系统可靠初始化：

```
Power-On Reset (POR)
    ├── ncpuporeset     → 整个CPU复位
    ├── ndbgreset       → 调试逻辑复位  
    ├── ncorereset      → 核心逻辑复位
    ├── npubreset       → 发布逻辑复位
    ├── nsreset         → 系统接口复位
    ├── npreset         → APB接口复位
    ├── natreset        → ATB接口复位
    └── ngicreset       → GIC接口复位
```

### 7.2 复位信号描述

| 复位信号 | 类型 | 覆盖范围 | 使用场景 |
|----------|------|----------|----------|
| `ncpuporeset` | POR | 整个CPU | 上电初始化 |
| `ncorereset` | W | 核心逻辑 | 热复位/软复位 |
| `ndbgreset` | Debug | 调试逻辑 | 调试控制器复位 |
| `npubreset` | Pub | 发布逻辑 | 发布状态复位 |

### 7.3 复位同步

每个时钟域都有独立的复位同步器：
- 异步断言，同步释放
- 多级同步器防止亚稳态
- 支持复位域跨越 (Reset Domain Crossing, RDC)

### 7.4 复位时序要求

- **POR 保持时间**: 至少 16 个时钟周期
- **W Reset 保持时间**: 至少 8 个时钟周期
- **复位释放**: 必须同步到对应时钟域

---

## 8. 子系统连接关系

### 8.1 顶层架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        ocpu_core (SoC Interface)                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   CHI Bus   │    │   GIC IF    │    │   Debug/Trace IF    │  │
│  │  (sclk域)   │    │  (gicclk)   │    │     (pclk/atclk)    │  │
│  └──────┬──────┘    └──────┬──────┘    └──────────┬──────────┘  │
│         │                  │                       │             │
│  ┌──────▼──────────────────▼───────────────────────▼──────────┐ │
│  │                    ocpu_vcpu (Clock Bridge)                 │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │                  Async FIFO Arrays                    │  │ │
│  │  │  [CHI TX/RX] [GIC ICC/IRI] [ATB] [P-Channel]          │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └──────┬──────────────────────────────────────────────────────┘ │
│         │ (coreclk域)                                            │
│  ┌──────▼──────────────────────────────────────────────────────┐ │
│  │                      ocpu_cpu (Core Logic)                   │ │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │ │
│  │  │  IFU   │ │  IDU   │ │   RN   │ │   IS   │ │  EXUs  │     │ │
│  │  │(取指)  │ │(解码)  │ │(重命名)│ │(发射)  │ │(执行)  │     │ │
│  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘     │ │
│  │  ┌────────┐ ┌────────┐ ┌────────┐                           │ │
│  │  │   CT   │ │   LS   │ │  MMU   │                           │ │
│  │  │(提交)  │ │(加载存)│ │(内存管)│                           │ │
│  │  └────────┘ └────────┘ └────────┘                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 内部连接详情

**1. ocpu_core → ocpu_vcpu**:
- 所有系统接口信号连接到 vCPU
- 时钟域交叉在此层处理

**2. ocpu_vcpu → ocpu_cpu**:
- 同步后的信号传递到 CPU 核心
- 所有信号在 `coreclk` 域

**3. ocpu_cpu 内部连接**:
- 流水线各级通过握手信号连接
- 旁路网络 (bypass) 连接执行单元到发射单元
- 提交单元通过广播信号控制冲刷和异常

### 8.3 关键内部总线

**CHI CPU侧接口**:
```systemverilog
// TX Request (CPU → System)
cpu_txreqflit[81:0]     // 请求消息
// TX Response (CPU → System)  
cpu_txrspflit[17:0]     // 响应消息
// TX Data (CPU → System)
cpu_txdatflit[293:0]    // 数据消息 (256-bit数据 + 控制)
// RX Snoop (System → CPU)
cb_rxsnpflit[63:0]      // Snoop请求
// RX Response (System → CPU)
cb_rxrspflit[28:0]      // 响应消息
// RX Data (System → CPU)
cb_rxdatflit[293:0]     // 数据消息
```

---

## 9. 顶层接口定义

### 9.1 物理地址接口

| 信号 | 宽度 | 描述 |
|------|------|------|
| `sys_rvbaraddr_i` | PA_W-1:2 | 复位向量基地址 |
| `sys_clusteridaff2_i` | 7:0 | Cluster ID Affinity 2 |
| `sys_clusteridaff3_i` | 7:0 | Cluster ID Affinity 3 |
| `sys_coreid_i` | 3:0 | 核心ID |

### 9.2 配置接口

| 信号 | 描述 |
|------|------|
| `sys_cfgend_i` | 大端模式配置 |
| `sys_vinithi_i` | 高向量初始化 |
| `sys_cfgte_i` | Thumb异常配置 |
| `sys_aa64naa32_i` | AArch64/AArch32 模式选择 |
| `sys_cryptodisable_i` | 加密扩展禁用 |

### 9.3 电源管理接口

**P-Channel (电源通道)**:
```systemverilog
// 核心电源控制
input  wire        sys_corepreq_i;      // 电源状态请求
input  wire [5:0]  sys_corepstate_i;    // 目标电源状态
output wire        cb_corepaccept_o;    // 电源状态接受
output wire        cb_corepdeny_o;      // 电源状态拒绝
output wire [17:0] cb_corepactive_o;    // 电源活动位图
```

**Q-Channel (时钟通道)**:  
为每个时钟域提供独立的 Q-Channel 接口。

### 9.4 调试和追踪接口

**CoreSight 调试接口**:
```systemverilog
// APB调试接口
input  wire        sys_pseldc_i;        // 外设选择
input  wire [16:2] sys_paddrdc_i;       // 地址
input  wire        sys_penabledc_i;     // 使能
input  wire        sys_pwritedc_i;      // 读写方向
input  wire [31:0] sys_pwdatadc_i;      // 写数据
output wire [31:0] cb_prdatadc_o;       // 读数据
output wire        cb_preadydc_o;       // 传输完成
output wire        cb_pslverrdc_o;      // 从机错误
```

**ATB 追踪接口**:
```systemverilog
output wire [31:0] cb_atdata_o;         // 追踪数据
output wire        cb_atvalid_o;        // 数据有效
output wire [6:0]  cb_atid_o;           // 追踪ID
output wire [1:0]  cb_atbytes_o;        // 字节有效
```

### 9.5 性能监控接口

```systemverilog
// PMU 中断输出
output wire [0:0]  cb_npmuirq_o;        // PMU溢出中断
input  wire        sys_pmusnapshotreq_i; // PMU快照请求
output wire        cb_pmusnapshotack_o;  // PMU快照确认
```

---

## 10. 总结

### 10.1 设计特点

1. **模块化设计**: 清晰的层次结构，从 SoC 接口到核心逻辑逐层封装
2. **多时钟域支持**: 支持异步桥接，便于系统集成和电源管理
3. **完整调试支持**: 集成 CoreSight 调试和追踪功能
4. **灵活配置**: 通过参数支持多种配置选项
5. **电源管理**: 完整的 P/Q-Channel 支持，支持多种低功耗模式

### 10.2 集成建议

1. **时钟**: 确保各时钟域正确连接，注意时钟频率限制
2. **复位**: 按层次提供复位信号，确保正确的复位时序
3. **CHI接口**: 正确配置节点ID和系统拓扑参数
4. **调试**: 根据需求选择调试功能，注意额外的面积开销
5. **电源**: 正确连接电源管理控制器，验证状态转换

### 10.3 注意事项

1. 该设计包含 RISC-V 专有 IP，使用需遵守相关许可协议
2. 某些参数组合可能不被支持，需参考官方文档
3. 仿真模型和实际实现可能有差异，以综合后网表为准

---

**文档结束**

*Generated by OpenClaw Agent - 2026-02-12*
