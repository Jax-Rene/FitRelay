-- 随练 AI mobile SQLite reference schema v1
-- Drift 应使用 Dart tables 和 migrations 实现；本文件用于统一概念与验收。

PRAGMA foreign_keys = ON;

CREATE TABLE user_profile (
    id TEXT PRIMARY KEY,
    display_name TEXT,
    primary_goal TEXT NOT NULL,
    experience_level TEXT NOT NULL,
    default_environment TEXT NOT NULL,
    coaching_tone TEXT NOT NULL,
    preferences_json TEXT NOT NULL DEFAULT '{}'
        CHECK (json_valid(preferences_json)),
    constraints_json TEXT NOT NULL DEFAULT '[]'
        CHECK (json_valid(constraints_json)),
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE TABLE coach_memories (
    id TEXT PRIMARY KEY,
    memory_type TEXT NOT NULL,
    content TEXT NOT NULL,
    structured_value_json TEXT
        CHECK (structured_value_json IS NULL OR json_valid(structured_value_json)),
    source TEXT NOT NULL,
    confidence REAL NOT NULL DEFAULT 0.5 CHECK (confidence BETWEEN 0 AND 1),
    status TEXT NOT NULL DEFAULT 'confirmed'
        CHECK (status IN ('candidate', 'confirmed', 'rejected')),
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE INDEX coach_memories_status_idx
ON coach_memories(status, memory_type);

CREATE TABLE exercises (
    slug TEXT PRIMARY KEY,
    catalog_version INTEGER NOT NULL,
    name_zh TEXT NOT NULL,
    movement_pattern TEXT NOT NULL,
    primary_muscles_json TEXT NOT NULL CHECK (json_valid(primary_muscles_json)),
    secondary_muscles_json TEXT NOT NULL CHECK (json_valid(secondary_muscles_json)),
    equipment_json TEXT NOT NULL CHECK (json_valid(equipment_json)),
    difficulty TEXT NOT NULL,
    cue_zh TEXT NOT NULL,
    alternative_slugs_json TEXT NOT NULL CHECK (json_valid(alternative_slugs_json)),
    risk_tags_json TEXT NOT NULL CHECK (json_valid(risk_tags_json)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
) STRICT;

CREATE TABLE readiness_checkins (
    id TEXT PRIMARY KEY,
    raw_text TEXT,
    input_mode TEXT NOT NULL DEFAULT 'text'
        CHECK (input_mode IN ('text', 'speech_transcript', 'quick_options')),
    available_minutes INTEGER NOT NULL CHECK (available_minutes BETWEEN 5 AND 240),
    energy_level INTEGER CHECK (energy_level BETWEEN 1 AND 5),
    pain_json TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(pain_json)),
    wanted_focus_json TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(wanted_focus_json)),
    avoided_focus_json TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(avoided_focus_json)),
    environment_json TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(environment_json)),
    created_at_ms INTEGER NOT NULL
) STRICT;

