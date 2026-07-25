# Tidy 窗口管理 App 市场调研报告

> 最后更新：2026-07-25 | 版本：v1.0
> 调研方法：实时网络调研（15+ 竞品 + Reddit/HN/App Store 用户痛点挖掘）

[TOC]

## 一、项目定位与调研目标

### 项目愿景

打造一个 macOS 系统级窗口编排工具，让多窗口工作者能用键盘完成"一键铺开 → 字母选择 → 工作还原"的完整工作流。

核心理念：

> 像整理桌面一样整理窗口：铺开、选中、用完归位。

### 调研目标

1. **验证 Tidy 三件套差异化定位**：一键铺开前台 App 所有可见窗口 + 字母标签选择 + 单热键还原
2. **梳理 5 大品类竞品全景**：系统内置多窗口选择 / 窗口位置记忆 / 手动窗口管理 / 平铺式管理器 / 窗口切换器
3. **挖掘用户真实痛点**：基于 Reddit / Hacker News / App Store 评论的真实用户声音
4. **校准商业模式与定价**：参考赛道惯例，调整原 spec 中的订阅策略
5. **识别市场机会与风险**：竞品维护状态、新入场者、技术风险

---

## 二、核心假设（创业与产品视角）

### 目标用户画像

#### 第一目标用户：多窗口工作者（核心用户，占比 50%）

典型人群：

* 开发者（多个 IDE 窗口、多个终端、多个浏览器窗口）
* 设计师（多个 Figma 文件、多个 Photoshop 文档）
* 写作者 / 研究员（多个浏览器窗口、多个 Word/Notion 文档）
* PM / 运营（多个浏览器窗口、多个 Slack 窗口、多个文档）

核心诉求：

> 同一 App 多窗口时，快速看到所有窗口并选择一个工作，做完还原。

特点：

| 特点 | 说明 |
|------|------|
| 工作流频繁被打断 | Cmd+Tab 切换效率低，App Exposé 缩略图太小 |
| 愿意为效率付费 | macOS Power User 主力，付费意愿高 |
| 多显示器场景多 | 外接显示器时窗口管理痛点加剧 |
| 反馈质量高 | 能提供专业建议与 Bug 报告 |

---

#### 第二目标用户：多显示器 Power User（扩展用户，占比 30%）

典型场景：

* 办公时外接显示器，回家拔掉显示器
* 会议室投影，临时单屏工作
* 多屏办公（主屏 + 副屏 + iPad 副屏）

价值主张：

> 焦点屏聚合 + 还原，解决多屏窗口分散问题。

特点：付费意愿中高，对"还原"功能敏感。

---

#### 第三目标用户：普通多任务用户（潜力用户，占比 20%）

典型场景：

* 浏览器开 10+ 标签页 + 多窗口
* Office 多文档对比
* 邮件 + 日历 + 文档同时打开

价值主张：

> 用键盘快速选择窗口，替代鼠标点击 App Exposé 缩略图。

特点：付费意愿低，是免费版用户，未来转化为 Pro 的概率较低。

---

### 用户核心痛点

当前 macOS 上多窗口工作流的痛点：

* App Exposé 缩略图太小看不清内容
* App Exposé / Mission Control **十年未支持键盘选择**（用户原话："十年都没实现键盘选择"）
* Cmd+Tab 切换的是 App 而非窗口（"CMD-tab brings ALL of your terminal windows to the front"）
* 同一 App 多窗口时无直观切换方式（VS Code 多个 issue 验证）
* 现有窗口管理工具（Rectangle/Magnet）只解决"摆窗口"，不解决"选窗口"
* Stage Manager 刚硬不灵活、不还原位置、外接屏不支持
* 多显示器拔插后窗口乱跑

一句话痛点：

> macOS 上仍然缺少一个"键盘驱动、按需铺开、可还原"的多窗口工作流工具。

---

### 核心价值主张

不是"再做一个 Rectangle"。

而是：

> 建立"瞬时整理 + 字母标签 + 可撤回"的窗口工作流范式。

