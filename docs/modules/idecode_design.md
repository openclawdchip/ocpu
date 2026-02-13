# OCPU 指令解码模块 (ocpu_idecode) 设计文档

## 目录
1. [概述](#1-概述)
2. [整体架构](#2-整体架构)
3. [顶层模块 (ocpu_idecode)](#3-顶层模块-ocpu_idecode)
4. [子模块详细设计](#4-子模块详细设计)
5. [解码流水线](#5-解码流水线)
6. [指令类型处理](#6-指令类型处理)
7. [微码生成](#7-微码生成)
8. [接口说明](#8-接口说明)
9. [ELA (Embedded Logic Analyzer)](#9-ela-embedded-logic-analyzer)

---

## 1. 概述

### 1.1 设计目的

`ocpu_idecode` 是 RISC-V RV64I 处理器架构中的**指令解码单元**，位于取指单元 (IFU) 和重命名单元 (Rename) 之间。其主要功能包括：

- **指令解码**: 将原始指令字节流解码为可执行的微操作 (MOP)
- **指令分类**: 识别指令类型 (ALU、分支、访存、系统指令等)
- **微码生成**: 将复杂指令拆分为多个微操作序列
- **指令队列管理**: 管理解码队列 (Decode Queue) 的读写控制
- **异常处理**: 检测预解码错误和指令异常

### 1.2 支持特性

| 特性 | 说明 |
|------|------|
| 指令集 | RISC-V RV64I (基础整数指令集) |
| 解码宽度 | 每周期最多4条指令并行解码 |
| 微操作类型 | ALU、分支、访存、系统指令 |
| 指令长度 | 32位定长指令 |
| 融合指令 | 支持指令融合优化 |

---

## 2. 整体架构

### 2.1 模块层次结构

```
ocpu_idecode (顶层)
│
├── ocpu_id_params.sv          # 参数定义
│
├── ocpu_id_dq.sv              # 解码队列 (Decode Queue)
│   ├── ocpu_id_dq_ctl.sv      # 解码队列控制器
│   └── ocpu_id_dq_bank.sv     # 解码队列存储体 (4个bank)
│
├── ocpu_id_inst_align.sv      # 指令对齐单元
│
├── ocpu_id_inst_steer.sv      # 指令分发/导向单元
│   └── ocpu_id_inst_class.sv  # 指令分类器
│   └── ocpu_id_inst_regcnt.sv # 寄存器计数器
│
├── ocpu_id_mop.sv             # 微操作生成器
│   └── ocpu_id_mop_lane.sv    # 单lane微操作生成 (4个实例)
│       └── ocpu_id_mop_dec.sv # RV64I 指令解码
│           ├── ocpu_id_mop_dec_fs.sv    # 第一级解码
│           ├── ocpu_id_mop_dec_alu.sv   # ALU指令解码
│           ├── ocpu_id_mop_dec_br.sv    # 分支指令解码
│           ├── ocpu_id_mop_dec_ls.sv    # 访存指令解码
│           ├── ocpu_id_mop_dec_sys.sv   # 系统指令解码
│           └── ocpu_id_mop_dec_mopcnt.sv # MOP计数
│
├── ocpu_id_mop_patch.sv       # 微操作patch单元
├── ocpu_id_mop_fuse.sv        # 指令融合单元
│
├── ocpu_id_estate.sv          # 执行状态管理
│   └── ocpu_id_mop_csr.sv     # CSR寄存器访问
│
└── ocpu_id_ela.sv             # 嵌入式逻辑分析器接口
```

### 2.2 数据流

```
┌─────────────────────────────────────────────────────────────────┐
│                         取指单元 (IFU)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    解码队列 (DQ - ocpu_id_dq)                     │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│  │ Bank 0  │ │ Bank 1  │ │ Bank 2  │ │ Bank 3  │                │
│  │ (32b)   │ │ (32b)   │ │ (32b)   │ │ (32b)   │                │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              指令对齐 (Inst Align - ocpu_id_inst_align)           │
│         将32位指令流对齐为可解码的指令包                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              指令分类 (Inst Class - ocpu_id_inst_class)           │
│         识别指令类型: ALU/Branch/LS/Sys                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              指令分发 (Inst Steer - ocpu_id_inst_steer)           │
│         将指令分发到4个解码lane                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               微操作生成 (MOP Gen - ocpu_id_mop)                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│  │ Lane 0  │ │ Lane 1  │ │ Lane 2  │ │ Lane 3  │                │
│  │ (MOP)   │ │ (MOP)   │ │ (MOP)   │ │ (MOP)   │                │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      重命名单元 (Rename)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 顶层模块 (ocpu_idecode)

### 3.1 模块参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `ELA` | 0 | 嵌入式逻辑分析器使能 |

### 3.2 主要接口

#### 3.2.1 时钟与复位
```systemverilog
input wire clk;              // 系统时钟
input wire reset;            // 异步复位
input wire cb_dftcgen;       // DFT时钟门控
```

#### 3.2.2 来自取指单元的输入 (IF → ID)

**Bank输入 (4个bank，每个bank包含32-bit指令)**

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| `if_id_bankX_wrptr_f2` | [2:0] | Bank写指针 |
| `if_id_bankX_vld_f2` | 1 | 指令有效位 |
| `if_id_bankX_opc_f2` | [31:0] | 操作码 (32b) |
| `if_id_bankX_pcoffset_f2` | [4:2] | PC偏移量 |
| `if_id_bankX_eob_f2` | 1 | End-of-Block标记 |
| `if_id_bankX_sor_f2` | 1 | Start-of-Region标记 |
| `if_id_bankX_pt_f2` | 1 | 预测跳转标记 |

**控制信号**
- `if_id_ia_cancel_f3`: 指令取消信号
- `if_id_term_vld_f2`: 终止标记有效
- `if_id_term_type_f2`[3:0]: 终止类型

#### 3.2.3 输出到重命名单元 (ID → RN)

**M0-M3 四组微操作输出 (每 lane 独立)**

| 信号组 | 位宽 | 说明 |
|--------|------|------|
| `id_rn_mX_mop_vld_rr` | 1 | MOP有效 |
| `id_rn_mX_frc_nop_rr` | 1 | 强制NOP |
| `id_rn_mX_frc_undef_rr` | 1 | 未定义指令异常 |
| `id_rn_mX_is_branch_rr` | 1 | 分支指令标记 |
| `id_rn_mX_dst0/dst1_*` | 多位 | 目的寄存器信息 |
| `id_rn_mX_src0/src1/src2_*` | 多位 | 源寄存器信息 |
| `id_rn_mX_iq_ctl_rr` | [38:0] | 发射队列控制 |
| `id_rn_mX_pcoffset_rr` | [4:1] | PC偏移 |

### 3.3 内部互联

顶层模块实例化了以下核心子模块：

```systemverilog
// 解码队列
ocpu_id_dq u_dq ( ... );

// 指令对齐
ocpu_id_inst_align u_inst_align ( ... );

// 指令分发
ocpu_id_inst_steer u_inst_steer ( ... );

// 微操作生成 (4个lane)
ocpu_id_mop u_mop ( ... );

// 执行状态
ocpu_id_estate u_estate ( ... );

// ELA接口
ocpu_id_ela u_ela ( ... );
```

---

## 4. 子模块详细设计

### 4.1 解码队列 (ocpu_id_dq)

#### 4.1.1 功能描述

解码队列是连接取指单元和指令解码单元的缓冲区，由4个独立的bank组成：

```
┌────────────────────────────────────────────────────────────┐
│                     Decode Queue (DQ)                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    DQ Controller                        │  │
│  │              (ocpu_id_dq_ctl.sv)                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │ Bank 0  │  │ Bank 1  │  │ Bank 2  │  │ Bank 3  │       │
│  │ 8x32b   │  │ 8x32b   │  │ 8x32b   │  │ 8x32b   │       │
│  │ RAM     │  │ RAM     │  │ RAM     │  │ RAM     │       │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │
└────────────────────────────────────────────────────────────┘
```

#### 4.1.2 关键信号

**输入信号**
- `if_id_bankX_*`: 来自IFU的bank写入数据
- `ia_ps_empty`: 指令对齐流水线空
- `inst_align_consume_hwcnt_ia0`: 指令对齐消耗计数

**输出信号**
- `rd_hwdataX_vld_ia/ia0`: 读数据有效
- `rd_hwdataX_opc_ia`: 操作码输出
- `id_if_dq_stall_ia`: 向IFU发送的stall信号

#### 4.1.3 读指针控制

```systemverilog
// 每个bank有独立的读指针
bank0_rdptr_ia[2:0]      // 数据读指针
bank0_ctrl_rdptr_ia      // 控制读指针
```

### 4.2 指令对齐 (ocpu_id_inst_align)

#### 4.2.1 功能描述

指令对齐模块负责：
1. 从解码队列读取原始32位指令数据
2. 将指令流打包成完整的指令
3. 处理跨bank的指令边界
4. 生成指令分类信息

#### 4.2.2 数据结构

```systemverilog
// 输出指令结构 (4条并行输出)
inst0_vld_ia           // 指令有效
inst0_class_ia[4:0]    // 指令分类
inst0_bytes_ia[31:0]   // 指令字节
inst0_pcoffset_ia[4:1] // PC偏移
inst0_eob_ia           // End-of-Block
inst0_sor_ia           // Start-of-Region
inst0_pt_ia            // Predicted Taken
inst0_mop_cnt_ia[1:0]  // 微操作计数
```

#### 4.2.3 指令分类编码

| inst_class[4:0] | 类型 | 说明 |
|-----------------|------|------|
| 5'b00001 | ALU/reg | ALU/寄存器操作 |
| 5'b00010 | ALU/imm | ALU/立即数操作 |
| 5'b00100 | Branch | 分支指令 |
| 5'b01000 | Load/Store | 访存指令 |
| 5'b10000 | System | 系统指令 |

### 4.3 指令分类器 (ocpu_id_inst_class)

#### 4.3.1 功能描述

纯组合逻辑模块，根据指令编码生成分类信息。

#### 4.3.2 RISC-V 指令分类逻辑

```systemverilog
// RISC-V RV64I 操作码字段 (opcode[6:0])
localparam OP_LUI    = 7'b0110111;  // LUI
localparam OP_AUIPC  = 7'b0010111;  // AUIPC
localparam OP_JAL    = 7'b1101111;  // JAL
localparam OP_JALR   = 7'b1100111;  // JALR
localparam OP_BRANCH = 7'b1100011;  // Branch
localparam OP_LOAD   = 7'b0000011;  // Load
localparam OP_STORE  = 7'b0100011;  // Store
localparam OP_ALUI   = 7'b0010011;  // ALU Immediate
localparam OP_ALU    = 7'b0110011;  // ALU Register
localparam OP_SYSTEM = 7'b1110011;  // System

// ALU/imm 分类 (inst_class[0])
assign inst_class[0] = 
    (opcode == OP_ALUI) | 
    (opcode == OP_LUI) |
    (opcode == OP_AUIPC);

// Branch 分类 (inst_class[2])
assign inst_class[2] = 
    (opcode == OP_BRANCH) |
    (opcode == OP_JAL) |
    (opcode == OP_JALR);

// Load/Store 分类 (inst_class[3])
assign inst_class[3] = 
    (opcode == OP_LOAD) |
    (opcode == OP_STORE);

// System 分类 (inst_class[4])
assign inst_class[4] = 
    (opcode == OP_SYSTEM);
```

### 4.4 指令分发 (ocpu_id_inst_steer)

#### 4.4.1 功能描述

将指令对齐后的4条指令分发到4个解码lane，处理：
- 指令间依赖检测
- 异常指令标记

#### 4.4.2 输出结构

每个lane输出完整的指令信息：

```systemverilog
// Lane 0 输出示例
lane0_vld_de              // 有效
lane0_class_de[4:0]       // 分类
lane0_opc_de[31:0]        // 操作码
lane0_sideband_de[3:0]    // 边带信息
lane0_mop_cnt_de[1:0]     // MOP计数
lane0_mop_num_de[4:0]     // MOP编号
lane0_br_*_de             // 分支指令字段
lane0_alu_*_de            // ALU指令字段
lane0_ls_*_de             // 访存指令字段
lane0_sys_*_de            // 系统指令字段
```

---

## 5. 解码流水线

### 5.1 流水线阶段

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│   F2    │ → │   F3    │ → │   IA    │ → │   DE    │ →  RR
│ (Fetch) │   │ (Queue) │   │ (Align) │   │ (Decode)│    (Rename)
└─────────┘   └─────────┘   └─────────┘   └─────────┘
     │             │             │             │
   Bank         Ctrl        Inst         MOP
   Write       Logic        Align        Gen
```

### 5.2 各阶段功能

| 阶段 | 模块 | 功能 |
|------|------|------|
| F2 | IFU/DQ | 取指单元将指令写入DQ |
| F3 | DQ CTL | 解码队列控制，管理读写指针 |
| IA | Inst Align | 指令对齐，打包32位指令 |
| DE | Inst Steer/MOP | 指令分发，生成微操作 |
| RR | MOP Lane | MOP寄存器化输出到Rename |

### 5.3 流水线控制

```systemverilog
// 流水线stall逻辑
assign stall_de = rn_id_stall_rr & (any_mop_vld_rr | rn_id_patch_active_rr);

// 指令消耗计数
assign inst_steer_consume_cnt_ia = 
    inst0_vld + inst1_vld + inst2_vld + inst3_vld;
```

---

## 6. 指令类型处理

### 6.1 RV64I 指令处理

#### 6.1.1 模块结构

```
ocpu_id_mop_dec
├── ocpu_id_mop_dec_fs     # First Stage: 通用解码
├── ocpu_id_mop_dec_alu    # ALU指令解码
├── ocpu_id_mop_dec_br     # 分支指令解码
├── ocpu_id_mop_dec_ls     # 访存指令解码
├── ocpu_id_mop_dec_sys    # 系统指令解码
└── ocpu_id_mop_dec_mopcnt # MOP计数器
```

#### 6.1.2 RISC-V 指令格式

```systemverilog
// R-Type (Register)
// funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0]

// I-Type (Immediate)
// imm[31:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0]

// S-Type (Store)
// imm[11:5][31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | imm[4:0][11:7] | opcode[6:0]

// B-Type (Branch)
// imm[12|10:5][31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | imm[4:1|11][11:7] | opcode[6:0]

// U-Type (Upper immediate)
// imm[31:12][31:12] | rd[11:7] | opcode[6:0]

// J-Type (Jump)
// imm[20|10:1|11|19:12][31:12] | rd[11:7] | opcode[6:0]
```

#### 6.1.3 关键解码逻辑

```systemverilog
// 目的寄存器选择 (rd字段)
assign gen_dst0[4:0] = 
    ({5{fs_sel}} & fs_gen_dst0) |
    ({5{alu_sel}} & alu_gen_dst0) |
    ({5{ls_sel}} & ls_gen_dst0);

// 源寄存器选择 (rs1字段)
assign gen_src0[4:0] = inst[19:15];

// 源寄存器2选择 (rs2字段)
assign gen_src1[4:0] = inst[24:20];
```

### 6.2 ALU指令解码

#### 6.2.1 指令分类处理

| 子模块 | 处理类型 | 说明 |
|--------|----------|------|
| `ocpu_id_mop_dec_alu` | ALU | 算术逻辑运算 |
| `ocpu_id_mop_dec_br` | Branch | 分支跳转 |
| `ocpu_id_mop_dec_ls` | Load/Store | 访存指令 |
| `ocpu_id_mop_dec_sys` | System | 系统/CSR指令 |

#### 6.2.2 ALU操作解码示例

```systemverilog
// ALU操作码解码 (基于funct3和funct7)
wire [2:0] funct3 = inst[14:12];
wire [6:0] funct7 = inst[31:25];

// 加法/减法
assign alu_op_add = (funct3 == 3'b000) & (funct7 == 7'b0000000);
assign alu_op_sub = (funct3 == 3'b000) & (funct7 == 7'b0100000);

// 逻辑运算
assign alu_op_and = (funct3 == 3'b111);
assign alu_op_or  = (funct3 == 3'b110);
assign alu_op_xor = (funct3 == 3'b100);

// 移位操作
assign alu_op_sll = (funct3 == 3'b001);
assign alu_op_srl = (funct3 == 3'b101) & (funct7 == 7'b0000000);
assign alu_op_sra = (funct3 == 3'b101) & (funct7 == 7'b0100000);

// 比较
assign alu_op_slt  = (funct3 == 3'b010);
assign alu_op_sltu = (funct3 == 3'b011);
```

### 6.3 分支指令处理

#### 6.3.1 分支目标计算

```systemverilog
// JAL目标计算
wire [31:0] jal_target = pc + {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

// JALR目标计算
wire [31:0] jalr_target = (rs1_value + {{20{inst[31]}}, inst[31:20]}) & ~32'b1;

// 条件分支目标
wire [31:0] br_target = pc + {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
```

#### 6.3.2 条件分支判断

```systemverilog
// 分支条件判断
wire beq  = (funct3 == 3'b000);  // 相等
wire bne  = (funct3 == 3'b001);  // 不等
wire blt  = (funct3 == 3'b100);  // 小于(有符号)
wire bge  = (funct3 == 3'b101);  // 大于等于(有符号)
wire bltu = (funct3 == 3'b110);  // 小于(无符号)
wire bgeu = (funct3 == 3'b111);  // 大于等于(无符号)
```

---

## 7. 微码生成

### 7.1 微操作结构

```systemverilog
// MOP控制字段 (39-bit iq_ctl)
struct iq_ctl {
    bit [3:0]  eu;           // 执行单元选择
    bit [2:0]  op_type;      // 操作类型
    bit [4:0]  alu_op;       // ALU操作码
    bit [1:0]  shift_type;   // 移位类型
    bit [5:0]  shift_amt;    // 移位量
    bit        set_flags;    // 更新标志位
    bit        use_imm;      // 使用立即数
    bit [31:0] imm;          // 立即数
    // ... 其他控制位
};
```

### 7.2 指令融合 (Fuse)

`ocpu_id_mop_fuse` 模块检测可融合的指令对：

```systemverilog
// 融合条件示例
assign fuse_lui_auipc = 
    (inst0_is_lui) && 
    (inst1_is_alui_add) && 
    (inst0_dst == inst1_src0) &&
    !inst1_src0_dep;

// 融合后的MOP
fused_parent_de   // 父指令标记
fused_child_de    // 子指令标记
```

### 7.3 MOP Lane 寄存器输出

```systemverilog
// DE → RR 流水线寄存器
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        mop_vld_rr_q <= 1'b0;
        iq_ctl_rr_q <= 39'b0;
        // ...
    end else if (mop_clken) begin
        mop_vld_rr_q <= mop_vld_de;
        iq_ctl_rr_q <= iq_ctl_de;
        // ...
    end
end
```

---

## 8. 接口说明

### 8.1 与取指单元接口 (IF-ID)

| 方向 | 信号名 | 位宽 | 说明 |
|------|--------|------|------|
| IF→ID | `if_id_bank*_wrptr_f2` | [2:0] | Bank写指针 |
| IF→ID | `if_id_bank*_vld_f2` | 1 | 指令有效 |
| IF→ID | `if_id_bank*_opc_f2` | [31:0] | 操作码数据 |
| ID→IF | `id_if_dq_stall_ia` | 1 | 解码队列满，请求stall |
| ID→IF | `id_if_pdec_err_*` | - | 预解码错误报告 |

### 8.2 与重命名单元接口 (ID-RN)

| 方向 | 信号名 | 位宽 | 说明 |
|------|--------|------|------|
| RN→ID | `rn_id_stall_rr` | 1 | Rename请求stall |
| RN→ID | `rn_id_clear_mX_rr` | 1 | 清除MOP |
| ID→RN | `id_rn_mX_mop_vld_rr` | 1 | MOP有效 |
| ID→RN | `id_rn_mX_iq_ctl_rr` | [38:0] | 发射队列控制 |
| ID→RN | `id_rn_mX_gen_dst0_rr` | [4:0] | 通用目的寄存器0 |
| ID→RN | `id_rn_mX_gen_src0_rr` | [4:0] | 通用源寄存器0 |

### 8.3 与控制单元接口 (ID-CT)

| 方向 | 信号名 | 位宽 | 说明 |
|------|--------|------|------|
| CT→ID | `ct_flush` | 1 | 流水线flush |
| CT→ID | `ct_priv_mode` | [1:0] | 特权模式 |
| ID→CT | `id_ct_mX_mop_vld_rr` | 1 | MOP有效 |
| ID→CT | `id_ct_mX_except_rr` | [3:0] | 异常类型 |

---

## 9. ELA (Embedded Logic Analyzer)

### 9.1 ELA接口模块 (ocpu_id_ela)

#### 9.1.1 探针信号

```systemverilog
// 组合ELA信号 (来自各子模块)
assign align_ela[24:0]    // 指令对齐ELA
assign dq_ela[69:0]       // 解码队列ELA  
assign steer_ela[84:0]    // 指令分发ELA
assign pdec_ela[4:0]      // 预解码ELA
assign mop_ela[27:0]      // MOP生成ELA
```

#### 9.1.2 ELA输出

```systemverilog
output wire [`OCPU_ID_ELA_WIDTH-1:0] id_ela
```

---

## 10. 处理文件统计

本次分析共处理 **30** 个 SystemVerilog 文件：

### 10.1 文件列表

| 序号 | 文件名 | 功能描述 |
|------|--------|----------|
| 1 | ocpu_idecode.sv | 顶层模块 |
| 2 | ocpu_id_params.sv | 参数定义 |
| 3 | ocpu_id_dq.sv | 解码队列顶层 |
| 4 | ocpu_id_dq_bank.sv | 解码队列存储体 |
| 5 | ocpu_id_dq_ctl.sv | 解码队列控制器 |
| 6 | ocpu_id_inst_align.sv | 指令对齐 |
| 7 | ocpu_id_inst_class.sv | 指令分类器 |
| 8 | ocpu_id_inst_regcnt.sv | 寄存器计数 |
| 9 | ocpu_id_inst_steer.sv | 指令分发 |
| 10 | ocpu_id_mop.sv | MOP生成器顶层 |
| 11 | ocpu_id_mop_lane.sv | MOP单lane生成 |
| 12 | ocpu_id_mop_fuse.sv | 指令融合 |
| 13 | ocpu_id_mop_patch.sv | MOP Patch |
| 14 | ocpu_id_mop_dec.sv | RV64I MOP生成 |
| 15 | ocpu_id_mop_dec_fs.sv | DEC First Stage |
| 16 | ocpu_id_mop_dec_alu.sv | ALU指令解码 |
| 17 | ocpu_id_mop_dec_br.sv | 分支指令解码 |
| 18 | ocpu_id_mop_dec_ls.sv | 访存指令解码 |
| 19 | ocpu_id_mop_dec_sys.sv | 系统指令解码 |
| 20 | ocpu_id_mop_dec_mopcnt.sv | DEC MOP计数 |
| 21-25 | ocpu_id_mop_dec_*_iqctl*.sv | IQ控制子模块 |
| 26 | ocpu_id_mop_csr.sv | CSR寄存器访问 |
| 27 | ocpu_id_estate.sv | 执行状态管理 |
| 28 | ocpu_id_ela.sv | ELA接口 |

---

## 11. 设计特点总结

### 11.1 关键特性

1. **并行解码**: 4-wide指令解码，每周期最多处理4条指令
2. **RISC-V RV64I支持**: 完整支持RISC-V 64位基础整数指令集
3. **定长指令**: 32位定长指令简化解码逻辑
4. **指令融合**: 检测并融合常见指令序列
5. **异常检测**: 早期检测未定义指令和异常条件

### 11.2 性能特征

| 指标 | 数值 |
|------|------|
| 解码宽度 | 4条指令/周期 |
| 解码队列 | 4 Bank x 8 Entry x 32-bit |
| MOP延迟 | 2-3周期 (DE→RR) |
| 指令长度 | 32位定长 |

---

**版本**: OCPU-RV64I-v1.0
