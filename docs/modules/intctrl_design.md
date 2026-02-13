# OCPU 中断控制器 (ocpu_intctrl) 设计文档

## 1. 概述

### 1.1 设计目的
OCPU中断控制器是 GICv3 (Generic Interrupt Controller v3) 架构的CPU接口实现，负责管理CPU与中断分发器(Distributor)之间的中断通信。它实现了物理中断和虚拟中断的完整支持，包括IRQ和FIQ两种中断类型。

### 1.2 主要特性
- 支持GICv3架构
- 物理中断和虚拟中断支持
- 4个Exception Level (EL0-EL3) 支持
- 安全状态和非安全状态支持
- 虚拟化支持 (Hypervisor模式)
- 中断优先级和抢占机制
- AXI4-Stream接口用于与Distributor通信

### 1.3 文件列表
共处理 **12个** SystemVerilog文件：

| 序号 | 文件名 | 功能描述 |
|------|--------|----------|
| 1 | `ocpu_intctrl.sv` | 顶层模块，集成所有子模块 |
| 2 | `ocpu_ic_aon.sv` | Always-On时钟域逻辑，中断输出控制 |
| 3 | `ocpu_ic_interface.sv` | 核心接口逻辑，中断处理和优先级管理 |
| 4 | `ocpu_ic_vinterface.sv` | 虚拟中断接口，VM中断管理 |
| 5 | `ocpu_ic_spr_ctl.sv` | 系统寄存器控制接口 |
| 6 | `ocpu_ic_axi4_stream_if.sv` | AXI4-Stream接口顶层 |
| 7 | `ocpu_ic_axi4_stream_out.sv` | AXI4-Stream发送逻辑 |
| 8 | `ocpu_ic_cpuif_2_dist_fsm.sv` | CPU到Distributor的FSM |
| 9 | `ocpu_ic_dist_2_cpuif_fsm.sv` | Distributor到CPU的FSM |
| 10 | `ocpu_ic_priority_encoder_32.sv` | 32位优先级编码器 |
| 11 | `ocpu_ic_priority_filter_32.sv` | 32位优先级过滤器 |
| 12 | `ocpu_ic_onehot_5.sv` | 5位到32位独热码转换 |

---

## 2. 顶层模块 (ocpu_intctrl)

### 2.1 模块功能
顶层模块负责集成所有子模块，实现完整的GIC CPU接口功能。主要功能包括：
- 时钟和复位管理
- 中断信号输入输出
- AXI4-Stream接口
- 系统寄存器接口
- 虚拟中断控制

### 2.2 接口信号详解

#### 2.2.1 时钟和复位
```systemverilog
input wire  clk           // 主时钟
input wire  reset         // 异步复位
```

#### 2.2.2 GIC控制
```systemverilog
input wire  cb_giccdisable    // GIC禁用信号
```

#### 2.2.3 传统中断输入 (Legacy Interrupts)
```systemverilog
input wire  cb_nirq       // 传统IRQ输入 (低电平有效)
input wire  cb_nfiq       // 传统FIQ输入 (低电平有效)
input wire  cb_nvfiq      // 传统虚拟FIQ输入
input wire  cb_nvirq      // 传统虚拟IRQ输入
```

#### 2.2.4 中断输出到CPU
```systemverilog
output wire ic_nirq       // CPU IRQ输出
output wire ic_nfiq       // CPU FIQ输出
output wire ic_nvirq      // CPU虚拟IRQ输出
output wire ic_nvfiq      // CPU虚拟FIQ输出
```

#### 2.2.5 AXI4-Stream接口 (与Distributor通信)
```systemverilog
// 接收通道 (Distributor -> CPU)
input wire         cb_iritvalid   // 输入有效
input wire [15:0]  cb_iritdata    // 输入数据
input wire         cb_iritlast    // 最后一拍
output wire        cpu_iritready  // 准备接收

// 发送通道 (CPU -> Distributor)
output wire        cpu_icctvalid  // 输出有效
output wire [15:0] cpu_icctdata   // 输出数据
output wire        cpu_icctlast   // 最后一拍
input wire         cb_icctready   // 目标就绪
```

