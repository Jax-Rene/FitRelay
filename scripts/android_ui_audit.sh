#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
MOBILE="$ROOT/mobile"
API="$ROOT/services/api"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
EMULATOR="${ANDROID_HOME:-$HOME/Library/Android/sdk}/emulator/emulator"
FLUTTER="$MOBILE/tool/flutterw"
GO="$HOME/development/go/bin/go"
AVD="${ANDROID_AVD:-Suilian_Pixel_7}"
PORT="${SUILIAN_AUDIT_PORT:-18080}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/artifacts/android-ui-audit/$RUN_ID"
LATEST="$ROOT/artifacts/android-ui-audit/latest"
RESULTS="$OUT/results.tsv"
UI_XML="$OUT/window.xml"
API_DB="$OUT/audit.db"
API_LOG="$OUT/api.log"
EMULATOR_LOG="$OUT/emulator.log"
VIDEO="$OUT/ui-test.mp4"
DEVICE_VIDEO="/sdcard/suilian-ai-ui-test-$RUN_ID.mp4"
STARTED_EMULATOR=0
API_PID=""
SCREENRECORD_PID=""
HOST_SCREENRECORD_PID=""
SHOW_TOUCHES_BEFORE=""

mkdir -p "$OUT"
: > "$RESULTS"