现有工具能力割裂：

| 需求 | 现有工具 |
|------|---------|
| 单窗口摆放 | Rectangle / Magnet / Moom / BetterSnapTool |
| 自动平铺 | Amethyst / yabai |
| 窗口切换 | Contexts / Witch / Cmd+Tab |
| 多窗口鸟瞰 | App Exposé / Mission Control |
| 窗口位置记忆 | Stay（已免费）/ Moom Layouts |
| 专注式管理 | Stage Manager |

本项目目标：

> 把"识别 + 选择 + 还原"整合到一个热键流程，是首个完整覆盖此工作流的工具。

---

## 三、竞品分析

### 调研渠道

| 渠道 | 价值 |
|------|------|
| Mac App Store | 用户评分与评论（Magnet 4.9/5, 166K 评分；Witch 4.8/5, 3,458 评分） |
| GitHub | 开源方案与技术实现（Rectangle 29.6k ⭐, yabai 26.6k ⭐, Amethyst 15.5k ⭐） |
| Reddit（r/macapps, r/mac） | 用户真实痛点与新工具讨论 |
| Hacker News | Power User 群体反馈与竞品对比 |
| 独立开发者博客与官网 | 商业模式与定价 |
| MacRumors / Apple Discussions | 系统升级后的兼容性问题 |

---

### 竞品对比总矩阵

#### A1 系统内置多窗口选择

| App | 定位 | 核心能力 | 一键铺开 | 字母选择 | 单热键还原 | 多屏 | 缺点 |
|-----|------|---------|---------|---------|-----------|------|------|
| **App Exposé** | 单 App 多窗口鸟瞰 | 缩略图切换 | ✅（前台 App） | ❌ | ❌ | 仅当前屏 | 缩略图小、键盘支持弱、Tahoe 26 动画卡顿 |
| **Mission Control** | 全局窗口鸟瞰 | 缩略图切换 | ❌（全局） | ❌ | ❌ | 仅当前屏 | **十年无键盘选择**、占满全屏、最小化窗口不显示 |
| **Stage Manager** | 专注式窗口管理 | 当前窗口居中 + 侧栏 | ❌ | ❌ | ❌ | ❌ **仅主屏** | 新 App 强制开新舞台、分组记忆丢失、外接屏无效 |

#### A2 窗口位置记忆/还原

| App | 定位 | 核心能力 | 定价 | 维护状态 | 缺点 |
|-----|------|---------|------|---------|------|
| **Stay** | 跨显示器窗口位置记忆 | 按显示器组合存储/还原布局 | **2025-08 起免费**（原 $14.99） | ✅ v1.5.1 (2025-08) | 不解决"快速选择"、Chrome 需反复 link、Spaces 配合有 bug |

#### A3 手动窗口管理

| App | 定价 | 一键铺开 | 字母选择 | 单热键还原 | 维护状态 | GitHub Stars / 评分 |
|-----|------|---------|---------|-----------|---------|------|
| **Rectangle**（免费） | 免费 | ❌ | ❌ | ⚠️ 单步 undo | ✅ v0.98 (2026-07) | 29.6k ⭐ |
| **Rectangle Pro** | $9.99 买断 | ❌（需预设 App 列表） | ❌ | ✅ 通过 saved layout | ✅ v3.80 (2026-06) | — |
| **Magnet** | $4.99 买断 | ❌ | ❌ | ❌ | ⚠️ 1 年+未更新 | 4.9/5, 166K 评分 |
| **Moom** | $15 买断 | ⚠️ Any-Window Layouts（最接近） | ❌ | ✅ 通过 saved layout | ✅ v4.5.1 | — |
| **BetterSnapTool** | $1.99 买断 | ❌ | ❌ | ⚠️ snap 还原 | ⚠️ 近 2 年未更新 | Editors' Choice |
| **Swish** | $16 买断 | ❌ | ❌ | ❌ | ✅ v1.13.2 (2026) | 30+ 手势 |

