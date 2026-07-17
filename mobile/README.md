# 随练 AI Mobile

随练 AI 的 Flutter 客户端，目标平台为 iOS 和 Android。当前已完成首次使用、计划生成、动作库、训练执行和事实总结闭环。

## 当前功能

- 7 步渐进式基础设置：性别、生日、身高、体重、经验、身体限制、可选语音介绍；
- 可返回修改，进度始终可见；
- 语音介绍支持跳过、模拟识别、重录和确认；
- 完成后进入「今天怎么练」首页；
- 胸部动作库首批包含 12 个高频动作，可按器械、哑铃、杠铃和自重筛选；
- 每个动作包含双阶段演示、中文步骤、关键提示、难度和训练参数；
- 计划确认页和训练中均可从动作库真实替换动作。

动作元数据与 24 张演示图片来自 Public Domain / Unlicense 的 `free-exercise-db`，完整来源记录见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。重新核验或导入素材：

```bash
../scripts/import_exercise_library.py --check
```

## 本地命令

```bash
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw run
```

## Android 真实 UI 审计

从项目根目录运行：

```bash
./scripts/android_ui_audit.sh
```

脚本会启动或复用 `Suilian_Pixel_7` 模拟器，构建并安装当前 APK，真实点击 Onboarding、首页、动作库筛选、动作详情、计划、训练、休息和总结链路。每次运行的 APK 哈希、断言、设备截图、全程录屏 `ui-test.mp4` 和报告会写入 `artifacts/android-ui-audit/<run-id>/`，最新一次可通过 `artifacts/android-ui-audit/latest/REPORT.md` 查看。

项目修改后的统一准出标准是：`./scripts/android_ui_audit.sh` 全部通过，并交付该次运行目录中的 `REPORT.md` 与 `ui-test.mp4`。录屏会显示点击位置，便于直接复核自动化操作。

Flutter SDK 固定使用 `~/development/flutter`，脚本已配置当前网络可用的软件包镜像。

## 目录

```text
lib/
  features/        按产品功能拆分的页面与交互
  models/          本地领域模型
  theme/           品牌颜色、字体和组件主题
```

## 本机尚需安装

- Android Studio / Android SDK：Android 编译与模拟器；
- 完整 Xcode：iOS 编译与模拟器；
- CocoaPods：iOS 原生插件依赖。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
