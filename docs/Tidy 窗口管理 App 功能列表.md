# Tidy 窗口管理 App 功能列表

> 最后更新：2026-07-30 | 版本：v1.3

[TOC]

## 一、产品定位

Tidy 是一个 macOS 系统级窗口编排工具，专注解决"同一 App 多窗口快速切换工作流"痛点：

> 一键铺开前台 App 的所有可见窗口 → 字母选择 → 最大化工作 → 一键还原

**最低系统要求：macOS 12（Monterey）**
**开发工具：Xcode 14.1+ / Swift 5.7+**

核心能力：

* 触发热键把前台 App 在当前 Space 上的所有可见窗口排列到一个屏幕内不重叠
* 字母标签覆盖层让用户用单字符选择目标窗口
* 选中窗口立即最大化，用户进入工作状态
* 再次按下热键，所有窗口还原到排列前的原始位置和大小

**与 macOS App Exposé / Mission Control 的区别**：

| 维度 | App Exposé / Mission Control | Tidy |
|------|------------------------------|------|
| 触发方式 | F3 / Ctrl+↓ / 触控板手势 | 全局热键 ⌘⌥T |
| 选择方式 | 鼠标点击窗口缩略图 | 键盘字母标签 |
| 还原方式 | 选择窗口即退出 | 单独热键还原所有窗口到原位置 |
| 窗口状态 | 缩略图（不可交互） | 真实窗口（排列后可立即工作） |
| 多屏支持 | 当前屏 | 焦点窗口所在屏 |

---

## 二、功能优先级

> **维度说明**：本节的 `P0/P1/P2` 指**功能优先级**（Priority），决定"先做哪个功能"。开发阶段划分见 [../docs.md](../docs.md) 第 4 节：先经准备阶段 `P0_技术探针`（技术验证 + 项目骨架），再按 `F0 → F0.1 → F1 → F2 → F3 → F4 → F5` 推进功能开发。两处的 `P0` 含义不同，不可混淆。

### 准备阶段（先于功能优先级）

阶段推进顺序、IN/OUT 边界、Exit Gate 和依赖关系由 [Tidy_开发路线图.md](Tidy_开发路线图.md) 定义，本节不再重复。P0_技术探针的详细需求与设计见 `docs/phases/P0_技术探针/` 目录。

---

### P0 — MVP 核心功能（必须实现）

#### F0. 权限引导（Permission Bootstrap）

首次启动时引导用户授予辅助功能权限（操作窗口 AXFrame 必需）：启动时检测，无权限则显示引导窗口；仅按需检测，不轮询。

**设计参考**：Macim F0 权限引导规范。Tidy 直接复用同一设计。

---

#### F0.1 状态栏图标、菜单与全局快捷键（Status Bar & Hotkeys）

F0 权限引导之后，建立状态栏交互和全局快捷键，让每个开发阶段都方便手动测试验收。

**状态栏图标状态**：

| 状态 | 图标样式 | 说明 |
|------|---------|------|
| 未授权 | ⚠️ 警告 | 权限引导窗口可见时 |
| 空闲 | 普通 | 正常工作状态 |
| 编排中 | 🔵 蓝点 | arranging / selecting 阶段 |
| 锁定工作 | 🔒 锁标识 | working 阶段（用户在目标 App 上工作）；v1.0 候选，v0.1 仅实现前 3 种 |

**状态栏菜单**：

| 菜单项 | 功能 | 快捷键 |
|--------|------|--------|
| Grant Accessibility Permission... | 打开权限引导窗口 | — |
| **Trigger Tidy** | **触发 Tidy 编排** | **⌘⌥T** |
| Preferences... | 打开偏好设置窗口 | ⌘, |
| About | 显示关于信息 | — |
| Quit | 退出应用 | ⌘Q |

**全局快捷键**：⌘⌥T（默认，可配置），通过 Carbon RegisterEventHotKey 注册。

**设计参考**：Macim F0.1 状态栏与快捷键规范。Tidy 简化为 5 个菜单项。

---

#### F1. 窗口编排核心（Tidy 主功能）

##### 核心目标

让用户在前台 App 有多个窗口时，无需鼠标即可：
1. 一键铺开所有窗口到当前屏幕
2. 字母选择目标窗口最大化
3. 工作完成后一键还原

##### 功能分解（F1.0 ~ F1.6）

> 每个子功能完成后，用户可在 app 中直接看到/操作到结果，可通过 XCUITest 或手动验证。
> 纵向功能切片策略：每步交付一个可操作、可展示的 app 状态。

| 编号 | 子功能 | 验证标准 | 依赖 | 状态 |
|------|--------|----------|------|------|
| **F1.0** | Integration Baseline（集成基线） | 启动 app → 状态栏图标可见 → 热键回调可达 → 状态机 idle → CI 绿灯 | F0, F0.1 | ❌ 未实现 |
| **F1.1** | 窗口枚举与原 frame 快照 | 热键激活 → 控制台输出前台 App 在当前 Space 上的可见窗口列表 + 各窗口原 frame → 仅 1 个窗口时显示通知 | F1.0 | ❌ 未实现 |
| **F1.2** | 自适应网格布局 | 热键激活 → 多个窗口被排列到焦点窗口所在屏的非重叠网格内 → 控制台输出布局参数（rows × cols） | F1.1 | ❌ 未实现 |
| **F1.3** | 字母标签覆盖层与选择输入 | 排列完成 → 每个窗口中心偏上显示 32pt 黄色字母气泡（a-z 按 z-order 分配） → 按 Esc 还原退出 → 按有效字母进入最大化；AX 失败窗口原位置显示标签降级 | F1.2 | ❌ 未实现 |
| **F1.4** | 选中窗口最大化与 working 状态 | 按有效字母 → 对应窗口立即最大化到屏幕可见区域 → 覆盖层消失 → 菜单栏图标变 🔒 → 控制台输出选中窗口 ID 和最大化 frame | F1.3 | ❌ 未实现 |
| **F1.5** | 还原流程与异常清理 | working 阶段按 ⌘⌥T → 所有窗口还原到 F1.1 快照的 frame → 菜单栏图标恢复正常 → 控制制台输出还原耗时；测试 Space 切换自动还原、App 切换 Session 保留、目标 App 退出尽力恢复 | F1.4 | ❌ 未实现 |
| **F1.6** | 偏好设置驱动行为（v1.0 候选） | 5 项配置可持久化，热键录制、超时、字体大小、背景色、启动时运行均生效；打开偏好时退出 Tidy 模式 | F1.4 | ❌ 未实现 |

**依赖关系**：

```
F1.0 → F1.1 → F1.2 → F1.3 → F1.4 → F1.5
                              │
                              └→ F1.6
```

