package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	_ "modernc.org/sqlite"
)

func testServer(t *testing.T) (*server, http.Handler) {
	t.Helper()
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	if err := migrate(db); err != nil {
		t.Fatal(err)
	}
	s := &server{db: db}
	return s, s.routes()
}

func installForTest(t *testing.T, handler http.Handler) string {
	t.Helper()
	install := httptest.NewRecorder()
	handler.ServeHTTP(install, httptest.NewRequest(http.MethodPost, "/v1/installations", bytes.NewBufferString(`{"invite_code":"EARLY-ACCESS-001","platform":"android","app_version":"0.1.0"}`)))
	if install.Code != http.StatusCreated {
		t.Fatalf("install status=%d body=%s", install.Code, install.Body.String())
	}
	var credentials map[string]string
	if err := json.Unmarshal(install.Body.Bytes(), &credentials); err != nil {
		t.Fatal(err)
	}
	return credentials["access_token"]
}

func deepSeekStub(t *testing.T, content string, inspect func(chatCompletionRequest, *http.Request)) (*httptest.Server, *deepSeekClient) {
	t.Helper()
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request chatCompletionRequest
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Errorf("decode upstream request: %v", err)
		}
		if inspect != nil {
			inspect(request, r)
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"choices": []any{map[string]any{
				"finish_reason": "stop",
				"message":       map[string]any{"content": content},
			}},
		})
	}))
	client := &deepSeekClient{
		apiKey:  "test-key",
		baseURL: upstream.URL,
		model:   "deepseek-v4-flash",
		client:  &http.Client{Timeout: time.Second},
	}
	return upstream, client
}

