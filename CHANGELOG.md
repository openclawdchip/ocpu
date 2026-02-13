# OCPU 变更日志

所有重要变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

---

## [4.0.0] - 2026-02-13

### 🎉 重大更新 - 双模架构

新增革命性的**双模处理器架构**，支持人类模式（OOO）和Agent模式（静态调度）。

#### 新增功能

- **Agent模式**: 全新的静态调度执行模式
  - Agent代码生成器 - 任务描述符到机器码的实时转换
  - 静态调度单元 - 确定性16发射调度
  - 16 Bank SRAM控制器 - 直接访问，无Cache
  - 软件流水线引擎 - 自动循环流水化

- **双模控制器**: 支持人类模式和Agent模式无缝切换
  - 模式切换状态机
  - 上下文保存/恢复
  - Cache到SRAM的数据迁移

- **新增RTL文件** (4个核心模块)
  - `ocpu_dual_mode_defs.sv` - 双模架构定义
  - `ocpu_agent_static_scheduler.sv` - 静态调度单元
  - `ocpu_agent_sram_controller.sv` - SRAM控制器
  - `ocpu_agent_code_generator.sv` - 代码生成器
  - `ocpu_dual_mode_controller.sv` - 双模控制器

#### 文档更新

- 新增 `DUAL_MODE_ARCHITECTURE_v4.0.md` - 双模架构设计文档
- 更新 `README.md` - 项目主文档
- 更新 `docs/architecture.md` - 架构设计文档
- 新增 `docs/user_guide.md` - 用户指南
- 新增 `docs/api_reference.md` - API参考
- 更新 `docs/developer_guide.md` - 开发者指南

---

## [3.0.0] - 2026-02-13

### 🚀 性能升级版本

全面升级处理器配置，从7nm/128-bit升级到3nm/512-bit架构。

#### 架构升级

- **工艺节点**: 7nm → 3nm
- **总线宽度**: 128-bit → 512-bit (4x带宽)
- **发射宽度**: 4 → 16
- **ROB深度**: 64 → 256
- **物理寄存器**: 128 → 512
- **L2缓存**: 1MB → 4MB

#### 执行单元扩展

- SX ALU: 2 → 10
- MX MAC: 1 → 6
- FPU: 1 → 6
- VPU: 2 → 8 (1024-bit VLEN)
- LSU: 2 → 8
- BRU: 1 → 4
- DIV: 1 → 2

#### 文档新增

- `OCPU_TRM_3.0.md` - 技术参考手册 (26KB, 16章)
- `DIDT_PLAN_3.0.md` - Design Intent Driven Test验证计划
- `CONFIG_UPGRADE_3.0.md` - 3.0配置升级指南

#### RTL v3.0文件

- `ocpu_ifetch_v3.sv` - v3.0取指单元
- `ocpu_idecode_v3.sv` - v3.0解码单元
- `ocpu_execute_v3.sv` - v3.0执行单元

---

## [2.0.0] - 2026-02-12

### 🔧 架构完善版本

完成所有模块RTL实现，总文件数扩展至420个。

#### 完成模块

- ✅ **ifetch/** - 40文件 (分支预测，I-Cache，预取器，TLB)
- ✅ **idecode/** - 40文件 (解码器，微操作生成，RVC支持)
- ✅ **rename/** - 40文件 (RAT，freelist，检查点，恢复逻辑)
- ✅ **issue/** - 38文件 (记分板，调度器，仲裁器，唤醒逻辑)
- ✅ **execute/** - 54文件 (ALU，MAC，DIV，FPU，VPU，分支)
- ✅ **loadstore/** - 43文件 (LSU，D-Cache，Store/Load Buffer)
- ✅ **commit/** - 41文件 (ROB，异常处理，CSR支持)
- ✅ **mmu/** - 40文件 (TLB层次，PTW，PMP)
- ✅ **level2/** - 41文件 (L2缓存，CHI协议，一致性)
- ✅ **core/** - 40文件 (Hart管理，中断，定时器，调试)
- ✅ **include/** - 3文件 (全局头文件，参数，定义)

#### 总计

- **420 SystemVerilog文件**
- **~50,000行RTL代码**
- **90+ 文档文件**

#### GitHub准备

- Issue模板 (bug报告，功能请求)
- Pull Request模板
- CI/CD工作流 (测试，Lint，综合)
- 发布工作流

---

## [1.1.0] - 2026-02-11

### 📚 文档完善

#### 新增文档

- 模块设计文档 (15个)
- 子模块文档 (40+个)
- GitHub模板
- 开发指南

#### 脚本工具

- `setup.sh` - 安装脚本
- `lint_check.sh` - Lint检查
- `gen_stats.py` - 统计生成
- `run_tests.py` - 测试运行

---

## [1.0.0] - 2026-02-10

### 🎉 初始版本

项目初始化和基础架构。

#### 基础实现

- 核心架构设计
- 基础RTL模块 (131文件)
- 仿真环境
- 测试平台

#### 初始模块

- ifetch/ - 取指单元
- idecode/ - 解码单元
- rename/ - 重命名单元
- issue/ - 发射单元
- execute/ - 执行单元
- loadstore/ - 加载存储单元
- commit/ - 提交单元

---

## 版本对比

| 版本 | 日期 | RTL文件 | 主要特性 |
|------|------|---------|----------|
| 1.0.0 | 2026-02-10 | 131 | 基础架构 |
| 2.0.0 | 2026-02-12 | 420 | 完整实现 |
| 3.0.0 | 2026-02-13 | 424 | 3nm + 512-bit |
| 4.0.0 | 2026-02-13 | 428 | 双模架构 |

---

## 未来计划

### [4.1.0] - 计划

- [ ] 更多Agent任务类型
- [ ] 多Agent协作调度
- [ ] 自适应代码生成优化
- [ ] GPU-like计算模式

### [5.0.0] - 计划

- [ ] 多核支持
- [ ] 片上网络 (NoC)
- [ ] 内存控制器集成
- [ ] PCIe接口

---

**格式**: [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)  
**版本号**: [Semantic Versioning](https://semver.org/lang/zh-CN/)