##### 模块说明（参考 Macim 架构层模块组织）

| 模块 | 职责 | 依赖 | 被依赖 |
|------|------|------|--------|
| M1. 基础设施 | App 骨架、状态栏、未来承载偏好窗口的模块、DI 容器 | 无 | M2-M5 |
| M2. 输入检测 | CGEventTap、Carbon 热键 | M1 | M4 |
| M3. 窗口服务 | CGWindowList 枚举、AXUIElement 操作、frame 快照与还原 | M1 | M4 |
| M4. 编排控制 | TidyMode 状态机、激活/还原流程、选择输入处理 | M2, M3, M5 | — |
| M5. 覆盖层 UI | NSPanel 覆盖层、字母标签渲染 | M1, M3 | M4 |

**模块依赖图**（A ──→ B = A depends on B）：

```
M4 ──→ M2 ──→ M1
 │       │
 ├──→ M3 ──→ M1
 │     │
 └──→ M5 ──→ M1, M3
```

###### M1. 基础设施（Infrastructure）

**职责**：App 入口与生命周期、DI 容器、状态栏图标与菜单、未来承载偏好设置窗口的模块（v1.0 候选）。

**核心类/协议**：

| Tidy 类型 | Macim 对应 | 说明 |
|-----------|-----------|------|
| `DependencyContainer` | `DependencyContainer` | DI 容器，创建和连接所有组件 |
| `StatusItemManager` | `StatusItemManager` | 菜单栏图标与下拉菜单 |
| `PreferencesWindowController` | `PreferencesWindowController` | 偏好设置窗口（NSWindow + SwiftUI content） |

**与 Macim 对比**：

| 维度 | Macim | Tidy | 选择理由 |
|------|-------|------|---------|
| 偏好窗口技术 | AppKit（NSGridView 表单） | NSWindow + SwiftUI content | macOS 12 SwiftUI 已稳定，偏好窗口交互简单，SwiftUI 开发效率更高 |
| 状态栏图标状态 | 4 种 | 4 种（空闲/未授权/编排中/锁定工作），v0.1 仅实现 3 种 | 一致，v0.1 简化 |
| 菜单项数量 | 10+ | 5（简化） | Tidy 功能单一，无需复杂菜单 |

---

###### M2. 输入检测（Input Detection）

**职责**：监听全局键盘事件（仅 selecting 阶段）、注册全局热键、管理 CGEventTap 生命周期。

**不做**：不决定"按键后做什么"（由 M4 编排控制决定）、不渲染 UI。

**核心类/协议**：

| Tidy 类型 | Macim 对应 | 说明 |
|-----------|-----------|------|
| `HotkeyRegistrar` | `HotkeyRegistrar` | Carbon API 注册全局热键 ⌘⌥T |
| `GlobalEventTap` | `GlobalEventTap` | 封装 CGEventTap 创建/启用/禁用/回调 |
| `TidyModeActivationHandling`（协议） | `HintModeActivationHandling` | 激活/退出协议 |

**与 Macim 对比**：

| 维度 | Macim | Tidy | 选择理由 |
|------|-------|------|---------|
| EventTap 数量 | 3 个独立 Tap（双键和弦/长按/HintMode 输入） | 1 个 Tap（仅 selecting 阶段字母输入） | Tidy 无双键和弦/长按，单一激活方式 |
| EventTap 生命周期 | HintMode 激活期间常驻 | 仅 selecting 阶段启用（200ms~30s） | working 阶段不拦截，用户在 App A 上正常工作 |
| EventTap 模式 | `.defaultTap`（可拦截） | `.defaultTap`（可拦截） | 一致：避免字母泄漏到前台 App |
| 激活方式 | 4 种（热键/双键和弦/长按/菜单自动） | 2 种（热键 / 状态栏菜单） | Tidy 简化 |

**CGEventTap 恢复策略**（参考 Macim）：

| 禁用原因 | 处理方式 |
|---------|---------|
| `.tapDisabledByTimeout` | 自动重新启用 tap，记录 Info 日志 |
| `.tapDisabledByUserInput` | 自动重新启用 tap，记录 Info 日志 |
| 重新启用失败 | 退出 selecting 状态，还原所有窗口，显示错误提示，不崩溃 |

---

###### M3. 窗口服务（Window Services）

**职责**：CGWindowList 窗口枚举、AXUIElement 窗口操作、frame 快照与还原、目标屏幕判定。

**不做**：不决定"排列布局"（由 M4 决定）、不渲染 UI。

**核心类/协议**：

| Tidy 类型 | Macim 对应 | 说明 |
|-----------|-----------|------|
| `WindowEnumerator` | — | 基于 CGWindowListCopyWindowInfo 枚举前台 App 在当前 Space 的可见窗口 |
| `WindowManipulator` | — | 基于 AXUIElement 设置窗口 frame（kAXPositionAttribute + kAXSizeAttribute） |
| `FrameSnapshotStore` | — | 存储排列前的窗口 frame 快照，用于还原 |
| `TargetScreenResolver` | — | 解析焦点窗口所在屏幕 |
| `FocusedWindowProvider` | — | 通过 AXUIElement kAXFocusedWindowAttribute 获取前台 App 焦点窗口 |

**窗口枚举流程**：

```
1. 获取前台 App PID（NSWorkspace.shared.frontmostApplication.processIdentifier）
2. CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) → 所有可见窗口
3. 过滤：
   - kCGWindowLayer == 0（排除菜单栏/Dock/Overlay）
   - kCGWindowOwnerPID == frontmostAppPID
   - kCGWindowAlpha > 0
   - kCGWindowBounds 非空
4. 通过 AXUIElementCreateApplication(pid) → kAXWindowsAttribute 获取 AXUIElement 列表
5. 按 frame 匹配 CGWindowList 结果与 AXUIElement 列表（匹配算法为 P0 待验证候选，产出 MATCHED / AMBIGUOUS / UNMATCHED 三种结果）
6. 输出 [(windowID, axUIElement, originalFrame)] 列表
```

**窗口操作 API**：

| 操作 | API | 说明 |
|------|-----|------|
| 获取焦点窗口 | `AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute, ...)` | 用于判定目标屏幕 |
| 获取窗口 frame | `AXUIElementCopyAttributeValue(window, kAXPositionAttribute, ...)` + `kAXSizeAttribute` | 用于快照 |
| 设置窗口 frame | `AXUIElementSetAttributeValue(window, kAXPositionAttribute, point)` + `AXUIElementSetAttributeValue(window, kAXSizeAttribute, size)` | 用于排列和还原 |
| 获取窗口标题 | `AXUIElementCopyAttributeValue(window, kAXTitleAttribute, ...)` | 用于诊断日志 |