func TestHealthInstallationAndPlan(t *testing.T) {
	_, handler := testServer(t)
	health := httptest.NewRecorder()
	handler.ServeHTTP(health, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if health.Code != http.StatusOK {
		t.Fatalf("health status=%d", health.Code)
	}

	installBody := bytes.NewBufferString(`{"invite_code":"EARLY-ACCESS-001","platform":"android","app_version":"0.1.0"}`)
	install := httptest.NewRecorder()
	handler.ServeHTTP(install, httptest.NewRequest(http.MethodPost, "/v1/installations", installBody))
	if install.Code != http.StatusCreated {
		t.Fatalf("install status=%d body=%s", install.Code, install.Body.String())
	}
	var credentials map[string]string
	if err := json.Unmarshal(install.Body.Bytes(), &credentials); err != nil {
		t.Fatal(err)
	}
	if len(credentials["access_token"]) < 32 {
		t.Fatal("missing access token")
	}

	planRequest := httptest.NewRequest(http.MethodPost, "/v1/coach/plans", bytes.NewBufferString(`{"request_id":"req_test","checkin":{"available_minutes":30,"energy_level":3,"pain":[]}}`))
	planRequest.Header.Set("Authorization", "Bearer "+credentials["access_token"])
	plan := httptest.NewRecorder()
	handler.ServeHTTP(plan, planRequest)
	if plan.Code != http.StatusOK {
		t.Fatalf("plan status=%d body=%s", plan.Code, plan.Body.String())
	}
	if !bytes.Contains(plan.Body.Bytes(), []byte(`"deterministic_fallback"`)) {
		t.Fatal("expected deterministic fallback")
	}
}

func TestProtectedEndpointsRejectMissingToken(t *testing.T) {
	_, handler := testServer(t)
	request := httptest.NewRequest(http.MethodPost, "/v1/coach/plans", bytes.NewBufferString(`{}`))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestDeterministicPlanUsesCanonicalDemoMetrics(t *testing.T) {
	plan := deterministicPlan(70)
	if got := plan["estimated_minutes"]; got != 68 {
		t.Fatalf("estimated_minutes=%v want=68", got)
	}
	exercises, ok := plan["exercises"].([]map[string]any)
	if !ok {
		t.Fatalf("unexpected exercises type %T", plan["exercises"])
	}
	if len(exercises) != 5 {
		t.Fatalf("exercise count=%d want=5", len(exercises))
	}
	strengthSets := 0
	for _, exercise := range exercises {
		if exercise["block_type"] == "strength" {
			strengthSets += exercise["sets"].(int)
		}
	}
	if strengthSets != 11 {
		t.Fatalf("strength sets=%d want=11", strengthSets)
	}
	last := exercises[len(exercises)-1]
	if last["exercise_slug"] != "incline_treadmill_walk" || last["target_duration_seconds"] != 900 {
		t.Fatalf("unexpected cardio item: %#v", last)
	}
}

func TestAdjustmentAndSummary(t *testing.T) {
	_, handler := testServer(t)
	install := httptest.NewRecorder()
	handler.ServeHTTP(install, httptest.NewRequest(http.MethodPost, "/v1/installations", bytes.NewBufferString(`{"invite_code":"EARLY-ACCESS-001","platform":"android","app_version":"0.1.0"}`)))
	var credentials map[string]string
	if err := json.Unmarshal(install.Body.Bytes(), &credentials); err != nil {
		t.Fatal(err)
	}
	auth := "Bearer " + credentials["access_token"]

	adjustRequest := httptest.NewRequest(http.MethodPost, "/v1/coach/adjustments", bytes.NewBufferString(`{"request_id":"req_adjust","current_plan":{},"adjustment":{"type":"shorten","remaining_minutes":15}}`))
	adjustRequest.Header.Set("Authorization", auth)
	adjust := httptest.NewRecorder()
	handler.ServeHTTP(adjust, adjustRequest)
	if adjust.Code != http.StatusOK || !bytes.Contains(adjust.Body.Bytes(), []byte(`"estimated_minutes":15`)) {
		t.Fatalf("adjust status=%d body=%s", adjust.Code, adjust.Body.String())
	}

	summaryRequest := httptest.NewRequest(http.MethodPost, "/v1/coach/summaries", bytes.NewBufferString(`{"request_id":"req_summary","session":{"actual_duration_seconds":2400,"completed_sets":9,"skipped_items":0,"cardio_minutes":0,"muscle_coverage":{}},"comparable_history":[]}`))
	summaryRequest.Header.Set("Authorization", auth)
	summary := httptest.NewRecorder()
	handler.ServeHTTP(summary, summaryRequest)
	if summary.Code != http.StatusOK || !bytes.Contains(summary.Body.Bytes(), []byte(`本次实际完成 9 个有效组`)) {
		t.Fatalf("summary status=%d body=%s", summary.Code, summary.Body.String())
	}
}

func TestDeepSeekPlanIsValidatedAndReturned(t *testing.T) {
	aiContent := `{"plan_id":"ignored","title":"30 分钟全身训练","session_type":"full_body","goal_summary":"覆盖主要肌群。","coach_message":"动作稳定优先。","estimated_minutes":30,"intensity_guidance":"每组保留 3 次余力。","exercises":[{"item_id":"item_1","order_index":0,"block_type":"strength","exercise_slug":"leg_press","sets":3,"reps_min":10,"reps_max":12,"target_rir":3,"rest_seconds":90,"load_basis":"explore","cue":"腰臀贴紧靠背。","alternative_slugs":[]}]}`
	upstream, ai := deepSeekStub(t, aiContent, func(request chatCompletionRequest, httpRequest *http.Request) {
		if httpRequest.Header.Get("Authorization") != "Bearer test-key" {
			t.Error("missing DeepSeek authorization")
		}
		if request.ResponseFormat["type"] != "json_object" || request.Thinking["type"] != "disabled" {
			t.Fatalf("unexpected structured-output settings: %#v", request)
		}
		if !strings.Contains(request.Messages[0].Content, "block_type 只能是 warmup、strength、core、cardio、cooldown") {
			t.Fatal("system prompt did not constrain block_type values")
		}
		if !strings.Contains(request.Messages[1].Content, "今天想稳一点") {
			t.Fatal("raw check-in text was not sent to DeepSeek")
		}
	})
	defer upstream.Close()

	s, handler := testServer(t)
	s.ai = ai
	token := installForTest(t, handler)
	body := `{"request_id":"req_ai_plan","locale":"zh-CN","timezone":"Asia/Shanghai","profile":{"primary_goal":"maintain_muscle"},"checkin":{"raw_text":"今天想稳一点","available_minutes":30,"energy_level":3,"pain":[],"wanted_focus":["full_body"],"avoided_focus":[]},"muscle_states":[],"exercise_capabilities":[],"available_exercise_slugs":["leg_press"]}`
	request := httptest.NewRequest(http.MethodPost, "/v1/coach/plans", bytes.NewBufferString(body))
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK || !bytes.Contains(response.Body.Bytes(), []byte(`"source":"ai"`)) {
		t.Fatalf("plan status=%d body=%s", response.Code, response.Body.String())
	}
	var provider, model, status string
	if err := s.db.QueryRow(`SELECT provider, model, status FROM ai_runs WHERE request_id=?`, "req_ai_plan").Scan(&provider, &model, &status); err != nil {
		t.Fatal(err)
	}
	if provider != "deepseek" || model != "deepseek-v4-flash" || status != "succeeded" {
		t.Fatalf("unexpected AI run metadata: provider=%s model=%s status=%s", provider, model, status)
	}
}

func TestDeepSeekCommonEnumsAndVolumeAreSafelyNormalized(t *testing.T) {
	aiContent := `{"plan_id":"ignored","title":"30 分钟全身训练","session_type":"workout","goal_summary":"覆盖主要肌群。","coach_message":"动作稳定优先。","estimated_minutes":45,"intensity_guidance":"每组保留 3 次余力。","exercises":[{"item_id":"item_1","order_index":0,"block_type":"main","exercise_slug":"leg_press","sets":8,"reps_min":0,"reps_max":50,"target_rir":9,"rest_seconds":400,"load_basis":"default","cue":"腰臀贴紧靠背。","alternative_slugs":["unknown_exercise"]}]}`
	upstream, ai := deepSeekStub(t, aiContent, nil)
	defer upstream.Close()

	s, handler := testServer(t)
	s.ai = ai
	token := installForTest(t, handler)
	body := `{"request_id":"req_ai_repaired","locale":"zh-CN","timezone":"Asia/Shanghai","profile":{"primary_goal":"maintain_muscle"},"checkin":{"raw_text":"今天想稳一点","available_minutes":30,"energy_level":3,"pain":[],"wanted_focus":["full_body"],"avoided_focus":[]},"muscle_states":[],"exercise_capabilities":[],"available_exercise_slugs":["leg_press"]}`
	request := httptest.NewRequest(http.MethodPost, "/v1/coach/plans", bytes.NewBufferString(body))
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK || !bytes.Contains(response.Body.Bytes(), []byte(`"source":"repaired_ai"`)) {
		t.Fatalf("plan status=%d body=%s", response.Code, response.Body.String())
	}
	var envelope struct {
		Plan workoutPlan `json:"plan"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &envelope); err != nil {
		t.Fatal(err)
	}
	exercise := envelope.Plan.Exercises[0]
	if envelope.Plan.SessionType != "mixed" ||
		envelope.Plan.EstimatedMinutes != 30 ||
		exercise.BlockType != "strength" ||
		exercise.Sets != 5 ||
		exercise.RepsMin != 8 ||
		exercise.RepsMax != 12 ||
		exercise.TargetRIR != 3 ||
		exercise.RestSeconds != 300 ||
		exercise.LoadBasis != "explore" ||
		len(exercise.AlternativeSlugs) != 0 {
		t.Fatalf("unexpected normalized plan: %#v", envelope.Plan)
	}
}

func TestDeepSeekPlanOutsideCatalogFallsBack(t *testing.T) {
	aiContent := `{"plan_id":"ignored","title":"计划","session_type":"full_body","goal_summary":"覆盖主要肌群。","coach_message":"动作稳定优先。","estimated_minutes":30,"intensity_guidance":"保留余力。","exercises":[{"item_id":"item_1","order_index":0,"block_type":"strength","exercise_slug":"unknown_exercise","sets":3,"reps_min":10,"reps_max":12,"target_rir":3,"rest_seconds":90,"load_basis":"explore","cue":"保持稳定。","alternative_slugs":[]}]}`
	upstream, ai := deepSeekStub(t, aiContent, nil)
	defer upstream.Close()

	s, handler := testServer(t)
	s.ai = ai
	token := installForTest(t, handler)
	body := `{"request_id":"req_ai_fallback","checkin":{"available_minutes":30,"energy_level":3,"pain":[]},"available_exercise_slugs":["leg_press"]}`
	request := httptest.NewRequest(http.MethodPost, "/v1/coach/plans", bytes.NewBufferString(body))
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK || !bytes.Contains(response.Body.Bytes(), []byte(`"source":"deterministic_fallback"`)) {
		t.Fatalf("plan status=%d body=%s", response.Code, response.Body.String())
	}
	var status string
	if err := s.db.QueryRow(`SELECT status FROM ai_runs WHERE request_id=?`, "req_ai_fallback").Scan(&status); err != nil {
		t.Fatal(err)
	}
	if status != "fallback" {
		t.Fatalf("AI run status=%s want=fallback", status)
	}
}
