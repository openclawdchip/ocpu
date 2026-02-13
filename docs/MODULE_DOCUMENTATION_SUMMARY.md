# OCPU v4.1 Module Documentation Summary

**版本**: 4.1  
**日期**: 2026-02-13  
**文档总数**: 110+

---

## 新模块文档 (v4.1)

### 共享执行后端相关模块

| 模块 | 路径 | 文档大小 | 说明 |
|------|------|----------|------|
| ocpu_core_v4 | `docs/submodules/core/ocpu_core_v4.md` | 10KB | v4.1顶层集成模块 |
| ocpu_shared_execute_backend | `docs/submodules/core/ocpu_shared_execute_backend.md` | 8KB | 共享执行后端仲裁器 |
| ocpu_execution_unit_pool | `docs/submodules/core/ocpu_execution_unit_pool.md` | 8KB | 38个执行单元池 |
| ocpu_human_mode_frontend | (占位模块) | - | 人类模式前端 |

### Agent模式模块 (v4.0延续)

| 模块 | 路径 | 文档状态 | 说明 |
|------|------|----------|------|
| ocpu_agent_code_generator | `docs/submodules/agent_mode/` | 待创建 | Agent代码生成器 |
| ocpu_agent_static_scheduler | `docs/submodules/agent_mode/` | 待创建 | 静态调度器 |
| ocpu_agent_sram_controller | `docs/submodules/agent_mode/` | 待创建 | SRAM控制器 |
| ocpu_agent_sw_pipeline | `docs/submodules/agent_mode/` | 待创建 | 软件流水线引擎 |

---

## 文档结构总览

### 根目录文档 (11个)

```
OCPU/
├── README.md                               # 项目主页
├── OCPU_TRM_3.0.md                        # 技术参考手册 (26KB)
├── DUAL_MODE_ARCHITECTURE_v4.0.md         # 双模架构设计 (19KB)
├── DIDT_PLAN_3.0.md                       # 验证测试计划 (21KB)
├── CONFIG_UPGRADE_3.0.md                  # 3.0配置升级指南 (6KB)
├── CHANGELOG.md                           # 变更日志 (5KB)
├── CONTRIBUTING.md                        # 贡献指南 (5KB)
├── SECURITY.md                            # 安全策略 (1KB)
├── CODE_OF_CONDUCT.md                     # 行为准则 (3KB)
├── COMPLETE.md                            # 完成状态 (4KB)
└── CONFIG_UPGRADE_2.0.md                  # 2.0配置升级 (5KB)
```

### docs目录文档 (6个)

```
docs/
├── architecture.md                         # 架构设计文档 (8KB)
├── developer_guide.md                      # 开发者指南 (9KB)
├── user_guide.md                           # 用户指南 (10KB)
├── api_reference.md                        # API参考 (9KB)
├── PROJECT_SUMMARY.md                      # 项目总结 (7KB)
└── shared_backend_architecture_v4.1.md     # v4.1共享后端架构 (17KB) ★NEW
```

### 子模块文档 (95+个)

```
docs/submodules/
├── commit/           # 提交单元文档 (3个)
├── core/             # 核心模块文档 (4个) ★新增3个
├── execute/          # 执行单元文档 (7个)
├── idecode/          # 解码单元文档 (1个)
├── ifetch/           # 取指单元文档 (17个)
├── include/          # 头文件文档 (3个)
├── issue/            # 发射单元文档 (4个)
├── level2/           # L2缓存文档 (2个)
├── loadstore/        # 加载存储文档 (4个)
├── mmu/              # MMU文档 (2个)
└── rename/           # 重命名文档 (3个)
```

---

## v4.1 架构文档更新

### 1. 共享执行后端架构

**文档**: `docs/shared_backend_architecture_v4.1.md`

**内容概要**:
- 三层架构设计 (Frontend → Arbitration → Execution)
- 共享执行单元优势 (40-50%面积节省)
- 请求仲裁逻辑
- EU分配策略
- 模式切换流程
- 性能对比

### 2. 模块级文档

**ocpu_shared_execute_backend.md**:
- 功能概述和架构位置
- 详细接口定义 (Human/Agent/EU)
- 仲裁逻辑实现
- EU分配表结构
- 时序描述
- 配置参数

**ocpu_execution_unit_pool.md**:
- 38个执行单元组成
- 各类EU详细设计 (SX/MX/FPU/VPU/LSU)
- 流水线设计
- 时序描述
- 性能特征和峰值计算

**ocpu_core_v4.md**:
- 完整架构框图
- 内部模块连接关系
- Human/Agent工作流程
- 模式切换流程
- 性能指标
- 实例化示例

---

## 文档统计

| 类别 | 数量 | 总大小 |
|------|------|--------|
| 根目录文档 | 11 | ~100KB |
| docs目录 | 6 | ~60KB |
| 子模块文档 | 95+ | ~200KB+ |
| **总计** | **110+** | **~360KB+** |

---

## 快速参考

### 最新文档索引

| 主题 | 文档路径 |
|------|----------|
| 项目概览 | README.md |
| 双模架构 | DUAL_MODE_ARCHITECTURE_v4.0.md |
| 共享后端 | docs/shared_backend_architecture_v4.1.md |
| 架构设计 | docs/architecture.md |
| 开发者指南 | docs/developer_guide.md |
| 用户指南 | docs/user_guide.md |
| API参考 | docs/api_reference.md |
| 技术手册 | OCPU_TRM_3.0.md |

### 模块文档索引

| 模块 | 文档路径 |
|------|----------|
| ocpu_core_v4 | docs/submodules/core/ocpu_core_v4.md |
| ocpu_shared_execute_backend | docs/submodules/core/ocpu_shared_execute_backend.md |
| ocpu_execution_unit_pool | docs/submodules/core/ocpu_execution_unit_pool.md |
| ocpu_dual_mode_controller | docs/submodules/core/ocpu_dual_mode_controller.md |

---

## 文档规范

### 命名规范

- 模块文档: `docs/submodules/<category>/<module_name>.md`
- 架构文档: `docs/<topic>_architecture_v<version>.md`
- 用户文档: `docs/<topic>_guide.md`

### 文档模板

每个模块文档包含:
1. 功能概述
2. 接口定义
3. 功能描述
4. 时序描述
5. 配置参数
6. 使用示例
7. 版本历史

---

**最后更新**: 2026-02-13  
**维护者**: OCPU Team