-- 保存可复用的结构化训练意图。临时疼痛、精力等状态仍应在复用时重新确认，
-- 不能因为出现在上一次输入中就自动升级为长期 Memory。
CREATE TABLE training_intents (
    id TEXT PRIMARY KEY,
    source_checkin_id TEXT REFERENCES readiness_checkins(id) ON DELETE SET NULL,
    raw_transcript TEXT,
    summary TEXT NOT NULL,
    structured_intent_json TEXT NOT NULL CHECK (json_valid(structured_intent_json)),
    source TEXT NOT NULL DEFAULT 'user_input'
        CHECK (source IN ('user_input','reused','edited')),
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE INDEX training_intents_created_idx
ON training_intents(created_at_ms DESC);

CREATE TABLE workout_sessions (
    id TEXT PRIMARY KEY,
    checkin_id TEXT REFERENCES readiness_checkins(id) ON DELETE SET NULL,
    status TEXT NOT NULL
        CHECK (status IN ('draft','ready','active','paused','completed','ended_early')),
    session_type TEXT NOT NULL,
    title TEXT NOT NULL,
    goal_summary TEXT NOT NULL,
    coach_message TEXT NOT NULL DEFAULT '',
    planned_duration_minutes INTEGER NOT NULL,
    actual_duration_seconds INTEGER,
    plan_source TEXT NOT NULL DEFAULT 'local'
        CHECK (plan_source IN ('local','remote','fallback')),
    plan_version INTEGER NOT NULL DEFAULT 1,
    exercise_catalog_version INTEGER NOT NULL,
    started_at_ms INTEGER,
    completed_at_ms INTEGER,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE INDEX workout_sessions_created_idx
ON workout_sessions(created_at_ms DESC);

CREATE INDEX workout_sessions_active_idx
ON workout_sessions(status)
WHERE status IN ('ready','active','paused');

CREATE TABLE workout_items (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    block_type TEXT NOT NULL
        CHECK (block_type IN ('warmup','strength','core','cardio','cooldown')),
    exercise_slug TEXT REFERENCES exercises(slug),
    planned_sets INTEGER NOT NULL CHECK (planned_sets BETWEEN 1 AND 10),
    reps_min INTEGER,
    reps_max INTEGER,
    target_duration_seconds INTEGER CHECK (target_duration_seconds IS NULL OR target_duration_seconds BETWEEN 1 AND 21600),
    target_rir INTEGER CHECK (target_rir IS NULL OR target_rir BETWEEN 0 AND 6),
    rest_seconds INTEGER NOT NULL DEFAULT 90 CHECK (rest_seconds BETWEEN 0 AND 600),
    suggested_load_kg REAL,
    load_basis TEXT NOT NULL DEFAULT 'explore',
    cue TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','active','completed','skipped','replaced')),
    replacement_for_item_id TEXT REFERENCES workout_items(id) ON DELETE SET NULL,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    UNIQUE(session_id, order_index)
) STRICT;

CREATE INDEX workout_items_session_idx
ON workout_items(session_id, order_index);

CREATE TABLE workout_adjustments (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    adjustment_type TEXT NOT NULL
        CHECK (adjustment_type IN ('shorten','replace_exercise','reduce_intensity','avoid_area','delete_item','reduce_sets','free_text')),
    source TEXT NOT NULL DEFAULT 'quick_action'
        CHECK (source IN ('quick_action','text','speech_transcript','local_rule','remote_ai')),
    source_item_id TEXT REFERENCES workout_items(id) ON DELETE SET NULL,
    result_item_id TEXT REFERENCES workout_items(id) ON DELETE SET NULL,
    plan_version_before INTEGER NOT NULL,
    plan_version_after INTEGER NOT NULL,
    details_json TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(details_json)),
    created_at_ms INTEGER NOT NULL,
    CHECK (plan_version_after >= plan_version_before)
) STRICT;

CREATE INDEX workout_adjustments_session_idx
ON workout_adjustments(session_id, created_at_ms);

CREATE TABLE workout_sets (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    workout_item_id TEXT NOT NULL REFERENCES workout_items(id) ON DELETE CASCADE,
    set_index INTEGER NOT NULL CHECK (set_index BETWEEN 1 AND 20),
    load_kg REAL,
    reps INTEGER CHECK (reps IS NULL OR reps BETWEEN 0 AND 500),
    duration_seconds INTEGER,
    effort TEXT CHECK (effort IS NULL OR effort IN ('easy','good','heavy')),
    is_warmup INTEGER NOT NULL DEFAULT 0 CHECK (is_warmup IN (0,1)),
    notes TEXT,
    completed_at_ms INTEGER,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    UNIQUE(workout_item_id, set_index)
) STRICT;

CREATE INDEX workout_sets_session_idx
ON workout_sets(session_id, workout_item_id, set_index);

CREATE TABLE workout_summaries (
    session_id TEXT PRIMARY KEY REFERENCES workout_sessions(id) ON DELETE CASCADE,
    headline TEXT NOT NULL DEFAULT '',
    factual_message TEXT NOT NULL DEFAULT '',
    grounded_facts_json TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(grounded_facts_json)),
    muscle_coverage_json TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(muscle_coverage_json)),
    cardio_minutes INTEGER NOT NULL DEFAULT 0 CHECK (cardio_minutes BETWEEN 0 AND 300),
    summary_source TEXT NOT NULL DEFAULT 'local'
        CHECK (summary_source IN ('local','remote','fallback')),
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE TABLE exercise_capabilities (
    exercise_slug TEXT PRIMARY KEY REFERENCES exercises(slug),
    last_load_kg REAL,
    last_reps INTEGER,
    typical_effort TEXT CHECK (typical_effort IS NULL OR typical_effort IN ('easy','good','heavy')),
    estimated_performance_score REAL,
    confidence REAL NOT NULL DEFAULT 0 CHECK (confidence BETWEEN 0 AND 1),
    last_performed_at_ms INTEGER,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE TABLE muscle_states (
    muscle_group TEXT PRIMARY KEY,
    last_trained_at_ms INTEGER,
    effective_sets_14d REAL NOT NULL DEFAULT 0,
    effective_sets_30d REAL NOT NULL DEFAULT 0,
    priority_score REAL NOT NULL DEFAULT 0,
    score_reason_json TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(score_reason_json)),
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE TABLE active_session_state (
    singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
    session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    current_item_id TEXT REFERENCES workout_items(id) ON DELETE SET NULL,
    current_set_index INTEGER,
    phase TEXT NOT NULL CHECK (phase IN ('ready','active','resting','paused')),
    rest_ends_at_ms INTEGER,
    updated_at_ms INTEGER NOT NULL
) STRICT;

CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL CHECK (json_valid(value_json)),
    updated_at_ms INTEGER NOT NULL
) STRICT;
