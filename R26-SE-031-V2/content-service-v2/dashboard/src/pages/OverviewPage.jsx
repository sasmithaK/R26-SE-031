import { SKILLS } from '../utils/constants';

export default function OverviewPage() {
  return (
    <>
      <div className="hero-card">
        <div className="hero-content">
          <h2>Personalized Learning Content Engine</h2>
          <p className="hero-desc">Bayesian Knowledge Tracing (BKT) + Zone of Proximal Development (ZPD) for adaptive Sinhala dyslexia screening</p>
          <div className="hero-stats">
            <div className="stat-pill"><span className="stat-value">10</span><span className="stat-label">Skill Nodes</span></div>
            <div className="stat-pill"><span className="stat-value">30</span><span className="stat-label">Content Items</span></div>
            <div className="stat-pill"><span className="stat-value">0.833</span><span className="stat-label">Mastery Threshold</span></div>
            <div className="stat-pill"><span className="stat-value">3</span><span className="stat-label">VARK Modalities</span></div>
          </div>
        </div>
      </div>

      <div className="card-grid-3">
        <div className="info-card">
          <div className="info-icon bkt-icon">🧠</div>
          <h3>BKT Engine</h3>
          <p>Hidden Markov Model tracking student knowledge state across 10 phonological skills using Bayesian posterior updates.</p>
          <div className="param-list">
            <div className="param"><span>P_init</span><span>0.30</span></div>
            <div className="param"><span>P_learn</span><span>0.10</span></div>
            <div className="param"><span>P_slip</span><span>0.10</span></div>
            <div className="param"><span>P_guess</span><span>0.20</span></div>
          </div>
        </div>
        <div className="info-card">
          <div className="info-icon zpd-icon">🎯</div>
          <h3>ZPD Selector</h3>
          <p>Vygotsky's Zone of Proximal Development combined with IRT difficulty targeting for optimal challenge level.</p>
          <div className="param-list">
            <div className="param"><span>ZPD Lower</span><span>0.45</span></div>
            <div className="param"><span>ZPD Upper</span><span>0.833</span></div>
            <div className="param"><span>Fatigue Cap</span><span>0.70</span></div>
            <div className="param"><span>IRT Formula</span><span>0.5 − CLI×0.3</span></div>
          </div>
        </div>
        <div className="info-card">
          <div className="info-icon vark-icon">🎨</div>
          <h3>VARK Personalization</h3>
          <p>Content modality filtered by Visual, Auditory, or Kinesthetic learner type from guardian intake questionnaire.</p>
          <div className="param-list">
            <div className="param"><span>Visual (V)</span><span>Images</span></div>
            <div className="param"><span>Auditory (A)</span><span>Audio</span></div>
            <div className="param"><span>Kinesthetic (K)</span><span>Tracing</span></div>
          </div>
        </div>
      </div>

      <div className="card full-width">
        <h3>📐 Phonological Skill Prerequisite Graph</h3>
        <p className="card-desc">Skills are unlocked sequentially. A skill enters the ZPD only when its prerequisites reach p_know ≥ 0.45.</p>
        <div className="skill-graph">
          {SKILLS.map((s, i) => (
            <div className="skill-graph-item" key={s.id}>
              <div className="skill-node">
                <div className="skill-code">{s.id.split('_')[0].toUpperCase()}</div>
                <div className="skill-name">{s.name}</div>
              </div>
              {i < SKILLS.length - 1 && <div className="skill-graph-arrow">→</div>}
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
