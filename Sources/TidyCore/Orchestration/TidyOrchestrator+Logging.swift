import Foundation
import os.log

// MARK: - 日志辅助方法

extension TidyOrchestrator {
    /// 记录 activateWindow 结果（F1 诊断日志）
    func logActivateResult(
        label: Character,
        window: WindowInfo,
        result: WindowOperationResult
    ) {
        switch result {
        case .success:
            os_log(
                "tidy.activate ok wid=%llu label=%{public}@",
                log: perfLog, type: .default,
                window.id, String(label)
            )
        case .failed(_, let reason):
            os_log(
                "tidy.activate FAIL wid=%llu reason=%{public}@",
                log: perfLog, type: .default,
                window.id, reason
            )
        }
    }

    /// 记录 selectWindow 结果（临时诊断日志，P0 探针阶段）
    func logSelectResult(
        label: Character,
        window: WindowInfo,
        result: WindowOperationResult
    ) {
        switch result {
        case .success:
            os_log(
                "tidy.debug select ok label=%{public}@ wid=%llu",
                log: perfLog,
                type: .default,
                String(label),
                window.id
            )
        case .failed(_, let reason):
            os_log(
                "tidy.debug select FAIL label=%{public}@ wid=%llu reason=%{public}@",
                log: perfLog,
                type: .default,
                String(label),
                window.id,
                reason
            )
        }
    }
}
