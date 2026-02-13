# OCPU IEXECUTE 模块设计文档

## 文档信息
- **模块名称**: ocpu_iexecute (整数执行单元)
- **版本**: OCPU-RV64I-v1.0
- **生成日期**: 2026-02-12

---

## 目录
1. [概述](#概述)
2. [整体架构](#整体架构)
3. [模块详细分析](#模块详细分析)
4. [流水线设计](#流水线设计)
5. [结果前递](#结果前递)
6. [接口定义](#接口定义)

---

## 概述

### 设计目的
`ocpu_iexecute` 是 RISC-V OCPU 处理器核心的整数执行单元，负责执行所有整数运算指令，包括：
- 基本算术逻辑运算（ALU）
- 乘法和乘加运算（MAC）
- 整数除法运算
- CSR寄存器访问
- 条件分支判断

### 关键特性
- **双发射架构**: 支持 IX0 和 IX1 两个简单 ALU 并行执行
- **复杂运算单元**: 独立的 ALU2、MAC 和除法器
- **多级流水线**: 2-5 级可变深度流水线
- **结果前递**: 支持多周期结果前递到后续指令
- **功耗管理**: 支持时钟门控（Clock Gating）

---

## 整体架构

### 顶层结构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    ocpu_iexecute (顶层模块)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────┐ │
│  │  ocpu_    │  │  ocpu_    │  │  ocpu_    │  │   ocpu_mx_    │ │
│  │ ix_alu1   │  │ ix_alu1   │  │ mx_alu2   │  │     mac       │ │
│  │  (IX0)    │  │  (IX1)    │  │           │  │               │ │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └───────┬───────┘ │
│        │              │              │                │         │
│  ┌─────▼──────┬───────▼──────────────▼────────────────▼───────┐ │
│  │                    ocpu_ix_ctl (控制单元)                   │ │
│  │  - 指令分发  - 流水线控制  - 结果选择  - 时钟门控控制        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│        │              │              │                │         │
│  ┌─────▼─────┐  ┌────▼────┐  ┌──────▼─────┐  ┌───────▼────────┐│
│  │ocpu_ix_rb │  │ocpu_mx_ │  │  ocpu_mx_  │  │  ocpu_mx_csr   ││
│  │(结果缓冲) │  │  div    │  │    csr    │  │ (CSR寄存器)    ││
│  └───────────┘  └─────────┘  └────────────┘  └────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 执行单元结构

| 单元名称 | 模块 | 功能 | 延迟周期 |
|---------|------|------|---------|
| 简单 ALU0 | `ocpu_ix_alu1` (IX0) | 基本 ALU 运算 | 1 周期 |
| 简单 ALU1 | `ocpu_ix_alu1` (IX1) | 基本 ALU 运算 | 1 周期 |
| 复杂 ALU | `ocpu_mx_alu2` | 扩展 ALU 运算 | 2 周期 |
| 乘加单元 | `ocpu_mx_mac` | 乘法/乘加 | 2-5 周期 |
| 除法器 | `ocpu_mx_div` | 整数除法 | 可变 (4-64 周期) |
| CSR单元 | `ocpu_mx_csr` | CSR 访问 | 1-3 周期 |

---

## 模块详细分析

### 1. 顶层模块: ocpu_iexecute

#### 功能
- 整数字执行单元的顶层封装
- 实例化所有子模块并连接接口
- 处理来自 Issue 单元 (IS) 的指令分发
- 向其他单元输出执行结果

#### 主要接口信号

**Issue 接口 (输入)**
| 信号名 | 宽度 | 描述 |
|--------|------|------|
| `is_mx_issue_v_i1` | 1 | MX 指令有效 |
| `is_mx_uop_ctl_i1` | 27 | 微操作控制字 |
| `is_mx_srca_data_i2` | 64 | 源操作数 A |
| `is_mx_srcb_data_i2` | 64 | 源操作数 B |
| `is_mx_srcc_data_i2` | 64 | 源操作数 C |

**结果输出接口 (输出)**
| 信号名 | 宽度 | 描述 |
|--------|------|------|
| `mx_is_resx_data_w0` | 64 | 64位结果输出 |
| `mx_is_resx_data_v_w0` | 2 | 结果有效指示 |

**控制接口**
| 信号名 | 描述 |
|--------|------|
| `bx_flush` | 分支冲刷 |
| `ct_flush` | 上下文冲刷 |
| `ct_precommit_uid` | 预提交 UID |
| `ct_commit_uid` | 提交 UID |

### 2. 控制单元: ocpu_ix_ctl

#### 功能
- 指令分发和流水线控制
- 微操作解码 (`uop_ctl_dec`)
- 时钟门控生成
- 结果选择信号生成
- 除法/MAC 流水线跟踪

#### 微操作控制字段

```verilog
// MX UOP CTL 格式 (27位)
[26:25] DP_SEL       // 数据通路选择: 00=ALU1, 01=ALU2, 10=MAC, 11=CSR
[23:20] FUNCT3       // RISC-V funct3 字段
[19:17] FUNCT7       // RISC-V funct7 字段[6:4]
[16:15] UNIT         // 单元选择 (2C/4C/5C)
[14:12] OP           // 操作码
[11:0]  IMM          // 立即数
```

#### 数据通路选择
| DP_SEL | 目标单元 | 说明 |
|--------|---------|------|
| 2'b00 | ALU1 (IX) | 简单 ALU 运算 |
| 2'b01 | ALU2 (MX) | 复杂 ALU 运算 |
| 2'b10 | MAC (MX) | 乘加/除法 |
| 2'b11 | CSR (MX) | CSR寄存器访问 |

### 3. 简单 ALU: ocpu_ix_alu1

#### 功能
- 执行基本算术逻辑运算
- 支持 32/64 位数据宽度 (RV64I)
- 条件分支判断支持

#### 子模块结构
```
ocpu_ix_alu1
├── ocpu_ix_alu1_au    // 算术单元 (加减法)
├── ocpu_ix_alu1_shf   // 移位单元
├── ocpu_ix_alu1_cmp   // 比较单元
└── ocpu_ix_alu1_br    // 分支判断单元
```

#### 支持的运算类型

**算术运算 (AU)**
- ADD, SUB
- ADDI (立即数加法)
- 溢出检测

**逻辑运算 (LU)**
- AND, OR, XOR
- ANDI, ORI, XORI (立即数逻辑)

**移位操作 (SHF)**
- SLL, SRL, SRA (寄存器移位)
- SLLI, SRLI, SRAI (立即数移位)

**比较操作 (CMP)**
- SLT, SLTU (有符号/无符号比较)
- SLTI, SLTIU (立即数比较)

**分支判断 (BR)**
- BEQ, BNE, BLT, BGE, BLTU, BGEU
- JAL, JALR

#### 流水线阶段
| 阶段 | 名称 | 功能 |
|------|------|------|
| I2 | Issue | 指令接收，操作数选择 |
| E1 | Execute | 运算执行，结果生成 |

### 4. 复杂 ALU: ocpu_mx_alu2

#### 功能
- 扩展 ALU 功能
- 复杂移位操作
- LUI/AUIPC 立即数生成

#### 子模块结构
```
ocpu_mx_alu2
├── ocpu_mx_alu2_au       // 算术单元
├── ocpu_mx_alu2_shf      // 移位单元
├── ocpu_mx_alu2_imm      // 立即数生成单元
└── ocpu_mx_alu2_lui      // LUI/AUIPC处理
```

#### 流水线阶段
| 阶段 | 名称 | 功能 |
|------|------|------|
| I2 | Issue | 指令接收 |
| E1 | Execute Stage 1 | 初步运算 |
| E2 | Execute Stage 2 | 最终运算 |
| W0 | Writeback | 结果写回 |

### 5. 乘加单元: ocpu_mx_mac

#### 功能
- 整数乘法 (MUL, MULH, MULHU, MULHSU)
- 除法 (DIV, DIVU)
- 取余 (REM, REMU)
- 64x64位乘法

#### 子模块结构
```
ocpu_mx_mac
├── ocpu_mx_mac_benc      // Booth 编码器
├── ocpu_mx_mac_bmux      // Booth 多路选择器
├── ocpu_mx_mac_8to2      // 8-2 压缩树
├── ocpu_mx_mac_9to2      // 9-2 压缩树
└── ocpu_mx_mac_div       // 除法单元
```

#### 乘法器架构

**Booth 编码**
- 使用改进的 Booth-2 编码
- 16 个部分积生成器
- 支持有符号/无符号乘法

**压缩树结构**
- 华莱士树 (Wallace Tree) 压缩
- 8-2 压缩器处理主要部分积
- 最终加法产生结果

**支持的运算延迟**
| 运算类型 | 延迟周期 | 说明 |
|---------|---------|------|
| 32x32 乘法 | 2 周期 | 单周期 Booth + 压缩 |
| 64x64 乘法 (低64位) | 2 周期 | MUL 指令 |
| 64x64 乘法 (完整) | 3-5 周期 | 多遍计算 |
| 除法 | 4-64 周期 | 迭代除法 |

#### 流水线阶段
| 阶段 | 功能 |
|------|------|
| I2 | 指令接收，操作数准备 |
| 0E1 | Booth 编码，部分积生成 |
| 1E1 | 压缩树第一阶段 |
| 2E1 | 压缩树第二阶段 (64位乘法) |
| 3E1 | 最终加法 (可选) |
| E2 | 结果格式化 |
| W1 | 结果写回 |

### 6. 除法器: ocpu_mx_div

#### 功能
- 32/64 位有符号/无符号除法
- 基于 SRT 算法的迭代除法
- 除零检测
- 溢出检测

#### 子模块结构
```
ocpu_mx_div
├── ocpu_mx_div_clz64     // 前导零计数 (64位)
├── ocpu_mx_div_lsh64     // 左移归一化
├── ocpu_mx_div_rsh64     // 右移结果
├── ocpu_mx_div_pow2      // 2的幂检测
└── ocpu_mx_div_qbit      // 商位生成
```

#### 算法描述

**除法算法步骤**
1. **归一化**: 计算被除数和除数的前导零，左移对齐
2. **迭代**: 每轮迭代产生 4 位商 (Radix-16 SRT)
3. **余数调整**: 根据最终余数符号调整商
4. **结果格式化**: 处理符号，检测溢出

**快速路径**
- 除数为 0: 立即返回特殊结果
- 除数为 2^n: 使用移位代替迭代
- 被除数 < 除数: 直接返回 0

#### 除法周期数
| 操作类型 | 典型周期数 | 最坏周期数 |
|---------|-----------|-----------|
| 32位除法 | 4-12 | 16 |
| 64位除法 | 8-20 | 32 |

### 7. CSR寄存器单元: ocpu_mx_csr

#### 功能
- CSR (控制和状态寄存器) 读写
- 访问权限检查
- 多周期 CSR 操作协调
- 异常状态处理

#### 子模块结构
```
ocpu_mx_csr
├── ocpu_mx_csr_regs      // CSR寄存器组
├── ocpu_mx_csr_exc       // 异常处理
├── ocpu_mx_csr_priv      // 权限检查
├── ocpu_mx_csr_nonpipe   // 非流水线操作
└── ocpu_mx_csr_revid     // 版本 ID
```

#### CSR 访问类型
| 类型 | 延迟 | 说明 |
|------|------|------|
| 本地读取 | 1 周期 | 内部寄存器 |
| 本地写入 | 1 周期 | 内部寄存器 |
| 远程读取 | 2-3 周期 | 访问其他单元 |
| 远程写入 | 2-3 周期 | 访问其他单元 |
| 非流水线 | 可变 | 需要同步的操作 |

#### 支持的CSR指令
- CSRRW (CSR读写)
- CSRRS (CSR置位)
- CSRRC (CSR清零)
- CSRRWI (立即数CSR读写)
- CSRRSI (立即数CSR置位)
- CSRRCI (立即数CSR清零)

### 8. 结果缓冲区: ocpu_ix_rb

#### 功能
- 收集所有执行单元的结果
- 结果前递选择
- 存储数据格式化

#### 结果选择逻辑
```verilog
// 结果选择解码
mx_resx_sel_dec8_lo_w0 = {
    ALU1_LU,    // 000: ALU1 逻辑单元
    ALU1_AU,    // 001: ALU1 算术单元  
    ALU1_OT,    // 010: ALU1 其他
    ALU2,       // 011: ALU2
    MAC,        // 100: MAC
    DIV,        // 101: 除法器
    CSR,        // 110: CSR访问
    RESERVED    // 111: 保留
}
```

---

## 流水线设计

### 流水线阶段定义

```
时钟周期:  |    T0    |    T1    |    T2    |    T3    |    T4    |    T5    |
           |          |          |          |          |          |          |
简单 ALU:  |   I1/I2  |    E1    |    W0    |          |          |          |
复杂 ALU:  |   I1/I2  |    E1    |    E2    |    W0    |          |          |
MAC(2c):   |   I1/I2  |   0E1    |    E2    |    W1    |          |          |
MAC(4c):   |   I1/I2  |   0E1    |   1E1    |   2E1    |    E2    |    W1    |
除法:      |   I1/I2  |    E1    |    E2    |   XE3... |    E4    |    W1    |
```

### 流水线寄存器命名

| 后缀 | 含义 |
|------|------|
| `_i1` | Issue 阶段 1 (来自 IS 单元) |
| `_i2` | Issue 阶段 2 (进入执行单元) |
| `_e1` | Execute 阶段 1 |
| `_e2` | Execute 阶段 2 |
| `_xe3`| Execute 扩展阶段 (迭代) |
| `_e4` | Execute 阶段 4 (除法结束) |
| `_w0` | Writeback 阶段 0 (单周期) |
| `_w1` | Writeback 阶段 1 (多周期) |

### 流水线控制

#### 流水线使能信号
```verilog
// 来自 ocpu_ix_ctl
ix0_issue_ctl_en = is_ix_issue_v_ix0_spec_i1 | ix0_issue_v_i2 | ix0_issue_v_e1_q | ix0_stid_v_i2;
ix1_issue_ctl_en = is_ix_issue_v_ix1_spec_i1 | ix1_issue_v_i2 | ix1_issue_v_e1_q | ix1_stid_v_i2;
mx_issue_ctl_en  = is_mx_issue_v_spec_i1 | mx_issue_v_i2 | mx_issue_v_e1_q | mx_stid_v_i2;
```

#### 取消信号传播
```verilog
// 指令取消在 E1 阶段生效
ix0_issue_v_e1 = ix0_issue_v_e1_q & ~ix0_issue_cancel_e1;
ix1_issue_v_e1 = ix1_issue_v_e1_q & ~ix1_issue_cancel_e1;
mx_issue_v_e1  = mx_issue_v_e1_q & ~mx_issue_cancel_e1;
```

---

## 结果前递

### 前递架构

```
                          ┌──────────────────────────────────────┐
                          │         ocpu_ix_rb (结果缓冲)         │
┌─────────────────────────┼──────────────────────────────────────┤
│                         │                                      │
│  IX0 ALU1 ──────────────┼─► LU/AU/OT 结果 ────┐                │
│                         │                      │                │
│  IX1 ALU1 ──────────────┼─► LU/AU/OT 结果 ────┤                │
│                         │                      │                │
│  MX ALU1 ───────────────┼─► LU/AU/OT 结果 ────┼──► 结果选择器   │
│                         │                      │    (8选1)      │
│  MX ALU2 ───────────────┼─► 结果 ─────────────┤                │
│                         │                      │                │
│  MX MAC ────────────────┼─► 结果 (W1) ────────┤                │
│                         │                      │                │
│  MX DIV ────────────────┼─► 结果 (W1) ────────┘                │
│                         │                                      │
│  MX CSR ────────────────┼─► mx_csr_rd_data                     │
│                         │                                      │
└─────────────────────────┼──────────────────────────────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │ mx_is_resx_ │
                    │ data_w0     │
                    └─────────────┘
```

### 结果选择解码

```verilog
// 定义在 ocpu_ix_defines.sv
`define OCPU_MX_RES_SEL_DEC8_ALU1_LU   8'b00000001  // ALU1 逻辑单元
`define OCPU_MX_RES_SEL_DEC8_ALU1_AU   8'b00000010  // ALU1 算术单元
`define OCPU_MX_RES_SEL_DEC8_ALU1_OT   8'b00000100  // ALU1 其他
`define OCPU_MX_RES_SEL_DEC8_ALU2      8'b00001000  // ALU2
`define OCPU_MX_RES_SEL_DEC8_MAC       8'b00010000  // MAC
`define OCPU_MX_RES_SEL_DEC8_DIV       8'b00100000  // 除法器
`define OCPU_MX_RES_SEL_DEC8_CSR       8'b01000000  // CSR访问
`define OCPU_MX_RES_SEL_DEC8_RESERVED  8'b10000000  // 保留
```

### 存储数据前递

存储指令需要特殊的前递路径：
```verilog
// 存储数据选择
mx_ls_store_data_p0_e1 = 
    ix1_srca_data_e1 |      // 来自 IX1 ALU1
    mx_srca_data_e1 |       // 来自 MX ALU
    {ix1_srcb, ix1_srca};   // 双字拼接

mx_ls_store_data_p1_e1 = 
    mx_srca_data_e1 |
    mx_srcb_data_e1 |
    ix1_srcb_data_e1 |
    {mx_srcb, mx_srca};
```

---

## 时钟门控

### 时钟域划分

```
┌─────────────────────────────────────────┐
│              clk (主时钟)                │
└─────────────┬───────────────────────────┘
              │
    ┌─────────┴──────────┐
    ▼                    ▼
┌─────────┐       ┌─────────────┐
│clk_alu1 │       │  clk_mx     │
│ (ALU1)  │       │ (MAC/ALU2)  │
└─────────┘       └──────┬──────┘
                         │
                ┌────────┴────────┐
                ▼                 ▼
          ┌──────────┐       ┌──────────┐
          │clk_mx_csr│       │ 其他门控  │
          │(CSR访问) │       │          │
          └──────────┘       └──────────┘
```

### 时钟使能生成

```verilog
// ALU1 时钟使能
assign alu1_active_nxt = chka_dis_ix_rcg_q
                       | is_ix_issue_v_ix0_spec_i1
                       | is_ix_issue_v_ix1_spec_i1
                       | is_mx_issue_v_spec_i1;

// MX 时钟使能  
assign mx_active_nxt = chka_dis_ix_rcg_q
                     | is_mx_issue_v_spec_i1
                     | mx_issue_v_i2
                     | (mx_issue_v_e1 & ~mx_latency_e1[1])
                     | mx_active_mac_div
                     | mx_csr_q_flag_wr_pending;
```

---

## 接口定义

### 与 Issue 单元接口 (IS-IX)

```verilog
// Issue 握手
input  wire         is_mx_issue_v_i1;        // 指令有效
input  wire [26:0]  is_mx_uop_ctl_i1;        // 微操作控制
input  wire         is_mx_issue_v_spec_i1;   // 推测性 Issue

// 操作数输入
input  wire [63:0]  is_mx_srca_data_i2;
input  wire [63:0]  is_mx_srcb_data_i2;
input  wire [63:0]  is_mx_srcc_data_i2;

// 结果输出
output wire [1:0]   mx_is_resx_data_v_w0;    // 结果有效
output wire [63:0]  mx_is_resx_data_w0;      // 64位结果
```

### 与 Load/Store 单元接口 (IX-LS)

```verilog
// 存储数据输出
output wire [1:0]   mx_ls_store_data_v_p0_e1;
output wire [1:0]   mx_ls_store_data_v_p1_e1;
output wire [63:0]  mx_ls_store_data_p0_e1;
output wire [63:0]  mx_ls_store_data_p1_e1;

// 存储 ID
output wire         mx_ls_int_stid_v_p0_i1;
output wire         mx_ls_int_stid_v_p1_i1;
output wire [4:0]   mx_ls_int_stid_p0_i1;
output wire [4:0]   mx_ls_int_stid_p1_i1;
```

### 与上下文控制接口 (IX-CT)

```verilog
// 上下文状态
input  wire [1:0]   ct_priv_mode;            // 特权模式
input  wire         ct_mstatus_mie;          // 全局中断使能
input  wire         ct_mstatus_mpie;         // 之前中断使能

// 冲刷信号
input  wire         ct_flush;
input  wire [7:0]   ct_flush_uid;
input  wire         ct_ia_restart;

// CSR 相关输出
output wire [63:0]  mx_ct_mepc;              // 异常PC
output wire [63:0]  mx_ct_mtvec;             // 异常向量基址
output wire         mx_ct_csr_idle;
```

---

## 文件列表

### 核心文件 (Core Files)
| 文件名 | 描述 |
|--------|------|
| `ocpu_iexecute.sv` | 顶层模块 |
| `ocpu_ix_ctl.sv` | 控制单元 |
| `ocpu_ix_rb.sv` | 结果缓冲区 |
| `ocpu_ix_defines.sv` | 宏定义 |
| `ocpu_ix_params.sv` | 参数定义 |

### ALU 相关文件
| 文件名 | 描述 |
|--------|------|
| `ocpu_ix_alu1.sv` | 简单 ALU |
| `ocpu_ix_alu1_au.sv` | 算术单元 |
| `ocpu_ix_alu1_shf.sv` | 移位单元 |
| `ocpu_ix_alu1_cmp.sv` | 比较单元 |
| `ocpu_ix_alu1_br.sv` | 分支判断单元 |
| `ocpu_mx_alu2.sv` | 复杂 ALU |
| `ocpu_mx_alu2_imm.sv` | 立即数生成单元 |
| `ocpu_mx_alu2_lui.sv` | LUI/AUIPC处理 |

### MAC 相关文件
| 文件名 | 描述 |
|--------|------|
| `ocpu_mx_mac.sv` | 乘加单元 |
| `ocpu_mx_mac_benc.sv` | Booth 编码器 |
| `ocpu_mx_mac_bmux.sv` | Booth 多路选择器 |
| `ocpu_mx_mac_8to2.sv` | 8-2 压缩树 |
| `ocpu_mx_mac_9to2.sv` | 9-2 压缩树 |
| `ocpu_mx_mac_6to2.sv` | 6-2 压缩树 |

### 除法器相关文件
| 文件名 | 描述 |
|--------|------|
| `ocpu_mx_div.sv` | 除法器主模块 |
| `ocpu_mx_div_clz64.sv` | 前导零计数 |
| `ocpu_mx_div_lsh64.sv` | 左移单元 |
| `ocpu_mx_div_rsh64.sv` | 右移单元 |
| `ocpu_mx_div_pow2.sv` | 2的幂检测 |
| `ocpu_mx_div_qbit.sv` | 商位生成 |

### CSR 相关文件
| 文件名 | 描述 |
|--------|------|
| `ocpu_mx_csr.sv` | CSR主模块 |
| `ocpu_mx_csr_regs.sv` | CSR寄存器组 |
| `ocpu_mx_csr_exc.sv` | 异常处理 |
| `ocpu_mx_csr_priv.sv` | 权限检查 |
| `ocpu_mx_csr_nonpipe.sv` | 非流水线操作 |
| `ocpu_mx_csr_revid.sv` | 版本 ID |

### 解码器文件
| 文件名 | 描述 |
|--------|------|
| `ocpu_ix_uop_ctl_dec.sv` | IX UOP 解码 |
| `ocpu_mx_uop_ctl_dec.sv` | MX UOP 解码 |
| `ocpu_mx_alu2_uop_ctl_dec.sv` | ALU2 UOP 解码 |
| `ocpu_mx_mac_uop_ctl_dec.sv` | MAC UOP 解码 |
| `ocpu_mx_csr_uop_ctl_dec.sv` | CSR UOP 解码 |

### 其他
| 文件名 | 描述 |
|--------|------|
| `ocpu_ix_ela.sv` | ELA (Embedded Logic Analyzer) 接口 |

---

## 总结

OCPU IEXECUTE 模块是一个高性能、多功能的整数执行单元，具有以下特点：

1. **高性能执行**: 双简单 ALU + 复杂 ALU + MAC + 除法器的多单元架构
2. **灵活流水线**: 支持 1-5 周期的可变深度流水线
3. **高效前递**: 8 路结果选择器支持快速数据前递
4. **功耗优化**: 细粒度时钟门控降低动态功耗
5. **完整功能**: 支持 RISC-V RV64I 架构的所有整数运算指令

---

*文档结束*
