# F1 跨 Phase 集成计划

> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) / [F1_02](../F1_02_设计文档.md) / [F1_03](../F1_03_测试用例表.md)
> 模式：per-phase-with-integration（Phase ≥ 6 复杂档）

## 1. 目的

本文档描述 F1 阶段 6 个 Phase 之间的依赖关系、集成点、端到端验证场景与 Final Candidate 准备。每个 Phase 的独立计划见 `plan-phase-01` ~ `plan-phase-06`。

## 2. Phase 依赖图

```
Phase 1: layout-alignment (FR-F1-002)
    ↓
Phase 2: ax-failure-policy (FR-F1-006 + 错误提示)
    ↓
Phase 3: selection-timing (FR-F1-003)
    ↓
Phase 4: session-lifecycle (FR-F1-004)
    ↓
Phase 5: working-hotkey-compare (FR-F1-005)
    ↓
Phase 6: tier-a-compatibility (AC-F1-008 + NFR 5.1)
```

依赖关系是线性的：每个 Phase 以前序 Phase 的产物为输入。Phase 6 依赖所有前序 Phase。

## 3. 集成点

### 3.1 Phase 1 → Phase 2: 布局结果与失败检测

- **Phase 1 产出**：GridLayoutCalculator 支持新规则；TidyOrchestrator 按 z-order 排序 + 10+ 截断
- **Phase 2 消费**：applyLayoutStrict 遍历 cells 调用 setFrame，任何失败即终止
- **集成点**：activate() 中 `applyLayoutStrict(cells, windows:)` 调用
- **风险**：Phase 1 的 z-order 排序可能影响失败窗口识别顺序
- **验证**：Phase 2 Task 2.4 单元测试覆盖失败窗口识别

### 3.2 Phase 2 → Phase 3: 错误提示与激活失败

- **Phase 2 产出**：OverlayShowing.showError 协议方法 + OverlayPanel 实现
- **Phase 3 消费**：激活失败时调用 overlay.showError
- **集成点**：selectWindow() 中 handleActivateFailure 调用 overlay?.showError
- **风险**：showError 与 showOverlay 同时调用可能冲突（覆盖层状态不一致）
- **验证**：Phase 3 Task 3.1 单元测试验证激活失败后覆盖层状态

### 3.3 Phase 3 → Phase 4: 选择时序与 Session 退出

- **Phase 3 产出**：selectWindow 完整时序（激活 → 250ms → 放大 / 激活失败 → 提示 + 回 selecting）
- **Phase 4 消费**：selecting 阶段切 App/Space 退出时，需正确处理 isSelectingWindow 标志
- **集成点**：exitToIdlePreservingLayout() 中重置 isSelectingWindow
- **风险**：250ms 延迟期间触发切 App 退出，可能导致 maximizeAfterActivate 在 idle 状态执行
- **验证**：Phase 4 Task 4.5 exitToIdlePreservingLayout 重置 isSelectingWindow；maximizeAfterActivate 已有 `guard state == .selecting` 保护

### 3.4 Phase 4 → Phase 5: Session 快照与集合比较

- **Phase 4 产出**：positionSnapshot 扩展存储窗口标识集合 + exitToIdlePreservingLayout 保留快照
- **Phase 5 消费**：handleWorkingHotkey 比较 positionSnapshot.keys 与 currentWindows IDs
- **集成点**：toggle() working 分支调用 handleWorkingHotkey
- **风险**：Phase 4 的"保留排列"语义导致 positionSnapshot 在 idle 状态仍保留，可能影响下一次 activate
- **验证**：Phase 5 Task 5.6 triggerRearrange 显式清空旧快照；activate() 入口应确认 positionSnapshot 为空或覆盖

### 3.5 Phase 5 → Phase 6: 完整闭环与兼容性

- **Phase 5 产出**：working 热键集合比较完整实现
- **Phase 6 消费**：Tier A App 兼容性回归测试完整闭环
- **集成点**：手动测试 + XCUITest 验证 AC-F1-001~008
- **风险**：真实 App 的 AX 行为可能与 mock 测试不一致
- **验证**：Phase 6 完整兼容性矩阵测试

## 4. 端到端验证场景

### 4.1 场景 1: 核心闭环（AC-F1-001）

```
idle → 热键 → arranging → selecting → 字母 → working → 热键（集合同）→ selecting
```

覆盖 Phase 1（布局）+ Phase 2（AX 失败不触发）+ Phase 3（选择时序）+ Phase 4（Session 保留）+ Phase 5（集合比较）

### 4.2 场景 2: 重排流程（AC-F1-005）

```
idle → 热键 → arranging → selecting → 字母 → working → 关闭窗口 → 热键（集合异）→ arranging → selecting
```

覆盖 Phase 5（集合比较不同分支）+ Phase 1（重排布局）

### 4.3 场景 3: 异常恢复（AC-F1-006）

```
idle → 热键 → arranging（AX 失败）→ idle（半排列 + 提示）
idle → 热键 → arranging → selecting → 字母（激活失败）→ selecting（提示）
```

覆盖 Phase 2（AX 失败即终止）+ Phase 3（激活失败处理）

### 4.4 场景 4: 生命周期退出（AC-F1-004/007）

