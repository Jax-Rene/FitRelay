# FitRelay

FitRelay（中文名：随练 AI）是一款面向非规律训练者的自适应健身助手。
它不会要求用户追赶固定周计划，而是在用户真正准备训练时，根据训练历史、
当天时间、身体状态和现场变化，生成一份可以立即执行的单日计划。

> Pick up where you are.

## Repository layout

- `mobile/`：Flutter 客户端，Android-first
- `services/api/`：Go API 服务
- `contracts/`：OpenAPI 协议与示例
- `schema/`：客户端和服务端 SQLite schema
- `demo/`：交互式产品 Demo
- `deploy/`：本地部署配置
- `scripts/`：测试、审计和数据导入脚本
- `PRODUCT_SPEC.md`：唯一人工维护的产品与实施文档

## CI/CD

推送到 `main` 后，GitHub Actions 会：

1. 运行 Go API 测试；
2. 运行 Flutter 静态检查和测试；
3. 构建可直接安装的 Android debug APK，并保留为 14 天的 Actions Artifact；
4. 在全部检查通过后，通过 SSH 将 API 发布到腾讯云轻量应用服务器。

首次启用前需配置 GitHub `production` Environment 和以下 Secrets：

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_SSH_KEY`
- `DEPLOY_KNOWN_HOSTS`

可选仓库变量 `FITRELAY_API_BASE_URL` 用于覆盖 APK 内的 API 地址。

首次服务器引导脚本位于 `deploy/provision-server.sh`。它会安装 Docker、创建
`fitrelay` 部署用户和持久化目录，并在写入 FitRelay 反向代理之前备份现有
Caddy 配置。执行时须通过 `DEPLOY_PUBLIC_KEY` 传入专用 CI 公钥。

## Product principle

No streaks to protect, no missed workouts to repay—just the next session that
fits real life.