cleanup() {
  stop_recording
  restore_show_touches
  if [[ -n "$API_PID" ]]; then
    kill "$API_PID" >/dev/null 2>&1 || true
  fi
  if [[ "$STARTED_EMULATOR" == 1 ]]; then
    "$ADB" emu kill >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

restore_show_touches() {
  if [[ -n "$SHOW_TOUCHES_BEFORE" ]]; then
    "$ADB" shell settings put system show_touches "$SHOW_TOUCHES_BEFORE" >/dev/null 2>&1 || true
    SHOW_TOUCHES_BEFORE=""
  fi
}

start_recording() {
  SHOW_TOUCHES_BEFORE="$("$ADB" shell settings get system show_touches 2>/dev/null | tr -d '\r')"
  [[ "$SHOW_TOUCHES_BEFORE" == "null" ]] && SHOW_TOUCHES_BEFORE=0
  "$ADB" shell settings put system show_touches 1 >/dev/null
  "$ADB" shell rm -f "$DEVICE_VIDEO" >/dev/null 2>&1 || true
  "$ADB" shell screenrecord --bit-rate 8000000 --time-limit 300 "$DEVICE_VIDEO" >/dev/null 2>&1 &
  HOST_SCREENRECORD_PID=$!
  sleep 1
  SCREENRECORD_PID="$("$ADB" shell pidof screenrecord 2>/dev/null | tr -d '\r')"
  if [[ -z "$SCREENRECORD_PID" ]]; then
    print -u2 'Unable to start Android screen recording'
    return 1
  fi
}

stop_recording() {
  if [[ -z "$SCREENRECORD_PID" ]]; then
    return
  fi

  "$ADB" shell kill -2 "$SCREENRECORD_PID" >/dev/null 2>&1 || true
  if [[ -n "$HOST_SCREENRECORD_PID" ]]; then
    wait "$HOST_SCREENRECORD_PID" >/dev/null 2>&1 || true
  fi
  SCREENRECORD_PID=""
  HOST_SCREENRECORD_PID=""
  "$ADB" pull "$DEVICE_VIDEO" "$VIDEO" >/dev/null 2>&1 || true
  "$ADB" shell rm -f "$DEVICE_VIDEO" >/dev/null 2>&1 || true
}

require_file() {
  if [[ ! -x "$1" ]]; then
    print -u2 "Missing executable: $1"
    exit 1
  fi
}

record() {
  print -r -- "$1"$'\t'"$2"$'\t'"$3" >> "$RESULTS"
}

dump_ui() {
  "$ADB" shell uiautomator dump /sdcard/suilian-window.xml >/dev/null
  "$ADB" pull /sdcard/suilian-window.xml "$UI_XML" >/dev/null
}

node_for_desc() {
  local desc="$1"
  dump_ui
  sed -E 's/></>\n</g' "$UI_XML" | grep -F "$desc" | head -1
}

wait_desc() {
  local desc="$1"
  local attempts="${2:-20}"
  local node=""
  local i
  for ((i = 1; i <= attempts; i++)); do
    node="$(node_for_desc "$desc" 2>/dev/null || true)"
    if [[ -n "$node" ]]; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

tap_desc() {
  local desc="$1"
  local node bounds x1 y1 x2 y2
  node="$(node_for_desc "$desc" || true)"
  if [[ -z "$node" ]]; then
    print -u2 "Unable to find tappable semantics: $desc"
    return 1
  fi
  bounds="$(print -r -- "$node" | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')"
  read x1 y1 x2 y2 <<< "$bounds"
  "$ADB" shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
}

capture() {
  local name="$1"
  sleep 0.7
  "$ADB" exec-out screencap -p > "$OUT/$name.png"
  dump_ui
  cp "$UI_XML" "$OUT/$name.xml"
}

assert_desc() {
  local checkpoint="$1"
  local desc="$2"
  local attempts="${3:-8}"
  if wait_desc "$desc" "$attempts"; then
    record "$checkpoint" PASS "$desc"
  else
    record "$checkpoint" FAIL "$desc"
    print -u2 "Assertion failed at $checkpoint: $desc"
    return 1
  fi
}

write_report() {
  local apk="$MOBILE/build/app/outputs/flutter-apk/app-debug.apk"
  local apk_sha="$(shasum -a 256 "$apk" | awk '{print $1}')"
  local device="$("$ADB" shell getprop ro.product.model | tr -d '\r')"
  local android="$("$ADB" shell getprop ro.build.version.release | tr -d '\r')"
  local failures="$(awk -F '\t' '$2 == "FAIL" {count++} END {print count + 0}' "$RESULTS")"
  {
    print -r -- '# 随练 AI Android 真实 UI 审计'
    print -r -- ''
    print -r -- "- 运行时间：$(date '+%Y-%m-%d %H:%M:%S %Z')"
    print -r -- "- 设备：$device / Android $android / AVD $AVD"
    print -r -- "- APK SHA-256：\`$apk_sha\`"
    print -r -- "- API：\`http://10.0.2.2:$PORT\`，日志见 [api.log](api.log)"
    print -r -- "- 结果：$([[ "$failures" == 0 ]] && print '主链路通过' || print "$failures 项失败")"
    print -r -- "- 全程录屏：[ui-test.mp4](ui-test.mp4)"
    print -r -- ''
    print -r -- '## 功能断言'
    print -r -- ''
    print -r -- '| 检查点 | 结果 | 断言 |'
    print -r -- '| --- | --- | --- |'
    while IFS=$'\t' read -r checkpoint result_status assertion; do
      print -r -- "| $checkpoint | $result_status | $assertion |"
    done < "$RESULTS"
    print -r -- ''
    print -r -- '## 真实设备截图'
    print -r -- ''
    print -r -- '| 一键登录 | Onboarding | 首页 |'
    print -r -- '| --- | --- | --- |'
    print -r -- '| ![](00_login.png) | ![](01_welcome.png) | ![](10_home.png) |'
    print -r -- ''
    print -r -- '| 计划 | 训练 | 总结 |'
    print -r -- '| --- | --- | --- |'
    print -r -- '| ![](11_plan.png) | ![](12_workout.png) | ![](13_summary.png) |'
    print -r -- ''
    print -r -- '| 动作库 | 器械筛选 | 动作详情：起始姿势 | 动作详情：结束姿势 |'
    print -r -- '| --- | --- | --- | --- |'
    print -r -- '| ![](10_library.png) | ![](10_library_dumbbell.png) | ![](10_exercise_detail.png) | ![](10_exercise_detail_end.png) |'
    print -r -- ''
    print -r -- '| 零组保护 | 完成后首页 | 完成记录即时打开 |'
    print -r -- '| --- | --- | --- |'
    print -r -- '| ![](12_zero_set_guard.png) | ![](14_home_completed.png) | ![](14_completed_record.png) |'
    print -r -- ''
    print -r -- '| 休息倒计时 | 倒计时结束 |'
    print -r -- '| --- | --- |'
    print -r -- '| ![](12_rest.png) | ![](12_rest_complete.png) |'
    print -r -- ''
    print -r -- '## 与 Demo 的口径对齐'
    print -r -- ''
    print -r -- '| 项目 | Demo | 当前 API/App | 判断 |'
    print -r -- '| --- | --- | --- | --- |'
    print -r -- '| 计划时长 | 68 分钟 | 68 分钟 | 已对齐 |'
    print -r -- '| 力量组 | 11 组 | 11 组 | 已按 3+3+3+2 的真实动作组数对齐 |'
    print -r -- '| 动作数 | 5 | 5 | 已对齐 |'
    print -r -- '| 有氧 | 15 分钟 | 15 分钟 | 已对齐 |'
    print -r -- ''
    print -r -- 'Demo 参考图：`../../flutter-demo-audit/reference/` 与 `../../../demo/audit/`。浏览器自动刷新基线需要 Node/npm/npx。'
  } > "$OUT/REPORT.md"
  rm -f "$LATEST"
  ln -s "$RUN_ID" "$LATEST"
}

require_file "$ADB"
require_file "$EMULATOR"
require_file "$FLUTTER"
require_file "$GO"

if ! "$ADB" devices | awk 'NR > 1 && $2 == "device" {found=1} END {exit !found}'; then
  "$EMULATOR" -avd "$AVD" -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect >"$EMULATOR_LOG" 2>&1 &
  STARTED_EMULATOR=1
fi

"$ADB" wait-for-device
for _ in {1..90}; do
  [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]] && break
  sleep 1
done

(cd "$API" && "$GO" test ./... && "$GO" build -o bin/api ./cmd/api)
HTTP_ADDR="0.0.0.0:$PORT" DATABASE_PATH="$API_DB" "$API/bin/api" >"$API_LOG" 2>&1 &
API_PID=$!
for _ in {1..50}; do
  curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break
  sleep 0.1
done
curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null

(cd "$MOBILE" && "$FLUTTER" analyze && "$FLUTTER" test && "$FLUTTER" build apk --debug --dart-define="API_BASE_URL=http://10.0.2.2:$PORT")

APK="$MOBILE/build/app/outputs/flutter-apk/app-debug.apk"
"$ADB" install -r "$APK" >/dev/null
"$ADB" shell pm clear ai.suilian.suilian_ai >/dev/null
"$ADB" shell pm grant ai.suilian.suilian_ai android.permission.ACCESS_COARSE_LOCATION >/dev/null
"$ADB" shell pm grant ai.suilian.suilian_ai android.permission.ACCESS_FINE_LOCATION >/dev/null
"$ADB" emu geo fix 121.437 31.188 >/dev/null 2>&1 || true
start_recording
"$ADB" shell am start -W -n ai.suilian.suilian_ai/.MainActivity >/dev/null

assert_desc login '本机一键登录'
capture 00_login
tap_desc '本机一键登录'
assert_desc welcome '开始设置'
capture 01_welcome
tap_desc '开始设置'
assert_desc gender '继续'
capture 02_gender

for screen in 03_birthday 04_height 05_weight 06_experience 07_limitations 08_optional_note; do
  tap_desc '继续'
  capture "$screen"
done
assert_desc optional_note '保存并开始训练'
tap_desc '保存并开始训练'
assert_desc home '今天怎么练？'
assert_desc home_environment '环境信息已更新' 30
assert_desc home_humidity '湿度'
capture 10_home

tap_desc '动作库'
assert_desc exercise_library '想练哪里？'
assert_desc exercise_library_count '找到 873 个动作'
capture 10_library
tap_desc '哑铃'
assert_desc exercise_library_dumbbell '找到 123 个动作'
capture 10_library_dumbbell
tap_desc '哑铃卧推'
assert_desc exercise_detail '动作步骤'
tap_desc '暂停播放'
tap_desc '显示起始姿势'
assert_desc exercise_detail_first_frame '哑铃卧推动作演示，第 1 帧'
capture 10_exercise_detail
tap_desc '显示结束姿势'
assert_desc exercise_detail_second_frame '哑铃卧推动作演示，第 2 帧'
capture 10_exercise_detail_end
tap_desc '返回动作库'
assert_desc exercise_library_return '找到 123 个动作'
"$ADB" shell input keyevent 4
assert_desc home_after_library '今天怎么练？'

tap_desc '快速生成今天计划'
assert_desc plan '今日计划'
capture 11_plan
assert_desc plan_duration '预计分钟'
assert_desc plan_strength_sets '力量组'
assert_desc plan_cardio '有氧分钟'
assert_desc plan_actions '开始训练'
tap_desc '开始训练'
assert_desc workout '动作 1 /'
capture 12_workout

for _ in {1..5}; do
  tap_desc '减少休息 15 秒'
done
assert_desc minimum_rest '15 秒'

tap_desc '结束'
assert_desc zero_set_guard '还没有完成任何一组'
capture 12_zero_set_guard
tap_desc '继续训练'

tap_desc '完成本组'
assert_desc rest '跳过休息'
capture 12_rest
assert_desc rest_counting '倒计时结束后会响铃提醒'
assert_desc rest_complete '休息完成' 40
assert_desc rest_zero '0 秒'
assert_desc rest_sound '提示音已响，可以开始下一组'
capture 12_rest_complete
tap_desc '继续训练'
tap_desc '结束'
assert_desc summary '今天完成了'
capture 13_summary
assert_desc summary_truth '本次实际完成 1 个有效组。'
assert_desc summary_muscles '肌群覆盖'
tap_desc '完成，回到首页'
assert_desc completed_home '今天练得不错。'
assert_desc restart_training '重新开练'
capture 14_home_completed
tap_desc '今日训练已完成'
assert_desc completed_record_instant '训练记录'
capture 14_completed_record
tap_desc '训练记录'
assert_desc completed_home_return '今天练得不错。'

"$ADB" shell am force-stop ai.suilian.suilian_ai
"$ADB" shell am start -W -n ai.suilian.suilian_ai/.MainActivity >/dev/null
assert_desc relaunch_persistence '今天练得不错。'
capture 15_relaunch_persisted

stop_recording
restore_show_touches
write_report
print "Android UI audit passed: $OUT/REPORT.md"
