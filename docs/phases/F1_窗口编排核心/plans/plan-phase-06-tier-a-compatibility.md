# Phase 6: Tier A 兼容性回归 + 性能基线

> Phase ID: 6 | slug: tier-a-compatibility
> 对应规格：[F1_01](../F1_01_阶段需求与验收.md) NFR 5.3 / [F1_03](../F1_03_测试用例表.md) 第 9 节
> 依赖：Phase 1-5（所有代码变更完成）

## 1. Goal

在 Tier A App 集上完成兼容性回归与性能基线测量：

- 5 个 Tier A App（Xcode / VS Code / Finder / Safari / Chrome）× 3 N（2 / 5 / 9）矩阵手动测试
- 完整闭环 + 布局规则 + 边界 + 生命周期 + 异常恢复 + App 退出全覆盖
- 性能基线测量（P95 latency / t0 / t1 / t2），输出基线报告
- 设定 NFR 5.1 性能门槛（基于 P0 baseline + F1 实测）
- 修复兼容性问题（若有）

**Tier B 测试性质说明**：F1_03 TC-F1-006-05 提到 Tier B App（如系统设置）用于异常恢复测试。Tier B 测试为**参考性测试**，记录结果但**不阻塞 F1 Exit Gate**（按路线图 Tier B 定义：必须测试、必须记录；允许 PASS / LIMITED / LABEL_ONLY / UNSUPPORTED）。若 Tier B 发现 Blocker 级问题，记录为已知缺陷，评估是否影响 v0.1 Pilot。

## 2. Architecture / Tech Stack

- 无代码变更（纯验证 Phase）
- 工具：`scripts/measure-performance.sh`（P0 已存在）+ 手动操作 + XCUITest（CI）
- 输出：兼容性测试报告 + 性能基线报告 + NFR 门槛设定文档

## 3. 文件与职责

| 文件 | 职责变更 |
|------|---------|
| `docs/phases/F1_窗口编排核心/F1_04_性能基线报告.md` | 新建：记录 P95 latency 基线数据 + NFR 门槛设定 |
| `docs/phases/F1_窗口编排核心/F1_05_兼容性回归报告.md` | 新建：Tier A App × N 矩阵测试结果 |
| `Sources/TidyAppUITests/TidyAppUITests.swift` | 新增 TC-F1-001-01 / TC-F1-008-01 XCUITest 用例（CI 执行） |
| `scripts/measure-performance.sh` | 确认脚本可用（P0 已存在，可能需调整参数） |

## 4. IN / OUT / Dependencies

- **IN**：Phase 1-5 所有代码变更完成 + 单元测试全绿
- **OUT**：兼容性回归报告 + 性能基线报告 + NFR 门槛设定 + 兼容性修复提交（若有）
- **Dependencies**：Phase 1, 2, 3, 4, 5

## 5. 任务（2-5 分钟粒度）

### Task 6.1: 准备测试环境

- 确认 5 个 Tier A App 已安装：Xcode / VS Code / Finder（系统自带）/ Safari（系统自带）/ Chrome
- 确认辅助功能权限已授予 Tidy
- 确认 `scripts/measure-performance.sh` 可运行
- 准备窗口管理脚本：每个 App 能打开指定数量的窗口（手动或脚本）

### Task 6.2: Xcode 兼容性测试

- N=2：打开 2 个 Xcode 窗口，执行 TC-F1-001-01 核心闭环，截图 + os_log
- N=5：同上
- N=9：同上
- 额外：TC-F1-002-06 布局验证 / TC-F1-003-03 边界（10+ 窗口）/ TC-F1-004-05 生命周期 / TC-F1-005-05 working 生命周期 / TC-F1-006-05 异常恢复 / TC-F1-007-05 App 退出
- 记录到 F1_05_兼容性回归报告.md

### Task 6.3: VS Code 兼容性测试

- 重复 Task 6.2 流程
- 关注：Electron App AX 行为可能不稳定，记录 AX 失败率
- 若失败率 >5%，记录并评估是否需要回退 AX 失败策略（FR-F1-006 风险提示）

### Task 6.4: Finder 兼容性测试

- 重复 Task 6.2 流程
- 关注：Finder AX 行为可能不稳定，记录 AX 失败率

### Task 6.5: Safari 兼容性测试

- 重复 Task 6.2 流程

### Task 6.6: Chrome 兼容性测试

- 重复 Task 6.2 流程
- 关注：Chrome 多进程架构可能影响窗口枚举

### Task 6.7: 性能基线测量 + AX 失败率统计

