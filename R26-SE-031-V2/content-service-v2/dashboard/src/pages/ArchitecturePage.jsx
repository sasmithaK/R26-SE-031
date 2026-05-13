export default function ArchitecturePage() {
  return (
    <>
      <div className="card full-width">
        <h3>🔗 Inter-Service Architecture</h3>
        <p className="card-desc">How C3 (PLCE) connects with C1 (Monitoring), C4 (Intervention), and the Flutter App.</p>
        <div className="arch-diagram">
          <div className="arch-box flutter"><div className="arch-label">Frontend</div><div className="arch-name">Flutter App</div></div>
          <div className="arch-arrow">⟶</div>
          <div className="arch-box c1"><div className="arch-label">C1</div><div className="arch-name">Monitoring</div><div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Port 8011</div></div>
          <div className="arch-arrow">⟶</div>
          <div className="arch-box c3"><div className="arch-label">C3 (You)</div><div className="arch-name">Content Engine</div><div style={{ fontSize: 10, color: 'var(--accent)' }}>Port 8012</div></div>
          <div className="arch-arrow">⟶</div>
          <div className="arch-box c4"><div className="arch-label">C4</div><div className="arch-name">Intervention</div><div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Port 8013</div></div>
        </div>
      </div>

      <div className="card-grid-2">
        <div className="card">
          <h3>📥 C3 Receives From</h3>
          <div className="connection-list">
            <div className="conn-item incoming">
              <span className="conn-source">C1 — Monitoring</span>
              <span className="conn-data">cognitive_load_index, session_fatigue_index</span>
              <span className="conn-desc">Used to adjust IRT difficulty target and trigger fatigue override</span>
            </div>
            <div className="conn-item incoming">
              <span className="conn-source">Flutter App</span>
              <span className="conn-data">student_id, skill_id, is_correct</span>
              <span className="conn-desc">Task response data for BKT mastery updates</span>
            </div>
            <div className="conn-item incoming">
              <span className="conn-source">Guardian Intake</span>
              <span className="conn-data">VARK learner_type, observation_matrix</span>
              <span className="conn-desc">Seeds BKT initial p_know values from clinical observation</span>
            </div>
          </div>
        </div>
        <div className="card">
          <h3>📤 C3 Sends To</h3>
          <div className="connection-list">
            <div className="conn-item outgoing">
              <span className="conn-source">C4 — Intervention</span>
              <span className="conn-data">mastery_vector, next_recommended_skill</span>
              <span className="conn-desc">C4 fetches mastery data via API to determine intervention stage</span>
            </div>
            <div className="conn-item outgoing">
              <span className="conn-source">Flutter App</span>
              <span className="conn-data">content_item, bkt_p_know, zpd_active, fatigue_override</span>
              <span className="conn-desc">The next optimal Sinhala content item to display to the student</span>
            </div>
          </div>
        </div>
      </div>

      <div className="card full-width">
        <h3>🔌 API Endpoints</h3>
        <div className="api-list">
          <div className="api-item"><span className="method post">POST</span><span className="path">/api/v1/mastery/update</span><span className="desc">Apply BKT update for a student's skill response</span></div>
          <div className="api-item"><span className="method get">GET</span><span className="path">/api/v1/mastery/{'{student_id}'}</span><span className="desc">Return full mastery vector for a student</span></div>
          <div className="api-item"><span className="method get">GET</span><span className="path">/api/v1/content/next/{'{student_id}'}</span><span className="desc">ZPD-targeted next content item with IRT difficulty matching</span></div>
          <div className="api-item"><span className="method post">POST</span><span className="path">/api/v1/content/learner_type</span><span className="desc">Set VARK learner type from guardian onboarding</span></div>
          <div className="api-item"><span className="method post">POST</span><span className="path">/api/v1/students/initialize</span><span className="desc">Initialize BKT + SM2 for new student (all skills p_know=0.3)</span></div>
          <div className="api-item"><span className="method get">GET</span><span className="path">/health</span><span className="desc">Service health check</span></div>
        </div>
      </div>
    </>
  );
}
