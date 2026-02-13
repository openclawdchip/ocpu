# ocpu_fpu 模块详细设计文档

## 1. 概述

### 1.1 模块简介
`ocpu_fpu` 是 OCPU 处理器中的浮点执行单元（Floating-Point Unit），负责执行所有 RISC-V F/D 扩展（单精度/双精度浮点）指令。该模块实现了 IEEE 754-2008 浮点标准，支持多种浮点运算（加、减、乘、除、开方、转换等）的并行处理。

### 1.2 主要特性
- **双发射架构**: 支持两个浮点执行流水线（FP0 和 FP1）
- **多精度浮点支持**: FP32/FP64（单精度/双精度）
- **RISC-V F/D扩展**: 完整支持 RV32F/RV64F/RV32D/RV64D 指令集
- **乘累加单元**: 支持 FMADD/FMSUB/FNMADD/FNMSUB 等融合乘加运算
- **数据重排**: 支持浮点寄存器数据的提取、插入、转置、反转等操作
- **归约操作**: 浮点向量元素的求和、最值等归约运算
- **自定义扩展**: 可选的自定义浮点加速（CUSTOM=1）

### 1.3 文件统计
- **顶层模块**: `ocpu_fpu.sv`
- **主要子模块**: 控制模块、浮点单元、整数单元、乘法单元、移位单元、排列单元等

---

## 2. 顶层架构

### 2.1 模块层次结构

```
ocpu_fpu (顶层)
├── ocpu_fpu_ctl (控制单元)
│   ├── ocpu_fpu_uop_ctl_dec (微操作解码)
│   ├── ocpu_fpu_fadd_uop_ctl_dec (浮点加解码)
│   ├── ocpu_fpu_fmul_uop_ctl_dec (浮点乘解码)
│   ├── ocpu_fpu_fcvt_uop_ctl_dec (浮点转换解码)
│   ├── ocpu_fpu_valu_uop_ctl_dec (向量ALU解码)
│   ├── ocpu_fpu_fmac_uop_ctl_dec (浮点MAC解码)
│   ├── ocpu_fpu_perm_uop_ctl_dec (排列解码)
│   └── ocpu_fpu_fshf_uop_ctl_dec (移位解码)
├── ocpu_fpu_byp (旁路/转发单元)
│   ├── ocpu_fpu_byp_fma64 (64位FMA旁路)
│   ├── ocpu_fpu_byp_fma32 (32位FMA旁路)
│   ├── ocpu_fpu_byp_valu (VALU旁路)
│   ├── ocpu_fpu_byp_fmac (FMAC旁路)
│   └── ...
├── 浮点运算单元 (FP0 - 4个并行单元)
│   ├── ocpu_fpu_fmul64 (64位浮点乘法)
│   ├── ocpu_fpu_fadd64 (64位浮点加法)
│   ├── ocpu_fpu_fmul32 (32位浮点乘法)
│   ├── ocpu_fpu_fadd32 (32位浮点加法)
│   ├── ocpu_fpu_fadd16 (16位浮点加法)
│   └── ocpu_fpu_fcvt64 (浮点类型转换)
├── 向量整数单元 (FP1)
│   ├── ocpu_fpu_valu (向量ALU)
│   │   ├── ocpu_fpu_valu_fmt (格式转换)
│   │   ├── ocpu_fpu_valu_au (算术单元)
│   │   ├── ocpu_fpu_valu_lu (逻辑单元)
│   │   └── ocpu_fpu_valu_clnt (结果合并)
│   ├── ocpu_fpu_fmac (浮点乘累加)
│   ├── ocpu_fpu_fdot (浮点点积)
│   └── ocpu_fpu_fred (浮点归约)
├── 数据重排单元
│   ├── ocpu_fpu_perm (浮点排列)
│   ├── ocpu_fpu_fshf (浮点移位)
│   └── ocpu_fpu_facc (浮点累加)
├── 除法/开方单元
│   ├── ocpu_fpu_fdivsqrt64_rad4 (64位除法/开方)
│   └── ocpu_fpu_fdivsqrt32_rad4 (32位除法/开方)
└── 密码学单元 (可选)
    ├── ocpu_fpu_crypt (密码学核心)
    └── ocpu_fpu_ela (嵌入式逻辑分析器)
```

