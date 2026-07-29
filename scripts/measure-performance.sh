#!/bin/bash
# P0_技术探针 性能测量脚本
#
# 用法: ./scripts/measure-performance.sh <app_name> <window_count> [iterations]
# 示例: ./scripts/measure-performance.sh Finder 5 20
#
# 前置条件:
# 1. Tidy.app 已构建并运行
# 2. 目标 App 已打开且在前台，窗口数正确
# 3. AX 权限和 Input Monitoring 权限已授予
# 4. Tidy 热键为 ⌘⌥T
#
# 测量流程:
# 1. warm-up 3 次（不计入统计）
# 2. 正式测量 N 次（默认 20）
# 3. 每次循环: ⌘⌥T(触发编排) → 等 1s → a(选择窗口) → 等 1s → ⌘⌥T(还原) → 等 1s
# 4. 从 log stream 收集 tidy.performance 日志
# 5. 计算统计量并输出

set -euo pipefail

APP_NAME="${1:?用法: $0 <app_name> <window_count> [iterations]}"
WINDOW_COUNT="${2:?用法: $0 <app_name> <window_count> [iterations]}"
ITERATIONS="${3:-20}"
WARMUP=3
TOTAL=$((WARMUP + ITERATIONS))

# 间隔时间（秒）
TRIGGER_DELAY=1.0
SELECT_DELAY=1.2
RESTORE_DELAY=1.5

# 日志输出
LOG_DIR="$(cd "$(dirname "$0")/.." && pwd)/docs/phases/P0_技术探针/artifacts"
RAW_LOG="/tmp/tidy_perf_${APP_NAME}_${WINDOW_COUNT}.log"
RESULT_FILE="${LOG_DIR}/perf-${APP_NAME}-${WINDOW_COUNT}.csv"

echo "=== P0 性能测量 ==="
echo "App: ${APP_NAME} | 窗口数: ${WINDOW_COUNT} | 正式样本: ${ITERATIONS} | Warm-up: ${WARMUP}"
echo ""

# 检查 Tidy 是否在运行
if ! pgrep -x "Tidy" > /dev/null 2>&1; then
    echo "❌ Tidy.app 未运行，请先启动"
    exit 1
fi

# 清理旧日志
rm -f "${RAW_LOG}"

# 启动 log stream 后台捕获
echo "📊 启动日志捕获..."
log stream --process Tidy --predicate 'subsystem == "com.tidy.windowmanagement"' --style compact > "${RAW_LOG}" 2>&1 &
LOG_PID=$!

# 等待日志流稳定
sleep 1

# 模拟按键的函数
send_hotkey() {
    # ⌘⌥T (keyCode=17, modifiers=cmd+option)
    osascript -e 'tell application "System Events" to key code 17 using {command down, option down}'
}

send_select_key() {
    # 按 'a' 键 (keyCode=0)
    osascript -e 'tell application "System Events" to key code 0'
}

# 执行单次测量循环
run_once() {
    local run_num=$1
    local phase=$2

    # 触发编排
    send_hotkey
    sleep ${TRIGGER_DELAY}

    # 选择窗口 'a'
    send_select_key
    sleep ${SELECT_DELAY}

    # 还原
    send_hotkey
    sleep ${RESTORE_DELAY}
}

# Warm-up
echo "🔥 Warm-up (${WARMUP} 次)..."
for i in $(seq 1 ${WARMUP}); do
    run_once $i "warmup"
    echo -n "."
done
echo ""

# Warm-up 后：清空日志，仅保留正式测量数据
kill ${LOG_PID} 2>/dev/null || true
wait ${LOG_PID} 2>/dev/null || true
rm -f "${RAW_LOG}"
sleep 0.5

# 重新启动日志捕获
log stream --process Tidy --predicate 'subsystem == "com.tidy.windowmanagement"' --style compact > "${RAW_LOG}" 2>&1 &
LOG_PID=$!
sleep 1

# 正式测量
echo "📈 正式测量 (${ITERATIONS} 次)..."
for i in $(seq 1 ${ITERATIONS}); do
    run_once $i "formal"
    echo -n "."
done
echo ""

# 停止日志捕获
sleep 2
kill ${LOG_PID} 2>/dev/null || true
wait ${LOG_PID} 2>/dev/null || true

# 解析性能日志
echo ""
echo "📋 解析性能日志..."

# 提取 tidy.performance 行中的 latency 值
# 格式: tidy.performance app=<bundle_id> windows=<count> t0=<ms> t1=<ms> t2=<ms> latency=<ms> success=<0|1>
LATENCIES=()
while IFS= read -r line; do
    # 提取 latency 值
    latency=$(echo "${line}" | grep -o 'latency=[0-9]*' | cut -d= -f2)
    if [[ -n "${latency}" && "${latency}" != "0" ]]; then
        LATENCIES+=("${latency}")
    fi
done < <(grep 'tidy.performance' "${RAW_LOG}" 2>/dev/null || true)

# 也提取 select 结果
SELECT_OK=$(grep -c 'tidy.debug select ok' "${RAW_LOG}" 2>/dev/null || echo 0)
SELECT_FAIL=$(grep -c 'tidy.debug select FAIL' "${RAW_LOG}" 2>/dev/null || echo 0)

# 输出原始数据到 CSV
echo "timestamp,app,window_count,latency_ms" > "${RESULT_FILE}"
for lat in "${LATENCIES[@]}"; do
    echo "$(date +%s),${APP_NAME},${WINDOW_COUNT},${lat}" >> "${RESULT_FILE}"
done

# 统计计算
N=${#LATENCIES[@]}
if [[ ${N} -eq 0 ]]; then
    echo "❌ 未收集到有效 latency 数据"
    echo "请检查 os_log 是否正常输出（可能需要调整日志级别）"
    echo "原始日志: ${RAW_LOG}"
    exit 1
fi

# 排序
IFS=$'\n' SORTED=($(sort -n <<<"${LATENCIES[*]}")); unset IFS

# Min, Max, Mean
MIN=${SORTED[0]}
MAX=${SORTED[$((N-1))]}

SUM=0
for v in "${SORTED[@]}"; do
    SUM=$((SUM + v))
done
MEAN=$((SUM / N))

# P50
P50_IDX=$((N * 50 / 100))
P50=${SORTED[$P50_IDX]:-${SORTED[0]}}

# P95
P95_IDX=$(( (N * 95 + 99) / 100 ))  # ceil
[[ ${P95_IDX} -ge ${N} ]] && P95_IDX=$((N-1))
P95=${SORTED[$P95_IDX]:-${SORTED[0]}}

# 判定
if [[ ${P95} -le 800 ]]; then
    VERDICT="PASS ✅"
else
    VERDICT="FAIL ❌ (P95=${P95}ms > 800ms)"
fi

echo ""
echo "=============================="
echo "  ${APP_NAME} × ${WINDOW_COUNT} 窗口"
echo "=============================="
echo "  样本数: ${N}"
echo "  Min:    ${MIN} ms"
echo "  Max:    ${MAX} ms"
echo "  Mean:   ${MEAN} ms"
echo "  P50:    ${P50} ms"
echo "  P95:    ${P95} ms"
echo "  门槛:   ≤ 800ms"
echo "  判定:   ${VERDICT}"
echo ""
echo "  select ok:  ${SELECT_OK}"
echo "  select FAIL: ${SELECT_FAIL}"
echo ""
echo "  CSV: ${RESULT_FILE}"
echo "  Raw log: ${RAW_LOG}"
echo "=============================="