**目标屏幕判定**：

```
1. AXUIElementCopyAttributeValue(frontmostApp, kAXFocusedWindowAttribute) → focusedWindow
2. AXUIElementCopyAttributeValue(focusedWindow, kAXPosition/AXSize) → frame
3. 计算 frame.center
4. 遍历 NSScreen.screens，找包含 center 的屏幕
5. 兜底：返回 NSScreen.main（含菜单栏的屏幕）
```

**AXSetFrame 失败处理**：

| 场景 | 处理 |
|------|------|
| 单个窗口 AXSetFrame 失败 | 跳过该窗口，保留原位置，在该窗口可见区域显示标签（原位置标签降级），本次会话降级为"仅标签窗口切换器"，记录 Warning 日志 |
| 失败窗口数 > 50% | 终止 Tidy 模式，显示通知"Tidy: 大量窗口无法编排，已退出" |
| 还原阶段单个窗口失败 | 跳过该窗口（保留排列后的位置），记录 Error 日志；其他窗口正常还原 |

---

###### M4. 编排控制（Orchestration Control）

**职责**：TidyMode 状态机管理、激活/还原流程、字母选择输入处理、超时管理。

**不做**：不直接监听键盘事件（由 M2 提供）、不直接操作窗口（由 M3 提供）、不直接渲染 UI（由 M5 提供）。

**核心类/协议**：

| Tidy 类型 | Macim 对应 | 说明 |
|-----------|-----------|------|
| `TidyModeController` | `HintModeViewController` | TidyMode 状态机 + 激活协调 |
| `TidyModeActivationHandling`（协议） | `HintModeActivationHandling` | 激活/退出协议（TidyCore 层） |
| `LayoutCalculator` | — | 自适应网格布局算法 |
| `LabelAssigner` | — | 按网格顺序分配 a-z 字母 |
| `SelectionInputHandler` | — | 字母输入处理，调用 M3 最大化选中窗口 |

**状态机（5 状态）**：

| 状态 | 含义 | 合法后继 | 内部子流程 |
|------|------|----------|-----------|
| `idle` | Tidy 未激活 | → arranging | — |
| `arranging` | 计算布局、保存快照、设置新 frame | → selecting / idle | 枚举窗口 → 保存快照 → 计算网格 → 设置 frame → 显示覆盖层 → 启用 EventTap |
| `selecting` | 字母标签已渲染，等待用户输入 | → working / restoring | 字母输入处理 → 最大化选中窗口 |
| `working` | 选中窗口已最大化，用户工作中 | → restoring | EventTap 已禁用；监听前台 App 切换/Space 切换 |
| `restoring` | 正在还原所有窗口 | → idle | 设置所有窗口 frame 回快照值 → 隐藏覆盖层 → 清理 TidySession |

**状态转换触发条件**：

| 当前状态 | 触发 | 后继状态 |
|---------|------|---------|
| idle | Tidy 热键按下 | arranging |
| arranging | 布局完成（典型 < 200ms） | selecting |
| arranging | 仅 0 或 1 个可见窗口 | idle（显示通知） |
| arranging | AXSetFrame 大量失败 | idle（显示错误通知） |
| selecting | 有效字母按下 | working（先最大化再切状态） |
| selecting | Esc 按下 | restoring |
| selecting | Tidy 热键按下 | restoring |
| selecting | 30 秒无输入（默认，可配置） | restoring |
| selecting | 前台 App 切换 | restoring |
| selecting | Space 切换 | restoring |
| working | Tidy 热键按下 | restoring |
| working | 前台 App 切换 | Session 保留，返回后 working 继续 |
| working | Space 切换 | restoring |
| working | 目标 App 退出 | restoring（尽力恢复 + 清理 Session） |
| restoring | 所有窗口 frame 已设置 | idle |

**输入规则**（参考 Q10 决策）：

| 输入 | 行为 |
|------|------|
| `a`-`z` / `A`-`Z`（在已分配字母范围内） | 选中对应窗口 → 最大化 → 进入 working 状态 |
| `a`-`z` / `A`-`Z`（未在范围内） | 忽略（无反馈） |
| `Escape` | 还原所有窗口 → idle |
| Tidy 热键（⌘⌥T） | 还原所有窗口 → idle（Carbon 注册的快捷键优先于 EventTap） |
| `Backspace` | 无操作（单字符输入） |
| 修饰键（Shift/Cmd/Opt 单独按） | 忽略 |
| 字母 + 修饰键（如 `⌘a`） | 忽略（防止误触） |
| 数字键 / 标点 / 其他 | 忽略 |
| 30 秒无输入（默认） | 自动还原退出 → idle |

**字母分配规则**：

1. 按 z-order 排序参与排列的窗口（最前面的优先）
2. 按网格填充顺序（从左到右、从上到下）分配字母 `a`, `b`, `c`, ...
3. 最常用窗口（z-order 最前）排在网格左上角，分配 `a`（最易输入）

**自适应网格算法**：

| N | 网格（宽屏） | 网格（竖屏） | 备注 |
|---|-------------|-------------|------|
| 2 | 1×2 | 2×1 | 核心场景 |
| 3 | 1×3 | 3×1 | 核心场景 |
| 4 | 2×2 | 2×2 | 核心场景 |
| 5-6 | 2×3 | 3×2 | 核心场景 |
| 7-9 | 3×3 | 3×3 | 核心场景 |
| 10-12 | 3×4 | 4×3 | v1.0 Candidate，验证后决定 |
| 13-16 | 4×4 | 4×4 | v1.0 Candidate，验证后决定 |
| 17-20 | 4×5 | 5×4 | v1.0 Candidate，验证后决定 |
| 21-25 | 5×5 | 5×5 | v1.0 Candidate，验证后决定 |
| 26 | 5×6 | 6×5 | v1.0 Candidate，验证后决定 |
| >26 | 仅取前 26 个（按 z-order）+ 通知 | 同左 | |

**算法伪代码**：

