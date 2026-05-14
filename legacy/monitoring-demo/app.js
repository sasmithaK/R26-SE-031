// ── Elements ────────────────────────────────────────────────────────────────
const video               = document.getElementById('webcam');
const logConsole          = document.getElementById('log-console');
const targetWord          = document.getElementById('target-word');
const optionsContainer    = document.getElementById('options-container');
const interventionOverlay = document.getElementById('intervention-overlay');
const interventionTitle   = document.getElementById('intervention-title');
const interventionDesc    = document.getElementById('intervention-desc');
const confusionHint       = document.getElementById('confusion-hint');

// C4 elements
const c4Cards = {
    LONG_WORD:            document.getElementById('c4-long-word'),
    VOWEL_CONFUSION:      document.getElementById('c4-vowel'),
    CONSONANT_CONFUSION:  document.getElementById('c4-consonant'),
    UNFAMILIAR:           document.getElementById('c4-unfamiliar'),
};
const c4Confs = {
    LONG_WORD:            document.getElementById('c4-conf-lw'),
    VOWEL_CONFUSION:      document.getElementById('c4-conf-vc'),
    CONSONANT_CONFUSION:  document.getElementById('c4-conf-cc'),
    UNFAMILIAR:           document.getElementById('c4-conf-uf'),
};
const c4Winner  = document.getElementById('c4-winner');
const werValue  = document.getElementById('wer-value');

// ── Constants ────────────────────────────────────────────────────────────────
const STUDENT_ID = "STU_DEMO_01";
const C1_BASE    = "http://localhost:8001/api/v1";  // monitoring-service-v2
const C2_BASE    = "http://localhost:8002/api/v1";  // visual-service-v2
const C4_BASE    = "http://localhost:8004/api/v1";  // intervention-service-v2

// ── UCSC Confusion Map (De Silva et al. 2025) ────────────────────────────────
// Each target Sinhala letter mapped to its empirically validated confusables.
const UCSC_CONFUSION = {
    'ග': { romanization: 'ga',  confusables: ['ල', 'ය'], options: ['ga', 'la', 'ya', 'da'] },
    'ල': { romanization: 'la',  confusables: ['ළ', 'ය'], options: ['la', 'ya', 'ra', 'ga'] },
    'ය': { romanization: 'ya',  confusables: ['ග', 'ල'], options: ['ya', 'ga', 'la', 'na'] },
    'ට': { romanization: 'ṭa', confusables: ['ත', 'ද'], options: ['ṭa', 'ta', 'da', 'ka'] },
    'ක': { romanization: 'ka',  confusables: ['ග', 'ඒ'], options: ['ka', 'ga', 'ee', 'pa'] },
    'ප': { romanization: 'pa',  confusables: ['බ', 'ඵ'], options: ['pa', 'ba', 'pha', 'ma'] },
};

const UCSC_TARGETS = Object.keys(UCSC_CONFUSION);

// Build syllabus from confusion map
const syllabus = UCSC_TARGETS.map(letter => ({
    target:  letter,
    correct: UCSC_CONFUSION[letter].romanization,
    options: UCSC_CONFUSION[letter].options,
    confusables: UCSC_CONFUSION[letter].confusables,
}));

// ── Game State ───────────────────────────────────────────────────────────────
let currentQuestionTime = Date.now();
let errorCount          = 0;
let lastMouseX = 0, lastMouseY = 0;
let totalDistance       = 0;
let currentQuestionIdx  = 0;
let sessionErrorCount   = 0;
let sessionAnswerCount  = 0;
let sessionStartTime    = Date.now();
let currentArm          = null;

