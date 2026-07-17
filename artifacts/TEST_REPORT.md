# 随练 AI MVP 完整自测报告

测试日期：2026-07-13  
覆盖范围：Flutter Android 客户端、Go API、SQLite 元数据、端到端接口契约、关键页面视觉回归。

## 结论

本轮 MVP 自测全部通过。Android Release APK 已基于当前源码重新生成；Flutter 静态检查无问题；16 项单元、组件与视觉回归测试全部通过；Go API 测试、构建与客户端契约联调通过。此外，Pixel 7 / Android 15 真实模拟器黑盒链路的 23 个检查点全部通过。

## 自动化测试结果

| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| Go API 单元与接口测试 | 通过 | `go test ./...` |
| Go API Release 构建 | 通过 | `services/api/bin/api` |
| Flutter 静态检查 | 通过 | `No issues found` |
| Flutter 单元、组件、Golden 测试 | 通过 | 16 tests passed |
| API 安装、鉴权、计划、调整、总结联调 | 通过 | `scripts/self_test.sh` |
| Android 真实 UI 主链路 | 通过 | 23 个黑盒检查点，见 `artifacts/android-ui-audit/latest/REPORT.md` |
| Android Release APK | 通过 | `mobile/build/app/outputs/flutter-apk/app-release.apk` |

一键复测：

```bash
./scripts/self_test.sh
./scripts/android_ui_audit.sh
```

## Android 安装包

- 文件：[`app-release.apk`](../mobile/build/app/outputs/flutter-apk/app-release.apk)
- 大小：55.1 MB（约 52.6 MiB）
- SHA-256：`387747d192cb1a40056978dc1e1f775c68799c7e20abedc147df62bd2fd26f58`
- 接口地址：构建时配置为 Android 模拟器访问宿主机的 `http://10.0.2.2:8080`

## 完整页面截图

### Onboarding

1. [欢迎页](../mobile/test/goldens/01_welcome.png)
2. [性别](../mobile/test/goldens/02_gender.png)
3. [生日](../mobile/test/goldens/03_birthday.png)
4. [身高](../mobile/test/goldens/04_height.png)
5. [体重](../mobile/test/goldens/05_weight.png)
6. [训练经验](../mobile/test/goldens/06_experience.png)
7. [身体限制](../mobile/test/goldens/07_limitations.png)
8. [可选语音介绍](../mobile/test/goldens/08_optional_voice.png)
9. [已完成语音介绍](../mobile/test/goldens/09_voice_recorded.png)

### 核心训练闭环

10. [首页](../mobile/test/goldens/10_home.png)
11. [今日计划](../mobile/test/goldens/11_plan.png)
12. [训练执行](../mobile/test/goldens/12_workout.png)
13. [训练总结](../mobile/test/goldens/13_summary.png)

### 动作库

14. [胸部动作库](../mobile/test/goldens/14_exercise_library.png)
15. [动作双阶段演示与步骤](../mobile/test/goldens/15_exercise_detail.png)
16. [哑铃筛选结果](../mobile/test/goldens/16_exercise_library_dumbbell.png)

### 服务端

17. [API 运行状态](test-screenshots/14_api_status.jpg)

## 已验证的产品链路

1. 首次打开进入分步 OB，依次完成生日等基础资料，语音介绍可跳过。
2. 首页支持语音意图、键盘输入与沿用上次训练意图。
3. 客户端自动完成安装鉴权，服务端生成计划；离线时使用本地降级计划。
4. 首页可直接进入动作库；胸部动作可按器械、哑铃、杠铃和自重筛选，并查看双阶段演示、中文步骤与关键提示。
5. 计划确认页和训练中均可从动作库选择动作并真实替换，组数保持、重量和次数采用新动作建议值。
6. 计划可缩短并进入训练；训练中可记录重量、次数、休息时间及跳转其他动作。
7. 完成训练后生成总结、卡路里和肌群覆盖，并保存今日记录。
8. 再次进入首页时优先展示今日训练记录，不重复要求输入。

## 真实 Android UI 审计

- [最新审计报告](android-ui-audit/latest/REPORT.md)
- 覆盖首次启动、完整 Onboarding、首页、动作库、哑铃筛选、动作详情、服务端计划、训练、休息、零组结束保护、真实总结、回到首页和重启持久化。
- 已修复：首页日期写死、离线计划只有 3 个动作、0 组也会被存成完成记录、肌群覆盖始终使用固定 4 肌群数据。
- Demo、API、客户端与契约样例已统一为 68 分钟 / 11 力量组 / 15 分钟有氧 / 5 个动作；力量组由 3+3+3+2 的动作明细计算，并由真实 UI 断言防止再次漂移。
- 动作库首批使用 `free-exercise-db` 的 12 个 Public Domain / Unlicense 胸部动作和 24 张图片；导入脚本会校验上游条目和本地素材完整性。

## 平台边界

- MVP 第一交付目标为 Android/OPPO，Release APK 已实际构建。
- Flutter 工程同时包含 iOS 工程文件；当前机器未安装完整 Xcode 与 CocoaPods，因此本轮没有产出 iOS 安装包。
- 服务端仅持久化安装鉴权与必要元数据；完整训练记录优先保存在客户端，符合当前产品文档的 local-first 约束。