#### A4 平铺式窗口管理器

| App | 定价 | 平铺策略 | 一键铺开 | 字母选择 | 单热键还原 | SIP 要求 | 维护状态 |
|-----|------|---------|---------|---------|-----------|---------|---------|
| **Amethyst** | 免费开源 | Tall/Wide/BSP/3-Col 等 15+ | ❌ 常驻平铺 | ❌ | ❌ | 不需要 | ✅ v0.24.3 (2026-04), 15.5k ⭐ |
| **yabai** | 免费开源 | BSP | ❌ 常驻平铺 | ❌ | ❌ | ⚠️ 高级功能必须 disable SIP | ⚠️ 慢维护, 26.6k ⭐ |
| **chunkwm** | 免费开源 | BSP/Monocle/Stack | — | — | — | — | ❌ **已废弃**（被 yabai 取代） |

#### A5 窗口切换器

| App | 定价 | 切换方式 | 字母选择 | 维护状态 | 缺点 |
|-----|------|---------|---------|---------|------|
| **Contexts** | $9.99 买断 | 搜索式 + 列表 + 侧栏 + 手势 | ⚠️ 搜索快捷键（1-2 字符） | ⚠️ 4 年未更新 | "偷焦点" bug、维护停滞 |
| **HyperDock** | $6.95 shareware | Dock 悬停预览 | ❌ | ❌ **实质停更**（仅支持到 Mojave） | Catalina 起崩溃、Apple Silicon 不工作 |
| **Witch** | $13.99 买断 | 列表 + 搜索 + 菜单栏 | ⚠️ 数字键 1-9 直跳 | ✅ v4.7 (2025-12), 4.8/5 | 面板出现慢、Secure Text Input 下失效 |

---

### 关键发现

**Tidy 三件套差异化验证**：

> **15+ 竞品中无一同时满足**"一键铺开前台 App 所有可见窗口 + 字母标签选择 + 单热键还原"。

最接近的竞品：

| 竞品 | 接近点 | 缺失点 |
|------|--------|--------|
| **Moom Any-Window Layouts** | 影响 N 个最近窗口 | 需预先保存、不区分前台 App、无字母标签 |
| **Contexts 搜索快捷键** | 1-2 字符直达窗口 | 需用户记忆绑定、无铺开、无还原 |
| **App Exposé** | 前台 App 窗口铺开 | 缩略图非真实窗口、鼠标点击、无还原 |

---

### 用户真实痛点（基于 Reddit/HN/App Store）

#### Mission Control 十年痛点

| 问题 | 用户原话 |
|------|---------|
| 无键盘选择 | "Mission Control has no keyboard navigation for a decade"（HN） |
| 占满全屏 | "Mission Control takes over the whole screen, breaking my flow" |
| 最小化窗口不显示 | "Why doesn't Mission Control show minimized windows?" |

#### Cmd+Tab 切换痛点

| 问题 | 用户原话 |
|------|---------|
| 切 App 而非窗口 | "CMD-tab brings ALL of your terminal windows to the front" |
| 多次按键 | "I have 5 VS Code windows, Cmd+Tab is useless" |

#### 同 App 多窗口切换痛点（VS Code 多 issue 验证）

VS Code Issue #324309、#322745、#11381 三个独立 issue 都在描述此痛点：
> "Switching between multiple windows of the same app is painful"

#### Stage Manager 痛点

| 问题 | 用户原话 |
|------|---------|
| 刚硬不灵活 | Digital Trends 编辑公开认错："I was wrong about Stage Manager" |
| 分组丢失 | Mac Power Users 标题："Spaces with complications" |
| 外接屏无效 | "Stage Manager doesn't work on external displays" |

#### 多屏拔插痛点

| 问题 | 用户原话 |
|------|---------|
| 窗口乱跑 | "Unplugging my monitor scatters all my windows" |
| 现有方案碎片化 | Display Maid、Stay、Moom Layouts、Macscope Scopes 都在解决 |