```swift
func computeGrid(n: Int, screenAspect: CGFloat) -> (rows: Int, cols: Int) {
    if n <= 1 { return (0, 0) }
    let aspect = screenAspect  // width / height
    var best = (rows: 1, cols: n, score: Double.infinity)
    for rows in 1...n {
        let cols = Int(ceil(Double(n) / Double(rows)))
        let cellAspect = (aspect * Double(rows)) / Double(cols)
        let score = abs(log(cellAspect))  // 越接近 1（正方形）越好
        if score < best.score {
            best = (rows, cols, score)
        }
    }
    return (best.rows, best.cols)
}

func layoutWindows(_ windows: [Window], on screen: NSScreen) -> [Window: CGRect] {
    let visibleFrame = screen.visibleFrame
    let n = windows.count
    let (rows, cols) = computeGrid(n: n, screenAspect: visibleFrame.width / visibleFrame.height)
    let cellWidth = visibleFrame.width / CGFloat(cols)
    let cellHeight = visibleFrame.height / CGFloat(rows)
    var result: [Window: CGRect] = [:]
    for (i, window) in windows.enumerated() {
        let row = i / cols
        let col = i % cols
        let cellRect = CGRect(
            x: visibleFrame.minX + CGFloat(col) * cellWidth + 2,
            y: visibleFrame.minY + CGFloat(rows - 1 - row) * cellHeight + 2,
            width: cellWidth - 4,
            height: cellHeight - 4
        )
        result[window] = cellRect
    }
    return result
}
```

**最大化算法**：

选中字母后，对应窗口的 frame 设置为目标屏幕的 `visibleFrame`（排除 Dock 和菜单栏）：

```swift
func maximizeWindow(_ window: AXUIElement, on screen: NSScreen) {
    let visibleFrame = screen.visibleFrame
    AXUIElementSetAttributeValue(window, kAXPositionAttribute, visibleFrame.origin)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute, visibleFrame.size)
}
```

**还原算法**：

按快照还原所有窗口（包括最大化的窗口）：

```swift
func restoreAllFrames(snapshot: [WindowID: CGRect], windows: [WindowID: AXUIElement]) {
    for (windowID, originalFrame) in snapshot {
        guard let window = windows[windowID] else { continue }
        // 跳过已关闭的窗口（AX 调用会失败）
        AXUIElementSetAttributeValue(window, kAXPositionAttribute, originalFrame.origin)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute, originalFrame.size)
    }
}
```

**working 阶段用户手动操作的处理**（参考 Q11 决策）：

| 用户在 working 阶段的操作 | 还原时行为 |
|--------------------------|-----------|
| 拖动 / 调整最大化窗口的大小 | 该窗口还原到排列前的原始 frame |
| 拖动 / 调整其他窗口（被遮在后面的） | 该窗口还原到排列前的原始 frame |
| 手动最小化最大化窗口 | 该窗口保持最小化状态；其他窗口还原 |
| 手动最小化其他窗口 | 同上 |
| 关闭最大化窗口 | 该窗口已关闭无法还原；其他窗口还原 |
| 关闭其他窗口 | 同上 |
| 打开新窗口 | 新窗口不参与还原（保持打开状态） |
| Cmd+Tab 切换到其他窗口（App A 内部） | 还原所有窗口到原始 frame |
| 切换到其他 App | Session 保留，返回后 working 继续 |

**数据模型**：

```swift
struct TidySession {
    let appPID: pid_t
    let appBundleID: String
    let targetScreenID: CGDirectDisplayID
    let originalFrames: [WindowID: CGRect]   // 排列前的 frame 快照
    let arrangedFrames: [WindowID: CGRect]   // 排列后的 frame（用于诊断）
    var maximizedWindowID: WindowID?          // working 阶段被最大化的窗口
    var maximizedFrame: CGRect?               // 最大化后的 frame
    var state: TidyState                      // idle / arranging / selecting / working / restoring
    let createdAt: Date
    var lastInputAt: Date                     // 用于超时检测
}

enum TidyState {
    case idle
    case arranging
    case selecting
    case working
    case restoring
}
```

---

###### M5. 覆盖层 UI（Overlay UI）

**职责**：NSPanel 覆盖层窗口管理、字母标签渲染。

**不做**：不处理业务逻辑（由 M4 决定显示什么）。

**核心类/协议**：

| Tidy 类型 | Macim 对应 | 说明 |
|-----------|-----------|------|
| `OverlayWindowController` | `OverlayWindowController` | 覆盖层窗口控制器（NSPanel） |
| `LetterBubbleLayer` | `ScreenNumberLabelView`（Macim） | 字母标签 CAShapeLayer 渲染 |
| `LetterPlacementCalculator` | `HintPlacementCalculator` | 字母标签位置计算（窗口中心偏上） |

**与 Macim 对比**：

| 维度 | Macim HintMode | Macim 屏幕数字标签 | Tidy 字母标签 |
|------|---------------|-------------------|--------------|
| 字体大小 | 11pt | 40pt | 32pt |
| 背景色 | `#FFE070` | `#FFE070` | `#FFE070` |
| 圆角半径 | 2px | 3px | 6px |
| 内边距 | 紧凑 | 6×20px | 8×12px |
| 阴影 | 无 | 0 4px 16px rgba(0,0,0,0.4) | 0 4px 16px rgba(0,0,0,0.4) |
| 定位 | 元素中心 + 底部三角指针 | 屏幕中央 | 窗口中心偏上，动态约束在屏幕可见区域内 |
| 渲染层 | CALayer（PrecomputedHintLayout） | CAShapeLayer | CAShapeLayer |

**字母标签视觉规格**：

| 属性 | 值 | 说明 |
|------|-----|------|
| 字体 | 系统粗体 32pt | 远距离可读 |
| 背景色 | `#FFE070`（暖黄色） | 与 Macim 一致 |
| 文字色 | `black` | 高对比 |
| 边框 | 1px `darkGray` | |
| 圆角半径 | 6px | |
| 内边距 | 8px × 12px | |
| 阴影 | 0 4px 16px rgba(0,0,0,0.4) | 增强浮动感 |
| 定位 | 窗口 frame 中心偏上，避开系统控制按钮，动态约束在屏幕可见区域内 | 不遮挡标题栏按钮（关闭/最小化/最大化），始终可见 |
| 层级 | NSPanel（.nonactivatingPanel + .popUpMenu） | 与 Macim HintMode 一致 |
| 跨 Space | .fullScreenAuxiliary | 仅当前 Space 可见 |

**覆盖层窗口规格**（参考 Macim M5）：

| 属性 | 值 |
|------|-----|
| 窗口类型 | NSPanel |
| 样式 | `.nonactivatingPanel` |
| 层级 | `.popUpMenu`（高于普通窗口，低于系统菜单） |
| 跨 Space | `.fullScreenAuxiliary` |
| 不抢焦点 | `ignoresMouseEvents = true` |
| 覆盖范围 | 目标屏幕的 `visibleFrame`（不是整个 screen.frame，避免遮挡菜单栏） |

**字母标签渲染流程**：

