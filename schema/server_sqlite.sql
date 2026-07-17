-- 随练 AI Go API SQLite schema v1
-- 仅保存安装授权、用量和 AI 调用元数据；不保存完整训练历史。

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
PRAGMA synchronous = FULL;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at_ms INTEGER NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS invite_codes (
    id TEXT PRIMARY KEY,
    code_hash BLOB NOT NULL UNIQUE,
    label TEXT NOT NULL DEFAULT '',
    max_activations INTEGER NOT NULL DEFAULT 1 CHECK (max_activations >= 1),
    activation_count INTEGER NOT NULL DEFAULT 0 CHECK (activation_count >= 0),
    expires_at_ms INTEGER,
    revoked_at_ms INTEGER,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    CHECK (activation_count <= max_activations)
) STRICT;

CREATE TABLE IF NOT EXISTS installations (
    id TEXT PRIMARY KEY,
    token_hash BLOB NOT NULL UNIQUE,
    invite_code_id TEXT REFERENCES invite_codes(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','revoked')),
    app_platform TEXT NOT NULL DEFAULT 'android'
        CHECK (app_platform IN ('android','ios','unknown')),
    app_version TEXT NOT NULL DEFAULT '',
    created_at_ms INTEGER NOT NULL,
    last_seen_at_ms INTEGER NOT NULL,
    revoked_at_ms INTEGER
) STRICT;

CREATE INDEX IF NOT EXISTS installations_status_idx
ON installations(status, last_seen_at_ms DESC);

CREATE TABLE IF NOT EXISTS prompt_versions (
    prompt_type TEXT NOT NULL,
    version TEXT NOT NULL,
    sha256_hex TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
    created_at_ms INTEGER NOT NULL,
    PRIMARY KEY(prompt_type, version)
) STRICT;

CREATE TABLE IF NOT EXISTS ai_runs (
    id TEXT PRIMARY KEY,
    installation_id TEXT REFERENCES installations(id) ON DELETE SET NULL,
    request_id TEXT NOT NULL UNIQUE,
    endpoint TEXT NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    prompt_version TEXT NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN ('started','succeeded','failed','fallback')),
    validation_status TEXT,
    input_tokens INTEGER,
    output_tokens INTEGER,
    latency_ms INTEGER,
    retry_count INTEGER NOT NULL DEFAULT 0,
    error_code TEXT,
    request_fingerprint TEXT,
    created_at_ms INTEGER NOT NULL,
    completed_at_ms INTEGER
) STRICT;

CREATE INDEX IF NOT EXISTS ai_runs_installation_created_idx
ON ai_runs(installation_id, created_at_ms DESC);

CREATE INDEX IF NOT EXISTS ai_runs_status_created_idx
ON ai_runs(status, created_at_ms DESC);

CREATE TABLE IF NOT EXISTS rate_limit_counters (
    installation_id TEXT NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
    bucket_start_ms INTEGER NOT NULL,
    bucket_seconds INTEGER NOT NULL CHECK (bucket_seconds > 0),
    request_count INTEGER NOT NULL DEFAULT 0 CHECK (request_count >= 0),
    updated_at_ms INTEGER NOT NULL,
    PRIMARY KEY(installation_id, bucket_start_ms, bucket_seconds)
) STRICT;