#### 键盘驱动窗口选择需求（HN 一年内涌现 5+ 新工具）

| 新工具 | 解决方案 |
|--------|---------|
| **rcmd** | "Never reach for your dock again" — 右 Cmd + 首字母切 App |
| **HopTab** | 键盘驱动窗口切换 |
| **Macscope** | Scopes（窗口布局保存/还原）+ 切换 |
| **DashPane** | 键盘驱动的多窗口管理 |
| **Witch 4.7** | 数字键 1-9 直跳前 10 项 |

> 用户对"键盘选择窗口"的需求在过去一年被多个新工具验证，但**没有任何一个整合了 Tidy 的三件套**。

---

## 四、市场机会分析（重点）

### 最大机会：三件套整合的空白定位

当前所有产品都存在一个共同问题：

> 没有任何产品同时做到"按需铺开 + 字母标签选择 + 单热键还原"。

现有方案的割裂：

| 需求维度 | 现有方案 | 缺陷 |
|---------|---------|------|
| 看所有窗口 | App Exposé / Mission Control | 缩略图非真实窗口、鼠标点击、无还原 |
| 键盘选窗口 | Contexts / Witch / rcmd | 需用户记忆或仅前 10 项、无铺开 |
| 还原窗口位置 | Stay / Moom Layouts | 需预先保存、不解决"快速选择" |
| 自动整理 | Amethyst / yabai | 常驻平铺、学习成本高、需禁用 SIP |

因此：

> Tidy 的"一键铺开 + 字母标签 + 单热键还原"三件套整合是当前市场最大的空白机会。

---

### 真实窗口 vs 缩略图机会

App Exposé / Mission Control 的核心痛点是缩略图太小：

> 当窗口多于 5 个时，缩略图小到看不清内容。

Tidy 铺开**真实窗口**到全屏网格，用户能立即读取窗口内容判断，且选择后**直接进入工作**（无需"放大过渡"）。

这是 Tidy 相对所有缩略图方案的根本性差异：

| 维度 | App Exposé 缩略图 | Tidy 真实窗口 |
|------|------------------|--------------|
| 内容可读性 | 5+ 窗口时极差 | 26 窗口内良好 |
| 选择后状态 | 退出缩略图 → 窗口恢复原大小 | 直接最大化工作 |
| 工作流连续性 | 中断（需重新调整窗口） | 连续（直接工作） |

---

### 字母标签 vs 搜索/数字键机会

Contexts 用"搜索快捷键"（1-2 字符查询 + 记忆绑定），Witch 用"数字键 1-9 直跳前 10 项"，rcmd 用"右 Cmd + 首字母切 App"。

这些方案的共同问题：

| 方案 | 用户认知负担 | 覆盖范围 |
|------|------------|---------|
| Contexts 搜索快捷键 | 高（需记忆每个窗口的快捷键） | 任意窗口 |
| Witch 数字键 1-9 | 低 | 仅前 10 项 |
| rcmd 首字母切 App | 低 | App 级，非窗口级 |
| **Tidy 字母标签** | **低（系统主动分配，可见即输入）** | **26 个窗口全覆盖** |

Tidy 的字母标签是**系统主动给每个窗口分配可见标签**，用户无需记忆，看到即输入，是认知负担最低的方案。

---

### 单热键还原机会

Stay 已转免费暗示"窗口位置还原"难单独收费，但这恰恰证明"还原"是用户刚需。

现有还原方案的痛点：

| 方案 | 痛点 |
|------|------|
| Stay | 需预先 Store，按显示器组合存储 |
| Moom Layouts | 需预先保存布局，绑定特定 App 集合 |
| Rectangle Pro | 通过 saved layout，需预先配置 |

Tidy 的"单热键还原"是**自动捕获排列前 frame + 单键撤回**，无需用户预先配置，是体验最简的方案。

---

### 新兴竞品机会窗口

HN 一年内涌现的新工具（rcmd、HopTab、Macscope、DashPane）证明：

