# OCPU Commit 模块设计文档 - 版本3.0

## 文档信息
- **模块名称**: ocpu_commit (提交单元)
- **版本**: OCPU-RV64I-r3p0
- **工艺节点**: 3nm
- **总线宽度**: 512-bit
- **更新日期**: 2026-02-13

---

## 概述

`ocpu_commit` 是 OCPU 处理器的提交单元，负责按程序顺序提交指令、管理ROB (重排序缓冲区)、处理异常和中断、管理CSR寄存器。

### OCPU 3.0 特性

| 特性 | 配置 |
|------|------|
| **提交宽度** | 16条指令/周期 |
| **ROB深度** | 256项 |
| **物理寄存器** | 512个 (整数/浮点) |
| **异常处理** | 精确异常 |
| **中断延迟** | <10周期 |
| **总线宽度** | 512-bit |

---

## 版本3.0更新

### 提交系统扩展

| 参数 | 2.0版本 | 3.0版本 | 提升 |
|------|---------|---------|------|
| **提交宽度** | 4 | **16** | 4x |
| **ROB深度** | 128 | **256** | 2x |
| **ROB索引位宽** | 7 | **8** | +1bit |
| **物理寄存器** | 128 | **512** | 4x |
| **寄存器索引位宽** | 7 | **9** | +2bit |
| **物理向量寄存器** | 128 | **256** | 2x |
| **MCQ深度** | 128 | **256** | 2x |

### 异常处理能力

| 特性 | 2.0 | 3.0 |
|------|-----|-----|
| **同时挂起异常数** | 1 | **4** |
| **中断响应延迟** | <20周期 | **<10周期** |
| **异常恢复速度** | 标准 | **加速** |

---

## 整体架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         OCPU Commit 3.0 架构                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         ROB (重排序缓冲区) - 256项                           ││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  ROB Entry (每项)                                                      │││
│  │  │  - 指令PC (64-bit)                                                     │││
│  │  │  - 指令编码 (32-bit)                                                   │││
│  │  │  - 目的寄存器 (9-bit: 512个物理寄存器)                                  │││
│  │  │  - 完成状态 (1-bit)                                                    │││
│  │  │  - 异常标志 (1-bit)                                                    │││
│  │  │  - 内存访问标志 (1-bit)                                                │││
│  │  │  - 分支标志 (1-bit)                                                    │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  │                                                                               ││
│  │  头指针 (Head): 指向最老的未完成指令                                       ││
│  │  尾指针 (Tail): 指向下一个分配位置                                          ││
│  │  有效范围: 最多256项同时在飞 (in-flight)                                   ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         提交逻辑 (16条/周期)                                  ││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  每周期检查:                                                           │││
│  │  │  1. ROB头部16项是否全部完成?                                           │││
│  │  │  2. 是否有异常?                                                        │││
│  │  │  3. 是否需要序列化? (fence/异常/中断)                                  │││
│  │  │  4. 提交16条到架构状态                                                 │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         异常与中断处理                                       │││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       ││
│  │  │   异常检测   │ │   异常仲裁   │ │   状态保存   │ │   恢复重启   │       ││
│  │  │  4个同时检测 │ │  优先级排序  │ │  精确现场    │ │  流水线冲刷  │       ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       ││
│  │                                                                               ││
│  │  支持异常类型:                                                                ││
│  │  - 指令页错误 (Instruction Page Fault)                                       ││
│  │  - 数据页错误 (Data Page Fault)                                              ││
│  │  - 未定义指令 (Illegal Instruction)                                          ││
│  │  - 访问错误 (Access Fault)                                                   ││
│  │  - 环境调用 (ECALL/EBREAK)                                                   ││
│  │  - 外部中断 (External Interrupt)                                             ││
│  │  - 计时器中断 (Timer Interrupt)                                              ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         CSR寄存器文件                                        │││
│  │  ┌────────────────────────────────────────────────────────────────────────┐││
│  │  │  RISC-V标准CSRs                                                        │││
│  │  │  - mstatus (机器状态)                                                  │││
│  │  │  - mepc (异常PC)                                                       │││
│  │  │  - mcause (异常原因)                                                   │││
│  │  │  - mtvec (陷阱向量)                                                    │││
│  │  │  - mie/mip (中断使能/等待)                                             │││
│  │  │  - mcycle/minstret (性能计数器)                                        │││
│  │  │  - 自定义性能监控寄存器 (64个)                                         │││
│  │  └────────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 核心模块详细分析

