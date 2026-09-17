#!/bin/bash
# Fold5 읽기 전용 진단(D1~D5) — 기기 상태를 바꾸는 명령은 넣지 않는다
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"; mkdir -p "$LOG_DIR"
DAY=$(date +%F); SUMMARY="$LOG_DIR/${DAY}_fold5_diag.log"

run() {  # run 단계 명령...
  local step=$1; shift
  local out="$LOG_DIR/${DAY}_fold5_diag_${step}.log"
  if adb shell "$@" > "$out" 2>&1; then r=성공; else r=실패; fi
  echo "$(date '+%F %T') | $step | $* | $r | $(wc -l < "$out" | tr -d ' ')줄" | tee -a "$SUMMARY"
}

run D1 'getprop ro.product.model; getprop ro.build.version.release; getprop ro.build.PDA; getprop ro.build.version.oneui'
run D2 dumpsys sensorservice
run D3 cmd device_state print-states
run D4 dumpsys display
run D5 dumpsys wallpaper