#### 2.2.6 系统寄存器接口
```systemverilog
input wire         mx_ic_spr_v         // 寄存器访问有效
input wire         mx_ic_spr_wr        // 写使能
input wire [7:0]   mx_ic_spr_addr      // 寄存器地址
input wire [63:0]  mx_ic_spr_wr_data   // 写入数据
output wire [63:0] ic_mx_spr_rd_data   // 读出数据
```

#### 2.2.7 处理器状态接口
```systemverilog
input wire [1:0]   ct_pstate_el        // 当前Exception Level
input wire         ct_sample_sys       // 系统状态采样
input wire         ct_sample_pstate    // PSTATE采样
```

### 2.3 子模块集成关系

```
ocpu_intctrl (顶层)
├── u_spr_ctl (ocpu_ic_spr_ctl)
│   └── 系统寄存器接口控制
├── u_axi4_stream_if (ocpu_ic_axi4_stream_if)
│   ├── u_dist_2_cpuif_fsm (ocpu_ic_dist_2_cpuif_fsm)
│   ├── u_cpuif_2_dist_fsm (ocpu_ic_cpuif_2_dist_fsm)
│   └── u_axi4_stream_out (ocpu_ic_axi4_stream_out)
├── u_vinterface (ocpu_ic_vinterface)
│   └── 虚拟中断处理
├── u_interface (ocpu_ic_interface)
│   └── 物理中断处理
└── u_aon (ocpu_ic_aon)
    └── 时钟门控和中断输出
```

---

## 3. 时钟管理模块 (ocpu_ic_aon)

### 3.1 功能描述
Always-On时钟域模块负责：
- 多时钟域管理（clk_ic, clk_gicc_enable, clk_axi4sp）
- 中断输出信号生成
- GIC禁用控制
- 空闲状态管理

### 3.2 时钟域
| 时钟名 | 描述 | 控制逻辑 |
|--------|------|----------|
| clk_ic | 主IC时钟 | 根据FSM活动和SPR访问动态使能 |
| clk_gicc_enable | GICC使能时钟 | GIC使能时工作 |
| clk_axi4sp | AXI4-Stream时钟 | FSM活动期间使能 |

### 3.3 中断输出逻辑

```systemverilog
// 物理中断输出
assign nxt_nirq_cpu = irq_passthrough_i ? legacy_nirq_q : ~cpu_irq_valid_i;
assign nxt_nfiq_cpu = fiq_passthrough_i ? legacy_nfiq_q : ~cpu_fiq_valid_i;

// 虚拟中断输出
assign nvirq_q = giccdisable_q ? external_nvirq_q : final_nvirq_i;
assign nvfiq_q = giccdisable_q ? external_nvfiq_q : final_nvfiq_i;
```

### 3.4 时钟门控
使用 `ocpu_ck_gate` 单元实现时钟门控，降低功耗：
- 当GIC禁用时关闭IC时钟
- 当FSM空闲时关闭AXI4-Stream时钟
- 保持计数器确保事务完成

---

## 4. 物理中断接口 (ocpu_ic_interface)

### 4.1 功能描述
核心物理中断处理模块，实现：
- 中断接收和激活
- 优先级管理
- 中断分组（Group 0, Group 1 Secure, Group 1 Non-Secure）
- 系统寄存器访问处理

### 4.2 中断分组

| 分组 | 描述 | 路由 |
|------|------|------|
| Group 0 | 安全组0中断 | 作为FIQ路由到EL3 |
| Group 1 Secure | 安全组1中断 | 作为IRQ路由到Secure EL1/EL3 |
| Group 1 Non-Secure | 非安全组1中断 | 作为IRQ路由到Non-Secure EL1/EL2 |

### 4.3 中断处理流程

```
1. 接收中断 (set_int_i)
   ↓
2. 优先级检查
   - 检查PMR (Priority Mask Register)
   - 检查当前活动中断优先级
   ↓
3. 分组检查
   - 检查对应的Group Enable位
   - 确定IRQ/FIQ路由
   ↓
4. 中断激活 (ack_req)
   - 发送确认到Distributor
   - 更新Active Priorities Register
   ↓
5. 中断完成 (EOI)
   - 写ICC_EOIRx_EL1
   - 可能发送Deactivate到Distributor
```

