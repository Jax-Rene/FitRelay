package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	_ "modernc.org/sqlite"
)

type server struct {
	db *sql.DB
	ai *deepSeekClient
}

type planRequest struct {
	RequestID string         `json:"request_id"`
	Locale    string         `json:"locale"`
	Timezone  string         `json:"timezone"`
	Profile   map[string]any `json:"profile"`
	Checkin   struct {
		RawText          string           `json:"raw_text"`
		AvailableMinutes int              `json:"available_minutes"`
		EnergyLevel      int              `json:"energy_level"`
		Pain             []map[string]any `json:"pain"`
		WantedFocus      []string         `json:"wanted_focus"`
		AvoidedFocus     []string         `json:"avoided_focus"`
	} `json:"checkin"`
	MuscleStates         []map[string]any `json:"muscle_states"`
	ExerciseCapabilities []struct {
		ExerciseSlug  string  `json:"exercise_slug"`
		LastLoadKG    float64 `json:"last_load_kg"`
		LastReps      int     `json:"last_reps"`
		TypicalEffort string  `json:"typical_effort"`
		Confidence    float64 `json:"confidence"`
	} `json:"exercise_capabilities"`
	AvailableExerciseSlugs []string `json:"available_exercise_slugs"`
}

type adjustRequest struct {
	RequestID        string         `json:"request_id"`
	CurrentPlan      map[string]any `json:"current_plan"`
	CompletedItemIDs []string       `json:"completed_item_ids"`
	Adjustment       struct {
		Type             string `json:"type"`
		RemainingMinutes int    `json:"remaining_minutes"`
		RawText          string `json:"raw_text"`
	} `json:"adjustment"`
}

type summaryRequest struct {
	RequestID string `json:"request_id"`
	Session   struct {
		ActualDurationSeconds int                `json:"actual_duration_seconds"`
		CompletedSets         int                `json:"completed_sets"`
		SkippedItems          int                `json:"skipped_items"`
		CardioMinutes         int                `json:"cardio_minutes"`
		MuscleCoverage        map[string]float64 `json:"muscle_coverage"`
		Notes                 []string           `json:"notes"`
	} `json:"session"`
	ComparableHistory []struct {
		Fact string `json:"fact"`
	} `json:"comparable_history"`
}

type apiError struct {
	Error struct {
		Code      string `json:"code"`
		Message   string `json:"message"`
		RequestID string `json:"request_id,omitempty"`
		Retryable bool   `json:"retryable"`
	} `json:"error"`
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		url := "http://127.0.0.1:8080/healthz"
		if len(os.Args) > 3 && os.Args[2] == "--url" {
			url = os.Args[3]
		}
		response, err := http.Get(url)
		if err != nil || response.StatusCode != http.StatusOK {
			os.Exit(1)
		}
		return
	}
	databasePath := env("DATABASE_PATH", "./data/app.db")
	if err := os.MkdirAll(dir(databasePath), 0o755); err != nil {
		log.Fatal(err)
	}
	db, err := sql.Open("sqlite", databasePath)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err := migrate(db); err != nil {
		log.Fatal(err)
	}

	s := &server{db: db, ai: newDeepSeekClientFromEnv()}
	httpServer := &http.Server{Addr: env("HTTP_ADDR", ":8080"), Handler: s.routes(), ReadHeaderTimeout: 5 * time.Second}
	go func() {
		log.Printf("suilian api listening on %s", httpServer.Addr)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(ctx)
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /demo", s.demoStatus)
	mux.HandleFunc("POST /v1/installations", s.install)
	mux.HandleFunc("POST /v1/coach/plans", s.withAuth(s.plan))
	mux.HandleFunc("POST /v1/coach/adjustments", s.withAuth(s.adjust))
	mux.HandleFunc("POST /v1/coach/summaries", s.withAuth(s.summary))
	return cors(mux)
}

