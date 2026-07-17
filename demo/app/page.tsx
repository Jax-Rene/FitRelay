"use client";

import { useEffect, useState } from "react";

type Screen = "onboarding" | "home" | "plan" | "workout" | "summary";

type ExerciseState = {
  load: string;
  reps: string;
  completedSets: number;
  targetSets: number;
  status: "pending" | "completed" | "skipped";
};

const exercises = [
  { name: "腿举", detail: "3 组 × 10–12 次", rest: "休息 90 秒", target: "建议 65 kg", cue: "腰臀贴紧靠背，膝盖与脚尖方向一致。", image: "https://wger.de/media/exercise-images/371/d2136f96-3a43-4d4c-9944-1919c4ca1ce1.webp.200x200_q85.png" },
  { name: "器械推胸", detail: "3 组 × 8–12 次", rest: "休息 90 秒", target: "从 30 kg 开始探索", cue: "肩胛保持稳定，推起时不要耸肩。", image: "https://wger.de/media/exercise-images/129/b263c968-e067-4750-916a-d8758a7df23e.webp.200x200_q85.jpg" },
  { name: "高位下拉", detail: "3 组 × 10–12 次", rest: "休息 90 秒", target: "建议 40 kg", cue: "拉向锁骨附近，避免身体大幅后仰。", image: "https://wger.de/media/exercise-images/158/0d51a0f2-622f-434b-beb8-1a003c54712a.png.200x200_q85.jpg" },
  { name: "坐姿腿弯举", detail: "2 组 × 10–15 次", rest: "休息 75 秒", target: "建议 25 kg", cue: "控制回程，不要让配重快速弹回。", image: "https://wger.de/media/exercise-images/117/seated-leg-curl-large-1.png.200x200_q85.jpg" },
  { name: "跑步机快走", detail: "15 分钟", rest: "可以说完整句子的强度", target: "坡度 5% · 5 km/h", cue: "保持自然步幅和稳定呼吸。", image: "https://wger.de/media/exercise-images/1615/7792295c-83b6-4ea8-9353-ce02f0ad2559.jpg.200x200_q85.jpg" },
];