### 4.4 优先级编码器集成

```systemverilog
ocpu_ic_priority_encoder_32 u_highest_active_priority (
    .priority_i         ( active_priorities_s_or_ns[31:0] ),
    .encoded_priority_o ( active_irq_priority[4:0] ),
    .encoded_valid_o    ( active_irq_valid )
);
```

优先级编码器用于确定当前最高优先级的中断。

### 4.5 中断类型路由

```systemverilog
// IRQ有效条件（Group 1中断）
assign cpu_irq_valid = (
    pending_can_be_sent & mode_is_el1s & pending_irq_secure_grp1s_q & grp1_enable_s_q |
    pending_can_be_sent & mode_is_ns & pending_irq_nsecure_q & grp1_enable_ns_q
) & ~release_pend_grpen;

// FIQ有效条件（Group 0中断或特定Group 1中断）
assign cpu_fiq_valid = (
    pending_can_be_sent & grp0_enable_s_q & pending_irq_secure_q |
    pending_can_be_sent & mode_is_el3 |
    pending_can_be_sent & mode_is_el1s & pending_irq_nsecure_q |
    pending_can_be_sent & mode_is_ns & pending_irq_secure_grp1s_q
) & ~release_pend_grpen;
```

---

## 5. 虚拟中断接口 (ocpu_ic_vinterface)

### 5.1 功能描述
虚拟中断处理模块，支持v8虚拟化扩展：
- 虚拟机(VM)中断列表管理
- 虚拟CPU接口寄存器
- Hypervisor控制接口
- 维护中断生成

### 5.2 中断列表寄存器 (List Registers)
支持4个列表寄存器 (LR0-LR3)，每个存储一个虚拟中断：

| 字段 | 描述 |
|------|------|
| State | 中断状态 (Invalid/Pending/Active/Pending+Active) |
| Priority | 虚拟中断优先级 (5位) |
| Virtual ID | 虚拟中断ID (16位) |
| Physical ID | 对应物理中断ID (10位) |
| HW | 是否硬件中断 |
| NS | 非安全状态 |

### 5.3 状态机
```systemverilog
define OCPU_STATE_INVALID 2'b00  // 无效状态
define OCPU_STATE_PENDING 2'b01  // 挂起状态
define OCPU_STATE_ACTIVE  2'b10  // 激活状态
define OCPU_STATE_PACTIVE 2'b11  // 挂起+激活状态
```

### 5.4 Hypervisor控制寄存器 (ICH_HCR_EL2)

| 位域 | 名称 | 描述 |
|------|------|------|
| [14] | TDIR | 捕获DIR访问 |
| [12] | Tall1 | 捕获EL1组1访问 |
| [11] | Tall0 | 捕获EL1组0访问 |
| [10] | TC | 捕获控制寄存器访问 |

### 5.5 虚拟中断输出
```systemverilog
// 虚拟FIQ有效条件
assign fiq_valid = vm_en_s_q & pending_can_be_sent & 
                   (nxt_list0123_priority[4:0] < vm_priority_mask_q[4:0]);

// 虚拟IRQ有效条件  
assign irq_valid = vm_en_ns_q & pending_can_be_sent & 
                   (nxt_list0123_priority[4:0] < vm_priority_mask_q[4:0]);
```

---

## 6. AXI4-Stream通信接口

### 6.1 架构概述
使用AXI4-Stream协议与中断Distributor通信，支持：
- 命令包传输
- 数据流控制
- 双向通信 (CPU↔Distributor)

### 6.2 命令类型

