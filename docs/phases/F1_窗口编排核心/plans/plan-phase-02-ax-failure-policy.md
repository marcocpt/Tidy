# Phase 2: AX 失败策略 + 覆盖层错误提示

> Phase ID: 2 | slug: ax-failure-policy
> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) FR-F1-006 / [F1_02](../F1_02_设计文档.md) 第 6、7 章
> 依赖：Phase 1（a 标签分配后才能正确识别失败窗口）

## 1. Goal

将 P0 的"跳过 + >50% 终止 + 还原"策略改为 F1_01 v0.12 的"任何失败即终止 + 不回滚"策略，并扩展覆盖层支持错误提示模式：

- arranging 阶段任何窗口 setFrame 失败 → 立即终止 + 不回滚 + 覆盖层提示失败原因 2 秒
- 覆盖层扩展 `showError(text:duration:)` 协议方法
- 10+ 窗口截断提示复用错误提示模式（Phase 1 留的 TODO）

## 2. Architecture / Tech Stack

- 模块：TidyCore（TidyOrchestrator / TidyOrchestratorTypes）+ TidyUI（OverlayPanel）
- TidyCore 定义 OverlayShowing 协议扩展；TidyUI 实现
- 不涉及 TidyApp 变更（注入点不变）
- Swift 5.7+ / SPM

## 3. 文件与职责

| 文件 | 职责变更 |
|------|---------|
| `Sources/TidyCore/Orchestration/TidyOrchestratorTypes.swift` | OverlayShowing 协议新增 `showError(text:duration:)` 方法 |
| `Sources/TidyCore/Orchestration/TidyOrchestrator.swift` | activate() 改为任何失败即终止 + 不回滚；删除 applyLayoutWithFallback 的降级标签逻辑；触发截断提示 |
| `Sources/TidyUI/Overlay/OverlayPanel.swift` | 实现 `showError(text:duration:)`：显示错误文本 2 秒后自动消失 |
| `Tests/TidyCoreTests/TidyOrchestratorTests.swift` | 新增任何失败即终止 / 不回滚 / 截断提示单元测试 |

## 4. IN / OUT / Dependencies

- **IN**：Phase 1 布局算法（z-order 排序 + 10+ 截断）
- **OUT**：TidyOrchestrator 任何失败即终止；OverlayShowing 协议支持错误提示；OverlayPanel 错误模式实现
- **Dependencies**：Phase 1

## 5. 任务（2-5 分钟粒度，TDD）

### Task 2.1: OverlayShowing 协议扩展单元测试（红）

- 文件：`Tests/TidyCoreTests/TidyOrchestratorTests.swift`
- 新增 `testOverlayShowingProtocolHasShowError()`：定义 MockOverlayShowing 实现 showError，断言协议方法存在
- 运行：预期编译失败（协议无 showError 方法）

### Task 2.2: 扩展 OverlayShowing 协议（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestratorTypes.swift`
- OverlayShowing 协议新增：
  ```swift
  func showError(text: String, duration: TimeInterval)
  ```
- 运行：编译失败（OverlayPanel 未实现）→ 继续 Task 2.3

### Task 2.3: OverlayPanel 实现 showError（绿）

- 文件：`Sources/TidyUI/Overlay/OverlayPanel.swift`
- **当前状态**：OverlayPanel 只有 OverlayLabelView（字母标签视图），无错误文本视图。本 Task 需新增错误提示基础设施。
- **实现步骤**：
  1. 新增 `OverlayErrorView` 私有类（NSTextField 子类或 NSView 包裹 NSTextField）：
     - 半透明背景（与 OverlayLabelView 一致的视觉风格）
     - 居中显示错误文本（窗口标题 + 错误码）
     - 字体大小适配可读性（建议 14-16pt）
  2. OverlayPanel 新增 `private var errorView: OverlayErrorView?` 字段
  3. 实现 `showError(text:duration:)`：
     - 隐藏标签视图（若可见）：`clearLabels()`
     - 创建或复用 errorView，设置文本
     - errorView.frame 居中偏上动态约束（panel.contentView.bounds 中心，y 偏上 1/4）
     - 添加为 panel.contentView 子视图
     - `panel.orderFrontRegardless()` 显示
     - `DispatchQueue.main.asyncAfter(deadline: .now() + duration)` 后调用 `hideError()`
  4. 新增 `private func hideError()`：移除 errorView + `panel.orderOut(nil)`
- **与 showOverlay 的互斥**：showError 调用 clearLabels 隐藏标签；showOverlay 调用时应先 hideError
- 运行：`swift build` → 预期编译通过

### Task 2.4: 任何失败即终止单元测试（红）