```
1. M4 计算完网格布局后，调用 M5 显示覆盖层
2. M5 创建 NSPanel 覆盖目标屏幕
3. 对每个参与排列的窗口：
   - 计算窗口在屏幕上的 frame（已设置的新 frame）
   - 计算标签位置：窗口 frame 中心偏上，避开系统控制按钮，动态约束在屏幕可见区域内
   - 创建 LetterBubbleLayer，绘制圆角矩形 + 字母文字
   - 添加到 NSPanel 的 contentView.layer
4. 标签添加完成后淡入显示（200ms ease-out）
5. 用户按下字母后，对应标签高亮 100ms，然后整个覆盖层淡出（100ms）
6. NSPanel 隐藏并释放
```

---

##### 技术实现

* CGWindowListCopyWindowInfo（窗口枚举，按 PID 过滤）
* AXUIElement（窗口操作，kAXPositionAttribute + kAXSizeAttribute + kAXFocusedWindowAttribute + kAXWindowsAttribute）
* Carbon RegisterEventHotKey（全局热键 ⌘⌥T）
* CGEventTap（.cgSessionEventTap + .defaultTap + .headInsertEventTap，仅 selecting 阶段启用）
* NSPanel 覆盖层（.nonactivatingPanel，.popUpMenu 层级，.fullScreenAuxiliary 跨 Space）
* 显式状态机（5 状态）+ Combine UI 桥接
* 手动依赖注入（初始化器注入）
* NSWorkspace.didActivateApplicationNotification（App 切换 Session 保留，非自动还原）
* NSWorkspace.activeSpaceDidChangeNotification（Space 切换自动还原）
* UserDefaults + Combine（5 项配置，实时生效）
* os_log（com.tidy.windowmanagement 子系统）

##### 架构决策摘要

| 决策 | 选择 | 理由 |
|------|------|------|
| 激活模型 | 单热键 Toggle（⌘⌥T） | 一个键管全部，认知成本最低 |
| 窗口范围 | 当前 Space 可见窗口 | 简单可靠；跨 Space 操作不稳定 |
| 目标屏幕 | 焦点窗口所在屏 | 与 Mission Control 一致，符合用户上下文 |
| 布局算法 | 自适应网格，核心 2-9，上限 26 为 v1.0 候选 | 核心场景 3×3 内足够，v1.0 验证后决定是否扩展 |
| 字母分配 | 按 z-order 排序后按网格顺序分配 a-z | 最常用窗口在左上角且标签是 a |
| 选中后其他窗口 | 原地不动 | 还原逻辑最简单，副作用最小 |
| 还原语义 | 撤销排列；App 切换不自动还原（Session 保留），Space 切换还原，目标 App 退出尽力恢复 | App 切换保留工作上下文，Space 切换还原防止错位 |
| 字母标签 UI | 32pt 黄色气泡，中心偏上动态约束 | 远距离可读，不遮挡标题栏按钮，始终可见 |
| 输入处理 | CGEventTap 拦截，单字符即选 | 26 个窗口单字符足够，无需回车确认 |
| 偏好窗口技术 | NSWindow + SwiftUI content | macOS 12 SwiftUI 已稳定，开发效率高 |
| EventTap 生命周期 | 仅 selecting 阶段启用 | working 阶段不拦截，用户在 App A 上正常工作 |
| AXSetFrame 失败处理 | 跳过失败窗口，原位置显示标签降级，>50% 失败终止 | 单窗口降级为仅标签切换器，容错与安全 |

##### 风险

| 风险 | 说明 | 应对策略 |
|------|------|----------|
| AXSetFrame 不稳定 | 部分应用（如 Logic Pro、Final Cut Pro）可能不响应 AX frame 设置 | 单窗口失败：保留原位置，原位置标签降级；>50% 失败终止；记录 Warning 日志 |
| 全屏窗口冲突 | 全屏窗口无法移动 | 当前 Space 可见窗口过滤已排除全屏窗口（全屏窗口在自己的 Space） |
| 多显示器坐标 | 高频 Bug 来源 | 使用 NSScreen.visibleFrame；目标屏幕判定基于焦点窗口中心 |
| CGEventTap 被禁用 | .tapDisabledByTimeout / .tapDisabledByUserInput | 自动重新启用；失败则退出 selecting 还原所有窗口 |
| 前台 App 切换 | Session 保留，返回后 working 继续 | 监听 NSWorkspace.didActivateApplicationNotification，保留 Session 而非自动还原；Space 切换仍自动还原 |
| Space 切换 | 还原可能错位 | 监听 NSWorkspace.activeSpaceDidChangeNotification，自动还原 |
| Stage Manager 冲突 | macOS 13+ Stage Manager 可能改变窗口位置 | 检测 Stage Manager 启用状态，启用时显示警告（v1 不深度集成） |
| 窗口关闭 | 还原时该窗口已不存在 | 跳过该窗口，记录 Info 日志，不报错 |
| App 退出 | 目标 App 在 working 阶段退出 | 监听 NSWorkspace.didTerminateApplicationNotification，自动清理 TidySession |
| Tidy 自身崩溃 | 窗口卡在排列状态 | v1 不持久化快照（接受丢失）；v2 考虑持久化以支持崩溃恢复 |
| macOS 更新 | Apple 经常修改权限 | 仅需辅助功能权限；App Sandbox 不兼容（已移除） |
| 偏好窗口与 NSPanel 集成 | SwiftUI 与 NSPanel 集成在 macOS 12 有已知问题 | 偏好窗口用 NSWindow + SwiftUI content；覆盖层坚持 AppKit |
| 字母标签遮挡窗口内容 | 32pt 标签可能遮挡窗口内容 | 标签位于窗口中心偏上，动态约束在屏幕可见区域内；用户可配置字体大小 |

---

### P1 — 高频增强功能（建议实现）

#### F2. 应用专属配置（Profiles）

##### 功能说明

* 针对 bundleIdentifier 匹配的应用，使用不同的默认配置
* 例如：Chrome 浏览器使用 4×2 布局，Finder 使用 3×3 布局
* 应用级热键覆盖（如某些 App 中 ⌘⌥T 冲突时使用 ⌘⌥Y）

##### 与 F1 的关系

F1 的偏好设置是全局配置；F2 在全局之上叠加应用级覆盖。配置合并优先级：应用级 > 全局。

---

#### F3. 自定义布局模板

##### 功能说明

* 用户可保存当前布局为模板（如"3×3 网格"、"上下分屏"）
* 通过偏好设置管理多个模板
* 在 Tidy 触发时通过二级快捷键选择模板（如 ⌘⌥T 触发后按数字键选模板）

##### 与 F1 自适应网格的关系

F1 默认自适应网格；F3 允许用户固定使用某种布局或快速切换。

---

### P2 — 差异化功能（后期）

#### F4. working 阶段窗口循环切换

##### 功能说明

