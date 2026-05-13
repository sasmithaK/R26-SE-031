import { useState, useRef, useEffect } from 'react';
import { fetchMastery, initializeStudent, updateMastery } from '../utils/api';
import { SKILLS } from '../utils/constants';

function getMasteryStyle(v) {
  if (v >= 0.833) return { cls: 'high', status: 'Mastered', statusCls: 'mastered', color: 'var(--success)' };
  if (v >= 0.45) return { cls: 'zpd', status: 'ZPD', statusCls: 'zpd-status', color: 'var(--zpd-color)' };
  if (v > 0.3) return { cls: 'mid', status: 'Learning', statusCls: 'learning', color: 'var(--warning)' };
  return { cls: 'low', status: 'New', statusCls: 'new', color: 'var(--danger)' };
}

function drawChart(canvas, history) {
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width, H = canvas.height;
  ctx.clearRect(0, 0, W, H);
  ctx.fillStyle = '#111827'; ctx.fillRect(0, 0, W, H);
  const pad = { t: 30, r: 20, b: 30, l: 50 };
  const cw = W - pad.l - pad.r, ch = H - pad.t - pad.b;
  ctx.strokeStyle = 'rgba(255,255,255,0.06)'; ctx.lineWidth = 1;
  ctx.fillStyle = '#5a6478'; ctx.font = '11px Inter';
  for (let v = 0; v <= 1; v += 0.2) {
    const y = pad.t + ch - v * ch;
    ctx.beginPath(); ctx.moveTo(pad.l, y); ctx.lineTo(W - pad.r, y); ctx.stroke();
    ctx.fillText(v.toFixed(1), 8, y + 4);
  }
  const masteryY = pad.t + ch - 0.833 * ch;
  ctx.strokeStyle = 'rgba(34,197,94,0.4)'; ctx.setLineDash([6, 4]);
  ctx.beginPath(); ctx.moveTo(pad.l, masteryY); ctx.lineTo(W - pad.r, masteryY); ctx.stroke();
  ctx.fillStyle = '#22c55e'; ctx.fillText('Mastery (0.833)', pad.l + 4, masteryY - 6);
  ctx.setLineDash([]);
  const zpdTopY = pad.t + ch - 0.833 * ch, zpdBotY = pad.t + ch - 0.45 * ch;
  ctx.fillStyle = 'rgba(168,85,247,0.06)';
  ctx.fillRect(pad.l, zpdTopY, cw, zpdBotY - zpdTopY);
  if (history.length === 0) return;
  const pts = history.map((h, i) => ({ x: pad.l + (i / Math.max(history.length - 1, 1)) * cw, y: pad.t + ch - h.after * ch, correct: h.correct }));
  ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2.5;
  ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
  ctx.stroke();
  const grad = ctx.createLinearGradient(0, pad.t, 0, H - pad.b);
  grad.addColorStop(0, 'rgba(99,102,241,0.15)'); grad.addColorStop(1, 'rgba(99,102,241,0)');
  ctx.fillStyle = grad;
  ctx.beginPath(); ctx.moveTo(pts[0].x, H - pad.b);
  pts.forEach(p => ctx.lineTo(p.x, p.y));
  ctx.lineTo(pts[pts.length - 1].x, H - pad.b); ctx.closePath(); ctx.fill();
  pts.forEach(p => {
    ctx.beginPath(); ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
    ctx.fillStyle = p.correct ? '#22c55e' : '#ef4444'; ctx.fill();
    ctx.strokeStyle = '#0a0e1a'; ctx.lineWidth = 2; ctx.stroke();
  });
}

