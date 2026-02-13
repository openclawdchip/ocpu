# OCPU L2 Cache 模块设计文档 - 版本3.0

## 文档信息
- **模块名称**: ocpu_l2cache (L2缓存)
- **版本**: OCPU-RV64I-r3p0
- **工艺节点**: 3nm
- **总线宽度**: 512-bit
- **更新日期**: 2026-02-13

---

## 概述

`ocpu_l2cache` 是 OCPU 处理器的L2缓存单元，提供L1缓存的后备存储，维护多核一致性，并作为内存系统的接口。

### OCPU 3.0 特性

| 特性 | 配置 |
|------|------|
| **L2缓存容量** | 4MB |
| **组相联度** | 16-way |
| **Bank数** | 8个 |
| **总线宽度** | 512-bit |
| **MSHR数量** | 32个 |
| **一致性协议** | MESI |
| **接口协议** | CHI (AMBA 5) |

---

## 版本3.0更新

### 缓存规模扩展

| 参数 | 2.0版本 | 3.0版本 | 提升 |
|------|---------|---------|------|
| **L2容量** | 512KB | **4MB** | 8x |
| **路数** | 8-way | **16-way** | 2x |
| **Bank数** | 4 | **8** | 2x |
| **MSHR** | 16 | **32** | 2x |
| **总线宽度** | 128-bit | **512-bit** | 4x |
| **请求队列** | 16深度 | **32深度** | 2x |
| **写回队列** | 16深度 | **32深度** | 2x |

### 地址计算

| 参数 | 2.0 | 3.0 |
|------|-----|-----|
| **Set Index** | 10-bit (1024 sets) | **12-bit (4096 sets)** |
| **Tag** | 48-bit | **46-bit** |
| **Offset** | 6-bit (64B line) | 6-bit |

---

## 整体架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        OCPU L2 Cache 3.0 架构                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         L1接口 (512-bit)                                     ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       ││
│  │  │   L1-I Req   │ │   L1-D Req   │ │   L1-I Resp  │ │   L1-D Resp  │       ││
│  │  │   512-bit    │ │   512-bit    │ │   512-bit    │ │   512-bit    │       ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         请求处理 (32 MSHR)                                   ││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  MSHR (Miss Status Handling Register) - 32项                           │││
│  │  │  - 跟踪未完成的缓存缺失                                                │││
│  │  │  - 合并相同缓存行的请求                                                │││
│  │  │  - 支持32个同时进行的缺失                                              │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  │                                                                               ││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  请求仲裁器                                                            │││
│  │  │  - 8个Bank并行访问                                                     │││
│  │  │  - 地址散列减少冲突                                                    │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         L2缓存阵列 (4MB, 16-way)                             ││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  Bank 0-7 (每个Bank 512KB)                                             │││
│  │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │││
│  │  │  │ Way 0  │ │ Way 1  │ │ ...    │ │ Way 14 │ │ Way 15 │ │ Tag    │   │││
│  │  │  │ 512-bit│ │ 512-bit│ │        │ │ 512-bit│ │ 512-bit│ │46-bit  │   │││
│  │  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │││
│  │  │                                                                          │││
│  │  │  每Bank配置:                                                             │││
│  │  │  - 512行 × 16路 = 8192项                                                │││
│  │  │  - 每项64字节                                                            │││
│  │  │  - 总计: 8192 × 64B = 512KB per Bank                                    │││
│  │  │  - 8 Banks: 4MB total                                                   │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         一致性控制 (MESI)                                    │││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                         ││
│  │  │   MESI状态机 │ │   监听控制   │ │   写回控制   │                         ││
│  │  │  Modified    │ │   Snooper    │ │   Writeback  │                         ││
│  │  │  Exclusive   │ │   (监听L1)   │ │   (脏行写回) │                         ││
│  │  │  Shared      │ │              │ │              │                         ││
│  │  │  Invalid     │ │              │ │              │                         ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘                         ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         内存接口 (CHI协议)                                   │││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  CHI TX: 请求发送到内存控制器                                          │││
│  │  │  CHI RX: 响应从内存控制器接收                                          │││
│  │  │  数据宽度: 512-bit                                                     │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 核心模块详细分析

### 1. L2控制器

```systemverilog
module ocpu_l2cache #(
    parameter L2_SIZE = 4*1024*1024,    // 4MB
    parameter L2_WAYS = 16,             // 16-way
    parameter L2_BANKS = 8,             // 8 banks
    parameter L2_LINE_SIZE = 64,        // 64B line
    parameter MSHR_NUM = 32,            // 32 MSHR
    parameter BUS_WIDTH = 512           // 512-bit总线
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // L1-I接口 (512-bit)
    input  wire                     l1i_req_valid_i,
    input  wire [51:0]              l1i_req_addr_i,
    output wire                     l1i_req_ready_o,
    output wire [511:0]             l1i_resp_data_o,
    output wire                     l1i_resp_valid_o,
    
    // L1-D接口 (512-bit)
    input  wire                     l1d_req_valid_i,
    input  wire [51:0]              l1d_req_addr_i,
    input  wire                     l1d_req_write_i,
    input  wire [511:0]             l1d_req_data_i,
    input  wire [63:0]              l1d_req_be_i,     // 64-bit字节使能
    output wire                     l1d_req_ready_o,
    output wire [511:0]             l1d_resp_data_o,
    output wire                     l1d_resp_valid_o,
    
    // CHI接口 (512-bit)
    output wire                     chi_tx_valid_o,
    output wire [7:0]               chi_tx_opc_o,     // 操作码
    output wire [51:0]              chi_tx_addr_o,
    output wire [511:0]             chi_tx_data_o,
    input  wire                     chi_rx_valid_i,
    input  wire [511:0]             chi_rx_data_i
);
```

