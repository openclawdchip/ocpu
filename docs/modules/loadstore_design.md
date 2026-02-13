# OCPU LoadStore 模块设计文档 - 版本3.0

## 文档信息
- **模块名称**: ocpu_loadstore (访存单元)
- **版本**: OCPU-RV64I-r3p0
- **工艺节点**: 3nm
- **总线宽度**: 512-bit
- **更新日期**: 2026-02-13

---

## 概述

`ocpu_loadstore` 是 OCPU 处理器的访存单元，负责执行所有Load/Store指令，管理内存访问顺序，处理D-Cache接口，并支持AMO原子操作。

### OCPU 3.0 特性

| 特性 | 配置 |
|------|------|
| **Load/Store单元数** | 8个 (4 Load + 4 Store) |
| **L1-D缓存** | 64KB, 8-way, 512-bit接口 |
| **Load Buffer** | 32深度 |
| **Store Buffer** | 32深度 |
| **Load Queue (LRQ)** | 32深度 |
| **Fill Buffer** | 32深度 |
| **总线宽度** | 512-bit |
| **AMO支持** | 完整RISC-V AMO |

---

## 版本3.0更新

### 访存单元扩展

| 参数 | 2.0版本 | 3.0版本 | 提升 |
|------|---------|---------|------|
| **Load单元数** | 2 | **4** | 2x |
| **Store单元数** | 2 | **4** | 2x |
| **L1-D缓存** | 32KB | **64KB** | 2x |
| **L1-D路数** | 4-way | **8-way** | 2x |
| **Load Buffer** | 12 | **32** | 2.7x |
| **Store Buffer** | 18 | **32** | 1.8x |
| **LRQ深度** | 12 | **32** | 2.7x |
| **Fill Buffer** | 12 | **32** | 2.7x |
| **总线宽度** | 128-bit | **512-bit** | 4x |

### 带宽提升

| 指标 | 2.0版本 | 3.0版本 | 提升 |
|------|---------|---------|------|
| **峰值Load带宽** | 16字节/周期 | **64字节/周期** | 4x |
| **峰值Store带宽** | 16字节/周期 | **64字节/周期** | 4x |
| **L1-D接口带宽** | 128-bit | **512-bit** | 4x |

---

## 整体架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        OCPU LoadStore 3.0 架构                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         执行单元 (8个)                                       ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       ││
│  │  │   LSU0       │ │   LSU1       │ │   LSU2       │ │   LSU3       │       ││
│  │  │  Load单元0   │ │  Load单元1   │ │  Load单元2   │ │  Load单元3   │       ││
│  │  │  地址计算    │ │  地址计算    │ │  地址计算    │ │  地址计算    │       ││
│  │  │  数据对齐    │ │  数据对齐    │ │  数据对齐    │ │  数据对齐    │       ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       ││
│  │                                                                               ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       ││
│  │  │   LSU4       │ │   LSU5       │ │   LSU6       │ │   LSU7       │       ││
│  │  │  Store单元0  │ │  Store单元1  │ │  Store单元2  │ │  Store单元3  │       ││
│  │  │  地址计算    │ │  地址计算    │ │  地址计算    │ │  地址计算    │       ││
│  │  │  数据合并    │ │  数据合并    │ │  数据合并    │ │  数据合并    │       ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         缓冲与队列 (512-bit数据通路)                          ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       ││
│  │  │  Load Buffer │ │  Store Buffer│ │  LRQ         │ │  Fill Buffer │       ││
│  │  │  32深度      │ │  32深度      │ │  32深度      │ │  32深度      │       ││
│  │  │  512-bit宽   │ │  512-bit宽   │ │  512-bit宽   │ │  512-bit宽   │       ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         D-Cache接口 (512-bit)                                ││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  L1-D Cache: 64KB, 8-way, 512-bit接口                                  │││
│  │  │  - 8个bank并行访问                                                     │││
│  │  │  - 支持8个并行访问 (4 Load + 4 Store)                                  │││
│  │  │  - MESI一致性协议                                                      │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         内存顺序与转发                                       ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                         ││
│  │  │  Load-Store  │ │  内存转发    │ │  AMO处理    │                         ││
│  │  │  顺序控制    │ │  (Forwarding)│ │  原子操作   │                         ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘                         ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 核心模块详细分析

### 1. Load单元 (4个)

```systemverilog
module ocpu_ls_load_unit #(
    parameter XLEN = 64,
    parameter BUS_WIDTH = 512           // 512-bit总线
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 输入: Load指令
    input  wire                     valid_i,
    input  wire [XLEN-1:0]          addr_i,         // 64-bit地址
    input  wire [2:0]               size_i,         // 访问大小 (1/2/4/8字节)
    
    // D-Cache接口 (512-bit)
    output wire [51:0]              cache_addr_o,
    output wire                     cache_req_o,
    input  wire [511:0]             cache_data_i,   // 512-bit缓存行
    input  wire                     cache_hit_i,
    
    // 输出: Load数据
    output wire [63:0]              data_o,         // 64-bit数据输出
    output wire                     valid_o,
    output wire                     exception_o     // 页错误/访问错误
);
```