```
selecting → 切 App → idle（保留排列）
selecting → 切 Space → idle（保留排列）
selecting → 超时 → idle（保留排列）
selecting → Esc → idle（保留排列）
working → 切 App → working（不动作）
working → 切 Space → working（不动作）
working → App 退出 → idle
arranging → App 退出 → idle（按 AX 失败处理）
selecting → App 退出 → idle（保留排列）
```

覆盖 Phase 4（系统通知监听 + 状态×事件矩阵）

### 4.5 场景 5: 边界处理（AC-F1-003）

```
0 窗口 → 静默退出
1 窗口 → 静默退出
10+ 窗口 → 截断到 9 + 提示
```

覆盖 Phase 1（10+ 截断）+ Phase 2（截断提示）

## 5. 集成测试策略

### 5.1 单元测试集成

- 每个 Phase 完成后运行 `swift test` 全套测试
- 确认无回归（前序 Phase 测试仍通过）
- 重点关注 TidyOrchestratorTests（跨 Phase 集成点最多）

### 5.2 手动集成测试

- Phase 5 完成后执行场景 1-5 全部端到端验证
- 使用 Xcode 作为主要测试 App（AX 行为最稳定）
- 记录截图与 os_log 作为证据

### 5.3 CI 集成测试

- Phase 6 编写 XCUITest 用例覆盖场景 1-3
- CI runner 执行 XCUITest + SwiftLint + 单元测试
- 本地禁止执行 XCUITest（用户偏好）

## 6. Final Candidate 准备

### 6.1 候选分支

- 基于 develop 最新提交创建 `feature/F1-window-orchestration` 候选分支
- Phase 6 完成后，所有 Phase 提交已合并到 develop
- 候选 SHA = develop 最新 SHA

### 6.2 完整 CI 验证

- 对候选 SHA 执行完整远程 CI：
  - SwiftLint `--strict`
  - `swift test` 全套单元测试
  - `swift build` 编译检查
  - XCUITest（macOS runner + 辅助功能权限）
- 所有 CI 必须通过才能推进到 Confirmation

### 6.3 证据收集

- 单元测试报告
- XCUITest 报告
- 性能基线报告（F1_04）
- 兼容性回归报告（F1_05）
- 手动测试截图与录屏

## 7. 风险与缓解

### 7.1 AX 失败率风险

- **风险**：FR-F1-006 严格策略（任何失败即终止）在 Finder/系统设置/Electron App 上失败率可能 >5%
- **缓解**：Phase 6 兼容性测试统计失败率；若 >5%，按 F1_01 风险提示重新评估（可能回退为阈值终止或降级保留标签）
- **决策点**：Phase 6 完成后，若失败率 >5%，ASK 用户决策

### 7.2 系统通知监听可靠性

- **风险**：NSWorkspace 通知可能延迟或丢失（特别是 Space 切换通知）
- **缓解**：Phase 4 单元测试使用 mock 验证逻辑；Phase 6 手动测试验证真实通知
- **决策点**：若手动测试发现通知丢失，评估是否增加备用检测机制（如定时轮询 frontmostApp）

### 7.3 250ms 时序竞态

- **风险**：250ms 延迟期间触发切 App/Space 退出，maximizeAfterActivate 可能在 idle 状态执行
- **缓解**：maximizeAfterActivate 已有 `guard state == .selecting` 保护；Phase 3 Task 3.6 验证状态一致性
- **决策点**：若单元测试发现竞态，增加状态校验或取消 pending DispatchQueue

### 7.4 Tier A App 兼容性差异

- **风险**：不同 App 的 AX 行为差异可能导致 Phase 1-5 的实现 在某些 App 上失效
- **缓解**：Phase 6 完整矩阵测试；Phase 1-5 单元测试使用 mock 覆盖逻辑分支
- **决策点**：若特定 App 失败，记录为已知缺陷，评估是否进入 v0.1 Pilot

## 8. 回滚策略

### 8.1 Phase 级回滚

- 每个 Phase 的提交独立可回滚（`git revert <sha>`）
- 回滚某个 Phase 后，需评估对后续 Phase 的影响
- 若回滚 Phase 4（Session 生命周期），Phase 5（working 热键）无法正常工作

### 8.2 整体回滚

- 若 F1 整体无法满足 Exit Gate，回退到 P0 探针状态
- 保留 F1_01/F1_02/F1_03 规格文档与 F1_04-F1_06 计划文档作为后续迭代基础
- 在 F1_01 版本记录中标注回退原因

## 9. Exit Gate 检查清单

F1 Exit Gate = PASS 当且仅当：

- [ ] 所有 Phase 1-6 Local Gate 通过
- [ ] AC-F1-001 ~ AC-F1-008 全部 PASS
- [ ] NFR 5.1 性能门槛已设定并 PASS
- [ ] NFR 5.2 可靠性 PASS（AX 失败不崩溃 / 边界场景安全退出）
- [ ] NFR 5.3 Tier A 兼容性 PASS
- [ ] 无 Blocker / Critical known defect
- [ ] F1_03 测试用例表 AC coverage 无 MISSING
- [ ] Final Candidate CI 全绿
- [ ] 允许进入 v0.1 Pilot

## 10. 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v0.1 | 2026-07-30 | 建立 F1 跨 Phase 集成计划，描述 6 个 Phase 依赖关系、5 个集成点、5 个端到端场景、Final Candidate 准备、4 项风险与缓解 |