### 2. MSHR (Miss Status Handling Register) - 32项

```systemverilog
module ocpu_l2_mshr #(
    parameter MSHR_NUM = 32,
    parameter ADDR_WIDTH = 52,
    parameter BUS_WIDTH = 512
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 分配MSHR (新缓存缺失)
    input  wire                     alloc_valid_i,
    input  wire [ADDR_WIDTH-1:0]    alloc_addr_i,
    output wire [4:0]               alloc_id_o,       // 5-bit MSHR ID
    output wire                     alloc_ready_o,    // MSHR有空闲
    
    // 合并检测 (相同缓存行的其他请求)
    input  wire [ADDR_WIDTH-1:0]    lookup_addr_i,
    output wire                     lookup_hit_o,     // 可以合并
    output wire [4:0]               lookup_mshr_id_o,
    
    // MSHR完成 (数据从内存返回)
    input  wire                     fill_valid_i,
    input  wire [4:0]               fill_mshr_id_i,
    input  wire [511:0]             fill_data_i,
    
    // 状态输出
    output wire [31:0]              mshr_busy_o       // 32个MSHR忙状态
);
```

### 3. Bank控制器 (8个Bank)

```systemverilog
module ocpu_l2_bank #(
    parameter BANK_ID = 0,
    parameter BANK_SIZE = 512*1024,     // 512KB per bank
    parameter WAYS = 16,
    parameter LINE_SIZE = 64,
    parameter BUS_WIDTH = 512
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 请求输入
    input  wire                     req_valid_i,
    input  wire [51:0]              req_addr_i,
    input  wire                     req_write_i,
    input  wire [511:0]             req_data_i,
    input  wire [63:0]              req_be_i,
    output wire                     req_ready_o,
    
    // 响应输出
    output wire                     resp_valid_o,
    output wire [511:0]             resp_data_o,
    output wire                     resp_hit_o,       // Hit/Miss
    
    // MSHR接口 (Miss时)
    output wire                     miss_valid_o,
    output wire [51:0]              miss_addr_o,
    input  wire                     fill_valid_i,
    input  wire [511:0]             fill_data_i
);
```

### 4. 替换策略

```systemverilog
module ocpu_l2_repl #(
    parameter WAYS = 16,
    parameter REPL_POLICY = "PLRU"      // Pseudo-LRU
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 访问更新
    input  wire                     access_valid_i,
    input  wire [3:0]               access_way_i,     // 访问的路 (0-15)
    
    // 替换选择
    input  wire                     repl_req_i,
    output wire [3:0]               repl_way_o        // 选择替换的路
);
```

---

## 地址映射

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        52-bit物理地址映射                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  52-bit物理地址:                                                             │
│  ┌────────┬──────────┬──────────┬─────────────┐                              │
│  │ Tag    │ Bank ID  │ Set Idx  │ Offset      │                              │
│  │ [51:12]│ [11:9]   │ [8:6]    │ [5:0]       │                              │
│  │ 40-bit │ 3-bit    │ 3-bit    │ 6-bit       │                              │
│  └────────┴──────────┴──────────┴─────────────┘                              │
│                                                                              │
│  实际L2映射 (4MB, 16-way, 8 Bank):                                           │
│  ┌────────┬──────────┬───────────┬────────────┐                              │
│  │ Tag    │ Bank ID  │ Set Index │ Offset     │                              │
│  │ [51:15]│ [14:12]  │ [11:6]    │ [5:0]      │                              │
│  │ 37-bit │ 3-bit    │ 6-bit     │ 6-bit      │                              │
│  └────────┴──────────┴───────────┴────────────┘                              │
│                                                                              │
│  Bank内: 64 sets × 16 ways = 1024项                                          │
│  每Bank: 1024 × 64B = 64KB tag + 512KB data                                  │
│  总计: 8 Banks = 4MB                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **访问延迟 (Hit)** | 4-5周期 | L2命中 |
| **访问延迟 (Miss)** | 20-30周期 | 到内存 |
| **吞吐量** | 8访问/周期 | 8 Banks并行 |
| **带宽** | 64GB/s | 512-bit @ 1GHz |
| **命中率** | 90%+ | 典型负载 |
| **MSHR利用率** | 70%+ | 32个MSHR |

---

## 配置参数

```systemverilog
// OCPU 3.0 L2 Cache 配置参数
`define OCPU_L2_PROCESS_NODE    3
`define OCPU_L2_BUS_WIDTH       512
`define OCPU_L2_SIZE            (4*1024*1024)   // 4MB
`define OCPU_L2_LINE_SIZE       64              // 64B
`define OCPU_L2_WAY_NUM         16              // 16-way
`define OCPU_L2_BANK_NUM        8               // 8 banks
`define OCPU_L2_MSHR_NUM        32              // 32 MSHR
`define OCPU_L2_REQ_DEPTH       32              // 32深度请求队列
`define OCPU_L2_WB_DEPTH        32              // 32深度写回队列
```

---

**文档版本**: 3.0  
**更新日期**: 2026-02-13  
**工艺节点**: 3nm  
**总线宽度**: 512-bit