### 2. Store单元 (4个)

```systemverilog
module ocpu_ls_store_unit #(
    parameter XLEN = 64,
    parameter BUS_WIDTH = 512
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 输入: Store指令
    input  wire                     valid_i,
    input  wire [XLEN-1:0]          addr_i,
    input  wire [63:0]              data_i,         // 64-bit存储数据
    input  wire [2:0]               size_i,
    
    // Store Buffer接口
    output wire [51:0]              stb_addr_o,
    output wire [63:0]              stb_data_o,
    output wire [7:0]               stb_be_o,       // 字节使能
    output wire                     stb_valid_o,
    
    // D-Cache接口
    output wire [51:0]              cache_addr_o,
    output wire [511:0]             cache_data_o,   // 512-bit存储
    output wire [63:0]              cache_be_o,     // 64-bit字节使能
    output wire                     cache_write_o
);
```

### 3. Load Buffer - 32深度

```systemverilog
module ocpu_ls_load_buffer #(
    parameter DEPTH = 32,               // 32深度
    parameter DATA_WIDTH = 512          // 512-bit
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 分配端口 (4个Load单元)
    input  wire [3:0]               alloc_valid_i,
    input  wire [3:0][51:0]         alloc_addr_i,
    output wire [3:0][4:0]          alloc_entry_o,  // 5-bit索引 (32深度)
    
    // 完成端口 (D-Cache返回)
    input  wire [3:0]               fill_valid_i,
    input  wire [3:0][4:0]          fill_entry_i,
    input  wire [3:0][511:0]        fill_data_i,    // 512-bit数据
    
    // 输出到写回
    output wire [3:0]               wb_valid_o,
    output wire [3:0][63:0]         wb_data_o       // 64-bit提取后数据
);
```

### 4. Store Buffer - 32深度

```systemverilog
module ocpu_ls_store_buffer #(
    parameter DEPTH = 32,
    parameter DATA_WIDTH = 512
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // Store分配
    input  wire [3:0]               alloc_valid_i,
    input  wire [3:0][51:0]         alloc_addr_i,
    input  wire [3:0][63:0]         alloc_data_i,
    input  wire [3:0][7:0]          alloc_be_i,
    
    // 合并检测
    input  wire [31:0][51:0]        buf_addr_i,     // 当前缓冲地址
    output wire [31:0]              merge_hits_o,   // 合并命中
    
    // 退休写入D-Cache
    input  wire                     retire_valid_i,
    output wire [51:0]              retire_addr_o,
    output wire [511:0]             retire_data_o,  // 512-bit行数据
    output wire [63:0]              retire_be_o     // 64-bit字节使能
);
```

### 5. D-Cache接口 (512-bit)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        D-Cache 512-bit接口                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   D-Cache配置:                                                               │
│   - 64KB容量, 8-way组相联                                                    │
│   - 64字节行大小                                                             │
│   - 512-bit数据接口 (8 x 64-bit bank)                                        │
│   - 8个并行访问端口                                                          │
│                                                                              │
│   请求格式:                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Address [51:0]  |  OpType [2:0]  |  Data [511:0]  |  BE [63:0]   │   │
│   │  52-bit物理地址   |  读/写/原子     |  512-bit数据   |  字节使能    │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   响应格式:                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Data [511:0]  |  Valid  |  Hit/Miss  |  Exception                 │   │
│   │  512-bit数据   |  有效   |  命中/缺失  |  异常类型                  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **Load吞吐量** | 4指令/周期 | 4个Load单元 |
| **Store吞吐量** | 4指令/周期 | 4个Store单元 |
| **总访存吞吐量** | 8指令/周期 | Load+Store |
| **Load延迟** | 2-3周期 | L1-D命中 |
| **Store延迟** | 1周期 | 写入Store Buffer |
| **内存带宽** | 64字节/周期 | 512-bit总线 |
| **L1-D命中率** | >95% | 典型负载 |

---

## 配置参数

```systemverilog
// OCPU 3.0 LoadStore 配置参数
`define OCPU_LS_PROCESS_NODE    3
`define OCPU_LS_BUS_WIDTH       512
`define OCPU_LS_NUM_LOAD        4       // 4 Load单元
`define OCPU_LS_NUM_STORE       4       // 4 Store单元
`define OCPU_LS_NUM_LS          8       // 8个LSU总计
`define OCPU_LS_L1D_SIZE        65536   // 64KB L1-D
`define OCPU_LS_L1D_WAYS        8       // 8-way
`define OCPU_LS_L1D_BANKS       8       // 8个bank
`define OCPU_LS_SB_SIZE         32      // Store Buffer 32深度
`define OCPU_LS_LB_SIZE         32      // Load Buffer 32深度
`define OCPU_LS_LRQ_SIZE        32      // LRQ 32深度
`define OCPU_LS_FB_SIZE         32      // Fill Buffer 32深度
```

---

**文档版本**: 3.0  
**更新日期**: 2026-02-13  
**工艺节点**: 3nm  
**总线宽度**: 512-bit
