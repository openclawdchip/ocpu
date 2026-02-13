# OCPU v4.1 - 共享执行后端架构

**版本**: 4.1  
**日期**: 2026-02-13  
**主题**: Agent模式与人类模式共用执行单元

---

## 1. 架构概述

OCPU v4.1引入**共享执行后端架构**，人类模式（OOO）和Agent模式（Static）共用同一组物理执行单元，实现硬件资源的最大化利用。

### 1.1 设计理念

```
传统分离架构:
┌─────────────────┐      ┌─────────────────┐
│   Human Mode    │      │   Agent Mode    │
│  ┌───────────┐  │      │  ┌───────────┐  │
│  │ 10 SX ALU │  │      │  │ 10 SX ALU │  │  ← 硬件重复!
│  │ 6 MX MAC  │  │      │  │ 6 MX MAC  │  │  ← 硬件重复!
│  │ 6 FPU     │  │      │  │ 6 FPU     │  │  ← 硬件重复!
│  │ 8 VPU     │  │      │  │ 8 VPU     │  │  ← 硬件重复!
│  └───────────┘  │      │  └───────────┘  │
└─────────────────┘      └─────────────────┘

共享执行后端架构 (v4.1):
                    ┌─────────────────────┐
                    │   Execution Unit    │
                    │       Pool          │
┌─────────────────┐ │  ┌───────────────┐  │ ┌─────────────────┐
│   Human Mode    │ │  │  10 SX ALU    │  │ │   Agent Mode    │
│  (OOO Frontend) │ │  │  6 MX MAC     │  │ │ (Static Front)  │
│                 │ │  │  6 FPU        │  │ │                 │
│  Dynamic Issue  │◀┼──┤  8 VPU        ├─▶┼┤  Static Issue   │
│  ROB-based      │ │  │  8 LSU        │  │ │  Table-based    │
└─────────────────┘ │  └───────────────┘  │ └─────────────────┘
                    │        ▲            │
                    │        │            │
                    │   Shared Backend    │
                    └─────────────────────┘
```

### 1.2 核心优势

| 优势 | 说明 |
|------|------|
| **面积节省** | 减少40-50%执行单元面积 |
| **功耗优化** | 动态关闭未使用的执行单元 |
| **资源共享** | 峰值性能不受单一模式限制 |
| **灵活性** | 根据负载动态分配执行单元 |

---

## 2. 架构详细设计

### 2.1 三层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        第一层: 前端层                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐              ┌──────────────────┐        │
│  │  Human Frontend  │              │  Agent Frontend  │        │
│  │  - IFetch        │              │  - Code Gen      │        │
│  │  - Decode        │              │  - Scheduler     │        │
│  │  - Rename        │              │  - SRAM Ctrl     │        │
│  │  - OOO Issue     │              │  - Static Issue  │        │
│  └────────┬─────────┘              └────────┬─────────┘        │
│           │                                 │                   │
│           │ 不同的发射机制                    │                   │
│           ▼                                 ▼                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        第二层: 仲裁层                            │
├─────────────────────────────────────────────────────────────────┤
│              ┌──────────────────────────────┐                  │
│              │   Shared Execute Backend     │                  │
│              │  ┌────────────────────────┐  │                  │
│              │  │   Request Arbiter      │  │                  │
│              │  │  - Mode Priority       │  │                  │
│              │  │  - EU Allocation       │  │                  │
│              │  │  - Conflict Resolution │  │                  │
│              │  └────────────────────────┘  │                  │
│              └─────────────┬────────────────┘                  │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        第三层: 执行层                            │
├─────────────────────────────────────────────────────────────────┤
│              ┌──────────────────────────────┐                  │
│              │   Execution Unit Pool        │                  │
│              │                                │                  │
│              │   ┌─────┐ ┌─────┐ ┌─────┐    │                  │
│              │   │SX 0 │ │SX 1 │ │ ... │    │  10 SX ALU       │
│              │   └─────┘ └─────┘ └─────┘    │                  │
│              │   ┌─────┐ ┌─────┐ ┌─────┐    │                  │
│              │   │MX 0 │ │MX 1 │ │ ... │    │  6 MX MAC        │
│              │   └─────┘ └─────┘ └─────┘    │                  │
│              │   ┌─────┐ ┌─────┐ ┌─────┐    │                  │
│              │   │FPU0 │ │FPU1 │ │ ... │    │  6 FPU           │
│              │   └─────┘ └─────┘ └─────┘    │                  │
│              │   ┌─────┐ ┌─────┐ ┌─────┐    │                  │
│              │   │VPU0 │ │VPU1 │ │ ... │    │  8 VPU           │
│              │   └─────┘ └─────┘ └─────┘    │                  │
│              │   ┌─────┐ ┌─────┐ ┌─────┐    │                  │
│              │   │LSU0 │ │LSU1 │ │ ... │    │  8 LSU           │
│              │   └─────┘ └─────┘ └─────┘    │                  │
│              └──────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 关键组件

