# Phase 1: 布局算法对齐

> Phase ID: 1 | slug: layout-alignment
> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) FR-F1-002 / [F1_02](../F1_02_设计文档.md) 第 2 章

## 1. Goal

将 P0 的 `GridLayoutCalculator` 与 `TidyOrchestrator` 窗口排序逻辑对齐 F1_01 v0.12 的布局规则：

- 9 窗口改为 3×3 均分（跳出 a 占左规则）
- 10+ 窗口截断到前 9 个 + 覆盖层提示
- 删除单元格内缩（8pt / 4pt），占满 visibleFrame
- a 标签分配给 z-order 最前窗口，剩余按 z-order 降序

## 2. Architecture / Tech Stack

- 模块：TidyCore（GridLayoutCalculator / TidyOrchestrator / WindowEnumerator）
- 不涉及 TidyUI / TidyApp 变更（覆盖层错误提示在 Phase 2）
- 不引入新依赖
- Swift 5.7+ / SPM

## 3. 文件与职责

| 文件 | 职责变更 |
|------|---------|
| `Sources/TidyCore/Layout/GridLayoutCalculator.swift` | 新增 9 窗口 3×3 分支；删除 10+ 接近正方形；删除 padding 内缩；10+ 由调用方截断 |
| `Sources/TidyCore/Orchestration/TidyOrchestrator.swift` | activate() 内按 z-order 降序排序窗口；10+ 截断到 9；触发截断提示 |
| `Sources/TidyCore/Window/WindowEnumerator.swift` | 确认 enumerateVisibleWindows 返回按 z-order 降序的窗口列表（若 P0 未按 z-order 排序，需补充） |
| `Tests/TidyCoreTests/GridLayoutCalculatorTests.swift` | 新增 9 窗口 3×3 / 无内缩 / 10+ 截断单元测试 |
| `Tests/TidyCoreTests/TidyOrchestratorTests.swift` | 新增 z-order 排序 / 10+ 截断单元测试 |

## 4. IN / OUT / Dependencies

- **IN**：P0 GridLayoutCalculator / TidyOrchestrator / WindowEnumerator 已实现
- **OUT**：GridLayoutCalculator 支持新规则；TidyOrchestrator z-order 排序 + 10+ 截断
- **Dependencies**：无（本 Phase 是其他 Phase 的基础）

## 5. 任务（2-5 分钟粒度，TDD）

### Task 1.1: 9 窗口 3×3 布局单元测试（红）

- 文件：`Tests/TidyCoreTests/GridLayoutCalculatorTests.swift`
- 新增 `testLayoutFor9WindowsIs3x3Grid()`：给定 windowCount=9, screen=(0,0,1920,1080)，断言 9 个 cell，3 行 3 列，每格 (640, 360)，标签 a-i 从左到右从上到下
- 运行：`swift test --filter GridLayoutCalculatorTests` → 预期失败（P0 走 splitLayout）

### Task 1.2: 实现 9 窗口 3×3 分支（绿）

- 文件：`Sources/TidyCore/Layout/GridLayoutCalculator.swift`
- 在 `calculateLayout` 中新增 `if capped == 9 { return standardGrid(count: 9, rows: 3, cols: 3, ...) }` 分支
- 运行：`swift test --filter GridLayoutCalculatorTests` → 预期通过

### Task 1.3: 删除内缩单元测试（红）

- 新增 `testLayoutHasNoPadding()`：断言 cell.frame.origin.x == screen.origin.x（无 padding），cell 宽度 == screen.width / cols
- 运行：预期失败（P0 有 8pt padding）

### Task 1.4: 删除 GridLayoutCalculator 内缩（绿）

- 删除 `padding: CGFloat = 8.0` 参数与所有 `insetBy` / `+ padding` / `- padding * 2` 计算
- 运行：`swift test --filter GridLayoutCalculatorTests` → 预期通过

### Task 1.5: 删除 TidyOrchestrator 放大内缩（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift` L235
- 将 `let maximizedFrame = screen.frame.insetBy(dx: 4, dy: 4)` 改为 `let maximizedFrame = screen.frame`
- 运行：`swift test` → 预期通过（无回归）