### 2.2 流水线架构

#### FP0 流水线（浮点为主）
```
Issue -> Decode -> Bypass -> Execute(2-5 cycles) -> Writeback
                                  │
                    ┌─────────────┼─────────────┐
                    ↓             ↓             ↓
               FMUL64/32     FADD64/32     FDIVSQRT
               (2 cycles)    (2 cycles)    (6-17 cycles)
```

#### FP1 流水线（辅助运算）
```
Issue -> Decode -> Bypass -> Execute(1-4 cycles) -> Writeback
                                  │
                    ┌─────────────┼─────────────┐
                    ↓             ↓             ↓
                  VALU          FMAC          FRED
               (1 cycle)     (3-4 cycles)   (3 cycles)
```

---

## 3. 关键模块详细分析

### 3.1 控制单元 (ocpu_fpu_ctl)

#### 3.1.1 功能描述
`ocpu_fpu_ctl` 是浮点执行单元的中央控制器，负责：
- 微操作（uop）解码
- 执行流水线控制
- 数据旁路选择信号生成
- 条件码处理
- 异常标志管理

#### 3.1.2 接口信号

**输入信号:**
| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `is_fp_issue_v_fp0_i1` | 1 | FP0 发射有效 |
| `is_fp_uop_ctl_fp0_i1` | 32 | FP0 微操作控制字 |
| `is_fp_srca_v_fp0_i2` | 1 | FP0 源操作数A有效 |
| `is_fp_srcb_v_fp0_i2` | 1 | FP0 源操作数B有效 |
| `is_fp_srcc_v_fp0_i2` | 1 | FP0 源操作数C有效 |
| `mx_fp_fpcr` | 6 | 浮点控制寄存器 |

**输出信号:**
| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `fp0_fmul_dp_val_l_v3` | 1 | FP0 低64位浮点乘有效 |
| `fp0_fadd_dp_val_l_v2` | 1 | FP0 低64位浮点加有效 |
| `fp0_valu_uop_vld_v1` | 1 | FP0 VALU操作有效 |
| `fp0_rmode_v1` | 2 | 舍入模式 |

#### 3.1.3 内部逻辑

**控制字解码 (ocpu_fpu_uop_ctl_dec):**
```systemverilog
// 控制字位域定义
`define OCPU_FPU_DP_CTL_FB_SEL      3:0   // 反馈选择
`define OCPU_FPU_DP_CTL_VSIZE       5:4   // 向量大小
`define OCPU_FPU_DP_CTL_ESIZE       7:6   // 元素大小
`define OCPU_FPU_DP_CTL_SCALAR      8     // 标量操作
`define OCPU_FPU_DP_CTL_UNSIGNED    9     // 无符号操作
`define OCPU_FPU_DP_CTL_CC          13:10 // 条件码
```

**反馈选择编码:**
- `4'b0000`: FMOV 结果
- `4'b0010`: FCVT 结果
- `4'b0101`: VALU 结果
- `4'b0111`: FADD_2C 结果
- `4'b1001`: FMADD_4C 结果
- `4'b1110`: FMAC 结果

---

### 3.2 向量ALU (ocpu_fpu_valu)

#### 3.2.1 功能描述
`ocpu_fpu_valu` 实现浮点辅助整数运算，包括：
- 加法/减法（支持饱和运算）
- 比较运算（等于、大于、小于等）
- 位逻辑运算（与、或、异或、取反）
- 移位运算
- 绝对值、取反
- 计数前导零/一（CLZ/CLO/CLS）
- 人口计数（CNT）

#### 3.2.2 接口信号