// ── Service Health Checks ────────────────────────────────────────────────────
async function checkService(url, dotId, lblId, label) {
    const dot = document.getElementById(dotId);
    const lbl = document.getElementById(lblId);
    try {
        const r = await fetch(`${url}/health`, { signal: AbortSignal.timeout(3000) });
        const ok = r.ok;
        dot.className = `status-dot ${ok ? 'online' : 'offline'}`;
        if (lbl) lbl.textContent = `${label} ${ok ? '✓' : '✗'}`;
        return ok;
    } catch {
        dot.className = 'status-dot offline';
        if (lbl) lbl.textContent = `${label} ✗`;
        return false;
    }
}

async function initServiceChecks() {
    const [c1Ok, c2Ok, c4Ok] = await Promise.all([
        checkService(C1_BASE, 'dot-c1', 'lbl-c1', 'C1 Monitoring'),
        checkService(C2_BASE, 'dot-c2', 'lbl-c2', 'C2 Visual'),
        checkService(C4_BASE, 'dot-c4', 'lbl-c4', 'C4 Intervention'),
    ]);

    // Whisper WER proxy: check via C1 /health which reports feature availability
    // SinBERT: check via C4 /classifier/status
    await checkWhisperStatus(c1Ok);
    await checkSinBERTStatus(c4Ok);
}

async function checkWhisperStatus(c1Reachable) {
    const dot = document.getElementById('dot-whisper');
    if (!c1Reachable) { dot.className = 'status-dot offline'; return; }
    try {
        const r = await fetch(`${C1_BASE}/health`);
        const d = await r.json();
        // monitoring-service-v2 /health → {status, service, models_loaded}
        // Whisper is loaded when models_loaded is true (it's bundled into C1 feature extraction)
        const ok = d.status === 'ok';
        dot.className = `status-dot ${ok ? 'online' : 'offline'}`;
        logMsg(`[health] Whisper WER proxy (via C1): ${ok ? 'available' : 'degraded'}`, ok ? 'success' : 'warning');
    } catch {
        dot.className = 'status-dot offline';
    }
}

async function checkSinBERTStatus(c4Reachable) {
    const dot = document.getElementById('dot-sinbert');
    if (!c4Reachable) { dot.className = 'status-dot offline'; return; }
    try {
        const r = await fetch(`${C4_BASE}/intervention/error_classifier/status`);
        const d = await r.json();
        const loaded = d.model_loaded ?? false;
        dot.className = `status-dot ${loaded ? 'online' : 'offline'}`;
        logMsg(`[health] SinBERT (keshan3252/sinbert): ${loaded ? 'loaded ✓' : 'not loaded – rule-based fallback active'}`,
               loaded ? 'success' : 'warning');
    } catch {
        dot.className = 'status-dot offline';
    }
}

// ── Webcam ───────────────────────────────────────────────────────────────────
async function initCamera() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: true });
        video.srcObject = stream;
        logMsg("Webcam access granted. Observational monitoring active.", "success");
    } catch (err) {
        logMsg(`Webcam unavailable: ${err.message}`, "warning");
    }
}

// ── Mouse tracking for swipe_velocity ────────────────────────────────────────
document.getElementById('game-area').addEventListener('mousemove', (e) => {
    const dx = e.clientX - lastMouseX;
    const dy = e.clientY - lastMouseY;
    totalDistance += Math.sqrt(dx * dx + dy * dy);
    lastMouseX = e.clientX;
    lastMouseY = e.clientY;
});

// ── Game ─────────────────────────────────────────────────────────────────────
function loadQuestion() {
    const q = syllabus[currentQuestionIdx];
    targetWord.textContent = q.target;

    // Show which letters this one is easily confused with (UCSC note)
    confusionHint.textContent =
        `UCSC confusion pair: ${q.target} ↔ ${q.confusables.join(', ')}`;

    optionsContainer.innerHTML = '';
    const shuffled = [...q.options].sort(() => Math.random() - 0.5);
    shuffled.forEach(opt => {
        const btn = document.createElement('button');
        btn.className = 'option-btn';
        btn.textContent = opt;
        btn.onclick = () => checkAnswer(opt, btn, q.correct, q.target);
        optionsContainer.appendChild(btn);
    });

    currentQuestionTime = Date.now();
    totalDistance       = 0;
    errorCount          = 0;
}

