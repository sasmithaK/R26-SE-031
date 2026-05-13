const API_BASE = 'http://localhost:8012';

export async function checkHealth() {
  const r = await fetch(`${API_BASE}/health`);
  return r.json();
}

export async function fetchMastery(studentId) {
  const r = await fetch(`${API_BASE}/api/v1/mastery/${studentId}`);
  return r.json();
}

export async function initializeStudent(studentId) {
  const r = await fetch(`${API_BASE}/api/v1/students/initialize?student_id=${studentId}`, { method: 'POST' });
  return r.json();
}

export async function updateMastery(studentId, skillId, isCorrect) {
  const r = await fetch(`${API_BASE}/api/v1/mastery/update`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ student_id: studentId, session_id: 'demo', skill_id: skillId, is_correct: isCorrect, response_latency_ms: 1500 }),
  });
  return r.json();
}

export async function fetchNextContent(studentId, cognitiveLoad, sessionFatigue) {
  const r = await fetch(`${API_BASE}/api/v1/content/next/${studentId}?cognitive_load_index=${cognitiveLoad}&session_fatigue_index=${sessionFatigue}`);
  return r.json();
}

export async function setLearnerType(studentId, learnerType) {
  const r = await fetch(`${API_BASE}/api/v1/content/learner_type`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ student_id: studentId, learner_type: learnerType }),
  });
  return r.json();
}