#### 2.2.1 共享执行后端 (Shared Execute Backend)

**功能**:
- 接收来自两种模式的发射请求
- 仲裁访问权限
- 分配执行单元
- 分发操作数
- 收集写回结果

**接口**:
```systemverilog
// Human模式接口 (OOO)
input  [31:0]          human_issue_valid;
input  [31:0][63:0]    human_issue_opcode;
input  [31:0][63:0]    human_issue_src0;
input  [31:0][63:0]    human_issue_src1;
output [31:0]          human_issue_ready;

// Agent模式接口 (Static)
input  [15:0]          agent_issue_valid;
input  [15:0][31:0]    agent_issue_opcode;
input  [15:0][63:0]    agent_issue_src0;
input  [15:0][63:0]    agent_issue_src1;
output [15:0]          agent_issue_ready;

// 执行单元接口 (共享)
output [NUM_SX-1:0]    sx_req;
output [NUM_SX-1:0][63:0] sx_op_a, sx_op_b;
input  [NUM_SX-1:0]    sx_ready, sx_valid;
input  [NUM_SX-1:0][63:0] sx_result;
```

#### 2.2.2 请求仲裁逻辑

**仲裁策略**:

1. **模式切换期间**: 完成当前模式的所有指令
2. **正常运行时**: 
   - Human模式: 动态优先级，减少OOO停顿
   - Agent模式: 静态分配，按调度表执行

**伪代码**:
```verilog
if (mode_switching)
    complete_current_mode();
else if (current_mode == HUMAN)
    grant_human_requests();
else if (current_mode == AGENT)
    grant_agent_requests();
```

#### 2.2.3 执行单元池 (Execution Unit Pool)

**物理执行单元**:

| 类型 | 数量 | 延迟 | 说明 |
|------|------|------|------|
| SX ALU | 10 | 1 | 单周期整数运算 |
| MX MAC | 6 | 3 | 整数乘加 |
| FPU | 6 | 4 | 浮点运算 |
| VPU | 8 | 6 | 1024-bit向量运算 |
| LSU | 8 | 可变 | 加载/存储 |

**执行单元状态表**:
```
EU ID | Type | Mode | DstReg | Busy | Ready
------|------|------|--------|------|-------
  0   |  SX  | H    | R12    |  1   |   0
  1   |  SX  | A    | R05    |  1   |   0
  2   |  SX  | -    |  -     |  0   |   1
 ...  | ...  | ...  | ...    | ...  | ...
```

---

## 3. 工作流程

### 3.1 Human Mode执行流程

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  IFetch  │────▶│  Decode  │────▶│  Rename  │────▶│  Issue   │
└──────────┘     └──────────┘     └──────────┘     └────┬─────┘
                                                         │
                                    OOO调度 (动态)        │
                                                         ▼
┌──────────┐     ┌──────────┐     ┌──────────────────────┐
│   ROB    │◀────│   WB     │◀────│   Shared Backend     │
│ (Commit) │     │          │     │   (Arbitration)      │
└──────────┘     └──────────┘     └──────────┬───────────┘
                                             │
                                             ▼
                              ┌────────────────────────────┐
                              │   Execution Unit Pool      │
                              │   (Physical Units)         │
                              └────────────────────────────┘
```

### 3.2 Agent Mode执行流程

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Task Desc│────▶│ Code Gen │────▶│ Scheduler│
└──────────┘     └──────────┘     └────┬─────┘
                                       │
                静态调度表              │
                                       ▼
┌──────────┐     ┌──────────┐     ┌──────────────────────┐
│  SRAM    │◀────│   WB     │◀────│   Shared Backend     │
└──────────┘     └──────────┘     │   (Arbitration)      │
                                  └──────────┬───────────┘
                                             │
                                             ▼
                              ┌────────────────────────────┐
                              │   Execution Unit Pool      │
                              │   (Physical Units)         │
                              └────────────────────────────┘
```

