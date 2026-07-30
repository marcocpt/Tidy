# Phase 4: Session 快照 + 系统通知监听

> Phase ID: 4 | slug: session-lifecycle
> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) FR-F1-004 / [F1_02](../F1_02_设计文档.md) 第 4 章
> 依赖：Phase 3（selecting 状态机已增强）

## 1. Goal

实现 F1_01 v0.12 的状态×事件矩阵（唯一行为真值）：

- Session 快照扩展存储窗口标识集合（用于 Phase 5 集合比较）
- 系统通知监听新模块：Space 切换 / App 切换 / App 退出
- selecting 阶段切 App/Space → idle + 保留排列
- working 阶段切 App/Space → 不动作（保留 Session）
- 目标 App 退出三阶段区分：arranging 按 AX 失败处理 / selecting → idle + 保留 / working → idle
- selecting 超时 / Esc → idle + 保留排列（对齐"保留排列"语义，不还原窗口）

## 2. Architecture / Tech Stack

- 模块：TidyCore（TidyOrchestrator + 新建 SystemNotificationObserver）
- TidyCore 定义 SystemNotificationObserving 协议；TidyApp 注入 NSWorkspace 实现
- 不涉及 TidyUI 变更
- Swift 5.7+ / SPM

## 3. 文件与职责

| 文件 | 职责变更 |
|------|---------|
| `Sources/TidyCore/Orchestration/SystemNotificationObserver.swift` | 新建：定义 SystemNotificationObserving 协议 + 默认实现（监听 NSWorkspace 通知） |
| `Sources/TidyCore/Orchestration/TidyOrchestratorTypes.swift` | 新增 SystemNotificationObserving 协议定义 |
| `Sources/TidyCore/Orchestration/TidyOrchestrator.swift` | 注入 SystemNotificationObserver；实现 onAppActivated / onSpaceChanged / onAppTerminated 回调；deactivate 改为不清空快照（保留排列语义） |
| `Sources/TidyCore/Orchestration/TidyOrchestrator.swift` | selecting 超时 / Esc 改为"进入 idle + 保留排列"（不调用 restoreWindows） |
| `Sources/TidyApp/TidyApp.swift` | 注入 SystemNotificationObserver 到 TidyOrchestrator |
| `Tests/TidyCoreTests/TidyOrchestratorTests.swift` | 新增切 App/Space 退出 / App 退出三阶段 / 超时保留排列 / Esc 保留排列单元测试 |
| `Tests/TidyCoreTests/SystemNotificationObserverTests.swift` | 新建：SystemNotificationObserver 单元测试 |

## 4. IN / OUT / Dependencies

- **IN**：Phase 3 选择时序增强
- **OUT**：SystemNotificationObserver 模块；TidyOrchestrator 通知处理；selecting 退出保留排列语义
- **Dependencies**：Phase 3

## 5. 任务（2-5 分钟粒度，TDD）

### Task 4.1: SystemNotificationObserving 协议定义（红）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestratorTypes.swift`
- 新增协议：
  ```swift
  public protocol SystemNotificationObserving: AnyObject {
      func startObserving(
          onAppActivated: @escaping (pid_t) -> Void,
          onSpaceChanged: @escaping () -> Void,
          onAppTerminated: @escaping (pid_t) -> Void
      )
      func stopObserving()
  }
  ```
- 文件：`Tests/TidyCoreTests/SystemNotificationObserverTests.swift`
- 新增 `testProtocolExists()`：定义 MockSystemNotificationObserver 实现协议
- 运行：预期编译失败（无 SystemNotificationObserver 实现）

### Task 4.2: SystemNotificationObserver 实现（绿）

- 文件：`Sources/TidyCore/Orchestration/SystemNotificationObserver.swift`
- 实现 `SystemNotificationObserving`：
  ```swift
  public final class SystemNotificationObserver: SystemNotificationObserving {
      private var appActivatedObserver: NSObjectProtocol?
      private var spaceChangedObserver: NSObjectProtocol?
      private var appTerminatedObserver: NSObjectProtocol?
      private var onAppActivated: ((pid_t) -> Void)?
      private var onSpaceChanged: (() -> Void)?
      private var onAppTerminated: ((pid_t) -> Void)?

      public init() {}

      public func startObserving(...) {
          appActivatedObserver = NSWorkspace.shared.notificationCenter.addObserver(
              forName: NSWorkspace.didActivateApplicationNotification, ...
          ) { note in
              guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
              self.onAppActivated?(app.processIdentifier)
          }
          // spaceChanged: activeSpaceDidChangeNotification
          // appTerminated: didTerminateApplicationNotification
      }

      public func stopObserving() {
          // 移除所有 observer
      }
  }
  ```
