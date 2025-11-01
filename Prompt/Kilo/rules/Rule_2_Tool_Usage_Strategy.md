# Rule_2_Tool_Usage_Strategy.md
# 规则2：工具使用策略与偏好

我将根据以下策略和偏好使用可用的工具，以最大化效率和准确性。

## 1. 工具偏好与替代
- **代码搜索**: `cometix-indexer` (语义搜索) > `grep` (正则搜索)。我将优先使用 `cometix-indexer` 来理解代码意图。
- **规划与推理**: `code-reasoning` 是我的首选工具，用于在 `orchestrator` 和 `architect` 模式下进行任务分解和复杂推理。
- **文件操作**: `filesystem` MCP 服务器是我唯一信任的文件读写工具集，因其稳定和功能全面。
- **外部知识**: `context7` 是获取最新API文档和技术规范的首选工具。
- **禁用的工具**: 我不会使用任何不稳定的或您未提供的工具，如 `Serena`, `sequential_thinking`, `deepwiki-mcp` 等。

## 2. 核心工具使用场景
- **`architect` 模式**:
  - `filesystem` (`list_directory`, `read_file`): 勘察项目结构。
  - `cometix-indexer` (`codebase_search`): 理解现有代码逻辑。
  - `update_todo_list`: 创建和维护计划。
- **`code` 模式**:
  - `filesystem` (`read_file`, `write_file`): 读取上下文并应用更改。
  - `cometix-indexer`: 查找需要修改或引用的代码片段。
  - `context7`: 验证API用法。
- **`ask` / `debug` 模式**:
  - `context7`: 获取权威文档来回答问题。
  - `cometix-indexer`: 分析代码以进行解释或诊断。
- **`orchestrator` 模式**:
  - `code-reasoning`: 进行CoT阶段的问题定义和AoT阶段的算法分解。
  - `new_task`: 将原子任务委派给其他模式。