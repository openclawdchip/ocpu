# OCPU 开发者指南

**版本**: 4.0  
**目标读者**: RTL设计工程师、验证工程师、架构师

---

## 1. 开发环境设置

### 1.1 系统要求

| 组件 | 要求 |
|------|------|
| OS | Linux (Ubuntu 22.04+ / CentOS 8+) |
| RAM | 32GB+ (64GB推荐) |
| Disk | 100GB+ 可用空间 |
| Python | 3.8+ |
| GCC | 9.0+ |

### 1.2 工具链安装

```bash
# 安装Verilator
sudo apt-get install verilator

# 安装Icarus Verilog (可选)
sudo apt-get install iverilog

# 安装GTKWave (波形查看)
sudo apt-get install gtkwave

# 安装Python依赖
pip3 install -r requirements.txt
```

### 1.3 商业EDA工具 (可选)

```bash
# Synopsys VCS
# Cadence Xcelium
# Mentor ModelSim/Questa
# Xilinx Vivado
# Intel Quartus
```

---

## 2. 项目结构详解

### 2.1 RTL目录结构

```
rtl/
├── include/              # 全局头文件
│   ├── ocpu_header.sv    # 全局定义
│   ├── ocpu_params.sv    # 参数配置
│   ├── ocpu_defines.sv   # 宏定义
│   └── ocpu_dual_mode_defs.sv  # 双模定义
│
├── ifetch/               # 取指单元
│   ├── ocpu_ifetch.sv           # 顶层
│   ├── ocpu_ifetch_v3.sv        # v3.0版本
│   ├── ocpu_btb.sv              # BTB分支目标缓冲
│   ├── ocpu_ghb.sv              # GHB全局历史缓冲
│   ├── ocpu_ras.sv              # RAS返回地址栈
│   └── ... (共40文件)
│
├── idecode/              # 解码单元
│   ├── ocpu_idecode.sv
│   ├── ocpu_idecode_v3.sv
│   ├── ocpu_id_ctl.sv
│   └── ... (共40文件)
│
├── rename/               # 重命名单元
│   ├── ocpu_rename.sv
│   ├── ocpu_rat.sv
│   ├── ocpu_freelist.sv
│   └── ... (共40文件)
│
├── issue/                # 发射单元
│   ├── ocpu_issue.sv
│   ├── ocpu_is_scheduler.sv
│   └── ... (共38文件)
│
├── execute/              # 执行单元
│   ├── ocpu_execute.sv
│   ├── ocpu_execute_v3.sv
│   ├── ocpu_alu.sv
│   ├── ocpu_fpu_top.sv
│   ├── ocpu_vpu_top.sv
│   └── ... (共54文件)
│
├── loadstore/            # 加载存储单元
│   ├── ocpu_loadstore.sv
│   ├── ocpu_lsq.sv
│   └── ... (共43文件)
│
├── commit/               # 提交单元
│   ├── ocpu_commit.sv
│   ├── ocpu_rob.sv
│   └── ... (共41文件)
│
├── mmu/                  # 内存管理单元
│   ├── ocpu_mmu.sv
│   ├── ocpu_mmu_ptw.sv
│   └── ... (共40文件)
│
├── level2/               # L2缓存
│   ├── ocpu_l2cache.sv
│   └── ... (共41文件)
│
├── core/                 # 核心控制
│   ├── ocpu_core.sv
│   ├── ocpu_dual_mode_controller.sv
│   └── ... (共40文件)
│
└── agent_mode/           # Agent模式 (v4.0新增)
    ├── ocpu_agent_static_scheduler.sv
    ├── ocpu_agent_sram_controller.sv
    ├── ocpu_agent_code_generator.sv
    └── ocpu_agent_sw_pipeline.sv
```

### 2.2 文件命名规范

```
通用格式: ocpu_<模块>_<子模块>.sv

示例:
- ocpu_ifetch.sv           # 取指单元顶层
- ocpu_if_btb.sv           # BTB模块
- ocpu_id_dec.sv           # 解码器
- ocpu_rn_rat.sv           # 重命名RAT
- ocpu_ex_alu.sv           # ALU执行单元
```

---

## 3. RTL设计规范

### 3.1 编码风格

```systemverilog
// 模块声明
module ocpu_example #(
    parameter WIDTH = 64,
    parameter DEPTH = 32
)(
    input  wire             clk,
    input  wire             reset_n,      // 低电平有效复位
    input  wire [WIDTH-1:0] data_in,
    output reg  [WIDTH-1:0] data_out
);

    // 内部信号
    reg [WIDTH-1:0] internal_reg;
    wire            internal_wire;
    
    // 组合逻辑
    assign internal_wire = data_in[0] & data_in[1];
    
    // 时序逻辑
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            internal_reg <= {WIDTH{1'b0}};
            data_out <= {WIDTH{1'b0}};
        end
        else begin
            internal_reg <= data_in;
            data_out <= internal_reg;
        end
    end

endmodule
```

### 3.2 命名规范

| 类型 | 前缀 | 示例 |
|------|------|------|
| 模块 | `ocpu_` | `ocpu_ifetch` |
| 宏 | `OCPU_` | `OCPU_XLEN` |
| 输入 | `*_i` | `clk_i`, `data_i` |
| 输出 | `*_o` | `result_o`, `valid_o` |
| 内部信号 | 无前缀 | `internal_reg` |
| 参数 | 大写 | `WIDTH`, `DEPTH` |

