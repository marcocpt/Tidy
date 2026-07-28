# AGENTS.md

> 最后更新：2026-07-28 | 版本：v0.3
> 文档状态：草案
> 适用对象：所有在本仓库工作的 AI Agent（Codex / Cursor / Claude Code / Trae 等）

本文档是 AI Agent 在 Tidy 仓库工作的执行纪律入口，与 [docs.md](docs.md) 互补：

- `docs.md` 面向人类协作者，定义文档治理、目录规范与阶段流程；
- `AGENTS.md` 面向 AI Agent，定义执行纪律、任务模板、输出格式与硬约束。

发生冲突时以 `docs.md` 为准；本文档不重复 `docs.md` 已定义的内容。

## 1. 项目概述

**Tidy** 是一个 macOS 系统级窗口编排工具（Menu Bar App），专注"同一 App 多窗口快速切换工作流"：

> 一键铺开前台 App 的所有可见窗口 → 字母选择 → 最大化工作 → 一键还原

- **目标平台**：macOS 12（Monterey）及以上
- **开发工具**：Xcode 14.1+ / Swift 5.7+
- **架构**：SPM 三 target（`TidyCore` 纯逻辑 / `TidyUI` AppKit+SwiftUI / `TidyApp` 入口）
- **当前阶段**：P0_技术探针（准备阶段，未开始）；详见 [docs.md 第 4 节](docs.md#4-阶段推进顺序)

更详细的产品定位、功能优先级、模块组织和状态机定义见：

- [docs/Tidy 窗口管理 App 功能列表.md](docs/Tidy%20窗口管理%20App%20功能列表.md)
- [docs/Tidy 窗口管理 App 市场调研报告.md](docs/Tidy%20窗口管理%20App%20市场调研报告.md)

## 2. 核心执行纪律

### 2.1 上游优先

- 开始任何编码或文档任务前，先按 [docs.md 第 8 节阅读顺序](docs.md#8-阅读顺序) 读取上游文档；
- 上游文档缺失或未批准时**停止编码**，先补齐上游；
- 不以历史归档、旧草案或单个测试现状覆盖当前批准文档；
- 下游文档发现上游不完整或冲突时，必须先修正上游，不得在下游另写一套规则。

### 2.2 Swift 项目硬约束

**Tidy 是 Swift 项目，任何 Git 提交前必须运行 SwiftLint 检查，并修复所有 error 级违规。**

- 提交前命令：`swiftlint lint --strict`（在仓库根目录执行）；
- 配置文件：`.swiftlint.yml`（位于根目录，P0 完成时建立）；
- `warning` 级违规应在同一提交内修复；确实无法修复时必须在 commit message 中显式说明豁免理由；
- CI 流水线必须将 SwiftLint 设为强制门禁；
- 第三方依赖与生成代码允许通过 `excluded` 排除；
- 未配置 `.swiftlint.yml` 前，提交前至少运行 `swiftlint` 默认规则并人工复核输出。

### 2.3 Git 提交规范

文档与代码提交统一使用 Conventional Commits：

```text
<type>(<scope>): <简洁祈使语气主题>
```

- **type**：`feat` / `fix` / `docs` / `refactor` / `test` / `chore` / `build` / `ci` / `perf` / `style`；
- **scope**（可选）：`governance` / `roadmap` / `architecture` / `adr` / `phase-P{n}` / `phase-F{n}` / `standards` / `spec` / `history` / `agents` / `tidycore` / `tidyui` / `tidyapp`；
- 一个提交只处理一个可独立审查的主题；
- 详细规则以后由 `docs/standards/git-commit-message.md` 维护。

**禁止行为**：

- 不得自动 `git commit` 除非用户明确要求；
- 不得 `git push` 除非用户明确要求；
- 不得执行 `--force` / `--force-with-lease` / `reset --hard` / `clean -f` 等破坏性操作除非用户明确要求；
- 不得 `git add -A` 或 `git add .`，应按文件名精确暂存；
- 不得提交 `.env`、credentials、密钥等敏感文件。

### 2.4 会话交互规范

- **所有需要用户决策的问题必须使用 `AskUserQuestion` 工具给出 2~4 个结构化选项**，不得用纯文本提问中断会话；
- 选项中应给出推荐项并在 label 后标注"（推荐）"，放在首位；
- 推荐应基于项目当前阶段、上游文档和技术可行性，不得随意推荐；
- 单次最多提出 4 个问题，每个问题 2~4 个选项；
- 用户可选"Other"提供自定义输入，Agent 应尊重用户最终决定。

### 2.5 浏览器展示规范

- 涉及"浏览器中展示"的需求**直接执行**，不询问用户；
- 执行前确认本地服务器或预览 URL 可用；
- 执行后通过 `OpenPreview` 工具向用户展示可用 URL；
- 如执行失败，再以 `AskUserQuestion` 询问后续方向。

### 2.6 会话收尾规范

- **禁止直接结束会话**；
- 完成用户指派的任务后，必须使用 `AskUserQuestion` 询问用户：
  - 选项应包含"结束会话"与"继续其他任务"两类；
  - 若有自然的后续工作（如 docs.md 第 4 节定义的下一阶段文档），应在选项中显式列出。

## 3. 任务模板

### 3.1 编码任务模板

```text
1. 读取相关上游文档（docs.md 第 8 节阅读顺序）
2. 读取与任务直接相关的代码、测试和 artifact
3. 使用 TodoWrite 拆解任务为 3~8 个可验证步骤
4. 实现每个步骤：
   a. 优先编辑现有文件，不创建新文件
   b. 不添加未要求的功能、注释、类型注解或错误处理
   c. 不为假设性未来需求设计抽象
5. 运行测试验证（XCTest / XCUITest）
6. 运行 swiftlint lint --strict
7. 如需提交：按 2.3 节格式生成 commit message，等待用户确认
8. 完成后用 AskUserQuestion 询问下一步
```

### 3.2 文档任务模板

```text
1. 读取 docs.md 确认文档归属和命名规则
2. 读取相关上游文档
3. 使用 TodoWrite 拆解文档结构
4. 按以下规则编写：
   a. Markdown 标题后必须包含元数据（最后更新 / 版本 / 文档状态）
   b. 仓库内使用相对链接
   c. 中文正文使用中文标点，英文术语保持原文
   d. 不创建指向尚不存在文件的 Markdown 链接，规划路径使用代码格式
   e. 文档末尾维护版本记录
5. 检查同步规则（docs.md 第 6.3 节）
6. 如需提交：使用 docs(<scope>): <主题> 格式
7. 完成后用 AskUserQuestion 询问下一步
```

### 3.3 调试任务模板

```text
1. 复现问题：先写测试或手动操作确认 bug 存在
2. 根因分析：使用 SearchCodebase / Grep / Read 定位问题代码
3. 提出修复方案：如有多方案，用 AskUserQuestion 给出 2~3 个选项
4. 实现修复：最小化改动，不重构周边代码
5. 验证修复：运行测试 + 手动验证
6. 运行 swiftlint lint --strict
7. 记录根因和修复方式（如适用，写入对应 artifact）
8. 完成后用 AskUserQuestion 询问下一步
```

## 4. 输出格式

### 4.1 文本输出

- 中文回复（除非用户用英文提问）；
- 简洁直接，先给结论再展开理由；
- 不重复用户已说明的内容；
- 不使用 emoji 除非用户明确要求；
- 代码引用使用 markdown 链接 `[文件名](file:///绝对路径#L行号)`，不使用纯文本。

### 4.2 代码块

- 提议新代码使用带语言标签的 markdown 代码块；
- 引用现有代码使用 CODE REFERENCES 格式（file:/// 链接）；
- 不在代码块中包含行号；
- 三反引号前必须有空行，不缩进。

### 4.3 任务管理

- 复杂任务（3+ 步骤）必须使用 `TodoWrite` 跟踪进度；
- 每完成一个步骤立即标记为 completed；
- 不在 `TodoWrite` 调用前输出文本；
- 单个 todo 列表最多 10 项。

### 4.4 工具使用

- 读取文件用 `Read`，不用 `cat` / `head` / `tail`；
- 编辑文件用 `Edit`，不用 `sed` / `awk`；
- 创建文件用 `Write`，不用 `echo` / heredoc；
- 搜索文件用 `Glob`，不用 `find`；
- 搜索内容用 `Grep`，不用 `grep` / `rg`；
- 代码语义搜索用 `SearchCodebase`；
- 终端命令用 `RunCommand`，仅在需要 shell 执行时使用。

## 5. 工具链

### 5.1 构建与测试

- 构建：`swift build`（SPM）
- 测试：`swift test`（SPM）或 Xcode Test Navigator
- UI 测试：XCUITest，需在 Xcode 中运行
- Lint：`swiftlint lint --strict`

### 5.2 依赖管理

- 使用 SPM（Swift Package Manager）；
- 依赖声明在 `Package.swift`；
- 不使用 CocoaPods 或 Carthage；
- 第三方依赖通过 `excluded` 排除 SwiftLint 检查。

### 5.3 日志

- 使用 `os_log`，子系统 `com.tidy.windowmanagement`；
- 关键节点 Info 级日志；
- AX 失败、状态机非法转换 Error 级日志；
- 不使用 `print` 或 `NSLog`。

## 6. 项目结构

```text
.                                       # 仓库根目录
├── docs.md                              # 文档治理与目录规范（人类协作者入口）
├── AGENTS.md                            # 本文件（AI Agent 入口）
├── .swiftlint.yml                       # SwiftLint 配置（P0 完成时建立）
├── Package.swift                        # SPM 包定义（P0 完成时建立）
└── docs/
    ├── Tidy 窗口管理 App 功能列表.md       # 功能优先级、模块组织、状态机
    ├── Tidy 窗口管理 App 市场调研报告.md    # 市场定位、风险、商业模式
    ├── Tidy_开发路线图.md                  # 计划路径
    ├── specs/                           # 已实现行为规格
    ├── architecture/                    # 全局架构契约与 ADR
    ├── phases/                          # 准备阶段（P 前缀）+ 功能阶段（F 前缀）
    │   ├── P0_技术探针/                  # 当前准备阶段
    │   └── F0_权限引导/                  # 下一功能阶段（P0 通过后开始）
    ├── standards/                       # 编码规范（4 文件）
    └── historys/                        # 历史归档
```

详细目录规则见 [docs.md 第 1 节](docs.md#1-目标目录)。

## 7. 阶段感知

当前处于 **P0_技术探针** 准备阶段（docs.md 已批准，阶段文档未创建）。

- 允许：创建 `docs/phases/P0_技术探针/` 下的阶段文档（`P0_01_阶段需求与验收.md` 等）；
- 允许：技术探针代码（AX 兼容性、CGEventTap、NSPanel、性能验证等，详见 docs.md 第 4.4 节）；
- 允许：建立 SPM 三 target 骨架（TidyCore / TidyUI / TidyApp 可编译）与 `.swiftlint.yml`；
- 允许：P0 期间探索首批 ADR 主题（激活模型、窗口范围、目标屏幕、还原语义、EventTap 生命周期），F1 验证后冻结；
- 禁止：创建 F0 及以后功能阶段的设计文档、测试用例表或实现计划；
- 禁止：TidyCore / TidyUI / TidyApp 三 target 的完整功能实现（P0 仅做骨架与探针）；
- 禁止：未经兼容性矩阵验证的未来接口。

阶段间依赖与推进规则见 [docs.md 第 4 节](docs.md#4-阶段推进顺序)。

## 8. 版本记录

- **v0.3（2026-07-28）**
  - 同步 docs.md v0.5：恢复 `P0_技术探针` 作为准备阶段，"当前阶段"从 `F0_权限引导` 改回 `P0_技术探针`；
  - 项目结构目录树新增 `P0_技术探针/`（当前准备阶段）与 `F0_权限引导/`（下一功能阶段）；`.swiftlint.yml` 与 `Package.swift` 建立时机改回 P0 完成时；
  - 第 7 节"阶段感知"重写：P0 允许技术探针代码、SPM 骨架与首批 ADR 探索；技术验证集中在 P0，不再分散到 F0/F1；
  - 2.2 节 SwiftLint 配置建立时机改回 P0；2.3 节 `<scope>` 同时支持 `phase-P{n}` 与 `phase-F{n}`；
  - 修正对 docs.md 第 4 节的链接锚点为 `#4-阶段推进顺序`。
- **v0.2（2026-07-28）**
  - 同步 docs.md v0.4 的功能阶段重划分：将"当前阶段"从 `P0_技术探针` 改为 `F0_权限引导`；
  - 项目结构目录树中的 `phases/` 当前阶段目录改为 `F0_权限引导/`，`.swiftlint.yml` 与 `Package.swift` 的建立时机改为 F0 完成时；
  - 第 7 节"阶段感知"重写：F0 允许权限检测代码，技术风险验证（AX 兼容性、CGEventTap、NSPanel 等）分散到对应功能中；
  - 2.2 节 SwiftLint 配置建立时机改为 F0 完成时；
  - 2.3 节 Conventional Commits 的 `<scope>` 由 `phase-P{n}` 改为 `phase-F{n}`；
  - 修正对 docs.md 第 4 节的链接锚点为 `#4-功能推进顺序`。
- **v0.1（2026-07-28）**
  - 建立 AI Agent 执行纪律入口；
  - 定义核心执行纪律：上游优先、SwiftLint 硬约束、Git 提交规范、会话交互规范、浏览器展示规范、会话收尾规范；
  - 提供编码 / 文档 / 调试三类任务模板；
  - 定义输出格式：文本、代码块、任务管理、工具使用；
  - 列出工具链：SPM 构建、XCTest 测试、SwiftLint lint、os_log 日志；
  - 与 docs.md 互补，不重复文档治理与目录规范内容。