- 对每个 Tier A App × N（2/5/9）执行 100 次触发热键
- 收集 os_log 性能埋点：`tidy.performance app=<bundle_id> windows=<count> t0=<ms> t1=<ms> t2=<ms> latency=<ms> success=<0|1>`
- 使用 `scripts/measure-performance.sh` 或手动收集
- 计算 P95 latency / t0 / t1 / t2
- **AX 失败率统计**：统计 `success=0` 的比例（失败次数 / 总次数 × 100%）
  - 按 App × N 分组统计
  - 若某 App × N 组合失败率 >5%，记录到 F1_05_兼容性回归报告.md 并触发风险 7.1 评估
  - 失败率 >5% 时按 F1_01 FR-F1-006 风险提示重新评估 AX 失败策略
- 记录到 F1_04_性能基线报告.md

### Task 6.8: 设定 NFR 5.1 性能门槛

- 基于 Task 6.7 基线数据，参考 P0 探针基线
- 设定门槛：
  - 排列完成时间 P95（2/5/9 窗口场景）
  - 还原时间 P95（working → idle）
  - 还原成功率
- 注意：还原时间 P95 在 Phase 4 后语义变化（保留排列不还原，"还原"指 working→selecting 取消放大）
- 写入 F1_04_性能基线报告.md 并更新 F1_01 NFR 5.1（移除"展缓"标注）

### Task 6.9: XCUITest 用例编写

- 文件：`Sources/TidyAppUITests/TidyAppUITests.swift`
- 实现 TC-F1-001-01（核心闭环 UI 测试）与 TC-F1-008-01（Tier A 兼容性矩阵）
- 注意：本地禁止执行 XCUITest，仅 CI 执行
- 运行：`swift build`（编译检查，不执行）

### Task 6.10: 兼容性问题修复（条件性）

- 若 Task 6.2-6.6 发现兼容性问题，记录到 F1_05_兼容性回归报告.md
- 评估问题等级（Blocker / Critical / Major / Minor）
- 修复 Blocker / Critical 问题（创建独立提交）
- Major / Minor 问题记录为已知缺陷，评估是否进入 v0.1 Pilot

### Task 6.11: 输出兼容性回归报告

- 文件：`docs/phases/F1_窗口编排核心/F1_05_兼容性回归报告.md`
- 内容：
  - Tier A App × N 矩阵测试结果表
  - 每个组合的通过/失败状态
  - 失败组合的根因分析与修复方案
  - AX 失败率统计
  - 已知缺陷清单

## 6. 验证命令

```bash
# 单元测试（确认无回归）
swift test

# 编译检查
swift build

# Lint
swiftlint lint --strict

# XCUITest（仅 CI，本地禁止）
# CI 中执行：xcodebuild test -scheme Tidy -destination 'platform=macOS'
```

## 7. UI 证据（手动）

- 每个 Tier A App × N 组合的核心闭环录屏
- 布局截图（2/3/4/5/6/7/8/9 窗口）
- 错误提示截图（AX 失败 / 激活失败 / 10+ 截断）
- 性能基线数据导出（os_log 截图或日志文件）

## 8. 提交边界与回滚

- 提交 1：Task 6.9（XCUITest 用例）→ `test(tidyapp): 新增 F1 核心闭环与 Tier A 兼容性 UI 测试`
- 提交 2：Task 6.7-6.8, 6.11（性能基线报告 + 兼容性回归报告 + NFR 门槛）→ `docs(phase-F1): 性能基线与 Tier A 兼容性回归报告`
- 提交 3-N（条件性）：Task 6.10 兼容性修复 → `fix(tidycore): <具体问题>`

回滚：每个提交独立可回滚。

## 9. AC → Task → Test 映射

| AC | Task | Test |
|----|------|------|
| AC-F1-008 Tier A 兼容性 | 6.2-6.6, 6.9, 6.11 | TC-F1-008-01/02/03 |
| NFR 5.1 性能门槛 | 6.7-6.8 | TC-F1-008-03 |

## 10. Local Gate

- [ ] 所有 Task 6.1-6.11 完成
- [ ] 5 个 Tier A App × 3 N 矩阵测试全部通过（或失败已记录 + 修复）
- [ ] 性能基线报告已输出（P95 latency 数据）
- [ ] NFR 5.1 门槛已设定并更新 F1_01
- [ ] XCUITest 用例编译通过（本地不执行）
- [ ] 兼容性回归报告已输出
- [ ] `swift test` 全绿（无回归）
- [ ] `swiftlint lint --strict` 0 violations
- [ ] 2+ 个提交已按顺序创建