- 注意：TidyCore 不依赖 AppKit，但 NSWorkspace 通过 AppKit 暴露。需要：
  - 方案 A：TidyCore 引入 AppKit（违反 INV-001）
  - 方案 B：SystemNotificationObserver 放在 TidyUI 或 TidyApp 层
  - **方案 C（推荐）**：协议在 TidyCore，实现在 TidyApp（NSWorkspace 访问层）
- 采用方案 C：SystemNotificationObserver 实现移到 `Sources/TidyApp/SystemNotificationObserver.swift`
- 运行：`swift build` → 预期编译通过

### Task 4.3: TidyOrchestrator 注入 observer（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- init 新增参数 `notificationObserver: SystemNotificationObserving?`
- 在 activate() 进入 arranging 时调用 `notificationObserver?.startObserving(...)`：
  ```swift
  notificationObserver?.startObserving(
      onAppActivated: { [weak self] pid in self?.handleAppActivated(pid) },
      onSpaceChanged: { [weak self] in self?.handleSpaceChanged() },
      onAppTerminated: { [weak self] pid in self?.handleAppTerminated(pid) }
  )
  ```
- 在 deactivate() 或进入 idle 时调用 `notificationObserver?.stopObserving()`
- 运行：`swift build` → 预期编译通过

### Task 4.4: selecting 切 App 退出单元测试（红）

- 新增 `testSelectingExitsOnAppSwitch()`：state == .selecting, frontmostPID=1234，触发 onAppActivated(5678)，断言：
  - state == .idle
  - 保留排列（arrangedWindows 非空）
  - 隐藏覆盖层
  - 停止 EventTap 与超时
  - 不调用 restoreWindows
- 运行：预期失败

### Task 4.5: 实现 handleAppActivated（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 新增 `handleAppActivated(_ pid: pid_t)`：
  ```swift
  private func handleAppActivated(_ pid: pid_t) {
      switch state {
      case .selecting:
          if pid != frontmostPID {
              exitToIdlePreservingLayout()
          }
      case .working:
          // 不动作，保留 Session
          break
      case .arranging, .idle:
          break
      }
  }
  ```
- 新增 `exitToIdlePreservingLayout()`：
  ```swift
  private func exitToIdlePreservingLayout() {
      stopSelectTimeout()
      eventTapManager.stopTap()
      overlay?.hideOverlay()
      // 不调用 restoreWindows，保留排列
      // 不清空 positionSnapshot / arrangedWindows / layoutCells（保留 Session）
      isSelectingWindow = false
      state = .idle
  }
  ```
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 4.6: selecting 切 Space 退出单元测试（红）

- 新增 `testSelectingExitsOnSpaceChange()`：state == .selecting，触发 onSpaceChanged，断言同 Task 4.4
- 运行：预期失败

### Task 4.7: 实现 handleSpaceChanged（绿）

- 新增 `handleSpaceChanged()`：逻辑同 handleAppActivated（selecting → idle 保留排列；working 不动作）
- 运行：`swift test` → 预期通过

### Task 4.8: working 切 App/Space 不动作单元测试（红）

- 新增 `testWorkingNoActionOnAppSwitch()`：state == .working, frontmostPID=1234，触发 onAppActivated(5678)，断言 state == .working，不调用 setFrame
- 新增 `testWorkingNoActionOnSpaceChange()`：state == .working，触发 onSpaceChanged，断言同上
- 运行：预期通过（Task 4.5/4.7 已实现 working 不动作分支）

### Task 4.9: App 退出三阶段单元测试（红）

- 新增 `testArrangingExitsOnAppTerminate()`：state == .arranging, frontmostPID=1234，触发 onAppTerminated(1234)，断言按 AX 失败处理（state == .idle，不回滚，提示）
- 新增 `testSelectingExitsOnAppTerminate()`：state == .selecting，触发 onAppTerminated，断言 state == .idle + 保留排列
- 新增 `testWorkingExitsOnAppTerminate()`：state == .working，触发 onAppTerminated，断言 state == .idle（放弃 working，不恢复）
- 运行：预期失败

### Task 4.10: 实现 handleAppTerminated（绿）

- 新增 `handleAppTerminated(_ pid: pid_t)`：
  ```swift
  private func handleAppTerminated(_ pid: pid_t) {
      guard pid == frontmostPID else { return }
      switch state {
      case .arranging:
          // 按 AX 失败处理（不回滚 + 提示 + idle）
          handleArrangeFailure(window: ..., result: .failed(...))
          exitToIdlePreservingLayout()
      case .selecting:
          exitToIdlePreservingLayout()
      case .working:
          // 放弃 working，不恢复已不存在窗口
          stopSelectTimeout()
          overlay?.hideOverlay()
          isSelectingWindow = false
          state = .idle
      case .idle:
          break
      }
      notificationObserver?.stopObserving()
  }
  ```