### 3.3 注释规范

```systemverilog
//============================================================================-
// 模块名称: OCPU IFetch Unit
// 功能描述: 指令获取单元，支持分支预测和预取
// 作者: OCPU Team
// 日期: 2026-02-13
// 版本: 4.0
//============================================================================-

// 参数说明
parameter FETCH_WIDTH = 16;     // 取指宽度: 每周期16条指令

// 功能块说明
// BTB: Branch Target Buffer - 存储分支目标地址
// GHB: Global History Buffer - 全局分支历史
```

---

## 4. 仿真与验证

### 4.1 运行仿真

```bash
cd sim

# 编译和运行测试
make test

# 指定仿真器
make test SIM=vcs
make test SIM=modelsim

# 运行特定测试
make test TEST=test_alu

# 生成波形
make test WAVES=1
```

### 4.2 调试技巧

```bash
# 使用Verilator调试
verilator --cc --exe --trace --top-module tb_ocpu_core tb_ocpu_core.sv ../rtl/**/*.sv

# 查看波形
gtkwave waveform.vcd

# 使用printf调试 (仿真时)
`ifdef DEBUG
$display("[DEBUG] Time=%0t, signal=%h", $time, signal);
`endif
```

### 4.3 测试平台结构

```
tb/
└── tb_ocpu_core.sv      # 核心测试平台
    ├── 时钟生成
    ├── 复位逻辑
    ├── 内存模型
    ├── 指令序列
    └── 结果检查
```

---

## 5. FPGA综合

### 5.1 Xilinx Vivado

```bash
cd fpga

# 综合
make synth VENDOR=xilinx

# 实现
make impl VENDOR=xilinx

# 生成比特流
make bitstream VENDOR=xilinx

# 下载到FPGA
make program VENDOR=xilinx
```

### 5.2 Intel Quartus

```bash
cd fpga

# 完整流程
make all VENDOR=intel

# 仅综合
make synth VENDOR=intel
```

---

## 6. Agent模式开发

### 6.1 Agent代码生成器

```systemverilog
// 提交任务描述符
task_descriptor_t task;
task.task_type = TASK_VEC_ADD;
task.data_size = 4096;
task.parallelism = 16;
task.data_address = 32'h80000000;

// 生成代码
ocpu_agent_submit_task(task);
```

### 6.2 添加新任务类型

1. 在 `ocpu_dual_mode_defs.sv` 定义任务类型:
```systemverilog
localparam TASK_MY_NEW_TASK = 8'h10;
```

2. 在 `ocpu_agent_code_generator.sv` 添加生成逻辑:
```systemverilog
case (current_task.task_type)
    TASK_MY_NEW_TASK: begin
        gen_my_new_task_code(...);
    end
endcase
```

---

## 7. 代码质量检查

### 7.1 Lint检查

```bash
# 运行Lint检查
cd scripts
./lint_check.sh

# 检查特定模块
./lint_check.sh ../rtl/execute/ocpu_alu.sv
```

### 7.2 代码统计

```bash
# 生成统计报告
cd scripts
python3 gen_stats.py
```

输出示例:
```
Total RTL files: 424
Total lines: ~50,000
Modules: 11
Documentation files: 105
```

---

## 8. 性能优化

### 8.1 人类模式优化

| 优化目标 | 方法 |
|----------|------|
| IPC | 提高发射宽度，优化分支预测 |
| Cache命中率 | 改进预取算法，调整Cache大小 |
| 功耗 | 时钟门控，动态电压频率调节 |

### 8.2 Agent模式优化

| 优化目标 | 方法 |
|----------|------|
| 发射效率 | 优化静态调度算法 |
| SRAM利用率 | Bank分配优化 |
| 代码生成 | 改进模板库 |

---

## 9. 故障排除

### 9.1 常见问题

**问题1**: 仿真编译错误
```bash
# 检查SystemVerilog版本
verilator --version  # 需要4.0+

# 检查文件路径
ls -la rtl/include/ocpu_header.sv
```

**问题2**: 测试失败
```bash
# 查看详细日志
cat sim/build/test.log

# 检查波形
make test WAVES=1
```

### 9.2 调试检查清单

- [ ] 时钟和复位信号正确
- [ ] 参数配置匹配
- [ ] 接口连接正确
- [ ] 时序约束满足
- [ ] 无未初始化信号

---

## 10. 贡献指南

### 10.1 提交代码

1. Fork仓库
2. 创建功能分支
3. 编写代码和测试
4. 运行验证
5. 提交Pull Request

### 10.2 代码审查清单

- [ ] 遵循编码规范
- [ ] 添加适当注释
- [ ] 通过Lint检查
- [ ] 通过仿真测试
- [ ] 更新文档

---

## 11. 参考资源

- [OCPU_TRM_3.0.md](../OCPU_TRM_3.0.md) - 技术参考手册
- [DUAL_MODE_ARCHITECTURE_v4.0.md](../DUAL_MODE_ARCHITECTURE_v4.0.md) - 双模架构
- [DIDT_PLAN_3.0.md](../DIDT_PLAN_3.0.md) - 验证计划

---

**版本**: 4.0  
**最后更新**: 2026-02-13
