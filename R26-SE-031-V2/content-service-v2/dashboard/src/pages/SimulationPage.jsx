import { useState } from 'react';
import { initializeStudent, setLearnerType, fetchNextContent, updateMastery } from '../utils/api';

export default function SimulationPage() {
  const [studentId, setStudentId] = useState('sim_student_01');
  const [learnerType, setLearnerTypeVal] = useState('V');
  const [accuracy, setAccuracy] = useState(70);
  const [rounds, setRounds] = useState(10);
  const [log, setLog] = useState([]);
  const [summary, setSummary] = useState(null);
  const [running, setRunning] = useState(false);

  const run = async () => {
    setRunning(true); setLog([]); setSummary(null);
    const addLog = (entry) => setLog(prev => [...prev, entry]);

    addLog({ type: 'info', text: `⚡ Initializing student ${studentId}...` });
    try { await initializeStudent(studentId); } catch {}
    try { await setLearnerType(studentId, learnerType); } catch {}
    addLog({ type: 'info', text: `👤 Learner type set to: ${learnerType}` });

    let correctCount = 0, lastPKnow = 0;

    for (let i = 1; i <= rounds; i++) {
      await new Promise(r => setTimeout(r, 300));
      const fat = Math.min(1.0, 0.1 * Math.random() + (i > rounds / 2 ? 0.3 : 0)).toFixed(2);
      const cliVal = (0.3 + Math.random() * 0.4).toFixed(2);

      let content;
      try {
        content = await fetchNextContent(studentId, cliVal, fat);
      } catch { addLog({ type: 'error', text: '❌ Failed to fetch content' }); continue; }

      const item = content.content_item;
      const isCorrect = Math.random() * 100 < accuracy;
      if (isCorrect) correctCount++;

      let update;
      try {
        update = await updateMastery(studentId, item.skill_id, isCorrect);
      } catch { continue; }

      lastPKnow = update.p_know_after;
      addLog({
        type: 'round',
        num: i,
        sinhala: item.sinhala_text,
        gloss: item.english_gloss,
        correct: isCorrect,
        before: update.p_know_before,
        after: update.p_know_after,
        mastery: update.mastery_achieved,
        zpd: update.zpd_active,
        fatigue: parseFloat(fat) > 0.7,
      });
    }

    setSummary({ rounds, correctCount, accuracy: Math.round(correctCount / rounds * 100), finalPKnow: lastPKnow });
    setRunning(false);
  };

  return (
    <div className="card">
      <div className="card-header">
        <h3>🎮 Full Session Simulation</h3>
        <p className="card-desc">Watch a complete learning session unfold. The system adapts content, tracks mastery, and responds to fatigue — all automatically.</p>
      </div>
      <div className="sim-setup">
        <div className="input-group"><label>Student ID</label><input type="text" value={studentId} onChange={e => setStudentId(e.target.value)} /></div>
        <div className="input-group">
          <label>Learner Type</label>
          <select value={learnerType} onChange={e => setLearnerTypeVal(e.target.value)}>
            <option value="V">Visual (V)</option><option value="A">Auditory (A)</option><option value="K">Kinesthetic (K)</option>
          </select>
        </div>
        <div className="input-group">
          <label>Simulated Accuracy</label>
          <input type="range" min="0" max="100" step="5" value={accuracy} onChange={e => setAccuracy(parseInt(e.target.value))} />
          <span className="range-val">{accuracy}%</span>
        </div>
        <div className="input-group"><label>Number of Rounds</label><input type="number" value={rounds} min="1" max="30" onChange={e => setRounds(parseInt(e.target.value))} /></div>
        <button className="btn btn-primary btn-large" onClick={run} disabled={running}>{running ? '⏳ Running...' : '▶ Run Simulation'}</button>
      </div>

      {log.length > 0 && (
        <div className="sim-log">
          {log.map((entry, i) => {
            if (entry.type === 'info') return <div key={i} className="round-entry">{entry.text}</div>;
            if (entry.type === 'error') return <div key={i} className="round-entry" style={{ color: 'var(--danger)' }}>{entry.text}</div>;
            return (
              <div key={i} className="round-entry">
                <span className="round-num">Round {entry.num}</span> | "{entry.sinhala}" ({entry.gloss}) |{' '}
                {entry.correct ? <span className="correct-mark">✓ Correct</span> : <span className="incorrect-mark">✗ Incorrect</span>} |{' '}
                p_know: {entry.before.toFixed(3)} → {entry.after.toFixed(3)}
                {entry.mastery && ' 🏆 MASTERED'}{entry.zpd && ' 🎯 ZPD'}
                {entry.fatigue && <span className="fatigue-warn"> ⚠ Fatigue Override</span>}
              </div>
            );
          })}
        </div>
      )}

      {summary && (
        <div className="sim-summary">
          <h4>📊 Simulation Summary</h4>
          <div className="summary-stats">
            <div className="summary-stat"><div className="val">{summary.rounds}</div><div className="lbl">Rounds</div></div>
            <div className="summary-stat"><div className="val">{summary.correctCount}</div><div className="lbl">Correct</div></div>
            <div className="summary-stat"><div className="val">{summary.accuracy}%</div><div className="lbl">Accuracy</div></div>
            <div className="summary-stat"><div className="val" style={{ color: 'var(--zpd-color)' }}>{summary.finalPKnow.toFixed(3)}</div><div className="lbl">Final p_know</div></div>
          </div>
        </div>
      )}
    </div>
  );
}