* working 阶段支持快捷键循环切换最大化窗口
* 例如：⌘⌥[ 切换到上一个窗口，⌘⌥] 切换到下一个窗口
* 切换时新窗口立即最大化，原最大化窗口回到排列位置

##### 价值

避免用户为切换窗口必须"还原 → 重新排列 → 重新选择"的三步流程。

##### 与 F1 的关系

F1 working 阶段不支持循环切换（用户必须重新触发 Tidy）；F4 增强该能力。

---

#### F5. 跨 App 编排

##### 功能说明

* 不仅编排前台 App 的窗口，还能编排多个相关 App 的窗口
* 例如：同时排列 Chrome + VS Code + Terminal 的所有窗口

##### 风险

跨 App 窗口管理复杂度高，可能涉及窗口归属、z-order 跨 App 协调等问题。建议后期实现。

---

## 三、建议删除或延后功能

| 功能 | 原因 |
|------|------|
| 鼠标交互选择 | Tidy 定位为键盘工具，鼠标选择由 macOS App Exposé 已覆盖 |
| 跨平台 | MVP 阶段成本过高，且 macOS 窗口管理 API 无跨平台对应 |
| 云同步配置 | 非核心价值，本地配置已足够 |
| 窗口缩略图预览 | 真实窗口已排列可见，无需缩略图 |
| 自定义字母字符集 | a-z 是普世默认，开放配置增加复杂度无收益 |
| 拼音/中文标签 | 字母标签是位置标签，非内容标签，无语义需求 |
| 多 Tidy 会话 | 单会话已覆盖 99% 场景，多会话状态管理复杂 |
| 持久化还原快照 | v1 接受崩溃后丢失；持久化引入磁盘 I/O 与状态一致性复杂度 |
| 触控板手势激活 | 与键盘工具定位冲突 |
| 菜单栏点击编排 | 状态栏菜单已有 Trigger Tidy 项，无需额外手势 |

---

## 四、v0.1 验证版与 v1.0 候选版的区分

> 对应 F1_窗口编排核心的首次交付。v0.1 是当前验证版（Validation Slice），v1.0 是正式版候选（Candidate），验证后决定是否纳入。

### v0.1 Validation Slice（验证版）

| 项目 | 范围 |
|------|------|
| 窗口数量 | 2~9（核心场景） |
| 目标屏幕 | 当前焦点屏 |
| 热键 | 固定热键 ⌘⌥T（不可配置） |
| 最大化 | Temporary Maximize（临时放大） |
| 字母标签位置 | 中心偏上，动态约束在屏幕内 |
| AX 失败处理 | 单窗口失败 → 原位置标签降级；>50% 失败终止 |
| App 切换 | 不自动还原，Session 保留，返回后 working 继续 |
| Space 切换 | 自动还原 |
| 权限引导 | 最小权限引导 |
| 状态栏图标 | 3 种（未授权 / 空闲 / 编排中） |
| 偏好设置 | 不做 |

### v1.0 Candidate（正式版候选，验证后决定）

| 项目 | 说明 |
|------|------|
| 窗口数量 | 是否扩展至 >9（最多 26） |
| 偏好设置 | 是否增加偏好设置窗口（热键录制、超时、字体大小、背景色、启动时运行） |
| 状态栏图标 | 是否增加第 4 种"锁定工作"图标状态 |
| App 切换还原 | 是否改变 App 切换自动还原策略 |
| 选中策略 | 是否增加 Focus / Bring Forward 选中策略 |

---

## 五、推荐 MVP 范围

### v1.0 — Tidy 核心功能

| 功能 | 必须 | 说明 |
|------|------|------|
| 状态栏菜单与图标 | ✅ | 5 项菜单 + 4 种图标状态 |
| 全局热键 ⌘⌥T | ✅ | Carbon RegisterEventHotKey 注册，可配置 |
| 权限引导 | ✅ | 辅助功能权限引导窗口（复用 Macim F0 设计） |
| 窗口枚举 | ✅ | CGWindowList + AX 混合，当前 Space 可见窗口 |
| 自适应网格布局 | ✅ | 2-9 个窗口（核心），最多 26（v1.0 候选），按屏幕长宽比自动选择最佳网格 |
| 字母标签覆盖层 | ✅ | 32pt 黄色气泡，中心偏上动态约束，a-z 按 z-order 分配 |
| 选择输入处理 | ✅ | CGEventTap 拦截，单字符即选，无效忽略 |
| 选中窗口最大化 | ✅ | AXSetFrame 设置为目标屏幕 visibleFrame |
| 还原流程 | ✅ | 按快照还原所有窗口到排列前 frame |
| 异常清理 | ✅ | App 切换 Session 保留/Space 切换自动还原/目标 App 退出尽力恢复/超时自动还原 |
| 偏好设置 | ✅ | 5 项配置 + SwiftUI 偏好窗口 |
| AXSetFrame 失败处理 | ✅ | 跳过失败窗口，原位置标签降级，>50% 失败终止 |

### v1.5 — 应用专属配置

| 功能 | 必须 | 说明 |
|------|------|------|
| 应用专属配置（F2） | ✅ | bundleIdentifier 匹配的应用级配置覆盖 |
| 自定义布局模板（F3） | ✅ | 用户保存与切换布局模板 |

### v2.0 — 高级功能

| 功能 | 必须 | 说明 |
|------|------|------|
| working 阶段循环切换（F4） | ✅ | 避免还原→重排→重选的三步流程 |
| 跨 App 编排（F5） | 建议 | 跨 App 窗口编排 |

---

## 六、推荐技术架构

### Target 结构

| Target | 类型 | 职责 | 依赖 |
|--------|------|------|------|
| TidyCore | Framework（SPM Package） | 核心逻辑（窗口枚举、AX 操作、状态机、布局算法） | 纯 Swift + 系统框架，无 AppKit |
| TidyUI | Framework（SPM Package） | UI 层（覆盖层、偏好窗口、状态栏） | AppKit（覆盖层）+ SwiftUI（偏好窗口）+ TidyCore |
| TidyApp | Application（Xcode Native Target） | App 入口、生命周期、依赖注入 | TidyCore + TidyUI |

### 技术选型