export default function MasteryPage() {
  const [studentId, setStudentId] = useState('demo_student_01');
  const [masteryData, setMasteryData] = useState(null);
  const [bktStudentId, setBktStudentId] = useState('demo_student_01');
  const [bktSkill, setBktSkill] = useState('S1_vowel_id');
  const [bktHistory, setBktHistory] = useState([]);
  const [error, setError] = useState('');
  const canvasRef = useRef(null);

  useEffect(() => { drawChart(canvasRef.current, bktHistory); }, [bktHistory]);

  const handleFetch = async () => {
    setError('');
    try { setMasteryData(await fetchMastery(studentId)); } catch (e) { setError(e.message); }
  };

  const handleInit = async () => {
    setError('');
    try { await initializeStudent(studentId); handleFetch(); } catch (e) { setError(e.message); }
  };

  const handleBkt = async (isCorrect) => {
    try {
      const d = await updateMastery(bktStudentId, bktSkill, isCorrect);
      setBktHistory(prev => [...prev, { correct: isCorrect, before: d.p_know_before, after: d.p_know_after, mastery: d.mastery_achieved, zpd: d.zpd_active }]);
    } catch (e) { setError(e.message); }
  };

  return (
    <>
      <div className="card">
        <div className="card-header">
          <h3>🧠 BKT Mastery Vector</h3>
          <div className="input-row">
            <input type="text" value={studentId} onChange={e => setStudentId(e.target.value)} placeholder="Enter Student ID" />
            <button className="btn btn-primary" onClick={handleFetch}>Fetch Mastery</button>
            <button className="btn btn-outline" onClick={handleInit}>Initialize New</button>
          </div>
        </div>
        {error && <div style={{ color: 'var(--danger)', padding: 8 }}>Error: {error}. Is C3 running?</div>}
        {masteryData && (
          <div className="mastery-grid">
            {SKILLS.map(s => {
              const v = masteryData.mastery_vector[s.id] || 0;
              const st = getMasteryStyle(v);
              return (
                <div className="mastery-item" key={s.id}>
                  <div className="mastery-item-header">
                    <span className="mastery-skill">{s.name}</span>
                    <span className={`mastery-status ${st.statusCls}`}>{st.status}</span>
                  </div>
                  <div className="mastery-value" style={{ color: st.color }}>{v.toFixed(4)}</div>
                  <div className="mastery-bar-bg"><div className={`mastery-bar ${st.cls}`} style={{ width: `${Math.round(v * 100)}%` }}></div></div>
                </div>
              );
            })}
            {masteryData.next_recommended_skill && (
              <div style={{ gridColumn: '1/-1', padding: '12px 16px', background: 'var(--zpd-bg)', border: '1px solid rgba(168,85,247,0.2)', borderRadius: 8, fontSize: 13 }}>
                🎯 <strong>Next Recommended Skill:</strong> {masteryData.next_recommended_skill}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="card">
        <div className="card-header">
          <h3>📈 BKT Update Simulator</h3>
          <p className="card-desc">Simulate correct/incorrect responses and watch the mastery score change in real-time using Bayesian posterior updates.</p>
        </div>
        <div className="sim-controls">
          <div className="input-group"><label>Student ID</label><input type="text" value={bktStudentId} onChange={e => setBktStudentId(e.target.value)} /></div>
          <div className="input-group">
            <label>Skill</label>
            <select value={bktSkill} onChange={e => setBktSkill(e.target.value)}>
              {SKILLS.map(s => <option key={s.id} value={s.id}>{s.id.split('_')[0].toUpperCase()} — {s.name}</option>)}
            </select>
          </div>
          <div className="btn-group">
            <button className="btn btn-success" onClick={() => handleBkt(true)}>✓ Correct</button>
            <button className="btn btn-danger" onClick={() => handleBkt(false)}>✗ Incorrect</button>
          </div>
        </div>
        <div className="bkt-history">
          {bktHistory.map((h, i) => (
            <div key={i} className={`bkt-entry ${h.correct ? 'correct' : 'incorrect'}`}>
              #{i + 1} {h.correct ? '✓' : '✗'} {h.before.toFixed(3)}→{h.after.toFixed(3)} {h.mastery ? '🏆' : h.zpd ? '🎯' : ''}
            </div>
          ))}
        </div>
        <canvas ref={canvasRef} width={800} height={280}></canvas>
      </div>
    </>
  );
}