```systemverilog
module ocpu_fpu_valu (
  input  wire            valu_en_v1,        // 操作使能
  input  wire            unsigned_v1,       // 无符号模式
  input  wire            res128_v1,         // 128位结果
  input  wire [1:0]      esize_v1,          // 元素大小
  input  wire [4:0]      valu_iadd_ctl_v1,  // 整数加法控制
  input  wire [3:0]      valu_icmp_ctl_v1,  // 整数比较控制
  input  wire [4:0]      valu_ilu_ctl_v1,   // 整数逻辑控制
  input  wire            valu_subtract_v1,  // 减法操作
  input  wire            valu_wide_v1,      // 加宽操作
  input  wire            valu_long_v1,      // 长操作
  input  wire [127:0]    opa_v1,            // 源操作数A
  input  wire [127:0]    opb_v1,            // 源操作数B
  input  wire [127:0]    opc_v1,            // 源操作数C
  output wire [127:0]    valuout_v2,        // 结果输出
  output wire            valu_qc_vld_v2,    // 条件码有效
  output wire            valu_qc_v2         // 条件码值
);
```

#### 3.2.3 内部架构

**子模块组成:**

1. **ocpu_fpu_valu_fmt** - 输入格式化和预计算
   - 数据符号扩展
   - 进位生成
   - 零标志计算

2. **ocpu_fpu_valu_au** (2个实例) - 算术单元
   - 低64位和高64位并行处理
   - 支持8/16/32/64位元素粒度
   - 饱和检测

3. **ocpu_fpu_valu_lu** - 逻辑单元
   - 位操作: AND, OR, EOR, BIC, ORN, EON
   - CLZ/CLS/CNT 实现

4. **ocpu_fpu_valu_clnt** - 结果合并
   - 根据操作类型选择结果
   - 条件码生成

#### 3.2.4 算法实现

**饱和加法示例:**
```systemverilog
// 8位有符号饱和加法
wire [7:0] sum = a + b;
wire overflow = (~a[7] & ~b[7] & sum[7]) | (a[7] & b[7] & ~sum[7]);
wire [7:0] sat_result = overflow ? (a[7] ? 8'h80 : 8'h7F) : sum;
```

**比较运算实现:**
```systemverilog
// 比较操作通过减法实现
wire [63:0] diff = a - b;
wire lt = (sign_a & ~sign_b) | ((sign_a == sign_b) & diff[63]);
wire eq = (diff == 0);
wire gt = ~lt & ~eq;
```

---

### 3.3 浮点MAC单元 (ocpu_fpu_fmac)

#### 3.3.1 功能描述
`ocpu_fpu_fmac` 实现浮点乘累加运算，支持：
- FMADD (Fused Multiply-Add): result = a * b + c
- FMSUB (Fused Multiply-Subtract): result = a * b - c
- FNMADD (Negated Fused Multiply-Add): result = -(a * b + c)
- FNMSUB (Negated Fused Multiply-Subtract): result = -(a * b - c)
- 多项式乘法 (PMUL)
- 点积支持

#### 3.3.2 接口信号

```systemverilog
module ocpu_fpu_fmac (
  input  wire         clk, reset,
  input  wire         fp_fmac_vld_v1,      // 操作有效
  input  wire [12:0]  fp_fmac_cmd_v1,      // 命令控制
  input  wire [2:0]   fp_fmac_fwd_sel_v1,  // 前递选择
  input  wire         fp_fmac_ccpass_v1,   // 条件通过
  input  wire [63:0]  opa_v1_q,            // 源A
  input  wire [63:0]  opb_v1_q,            // 源B
  input  wire [127:0] opc_v1_q,            // 源C（累加值）
  input  wire [63:0]  fp_fmac_rest,        // 扩展输入
  output reg  [127:0] fmacout_v3,          // 结果V3
  output reg  [127:0] fmacout_v4,          // 结果V4
  output reg          fmac_qc_v4           // 条件码
);
```

#### 3.3.3 命令控制位

| 位 | 名称 | 描述 |
|----|------|------|
| 0 | FMAC_FMADD | FMADD 选择 |
| 1 | FMAC_FMSUB | 减法模式 |
| 2 | FMAC_POLYNOMIAL | 多项式模式 |
| 3 | FMAC_SATURATE | 饱和运算 |
| 4 | FMAC_ROUND | 舍入 |
| 5 | FMAC_LONG | 长操作 |
| 6 | FMAC_SRCB_SCALAR | 源B为标量 |
| 9:7 | FMAC_SRCB_SCALAR_IDX | 标量索引 |
| 10 | FMAC_UPPER | 高部分结果 |
| 11 | FMAC_FDOT | 点积模式 |

