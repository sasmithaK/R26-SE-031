// Elements
const video = document.getElementById('webcam');
const logConsole = document.getElementById('log-console');
const targetWord = document.getElementById('target-word');
const optionsContainer = document.getElementById('options-container');
const interventionOverlay = document.getElementById('intervention-overlay');
const interventionTitle = document.getElementById('intervention-title');
const interventionDesc = document.getElementById('intervention-desc');

// Game State
let currentQuestionTime = Date.now();
let errorCount = 0;
let lastMouseX = 0;
let lastMouseY = 0;
let lastMouseTime = Date.now();
let totalDistance = 0;

const STUDENT_ID = "STU_DEMO_01";
const API_BASE = "http://localhost:8001/api/v1";

const syllabus = [
    { target: 'ක', options: ['ka', 'ga', 'ta', 'ma'], correct: 'ka' },
    { target: 'ග', options: ['da', 'ga', 'ba', 'ya'], correct: 'ga' },
    { target: 'ට', options: ['la', 'wa', 'ta', 'ca'], correct: 'ta' },
    { target: 'ම', options: ['sa', 'ma', 'pa', 'na'], correct: 'ma' },
    { target: 'ල', options: ['la', 'ra', 'va', 'ba'], correct: 'la' },
];

let currentQuestionIdx = 0;

// Initialize Webcam
async function initCamera() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: true });
        video.srcObject = stream;
        logMsg("Webcam access granted. Observational monitoring active.", "success");
    } catch (err) {
        logMsg(`Webcam access denied or unavailable: ${err.message}`, "danger");
    }
}

// Track Mouse movement for 'swipe_velocity'
document.getElementById('game-area').addEventListener('mousemove', (e) => {
    const now = Date.now();
    const dx = e.clientX - lastMouseX;
    const dy = e.clientY - lastMouseY;
    const distance = Math.sqrt(dx * dx + dy * dy);
    
    totalDistance += distance;
    
    lastMouseX = e.clientX;
    lastMouseY = e.clientY;
    lastMouseTime = now;
});

function loadQuestion() {
    const q = syllabus[currentQuestionIdx];
    targetWord.textContent = q.target;
    
    optionsContainer.innerHTML = '';
    
    // Shuffle options
    const shuffled = [...q.options].sort(() => Math.random() - 0.5);
    
    shuffled.forEach(opt => {
        const btn = document.createElement('button');
        btn.className = 'option-btn';
        btn.textContent = opt;
        btn.onclick = () => checkAnswer(opt, btn, q.correct);
        optionsContainer.appendChild(btn);
    });

    // Reset interaction metrics for this question
    currentQuestionTime = Date.now();
    totalDistance = 0;
    errorCount = 0;
}

async function checkAnswer(selected, btnElement, correct) {
    const now = Date.now();
    const hesitationTime = now - currentQuestionTime;
    
    // Calculate approximate velocity (px / ms) -> convert to some scale, e.g. px / sec
    const velocity = totalDistance / (hesitationTime / 1000); 
    
    if (selected === correct) {
        btnElement.style.backgroundColor = 'var(--success)';
        btnElement.style.color = 'white';
        
        // Send telemetry
        await sendTelemetry(hesitationTime, velocity, errorCount);

        setTimeout(() => {
            currentQuestionIdx = (currentQuestionIdx + 1) % syllabus.length;
            loadQuestion();
        }, 800);
    } else {
        btnElement.style.backgroundColor = 'var(--danger)';
        btnElement.style.color = 'white';
        errorCount++;
        
        logMsg(`Incorrect! Option '${selected}' selected. Error count: ${errorCount}`, "warning");
    }
}

async function sendTelemetry(hesitation_ms, velocity, errors) {
    const payload = {
        student_id: STUDENT_ID,
        task_id: "match_syllable",
        hesitation_time_ms: hesitation_ms,
        swipe_velocity: velocity || 0,
        correction_rate: 0.0, // handled by backend
        error_count: errors,
        hesitation_count: hesitation_ms > 3000 ? 1 : 0
    };

    logMsg(`[TX] Sending Telemetry: Hesitation=${hesitation_ms}ms, Errors=${errors}, Vel=${velocity.toFixed(1)}px/s`, "info");

    try {
        const response = await fetch(`${API_BASE}/telemetry`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        if (!response.ok) throw new Error("Failed to send telemetry");
        
        const data = await response.json();
        
        // Log response
        const loadText = data.predicted_cognitive_load === 2 ? "HIGH" : 
                         data.predicted_cognitive_load === 1 ? "MEDIUM" : "LOW";
        
        let colorClass = data.predicted_cognitive_load > 0 ? "warning" : "success";
        logMsg(`[RX] Cognitive Load: ${loadText} | Z-Score: ${data.personalised_z_score}`, colorClass);

        // Check if intervention triggered
        if (data.intervention_triggered) {
            triggerInterventionDisplay(data.predicted_cognitive_load);
        }

    } catch (err) {
        logMsg(`[ERROR] Backend unreachable. Make sure Monitoring Service is running on port 8001.`, "danger");
    }
}

function triggerInterventionDisplay(loadLevel) {
    interventionOverlay.style.display = 'flex';
    if (loadLevel === 2) {
        interventionTitle.textContent = "High Cognitive Load Detected!";
        interventionDesc.textContent = "The system has triggered a Break/Restart intervention.";
        interventionOverlay.style.backgroundColor = 'rgba(239, 68, 68, 0.9)'; // Red
    } else {
        interventionTitle.textContent = "Struggle Detected";
        interventionDesc.textContent = "The system has triggered an Audio/Visual scaffolding hint.";
        interventionOverlay.style.backgroundColor = 'rgba(245, 158, 11, 0.9)'; // Orange
    }
    
    logMsg(`[INTERVENTION] Active intervention applied for student.`, "warning");
}

function resumeGame() {
    interventionOverlay.style.display = 'none';
    currentQuestionTime = Date.now(); // Reset timer so they aren't penalized for the break
    totalDistance = 0;
}

function logMsg(message, type = "info") {
    const time = new Date().toLocaleTimeString();
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `<span class="log-time">[${time}]</span> <span class="log-${type}">${message}</span>`;
    
    logConsole.appendChild(entry);
    logConsole.scrollTop = logConsole.scrollHeight;
}

// Start
initCamera();
loadQuestion();