| 模块 | 技术 | 说明 |
|------|------|------|
| 窗口枚举 | CGWindowListCopyWindowInfo | 按 PID + onscreen 过滤 |
| 窗口操作 | AXUIElement（kAXPositionAttribute + kAXSizeAttribute） | 标准 AX API，无需私有 API |
| 键盘拦截 | CGEventTap（.cgSessionEventTap + .defaultTap） | 仅 selecting 阶段启用 |
| 热键注册 | Carbon RegisterEventHotKey | 兼容 macOS 12 |
| 覆盖层 UI | NSPanel（.nonactivatingPanel） | AppKit；.popUpMenu 层级；.fullScreenAuxiliary 跨 Space |
| 偏好窗口 UI | NSWindow + SwiftUI content | macOS 12 SwiftUI 已稳定 |
| 状态栏 UI | NSStatusItem + NSMenu | AppKit |
| 并发模型 | Swift Concurrency（async/await + Task） | 简单场景，无需 TaskGroup |
| 响应式框架 | Combine + Swift Concurrency | UI 响应式绑定 |
| 状态管理 | 显式状态机 + Combine UI 桥接 | 5 状态，非法转换触发断言 |
| 架构模式 | 协调器 + 状态机 | 与 Macim 一致 |
| 依赖注入 | 手动 DI（初始化器注入） | 不使用第三方 DI 框架 |
| 配置系统 | UserDefaults + Combine | 5 项配置，实时生效 |
| 日志 | os_log（com.tidy.windowmanagement 子系统） | 关键节点 Info，AX 失败 Error |
| 测试 | XCTest + XCUITest | 单元测试（布局算法、状态机）+ UI 测试（端到端流程） |

### 架构决策摘要

| 决策 | 选择 | 理由 |
|------|------|------|
| 进程间通信 | 进程内 | v1 简单可靠 |
| 覆盖层渲染 | NSPanel + AppKit 原生视图 | macOS 12 上稳定可靠，SwiftUI 与 NSPanel 集成有已知问题 |
| 偏好窗口 | NSWindow + SwiftUI content | macOS 12 SwiftUI 已稳定；偏好窗口交互简单 |
| 键盘事件拦截 | CGEventTap（.defaultTap 可拦截） | 唯一能拦截并消费事件的方案 |
| 并发模型 | Swift Concurrency（async/await） | 简单场景，无复杂并发需求 |
| 状态管理 | 显式状态机 + Combine | 核心状态可审计，UI 用 Combine 自动更新 |
| 偏好存储 | UserDefaults + Combine | 仅 5 项配置，无需 JSON/数据库 |
| 响应式框架 | Combine + Swift Concurrency | macOS 12 下 Combine 是 UI 响应式绑定的标准方案 |
| 架构模式 | 协调器 + 状态机 | 与事件驱动特征匹配 |
| 窗口操作 API | AXUIElement（公开 API） | 不使用 CGS 私有 API，避免 macOS 版本兼容性问题 |
| EventTap 生命周期 | 仅 selecting 阶段启用 | working 阶段不拦截，用户在 App A 上工作不受影响 |

### 隔离原则

* TidyCore 不链接 AppKit（编译器拒绝 `import AppKit`）
* TidyUI 的覆盖层坚持 AppKit；偏好窗口可用 SwiftUI
* Controller 与 UI 之间严格单向数据流：Controller → UI（指令），UI → Controller（delegate 回调）
* 所有跨组件通信通过协议，不通过具体类型引用

---

## 七、关键技术风险

| 风险 | 说明 | 应对策略 |
|------|------|----------|
| AXSetFrame 不稳定 | 部分应用不响应 AX frame 设置 | 单窗口失败：保留原位置，原位置标签降级；>50% 失败终止；维护已知不兼容 App 黑名单 |
| 多显示器坐标 | 高频 Bug 来源 | 全局坐标系；目标屏幕基于焦点窗口；NSScreen.visibleFrame 排除 Dock/菜单栏 |
| macOS 更新 | Apple 经常修改权限 | 仅需辅助功能权限；App Sandbox 不兼容（已移除） |
| CGEventTap 被禁用 | 系统保护机制 | 自动重新启用；失败则退出 selecting 还原所有窗口 |
| 前台 App 切换 | Session 保留，返回后 working 继续 | 监听 NSWorkspace.didActivateApplicationNotification，保留 Session 而非自动还原；Space 切换仍自动还原 |
| Space 切换 | 还原可能错位 | 监听 NSWorkspace.activeSpaceDidChangeNotification，自动还原 |
| Stage Manager | macOS 13+ Stage Manager 改变窗口位置 | v1 检测后显示警告，不深度集成；v2 评估深度集成 |
| 全屏窗口 | 全屏窗口无法移动 | 当前 Space 过滤已排除（全屏窗口在自己 Space） |
| 窗口关闭 | 还原时窗口已不存在 | 跳过该窗口，记录 Info 日志 |
| 目标 App 退出 | working 阶段 App 退出 | 监听 NSWorkspace.didTerminateApplicationNotification，尽力恢复 + 清理 TidySession |
| Tidy 自身崩溃 | 窗口卡在排列状态 | v1 接受丢失；v2 评估持久化快照 |
| 偏好窗口与覆盖层 | SwiftUI 与 NSPanel 集成问题 | 偏好用 NSWindow+SwiftUI；覆盖层坚持 AppKit |
| 字母标签遮挡 | 32pt 标签遮挡窗口内容 | 中心偏上定位，动态约束在屏幕可见区域内；字体大小可配置 |

---

## 八、推荐商业模式

| 版本 | 内容 |
|------|------|
| 免费版 | 完整 v1.0 功能（窗口编排 + 字母选择 + 还原） |
| Pro 买断 | F2 应用专属配置 + F3 自定义布局模板 |
| 后期订阅 | F4 循环切换 + F5 跨 App 编排 + 云同步配置 |

说明：

macOS Power User 群体更偏好买断。Tidy v1.0 完整功能免费，降低用户尝鲜门槛；高级功能买断订阅。

---

## 九、应用界面

Tidy 是**菜单栏应用**（Menu Bar App），没有传统的主窗口界面。

### 状态栏图标

* 位置：macOS 顶部菜单栏右侧
* 图标样式：方形 T 字母图标，简洁设计
* 4 种状态：普通 / ⚠️ 警告（未授权）/ 🔵 蓝点（编排中）/ 🔒 锁标识（锁定工作）；v0.1 仅实现前 3 种
* 交互：左键/右键点击显示下拉菜单

### 状态栏菜单

| 菜单项 | 功能 | 快捷键 | 动态行为 |
|--------|------|--------|----------|
| Grant Accessibility Permission... | 打开权限引导窗口 | — | 仅未授权时显示 |
| **Trigger Tidy** | **触发 Tidy 编排** | **⌘⌥T** | **未授权时禁用；arranging/selecting/working 阶段禁用（避免重复触发）** |
| Preferences... | 打开偏好设置窗口 | ⌘, | — |
| About | 显示关于信息 | — | — |
| Quit | 退出应用 | ⌘Q | working 阶段退出时自动还原所有窗口 |

### 偏好设置窗口

NSWindow + SwiftUI content，4 个标签页（NSTabViewController 或 SwiftUI TabView）：