- 注意：arranging 阶段 App 退出时，handleArrangeFailure 需要 window 参数，但 arranging 中失败窗口可能未确定。简化为提示"目标 App 已退出"：
  ```swift
  case .arranging:
      overlay?.showError(text: "目标 App 已退出", duration: 2.0)
      exitToIdlePreservingLayout()
  ```
- 运行：`swift test` → 预期通过

### Task 4.11: selecting 超时保留排列单元测试（红）

- 新增 `testSelectingTimeoutPreservesLayout()`：模拟 30 秒超时，断言 state == .idle + arrangedWindows 非空 + 不调用 restoreWindows
- 运行：预期失败（P0 deactivate 调用 restoreWindows）

### Task 4.12: 重构 deactivate 为保留排列语义（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift`
- 拆分 deactivate 为两个方法：
  - `exitToIdlePreservingLayout()`：selecting/working 退出保留排列（不还原窗口，不清空快照）
  - `deactivate()`：保留原 P0 行为（还原窗口 + 清空快照），仅用于显式还原场景（本 Phase 后无调用方，可标记 deprecated 或删除）
- 修改 startSelectTimeout 的回调：调用 `exitToIdlePreservingLayout()` 替代 `deactivate()`
- 修改 Esc 处理（handleKeyEvent）：调用 `exitToIdlePreservingLayout()`
- 运行：`swift test` → 预期通过

### Task 4.13: TidyApp 注入 SystemNotificationObserver

- 文件：`Sources/TidyApp/TidyApp.swift`
- 创建 `SystemNotificationObserver()` 实例并注入 TidyOrchestrator init
- 运行：`swift build` → 预期编译通过

### Task 4.14: App 退出不崩溃单元测试

- 新增 `testAppTerminatedTwiceDoesNotCrash()`：连续两次触发 onAppTerminated，断言不崩溃 + state == .idle
- 运行：`swift test` → 预期通过

## 6. 验证命令

```bash
swift test --filter TidyOrchestratorTests
swift test --filter SystemNotificationObserverTests
swift test
swift build
swiftlint lint --strict
```

## 7. UI 证据（手动）

- 手动测试：进入 selecting，切到其他 App，确认窗口排列保留 + 覆盖层消失
- 手动测试：进入 selecting，切到其他 Space，确认同上
- 手动测试：进入 working，切到其他 App 后切回，确认保持 working 状态
- 手动测试：进入 working，切到其他 Space 后切回，确认保持 working 状态
- 手动测试：进入 arranging/selecting/working，⌘Q 退出目标 App，确认三阶段正确退出 + 不崩溃
- 截图证据：各场景截图

## 8. 提交边界与回滚

- 提交 1：Task 4.1-4.3（SystemNotificationObserver 模块 + 注入）→ `feat(tidycore): 新增系统通知监听模块`
- 提交 2：Task 4.4-4.8（切 App/Space 退出 + working 不动作）→ `feat(tidycore): selecting 切 App/Space 退出保留排列`
- 提交 3：Task 4.9-4.10, 4.14（App 退出三阶段）→ `feat(tidycore): 目标 App 退出三阶段区分处理`
- 提交 4：Task 4.11-4.12（超时/Esc 保留排列）→ `refactor(tidycore): selecting 超时与 Esc 改为保留排列语义`
- 提交 5：Task 4.13（TidyApp 注入）→ `feat(tidyapp): 注入 SystemNotificationObserver`

回滚：每个提交独立可回滚。

## 9. AC → Task → Test 映射

| AC | Task | Test |
|----|------|------|
| AC-F1-004 selecting 生命周期 | 4.4-4.8, 4.11-4.12 | TC-F1-004-01/02/03/04 |
| AC-F1-005 working 切 App/Space 不动作 | 4.8 | TC-F1-005-01/02 |
| AC-F1-007 目标 App 退出 | 4.9-4.10, 4.14 | TC-F1-007-01/02/03/04 |

## 10. Local Gate

- [ ] 所有 Task 4.1-4.14 完成
- [ ] `swift test` 全绿
- [ ] `swiftlint lint --strict` 0 violations
- [ ] `swift build` 成功
- [ ] 手动测试切 App/Space/App 退出截图已保存
- [ ] 5 个提交已按顺序创建
