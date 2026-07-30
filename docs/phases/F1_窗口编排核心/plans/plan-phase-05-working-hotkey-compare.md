# Phase 5: working 热键窗口集合比较

> Phase ID: 5 | slug: working-hotkey-compare
> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) FR-F1-005 / [F1_02](../F1_02_设计文档.md) 第 5 章
> 依赖：Phase 4（Session 快照已扩展，系统通知监听已建立）

## 1. Goal

实现 F1_01 v0.12 的 working 阶段热键窗口集合比较：

- working 阶段用户按热键时，重新枚举前台 App 可见窗口
- 与 Session 快照中的窗口集合比较（CGWindowID 集合）
- 集合相同 → 取消放大 + 回 selecting（保留排列）
- 集合不同 → 触发重排（清空旧快照，走完整 arranging → selecting）

## 2. Architecture / Tech Stack

- 模块：TidyCore（TidyOrchestrator）
- 不涉及 TidyUI / TidyApp 变更
- Swift 5.7+ / SPM

## 3. 文件与职责

| 文件 | 职责变更 |
|------|---------|
| `Sources/TidyCore/Orchestration/TidyOrchestrator.swift` | toggle() 在 working 状态改为集合比较分支；新增 returnToSelectingFromWorking() 与 triggerRearrange() 方法 |
| `Tests/TidyCoreTests/TidyOrchestratorTests.swift` | 新增集合相同 / 集合不同 / 边界（空窗口集 / 单窗口）单元测试 |

## 4. IN / OUT / Dependencies

- **IN**：Phase 4 Session 快照扩展（positionSnapshot.keys 作为窗口标识集合）+ exitToIdlePreservingLayout
- **OUT**：toggle() working 状态集合比较分支；returnToSelectingFromWorking / triggerRearrange 方法
- **Dependencies**：Phase 4

## 5. 任务（2-5 分钟粒度，TDD）

### Task 5.1: 集合相同分支单元测试（红）

- 文件：`Tests/TidyCoreTests/TidyOrchestratorTests.swift`
- 新增 `testWorkingHotkeySameSetReturnsToSelecting()`：
  - state == .working，positionSnapshot 包含窗口 [w1, w2, w3]
  - mock enumerateVisibleWindows 返回 [w1, w2, w3]（顺序可变）
  - 调用 toggle()
  - 断言：
    - setFrame 被调用 1 次（取消放大，恢复放大窗口到 layoutCell.frame）
    - state == .selecting
    - overlay.showOverlay 被调用（cells 与原 layoutCells 一致）
    - startSelectTimeout 与 startKeyEventTap 被调用
- 运行：预期失败（P0 toggle 在 working 时直接 deactivate）

### Task 5.2: 实现 toggle() working 集合比较（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 修改 toggle()：
  ```swift
  public func toggle() {
      switch state {
      case .idle:
          activate()
      case .selecting:
          exitToIdlePreservingLayout()  // Phase 4 已实现
      case .working:
          handleWorkingHotkey()
      case .arranging:
          break
      }
  }
  ```
- 删除原 `case .selecting, .working: deactivate()` 分支
- 新增 `handleWorkingHotkey()`：
  ```swift
  private func handleWorkingHotkey() {
      let currentWindows = windowEnumerator.enumerateVisibleWindows(forPID: frontmostPID)
      let snapshotIDs = Set(positionSnapshot.keys)
      let currentIDs = Set(currentWindows.map { $0.id })

      if snapshotIDs == currentIDs {
          returnToSelectingFromWorking()
      } else {
          triggerRearrange(with: currentWindows)
      }
  }
  ```
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 5.3: 记录放大窗口 ID（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 新增字段 `private var maximizedWindowID: CGWindowID?`
- 在 maximizeAfterActivate 中设置：`maximizedWindowID = window.id`
- 在 exitToIdlePreservingLayout / deactivate / handleAppTerminated(working 分支) 中重置：`maximizedWindowID = nil`
- 运行：`swift test` → 预期通过

### Task 5.4: 实现 returnToSelectingFromWorking（绿）

- 新增 `returnToSelectingFromWorking()`（依赖 Task 5.3 的 maximizedWindowID 字段）：
  ```swift
  private func returnToSelectingFromWorking() {
      // 取消放大：使用 maximizedWindowID 找到放大窗口
      guard let wid = maximizedWindowID,
            let windowIndex = arrangedWindows.firstIndex(where: { $0.id == wid }),
            let originalCell = layoutCells.first(where: { $0.windowIndex == windowIndex })
      else { return }
      let maximizedWindow = arrangedWindows[windowIndex]
      _ = windowManipulator.setFrame(originalCell.frame, for: maximizedWindow)
      maximizedWindowID = nil

      overlay?.showOverlay(cells: layoutCells, on: targetScreenFrame)
      state = .selecting
      startSelectTimeout()
      startKeyEventTap()
  }
  ```
- 运行：`swift test` → 预期通过

### Task 5.5: 集合不同分支单元测试（红）

- 新增 `testWorkingHotkeyDifferentSetTriggersRearrange()`：
  - state == .working，positionSnapshot 包含 [w1, w2, w3]
  - mock enumerateVisibleWindows 返回 [w1, w2, w4]（w3 关闭，w4 新开）
  - 调用 toggle()
  - 断言：
    - 清空旧快照（positionSnapshot 被重新填充）
    - 走完整 arranging → selecting 流程
    - state == .selecting
    - 新 positionSnapshot 包含 [w1, w2, w4]
- 运行：预期失败

### Task 5.6: 实现 triggerRearrange + 重构 acceptArranging（绿）