async function checkAnswer(selected, btnElement, correct, letter) {
    const now           = Date.now();
    const hesitationMs  = now - currentQuestionTime;
    const velocity      = totalDistance / Math.max(hesitationMs / 1000, 0.001);
    const isCorrect     = selected === correct;

    if (isCorrect) {
        btnElement.style.backgroundColor = 'var(--success)';
        btnElement.style.color = 'white';
        sessionAnswerCount++;
        await sendTelemetry(hesitationMs, velocity, errorCount, letter);
        setTimeout(() => {
            currentQuestionIdx = (currentQuestionIdx + 1) % syllabus.length;
            loadQuestion();
        }, 800);
    } else {
        btnElement.style.backgroundColor = 'var(--danger)';
        btnElement.style.color = 'white';
        errorCount++;
        sessionErrorCount++;
        logMsg(`Incorrect! '${selected}' ≠ '${correct}' for ${letter}. Errors this round: ${errorCount}`, "warning");
    }
}

// ── C1 Telemetry ─────────────────────────────────────────────────────────────
async function sendTelemetry(hesitation_ms, velocity, errors, letter) {
    const sessionElapsedMs = Date.now() - sessionStartTime;
    const correctionRate   = sessionAnswerCount > 0
        ? Math.max(0, (sessionAnswerCount - sessionErrorCount) / sessionAnswerCount)
        : 1.0;

    // Simulate read-aloud pause (not tracked in demo, realistic mock)
    const readAloudPauseMs = Math.floor(hesitation_ms * 0.4);

    // Build context sentence for SinBERT (C4)
    const contextSentence = `Student attempted to read "${letter}" (${UCSC_CONFUSION[letter]?.romanization ?? '?'})`;

    // Simulate a Whisper WER proxy value (0.0–1.0)
    // In production this comes from audio_base64 decoded by C1
    const simulatedWer = parseFloat((0.15 + (errors * 0.12)).toFixed(2));

    const payload = {
        student_id:           STUDENT_ID,
        task_id:              `letter_match_${letter}`,
        session_id:           `SESSION_DEMO_${Math.floor(sessionStartTime / 1000)}`,
        hesitation_ms:        Math.floor(hesitation_ms),
        swipe_velocity:       parseFloat(velocity.toFixed(2)),
        correction_rate:      parseFloat(correctionRate.toFixed(3)),
        session_latency_ms:   Math.floor(sessionElapsedMs),
        read_aloud_pause_ms:  readAloudPauseMs,
        disfluency_count:     errors,
        syllable_rate:        parseFloat((3.5 - errors * 0.3).toFixed(2)),
        touch_events:         [{ x: 150, y: 300, pressure: 0.6, timestamp_ms: Date.now() }],
        event_type:           errors > 0 ? 'TAP' : 'TAP',
        // whisper_wer_proxy sent separately via audio_base64 — we log it locally
        audio_base64:         null,
    };

    logMsg(`[C1→] letter=${letter}  hesitation=${hesitation_ms}ms  errors=${errors}  vel=${velocity.toFixed(1)}px/s`, "info");

    try {
        const r = await fetch(`${C1_BASE}/telemetry`, {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify(payload),
        });

        if (!r.ok) {
            const err = await r.text();
            logMsg(`[C1✗] ${r.status}: ${err}`, "danger");
            return;
        }

        const data = await r.json();
        const loadLabels = ['LOW', 'MEDIUM', 'HIGH'];
        const loadText   = loadLabels[data.predicted_cognitive_load] ?? 'UNKNOWN';
        const loadClass  = data.predicted_cognitive_load > 0 ? 'warning' : 'success';

        logMsg(`[C1←] Cognitive Load: ${loadText}  |  MBSV: VSI=${data.mbsv?.visual_strain_index?.toFixed(2) ?? '?'}  ENG=${data.mbsv?.engagement_index?.toFixed(2) ?? '?'}  ERI=${data.mbsv?.error_resilience_index?.toFixed(2) ?? '?'}`, loadClass);

        // Whisper WER row update (simulated since no audio in demo)
        werValue.textContent = simulatedWer.toFixed(2);
        logMsg(`[Whisper] WER proxy (simulated): ${simulatedWer.toFixed(2)}`, 'info');

        if (data.intervention_triggered) {
            triggerInterventionDisplay(data.predicted_cognitive_load);
        }

        // ── C4 classification ────────────────────────────────────────────────
        await sendC4Classification(letter, errors, contextSentence);

        // ── C2 reward (if arm is active) ─────────────────────────────────────
        if (currentArm !== null && data.mbsv) {
            await sendC2Reward(data.mbsv, correctionRate);
        }

    } catch {
        logMsg(`[C1✗] Backend unreachable – ensure monitoring-service-v2 running on :8001`, "danger");
    }
}

