import { useState } from 'react';
import { fetchNextContent } from '../utils/api';
import { SKILLS, CONTENT_REPO } from '../utils/constants';

export default function ContentPage() {
  const [studentId, setStudentId] = useState('demo_student_01');
  const [cli, setCli] = useState(0.5);
  const [fatigue, setFatigue] = useState(0.0);
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');

  const handleFetch = async () => {
    setError('');
    try { setResult(await fetchNextContent(studentId, cli, fatigue)); } catch (e) { setError(e.message); }
  };

  const grouped = {};
  CONTENT_REPO.forEach(item => { (grouped[item.skill_id] = grouped[item.skill_id] || []).push(item); });

  return (
    <>
      <div className="card">
        <div className="card-header">
          <h3>📚 ZPD Content Selection</h3>
          <p className="card-desc">Request the next optimal content item. Adjust Cognitive Load and Fatigue to see how C3 adapts difficulty in real-time.</p>
        </div>
        <div className="content-controls">
          <div className="input-group"><label>Student ID</label><input type="text" value={studentId} onChange={e => setStudentId(e.target.value)} /></div>
          <div className="input-group">
            <label>Cognitive Load (from C1)</label>
            <input type="range" min="0" max="1" step="0.05" value={cli} onChange={e => setCli(parseFloat(e.target.value))} />
            <span className="range-val">{cli.toFixed(2)}</span>
          </div>
          <div className="input-group">
            <label>Session Fatigue (from C1)</label>
            <input type="range" min="0" max="1" step="0.05" value={fatigue} onChange={e => setFatigue(parseFloat(e.target.value))} />
            <span className="range-val">{fatigue.toFixed(2)}</span>
          </div>
          <button className="btn btn-primary btn-large" onClick={handleFetch}>🎯 Get Next Content Item</button>
        </div>
        {error && <div style={{ color: 'var(--danger)', padding: 12 }}>Error: {error}</div>}
        {result && (
          <div className="content-result-area">
            <div className="content-card">
              <div className="content-sinhala">{result.content_item.sinhala_text}</div>
              <div className="content-english">"{result.content_item.english_gloss}"</div>
              <div className="content-meta">
                <span className="meta-tag skill">📐 {result.content_item.skill_id}</span>
                <span className="meta-tag difficulty">📊 IRT b = {result.content_item.irt_difficulty_b}</span>
                <span className="meta-tag modality">🎨 {result.content_item.modality}</span>
                {result.zpd_active && <span className="meta-tag zpd-tag">🎯 ZPD Active</span>}
                {result.fatigue_override && <span className="meta-tag fatigue">😴 Fatigue Override</span>}
              </div>
            </div>
            <div className="decision-box">
              <h4>🔬 Selection Decision Breakdown</h4>
              <div className="decision-row"><span>Student p_know</span><span>{result.bkt_p_know}</span></div>
              <div className="decision-row"><span>Cognitive Load Index (from C1)</span><span>{cli}</span></div>
              <div className="decision-row"><span>Session Fatigue (from C1)</span><span>{fatigue}</span></div>
              <div className="decision-row"><span>IRT Target b = 0.5 − ({cli} × 0.3)</span><span style={{ color: 'var(--accent)' }}>{(0.5 - cli * 0.3).toFixed(3)}</span></div>
              <div className="decision-row"><span>Selected Item Difficulty</span><span>{result.content_item.irt_difficulty_b}</span></div>
              <div className="decision-row"><span>Fatigue Override (&gt; 0.70)</span><span style={{ color: result.fatigue_override ? 'var(--danger)' : 'var(--success)' }}>{result.fatigue_override ? 'YES — Consolidation Mode' : 'No'}</span></div>
              <div className="decision-row"><span>ZPD Active (0.45 ≤ p ≤ 0.833)</span><span style={{ color: result.zpd_active ? 'var(--zpd-color)' : 'var(--text-muted)' }}>{result.zpd_active ? 'YES' : 'No'}</span></div>
            </div>
          </div>
        )}
      </div>

      <div className="card">
        <div className="card-header">
          <h3>📦 Content Repository</h3>
          <p className="card-desc">All 30 Sinhala content items organized by skill node with IRT difficulty values.</p>
        </div>
        <div className="content-repo">
          {Object.entries(grouped).map(([skillId, items]) => (
            <div className="repo-skill-group" key={skillId}>
              <div className="repo-skill-title">{skillId} — {SKILLS.find(s => s.id === skillId)?.name}</div>
              {items.map(i => (
                <div className="repo-item" key={i.item_id}>
                  <span className="repo-sinhala">{i.sinhala_text}</span>
                  <span style={{ color: 'var(--text-secondary)' }}>{i.english_gloss}</span>
                  <span style={{ color: 'var(--warning)', fontFamily: "'SF Mono', monospace", fontSize: 11 }}>b = {i.irt_difficulty_b}</span>
                  <span style={{ color: 'var(--zpd-color)', fontSize: 11 }}>{i.modality}</span>
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
