# OCPU 用户指南

**版本**: 4.0  
**目标读者**: 系统开发者、软件工程师、系统集成商

---

## 1. 简介

OCPU是一个高性能RISC-V处理器，支持两种执行模式：

- **人类模式**: 运行传统RISC-V软件
- **Agent模式**: 运行Agent生成的优化代码

本指南帮助您理解和使用OCPU。

---

## 2. 快速开始

### 2.1 硬件要求

#### FPGA开发板

| 开发板 | FPGA | 资源 | 状态 |
|--------|------|------|------|
| Xilinx Alveo U280 | VU37P | 足够 | 支持 |
| Xilinx VCU118 | VU9P | 足够 | 支持 |
| Intel Stratix 10 | GX 2800 | 足够 | 计划中 |

#### ASIC测试芯片

- 工艺: 3nm
- 封装: FC-BGA
- 功耗: 15W TDP

### 2.2 软件开发环境

```bash
# 安装RISC-V工具链
sudo apt-get install gcc-riscv64-linux-gnu

# 或从源码构建
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv64gcv
make linux
```

---

## 3. 人类模式使用

### 3.1 编译程序

```bash
# 编译C程序
riscv64-unknown-elf-gcc -O3 -march=rv64gcv -o program.elf program.c

# 生成机器码
riscv64-unknown-elf-objcopy -O binary program.elf program.bin

# 转换为hex格式
xxd -p program.bin > program.hex
```

### 3.2 运行程序

```bash
# 加载到OCPU模拟器
cd sim
./ocpu_sim --program=program.hex --cycles=1000000

# 查看结果
./ocpu_sim --program=program.hex --trace=1
```

### 3.3 性能分析

```bash
# 运行并收集统计
./ocpu_sim --program=program.hex --stats=stats.txt

# 统计输出示例:
# 总周期: 1,234,567
# 提交指令: 5,678,901
# IPC: 4.60
# 分支预测准确率: 96.5%
```

---

## 4. Agent模式使用

### 4.1 基本概念

Agent模式不需要编译传统软件。您提交**任务描述符**，Agent实时生成最优机器码。

### 4.2 任务描述符格式

```c
typedef struct {
    uint8_t  task_type;         // 任务类型
    uint16_t data_size;         // 数据大小 (元素数)
    uint16_t iterations;        // 迭代次数
    uint8_t  parallelism;       // 并行度 (1-16)
    uint8_t  memory_pattern;    // 内存访问模式
    uint16_t compute_intensity; // 计算强度
    uint32_t data_address;      // 数据起始地址
    uint16_t optimization_goal; // 优化目标
} task_descriptor_t;
```

### 4.3 内置任务类型

| 任务类型 | 描述 | 用途 |
|----------|------|------|
| `TASK_VEC_ADD` | 向量加法 | C[i] = A[i] + B[i] |
| `TASK_MAT_MUL` | 矩阵乘法 | C = A × B |
| `TASK_CONV` | 卷积运算 | 深度学习 |
| `TASK_FFT` | 快速傅里叶变换 | 信号处理 |
| `TASK_REDUCTION` | 归约运算 | 求和/最大/最小 |
| `TASK_SCAN` | 扫描运算 | 前缀和 |

### 4.4 提交任务

```c
#include "ocpu_agent.h"

int main() {
    // 创建任务描述符
    task_descriptor_t task = {
        .task_type = TASK_VEC_ADD,
        .data_size = 4096,          // 4K元素
        .iterations = 1,
        .parallelism = 16,          // 16并行
        .data_address = 0x80000000,
        .optimization_goal = OPT_MIN_LATENCY
    };
    
    // 初始化OCPU
    ocpu_init();
    
    // 切换到Agent模式
    ocpu_switch_mode(MODE_AGENT);
    
    // 提交任务
    ocpu_agent_submit_task(task);
    
    // 等待完成
    ocpu_agent_wait_complete();
    
    // 获取结果
    uint64_t cycles = ocpu_get_cycle_count();
    printf("任务完成，用时 %lu 周期\n", cycles);
    
    return 0;
}
```