func (s *server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *server) demoStatus(w http.ResponseWriter, _ *http.Request) {
	var installations int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM installations`).Scan(&installations)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>随练 AI API 状态</title><style>
	:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0f1115;color:#f3f5f0;font:15px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.wrap{max-width:920px;margin:0 auto;padding:64px 28px}.brand{display:flex;align-items:center;gap:14px;font-weight:800;font-size:20px}.logo{display:grid;width:46px;height:46px;place-items:center;border-radius:14px;background:#d8ff3e;color:#11130d;font-size:22px}.ok{margin:70px 0 34px;color:#d8ff3e;font-size:13px;font-weight:800;letter-spacing:.12em}.hero{font-size:54px;line-height:1.05;letter-spacing:-.04em;max-width:700px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:42px}.card{padding:22px;border:1px solid #2d3239;border-radius:18px;background:#181b20}.card b{display:block;font-size:28px;color:#d8ff3e}.card span{color:#929aa4;font-size:12px}.routes{margin-top:28px;padding:24px;border-radius:18px;background:#171b12;border:1px solid #3f4925}.routes h2{margin-top:0}.route{display:flex;justify-content:space-between;padding:12px 0;border-top:1px solid #303724;color:#cdd4bd}.route code{color:#d8ff3e}.footer{margin-top:28px;color:#6f7781;font-size:12px}@media(max-width:650px){.hero{font-size:38px}.grid{grid-template-columns:1fr}.wrap{padding-top:36px}}</style></head><body><main class="wrap"><div class="brand"><span class="logo">随</span>随练 AI · API</div><div class="ok">● SERVICE HEALTHY</div><h1 class="hero">客户端与服务端，<br>已经真正连起来。</h1><section class="grid"><div class="card"><b>OK</b><span>健康检查</span></div><div class="card"><b>%d</b><span>测试安装记录</span></div><div class="card"><b>SQLite</b><span>元数据持久化</span></div></section><section class="routes"><h2>已验证接口</h2><div class="route"><code>POST /v1/installations</code><span>安装鉴权</span></div><div class="route"><code>POST /v1/coach/plans</code><span>生成计划</span></div><div class="route"><code>POST /v1/coach/adjustments</code><span>调整计划</span></div><div class="route"><code>POST /v1/coach/summaries</code><span>事实总结</span></div></section><p class="footer">无大模型密钥时自动使用确定性规则，Demo 不依赖外部 AI 可用性。</p></main></body></html>`, installations)
}