#### 3.3.4 流水线阶段

```
Cycle 1 (V1): 输入寄存，标量展开，符号扩展
      ↓
Cycle 2 (V2): 乘法运算，多项式计算，累加值转发选择
      ↓
Cycle 3 (V3): 累加运算，饱和检测，结果输出
      ↓
Cycle 4 (V4): 结果寄存（用于旁路）
```

#### 3.3.5 数据通路

**乘法器阵列:**
- 8个8×8乘法器（支持64位并行）
- 4个16×16乘法器
- 2个32×32乘法器

**累加树:**
- 4:2压缩树（ocpu_fpu_fmac_paccu_4to2）
- 最终进位传播加法

---

### 3.4 浮点加法器 (ocpu_fpu_fadd64)

#### 3.4.1 功能描述
`ocpu_fpu_fadd64` 实现IEEE 754标准的64位浮点加法/减法，支持：
- 加法/减法
- 比较（大于、等于、小于等）
- 最小/最大值选择
- FMA（融合乘加）的后级累加

#### 3.4.2 内部架构

**主要通路:**

1. **Far Path** - 大指数差（>1）
   - 有效数对齐（右移）
   - 加法/减法
   - 前导零检测和规格化

2. **Near Path** - 小指数差（0或1）
   - 有效数减法
   - LZA（前导零预测）
   - 左移规格化

3. **Special Path** - 特殊值处理
   - NaN、Infinity、Zero检测
   - 默认NaN生成

#### 3.4.3 关键算法

**指数比较和对齐:**
```systemverilog
wire [11:0] exp_diff = expa - expb;
wire expa_ge_expb = exp_diff[11];
wire [6:0] shift_amount = expa_ge_expb ? exp_diff : -exp_diff;
```

**LZA（前导零预测）:**
使用 `ocpu_fpu_fadd_lza128em` 模块实现快速前导零检测，避免规格化时的迭代延迟。

**舍入逻辑:**
```systemverilog
wire round_inc = (rne & guard & (lsb | sticky)) |
                 (ru & (guard | sticky));
```

---

### 3.5 浮点乘法器 (ocpu_fpu_fmul64)

#### 3.5.1 功能描述
`ocpu_fpu_fmul64` 实现64位浮点乘法，支持：
- 普通乘法
- FMA融合乘加的前级乘法
- 平方根倒数估计（用于FRSQRTE）

#### 3.5.2 乘法器阵列

** Booth4 编码:**
使用 `ocpu_fpu_fmul64_array_booth4` 实现高效率乘法：
- 部分积生成（Booth编码）
- 部分积选择（Booth4 Mux）
- Wallace树压缩
- 最终加法

**部分积压缩:**
```
Partial Products (17个) → 
4:2 Compressors → 
2:2 Compressors → 
Final CPA (Carry Propagate Adder)
```

---

### 3.6 浮点移位单元 (ocpu_fpu_fshf)

#### 3.6.1 功能描述
`ocpu_fpu_fshf` 实现浮点数据的移位操作，包括：
- 逻辑左移/右移
- 算术右移
- 窄化移位（高位舍入）
- 扩展移位
- 插入操作

#### 3.6.2 架构特点

**两级移位架构:**

1. **FSHF1** (ocpu_fpu_fshf1) - 第一阶段
   - 8×3旋转器（ocpu_fpu_fshf1_8x3rot）
   - 生成中间结果和控制信号
   - 饱和检测准备

2. **FSHF2** (ocpu_fpu_fshf2) - 第二阶段
   - 最终排列和舍入
   - 饱和检测完成
   - 结果生成

**移位网络:**
- 支持0-63位任意移位量
- 字节/半字/字/双字粒度
- 多路选择器树实现

---

### 3.7 数据旁路单元 (ocpu_fpu_byp)

#### 3.7.1 功能描述
`ocpu_fpu_byp` 实现执行单元间的数据转发（bypass/forwarding），解决数据相关性导致的停顿：
- 源操作数旁路选择
- 结果数据转发
- 累加值特殊处理

#### 3.7.2 旁路来源