| 命令编码 | 名称 | 描述 |
|----------|------|------|
| 4'h0 | NO_CMD | 无命令 |
| 4'h1 | CMD_ACT | 中断激活 |
| 4'h3 | CMD_REL | 中断释放 |
| 4'h4 | CMD_CLR | 清除中断 |
| 4'h6 | CMD_DIR | 中断停用(Deactivate) |
| 4'h7 | CMD_SGI | 生成SGI |
| 4'h8 | CMD_DWR | 数据写入 |
| 4'h9 | CMD_QUA | 静止(Quiesce) |
| 4'hB | CMD_DRE | 数据写入响应 |
| 4'hC | CMD_ACK | 确认 |

### 6.3 FSM状态机

#### Distributor到CPU FSM (`ocpu_ic_dist_2_cpuif_fsm`)
```systemverilog
define OCPU_IDLE_D2C  1'b0   // 空闲状态
define OCPU_READ0     1'b1   // 读取数据状态
```

#### CPU到Distributor FSM (`ocpu_ic_cpuif_2_dist_fsm`)
```systemverilog
define OCPU_IDLE_C2D   2'b00  // 空闲
define OCPU_PUSH_MSG   2'b01  // 发送消息
```

### 6.4 包格式

命令包 (16位):
```
[15:8] - 优先级/数据
[7:4]  - 保留
[5]    - PMR改变指示
[4]    - 虚拟中断指示
[3:0]  - 命令类型
```

---

## 7. 系统寄存器控制 (ocpu_ic_spr_ctl)

### 7.1 功能描述
管理系统寄存器访问的时序和控制：
- 寄存器地址锁存
- 读写控制信号生成
- 处理器状态采样
- 读数据返回

### 7.2 Exception Level检测
```systemverilog
assign ct_el0_mode_o = (ct_pstate_el_q[1:0] == 2'b00);  // EL0
assign ct_el1_mode_o = (ct_pstate_el_q[1:0] == 2'b01);  // EL1
assign ct_el2_mode_o = (ct_pstate_el_q[1:0] == 2'b10);  // EL2
assign ct_el3_mode_o = (ct_pstate_el_q[1:0] == 2'b11);  // EL3
```

### 7.3 寄存器地址映射
支持的主要寄存器：
- `ICC_IAR0_EL1` / `ICC_IAR1_EL1` - 中断确认
- `ICC_EOIR0_EL1` / `ICC_EOIR1_EL1` - 中断结束
- `ICC_HPPIR0_EL1` / `ICC_HPPIR1_EL1` - 最高优先级挂起中断
- `ICC_BPR0_EL1` / `ICC_BPR1_EL1` - 二进制点
- `ICC_PMR_EL1` - 优先级屏蔽
- `ICC_CTLR_EL1/EL3` - 控制寄存器
- `ICC_IGRPEN0_EL1` / `ICC_IGRPEN1_EL1/EL3` - 中断组使能
- `ICC_SRE_EL1/EL2/EL3` - 系统寄存器使能
- `ICH_*` - 虚拟化相关寄存器

---

## 8. 优先级管理

### 8.1 优先级编码
- 优先级字段: 8位 (但只使用[7:3]，即5位有效)
- 值越小优先级越高 (0为最高优先级)
- 支持32个优先级级别 (0-31)

### 8.2 优先级编码器 (ocpu_ic_priority_encoder_32)
将32位独热码优先级转换为5位二进制编码：
```systemverilog
// 示例: 如果priority_i[5]=1且priority_i[4:0]=0
// 则encoded_priority_o = 5'd5
```

### 8.3 优先级过滤器 (ocpu_ic_priority_filter_32)
确保只有最高优先级位被置位：
```systemverilog
assign filtered_priority[i] = priority_i[i] & ~|priority_i[i-1:0];
```

### 8.4 抢占支持
- 使用Active Priorities Register跟踪活动中断
- 支持嵌套中断（当新中断优先级高于当前运行优先级）
- 二进制点寄存器控制抢占组

---

## 9. 中断类型详解

### 9.1 IRQ (Interrupt Request)
- **类型**: 普通中断
- **路由**: 主要路由到Group 1
- **目标**: Non-Secure EL1/EL2, Secure EL1
- **寄存器**: ICC_IAR1_EL1, ICC_EOIR1_EL1