func (s *server) install(w http.ResponseWriter, r *http.Request) {
	var request struct {
		InviteCode string `json:"invite_code"`
		Platform   string `json:"platform"`
		AppVersion string `json:"app_version"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if request.InviteCode != "EARLY-ACCESS-001" || request.AppVersion == "" {
		writeError(w, http.StatusBadRequest, "invalid_installation", "邀请码或版本信息无效。", "", false)
		return
	}
	token := randomToken(32)
	id := "ins_" + randomToken(12)
	now := time.Now().UnixMilli()
	_, err := s.db.Exec(`INSERT INTO installations(id, token_hash, app_platform, app_version, created_at_ms, last_seen_at_ms) VALUES(?,?,?,?,?,?)`, id, tokenHash(token), request.Platform, request.AppVersion, now, now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "storage_error", "无法创建安装记录。", "", true)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"installation_id": id, "access_token": token})
}

func (s *server) plan(w http.ResponseWriter, r *http.Request) {
	var request planRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if request.RequestID == "" || request.Checkin.AvailableMinutes < 5 {
		writeError(w, http.StatusUnprocessableEntity, "invalid_checkin", "训练时间至少需要 5 分钟。", request.RequestID, false)
		return
	}
	if len(request.Checkin.Pain) > 0 && request.Checkin.EnergyLevel <= 1 {
		writeJSON(w, http.StatusOK, map[string]any{"result_type": "stop_and_seek_help", "request_id": request.RequestID, "reason_code": "pain_and_low_readiness", "message": "今天先不要训练。持续不适请咨询医生或康复师。"})
		return
	}
	if s.ai != nil && len(request.AvailableExerciseSlugs) > 0 {
		started := time.Now()
		var aiPlan workoutPlan
		err := s.ai.completeJSON(r.Context(), "generate_workout_plan", request, &aiPlan)
		allowed := make(map[string]bool, len(request.AvailableExerciseSlugs))
		for _, slug := range request.AvailableExerciseSlugs {
			allowed[slug] = true
		}
		knownLoads := make(map[string]float64, len(request.ExerciseCapabilities))
		for _, capability := range request.ExerciseCapabilities {
			if capability.LastLoadKG > 0 {
				knownLoads[capability.ExerciseSlug] = capability.LastLoadKG
			}
		}
		repaired := false
		if err == nil {
			repaired, err = validateAIPlan(&aiPlan, request.Checkin.AvailableMinutes, allowed, knownLoads)
		}
		if err == nil {
			source := "ai"
			if repaired {
				source = "repaired_ai"
			}
			s.recordAIRun(r, request.RequestID, "plans", "succeeded", time.Since(started))
			writeJSON(w, http.StatusOK, map[string]any{"result_type": "workout_plan", "request_id": request.RequestID, "source": source, "plan": aiPlan})
			return
		}
		s.recordAIRun(r, request.RequestID, "plans", "fallback", time.Since(started))
	}
	plan := deterministicPlan(request.Checkin.AvailableMinutes)
	writeJSON(w, http.StatusOK, map[string]any{"result_type": "workout_plan", "request_id": request.RequestID, "source": "deterministic_fallback", "plan": plan})
}

func (s *server) adjust(w http.ResponseWriter, r *http.Request) {
	var request adjustRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	minutes := request.Adjustment.RemainingMinutes
	if minutes < 10 {
		minutes = 10
	}
	if s.ai != nil && request.RequestID != "" {
		started := time.Now()
		var aiPlan workoutPlan
		err := s.ai.completeJSON(r.Context(), "adjust_workout_plan", request, &aiPlan)
		allowed := allowedSlugsFromPlan(request.CurrentPlan)
		repaired := false
		if err == nil && len(allowed) > 0 {
			repaired, err = validateAIPlan(&aiPlan, minutes, allowed, nil)
		}
		if err == nil {
			source := "ai"
			if repaired {
				source = "repaired_ai"
			}
			s.recordAIRun(r, request.RequestID, "adjustments", "succeeded", time.Since(started))
			writeJSON(w, http.StatusOK, map[string]any{"result_type": "workout_plan", "request_id": request.RequestID, "source": source, "plan": aiPlan})
			return
		}
		s.recordAIRun(r, request.RequestID, "adjustments", "fallback", time.Since(started))
	}
	plan := deterministicPlan(minutes)
	plan["title"] = "缩短版全身训练"
	plan["coach_message"] = fmt.Sprintf("已按剩余 %d 分钟重排，保留三个主要动作。", minutes)
	writeJSON(w, http.StatusOK, map[string]any{"result_type": "workout_plan", "request_id": request.RequestID, "source": "deterministic_fallback", "plan": plan})
}

func (s *server) summary(w http.ResponseWriter, r *http.Request) {
	var request summaryRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	fact := fmt.Sprintf("本次实际完成 %d 个有效组。", request.Session.CompletedSets)
	headline := "一次有效的恢复训练。"
	if request.Session.CompletedSets <= 0 || request.Session.ActualDurationSeconds <= 0 {
		headline = "今天先到这里，没有虚构完成数据。"
	}
	if len(request.ComparableHistory) > 0 && request.ComparableHistory[0].Fact != "" {
		fact = request.ComparableHistory[0].Fact
	}
	if s.ai != nil && request.RequestID != "" {
		allowedFacts := []string{fmt.Sprintf("本次实际完成 %d 个有效组。", request.Session.CompletedSets)}
		for _, history := range request.ComparableHistory {
			if history.Fact != "" {
				allowedFacts = append(allowedFacts, history.Fact)
			}
		}
		started := time.Now()
		var generated aiSummary
		err := s.ai.completeJSON(r.Context(), "summarize_workout_facts", map[string]any{"session": request.Session, "allowed_facts": allowedFacts}, &generated)
		if err == nil {
			err = validateAISummary(generated, allowedFacts)
		}
		if err == nil {
			s.recordAIRun(r, request.RequestID, "summaries", "succeeded", time.Since(started))
			writeJSON(w, http.StatusOK, map[string]any{"request_id": request.RequestID, "headline": generated.Headline, "factual_message": generated.FactualMessage, "grounded_facts": generated.GroundedFacts, "source": "ai"})
			return
		}
		s.recordAIRun(r, request.RequestID, "summaries", "fallback", time.Since(started))
	}
	writeJSON(w, http.StatusOK, map[string]any{"request_id": request.RequestID, "headline": headline, "factual_message": fact, "grounded_facts": []string{fact}, "source": "deterministic_fallback"})
}

func allowedSlugsFromPlan(plan map[string]any) map[string]bool {
	allowed := make(map[string]bool)
	exercises, _ := plan["exercises"].([]any)
	for _, rawExercise := range exercises {
		exercise, _ := rawExercise.(map[string]any)
		if slug, ok := exercise["exercise_slug"].(string); ok && slug != "" {
			allowed[slug] = true
		}
		if alternatives, ok := exercise["alternative_slugs"].([]any); ok {
			for _, rawSlug := range alternatives {
				if slug, ok := rawSlug.(string); ok && slug != "" {
					allowed[slug] = true
				}
			}
		}
	}
	return allowed
}

func deterministicPlan(minutes int) map[string]any {
	all := []map[string]any{
		{"item_id": "item_1", "order_index": 0, "block_type": "strength", "exercise_slug": "leg_press", "sets": 3, "reps_min": 10, "reps_max": 12, "target_rir": 3, "rest_seconds": 90, "suggested_load_kg": 65, "load_basis": "conservative_adjustment", "cue": "腰臀贴紧靠背，膝盖与脚尖方向一致。", "alternative_slugs": []string{"machine_leg_extension"}},
		{"item_id": "item_2", "order_index": 1, "block_type": "strength", "exercise_slug": "machine_chest_press", "sets": 3, "reps_min": 8, "reps_max": 12, "target_rir": 3, "rest_seconds": 90, "suggested_load_kg": 30, "load_basis": "explore", "cue": "肩胛稳定，不耸肩。", "alternative_slugs": []string{"dumbbell_bench_press"}},
		{"item_id": "item_3", "order_index": 2, "block_type": "strength", "exercise_slug": "lat_pulldown", "sets": 3, "reps_min": 10, "reps_max": 12, "target_rir": 3, "rest_seconds": 90, "suggested_load_kg": 40, "load_basis": "previous_session", "cue": "拉向锁骨附近，避免大幅后仰。", "alternative_slugs": []string{"assisted_pull_up"}},
		{"item_id": "item_4", "order_index": 3, "block_type": "strength", "exercise_slug": "machine_leg_curl", "sets": 2, "reps_min": 10, "reps_max": 15, "target_rir": 3, "rest_seconds": 75, "suggested_load_kg": 25, "load_basis": "explore", "cue": "控制回程，不要快速弹回。", "alternative_slugs": []string{"seated_leg_curl"}},
		{"item_id": "item_5", "order_index": 4, "block_type": "cardio", "exercise_slug": "incline_treadmill_walk", "sets": 1, "target_duration_seconds": 900, "target_rir": 3, "rest_seconds": 0, "load_basis": "explore", "cue": "保持能够说完整句子的强度。", "alternative_slugs": []string{"elliptical"}},
	}
	count := len(all)
	if minutes <= 45 {
		count = 3
	}
	if minutes <= 20 {
		count = 2
	}
	estimatedMinutes := minutes
	if count == len(all) && estimatedMinutes > 68 {
		estimatedMinutes = 68
	}
	return map[string]any{"plan_id": "plan_" + randomToken(10), "title": "恢复型全身力量 + 有氧", "session_type": "recovery_full_body", "goal_summary": "重新覆盖主要肌群，找回动作节奏，不做补偿性加量。", "coach_message": "今天把强度留在还有约 3 次余力，动作稳定优先。", "estimated_minutes": estimatedMinutes, "intensity_guidance": "每组保留约 3 次余力；动作稳定优先。", "exercises": all[:count]}
}

func (s *server) withAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if token == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "缺少访问凭证。", "", false)
			return
		}
		var id string
		if err := s.db.QueryRow(`SELECT id FROM installations WHERE token_hash=? AND status='active'`, tokenHash(token)).Scan(&id); err != nil {
			writeError(w, http.StatusUnauthorized, "unauthorized", "访问凭证无效。", "", false)
			return
		}
		_, _ = s.db.Exec(`UPDATE installations SET last_seen_at_ms=? WHERE id=?`, time.Now().UnixMilli(), id)
		next(w, r.WithContext(context.WithValue(r.Context(), installationIDKey{}, id)))
	}
}

type installationIDKey struct{}

func (s *server) recordAIRun(r *http.Request, requestID, endpoint, status string, latency time.Duration) {
	installationID, _ := r.Context().Value(installationIDKey{}).(string)
	now := time.Now().UnixMilli()
	validationStatus := "passed"
	errorCode := ""
	if status == "fallback" {
		validationStatus = "failed"
		errorCode = "provider_or_validation_failure"
	}
	model := ""
	if s.ai != nil {
		model = s.ai.model
	}
	_, _ = s.db.Exec(`INSERT INTO ai_runs(id, installation_id, request_id, endpoint, provider, model, prompt_version, status, validation_status, latency_ms, error_code, created_at_ms, completed_at_ms)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON CONFLICT(request_id) DO UPDATE SET status=excluded.status, validation_status=excluded.validation_status, latency_ms=excluded.latency_ms, error_code=excluded.error_code, completed_at_ms=excluded.completed_at_ms`,
		"air_"+randomToken(12), installationID, requestID, endpoint, "deepseek", model, "v1", status, validationStatus, latency.Milliseconds(), errorCode, now, now)
}

func migrate(db *sql.DB) error {
	_, err := db.Exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
	CREATE TABLE IF NOT EXISTS installations(id TEXT PRIMARY KEY, token_hash TEXT NOT NULL UNIQUE, status TEXT NOT NULL DEFAULT 'active', app_platform TEXT NOT NULL, app_version TEXT NOT NULL, created_at_ms INTEGER NOT NULL, last_seen_at_ms INTEGER NOT NULL);
	CREATE TABLE IF NOT EXISTS ai_runs(id TEXT PRIMARY KEY, installation_id TEXT, request_id TEXT NOT NULL UNIQUE, endpoint TEXT NOT NULL, provider TEXT NOT NULL DEFAULT '', model TEXT NOT NULL DEFAULT '', prompt_version TEXT NOT NULL DEFAULT 'v1', status TEXT NOT NULL, validation_status TEXT, input_tokens INTEGER, output_tokens INTEGER, latency_ms INTEGER, retry_count INTEGER NOT NULL DEFAULT 0, error_code TEXT, request_fingerprint TEXT, created_at_ms INTEGER NOT NULL, completed_at_ms INTEGER);`)
	if err != nil {
		return err
	}
	columns := map[string]string{
		"provider":            "TEXT NOT NULL DEFAULT ''",
		"model":               "TEXT NOT NULL DEFAULT ''",
		"prompt_version":      "TEXT NOT NULL DEFAULT 'v1'",
		"validation_status":   "TEXT",
		"input_tokens":        "INTEGER",
		"output_tokens":       "INTEGER",
		"retry_count":         "INTEGER NOT NULL DEFAULT 0",
		"error_code":          "TEXT",
		"request_fingerprint": "TEXT",
	}
	for name, definition := range columns {
		if err := ensureColumn(db, "ai_runs", name, definition); err != nil {
			return err
		}
	}
	return nil
}