1. 用户对"键盘驱动窗口管理"的需求正在被激发
2. 但这些工具都是**单点解决方案**，未整合三件套
3. Tidy 有先发优势窗口（6-12 个月内无直接整合竞品）

---

## 五、技术可行性与系统限制

### 核心技术能力

| 能力 | 技术方案 | 已在 Macim 验证 |
|------|---------|----------------|
| 全局热键 | Carbon RegisterEventHotKey | ✅ |
| 键盘拦截 | CGEventTap（.cgSessionEventTap + .defaultTap） | ✅ |
| 窗口枚举 | CGWindowListCopyWindowInfo + AXUIElement | ✅ |
| 窗口操作 | AXUIElement（kAXPositionAttribute + kAXSizeAttribute） | ✅ |
| 覆盖层 UI | NSPanel（.nonactivatingPanel + .popUpMenu） | ✅ |
| 目标屏判定 | AXUIElement kAXFocusedWindowAttribute + NSScreen | ✅ |

---

### 必需系统权限

| 权限 | 用途 | 风险等级 | Tidy 是否需要 |
|------|------|---------|--------------|
| Accessibility | 操作窗口 AXFrame | 高 | ✅ 必须 |
| Input Monitoring | CGEventTap 全局键盘监听 | 高 | ✅ 必须 |
| Screen Recording | OCR / 截图分析 | 中 | ❌ 不需要 |

说明：

仅需 2 项权限（vs Macim 的 3 项），权限授权失败仍是核心用户流失点，需重点优化首次启动体验。

---

### 沙盒与 Mac App Store 风险

该类工具存在较高审核风险：

* 全局事件拦截（CGEventTap）
* 自动化控制（AXUIElement）
* 辅助功能深度访问
* 输入监听

参考竞品渠道策略：

| 产品 | 上架 Mac App Store | 原因 |
|------|------------------|------|
| Magnet | ✅ | 沙盒兼容（仅用 Accessibility，不用 CGEventTap） |
| BetterSnapTool | ✅ | 同上 |
| Witch（旧版） | ✅ | 沙盒兼容 |
| Rectangle | ❌ | 直接分发（dmg / Homebrew） |
| Rectangle Pro | ❌ | Paddle 直销 |
| Moom（新版） | ❌ | 官网直销 + App Store 旧版 |
| Swish | ❌ | 官网直销（需非沙盒权限） |
| Contexts | ❌ | 官网直销 |
| Amethyst / yabai | ❌ | 开源直接分发 |

**Tidy 渠道策略建议**：

| 渠道 | 建议 | 原因 |
|------|------|------|
| Mac App Store | ⚠️ 可选（沙盒限制） | Tidy 需要 CGEventTap，与沙盒不兼容；可考虑功能受限的 MAS 版本 |
| 官网直售（Notarized） | ✅ 推荐 | 与 Rectangle Pro / Swish / Contexts 一致 |
| Setapp | ✅ 强烈推荐 | 与 Swish 同档，触达订阅用户群 |

---

## 六、推荐技术栈

| 模块 | 推荐技术 | 说明 |
|------|---------|------|
| 主语言 | Swift 5.7+ | 与 Macim 一致 |
| 最低系统 | macOS 12 Monterey | 覆盖主流用户 |
| UI | AppKit（覆盖层、状态栏）+ SwiftUI（偏好窗口） | macOS 12 SwiftUI 已稳定 |
| 窗口操作 | AXUIElement（公开 API） | 不使用 CGS 私有 API |
| 键盘拦截 | CGEventTap（.defaultTap 可拦截） | 仅 selecting 阶段启用 |
| 热键注册 | Carbon RegisterEventHotKey | 兼容 macOS 12 |
| 覆盖层 | NSPanel + AppKit 原生视图 | macOS 12 稳定可靠 |
| 配置存储 | UserDefaults + Combine | 5 项配置，无需 JSON/数据库 |
| 更新系统 | Sparkle | 与 Rectangle Pro / Swish 一致 |
| 测试 | XCTest + XCUITest | 单元测试 + UI 测试 |
| 日志 | os_log（com.tidy.windowmanagement） | 关键节点 Info，AX 失败 Error |