// ── C4 SinBERT Classification ─────────────────────────────────────────────────
async function sendC4Classification(letter, errors, contextSentence) {
    const errorType = errors > 2 ? 'substitution'
                    : errors > 0 ? 'omission'
                    : 'hesitation';

    const payload = {
        student_id:       STUDENT_ID,
        task_id:          `letter_match_${letter}`,
        error_type:       errorType,
        context_sentence: contextSentence,
        syllable:         letter,
    };

    logMsg(`[C4→] classify  error_type=${errorType}  context="${contextSentence}"`, "info");

    try {
        const r = await fetch(`${C4_BASE}/intervention/check`, {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify(payload),
        });

        if (!r.ok) {
            logMsg(`[C4✗] ${r.status} – SinBERT fallback rule-based`, "warning");
            renderC4Fallback(errorType);
            return;
        }

        const d = await r.json();

        // C4 /intervention/check returns: { stage, error_type, confidence, classifier_model }
        // error_type is the winning class; confidence is the winner's score.
        const winner     = (d.error_type ?? 'UNFAMILIAR').toUpperCase().replace(/ /g, '_');
        const winnerConf = d.confidence  ?? 0.75;
        const classifier = d.classifier_model ?? 'rule_based';

        // Distribute remaining probability across the other three classes
        const ALL_CLASSES = ['LONG_WORD', 'VOWEL_CONFUSION', 'CONSONANT_CONFUSION', 'UNFAMILIAR'];
        const confs = {};
        const remainder = (1 - winnerConf) / (ALL_CLASSES.length - 1);
        ALL_CLASSES.forEach(c => confs[c] = c === winner ? winnerConf : remainder);

        renderC4Results(winner, confs);
        logMsg(`[C4←] ${classifier} → ${winner} (${(winnerConf*100).toFixed(0)}%)  stage=${d.stage ?? '?'}`, "success");

    } catch {
        logMsg(`[C4✗] intervention-service-v2 unreachable – rendering simulated classification`, "warning");
        renderC4Simulated(errors);
    }
}

function renderC4Results(winner, confs) {
    const classMap = {
        LONG_WORD:           'c4-long-word',
        VOWEL_CONFUSION:     'c4-vowel',
        CONSONANT_CONFUSION: 'c4-consonant',
        UNFAMILIAR:          'c4-unfamiliar',
    };
    const confKeys = {
        LONG_WORD:           'c4-conf-lw',
        VOWEL_CONFUSION:     'c4-conf-vc',
        CONSONANT_CONFUSION: 'c4-conf-cc',
        UNFAMILIAR:          'c4-conf-uf',
    };

    Object.keys(classMap).forEach(cls => {
        const card = document.getElementById(classMap[cls]);
        const conf = document.getElementById(confKeys[cls]);
        card.classList.toggle('active', cls === winner);
        conf.textContent = confs[cls] !== undefined ? `${(confs[cls] * 100).toFixed(0)}%` : '—';
    });
    c4Winner.textContent = winner.replace(/_/g, ' ');
}

