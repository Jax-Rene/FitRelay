package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const deepSeekSystemPrompt = `你是随练 AI 的训练计划编排器。只输出 JSON，不要输出 Markdown 或解释。
安全规则：只能使用输入中的动作 slug；不得诊断疾病；有疼痛风险时不要自行给康复处方；不得虚构训练历史；训练量、时长和重量必须保守。
生成或调整计划时，顶层必须直接是计划对象，只允许 plan_id、title、session_type、goal_summary、coach_message、estimated_minutes、intensity_guidance、exercises 这 8 个字段；不要包装 plan，不要添加 summary、reasoning 或其他字段。每个 exercise 只允许 item_id、order_index、block_type、exercise_slug、sets、reps_min、reps_max、target_duration_seconds、target_rir、rest_seconds、suggested_load_kg、load_basis、cue、alternative_slugs；力量动作需要 reps_min、reps_max，有氧动作需要 target_duration_seconds，不适用的可选字段直接省略。
生成总结时，顶层只允许 headline、factual_message、grounded_facts 这 3 个字段，并且 factual_message 和 grounded_facts 只能逐字使用输入的 allowed_facts。`

type deepSeekClient struct {
	apiKey  string
	baseURL string
	model   string
	client  *http.Client
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatCompletionRequest struct {
	Model          string            `json:"model"`
	Messages       []chatMessage     `json:"messages"`
	ResponseFormat map[string]string `json:"response_format"`
	Thinking       map[string]string `json:"thinking,omitempty"`
	MaxTokens      int               `json:"max_tokens"`
}

type chatCompletionResponse struct {
	Choices []struct {
		FinishReason string `json:"finish_reason"`
		Message      struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

type workoutPlan struct {
	PlanID            string            `json:"plan_id"`
	Title             string            `json:"title"`
	SessionType       string            `json:"session_type"`
	GoalSummary       string            `json:"goal_summary"`
	CoachMessage      string            `json:"coach_message"`
	EstimatedMinutes  int               `json:"estimated_minutes"`
	IntensityGuidance string            `json:"intensity_guidance"`
	Exercises         []workoutExercise `json:"exercises"`
}

type workoutExercise struct {
	ItemID                any      `json:"item_id"`
	OrderIndex            int      `json:"order_index"`
	BlockType             string   `json:"block_type"`
	ExerciseSlug          string   `json:"exercise_slug"`
	Sets                  int      `json:"sets"`
	RepsMin               int      `json:"reps_min,omitempty"`
	RepsMax               int      `json:"reps_max,omitempty"`
	TargetDurationSeconds int      `json:"target_duration_seconds,omitempty"`
	TargetRIR             int      `json:"target_rir"`
	RestSeconds           int      `json:"rest_seconds"`
	SuggestedLoadKG       *float64 `json:"suggested_load_kg,omitempty"`
	LoadBasis             string   `json:"load_basis"`
	Cue                   string   `json:"cue"`
	AlternativeSlugs      []string `json:"alternative_slugs"`
}

type aiSummary struct {
	Headline       string   `json:"headline"`
	FactualMessage string   `json:"factual_message"`
	GroundedFacts  []string `json:"grounded_facts"`
}

func newDeepSeekClientFromEnv() *deepSeekClient {
	if provider := strings.ToLower(strings.TrimSpace(env("LLM_PROVIDER", "deepseek"))); provider != "deepseek" {
		return nil
	}
	apiKey := strings.TrimSpace(env("LLM_API_KEY", env("DEEPSEEK_API_KEY", "")))
	if apiKey == "" {
		return nil
	}
	timeout, err := time.ParseDuration(env("LLM_TIMEOUT", env("DEEPSEEK_TIMEOUT", "12s")))
	if err != nil || timeout <= 0 {
		timeout = 12 * time.Second
	}
	return &deepSeekClient{
		apiKey:  apiKey,
		baseURL: strings.TrimRight(env("LLM_BASE_URL", env("DEEPSEEK_BASE_URL", "https://api.deepseek.com")), "/"),
		model:   env("LLM_MODEL", env("DEEPSEEK_MODEL", "deepseek-v4-flash")),
		client:  &http.Client{Timeout: timeout},
	}
}

func (c *deepSeekClient) completeJSON(ctx context.Context, operation string, input any, output any) error {
	inputJSON, err := json.Marshal(input)
	if err != nil {
		return fmt.Errorf("marshal %s input: %w", operation, err)
	}
	prompt := fmt.Sprintf("任务：%s。请根据以下输入返回符合约定的 JSON：\n%s", operation, inputJSON)
	payload, err := json.Marshal(chatCompletionRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: deepSeekSystemPrompt},
			{Role: "user", Content: prompt},
		},
		ResponseFormat: map[string]string{"type": "json_object"},
		Thinking:       map[string]string{"type": "disabled"},
		MaxTokens:      2048,
	})
	if err != nil {
		return fmt.Errorf("marshal DeepSeek request: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("create DeepSeek request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	response, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("call DeepSeek: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return fmt.Errorf("read DeepSeek response: %w", err)
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("DeepSeek returned HTTP %d", response.StatusCode)
	}
	var completion chatCompletionResponse
	if err := json.Unmarshal(body, &completion); err != nil {
		return fmt.Errorf("decode DeepSeek response envelope: %w", err)
	}
	if len(completion.Choices) == 0 || completion.Choices[0].FinishReason != "stop" {
		return errors.New("DeepSeek response was incomplete")
	}
	content := strings.TrimSpace(completion.Choices[0].Message.Content)
	if content == "" {
		return errors.New("DeepSeek returned empty JSON content")
	}
	decoder := json.NewDecoder(strings.NewReader(content))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(output); err != nil {
		return fmt.Errorf("decode DeepSeek JSON content: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return errors.New("DeepSeek returned trailing JSON content")
	}
	return nil
}

func validateAIPlan(plan *workoutPlan, maxMinutes int, allowedSlugs map[string]bool, knownLoads map[string]float64) (bool, error) {
	if plan.Title == "" || plan.SessionType == "" || plan.GoalSummary == "" || plan.CoachMessage == "" || plan.IntensityGuidance == "" {
		return false, errors.New("plan text fields are incomplete")
	}
	if len(plan.Title) > 80 || len(plan.GoalSummary) > 300 || len(plan.CoachMessage) > 300 || len(plan.IntensityGuidance) > 300 {
		return false, errors.New("plan text exceeds safety limits")
	}
	if plan.EstimatedMinutes < 5 || plan.EstimatedMinutes > maxMinutes {
		return false, errors.New("plan duration exceeds the available time")
	}
	if len(plan.Exercises) == 0 || len(plan.Exercises) > 8 {
		return false, errors.New("invalid exercise count")
	}
	repaired := false
	totalSets := 0
	plan.PlanID = "plan_" + randomToken(10)
	for index := range plan.Exercises {
		exercise := &plan.Exercises[index]
		if !allowedSlugs[exercise.ExerciseSlug] {
			return false, fmt.Errorf("exercise %q is not in the client catalog", exercise.ExerciseSlug)
		}
		if len(exercise.Cue) > 240 {
			return false, errors.New("exercise cue exceeds safety limits")
		}
		if exercise.Cue == "" {
			exercise.Cue = "动作稳定、全程可控；出现不适立即停止。"
			repaired = true
		}
		exercise.ItemID = fmt.Sprintf("item_%d", index+1)
		validBlockTypes := map[string]bool{"warmup": true, "strength": true, "core": true, "cardio": true, "cooldown": true}
		if !validBlockTypes[exercise.BlockType] {
			return false, errors.New("invalid exercise block type")
		}
		if exercise.Sets < 1 || exercise.Sets > 5 || exercise.TargetRIR < 0 || exercise.TargetRIR > 6 || exercise.RestSeconds < 0 || exercise.RestSeconds > 300 {
			return false, errors.New("exercise volume is outside safety limits")
		}
		if exercise.BlockType == "strength" && (exercise.RepsMin < 1 || exercise.RepsMax < exercise.RepsMin || exercise.RepsMax > 30) {
			return false, errors.New("strength repetition range is invalid")
		}
		if exercise.BlockType == "cardio" && (exercise.TargetDurationSeconds < 60 || exercise.TargetDurationSeconds > 3600) {
			return false, errors.New("cardio duration is invalid")
		}
		for _, alternative := range exercise.AlternativeSlugs {
			if !allowedSlugs[alternative] {
				return false, fmt.Errorf("alternative %q is not in the client catalog", alternative)
			}
		}
		if exercise.SuggestedLoadKG != nil {
			lastLoad, known := knownLoads[exercise.ExerciseSlug]
			if !known || *exercise.SuggestedLoadKG <= 0 {
				exercise.SuggestedLoadKG = nil
				exercise.LoadBasis = "explore"
				repaired = true
			} else if *exercise.SuggestedLoadKG > lastLoad {
				load := lastLoad
				exercise.SuggestedLoadKG = &load
				exercise.LoadBasis = "conservative_adjustment"
				repaired = true
			}
		}
		if exercise.OrderIndex != index {
			exercise.OrderIndex = index
			repaired = true
		}
		totalSets += exercise.Sets
	}
	if totalSets > 20 {
		return false, errors.New("total set count exceeds safety limits")
	}
	return repaired, nil
}

func validateAISummary(summary aiSummary, allowedFacts []string) error {
	if summary.Headline == "" || len(summary.Headline) > 160 || summary.FactualMessage == "" || len(summary.GroundedFacts) == 0 || len(summary.GroundedFacts) > 5 {
		return errors.New("summary fields are invalid")
	}
	allowed := make(map[string]bool, len(allowedFacts))
	for _, fact := range allowedFacts {
		allowed[fact] = true
	}
	if !allowed[summary.FactualMessage] {
		return errors.New("summary factual message is not grounded")
	}
	for _, fact := range summary.GroundedFacts {
		if !allowed[fact] {
			return errors.New("summary contains an ungrounded fact")
		}
	}
	return nil
}