**FP0 旁路源:**
| 来源 | 延迟 | 描述 |
|------|------|------|
| Issue | 0 | 发射阶段数据 |
| FMUL64 | 2 | 64位乘法结果 |
| FADD64 | 2 | 64位加法结果 |
| FMUL32 | 2 | 32位乘法结果 |
| FADD32 | 2 | 32位加法结果 |
| VALU | 1 | 整数ALU结果 |
| PERM | 1 | 排列结果 |
| FSHF | 1 | 移位结果 |

**选择信号:**
```systemverilog
output reg [6:0] fp0_srca_fma64_data_byp0_sel_i3,  // 3级选择信号
output reg [6:0] fp0_srca_fma64_data_byp1_sel_i3,  // 2级选择信号
output reg [6:0] fp0_srca_fma64_data_byp2_sel_i3,  // 1级选择信号
```

---

## 4. 浮点执行流水线详解

### 4.1 指令流

```
指令发射 (Issue)
    ↓
微操作解码 (Decode) - ocpu_fpu_ctl
    ↓
操作数准备 (Operand Fetch)
    ├─ 寄存器堆读取
    ├─ 旁路数据选择
    └─ 立即数扩展
    ↓
执行 (Execute)
    ├─ FP0: FMUL/FADD/FCVT/FDIV
    └─ FP1: VALU/FMAC/FSHF/PERM
    ↓
写回 (Writeback)
    ├─ 结果寄存
    └─ 标志更新
```

### 4.2 数据通路宽度

- **向量宽度**: 128位（RISC-V V扩展兼容）
- **数据粒度**: 8/16/32/64位元素
- **最大并行度**: 
  - 4×32位操作（单精度并行）
  - 2×64位操作（双精度并行）

### 4.3 延迟特性

| 操作类型 | 延迟周期 | 吞吐量 |
|----------|----------|--------|
| 整数ALU | 1 | 1/cycle |
| 浮点FMAC | 3-4 | 1/cycle |
| FP32 Add | 2 | 1/cycle |
| FP32 Mul | 2 | 1/cycle |
| FP32 FMA | 4-5 | 1/cycle |
| FP64 Add | 2 | 1/2cycle |
| FP64 Mul | 3 | 1/2cycle |
| FP64 Div | 6-17 | 非流水线 |

---

## 5. 关键算法解析

### 5.1 RISC-V F/D扩展指令支持

**F扩展指令集（单精度）:**
```
┌─────────────────────────────────────────────────────────────┐
│ 算术运算: FADD.S, FSUB.S, FMUL.S, FDIV.S, FSQRT.S           │
│ 融合乘加: FMADD.S, FMSUB.S, FNMADD.S, FNMSUB.S              │
│ 符号注入: FSGNJ.S, FSGNJN.S, FSGNJX.S                       │
│ 比较: FEQ.S, FLT.S, FLE.S                                   │
│ 分类: FCLASS.S                                              │
│ 转换: FCVT.W.S, FCVT.WU.S, FCVT.S.W, FCVT.S.WU             │
│ 移动: FMV.W.X, FMV.X.W                                      │
└─────────────────────────────────────────────────────────────┘
```

**D扩展指令集（双精度）:**
```
┌─────────────────────────────────────────────────────────────┐
│ 算术运算: FADD.D, FSUB.D, FMUL.D, FDIV.D, FSQRT.D           │
│ 融合乘加: FMADD.D, FMSUB.D, FNMADD.D, FNMSUB.D              │
│ 符号注入: FSGNJ.D, FSGNJN.D, FSGNJX.D                       │
│ 比较: FEQ.D, FLT.D, FLE.D                                   │
│ 分类: FCLASS.D                                              │
│ 转换: FCVT.S.D, FCVT.D.S                                    │
│ 移动: FMV.D.X, FMV.X.D                                      │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 IEEE 754-2008 浮点格式

**单精度（32位）:**
```
┌────┬───────────────────────┬──────────────────────────────┐
│Sign│     Exponent (8)      │      Significand (23)        │
│ 1  │    8 bits (127 bias)  │         23 bits              │
└────┴───────────────────────┴──────────────────────────────┘
```

**双精度（64位）:**
```
┌────┬────────────────────────┬─────────────────────────────┐
│Sign│     Exponent (11)      │      Significand (52)       │
│ 1  │   11 bits (1023 bias)  │         52 bits             │
└────┴────────────────────────┴─────────────────────────────┘
```

### 5.3 多项式乘法 (PMUL)

用于密码学算法，在GF(2^8)上的乘法：

```systemverilog
// 8位多项式乘法
ocpu_fpu_fmac_poly8 u_poly (
  .s16_o(poly_result[15:0]),
  .a8_i(a[7:0]),
  .b8_i(b[7:0])
);
```

### 5.4 饱和运算

防止溢出，将结果限制在数据类型范围内：

```systemverilog
function automatic [7:0] sat_add_8s;
  input [7:0] a, b;
  reg [8:0] sum;
  begin
    sum = {a[7], a} + {b[7], b};
    if (sum[8] != sum[7])  // 溢出检测
      sat_add_8s = a[7] ? 8'h80 : 8'h7F;
    else
      sat_add_8s = sum[7:0];
  end