### 9.2 FIQ (Fast Interrupt Request)
- **类型**: 快速中断
- **路由**: 主要路由到Group 0
- **目标**: EL3 (安全监视器)
- **寄存器**: ICC_IAR0_EL1, ICC_EOIR0_EL1

### 9.3 虚拟中断
- **vIRQ**: 虚拟IRQ，用于VM
- **vFIQ**: 虚拟FIQ，用于VM
- **维护中断**: Hypervisor管理事件

### 9.4 中断路由决策

| 中断组 | EL0 | EL1 (S) | EL1 (NS) | EL2 | EL3 |
|--------|-----|---------|----------|-----|-----|
| Group 0 | FIQ | FIQ | FIQ | FIQ | FIQ |
| Group 1 Secure | IRQ | IRQ | FIQ | - | IRQ |
| Group 1 NS | - | IRQ | IRQ | IRQ | - |

---

## 10. GIC接口规范

### 10.1 GICv3架构
OCPU中断控制器实现 GICv3架构的CPU接口部分，与Distributor配合工作。

### 10.2 与Distributor的交互
1. **中断设置**: Distributor通过AXI4-Stream发送SET_INT命令
2. **中断激活**: CPU接口确认中断，发送ACT命令
3. **中断结束**: CPU写EOIR寄存器，可能发送DIR命令
4. **SGI生成**: CPU接口支持软件生成中断

### 10.3 安全状态支持
- 支持安全和非安全状态切换
- SCR_EL3.NS位控制当前安全状态
- 独立的中断组使能控制

### 10.4 虚拟化支持
- EL2 Hypervisor可以控制虚拟中断
- 列表寄存器存储虚拟中断状态
- 维护中断通知Hypervisor需要介入

---

## 11. 时序和性能

### 11.1 时钟域划分
- **主时钟域**: clk - 系统寄存器访问
- **IC时钟域**: clk_ic - 中断处理逻辑
- **GICC时钟域**: clk_gicc_enable - GICC接口
- **AXI4-Stream时钟域**: clk_axi4sp - 与Distributor通信

### 11.2 关键时序
- 中断检测到输出: 2-3个时钟周期
- 寄存器访问延迟: 1-2个时钟周期
- AXI4-Stream传输: 取决于包长度

### 11.3 空闲状态
- 支持时钟门控降低功耗
- 空闲检测逻辑监控所有活动
- 自动唤醒响应中断或寄存器访问

---

## 12. 综合架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        ocpu_intctrl (顶层)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ SPR Control │  │   AON/时钟   │  │ AXI4-Stream │             │
│  │  u_spr_ctl  │  │   u_aon     │  │    I/F      │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                      │
│  ┌──────▼────────────────▼────────────────▼──────┐             │
│  │          Physical Interrupt I/F               │             │
│  │            (ocpu_ic_interface)                │             │
│  │  ┌─────────────┐      ┌─────────────┐         │             │
│  │  │  Priority   │      │  Priority   │         │             │
│  │  │  Encoder    │      │  Filter     │         │             │
│  │  └─────────────┘      └─────────────┘         │             │
│  └───────────────────────────────────────────────┘             │
│         ▲                ▲                ▲                     │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐             │
│  │ Virtual I/F │  │   IRQ/FIQ   │  │ Distributor │             │
│  │ u_vinterface│  │   Output    │  │  via AXI4S  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘

外部接口:
- CPU: nIRQ, nFIQ, nVIRQ, nVFIQ
- Distributor: AXI4-Stream (IRIT/ICCT)
- System: SPR access, Clock/Reset
```

---

## 13. 总结

OCPU中断控制器是一个完整的GICv3 CPU接口实现，具有以下特点：

1. **完整性**: 支持物理和虚拟中断，覆盖所有Exception Level
2. **安全性**: 完整的安全状态支持，独立的中断分组
3. **虚拟化**: 支持v8虚拟化扩展，适用于Hypervisor场景
4. **效率**: 多级时钟门控，优化的优先级编码
5. **兼容性**: 遵循 GICv3架构规范

该设计适用于需要完整中断控制功能的高性能处理器实现。

---

