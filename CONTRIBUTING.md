# Contributing to OCPU

感谢您对OCPU项目的兴趣！我们欢迎各种形式的贡献，包括但不限于：

- 报告Bug
- 提交功能请求
- 改进文档
- 提交代码修复
- 添加新功能

## 如何贡献

### 报告问题

如果您发现了Bug或有功能建议，请通过GitHub Issues提交：

1. 检查是否已有相关Issue
2. 创建新Issue，使用相应的模板
3. 提供详细的描述、复现步骤和环境信息

### 提交代码

1. **Fork项目**
   ```bash
   git clone https://github.com/yourusername/ocpu.git
   cd ocpu
   ```

2. **创建分支**
   ```bash
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/issue-number
   ```

3. **进行更改**
   - 遵循代码规范
   - 添加必要的注释
   - 更新相关文档

4. **提交更改**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   git push origin feature/your-feature-name
   ```

5. **创建Pull Request**
   - 填写PR模板
   - 描述更改内容
   - 关联相关Issue

## 代码规范

### SystemVerilog编码规范

1. **文件命名**
   - 模块文件: `ocpu_<module_name>.sv`
   - 头文件: `ocpu_<name>.svh`
   - 测试文件: `tb_<module_name>.sv`

2. **命名规范**
   ```systemverilog
   // 模块名: 小写，下划线分隔
   module ocpu_ifetch_unit;
   
   // 参数: 大写，OCPU_前缀
   parameter OCPU_DATA_WIDTH = 64;
   
   // 信号名: 小写，下划线分隔
   logic [63:0] instruction_data;
   logic        instruction_valid;
   
   // 宏定义: 大写，OCPU_前缀
   `define OCPU_OPCODE_ADD 7'b0110011
   ```

3. **代码风格**
   - 使用2空格缩进
   - 每行不超过100字符
   - 使用`logic`代替`reg`和`wire`
   - 显式指定位宽

4. **注释规范**
   ```systemverilog
   //=========================================================================
   // 模块描述
   // 模块名称: ocpu_example
   // 功能描述: 简要描述模块功能
   // 作者: 姓名
   // 日期: YYYY-MM-DD
   //=========================================================================
   
   module ocpu_example (
     input  wire        clk,           // 时钟信号，上升沿有效
     input  wire        reset_n,       // 复位信号，低电平有效
     input  wire [63:0] data_in,       // 输入数据
     output reg  [63:0] data_out       // 输出数据
   );
   ```

### 提交信息规范

使用[Conventional Commits](https://www.conventionalcommits.org/)格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型说明:**
- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

**示例:**
```
feat(ifetch): add TAGE branch predictor

Implement TAGE (TAgged GEometric history length) predictor
with 4 tables and 1024 entries each.

Closes #123
```

## 测试要求

### 单元测试

- 新功能必须包含单元测试
- 测试覆盖率应达到80%以上
- 使用Verilator或VCS进行仿真

### 测试文件组织

```
tb/
├── common/           # 通用测试平台
├── ifetch/          # ifetch模块测试
├── idecode/         # idecode模块测试
├── ...
└── integration/     # 集成测试
```

### 运行测试

```bash
# 运行所有测试
make test_all

# 运行特定模块测试
make test MODULE=ifetch

# 运行代码覆盖率检查
make coverage
```

## 文档要求

- 更新相关设计文档
- 更新API文档
- 更新README（如需要）
- 添加CHANGELOG条目

## 代码审查流程

1. 提交PR后，自动化测试会运行
2. 至少需要一个维护者审查
3. 解决所有审查意见
4. 通过所有测试
5. 由维护者合并

## 开发环境设置

### 推荐工具

- **编辑器**: VS Code with SystemVerilog扩展
- **仿真**: Verilator 4.100+
- **波形查看**: GTKWave
- **版本控制**: Git

### VS Code配置

推荐安装以下扩展：
- SystemVerilog
- Verilog-HDL/SystemVerilog
- WaveTrace

## 社区

- **讨论区**: GitHub Discussions
- **即时通讯**: [Discord/Telegram/Slack链接]
- **邮件列表**: ocpu-dev@example.com

## 行为准则

### 我们的承诺

为了促进开放和友好的环境，我们作为贡献者和维护者承诺：

- 尊重不同的观点和经验
- 接受建设性的批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

### 不可接受的行为

- 使用带有性暗示的语言或图像
- 挑衅、侮辱/贬损的评论，个人或政治攻击
- 公开或私下的骚扰
- 未经明确许可发布他人的私人信息
- 其他不道德或不专业的行为

## 获取帮助

如果您需要帮助或有任何问题：

1. 查看[文档](docs/)
2. 搜索[Issues](https://github.com/yourusername/ocpu/issues)
3. 在Discussions中提问
4. 联系维护者

## 许可证

通过贡献代码，您同意您的贡献将在[Apache License 2.0](LICENSE)下开源。

---

**感谢您对OCPU项目的贡献！** 🎉