### 1. ROB (Reorder Buffer) - 256项

```systemverilog
module ocpu_ct_rob #(
    parameter DEPTH = 256,              // 256深度
    parameter INDEX_WIDTH = 8,          // 8-bit索引
    parameter XLEN = 64,
    parameter PREG_WIDTH = 9            // 9-bit物理寄存器号 (512个)
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 分配端口 (从重命名阶段)
    input  wire [15:0]              alloc_valid_i,     // 最多16条分配
    input  wire [15:0][XLEN-1:0]    alloc_pc_i,
    input  wire [15:0][31:0]        alloc_inst_i,
    input  wire [15:0][PREG_WIDTH-1:0] alloc_dest_i,   // 目的物理寄存器
    output wire [15:0][INDEX_WIDTH-1:0] alloc_rob_id_o, // ROB索引
    output wire                     alloc_ready_o,     // ROB有空闲
    
    // 完成端口 (从执行单元)
    input  wire [31:0]              complete_valid_i,  // 32个执行单元完成
    input  wire [31:0][INDEX_WIDTH-1:0] complete_rob_id_i,
    input  wire [31:0]              complete_exception_i,
    
    // 提交端口
    output wire [15:0]              commit_valid_o,    // 16条提交
    output wire [15:0][INDEX_WIDTH-1:0] commit_rob_id_o,
    output wire [15:0][XLEN-1:0]    commit_pc_o,
    output wire [15:0]              commit_exception_o,
    
    // 当前状态
    output wire [INDEX_WIDTH-1:0]   rob_head_o,
    output wire [INDEX_WIDTH-1:0]   rob_tail_o,
    output wire [INDEX_WIDTH:0]     rob_count_o        // 9-bit计数 (0-256)
);
```

### 2. 提交控制 (Commit Control)

```systemverilog
module ocpu_ct_commit_ctrl #(
    parameter COMMIT_WIDTH = 16,        // 16条提交
    parameter ROB_DEPTH = 256
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // ROB状态输入
    input  wire [COMMIT_WIDTH-1:0]  rob_entry_valid_i, // 16项完成状态
    input  wire [COMMIT_WIDTH-1:0]  rob_entry_exception_i,
    input  wire [COMMIT_WIDTH-1:0]  rob_entry_mem_i,   // 内存访问标记
    input  wire [COMMIT_WIDTH-1:0]  rob_entry_branch_i,// 分支标记
    
    // 中断输入
    input  wire                     irq_external_i,
    input  wire                     irq_timer_i,
    input  wire                     irq_software_i,
    
    // 提交决策输出
    output wire [COMMIT_WIDTH-1:0]  commit_grant_o,    // 允许提交
    output wire                     exception_detect_o,// 检测到异常
    output wire                     irq_accept_o,      // 接受中断
    output wire                     flush_pipeline_o   // 冲刷流水线
);
```

### 3. 异常处理单元

```systemverilog
module ocpu_ct_exception #(
    parameter XLEN = 64,
    parameter NUM_EXCEPTION_TYPES = 64
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // 异常检测 (最多4个同时)
    input  wire [3:0]               exc_valid_i,
    input  wire [3:0][5:0]          exc_type_i,        // 异常类型
    input  wire [3:0][XLEN-1:0]     exc_pc_i,          // 异常PC
    input  wire [3:0][XLEN-1:0]     exc_tval_i,        // 异常值
    
    // 当前特权级
    input  wire [1:0]               priv_mode_i,       // M/S/U
    
    // CSR更新输出
    output wire                     csr_mstatus_wen_o,
    output wire [XLEN-1:0]          csr_mstatus_wdata_o,
    output wire                     csr_mepc_wen_o,
    output wire [XLEN-1:0]          csr_mepc_wdata_o,
    output wire                     csr_mcause_wen_o,
    output wire [XLEN-1:0]          csr_mcause_wdata_o,
    output wire                     csr_mtval_wen_o,
    output wire [XLEN-1:0]          csr_mtval_wdata_o,
    
    // 陷阱向量输出
    output wire [XLEN-1:0]          trap_vector_o,
    output wire                     trap_valid_o
);
```

