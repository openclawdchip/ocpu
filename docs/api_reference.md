# OCPU API参考

**版本**: 4.0  
**接口**: C API / SystemVerilog Interface

---

## 目录

1. [C API](#c-api)
2. [Agent模式API](#agent模式api)
3. [SystemVerilog接口](#systemverilog接口)
4. [CSR寄存器](#csr寄存器)

---

## C API

### 核心控制API

#### `ocpu_init`

```c
int ocpu_init(void);
```

**描述**: 初始化OCPU硬件

**参数**: 无

**返回值**:
- `0`: 成功
- `-1`: 初始化失败

**示例**:
```c
if (ocpu_init() != 0) {
    fprintf(stderr, "OCPU初始化失败\n");
    return 1;
}
```

---

#### `ocpu_deinit`

```c
void ocpu_deinit(void);
```

**描述**: 释放OCPU资源

**参数**: 无

**返回值**: 无

---

#### `ocpu_switch_mode`

```c
int ocpu_switch_mode(ocpu_mode_t mode);
```

**描述**: 切换处理器工作模式

**参数**:
- `mode`: 目标模式
  - `MODE_HUMAN`: 人类模式 (OOO)
  - `MODE_AGENT`: Agent模式 (静态调度)

**返回值**:
- `0`: 成功
- `-1`: 切换失败

**示例**:
```c
// 切换到Agent模式
ocpu_switch_mode(MODE_AGENT);

// 执行Agent任务...

// 切回人类模式
ocpu_switch_mode(MODE_HUMAN);
```

---

#### `ocpu_get_mode`

```c
ocpu_mode_t ocpu_get_mode(void);
```

**描述**: 获取当前工作模式

**返回值**: 当前模式

---

### 性能监控API

#### `ocpu_get_cycle_count`

```c
uint64_t ocpu_get_cycle_count(void);
```

**描述**: 获取处理器周期计数

**返回值**: 64位周期计数

---

#### `ocpu_get_instret`

```c
uint64_t ocpu_get_instret(void);
```

**描述**: 获取退役指令数

**返回值**: 64位指令计数

---

#### `ocpu_read_csr`

```c
uint64_t ocpu_read_csr(uint16_t csr_addr);
```

**描述**: 读取CSR寄存器

**参数**:
- `csr_addr`: CSR地址

**返回值**: CSR值

---

## Agent模式API

### 任务描述符

```c
typedef struct {
    uint8_t  task_type;          // 任务类型 (见下表)
    uint16_t data_size;          // 数据大小 (元素数)
    uint16_t iterations;         // 迭代次数
    uint8_t  parallelism;        // 并行度 (1-16)
    uint8_t  memory_pattern;     // 内存访问模式
    uint16_t compute_intensity;  // 计算强度
    uint32_t data_address;       // 数据起始地址
    uint16_t optimization_goal;  // 优化目标
} task_descriptor_t;
```

### 任务类型

| 常量 | 值 | 描述 |
|------|-----|------|
| `TASK_VEC_ADD` | 0x01 | 向量加法 |
| `TASK_MAT_MUL` | 0x02 | 矩阵乘法 |
| `TASK_CONV` | 0x03 | 卷积运算 |
| `TASK_FFT` | 0x04 | 快速傅里叶变换 |
| `TASK_SORT` | 0x05 | 排序 |
| `TASK_SEARCH` | 0x06 | 搜索 |
| `TASK_REDUCTION` | 0x07 | 归约运算 |
| `TASK_SCAN` | 0x08 | 扫描运算 |
| `TASK_CUSTOM` | 0xFF | 自定义任务 |

### 内存访问模式

| 常量 | 值 | 描述 |
|------|-----|------|
| `MEM_PATTERN_SEQUENTIAL` | 0x00 | 顺序访问 |
| `MEM_PATTERN_STRIDED` | 0x01 | 步幅访问 |
| `MEM_PATTERN_RANDOM` | 0x02 | 随机访问 |
| `MEM_PATTERN_BLOCKED` | 0x03 | 分块访问 |

### 优化目标

| 常量 | 值 | 描述 |
|------|-----|------|
| `OPT_MIN_LATENCY` | 0x0001 | 最小延迟 |
| `OPT_MAX_THROUGHPUT` | 0x0002 | 最大吞吐量 |
| `OPT_MIN_ENERGY` | 0x0004 | 最小能耗 |
| `OPT_BALANCED` | 0x0008 | 平衡优化 |

---

### `ocpu_agent_submit_task`

```c
int ocpu_agent_submit_task(task_descriptor_t task);
```

**描述**: 提交Agent任务

**参数**:
- `task`: 任务描述符

**返回值**:
- `0`: 成功
- `-1`: 失败 (无效参数或模式错误)

**示例**:
```c
task_descriptor_t task = {
    .task_type = TASK_VEC_ADD,
    .data_size = 4096,
    .parallelism = 16,
    .data_address = 0x80000000,
    .optimization_goal = OPT_MAX_THROUGHPUT
};

if (ocpu_agent_submit_task(task) != 0) {
    fprintf(stderr, "任务提交失败\n");
}
```

---

### `ocpu_agent_wait_complete`

```c
int ocpu_agent_wait_complete(void);
```

**描述**: 等待所有Agent任务完成

**返回值**:
- `0`: 成功完成
- `-1`: 执行错误

**示例**:
```c
ocpu_agent_submit_task(task1);
ocpu_agent_submit_task(task2);
ocpu_agent_wait_complete();  // 等待两个任务都完成
```

---

### `ocpu_agent_query_status`

```c
typedef struct {
    uint64_t cycles_executed;
    uint64_t instructions_generated;
    uint64_t sram_accesses;
    uint8_t  status;  // 0=idle, 1=running, 2=complete, 3=error
} agent_status_t;

agent_status_t ocpu_agent_query_status(void);
```

**描述**: 查询Agent执行状态

**返回值**: 状态结构体

---

## SystemVerilog接口

### 顶层模块接口

#### `ocpu_core`

```systemverilog
module ocpu_core #(
    parameter XLEN = 64,
    parameter ISSUE_WIDTH = 16,
    parameter NUM_PREG = 512,
    parameter MODE = MODE_HUMAN  // 默认模式
)(
    // 时钟复位
    input  wire         clk,
    input  wire         reset_n,
    
    // 中断
    input  wire [15:0]  irq,            // 外部中断
    input  wire         timer_int,      // 定时器中断
    input  wire         soft_int,       // 软件中断
    
    // CHI系统总线
    output wire         chi_txreq_valid,
    output wire [47:0]  chi_txreq_addr,
    // ... (完整CHI接口)
    
    // JTAG调试
    input  wire         jtag_tck,
    input  wire         jtag_tms,
    input  wire         jtag_tdi,
    output wire         jtag_tdo,
    
    // Agent模式任务接口
    input  wire [127:0] agent_task_desc,
    input  wire         agent_task_valid,
    output wire         agent_ready,
    
    // 模式控制
    input  wire [1:0]   mode_select,
    input  wire         mode_switch_req,
    output wire         mode_switch_ack
);
```

### Agent接口

#### `ocpu_agent_code_generator`

```systemverilog
module ocpu_agent_code_generator #(
    parameter CODE_BUFFER_SIZE = 4096,
    parameter MAX_TASK_DESCRIPTORS = 256
)(
    input  wire         clk,
    input  wire         reset_n,
    input  wire         en,
    
    // 任务描述符输入
    input  wire [127:0] task_descriptor_i,
    input  wire         task_valid_i,
    output reg          gen_ready_o,
    
    // 代码输出
    output reg  [511:0] code_stream_o,
    output reg          code_valid_o,
    input  wire         code_accepted_i
);
```

---

## CSR寄存器

### 标准RISC-V CSR

| CSR | 地址 | 描述 | 访问 |
|-----|------|------|------|
| `cycle` | 0xC00 | 周期计数 | RO |
| `time` | 0xC01 | 实时计数器 | RO |
| `instret` | 0xC02 | 退役指令数 | RO |
| `mstatus` | 0x300 | 机器状态 | RW |
| `mie` | 0x304 | 中断使能 | RW |
| `mip` | 0x344 | 中断等待 | RO |

### OCPU自定义CSR

| CSR | 地址 | 描述 | 访问 |
|-----|------|------|------|
| `ocpu_mode` | 0x7C0 | 当前模式 | RW |
| `ocpu_stats` | 0x7C1 | 性能统计控制 | RW |
| `ocpu_l1i_miss` | 0x7C2 | L1-I未命中 | RO |
| `ocpu_l1d_miss` | 0x7C3 | L1-D未命中 | RO |
| `ocpu_l2_miss` | 0x7C4 | L2未命中 | RO |
| `ocpu_branch_misp` | 0x7C5 | 分支预测失误 | RO |
| `ocpu_rob_full` | 0x7C6 | ROB满次数 | RO |
| `ocpu_issue_stall` | 0x7C7 | 发射停顿 | RO |
| `ocpu_agent_cycles` | 0x7C8 | Agent周期数 | RO |
| `ocpu_agent_tasks` | 0x7C9 | Agent任务数 | RO |
| `ocpu_sram_access` | 0x7CA | SRAM访问数 | RO |

### CSR访问宏

```c
// 读取CSR
#define read_csr(csr) ({ \
    uint64_t __tmp; \
    asm volatile ("csrr %0, " #csr : "=r"(__tmp)); \
    __tmp; \
})

// 写入CSR
#define write_csr(csr, val) ({ \
    asm volatile ("csrw " #csr ", %0" :: "rK"(val)); \
})

// 设置CSR位
#define set_csr(csr, val) ({ \
    asm volatile ("csrs " #csr ", %0" :: "rK"(val)); \
})
```

---

## 错误代码

### 通用错误代码

| 代码 | 常量 | 描述 |
|------|------|------|
| 0 | `OCPU_OK` | 成功 |
| -1 | `OCPU_ERROR_INIT` | 初始化失败 |
| -2 | `OCPU_ERROR_MODE` | 无效模式 |
| -3 | `OCPU_ERROR_BUSY` | 硬件忙 |
| -4 | `OCPU_ERROR_INVALID` | 无效参数 |

### Agent模式错误代码

| 代码 | 常量 | 描述 |
|------|------|------|
| -0x10 | `OCPU_ERROR_TASK_TYPE` | 无效任务类型 |
| -0x11 | `OCPU_ERROR_DATA_ADDR` | 无效数据地址 |
| -0x12 | `OCPU_ERROR_DATA_SIZE` | 无效数据大小 |
| -0x13 | `OCPU_ERROR_PARALLELISM` | 无效并行度 |
| -0x14 | `OCPU_ERROR_MODE_SWITCH` | 模式切换失败 |
| -0x15 | `OCPU_ERROR_SRAM_CONFLICT` | SRAM访问冲突 |
| -0x16 | `OCPU_ERROR_CODE_GEN` | 代码生成失败 |

---

## 版本信息

### 获取版本

```c
// 获取OCPU版本
uint32_t ocpu_get_version(void);

// 返回值格式: 0xMMmmpp00
// MM = 主版本, mm = 次版本, pp = 补丁版本
// 例如: 0x04000000 = v4.0.0
```

### 版本常量

```c
#define OCPU_VERSION_MAJOR  4
#define OCPU_VERSION_MINOR  0
#define OCPU_VERSION_PATCH  0
#define OCPU_VERSION_STRING "4.0.0"
```

---

**版本**: 4.0  
**最后更新**: 2026-02-13