- **重构 activate() 为两个方法**：
  - `activate()`：公共入口，负责 idle 状态校验 + 枚举窗口 + 10+ 截断 + 调用 acceptArranging
  - `acceptArranging(with windows:)`：arranging 核心逻辑，从 positionSnapshot 开始到 state = .selecting
- **职责划分**：
  ```swift
  public func activate() {
      guard state == .idle else { return }
      let t0 = DispatchTime.now()
      state = .arranging

      let focusedWindow = windowManipulator.focusedWindow(forPID: frontmostPID)
      let targetScreen = displayCoordinator.targetScreen(for: focusedWindow, provider: screenProvider)
      targetScreenFrame = targetScreen.frame

      let windows = windowEnumerator.enumerateVisibleWindows(forPID: frontmostPID)
      let truncated = Array(windows.prefix(9))
      let wasTruncated = windows.count > 9

      guard !truncated.isEmpty else {
          state = .idle
          logPerformance(t0: t0, t1: nil, t2: nil, windowCount: 0, success: false)
          return
      }

      acceptArranging(with: truncated, t0: t0, targetScreen: targetScreen, wasTruncated: wasTruncated)
  }

  private func acceptArranging(with windows: [WindowInfo], t0: DispatchTime, targetScreen: ScreenInfo, wasTruncated: Bool) {
      // 以下逻辑从原 activate() 移入：
      // 1. positionSnapshot = windowManipulator.snapshotWindows(windows)
      // 2. arrangedWindows = windows
      // 3. cells = layoutCalculator.calculateLayout(...)
      // 4. applyLayoutStrict(...)
      // 5. overlay.showOverlay(...)
      // 6. state = .selecting + startSelectTimeout + startKeyEventTap
      // 7. if wasTruncated { overlay.showError("仅排列前 9 个窗口", 2.0) }
      // 8. notificationObserver?.startObserving(...)
      // 9. logPerformance(...)
  }
  ```
- **triggerRearrange 实现**：
  ```swift
  private func triggerRearrange(with newWindows: [WindowInfo]) {
      // 清空旧 Session 快照
      positionSnapshot = [:]
      arrangedWindows = []
      layoutCells = []
      maximizedWindowID = nil
      overlay?.hideOverlay()
      notificationObserver?.stopObserving()

      // 走完整 arranging → selecting 流程
      let truncated = Array(newWindows.prefix(9))
      guard !truncated.isEmpty else {
          state = .idle
          return
      }
      state = .arranging
      let t0 = DispatchTime.now()
      let focusedWindow = windowManipulator.focusedWindow(forPID: frontmostPID)
      let targetScreen = displayCoordinator.targetScreen(for: focusedWindow, provider: screenProvider)
      targetScreenFrame = targetScreen.frame
      acceptArranging(with: truncated, t0: t0, targetScreen: targetScreen, wasTruncated: newWindows.count > 9)
  }
  ```
- 运行：`swift test` → 预期通过

### Task 5.7: 边界 - 空窗口集单元测试

- 新增 `testWorkingHotkeyEmptyWindowsExitsToIdle()`：
  - state == .working，mock enumerateVisibleWindows 返回空数组
  - 调用 toggle()
  - 断言：state == .idle（目标 App 可能已无可见窗口，进入 idle）
- 运行：`swift test` → 预期通过（空集 != 原集合，走 triggerRearrange，acceptArranging 内部判断空窗口进入 idle）

### Task 5.8: 边界 - 单窗口单元测试

- 新增 `testWorkingHotkeySingleWindowExitsToIdle()`：
  - state == .working，原快照有 3 窗口，mock 返回 1 窗口
  - 调用 toggle()
  - 断言：state == .idle（单窗口不触发热键编排，FR-F1-002 边界处理）
- 运行：`swift test` → 预期通过

### Task 5.9: 重排后覆盖层显示单元测试

- 新增 `testRearrangeShowsOverlayWithNewLayout()`：
  - 集合不同触发重排后，断言 overlay.showOverlay 被调用，cells 对应新窗口集合
- 运行：`swift test` → 预期通过

## 6. 验证命令

```bash
swift test --filter TidyOrchestratorTests
swift test
swift build
swiftlint lint --strict
```

## 7. UI 证据（手动）

- 手动测试：进入 working，按热键（窗口集合未变），确认取消放大 + 回 selecting + 覆盖层显示
- 手动测试：进入 working，关闭一个窗口后按热键，确认触发重排 + 新覆盖层显示
- 手动测试：进入 working，新开一个窗口后按热键，确认触发重排
- 截图证据：集合相同回 selecting / 集合不同重排截图

## 8. 提交边界与回滚

- 提交 1：Task 5.1-5.4（集合相同分支 + 放大窗口记录）→ `feat(tidycore): working 热键集合同回 selecting`
- 提交 2：Task 5.5-5.9（集合不同分支 + 边界 + 重排覆盖层）→ `feat(tidycore): working 热键集合异触发重排`

回滚：每个提交独立可回滚。

## 9. AC → Task → Test 映射

| AC | Task | Test |
|----|------|------|
| AC-F1-005 working 热键 | 5.1-5.9 | TC-F1-005-03/04 |
| AC-F1-001 核心闭环（部分） | 5.1-5.4 | TC-F1-001-01/03 |

## 10. Local Gate

- [ ] 所有 Task 5.1-5.9 完成
- [ ] `swift test` 全绿
- [ ] `swiftlint lint --strict` 0 violations
- [ ] `swift build` 成功
- [ ] 手动测试集合相同/不同分支截图已保存
- [ ] 2 个提交已按顺序创建