说明：

Swift + AppKit + AXUIElement 是 macOS 窗口管理工具的唯一稳定组合，所有主流竞品（Rectangle / Amethyst / Contexts / Witch）均采用此栈。SwiftUI 仅用于偏好窗口（macOS 12 已稳定），覆盖层坚持 AppKit。

---

## 七、MVP 聚焦建议（重要）

独立开发最大风险：

> 过早做平台 / 过早做差异化功能堆砌。

### 推荐 MVP 范围

#### 第一阶段只解决：

> "一键铺开前台 App 多窗口 + 字母选择 + 还原"的完整闭环。

#### MVP 必做功能

| 功能 | 保留 | 说明 |
|------|------|------|
| 状态栏图标 + 菜单 | ✅ | 菜单栏应用入口 |
| 全局热键 ⌘⌥T | ✅ | Carbon RegisterEventHotKey |
| 权限引导 | ✅ | Accessibility + Input Monitoring |
| 窗口枚举（CGWindowList + AX） | ✅ | 当前 Space 可见窗口 |
| 自适应网格布局 | ✅ | 2-26 个窗口 |
| 字母标签覆盖层（32pt 黄色气泡） | ✅ | a-z 按 z-order 分配 |
| 选择输入处理（CGEventTap） | ✅ | 单字符即选 |
| 选中窗口最大化 | ✅ | AXSetFrame |
| 还原流程 | ✅ | 按快照还原 |
| 异常清理 | ✅ | App/Space 切换自动还原 |
| 偏好设置（5 项配置） | ✅ | 热键/超时/字体/颜色/启动 |
| AXSetFrame 失败处理 | ✅ | 跳过失败窗口 |

#### MVP 暂时不做

| 功能 | 原因 |
|------|------|
| 应用专属配置（F2） | Pro 功能，v1.5 再做 |
| 自定义布局模板（F3） | Pro 功能，v1.5 再做 |
| working 阶段循环切换（F4） | Pro 功能，v2.0 再做 |
| 跨 App 编排（F5） | v2.0+ 后期 |
| 鼠标交互选择 | Tidy 定位为键盘工具 |
| 跨平台 | macOS 窗口 API 无跨平台对应 |
| 云同步配置 | 非核心价值 |
| 窗口缩略图预览 | 真实窗口已可见 |
| 持久化还原快照 | v1 接受崩溃丢失 |
| 触控板手势激活 | 与键盘工具定位冲突 |
| 多 Tidy 会话 | 单会话已覆盖 99% 场景 |

---

## 八、商业化分析

### 用户付费意愿

macOS Power User 工具市场验证充分：

| 产品 | 收费模式 | 价格 |
|------|---------|------|
| Rectangle Pro | 买断 | $9.99 |
| Magnet | 买断 | $4.99 |
| Moom | 买断 | $15 |
| BetterSnapTool | 买断 | $1.99 |
| Swish | 买断 | $16 |
| Contexts | 买断 | $9.99 |
| Witch | 买断 | $13.99 |
| Stay | 免费（原 $14.99） | $0 |
| BetterTouchTool | 订阅 | $9.5/年 |

结论：

> 窗口管理赛道**买断制占绝对主导**，订阅制极罕见且常被吐槽。

### 推荐商业模式（修订）

基于调研发现，**取消订阅策略**，全买断制：

| 版本 | 内容 | 定价 |
|------|------|------|
| 免费版 | v1.0 完整核心功能（F0/F0.1/F1.0-F1.6） | $0 |
| Pro 买断 | F2 应用专属配置 + F3 自定义布局模板 + F4 working 阶段循环切换 | **$9.99** |
| 后期版本 | F5 跨 App 编排 | 含在 Pro 内（已购用户免费升级） |

理由：

