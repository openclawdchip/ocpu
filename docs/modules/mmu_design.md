# OCPU MMU 模块设计文档

**版本**: OCPU-v1.0  
**架构**: RISC-V RV64I (Sv39)  
**分析日期**: 2026-02-12

---

## 目录

1. [概述](#概述)
2. [模块架构](#模块架构)
3. [核心模块详细分析](#核心模块详细分析)
4. [页表遍历](#页表遍历)
5. [接口定义](#接口定义)

---

## 概述

OCPU MMU 模块实现RISC-V Sv39页表格式，负责虚拟地址到物理地址的转换。

### MMU特性

| 特性 | 规格 |
|------|------|
| 页表格式 | Sv39 (RISC-V) |
| 虚拟地址 | 39位有效 (64位扩展) |
| 物理地址 | 48位 |
| 页大小 | 4KB / 2MB / 1GB |
| TLB | ITLB + DTLB |

---

## 模块架构

```
ocpu_mmu/
├── ocpu_mmu.sv             # MMU顶层
├── ocpu_mmu_ptw.sv         # 页表遍历
├── ocpu_mmu_itlb.sv        # 指令TLB
└── ocpu_mmu_dtlb.sv        # 数据TLB
```

---

## 核心模块详细分析

### 1. ocpu_mmu - MMU顶层

**功能**:
- TLB查询和填充
- 页表遍历控制
- 异常检测

**接口**:
```systemverilog
module ocpu_mmu #(
    parameter VA_WIDTH = 64,
    parameter PA_WIDTH = 48
)(
    // 时钟复位
    input  wire         clk,
    input  wire         reset_n,
    
    // ITLB接口
    input  wire [63:0]  itlb_req_va,
    input  wire         itlb_req_valid,
    output wire [47:0]  itlb_rsp_pa,
    output wire         itlb_rsp_valid,
    output wire         itlb_miss,
    
    // DTLB接口
    input  wire [63:0]  dtlb_req_va,
    input  wire         dtlb_req_valid,
    output wire [47:0]  dtlb_rsp_pa,
    output wire         dtlb_rsp_valid,
    output wire         dtlb_miss,
    
    // PTW接口
    output wire [47:0]  ptw_req_pa,
    output wire         ptw_req_valid,
    input  wire [63:0]  ptw_rsp_data,
    input  wire         ptw_rsp_valid,
    
    // SATP (页表基址)
    input  wire [63:0]  satp,
    
    // 异常输出
    output wire         page_fault,
    output wire [3:0]   fault_type
);
```

### 2. ocpu_mmu_ptw - 页表遍历

**功能**:
- 三级页表遍历
- 支持大页 (2MB, 1GB)
- 页权限检查

**Sv39页表格式**:
```
虚拟地址 (64位):
┌────────────┬───────────┬───────────┬───────────┬────────────┐
│ 63-39      │ 38-30     │ 29-21     │ 20-12     │ 11-0       │
│ 符号扩展    │ VPN[2]    │ VPN[1]    │ VPN[0]    │ 页内偏移   │
│ 25位       │ 9位       │ 9位       │ 9位       │ 12位       │
└────────────┴───────────┴───────────┴───────────┴────────────┘

PTE格式 (64位):
┌────────────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│ 63-54      │ 53-10│ 9-8  │ 7    │ 6    │ 5    │ 4    │ 3    │
│ 保留        │ PPN  │ RSW  │ D    │ A    │ G    │ U    │ X    │
├────────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ 2          │ 1    │ 0    │
│ W          │ R    │ V    │
└────────────┴──────┴──────┘
```

**页表遍历状态机**:
```systemverilog
typedef enum logic [2:0] {
    PTW_IDLE,
    PTW_LEVEL2,
    PTW_LEVEL1,
    PTW_LEVEL0,
    PTW_DONE,
    PTW_FAULT
} ptw_state_t;

ptw_state_t ptw_state;
```

**遍历逻辑**:
```systemverilog
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ptw_state <= PTW_IDLE;
    end else begin
        case (ptw_state)
            PTW_IDLE: begin
                if (ptw_req_valid) begin
                    ptw_va <= ptw_req_va;
                    ptw_state <= PTW_LEVEL2;
                end
            end
            
            PTW_LEVEL2: begin
                // 读取第一级页表
                ptw_l2_addr <= {satp[43:0], 12'd0} + 
                               {35'd0, ptw_va[38:30], 3'd0};
                if (ptw_l2_ready)
                    ptw_state <= PTW_LEVEL1;
            end
            
            PTW_LEVEL1: begin
                // 检查第一级PTE
                if (!pte_v) begin
                    ptw_state <= PTW_FAULT;
                end else if (pte_r || pte_x) begin
                    // 叶节点 (1GB页)
                    ptw_pa <= {pte_ppn[53:30], ptw_va[29:0]};
                    ptw_state <= PTW_DONE;
                end else begin
                    // 继续遍历
                    ptw_pt_base <= pte_ppn;
                    ptw_state <= PTW_LEVEL0;
                end
            end
            
            PTW_LEVEL0: begin
                // 读取第三级页表
                ptw_l2_addr <= {ptw_pt_base, 12'd0} + 
                               {35'd0, ptw_va[20:12], 3'd0};
                if (ptw_l2_valid) begin
                    if (!pte_v || (!pte_r && pte_w)) begin
                        ptw_state <= PTW_FAULT;
                    end else begin
                        // 4KB页
                        ptw_pa <= {pte_ppn, ptw_va[11:0]};
                        ptw_state <= PTW_DONE;
                    end
                end
            end
            
            PTW_DONE: begin
                ptw_rsp_valid <= 1'b1;
                ptw_state <= PTW_IDLE;
            end
            
            PTW_FAULT: begin
                ptw_fault <= 1'b1;
                ptw_state <= PTW_IDLE;
            end
        endcase
    end
end
```

### 3. ocpu_mmu_itlb - 指令TLB

**功能**:
- 缓存最近使用的指令地址映射
- 32条目，4路组相联

**结构**:
```systemverilog
typedef struct packed {
    logic               valid;
    logic [26:0]        tag;        // VPN[38:12]
    logic [35:0]        ppn;        // 物理页号
    logic [2:0]         flags;      // 权限位
} itlb_entry_t;

itlb_entry_t itlb [0:7][0:3];  // 8组 x 4路
```

**查询逻辑**:
```systemverilog
wire [2:0]  itlb_idx = va[14:12];
wire [26:0] itlb_tag = va[38:12];

// 4路并行比较
wire [3:0] itlb_hit_way;
genvar i;
generate
for (i = 0; i < 4; i = i + 1) begin
    assign itlb_hit_way[i] = itlb[itlb_idx][i].valid &&
                             (itlb[itlb_idx][i].tag == itlb_tag);
end
endgenerate

assign itlb_hit = |itlb_hit_way;
assign itlb_pa = {itlb[itlb_idx][hit_way].ppn, va[11:0]};
```

---

## 页表遍历

### 三级页表结构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Sv39 三级页表                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Level 2 (根页表)                                                           │
│  ┌─────────────┬────────────────────────────────────────────────────────┐  │
│  │ SATP.PPN    │ PTE[0]    PTE[1]    ...    PTE[511]                    │  │
│  │ 指向根页表   │  │        │              │                            │  │
│  └─────────────┴──┼────────┼──────────────┼────────────────────────────┘  │
│                   │        │              │                                 │
│                   ▼        ▼              ▼                                 │
│              Level 1     Level 1      Level 1                               │
│              (2MB页)     (2MB页)      (下一级)                              │
│              ┌─────┐     ┌─────┐       ┌─────┐                             │
│              │PTE  │     │PTE  │       │PTE  │                             │
│              └─────┘     └─────┘       └──┬──┘                             │
│                                            │                                │
│                                            ▼                                │
│                                       Level 0                               │
│                                       (4KB页)                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 大页支持

| 页类型 | 大小 | VPN使用 | PPN使用 |
|--------|------|---------|---------|
| 4KB页 | 4KB | VPN[2:0] | PPN[53:0] |
| 2MB页 | 2MB | VPN[2:1] | PPN[53:9] |
| 1GB页 | 1GB | VPN[2] | PPN[53:18] |

---

## 接口定义

### TLB查询接口

| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `tlb_req_va` | 64-bit | 虚拟地址 |
| `tlb_req_valid` | 1-bit | 请求有效 |
| `tlb_rsp_pa` | 48-bit | 物理地址 |
| `tlb_rsp_valid` | 1-bit | 响应有效 |
| `tlb_miss` | 1-bit | TLB Miss |

### PTW接口

| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `ptw_req_pa` | 48-bit | 页表物理地址 |
| `ptw_req_valid` | 1-bit | 请求有效 |
| `ptw_rsp_data` | 64-bit | PTE数据 |
| `ptw_rsp_valid` | 1-bit | 响应有效 |

### 控制接口

| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `satp` | 64-bit | 页表基址寄存器 |
| `flush_tlb` | 1-bit | TLB冲刷 |

---

## 性能特征

| 指标 | 数值 |
|------|------|
| TLB命中延迟 | 1周期 |
| TLB Miss惩罚 | 10-20周期 |
| 页表遍历深度 | 3级 |
| 支持大页 | 4KB/2MB/1GB |

---

**文档结束**