| 标签页 | 功能 |
|--------|------|
| General | 通用设置：启动时运行、选择阶段超时 |
| Bindings | 快捷键绑定：Tidy 触发热键录制 |
| Appearance | 视觉设置：标签字体大小、标签背景色 |
| About | 关于信息：版本号、作者、许可证、致谢 |

窗口行为：关闭时应用不退出（继续在菜单栏运行）；打开时临时显示 Dock 图标，关闭后恢复为 UIElement 应用（从 Dock 中消失）。

### Tidy 覆盖层

* 窗口类型：NSPanel（.nonactivatingPanel 样式）
* 层级：.popUpMenu（高于普通窗口，低于系统菜单）
* 跨 Space：.fullScreenAuxiliary
* 不抢焦点：ignoresMouseEvents = true
* 组成：字母标签（32pt 黄色气泡，中心偏上）

### 权限引导窗口

首次启动时，若未获得辅助功能权限，在屏幕中央显示 NSPanel 引导窗口：包含 App 图标、权限用途说明、3 步授权指引、"打开系统设置"主按钮和"退出 Tidy"次按钮。仅按需检测权限状态（不轮询），下次触发功能时检测到已授权则自动关闭。

**设计参考**：Macim F0 权限引导视觉原型。

### 应用生命周期状态

| 状态 | Dock 图标 | 菜单栏图标 | 说明 |
|------|----------|-----------|------|
| 未授权（引导窗口打开） | ✅ 显示 | ⚠️ 警告 | 权限引导窗口居中显示；关闭窗口即退出应用 |
| 已授权（空闲） | ❌ 隐藏 | ✅ 普通 | 正常工作状态 |
| 已授权（偏好设置打开） | ✅ 显示 | ✅ 普通 | 临时显示 Dock 图标 |
| 已授权（arranging / selecting） | ❌ 隐藏 | 🔵 蓝点 | 编排进行中，通常 < 30 秒 |
| 已授权（working） | ❌ 隐藏 | 🔒 锁标识（v1.0 候选） | 用户在目标 App 上工作，时长不定 |

---

## 十、实现路线图

阶段推进顺序、IN/OUT 边界、Exit Gate 和依赖关系由 [Tidy_开发路线图.md](Tidy_开发路线图.md) 统一定义，本节不再重复。

F1 内部子功能依赖见上文 F1.0~F1.6 表格；详细任务与命令由各阶段实现计划承载。

---

## 十一、最终产品方向（建议）

Tidy 不应定位为：

* 通用窗口管理工具（与 Rectangle/Magnet 竞争）
* 鼠标驱动的窗口切换器（与 macOS App Exposé 竞争）

而应定位为：

> 一个聚焦"键盘驱动多窗口工作流"的 macOS 系统级工具。

核心竞争力：

> 一键铺开 → 字母选择 → 工作还原 的极简键盘流。

版本演进路径：

> P0_技术探针（准备）→ F0~F0.1（权限与入口）→ F1（编排核心）→ F2~F3（应用配置与模板）→ F4~F5（循环切换与跨 App）

---

## 版本记录

- **v1.3**（2026-07-30）
  - 消除与 [Tidy_开发路线图.md](Tidy_开发路线图.md) 的内容重叠：准备阶段和实现路线图两节改为引用路线图，不再重复阶段定义、IN/OUT、Exit Gate；
  - 路线图为阶段推进的最高权威，功能列表为功能细节的唯一来源。
- **v1.2**（2026-07-28）
  - 新增第四节"v0.1 验证版与 v1.0 候选版的区分"：明确 v0.1 Validation Slice 与 v1.0 Candidate 的拆分；
  - F1.0 改为 Integration Baseline（集成基线），仅做依赖组装与空状态机启动；
  - 修正 M1-M5 模块依赖图，与表格一致（A ──→ B = A depends on B）；
  - 字母标签定位从"窗口左上角内侧"改为"窗口中心偏上，动态约束在屏幕可见区域内"；
  - App 切换不再自动还原，改为 Session 保留、返回后 working 继续；Space 切换仍自动还原；目标 App 退出尽力恢复 + 清理 Session；
  - AXSetFrame 单窗口失败改为原位置标签降级模式，>50% 失败仍终止；
  - 窗口数量核心收敛为 2-9，10-26 标注为 v1.0 Candidate；
  - 状态栏图标 v0.1 仅实现 3 种（未授权/空闲/编排中），锁定工作为 v1.0 候选；
  - 偏好设置（F1.6）改为 v1.0 候选，v0.1 不做偏好窗口；
  - M1 基础设施去掉偏好窗口，改为"未来承载偏好窗口的模块"；
  - CGWindow↔AXWindow 匹配算法从"容差 1pt"改为"P0 待验证候选算法"，产出 MATCHED / AMBIGUOUS / UNMATCHED；
  - 路线图新增对 `Tidy_开发路线图.md` 的引用，明确其为阶段推进最高权威；
  - 节编号顺延（新增第四节，原四~十顺延为五~十一）。
- **v1.1**（2026-07-28）
  - 同步 [docs.md](../docs.md) v0.5 阶段推进顺序：新增"准备阶段"小节，引入 `P0_技术探针`（技术验证 + 项目骨架），明确其先于功能优先级 P0/P1/P2；
  - 新增"维度说明"：本节 `P0/P1/P2` 是**功能优先级**，与 `docs/phases/` 下的 `P0_技术探针` 准备阶段是不同维度；
  - 第九节"实现路线图"改写为 P0_技术探针 → F0 → F0.1 → F1 → F2~F5 的阶段表，与 docs.md 第 4 节对齐；
  - 第十节"版本演进路径"改为 P0 → F0~F5 阶段编号表述。
- **v1.0**（2026-07-25）
  - 初始版本
  - 定义 P0 MVP 核心功能：F0 权限引导、F0.1 状态栏与快捷键、F1 窗口编排核心（F1.0-F1.6 子功能）
  - 定义 P1 高频增强：F2 应用专属配置、F3 自定义布局模板
  - 定义 P2 差异化：F4 working 阶段循环切换、F5 跨 App 编排
  - 5 状态机：idle / arranging / selecting / working / restoring
  - 5 项配置：热键、超时、字体大小、背景色、启动时运行
  - 默认热键 ⌘⌥T，单热键 Toggle 模式
  - 自适应网格布局，上限 26 个窗口（a-z 字母标签）
  - 字母标签 UI：32pt 黄色气泡，左上角内侧，Macim 屏幕数字标签风格
  - 还原语义：撤销排列，无视 working 阶段手动操作
  - 技术栈：macOS 12+ / Swift 5.7+ / SPM 三 target / AppKit + SwiftUI 偏好窗口