1. **赛道惯例**：8/9 主流竞品都是买断，订阅会引起价格抗议
2. **Stay 转免费的教训**：窗口位置还原类功能难单独收费，应捆绑在 Pro
3. **$9.99 是甜蜜点**：与 Rectangle Pro、Contexts 同档，低于 Moom/Swish/Witch，用户接受度高
4. **F4 循环切换含在 Pro**：避免拆分过细
5. **F5 跨 App 编排免费升级**：作为长期价值锚点
6. **独立开发可持续性**：买断 + 量大可支撑，参考 Rectangle Pro 单一开发者模式

---

### 渠道策略

| 渠道 | 优先级 | 说明 |
|------|--------|------|
| 官网直售（Notarized + Sparkle 更新） | P0 | 与 Rectangle Pro / Swish / Contexts 一致 |
| Setapp | P1 | 触达订阅用户群，与 Swish 同档 |
| Mac App Store | P2 | 沙盒限制可能无法支持 CGEventTap；可考虑功能受限版本 |
| GitHub（开源） | ❌ 不建议 | Tidy 是商业产品，不开源 |

---

## 九、用户核心使用路径

### 主流程：多窗口选择工作

```
按 ⌘⌥T
  → 前台 App 所有可见窗口被铺开到焦点屏网格
  → 每个窗口左上角显示字母标签（a-z）
  → 用户按字母
  → 对应窗口最大化
  → 用户工作
  → 按 ⌘⌥T
  → 所有窗口还原到排列前位置
```

### 异常流程：仅 1 个窗口

```
按 ⌘⌥T
  → 显示通知"Tidy: 仅 1 个可见窗口，无需排列"
  → 回到 idle
```

### 异常流程：选择阶段取消

```
按 ⌘⌥T
  → 窗口铺开 + 字母标签显示
  → 用户按 Esc / ⌘⌥T / 30 秒无操作
  → 所有窗口还原
  → 回到 idle
```

### 异常流程：工作阶段切换 App

```
按 ⌘⌥T
  → 铺开 + 选择 + 最大化
  → 用户 Cmd+Tab 切到其他 App
  → Tidy 自动还原所有窗口
  → 回到 idle
```

### 多屏流程

```
用户在屏幕 1 工作时按 ⌘⌥T
  → 屏幕 1 + 屏幕 2 上的前台 App 窗口都被搬到屏幕 1
  → 网格排列
  → 选择 + 最大化
  → 工作
  → 按 ⌘⌥T
  → 所有窗口还原到原屏原位置（包括回到屏幕 2）
```

---

## 十、风险列表

| 风险 | 说明 | 应对策略 |
|------|------|----------|
| AXSetFrame 不稳定 | 部分应用（Logic Pro、Final Cut Pro）不响应 AX frame 设置 | 单窗口失败跳过；>50% 失败终止；维护已知不兼容 App 黑名单 |
| macOS 更新破坏兼容 | Apple 经常修改权限（TCC/Accessibility）；Tahoe 26 已导致 yabai/Amethyst/Rectangle 短暂失效 | 仅需 2 项权限（Accessibility + Input Monitoring）；建立快速适配机制；关注 macOS beta |
| CGEventTap 被禁用 | 系统保护机制（.tapDisabledByTimeout / .tapDisabledByUserInput） | 自动重新启用；失败则退出 selecting 还原所有窗口 |
| 前台 App 切换 | 还原可能错位 | 监听 NSWorkspace.didActivateApplicationNotification，自动还原 |
| Space 切换 | 还原可能错位 | 监听 NSWorkspace.activeSpaceDidChangeNotification，自动还原 |
| Stage Manager 冲突 | macOS 13+ Stage Manager 改变窗口位置 | v1 检测后显示警告，不深度集成；v2 评估深度集成 |
| 多显示器坐标 | 高频 Bug 来源（所有竞品共性痛点） | 使用 NSScreen.visibleFrame；目标屏幕基于焦点窗口中心 |
| 全屏窗口 | 全屏窗口无法移动 | 当前 Space 过滤已排除（全屏窗口在自己 Space） |
| 窗口关闭 | 还原时窗口已不存在 | 跳过该窗口，记录 Info 日志 |
| 目标 App 退出 | working 阶段 App 退出 | 监听 NSWorkspace.didTerminateApplicationNotification，清理 TidySession |
| Tidy 自身崩溃 | 窗口卡在排列状态 | v1 接受丢失；v2 评估持久化快照 |
| 字母标签遮挡 | 32pt 标签遮挡窗口内容 | (8, 8) 偏移；字体大小可配置 |
| 新兴竞品涌现 | rcmd/HopTab/Macscope/DashPane 等可能整合三件套 | 6-12 个月先发优势窗口；快速迭代 v1.5/v2.0 |
| 定价压力 | Rectangle 免费 + Magnet $4.99 形成价格天花板 | Tidy 差异化足够明显，$9.99 有空间；免费版功能完整降低尝试门槛 |
| 用户教育成本 | "Tidy 不是另一个 Rectangle" 需要解释 | 营销文案聚焦"工作流"而非"窗口管理"；Demo 视频为核心营销资产 |