// Simulated fallback when C4 is offline
function renderC4Simulated(errors) {
    const classes = ['LONG_WORD', 'VOWEL_CONFUSION', 'CONSONANT_CONFUSION', 'UNFAMILIAR'];
    // heuristic: more errors → consonant confusion; no errors → unfamiliar
    const winnerIdx = errors > 2 ? 2 : errors > 0 ? 1 : 3;
    const confs = {};
    classes.forEach((c, i) => confs[c] = i === winnerIdx ? 0.72 : 0.1 + Math.random() * 0.1);
    renderC4Results(classes[winnerIdx], confs);
    c4Winner.textContent = classes[winnerIdx].replace(/_/g, ' ') + ' (simulated)';
}

function renderC4Fallback(errorType) {
    // Rule-based: map error_type → error_class
    const mapping = { substitution: 'CONSONANT_CONFUSION', omission: 'VOWEL_CONFUSION', hesitation: 'UNFAMILIAR' };
    const winner  = mapping[errorType] ?? 'UNFAMILIAR';
    const confs   = { LONG_WORD: 0.05, VOWEL_CONFUSION: 0.2, CONSONANT_CONFUSION: 0.2, UNFAMILIAR: 0.55 };
    confs[winner] = 0.80;
    renderC4Results(winner, confs);
    c4Winner.textContent = winner.replace(/_/g, ' ') + ' (rule-based fallback)';
}

// ── C2 Reward ────────────────────────────────────────────────────────────────
async function sendC2Reward(mbsv, accuracyDelta) {
    const reward = Math.max(-1, Math.min(1,
        (mbsv.visual_strain_index ?? 0) * -0.5 + accuracyDelta * 0.3
    ));

    try {
        await fetch(`${C2_BASE}/ui/reward`, {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify({
                student_id:    STUDENT_ID,
                arm_id:        currentArm,
                reward:        parseFloat(reward.toFixed(4)),
                accuracy_delta: parseFloat(accuracyDelta.toFixed(4)),
            }),
        });
        logMsg(`[C2←] reward=${reward.toFixed(3)} sent for arm #${currentArm}`, "success");
    } catch {
        logMsg(`[C2✗] reward submit failed`, "warning");
    }
}

// ── Intervention Display ──────────────────────────────────────────────────────
function triggerInterventionDisplay(loadLevel) {
    interventionOverlay.style.display = 'flex';
    if (loadLevel === 2) {
        interventionTitle.textContent = "High Cognitive Load Detected!";
        interventionDesc.textContent  = "Break/Restart intervention triggered.";
        interventionOverlay.style.backgroundColor = 'rgba(239,68,68,0.9)';
    } else {
        interventionTitle.textContent = "Struggle Detected";
        interventionDesc.textContent  = "Audio/Visual scaffolding hint triggered.";
        interventionOverlay.style.backgroundColor = 'rgba(245,158,11,0.9)';
    }
    logMsg("[INTERVENTION] Active intervention applied for student.", "warning");
}

function resumeGame() {
    interventionOverlay.style.display = 'none';
    currentQuestionTime = Date.now();
    totalDistance = 0;
}

// ── Log ───────────────────────────────────────────────────────────────────────
function logMsg(message, type = "info") {
    const time  = new Date().toLocaleTimeString();
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `<span class="log-time">[${time}]</span> <span class="log-${type}">${message}</span>`;
    logConsole.appendChild(entry);
    logConsole.scrollTop = logConsole.scrollHeight;
}

// ── Start ─────────────────────────────────────────────────────────────────────
initCamera();
initServiceChecks();
loadQuestion();