- 文件：`Tests/TidyCoreTests/TidyOrchestratorTests.swift`
- 新增 `testActivateAbortsOnAnySetFrameFailure()`：mock setFrame 第 2 个窗口返回 .failed，断言：
  - state == .idle
  - 不调用第 3 个窗口 setFrame
  - 不调用 restoreWindows
  - 调用 overlay.showError
- 运行：预期失败（P0 走 >50% 终止 + 还原）

### Task 2.5: 重写 applyLayout 为任何失败即终止（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 删除 `applyLayoutWithFallback` 方法
- 新增 `applyLayoutStrict` 方法：
  ```swift
  private func applyLayoutStrict(_ cells: [LayoutCell], windows: [WindowInfo]) -> Bool {
      for cell in cells {
          guard cell.windowIndex < windows.count else { break }
          let window = windows[cell.windowIndex]
          let result = windowManipulator.setFrame(cell.frame, for: window)
          if result != .success {
              // 任何失败即终止
              handleArrangeFailure(window: window, result: result)
              return false
          }
      }
      return true
  }
  ```
- activate() 中：
  ```swift
  let success = applyLayoutStrict(cells, windows: windows)
  guard success else {
      state = .idle
      logPerformance(t0: t0, t1: t1, t2: nil, windowCount: windows.count, success: false)
      return
  }
  layoutCells = cells
  ```
- 删除 `failedCount > windows.count / 2` 分支与 `restoreWindows` 调用
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 2.6: 失败提示处理方法

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 新增 `handleArrangeFailure(window:result:)`：
  ```swift
  private func handleArrangeFailure(window: WindowInfo, result: WindowOperationResult) {
      let errorText: String
      switch result {
      case .failed(_, let reason):
          errorText = "\(window.title) — \(reason)"
      case .success:
          return
      }
      overlay?.showError(text: errorText, duration: 2.0)
      os_log("tidy.arrange FAIL wid=%llu reason=%{public}@", ...)
  }
  ```
- 运行：`swift test` → 预期通过

### Task 2.7: 已排列窗口保留单元测试（红）

- 新增 `testActivateKeepsArrangedWindowsOnFailure()`：mock 第 2 个窗口失败，断言第 1 个窗口保留新位置（不被还原）
- 运行：预期通过（Task 2.5 已删除 restoreWindows）

### Task 2.8: 10+ 截断提示接入（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift` activate()
- 替换 Phase 1 的 TODO：
  ```swift
  if wasTruncated {
      overlay?.showError(text: "仅排列前 9 个窗口", duration: 2.0)
  }
  ```
- 注意：截断提示与标签显示不冲突（showError 独立显示 2 秒，标签持续显示）
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 2.9: 删除降级标签逻辑

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 删除 `applyLayoutWithFallback` 中失败窗口使用原 frame 显示标签的逻辑（已由 Task 2.5 替换）
- 删除相关 os_log `tidy.arrange FAIL label=...` 日志（由 handleArrangeFailure 替代）
- 运行：`swift test` → 预期通过

## 6. 验证命令

```bash
swift test --filter TidyOrchestratorTests
swift test
swift build
swiftlint lint --strict
```

## 7. UI 证据（手动）

- 手动测试：在系统设置中触发编排（预期 AX 失败），确认覆盖层显示错误文本 2 秒后消失
- 手动测试：在 Finder 中打开 12 个窗口，确认覆盖层显示"仅排列前 9 个窗口"提示 2 秒 + 排列 9 个窗口
- 截图证据：错误提示覆盖层截图

## 8. 提交边界与回滚

- 提交 1：Task 2.1-2.3（OverlayShowing 协议扩展 + OverlayPanel 实现）→ `feat(tidyui): 覆盖层扩展错误提示模式`
- 提交 2：Task 2.4-2.6（任何失败即终止 + 不回滚）→ `refactor(tidycore): AX 失败策略改为任何失败即终止+不回滚`
- 提交 3：Task 2.7-2.9（保留已排列 + 截断提示 + 删除降级标签）→ `feat(tidycore): 10+ 窗口截断提示接入错误模式`

回滚：每个提交独立可回滚。

## 9. AC → Task → Test 映射

| AC | Task | Test |
|----|------|------|
| AC-F1-006 arranging AX 失败 | 2.4-2.6, 2.7 | TC-F1-006-01/02 |
| AC-F1-003 10+ 截断提示 | 2.8 | TC-F1-003-02/03 |

## 10. Local Gate

- [ ] 所有 Task 2.1-2.9 完成
- [ ] `swift test` 全绿
- [ ] `swiftlint lint --strict` 0 violations
- [ ] `swift build` 成功
- [ ] 手动测试错误提示覆盖层截图已保存
- [ ] 3 个提交已按顺序创建