export default function Home() {
  const [screen, setScreen] = useState<Screen>("onboarding");
  const [onboardingStep, setOnboardingStep] = useState(0);
  const [profile, setProfile] = useState({ sex: "男", birthYear: 1995, birthMonth: 7, birthDay: 12, height: 175, weight: 70, experience: "练过一阵", limitation: "暂无" });
  const [completedToday, setCompletedToday] = useState(false);
  const [inputMode, setInputMode] = useState<"voice" | "keyboard">("voice");
  const [listening, setListening] = useState(false);
  const [showTranscript, setShowTranscript] = useState(false);
  const [typedIntent, setTypedIntent] = useState("");
  const [setIndex, setSetIndex] = useState(1);
  const [currentExercise, setCurrentExercise] = useState(0);
  const [exerciseListOpen, setExerciseListOpen] = useState(false);
  const [resting, setResting] = useState(false);
  const [seconds, setSeconds] = useState(90);
  const [restDuration, setRestDuration] = useState(90);
  const [load, setLoad] = useState("65");
  const [reps, setReps] = useState("10");
  const [exerciseMenu, setExerciseMenu] = useState<number | null>(null);
  const [editingExercise, setEditingExercise] = useState(false);
  const [editLoad, setEditLoad] = useState(65);
  const [editSets, setEditSets] = useState(3);
  const [adjustPlan, setAdjustPlan] = useState(false);
  const [adjustListening, setAdjustListening] = useState(false);
  const [adjustResult, setAdjustResult] = useState(false);
  const [coachOpen, setCoachOpen] = useState(false);
  const [coachListening, setCoachListening] = useState(false);
  const [coachReply, setCoachReply] = useState(false);
  const [coachQuestion, setCoachQuestion] = useState("");
  const [planAdjusted, setPlanAdjusted] = useState(false);
  const [activeExerciseIds, setActiveExerciseIds] = useState([0, 1, 2, 3, 4]);
  const [paused, setPaused] = useState(false);
  const [introVoiceState, setIntroVoiceState] = useState<"idle" | "listening" | "recorded">("idle");
  const [exerciseStates, setExerciseStates] = useState<ExerciseState[]>([
    { load: "65", reps: "10", completedSets: 0, targetSets: 3, status: "pending" },
    { load: "30", reps: "10", completedSets: 0, targetSets: 3, status: "pending" },
    { load: "40", reps: "10", completedSets: 0, targetSets: 3, status: "pending" },
    { load: "25", reps: "12", completedSets: 0, targetSets: 2, status: "pending" },
    { load: "5", reps: "15", completedSets: 0, targetSets: 1, status: "pending" },
  ]);

  useEffect(() => {
    if (!resting || seconds <= 0) return;
    const timer = window.setInterval(() => setSeconds((value) => value - 1), 1000);
    return () => window.clearInterval(timer);
  }, [resting, seconds]);

  function startVoice() {
    setListening(true);
    window.setTimeout(() => {
      setListening(false);
      setShowTranscript(true);
    }, 900);
  }

  function submitTypedIntent() {
    if (!typedIntent.trim()) return;
    setShowTranscript(true);
  }

  function completeSet() {
    const exerciseId = activeExerciseIds[currentExercise];
    const targetSets = exerciseStates[exerciseId].targetSets;
    setExerciseStates((states) => states.map((state, index) => index === exerciseId ? { ...state, load, reps, completedSets: Math.max(state.completedSets, setIndex) } : state));
    if (setIndex >= targetSets) {
      setResting(false);
      setExerciseStates((states) => states.map((state, index) => index === exerciseId ? { ...state, status: "completed" } : state));
      goToNextExercise();
      return;
    }
    setResting(true);
    setSeconds(restDuration);
  }

  function switchExercise(nextPosition: number) {
    const currentId = activeExerciseIds[currentExercise];
    const nextId = activeExerciseIds[nextPosition];
    setExerciseStates((states) => states.map((state, index) => index === currentId ? { ...state, load, reps } : state));
    setCurrentExercise(nextPosition);
    setLoad(exerciseStates[nextId].load);
    setReps(exerciseStates[nextId].reps);
    setSetIndex(Math.min(exerciseStates[nextId].completedSets + 1, exerciseStates[nextId].targetSets));
    setResting(false);
    setRestDuration(nextId === 3 ? 75 : 90);
  }

  function goToNextExercise() {
    const next = activeExerciseIds.findIndex((id, position) => position > currentExercise && exerciseStates[id].status === "pending");
    if (next >= 0) switchExercise(next);
    else setExerciseListOpen(true);
  }

  function endCurrentExercise() {
    const exerciseId = activeExerciseIds[currentExercise];
    setExerciseStates((states) => states.map((state, index) => index === exerciseId ? { ...state, load, reps, status: state.completedSets > 0 ? "completed" : "skipped" } : state));
    const next = currentExercise < activeExerciseIds.length - 1 ? currentExercise + 1 : -1;
    if (next >= 0) switchExercise(next);
    else setExerciseListOpen(true);
  }

  function applyPlanAdjustment() {
    setPlanAdjusted(true);
    setActiveExerciseIds([0, 1, 2]);
    setCurrentExercise(0);
    setAdjustPlan(false);
  }

  const completedSets = exerciseStates.reduce((sum, state) => sum + state.completedSets, 0);
  const completedExercises = exerciseStates.filter((state) => state.status === "completed").length;
  const summaryMinutes = Math.max(8, completedSets * 4);
  const estimatedCalories = Math.round((profile.weight * summaryMinutes * 5.5 / 60) / 10) * 10;

  function finishRest() {
    setResting(false);
    setSetIndex((value) => Math.min(3, value + 1));
  }

  function listenForAdjustment() {
    setAdjustListening(true);
    window.setTimeout(() => {
      setAdjustListening(false);
      setAdjustResult(true);
    }, 900);
  }

  function askCoachByVoice() {
    setCoachListening(true);
    window.setTimeout(() => {
      setCoachListening(false);
      setCoachReply(true);
    }, 900);
  }

  function recordOptionalIntroduction() {
    setIntroVoiceState("listening");
    window.setTimeout(() => setIntroVoiceState("recorded"), 1100);
  }

  return (
    <main className="demo-shell">
      <section className="intro">
        <div className="brand"><img className="brand-mark" src="/logo.png" alt="随练 AI Logo" />随练 AI</div>
        <p className="eyebrow">STATIC PRODUCT DEMO · V0.1</p>
        <h1>你负责来，<br /><span>今天练什么交给我。</span></h1>
        <p className="intro-copy">不需要承诺每周练几次。到了健身房，说一句今天的状态，直接得到能执行的训练。</p>
        <div className="principles">
          <div><b>20 秒</b><span>老用户开练</span></div>
          <div><b>1 次</b><span>点击完成一组</span></div>
          <div><b>0 焦虑</b><span>没有断签补课</span></div>
        </div>
        <p className="demo-tip">在右侧手机中点击体验完整流程 →</p>
      </section>

      <section className="phone-wrap" aria-label="随练 AI 手机界面演示">
        <div className="phone">
          <div className="statusbar"><span>09:41</span><span>● ◔ ▰</span></div>

          {screen === "onboarding" && (
            <div className="screen onboarding-screen">
              <div className="onboarding-progress"><span style={{ width: `${((onboardingStep + 1) / 8) * 100}%` }}></span></div>
              {onboardingStep === 0 && <div className="onboarding-panel welcome-panel">
                <img className="onboarding-logo" src="/logo.png" alt="随练 AI Logo" />
                <p className="eyebrow">欢迎来到随练 AI</p>
                <h2>不用坚持打卡，<br />每次来都能练。</h2>
                <p>告诉我一点基础情况。以后到了健身房，只要说时间和状态，就能直接开练。</p>
                <div className="onboarding-value"><span><b>20 秒</b>生成今天的训练</span><span><b>1 句话</b>随时调整计划</span><span><b>每一组</b>都会被记住</span></div>
                <button className="primary" onClick={() => setOnboardingStep(1)}>开始设置 <span>→</span></button>
              </div>}
              {onboardingStep === 1 && <div className="onboarding-panel">
                <p className="eyebrow">1 / 7 · 性别</p>
                <h2>怎么称呼你的<br />身体数据？</h2>
                <p>用于估算基础消耗和推荐强度，不影响你选择任何训练内容。</p>
                <div className="single-choice">{["男", "女"].map((sex) => <button className={profile.sex === sex ? "selected" : ""} key={sex} onClick={() => setProfile({ ...profile, sex })}><span>{sex}</span><i>✓</i></button>)}</div>
                <button className="primary onboarding-next" onClick={() => setOnboardingStep(2)}>继续 <span>→</span></button>
              </div>}
              {onboardingStep === 2 && <div className="onboarding-panel">
                <p className="eyebrow">2 / 7 · 生日</p>
                <h2>你的生日是？</h2>
                <p>年龄会影响训练恢复和强度建议。生日仅用于个性化计算。</p>
                <div className="birthday-picker">
                  <label><span>年份</span><select aria-label="出生年份" value={profile.birthYear} onChange={(event) => setProfile({ ...profile, birthYear: Number(event.target.value) })}>{Array.from({ length: 73 }, (_, index) => 2008 - index).map((year) => <option key={year}>{year}</option>)}</select></label>
                  <label><span>月份</span><select aria-label="出生月份" value={profile.birthMonth} onChange={(event) => setProfile({ ...profile, birthMonth: Number(event.target.value) })}>{Array.from({ length: 12 }, (_, index) => index + 1).map((month) => <option key={month}>{month}</option>)}</select></label>
                  <label><span>日期</span><select aria-label="出生日期" value={profile.birthDay} onChange={(event) => setProfile({ ...profile, birthDay: Number(event.target.value) })}>{Array.from({ length: 31 }, (_, index) => index + 1).map((day) => <option key={day}>{day}</option>)}</select></label>
                </div>
                <div className="profile-preview"><span>当前年龄</span><b>{2026 - profile.birthYear} 岁</b></div>
                <button className="primary onboarding-next" onClick={() => setOnboardingStep(3)}>继续 <span>→</span></button>
              </div>}
              {onboardingStep === 3 && <div className="onboarding-panel">
                <p className="eyebrow">3 / 7 · 身高</p>
                <h2>你的身高是？</h2>
                <p>和体重一起用于估算动作起点，之后可以在个人资料里修改。</p>
                <div className="single-stepper"><button aria-label="身高减少 1 厘米" onClick={() => setProfile({ ...profile, height: Math.max(120, profile.height - 1) })}>−</button><b>{profile.height}<small>cm</small></b><button aria-label="身高增加 1 厘米" onClick={() => setProfile({ ...profile, height: Math.min(220, profile.height + 1) })}>＋</button></div>
                <button className="primary onboarding-next" onClick={() => setOnboardingStep(4)}>继续 <span>→</span></button>
              </div>}
              {onboardingStep === 4 && <div className="onboarding-panel">
                <p className="eyebrow">4 / 7 · 体重</p>
                <h2>你的体重是？</h2>
                <p>用于估算动作负荷与训练消耗，不会公开展示。</p>
                <div className="single-stepper"><button aria-label="体重减少 1 千克" onClick={() => setProfile({ ...profile, weight: Math.max(35, profile.weight - 1) })}>−</button><b>{profile.weight}<small>kg</small></b><button aria-label="体重增加 1 千克" onClick={() => setProfile({ ...profile, weight: Math.min(200, profile.weight + 1) })}>＋</button></div>
                <button className="primary onboarding-next" onClick={() => setOnboardingStep(5)}>继续 <span>→</span></button>
              </div>}
              {onboardingStep === 5 && <div className="onboarding-panel">
                <p className="eyebrow">5 / 7 · 训练经验</p>
                <h2>今天从合适的<br />起点开始。</h2>
                <p>不做测试，也不要求你承诺每周练几次。</p>
                <div className="choice-group"><span>你的训练经验</span>{["刚开始", "练过一阵", "比较熟悉"].map((value) => <button className={profile.experience === value ? "selected" : ""} key={value} onClick={() => setProfile({ ...profile, experience: value })}><b>{value}</b><small>{value === "刚开始" ? "需要更多动作提示" : value === "练过一阵" ? "知道常见动作和器械" : "可以自主判断训练强度"}</small><i>✓</i></button>)}</div>
                <button className="primary onboarding-next" onClick={() => setOnboardingStep(6)}>继续 <span>→</span></button>
              </div>}
              {onboardingStep === 6 && <div className="onboarding-panel">
                <p className="eyebrow">6 / 7 · 身体限制</p>
                <h2>有需要避开的<br />部位吗？</h2>
                <p>我们会优先避开容易引起不适的动作，你也可以选择暂无。</p>
                <div className="choice-group compact"><span>需要避开的部位</span>{["暂无", "膝盖", "腰背", "肩颈"].map((value) => <button className={profile.limitation === value ? "selected" : ""} key={value} onClick={() => setProfile({ ...profile, limitation: value })}>{value}</button>)}</div>
                <p className="safety-note">身体不适或处于康复期时，请先咨询医生或康复师。</p>
                <button className="primary onboarding-next" onClick={() => setOnboardingStep(7)}>继续 <span>→</span></button>
              </div>}
              {onboardingStep === 7 && <div className="onboarding-panel optional-voice-panel">
                <p className="eyebrow">7 / 7 · 可选</p>
                <h2>还有什么想让<br />我了解的吗？</h2>
                <p>可以简单介绍训练目标、喜欢或不喜欢的动作。以后生成计划时会参考。</p>
                {introVoiceState !== "recorded" ? <button className={`intro-voice-button ${introVoiceState === "listening" ? "listening" : ""}`} onClick={recordOptionalIntroduction}>
                  <span className="intro-voice-orb"><i></i><i></i><i></i></span>
                  <b>{introVoiceState === "listening" ? "正在听…" : "按住说话"}</b>
                  <small>{introVoiceState === "listening" ? "松开后会整理成文字" : "例如：想增肌，不喜欢跑步"}</small>
                </button> : <div className="intro-transcript">
                  <div><span>✓ 已记录</span><button onClick={() => setIntroVoiceState("idle")}>重录</button></div>
                  <p>我主要想增肌，比较喜欢器械训练，不太喜欢跑步。平时一周大概能来两次。</p>
                  <div className="chips"><span>增肌</span><span>偏好器械</span><span>不喜欢跑步</span></div>
                </div>}
                <div className="optional-hint">这一步可以跳过，不影响生成训练计划。</div>
                <button className="primary onboarding-next" onClick={() => setScreen("home")}>{introVoiceState === "recorded" ? "保存并开始训练" : "跳过，开始训练"} <span>→</span></button>
              </div>}
              {onboardingStep > 0 && <button className="onboarding-back" onClick={() => setOnboardingStep((step) => step - 1)}>‹ 返回</button>}
            </div>
          )}

          {screen === "home" && (
            <div className="screen home-screen">
              <header className="app-header">
                <div>
                  <p className="muted">7 月 12 日 · 周日</p>
                  <p className="weather-line"><span>上海 · 徐汇</span><span>☀ 晴 31°C</span><span>湿度 62%</span></p>
                  <h2>{completedToday ? "今天练得不错。" : "今天怎么练？"}</h2>
                </div>
                <button className="avatar" aria-label="个人资料">堂</button>
              </header>

              {completedToday ? (
                <button className="today-workout-card" onClick={() => setScreen("summary")}>
                  <div className="today-workout-top"><span className="today-check">✓</span><span><small>今日训练已完成</small><strong>恢复型全身训练</strong></span><b>›</b></div>
                  <div className="today-workout-stats"><span><b>{summaryMinutes}</b>分钟</span><span><b>{completedSets}</b>有效组</span><span><b>{estimatedCalories}</b>估算千卡</span></div>
                  <p>主要肌群已经重新覆盖，点击查看今天的训练总结。</p>
                </button>
              ) : <>
              {inputMode === "voice" ? (
                <div className={`original-voice-card ${listening ? "listening" : ""}`}>
                  <button className="original-voice-main" onClick={startVoice}>
                    <span className="original-voice-orb"><i></i><i></i><i></i></span>
                    <strong>{listening ? "正在听…" : "按住说今天怎么练"}</strong>
                    <small>{listening ? "例如：今天四十分钟，不想练腿" : "说时间、状态和想练的内容"}</small>
                  </button>
                  <button className="original-keyboard" onClick={() => { setInputMode("keyboard"); setShowTranscript(false); }}>键盘输入 →</button>
                </div>
              ) : (
                <div className="keyboard-card">
                  <button className="inline-input-toggle keyboard-toggle" onClick={() => { setInputMode("voice"); setShowTranscript(false); }}>◉ 改用语音</button>
                  <textarea
                    value={typedIntent}
                    onChange={(event) => setTypedIntent(event.target.value)}
                    placeholder="例如：今天只有四十分钟，状态一般，不想练腿。"
                    autoFocus
                  />
                  <div><span>{typedIntent.length}/200</span><button onClick={submitTypedIntent} disabled={!typedIntent.trim()}>理解我的输入 →</button></div>
                </div>
              )}

              {showTranscript && (
                <div className="transcript-card">
                  <div className="transcript-top"><span>已理解</span><button onClick={() => setShowTranscript(false)}>修改</button></div>
                  <p>{inputMode === "keyboard" && typedIntent.trim() ? typedIntent : "一周没练，今天有 70 分钟。状态还行，想练全身再做一点有氧。"}</p>
                  <div className="chips"><span>70 分钟</span><span>全身</span><span>短有氧</span></div>
                  <button className="primary" onClick={() => setScreen("plan")}>生成今天的计划 <span>→</span></button>
                </div>
              )}

              {!showTranscript && (
                <button className="reuse-card" onClick={() => setScreen("plan")}>
                  <span className="reuse-icon">↻</span>
                  <span><small>沿用上次的训练意图</small><strong>60 分钟 · 全身力量 + 短有氧</strong></span>
                  <b>›</b>
                </button>
              )}
              </>}

              <div className="last-session">
                <div className="section-title"><h3>{completedToday ? "更早的训练" : "上一次训练"}</h3><button>查看历史</button></div>
                <div className="session-row"><div className="date-box"><b>05</b><span>7 月</span></div><div><strong>全身力量 · 62 分钟</strong><p>15 个有效组 · 4 个主要肌群</p></div></div>
                <div className="fact"><span>↗</span><p>高位下拉在相同重量下，<b>比上次多完成 3 次</b></p></div>
              </div>
            </div>
          )}

          {screen === "plan" && (
            <div className="screen plan-screen">
              <header className="simple-header"><button onClick={() => setScreen("home")}>‹</button><span>今日计划</span><span className="header-spacer"></span></header>
              <div className="plan-hero">
                <p className="eyebrow">恢复型全身训练</p>
                <h2>找回节奏，<br />今天不追重量。</h2>
                <p>一周没练，今天每组保留约 3 次余力。完成主要动作后再做短有氧就足够有效。</p>
                <div className="target-summary"><small>{planAdjusted ? "已按你的要求调整" : "本次目标"}</small><div><span><b>{planAdjusted ? 30 : 68}</b>预计分钟</span><span><b>{planAdjusted ? 9 : 11}</b>力量组</span><span><b>{planAdjusted ? 0 : 15}</b>有氧分钟</span></div></div>
              </div>
              <div className="exercise-list">
                {activeExerciseIds.map((exerciseId, index) => {
                  const exercise = exercises[exerciseId];
                  return <div className="exercise-row" key={exercise.name}>
                    <div className="exercise-image"><img src={exercise.image} alt={`${exercise.name}动作示例`} /></div>
                    <div><span className="exercise-order">{index + 1}</span><strong>{exercise.name}</strong><p>{exercise.detail} · {exercise.rest}</p><small>{exercise.target}</small></div>
                    <button aria-label={`调整${exercise.name}`} onClick={() => { setExerciseMenu(exerciseId); setEditingExercise(false); setEditLoad(Number(exerciseStates[exerciseId].load)); setEditSets(exerciseStates[exerciseId].targetSets); }}>•••</button>
                  </div>
                })}
                <p className="asset-credit">动作示例图来自 wger 开源动作库 · CC / CC0</p>
              </div>
              <div className="sticky-action plan-actions"><button className="adjust-plan-button" onClick={() => { setAdjustPlan(true); setAdjustResult(false); }}>≋ 调整计划</button><button className="primary" onClick={() => setScreen("workout")}>开始训练 <span>→</span></button></div>

              {exerciseMenu !== null && (
                <div className="sheet-backdrop" onClick={() => setExerciseMenu(null)}>
                  <div className="bottom-sheet" onClick={(event) => event.stopPropagation()}>
                    <div className="sheet-handle"></div>
                    <div className="sheet-exercise"><img src={exercises[exerciseMenu].image} alt="" /><div><small>调整动作 {exerciseMenu + 1}</small><h3>{exercises[exerciseMenu].name}</h3></div></div>
                    {!editingExercise ? <>
                      <button onClick={() => setExerciseMenu(null)}><span>↻</span><div><b>替换动作</b><small>换成相同肌群的动作</small></div><strong>›</strong></button>
                      <button onClick={() => setEditingExercise(true)}><span>±</span><div><b>调整重量或组数</b><small>只修改这个动作</small></div><strong>›</strong></button>
                      <button className="danger" onClick={() => setExerciseMenu(null)}><span>×</span><div><b>从计划中移除</b><small>其余动作保持不变</small></div><strong>›</strong></button>
                      <button className="sheet-cancel" onClick={() => setExerciseMenu(null)}>取消</button>
                    </> : <div className="exercise-editor">
                      <label><span>建议重量</span><div><button onClick={() => setEditLoad(Math.max(0, editLoad - 5))}>−</button><b>{editLoad} <small>kg</small></b><button onClick={() => setEditLoad(editLoad + 5)}>＋</button></div></label>
                      <label><span>训练组数</span><div><button onClick={() => setEditSets(Math.max(1, editSets - 1))}>−</button><b>{editSets} <small>组</small></b><button onClick={() => setEditSets(Math.min(10, editSets + 1))}>＋</button></div></label>
                      <div className="editor-actions"><button onClick={() => setEditingExercise(false)}>返回</button><button onClick={() => { const id = exerciseMenu; setExerciseStates((states) => states.map((state, index) => index === id ? { ...state, load: String(editLoad), targetSets: editSets } : state)); setEditingExercise(false); setExerciseMenu(null); }}>保存修改</button></div>
                    </div>}
                  </div>
                </div>
              )}

              {adjustPlan && (
                <div className="sheet-backdrop" onClick={() => setAdjustPlan(false)}>
                  <div className="bottom-sheet adjust-sheet" onClick={(event) => event.stopPropagation()}>
                    <div className="sheet-handle"></div>
                    <small className="sheet-kicker">调整今天剩下的计划</small>
                    <h3>直接说哪里需要变</h3>
                    {!adjustResult ? <>
                      <button className={`adjust-voice ${adjustListening ? "active" : ""}`} onClick={listenForAdjustment}><span className="voice-orb small"><i></i><i></i><i></i></span><b>{adjustListening ? "正在听…" : "按住说出变化"}</b><small>例如：临时只剩 30 分钟</small></button>
                      <div className="adjust-presets"><button onClick={() => setAdjustResult(true)}>轻松一点</button><button onClick={() => setAdjustResult(true)}>缩短时间</button><button onClick={() => setAdjustResult(true)}>取消有氧</button></div>
                    </> : <div className="adjust-understood"><span>✓ 已理解</span><p>把总时长缩短到 30 分钟，保留腿举、推胸和高位下拉，取消有氧。</p><div><button onClick={() => setAdjustResult(false)}>重新说</button><button onClick={applyPlanAdjustment}>应用调整</button></div></div>}
                  </div>
                </div>
              )}
            </div>
          )}

          {screen === "workout" && (
            <div className="screen workout-screen">
              <header className="simple-header"><button onClick={() => setScreen("plan")}>‹</button><span>{paused ? "训练已暂停" : "训练中 · 03:42"}</span><button onClick={() => setPaused(!paused)}>{paused ? "继续" : "暂停"}</button></header>
              <div className="progress"><span style={{ width: `${setIndex * 11}%` }}></span></div>
              <div className="workout-step-line"><p className="muted step-label">动作 {currentExercise + 1} / {activeExerciseIds.length}</p><button onClick={() => setExerciseListOpen(true)}>全部动作 ≡</button></div>
              <div className="active-exercise-hero"><img src={exercises[activeExerciseIds[currentExercise]].image} alt={`${exercises[activeExerciseIds[currentExercise]].name}动作示例`} /><div><h2>{exercises[activeExerciseIds[currentExercise]].name}</h2><p className="cue">{exercises[activeExerciseIds[currentExercise]].cue}</p></div></div>
              <div className="set-pills">{Array.from({ length: exerciseStates[activeExerciseIds[currentExercise]].targetSets }, (_, index) => index + 1).map((set) => <span key={set} className={set <= exerciseStates[activeExerciseIds[currentExercise]].completedSets ? "done" : set === setIndex ? "current" : ""}>{set <= exerciseStates[activeExerciseIds[currentExercise]].completedSets ? "✓" : set}</span>)}</div>
              <div className="target-row"><span>第 {setIndex} 组，共 {exerciseStates[activeExerciseIds[currentExercise]].targetSets} 组</span></div>
              <div className="rest-setting"><span>组间休息</span><div><button aria-label="休息时间减少 15 秒" onClick={() => setRestDuration(Math.max(15, restDuration - 15))}>−</button><b>{restDuration} 秒</b><button aria-label="休息时间增加 15 秒" onClick={() => setRestDuration(Math.min(300, restDuration + 15))}>＋</button></div></div>
              <div className="inputs">
                <label><span>重量</span><div><button aria-label="重量减少 5 千克" onClick={() => setLoad(String(Math.max(0, Number(load) - 5)))}>−</button><input aria-label="本组重量" value={load} onChange={(event) => setLoad(event.target.value)} /><b>kg</b><button aria-label="重量增加 5 千克" onClick={() => setLoad(String(Number(load) + 5))}>＋</button></div></label>
                <label><span>次数</span><div><button aria-label="次数减少 1 次" onClick={() => setReps(String(Math.max(0, Number(reps) - 1)))}>−</button><input aria-label="本组次数" value={reps} onChange={(event) => setReps(event.target.value)} /><b>次</b><button aria-label="次数增加 1 次" onClick={() => setReps(String(Number(reps) + 1))}>＋</button></div></label>
              </div>
              {resting ? (
                <div className="rest-card"><div><span>休息中</span><strong>{String(Math.floor(seconds / 60)).padStart(2, "0")}:{String(seconds % 60).padStart(2, "0")}</strong></div><div className="rest-actions"><button onClick={() => setSeconds(Math.max(0, seconds - 15))}>−15</button><button onClick={() => setSeconds(seconds + 15)}>＋15</button><button onClick={finishRest}>跳过</button></div></div>
              ) : (
                <button className="complete-button" onClick={completeSet}>✓ 完成本组</button>
              )}
              <div className="workout-tools"><button onClick={() => setExerciseListOpen(true)}>替换动作</button><button onClick={() => { const id = activeExerciseIds[currentExercise]; setExerciseStates((states) => states.map((state, index) => index === id ? { ...state, targetSets: Math.max(setIndex, state.targetSets - 1) } : state)); }}>减少一组</button><button onClick={endCurrentExercise}>结束动作</button></div>
              <button className="coach-dock" aria-label="问随练 AI" onClick={() => { setCoachOpen(true); setCoachReply(false); }}><span className="coach-label">问随练 AI</span><span className="coach-avatar"><i></i><i></i><i></i></span><span className="coach-notice"></span></button>

              {exerciseListOpen && (
                <div className="sheet-backdrop" onClick={() => setExerciseListOpen(false)}>
                  <div className="bottom-sheet workout-list-sheet" onClick={(event) => event.stopPropagation()}>
                    <div className="sheet-handle"></div>
                    <div className="workout-list-title"><div><small>今天的训练</small><h3>全部动作</h3></div><span>{completedExercises} 个已完成</span></div>
                    <div className="workout-list-items">{activeExerciseIds.map((exerciseId, index) => { const exercise = exercises[exerciseId]; const state = exerciseStates[exerciseId]; return <button className={index === currentExercise ? "current" : ""} key={exercise.name} onClick={() => { switchExercise(index); setExerciseListOpen(false); }}><img src={exercise.image} alt="" /><span className={`list-order ${state.status}`}>{state.status === "completed" ? "✓" : state.status === "skipped" ? "—" : index + 1}</span><div><b>{exercise.name}</b><small>{state.completedSets}/{state.targetSets} 组完成 · {state.load} kg</small></div><strong>{index === currentExercise ? "当前" : state.status === "completed" ? "已完成" : "去做"}</strong></button> })}</div>
                    <button className="end-workout-button" onClick={() => { setExerciseListOpen(false); setScreen("summary"); }}>结束本次训练</button>
                  </div>
                </div>
              )}

              {coachOpen && (
                <div className="sheet-backdrop" onClick={() => setCoachOpen(false)}>
                  <div className="bottom-sheet coach-sheet" onClick={(event) => event.stopPropagation()}>
                    <div className="sheet-handle"></div>
                    <div className="coach-sheet-title"><span className="coach-avatar"><i></i><i></i><i></i></span><div><small>随练 AI · 了解当前训练</small><h3>现在需要什么帮助？</h3></div></div>
                    {!coachReply ? <>
                      <div className="coach-suggestions"><button onClick={() => setCoachReply(true)}>这组感觉太重</button><button onClick={() => setCoachReply(true)}>这个动作怎么发力？</button><button onClick={() => setCoachReply(true)}>帮我换个动作</button></div>
                      <div className="coach-composer"><input value={coachQuestion} onChange={(event) => setCoachQuestion(event.target.value)} placeholder="问健身问题或说出调整…" /><button className={coachListening ? "listening" : ""} onClick={askCoachByVoice}>{coachListening ? "◉" : "⌁"}</button><button onClick={() => setCoachReply(true)} disabled={!coachQuestion.trim()}>↑</button></div>
                    </> : <div className="coach-answer"><p>如果这一组已经明显偏重，先把重量从 65 kg 降到 60 kg，仍以动作稳定、完成 10 次为目标。</p><div><button onClick={() => setCoachReply(false)}>继续问</button><button onClick={() => setCoachOpen(false)}>应用到下一组</button></div></div>}
                  </div>
                </div>
              )}
            </div>
          )}

          {screen === "summary" && (
            <div className="screen summary-screen">
              <div className="summary-mark">✓</div>
              <p className="eyebrow">今天完成了</p>
              <h2>{completedSets > 0 ? <>一次有效的<br />恢复训练。</> : <>今天先到这里，<br />也算一次记录。</>}</h2>
              <div className="summary-stats"><div><b>{summaryMinutes}</b><span>分钟</span></div><div><b>{completedSets}</b><span>有效组</span></div><div><b>{completedExercises}</b><span>完成动作</span></div><div><b>{estimatedCalories}</b><span>估算千卡</span></div></div>
              <div className="insight-card"><span>↗</span><div><small>{completedSets > 0 ? "本次真实记录" : "保持诚实"}</small><p>{completedSets > 0 ? <>你实际完成了 <b>{completedSets} 组</b>，下次会从本次重量和次数继续。</> : <>没有虚构完成数据，随时可以重新开始一次训练。</>}</p></div></div>
              <p className="coach-note">总结只统计本次实际完成的动作与组数。热量消耗根据体重、有效时长和训练类型估算。</p>
              <div className="coverage body-coverage"><div className="section-title"><h3>肌群覆盖</h3><span>颜色越深，本次刺激越多</span></div><div className="body-map"><div><span className="muscle-stack"><img className="body-base" src="https://wger.de/static/images/muscles/muscular_system_front.svg" alt="完整身体正面肌群" /><img className="muscle-layer high" src="https://wger.de/static/images/muscles/main/muscle-10.b1445ea1acf6.svg" alt="" /><img className="muscle-layer mid" src="https://wger.de/static/images/muscles/main/muscle-4.c9fa9a228bc8.svg" alt="" /><img className="muscle-layer low" src="https://wger.de/static/images/muscles/main/muscle-6.592f938fa8c7.svg" alt="" /></span><small>正面</small></div><div><span className="muscle-stack"><img className="body-base" src="https://wger.de/static/images/muscles/muscular_system_back.svg" alt="完整身体背面肌群" /><img className="muscle-layer high" src="https://wger.de/static/images/muscles/main/muscle-12.6a5de7a0e373.svg" alt="" /><img className="muscle-layer mid" src="https://wger.de/static/images/muscles/main/muscle-11.54ef31755917.svg" alt="" /></span><small>背面</small></div><ul><li><i className="level high"></i><span>腿部</span><b>84%</b></li><li><i className="level high"></i><span>背部</span><b>76%</b></li><li><i className="level mid"></i><span>胸部</span><b>65%</b></li><li><i className="level low"></i><span>核心</span><b>38%</b></li></ul></div></div>
              <button className="primary" onClick={() => { setCompletedToday(true); setScreen("home"); setShowTranscript(false); setSetIndex(1); }}>完成，回到首页</button>
            </div>
          )}

          <div className="home-indicator"></div>
        </div>
      </section>
    </main>
  );
}