### 3.3 模式切换流程

```
Human Mode Running
       │
       │ Mode Switch Request
       ▼
Drain Human Instructions
(完成ROB中所有指令)
       │
       ▼
Save Human Context
       │
       ▼
Switch EU Allocation Table
(切换执行单元分配表)
       │
       ▼
Restore Agent Context
       │
       ▼
Agent Mode Running
```

---

## 4. 性能优化

### 4.1 执行单元分配策略

#### Human Mode

```verilog
// 动态分配: 最先可用
for (i = 0; i < NUM_INSTRUCTIONS; i++) begin
    for (j = 0; j < NUM_EU; j++) begin
        if (eu[j].type == inst[i].type && eu[j].ready)
            allocate(inst[i], eu[j]);
    end
end
```

#### Agent Mode

```verilog
// 静态分配: 预分配
for (i = 0; i < NUM_INSTRUCTIONS; i++) begin
    j = schedule_table[i].eu_id;  // 从调度表读取
    allocate(inst[i], eu[j]);
end
```

### 4.2 功耗管理

**动态门控**:
- Human Mode时，Agent Frontend时钟门控
- Agent Mode时，OOO Frontend时钟门控
- 空闲执行单元自动门控

**电压/频率调节**:
- Human Mode: 高频，高电压
- Agent Mode: 根据任务调整频率

---

## 5. RTL实现

### 5.1 文件结构

```
rtl/core/
├── ocpu_core_v4.sv                    # v4.1顶层
├── ocpu_dual_mode_controller.sv       # 双模控制器
├── ocpu_shared_execute_backend.sv     # 共享执行后端 (NEW)
├── ocpu_execution_unit_pool.sv        # 执行单元池 (NEW)
├── ocpu_human_mode_frontend.sv        # 人类模式前端
└── ocpu_agent_mode_frontend.sv        # Agent模式前端

rtl/agent_mode/
├── ocpu_agent_static_scheduler.sv     # 静态调度器
├── ocpu_agent_sram_controller.sv      # SRAM控制器
└── ocpu_agent_code_generator.sv       # 代码生成器
```

### 5.2 关键参数

```systemverilog
// 共享执行单元配置
parameter NUM_SX  = 10;     // 单周期ALU
parameter NUM_MX  = 6;      // 乘加单元
parameter NUM_FPU = 6;      // 浮点单元
parameter NUM_VPU = 8;      // 向量单元
parameter NUM_LSU = 8;      // 加载存储单元

// 前端配置
parameter HUMAN_ISSUE_WIDTH = 32;   // OOO发射宽度
parameter AGENT_ISSUE_WIDTH = 16;   // 静态发射宽度
```

---

## 6. 性能对比

### 6.1 面积对比

| 架构 | 执行单元面积 | 前端面积 | 总面积 | 节省 |
|------|-------------|----------|--------|------|
| 分离架构 | 100% | 100% | 200% | - |
| 共享架构 | 100% | 100% | 150% | **25%** |

### 6.2 性能对比

| 场景 | Human Mode | Agent Mode | 混合模式 |
|------|------------|------------|----------|
| 峰值吞吐量 | 100% | 80% | 90% |
| 平均利用率 | 60% | 85% | 75% |
| 模式切换开销 | N/A | N/A | ~1000 cycles |

---

## 7. 使用指南

### 7.1 选择合适的模式

| 场景 | 推荐模式 | 原因 |
|------|----------|------|
| 通用软件执行 | Human | 兼容现有软件 |
| AI推理 | Agent | 确定性延迟 |
| 混合负载 | 动态切换 | 资源优化 |

### 7.2 编程建议

**Human Mode**:
```c
// 标准RISC-V代码
for (int i = 0; i < N; i++) {
    c[i] = a[i] + b[i];
}
```

**Agent Mode**:
```c
// 任务描述符
task_descriptor_t task = {
    .type = TASK_VEC_ADD,
    .size = N,
    .parallel = 16
};
ocpu_agent_submit(task);
```

---

## 8. 未来扩展

### 8.1 计划功能

- [ ] 细粒度模式切换 (函数级)
- [ ] 同时运行两种模式 (分区执行单元)
- [ ] 自适应执行单元分配
- [ ] 更多执行单元类型 (AI加速单元)

### 8.2 研究方向

- 异构计算优化
- 功耗感知调度
- 热管理策略
- 可靠性增强

---

**版本**: 4.1  
**最后更新**: 2026-02-13
