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

## Product principle

No streaks to protect, no missed workouts to repay—just the next session that
fits real life.