### 4. CSR寄存器文件

```systemverilog
module ocpu_ct_csr #(
    parameter XLEN = 64,
    parameter NUM_PMC = 64              // 64个性能监控计数器
)(
    input  wire                     clk,
    input  wire                     reset_n,
    
    // CSR读写端口
    input  wire                     csr_rd_en_i,
    input  wire [11:0]              csr_addr_i,
    output wire [XLEN-1:0]          csr_rdata_o,
    
    input  wire                     csr_wr_en_i,
    input  wire [11:0]              csr_wr_addr_i,
    input  wire [XLEN-1:0]          csr_wr_data_i,
    
    // 自动更新 (由提交单元触发)
    input  wire                     instret_inc_i,     // 指令退休计数
    input  wire [15:0]              instret_cnt_i,     // 每周期退休数 (0-16)
    
    // 性能监控计数器更新
    input  wire [NUM_PMC-1:0]       pmc_inc_i,         // 64个PMC增量
    
    // 中断使能输出
    output wire                     irq_mie_o,         // 机器中断使能
    output wire                     irq_sie_o          // 监督中断使能
);
```

---

## 提交流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           提交流程 (每周期)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Step 1: 检查ROB头部                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  读取ROB[Head]到ROB[Head+15] (16项)                                 │   │
│  │  检查: 是否全部完成?                                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼                                               │
│  Step 2: 异常/中断检测                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  检查16项中的异常标志                                               │   │
│  │  检查外部中断输入                                                   │   │
│  │  如果有异常/中断: 停止提交, 进入处理流程                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼                                               │
│  Step 3: 序列化检查                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  检查是否有Fence指令                                                │   │
│  │  检查是否有CSR同步指令                                              │   │
│  │  如果需要序列化: 只提交到该指令                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼                                               │
│  Step 4: 提交执行                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  提交0-16条指令:                                                    │   │
│  │  - 更新架构寄存器 (物理→逻辑映射)                                   │   │
│  │  - 更新CSR (instret等)                                              │   │
│  │  - 释放物理寄存器到空闲列表                                         │   │
│  │  - 更新ROB头指针                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼                                               │
│  Step 5: 中断处理 (如果需要)                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  保存当前PC到mepc                                                   │   │
│  │  设置mcause为中断原因                                               │   │
│  │  跳转到mtvec处理                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **提交吞吐量** | 16指令/周期 | 峰值性能 |
| **ROB利用率** | 80%+ | 典型负载 |
| **异常延迟** | <10周期 | 检测→处理完成 |
| **中断响应** | <10周期 | 中断输入→跳转 |
| **上下文切换** | <100周期 | 完整状态保存/恢复 |

---

## 配置参数

```systemverilog
// OCPU 3.0 Commit 配置参数
`define OCPU_CT_PROCESS_NODE    3
`define OCPU_CT_BUS_WIDTH       512
`define OCPU_CT_COMMIT_WIDTH    16      // 16条提交
`define OCPU_CT_ROB_DEPTH       256     // 256项ROB
`define OCPU_CT_ROB_WIDTH       8       // 8-bit索引
`define OCPU_CT_NUM_PREG        512     // 512物理寄存器
`define OCPU_CT_PREG_WIDTH      9       // 9-bit索引
`define OCPU_CT_NUM_PVREG       256     // 256物理向量寄存器
`define OCPU_CT_MCQ_DEPTH       256     // 256项MCQ
```

---

**文档版本**: 3.0  
**更新日期**: 2026-02-13  
**工艺节点**: 3nm  
**总线宽度**: 512-bit