### 4.5 内存访问模式

```c
// 内存访问模式定义
#define MEM_PATTERN_SEQUENTIAL  0x00  // 顺序访问
#define MEM_PATTERN_STRIDED     0x01  // 步幅访问
#define MEM_PATTERN_RANDOM      0x02  // 随机访问
#define MEM_PATTERN_BLOCKED     0x03  // 分块访问
```

### 4.6 优化目标

```c
// 优化目标定义
#define OPT_MIN_LATENCY     0x0001  // 最小延迟
#define OPT_MAX_THROUGHPUT  0x0002  // 最大吞吐量
#define OPT_MIN_ENERGY      0x0004  // 最小能耗
#define OPT_BALANCED        0x0008  // 平衡优化
```

---

## 5. 混合编程

### 5.1 模式切换

```c
// 在人类模式和Agent模式之间切换

// 人类模式: 运行通用代码
ocpu_switch_mode(MODE_HUMAN);
run_general_purpose_code();

// 切换到Agent模式: 运行AI推理
ocpu_switch_mode(MODE_AGENT);
task_descriptor_t inference_task = {
    .task_type = TASK_CONV,
    .data_size = input_size,
    .parallelism = 16
};
ocpu_agent_submit_task(inference_task);
ocpu_agent_wait_complete();

// 切回人类模式
ocpu_switch_mode(MODE_HUMAN);
process_results();
```

### 5.2 最佳实践

1. **在Agent模式执行计算密集型任务**
   - 矩阵运算
   - 卷积
   - 向量运算

2. **在人类模式执行控制密集型任务**
   - 操作系统
   - 文件系统
   - 网络协议栈

3. **最小化模式切换开销**
   - 批量提交Agent任务
   - 合并小规模任务

---

## 6. 性能调优

### 6.1 人类模式优化

#### 编译器优化

```bash
# 最高优化级别
riscv64-unknown-elf-gcc -O3 -march=rv64gcv

# 链接时优化
riscv64-unknown-elf-gcc -O3 -flto

# 向量化
riscv64-unknown-elf-gcc -O3 -march=rv64gcv -ftree-vectorize
```

#### 代码优化技巧

```c
// 1. 循环展开
for (i = 0; i < N; i += 4) {
    sum += a[i];
    sum += a[i+1];
    sum += a[i+2];
    sum += a[i+3];
}

// 2. 数据对齐
float __attribute__((aligned(64))) array[N];

// 3. 预取
__builtin_prefetch(&a[i+64], 0, 3);
```

### 6.2 Agent模式优化

#### 选择合适并行度

```c
// 根据数据大小选择并行度
if (data_size < 256)
    task.parallelism = 4;
else if (data_size < 1024)
    task.parallelism = 8;
else
    task.parallelism = 16;
```

#### 内存布局优化

```c
// 使用分块布局提高SRAM命中率
#define BLOCK_SIZE 1024

for (int block = 0; block < total_size; block += BLOCK_SIZE) {
    task.data_address = base_addr + block * sizeof(float);
    task.data_size = min(BLOCK_SIZE, total_size - block);
    ocpu_agent_submit_task(task);
}
```

---

## 7. 调试与诊断

### 7.1 调试接口

```bash
# 连接JTAG调试器
openocd -f interface/ftdi/ocpu-jtag.cfg -f target/ocpu.cfg

# GDB调试
riscv64-unknown-elf-gdb program.elf
(gdb) target remote localhost:3333
(gdb) load
(gdb) break main
(gdb) continue
```

### 7.2 性能计数器

```c
// 读取性能计数器
uint64_t cycles = ocpu_read_csr(CSR_CYCLE);
uint64_t instret = ocpu_read_csr(CSR_INSTRET);
uint64_t cache_misses = ocpu_read_csr(CSR_L1D_CACHE_MISS);

printf("IPC: %.2f\n", (double)instret / cycles);
```

