# OCPU IFetch 模块详细设计文档 - 版本3.0

**架构**: RISC-V RV64I  
**工艺**: 3nm  
**总线宽度**: 512-bit  
**更新日期**: 2026-02-13  

---

## 目录

1. [概述](#概述)
2. [版本3.0更新](#版本30更新)
3. [目录结构](#目录结构)
4. [模块清单和依赖关系](#模块清单和依赖关系)
5. [系统整体架构](#系统整体架构)
6. [核心模块详细分析](#核心模块详细分析)
7. [关键设计决策](#关键设计决策)
8. [附录](#附录)

---

## 概述

`ocpu_ifetch` 是 RISC-V OCPU 处理器的指令获取子系统，负责从指令缓存或内存中获取指令，进行预解码，并支持分支预测机制。该模块实现了完整的取指流水线，支持 RISC-V RV64I 架构。

### OCPU 3.0 主要特性

- **工艺节点**: 3nm先进工艺
- **总线宽度**: 512-bit内部总线
- **取指宽度**: 64字节/周期 (支持16条32位指令)
- **时钟频率**: 3GHz+
- **RISC-V支持**: 支持 RV64I 基础指令集，可扩展支持乘法和浮点
- **分支预测**: 集成 BTB(2048项)、GHB(8192项)、RAS(32项)、TAGE预测器
- **缓存接口**: 256KB L1-I Cache，512-bit数据接口
- **异常处理**: 完整的异常和错误处理流程
- **性能优化**: 流水线化设计，支持推测执行
- **调试支持**: 集成 ELA (Embedded Logic Analyzer) 和调试接口
- **固定指令长度**: 所有指令32位固定长度，简化取指逻辑

### 架构规格

| 特性 | OCPU 3.0 配置 |
|------|---------------|
| 指令集 | RISC-V RV64I/M/F/D/V |
| 指令长度 | 固定32位 (RVC压缩16位扩展) |
| 地址宽度 | 64位 |
| 取指宽度 | 64字节/周期 (16条指令) |
| 总线宽度 | 512-bit |
| 分支预测 | BTB+GHB+RAS+TAGE |
| L1-I缓存 | 256KB, 8-way, 512-bit接口 |
| 压缩指令 | RVC支持 |

---

## 版本3.0更新

### 3.0版本升级内容

| 参数 | 2.0版本 | 3.0版本 | 说明 |
|------|---------|---------|------|
| **工艺节点** | 5nm | **3nm** | 先进工艺 |
| **总线宽度** | 128-bit | **512-bit** | 4倍带宽 |
| **取指宽度** | 16字节 | **64字节** | 16条指令/周期 |
| **L1-I缓存** | 32KB | **256KB** | 8倍容量 |
| **BTB条目** | 512 | **2048** | 4倍容量 |
| **GHB条目** | 4096 | **8192** | 2倍容量 |
| **RAS深度** | 16 | **32** | 2倍深度 |
| **时钟频率** | 2GHz | **3GHz+** | 更高频率 |

### 512-bit总线优势

- **带宽提升**: 4倍于128-bit总线
- **指令获取**: 每周期可获取16条32位指令
- **缓存效率**: 单次访问可获取8条缓存行指令
- **预取优化**: 更大带宽支持更激进预取

---

## 目录结构

```
ocpu_ifetch/
├── rtl/
│   ├── ocpu_ifetch.sv              # 顶层模块
│   ├── ocpu_if_params.sv           # 参数定义 (512-bit总线配置)
│   ├── ocpu_if_defines.sv          # 宏定义
│   ├── ocpu_if_pp_defines.sv       # PP 模块宏定义
│   ├── ocpu_if_bx_defines.sv       # BX 模块宏定义
│   │
│   ├── 取指流水线 (FP)
│   │   ├── ocpu_if_fp.sv           # Fetch Pipeline 主模块
│   │   ├── ocpu_if_fq.sv           # Fetch Queue (扩展深度)
│   │   ├── ocpu_if_cfc.sv          # Cache Fill Control
│   │   └── ocpu_if_dq_ctl.sv       # Decode Queue Control
│   │
│   ├── 预解码 (PD)
│   │   ├── ocpu_if_pd.sv           # Pre-decode 主模块
│   │   ├── ocpu_if_pd_rv64_dec.sv  # RV64I 指令解码
│   │   ├── ocpu_if_pd_rvc_dec.sv   # RVC 压缩指令解码
│   │   └── ocpu_if_pd_repair.sv    # Pre-decode Repair
│   │
│   ├── 分支预测 (PP)
│   │   ├── ocpu_if_pp.sv           # Preprocess 主模块
│   │   ├── ocpu_if_pp_ctl.sv       # PP 控制
│   │   ├── ocpu_if_btb_ctl.sv      # BTB 控制 (2048项)
│   │   ├── ocpu_if_btb_arr.sv      # BTB 阵列
│   │   ├── ocpu_if_btb_ent.sv      # BTB 条目
│   │   ├── ocpu_if_ghb.sv          # GHB 主模块 (8192项)
│   │   ├── ocpu_if_ghb_arr.sv      # GHB 阵列
│   │   ├── ocpu_if_ghb_ctl.sv      # GHB 控制
│   │   ├── ocpu_if_ghb_upd.sv      # GHB 更新
│   │   ├── ocpu_if_ras.sv          # Return Address Stack (32项)
│   │   └── ocpu_if_tage.sv         # TAGE预测器
│   │
│   ├── 指令缓存接口 (ICache)
│   │   ├── ocpu_if_icache.sv       # I-Cache接口 (512-bit)
│   │   ├── ocpu_if_icache_req.sv   # I-Cache请求
│   │   └── ocpu_if_line_buf.sv     # 行缓冲
│   │
│   ├── 控制与调试
│   │   ├── ocpu_if_ctl.sv          # 控制单元
│   │   ├── ocpu_if_stall.sv        # 停顿控制
│   │   ├── ocpu_if_flush.sv        # 冲刷控制
│   │   ├── ocpu_if_redirect.sv     # 重定向控制
│   │   ├── ocpu_if_perf.sv         # 性能计数器
│   │   └── ocpu_if_debug.sv        # 调试接口
│   │
│   └── 预取器
│       ├── ocpu_if_prefetch.sv     # 预取器主模块
│       └── ocpu_if_pf_stride.sv    # 步幅预取
│
└── docs/
    └── ifetch_design.md            # 本文件

```

---

## 模块清单和依赖关系

### 顶层模块接口

```systemverilog
module ocpu_ifetch #(
    parameter XLEN          = 64,           // 64位架构
    parameter FETCH_WIDTH   = 64,           // 64字节取指宽度
    parameter BUS_WIDTH     = 512,          // 512-bit总线
    parameter DQ_DEPTH      = 64,           // 解码队列深度
    parameter BTB_ENTRIES   = 2048,         // BTB条目数
    parameter GHB_ENTRIES   = 8192,         // GHB条目数
    parameter RAS_DEPTH     = 32            // RAS深度
)(
    // 时钟和复位
    input  wire             clk,
    input  wire             reset_n,
    
    // 配置接口
    input  wire [31:0]      config_i,       // 配置寄存器
    
    // 指令缓存接口 (512-bit)
    output wire [51:0]      icache_addr_o,  // 物理地址 (52位)
    output wire             icache_req_o,   // 请求有效
    input  wire [511:0]     icache_data_i,  // 512-bit数据返回
    input  wire             icache_valid_i, // 数据有效
    
    // 输出到解码阶段 (16条指令)
    output wire [511:0]     inst_data_o,    // 16 x 32-bit指令
    output wire [15:0]      inst_valid_o,   // 16条指令有效位
    output wire [1023:0]    inst_pc_o,      // 16 x 64-bit PC
    
    // 分支预测结果
    output wire [15:0]      pred_taken_o,   // 预测跳转
    output wire [1023:0]    pred_target_o,  // 预测目标地址
    
    // 重定向输入
    input  wire             redirect_i,     // 重定向信号
    input  wire [63:0]      redirect_pc_i,  // 重定向PC
    
    // 性能监控
    output wire [63:0]      perf_fetch_cnt_o,   // 取指计数
    output wire [63:0]      perf_btb_hit_o,     // BTB命中
    output wire [63:0]      perf_btb_miss_o     // BTB缺失
);
```

---

## 系统整体架构

### 取指流水线 (10级)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           OCPU IFetch 3.0 流水线                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Cycle 1-2: 地址生成与TLB查找                                                  │
│  ┌──────────────┐    ┌──────────────┐                                         │
│  │   PC生成      │───▶│   ITLB查找    │                                        │
│  │  (64-bit PC) │    │  (64→52位)   │                                        │
│  └──────────────┘    └──────────────┘                                         │
│                                                                              │
│  Cycle 3-4: 指令缓存访问 (512-bit总线)                                         │
│  ┌──────────────┐    ┌──────────────┐                                         │
│  │   L1-I请求    │───▶│   512-bit返回 │                                        │
│  │  (256KB 8-way)    │   (16条指令)  │                                        │
│  └──────────────┘    └──────────────┘                                         │
│                                                                              │
│  Cycle 5: 预解码与分支预测                                                     │
│  ┌──────────────┐    ┌──────────────────────────────────────────┐            │
│  │   预解码      │───▶│   分支预测 (BTB/GHB/RAS/TAGE)            │            │
│  │  (16条指令)   │    │   2048/8192/32项                         │            │
│  └──────────────┘    └──────────────────────────────────────────┘            │
│                                                                              │
│  Cycle 6-7: 指令队列与对齐                                                     │
│  ┌──────────────┐    ┌──────────────┐                                         │
│  │   指令队列    │───▶│   指令对齐    │                                        │
│  │   (64深度)    │    │  (16条输出)   │                                        │
│  └──────────────┘    └──────────────┘                                         │
│                                                                              │
│  Cycle 8-10: 解码队列输出                                                      │
│  ┌──────────────┐    ┌──────────────┐                                         │
│  │   解码队列    │───▶│   输出到ID    │                                        │
│  │   (64深度)    │    │  (16条/周期)  │                                        │
│  └──────────────┘    └──────────────┘                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 分支预测架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OCPU 3.0 分支预测器架构                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   PC输入 (64-bit)                                                             │
│       │                                                                       │
│       ├──▶ BTB (2048项, 8-way) ──▶ 目标地址预测                              │
│       │                              (64-bit目标地址)                         │
│       │                                                                       │
│       ├──▶ GHB (8192项) ─────────▶ 方向预测                                  │
│       │       │                      (跳转/不跳转)                           │
│       │       ▼                                                               │
│       │   全局历史寄存器 (20-bit)                                            │
│       │                                                                       │
│       ├──▶ RAS (32项) ───────────▶ 返回地址预测                              │
│       │                              (函数返回)                              │
│       │                                                                       │
│       └──▶ TAGE (多表1024项) ────▶ 高级预测                                  │
│                                                                              │
│   预测结果组合                                                                │
│       │                                                                       │
│       ▼                                                                       │
│   最终预测: 跳转/不跳转 + 目标地址                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 核心模块详细分析

### 1. Fetch Pipeline (ocpu_if_fp)

#### 功能
- 生成取指地址
- 发起指令缓存请求
- 处理重定向和分支预测

#### 3.0版本更新
- 支持512-bit缓存返回
- 64字节对齐取指
- 16指令预取缓冲

#### 接口
```systemverilog
module ocpu_if_fp #(
    parameter XLEN = 64,
    parameter FETCH_WIDTH = 64,     // 64字节
    parameter BUS_WIDTH = 512       // 512-bit总线
)(
    input  wire             clk,
    input  wire             reset_n,
    
    // PC输入
    input  wire [XLEN-1:0]  pc_i,
    input  wire             pc_valid_i,
    
    // 缓存接口 (512-bit)
    output wire [51:0]      cache_addr_o,
    output wire             cache_req_o,
    input  wire [511:0]     cache_data_i,
    input  wire             cache_valid_i,
    
    // 指令输出 (16条)
    output wire [511:0]     inst_data_o,      // 16 x 32-bit
    output wire [15:0]      inst_valid_o,
    output wire [1023:0]    inst_pc_o,        // 16 x 64-bit PC
    
    // 控制
    input  wire             stall_i,
    input  wire             flush_i,
    input  wire             redirect_i,
    input  wire [XLEN-1:0]  redirect_pc_i
);
```

### 2. Branch Target Buffer (BTB)

#### 3.0版本配置
| 参数 | 值 | 说明 |
|------|-----|------|
| 条目数 | 2048 | 4倍于2.0版本 |
| 路数 | 8-way | 组相联 |
| 标签宽度 | 41-bit | 52位地址 - 11位索引 |
| 目标地址 | 52-bit | 物理地址 |

#### 性能预期
- **命中率**: >95% (典型工作负载)
- **访问延迟**: 1周期
- **功耗**: 3nm工艺优化

### 3. Global History Buffer (GHB)

#### 3.0版本配置
| 参数 | 值 | 说明 |
|------|-----|------|
| 条目数 | 8192 | 2倍于2.0版本 |
| 历史长度 | 20-bit | 更长历史 |
| 模式表 | 4个 | TAGE辅助 |

---

## 关键设计决策

### 1. 512-bit总线设计

**决策**: 采用512-bit内部总线

**理由**:
- 匹配16指令发射宽度 (16 × 32-bit = 512-bit)
- 4倍带宽提升
- 减少缓存访问次数

**实现**:
- L1-I Cache 512-bit数据接口
- 取指队列512-bit宽度
- 预解码512-bit输入

### 2. 3nm工艺优化

**决策**: 针对3nm工艺优化设计

**优化点**:
- 支持3GHz+时钟频率
- 低电压运行 (0.5V-0.85V)
- 更高的分支预测表容量

### 3. 大容量分支预测

**决策**: BTB 2048项, GHB 8192项

**理由**:
- 16发射宽度需要更高预测准确率
- 减少分支预测失误惩罚
- 支持更复杂的控制流

---

## 附录

### A. 配置参数汇总

```systemverilog
// OCPU 3.0 IFetch 配置参数
`define OCPU_IF_PROCESS_NODE    3       // 3nm工艺
`define OCPU_IF_BUS_WIDTH       512     // 512-bit总线
`define OCPU_IF_WIDTH           64      // 64字节取指
`define OCPU_IF_FETCH_WIDTH     16      // 16条指令
`define OCPU_IF_DQ_DEPTH        64      // 解码队列深度
`define OCPU_IF_BTB_DEPTH       2048    // BTB深度
`define OCPU_IF_BTB_WAY         8       // BTB路数
`define OCPU_IF_GHB_DEPTH       8192    // GHB深度
`define OCPU_IF_RAS_DEPTH       32      // RAS深度
`define OCPU_IF_L1I_SIZE        262144  // 256KB L1-I
`define OCPU_IF_L1I_WAYS        8       // L1-I路数
```

### B. 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 取指带宽 | 64指令/周期 | 峰值性能 |
| BTB命中率 | >95% | 典型负载 |
| 分支预测准确率 | >97% | 含TAGE |
| 缓存命中延迟 | 2-3周期 | L1-I命中 |
| 功耗 | <500mW | @3nm, 3GHz |

### C. 相关文档

- [架构概述](../architecture.md)
- [配置升级3.0](../../CONFIG_UPGRADE_3.0.md)
- [项目总结](../PROJECT_SUMMARY.md)

---

**文档版本**: 3.0  
**更新日期**: 2026-02-13  
**工艺节点**: 3nm  
**总线宽度**: 512-bit
