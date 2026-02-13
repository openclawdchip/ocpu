# OCPU 架构设计文档

**版本**: 4.0  
**日期**: 2026-02-13

---

## 1. 概述

OCPU采用创新的双模处理器架构，结合传统OOO乱序执行和现代Agent静态调度，提供统一的硬件平台支持通用计算和AI加速。

### 1.1 设计目标

1. **高性能**: 16发射超标量，单线程IPC > 12
2. **灵活性**: 支持传统软件和Agent代码
3. **确定性**: Agent模式提供可预测的执行时间
4. **可扩展**: 模块化设计，易于扩展

### 1.2 架构亮点

- **双模设计**: 人类模式 + Agent模式
- **纯64位**: 无32位兼容负担
- **向量扩展**: 1024-bit VLEN
- **确定性**: Agent模式无缓存未命中

---

## 2. 人类模式架构

### 2.1 流水线概览

```
Fetch → Decode → Rename → Dispatch → Issue → Execute → Commit
  │       │       │         │        │        │        │
  ▼       ▼       ▼         ▼        ▼        ▼        ▼
16-wide 16-wide  512      256       44       44      256
256KB   RVC      PREG     IQ        EU       EU      ROB
L1-I
```

### 2.2 取指单元 (IFetch)

**功能**: 每周期从I-Cache获取16条指令

**主要组件**:
- **分支预测器**: BTB(2048) + GHB(8192) + RAS(32) + TAGE
- **I-Cache**: 256KB, 8-way, 64B line
- **预取器**: Stream + Stride prefetching

**性能目标**:
- 分支预测准确率: >95%
- 取指带宽: 64B/周期

### 2.3 解码单元 (IDecode)

**功能**: 16条并行解码，RVC压缩指令支持

**特性**:
- 16-wide解码
- RVC (Compressed) 指令支持
- 异常检测
- 微操作生成

### 2.4 重命名单元 (Rename)

**功能**: 寄存器重命名，消除WAW/WAR冲突

**规格**:
- 物理寄存器: 512 (标量) + 256 (向量)
- 重命名宽度: 16
- 检查点: 16个 (用于分支恢复)
- RCQ: 256条目

### 2.5 发射单元 (Issue)

**功能**: OOO指令调度，动态发射到执行单元

**结构**:
- **IQ**: 256条目统一队列
- **调度器**: 唤醒-选择逻辑
- **分派**: 16-wide分派

**端口**:
- 10个SX (单周期ALU)
- 6个MX (乘加单元)
- 8个LSU (加载存储)

### 2.6 执行单元 (Execute)

**功能**: 44个执行单元并行执行

**单元配置**:
| 类型 | 数量 | 延迟 | 说明 |
|------|------|------|------|
| SX ALU | 10 | 1 | 单周期整数ALU |
| MX MAC | 6 | 3 | 整数乘加 |
| FPU | 6 | 4 | IEEE 754-2008 |
| VPU | 8 | 6 | 1024-bit向量 |
| LSU | 8 | 可变 | 加载存储 |
| BRU | 4 | 1 | 分支单元 |
| DIV | 2 | 可变 | 除法/开方 |

### 2.7 加载存储单元 (LoadStore)

**功能**: OOO内存访问，非阻塞Cache

**组件**:
- **D-Cache**: 64KB, 8-way
- **Load Buffer**: 48条目
- **Store Buffer**: 48条目
- **MSHR**: 32条目
- **预取**: L1 + L2预取

### 2.8 提交单元 (Commit)

**功能**: 按程序顺序提交指令

**特性**:
- ROB: 256条目
- 提交宽度: 16
- 精确异常
- CSR处理

---

## 3. Agent模式架构

### 3.1 设计理念

Agent模式面向AI推理和确定性计算，采用静态调度替代动态调度，消除运行时开销。

### 3.2 核心组件

#### 3.2.1 Agent代码生成器

**输入**: 任务描述符 (128-bit)
**输出**: 机器码序列 (512-bit streams)

**任务描述符格式**:
```
[TaskType:8] [DataSize:16] [Iterations:16] [Parallel:8] 
[MemPattern:8] [CompIntensity:16] [DataAddr:32] [OptGoal:16]
```

**代码生成流程**:
1. 解析任务描述符
2. 选择代码模板
3. 定制化生成
4. 静态调度
5. 软件流水化
6. 输出生成代码

#### 3.2.2 静态调度单元

**特性**:
- 调度表: 256条目
- 确定性发射: 16条/周期
- 无动态依赖检查
- 无记分板