### Task 1.6: z-order 排序单元测试（红）

- 文件：`Tests/TidyCoreTests/TidyOrchestratorTests.swift`
- 新增 `testActivateAssignsLabelAToZOrderFrontmost()`：给定 5 个窗口 z-order=[w3,w1,w4,w2,w5]，断言 a→w3, b→w1, c→w4, d→w2, e→w5
- 运行：预期失败（P0 按枚举顺序）

### Task 1.7: 实现 z-order 排序（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift` activate()
- 在 `positionSnapshot = windowManipulator.snapshotWindows(windows)` 前按 z-order 降序排序 windows
- z-order 来源：CGWindowList 已按 z-order 降序返回（P0 WindowEnumerator 应已支持，若未支持需补充 layer 字段）
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 1.8: 10+ 截断单元测试（红）

- 新增 `testActivateTruncatesTo9Windows()`：mock 返回 12 个窗口，断言 arrangedWindows.count == 9，layoutCells.count == 9，前 9 个为 z-order 最前
- 运行：预期失败（P0 走接近正方形布局）

### Task 1.9: 实现 10+ 截断（绿）

- 文件：`Sources/TidyCore/Orchestration/TidyOrchestrator.swift` activate()
- 在 `let windows = windowEnumerator.enumerateVisibleWindows(forPID: frontmostPID)` 后：
  ```swift
  let truncated = Array(windows.prefix(9))
  let wasTruncated = windows.count > 9
  ```
- 使用 `truncated` 替代 `windows` 进行后续排列
- 若 `wasTruncated`，触发覆盖层截断提示（Phase 2 实现 showError，本 Phase 先用 os_log 记录 + TODO 标记）
- 运行：`swift test --filter TidyOrchestratorTests` → 预期通过

### Task 1.10: 删除 GridLayoutCalculator 10+ 接近正方形分支

- 文件：`Sources/TidyCore/Layout/GridLayoutCalculator.swift` evenGridDimensions
- 删除 `// 10+: 尽量接近正方形` 分支（10+ 由调用方截断，不会传入 calculateLayout）
- 添加 `precondition(capped <= 9, "GridLayoutCalculator only handles 1-9 windows; caller must truncate")`
- 运行：`swift test` → 预期通过

## 6. 验证命令

```bash
# 单元测试
swift test --filter GridLayoutCalculatorTests
swift test --filter TidyOrchestratorTests

# 编译检查
swift build

# Lint
swiftlint lint --strict
```

## 7. UI 证据（手动）

本 Phase 无直接 UI 变更（覆盖层错误提示在 Phase 2），但布局变化影响视觉：

- 手动测试：在 Xcode 中打开 9 个窗口，触发热键，截图确认 3×3 均分布局
- 手动测试：在 Finder 中打开 12 个窗口，触发热键，确认排列 9 个 + 控制台日志记录截断

## 8. 提交边界与回滚

- 提交 1：Task 1.1-1.4（布局算法对齐）→ `feat(tidycore): 布局算法对齐 F1_01 v0.12（9 窗口 3×3 + 删除内缩）`
- 提交 2：Task 1.5（放大无内缩）→ `refactor(tidycore): 删除放大阶段 4pt 内缩`
- 提交 3：Task 1.6-1.7（z-order 排序）→ `feat(tidycore): a 标签分配给 z-order 最前窗口`
- 提交 4：Task 1.8-1.10（10+ 截断）→ `feat(tidycore): 10+ 窗口截断到前 9 个`

回滚：每个提交独立可回滚（`git revert <sha>`）。

## 9. AC → Task → Test 映射

| AC | Task | Test |
|----|------|------|
| AC-F1-002 布局规则 | 1.1-1.4, 1.6-1.7 | TC-F1-002-01/02/03/04/05 |
| AC-F1-003 边界窗口数 | 1.8-1.10 | TC-F1-003-01/02 |

## 10. Local Gate

- [ ] 所有 Task 1.1-1.10 完成
- [ ] `swift test` 全绿
- [ ] `swiftlint lint --strict` 0 violations
- [ ] `swift build` 成功
- [ ] 手动测试 9 窗口 3×3 布局截图已保存
- [ ] 4 个提交已按顺序创建