func ensureColumn(db *sql.DB, table, name, definition string) error {
	rows, err := db.Query("PRAGMA table_info(" + table + ")")
	if err != nil {
		return fmt.Errorf("inspect %s schema: %w", table, err)
	}
	found := false
	for rows.Next() {
		var cid int
		var columnName, columnType string
		var notNull, primaryKey int
		var defaultValue any
		if err := rows.Scan(&cid, &columnName, &columnType, &notNull, &defaultValue, &primaryKey); err != nil {
			rows.Close()
			return fmt.Errorf("read %s schema: %w", table, err)
		}
		if columnName == name {
			found = true
		}
	}
	if err := rows.Close(); err != nil {
		return fmt.Errorf("close %s schema rows: %w", table, err)
	}
	if found {
		return nil
	}
	if _, err := db.Exec("ALTER TABLE " + table + " ADD COLUMN " + name + " " + definition); err != nil {
		return fmt.Errorf("add %s.%s: %w", table, name, err)
	}
	return nil
}

func decodeJSON(w http.ResponseWriter, r *http.Request, destination any) bool {
	defer r.Body.Close()
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 262144))
	if err := decoder.Decode(destination); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "请求格式无效。", "", false)
		return false
	}
	return true
}
func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func writeError(w http.ResponseWriter, status int, code, message, requestID string, retryable bool) {
	var response apiError
	response.Error.Code = code
	response.Error.Message = message
	response.Error.RequestID = requestID
	response.Error.Retryable = retryable
	writeJSON(w, status, response)
}
func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
func randomToken(bytes int) string {
	value := make([]byte, bytes)
	if _, err := rand.Read(value); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(value)
}
func tokenHash(token string) string {
	value := sha256.Sum256([]byte(token))
	return hex.EncodeToString(value[:])
}
func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
func dir(path string) string {
	index := strings.LastIndex(path, "/")
	if index < 0 {
		return "."
	}
	return path[:index]
}