**调度表项**:
```
[InstRaw:32] [CycleOffset:8] [Slot:4] [Src0:6] [Dst:6] [Latency:8]
```

#### 3.2.3 SRAM控制器

**架构**: 16 Bank并行访问

**规格**:
- Bank数: 16
- Bank大小: 32KB
- 总容量: 512KB
- 访问延迟: 2周期 (确定性)
- 并发端口: 16

**仲裁模式**:
- 静态分配
- 轮询仲裁
- 优先级仲裁

#### 3.2.4 软件流水线引擎

**功能**: 自动将循环转换为流水线形式

**三阶段**:
- **Prolog**: 填充流水线
- **Kernel**: 稳态执行
- **Epilog**: 排空流水线

**模调度**: 自动计算最优II (Initiation Interval)

---

## 4. 存储系统

### 4.1 人类模式存储层次

```
┌─────────┐
│  Reg    │  64 × 32 = 2KB
├─────────┤
│  L1-I   │  256KB, 8-way
├─────────┤
│  L1-D   │  64KB, 8-way
├─────────┤
│  L2     │  4MB, 16-way, MESI
├─────────┤
│  Memory │  DDR5
└─────────┘
```

### 4.2 Agent模式存储

```
┌─────────┐
│  Reg    │  Agent专用64寄存器
├─────────┤
│  SRAM   │  512KB, 16 Bank
├─────────┤
│  Memory │  DDR5 (通过DMA)
└─────────┘
```

### 4.3 缓存一致性

- **协议**: MESI
- **监听**: L2监听所有L1访问
- **写策略**: 写回 (Write-back)

---

## 5. 模式切换

### 5.1 切换流程

```
Human Active
     │
     │ Switch Request
     ▼
Save Context (PC, Regs, Cache)
     │
     ▼
Flush Cache to SRAM
     │
     ▼
Restore Agent Context
     │
     ▼
Agent Active
```

### 5.2 上下文定义

| 上下文项 | Human Mode | Agent Mode |
|----------|------------|------------|
| PC | 64-bit地址 | 任务描述符指针 |
| 寄存器 | 512 PREG | 64 Agent Reg |
| 状态 | ROB/队列 | 调度表位置 |
| 存储 | Cache内容 | SRAM Bank |

### 5.3 切换延迟

- **Human → Agent**: ~1000 cycles (Cache flush)
- **Agent → Human**: ~100 cycles

---

## 6. 接口

### 6.1 系统接口

**CHI总线**:
- 协议: AMBA CHI Issue E
- 数据位宽: 512-bit
- 频率: 同核心频率

### 6.2 调试接口

**JTAG/DMI**:
- 符合RISC-V External Debug Support v0.13
- 4个硬件断点
- 单步执行
- 寄存器访问

### 6.3 中断接口

**PLIC + CLINT**:
- 支持1024个外部中断源
- 7个优先级级别
- 软件中断和定时器中断

---

## 7. 性能目标

### 7.1 人类模式

| 指标 | 目标 |
|------|------|
| IPC | > 12 @ SPECint2017 |
| 分支预测准确率 | > 95% |
| L1-I命中率 | > 98% |
| L1-D命中率 | > 95% |
| L2命中率 | > 90% |

### 7.2 Agent模式

| 指标 | 目标 |
|------|------|
| 发射效率 | 100% (确定性) |
| SRAM利用率 | > 90% |
| 延迟确定性 | 100% |
| 代码启动时间 | < 1μs |

---

## 8. 物理实现

### 8.1 工艺节点

- **目标工艺**: 3nm
- **频率目标**: 3.5GHz
- **功耗预算**: 15W (TDP)

### 8.2 面积估算

| 模块 | 面积 (mm²) |
|------|-----------|
| Core (Human) | 8.5 |
| Core (Agent) | 2.0 |
| L2 Cache | 12.0 |
| Uncore | 3.5 |
| **Total** | **26.0** |

---

## 9. 设计方法

### 9.1 RTL设计

- **语言**: SystemVerilog
- **风格**: 可综合RTL
- **验证**: UVM + 形式验证

### 9.2 命名规范

- **模块**: `ocpu_<module_name>`
- **宏**: `OCPU_<MACRO_NAME>`
- **信号**: `<module>_<signal>`

---

## 10. 参考

- RISC-V Instruction Set Manual v2.2
- RISC-V Privileged Architecture v1.12
- RISC-V Vector Extension v1.0
- RISC-V External Debug Support v0.13
- IEEE 754-2008 Floating Point Standard

---

**文档版本**: 4.0  
**最后更新**: 2026-02-13
