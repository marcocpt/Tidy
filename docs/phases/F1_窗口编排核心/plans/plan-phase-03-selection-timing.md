# Phase 3: 选择时序增强

> Phase ID: 3 | slug: selection-timing
> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) FR-F1-003 / [F1_02](../F1_02_设计文档.md) 第 3 章
> 依赖：Phase 2（覆盖层错误提示模式已建立）

## 1. Goal

对齐 F1_01 v0.12 的选择时序设计：

- 激活失败处理：不放大 + 覆盖层提示失败原因 2 秒 + 回 selecting
- 250ms 延迟期间忽略后续按键（含同一字母与其他字母）
- 放大无内缩（Phase 1 已删除 4pt 内缩，本 Phase 确认无回归）

## 2. Architecture / Tech Stack

- 模块：TidyCore（TidyOrchestrator）
- 不涉及 TidyUI / TidyApp 变更
- Swift 5.7+ / SPM

## 3. 文件与职责

| 文件 | 职责变更 |
|------|---------|
| `Sources/TidyCore/Orchestration/TidyOrchestrator.swift` | selectWindow() 新增激活失败分支；maximizeAfterActivate 确认无内缩 |
| `Tests/TidyCoreTests/TidyOrchestratorTests.swift` | 新增激活失败处理 / 250ms 按键忽略单元测试 |

## 4. IN / OUT / Dependencies

- **IN**：Phase 2 OverlayShowing.showError 协议方法
- **OUT**：selectWindow 激活失败分支；250ms 按键忽略明确化
- **Dependencies**：Phase 2

## 5. 任务（2-5 分钟粒度，TDD）

### Task 3.1: 激活失败处理单元测试（红）

- 文件：`Tests/TidyCoreTests/TidyOrchestratorTests.swift`
- 新增 `testSelectWindowHandlesActivateFailure()`：mock activateWindow 返回 .failed，断言：
  - 不调用 setFrame（不放大）
  - 调用 overlay.showError(窗口标题 + 错误码, 2.0)
  - state == .selecting（保持）
  - isSelectingWindow == false
  - 重启 selectTimeout 与 eventTap
- 运行：预期失败（P0 未处理 activateResult == .failed）

### Task 3.2: 实现激活失败分支（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift` selectWindow()
- 在 `let activateResult = windowManipulator.activateWindow(window)` 后：
  ```swift
  switch activateResult {
  case .success:
      break  // 继续放大流程
  case .failed(_, let reason):
      handleActivateFailure(window: window, reason: reason)
      return
  }
  ```
- 新增 `handleActivateFailure(window:reason:)`：
  ```swift
  private func handleActivateFailure(window: WindowInfo, reason: String) {
      isSelectingWindow = false
      let errorText = "\(window.title) — \(reason)"
      overlay?.showError(text: errorText, duration: 2.0)
      // 保持 state == .selecting，重启超时与 EventTap
      startSelectTimeout()
      startKeyEventTap()
      os_log("tidy.select FAIL wid=%llu reason=%{public}@", ...)
  }
  ```
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 3.3: 250ms 按键忽略单元测试（红）

- 新增 `testSelectWindowIgnoresSubsequentKeysDuring250ms()`：
  - 调用 selectWindow("a") 触发激活阶段
  - 250ms 内再次调用 selectWindow("b")
  - 断言：第二次调用被忽略（isSelectingWindow == true 时返回）
  - 只触发一次 activate + maximize
- 运行：预期通过（P0 已有 isSelectingWindow 标志，需确认逻辑覆盖）

### Task 3.4: 确认 250ms 按键忽略逻辑（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift` selectWindow()
- 确认 `guard !isSelectingWindow else { return }` 在 selectWindow 入口（P0 已有 L184）
- 确认 isSelectingWindow 在激活阶段前置设置为 true（P0 已有 L198）
- 确认 isSelectingWindow 在 maximizeAfterActivate 的 defer 中重置（P0 已有 L228）
- 若逻辑完整，本 Task 为验证性测试，无需代码变更
- 运行：`swift test` → 预期通过

### Task 3.5: 激活失败后状态一致性测试

- 新增 `testStateConsistentAfterActivateFailure()`：
  - 激活失败后，selecting 状态保持
  - 超时计时器重启（可再次触发超时退出）
  - EventTap 重启（可再次拦截按键）
  - 用户按其他字母仍能正常选择
- 运行：`swift test` → 预期通过

> **注**：放大无内缩验证已移至 Phase 1 Task 1.11（与放大逻辑变更同 Phase）。

## 6. 验证命令

```bash
swift test --filter TidyOrchestratorTests
swift test
swift build
swiftlint lint --strict
```

## 7. UI 证据（手动）

- 手动测试：触发编排进入 selecting，按字母选择一个 AX 行为不稳定的窗口（如系统设置子窗口），确认覆盖层显示错误文本 2 秒 + 回 selecting
- 手动测试：进入 selecting，快速连按多个字母，确认只触发一次选择流程
- 截图证据：激活失败错误提示截图

## 8. 提交边界与回滚

- 提交 1：Task 3.1-3.2（激活失败处理）→ `feat(tidycore): 选择时序激活失败处理`
- 提交 2：Task 3.3-3.5（250ms 按键忽略验证 + 状态一致性）→ `test(tidycore): 选择时序 250ms 按键忽略与状态一致性测试`

回滚：每个提交独立可回滚。

## 9. AC → Task → Test 映射

| AC | Task | Test |
|----|------|------|
| AC-F1-006 激活失败 | 3.1-3.2, 3.5 | TC-F1-006-03 |
| AC-F1-001 核心闭环（部分） | 3.3-3.4 | TC-F1-001-03, TC-F1-006-04 |

## 10. Local Gate

- [ ] 所有 Task 3.1-3.5 完成
- [ ] `swift test` 全绿
- [ ] `swiftlint lint --strict` 0 violations
- [ ] `swift build` 成功
- [ ] 手动测试激活失败错误提示截图已保存
- [ ] 2 个提交已按顺序创建