---

## 十一、阶段路线图

| 阶段 | 功能 | 目标 | 商业化 |
|------|------|------|--------|
| **MVP v1.0** | F0 权限引导 + F0.1 状态栏与热键 + F1 窗口编排核心（F1.0-F1.6） | 核心闭环 | 免费 |
| **v1.5** | F2 应用专属配置 + F3 自定义布局模板 | Pro 转化 | Pro $9.99 买断 |
| **v2.0** | F4 working 阶段循环切换 | 提升留存 | 含在 Pro |
| **v2.5** | F5 跨 App 编排 | 差异化竞争 | 已购用户免费升级 |
| **v3.0** | 持久化还原快照 + Stage Manager 深度集成 | 生态扩展 | 评估 |

---

## 十二、最终定位（建议）

一句话产品定义：

> 一个聚焦"键盘驱动多窗口工作流"的 macOS 系统级工具：一键铺开 → 字母选择 → 工作还原。

核心目标：

> 让多窗口工作者用键盘完成"看到所有窗口 → 选一个工作 → 完事归位"的完整闭环，不依赖鼠标，不破坏原布局。

与现有产品的根本差异：

| 维度 | 现有产品 | Tidy |
|------|---------|------|
| 工作流 | 单点功能（摆放/切换/还原） | 完整闭环（铺开 → 选择 → 还原） |
| 选择方式 | 鼠标点击缩略图 / 数字键前 10 / 搜索记忆 | 系统主动分配字母标签，可见即输入 |
| 还原语义 | 需预先保存布局 | 自动捕获 + 单键撤回 |
| 窗口状态 | 缩略图 / 自动平铺 | 真实窗口按需铺开 |
| 心智模型 | "管理窗口位置" | "整理窗口工作流" |

版本演进路径：

> v1.0 单 App 多窗口编排（免费）→ v1.5 应用专属配置与自定义布局（Pro）→ v2.0 循环切换（Pro）→ v2.5 跨 App 编排（Pro 免费升级）→ v3.0 持久化与系统集成

---

## 版本记录

- **v1.0**（2026-07-25）
  - 初始版本，基于实时网络调研
  - 覆盖 5 大品类 15+ 竞品（A1 系统内置 / A2 位置记忆 / A3 手动管理 / A4 平铺式 / A5 切换器）
  - 验证 Tidy 三件套差异化定位（无一竞品同时满足）
  - 三层用户画像：多窗口工作者（核心）/ 多显示器 Power User（扩展）/ 普通多任务用户（潜力）
  - 修订商业模式：取消订阅，全买断制（$9.99 Pro）
  - 识别 15 项风险与应对策略
  - 关键发现：Stay 已转免费、Magnet/BetterSnapTool/Contexts 维护停滞、yabai 需禁 SIP、HyperDock 实质停更、HN 一年涌现 5+ 键盘驱动窗口工具