endfunction
```

---

## 6. 与其他模块的交互

### 6.1 与发射单元 (Issue) 接口

```
is_fp_issue_v_fp0_i1 ──────┐
is_fp_uop_ctl_fp0_i1 ──────┼──> ocpu_fpu
is_fp_srca_data_fp0_i3 ────┤      ↓
is_fp_srcb_data_fp0_i3 ────┤   执行结果
is_fp_srcc_data_fp0_i3 ────┘      ↓
                        fp_is_resx_data_w1
                        fp_is_resy_data_w1
```

### 6.2 与Load/Store单元接口

```
ls_is_resx_data_d4 ──────┐
ls_is_resy_data_d4 ──────┼──> 旁路输入
fp_is_ls_resx_data_w0 <──┘
fp_is_ls_resy_data_w0 <──┘
```

### 6.3 与标量执行单元接口

```
mx_is_fmove_data_e2 ─────> 旁路输入
                          ↓
                     fp_mx_xfer_data0_v1
                     fp_mx_xfer_data1_v1
```

---

## 7. 设计要点总结

### 7.1 性能优化

1. **双发射架构**: FP0和FP1可并行执行不同类型指令
2. **数据旁路**: 减少RAW（读后写）相关导致的停顿
3. **流水线化**: 大多数操作每周期可发射
4. **并行乘法器**: 多个小位宽乘法器替代单个大乘法器

### 7.2 面积优化

1. **共享资源**: FADD/FMUL共享部分数据通路
2. **参数化设计**: CRYPTO/ELA功能可选配置
3. **门控时钟**: 未使用单元的时钟可关闭

### 7.3 功耗优化

1. **细粒度时钟门控**: 每个执行单元独立控制
2. **操作数隔离**: 未使用输入寄存隔离
3. **动态电压频率调节**: 支持多种频率模式

---

## 8. 附录

### 8.1 文件列表（按功能分类）

| 类别 | 文件数 | 关键文件 |
|------|--------|----------|
| 顶层/定义 | 5 | ocpu_fpu.sv, ocpu_fpu_defines.sv, ocpu_fpu_params.sv |
| 控制单元 | 8 | ocpu_fpu_ctl.sv, ocpu_fpu_*_ctl_dec.sv |
| 浮点单元 | 25 | ocpu_fpu_fadd*.sv, ocpu_fpu_fmul*.sv, ocpu_fpu_fcvt*.sv, ocpu_fpu_fdivsqrt*.sv |
| 整数单元 | 12 | ocpu_fpu_valu*.sv, ocpu_fpu_fred.sv |
| 乘法/MAC | 20 | ocpu_fpu_fmac*.sv, ocpu_fpu_fdot*.sv |
| 移位/排列 | 28 | ocpu_fpu_fshf*.sv, ocpu_fpu_perm*.sv, ocpu_fpu_facc.sv |
| 旁路 | 12 | ocpu_fpu_byp*.sv |
| 密码学 | 8 | ocpu_fpu_crypt*.sv (可选) |
| ELA | 1 | ocpu_fpu_ela.sv (可选) |

### 8.2 版本信息

- **Release**: OCPU-FPU-v1.0
- **Copyright**: 2025 OCPU Project
- **License**: Open Source

---

*文档生成日期: 2026-02-12*