### 7.3 日志输出

```c
// 启用详细日志
ocpu_set_log_level(LOG_DEBUG);

// 日志输出:
// [OCPU] Mode switched to AGENT
// [OCPU] Task submitted: type=VEC_ADD, size=4096
// [OCPU] Code generated: 64 instructions
// [OCPU] Task completed in 256 cycles
```

---

## 8. 系统集成

### 8.1 SoC集成

```verilog
// OCPU实例化示例
ocpu_core #(
    .MODE(MODE_HUMAN)           // 默认模式
) u_cpu (
    .clk(clk),
    .reset_n(reset_n),
    .irq(irq),
    .timer_int(timer_int),
    .chi_tx(chi_tx),
    .chi_rx(chi_rx),
    .jtag_tck(jtag_tck),
    .jtag_tms(jtag_tms),
    .jtag_tdi(jtag_tdi),
    .jtag_tdo(jtag_tdo)
);
```

### 8.2 内存映射

```
0x0000_0000 - 0x7FFF_FFFF: DDR5 (2GB)
0x8000_0000 - 0x8007_FFFF: Agent SRAM (512KB)
0x9000_0000 - 0x9000_0FFF: OCPU寄存器
0x9000_1000 - 0x9000_1FFF: PLIC
0x9000_2000 - 0x9000_2FFF: CLINT
0x9000_3000 - 0x9000_3FFF: Debug Module
```

---

## 9. 故障排除

### 9.1 常见问题

**Q: 程序在OCPU上运行很慢**

A: 检查以下几点:
- 编译时启用优化 `-O3`
- 确保使用正确的架构 `-march=rv64gcv`
- 考虑使用Agent模式处理计算密集型部分

**Q: Agent任务执行失败**

A: 检查:
- 任务描述符参数有效
- 数据地址在有效范围内
- 并行度不超过16

**Q: 模式切换失败**

A: 检查:
- 当前无正在执行的任务
- 上下文已保存
- Cache已刷新

### 9.2 错误代码

| 代码 | 含义 | 解决方案 |
|------|------|----------|
| 0x01 | 无效任务类型 | 检查task_type参数 |
| 0x02 | 无效数据地址 | 确保地址对齐 |
| 0x03 | 模式切换失败 | 等待当前任务完成 |
| 0x04 | SRAM访问冲突 | 调整Bank访问模式 |

---

## 10. 示例代码

### 10.1 向量加法

```c
#include "ocpu_agent.h"

void vector_add(float* a, float* b, float* c, int n) {
    task_descriptor_t task = {
        .task_type = TASK_VEC_ADD,
        .data_size = n,
        .parallelism = 16,
        .data_address = (uint32_t)a,
        .optimization_goal = OPT_MAX_THROUGHPUT
    };
    
    ocpu_agent_submit_task(task);
    ocpu_agent_wait_complete();
}
```

### 10.2 矩阵乘法

```c
void matrix_multiply(float* a, float* b, float* c, 
                     int m, int n, int k) {
    // 分块处理大矩阵
    #define BLOCK_M 64
    #define BLOCK_N 64
    
    for (int i = 0; i < m; i += BLOCK_M) {
        for (int j = 0; j < n; j += BLOCK_N) {
            task_descriptor_t task = {
                .task_type = TASK_MAT_MUL,
                .data_size = min(BLOCK_M, m - i) * 
                            min(BLOCK_N, n - j),
                .parallelism = 16
            };
            ocpu_agent_submit_task(task);
        }
    }
    ocpu_agent_wait_complete();
}
```

---

## 11. 参考文档

- [OCPU_TRM_3.0.md](../OCPU_TRM_3.0.md) - 技术参考手册
- [DUAL_MODE_ARCHITECTURE_v4.0.md](../DUAL_MODE_ARCHITECTURE_v4.0.md) - 双模架构
- [docs/developer_guide.md](developer_guide.md) - 开发者指南

---

**版本**: 4.0  
**最后更新**: 2026-02-13
