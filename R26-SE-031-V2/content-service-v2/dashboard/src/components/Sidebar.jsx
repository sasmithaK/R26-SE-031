import { useState, useEffect } from 'react';
import { checkHealth } from '../utils/api';

const NAV_ITEMS = [
  { id: 'overview', icon: '📊', label: 'System Overview' },
  { id: 'mastery', icon: '🧠', label: 'BKT Mastery Tracker' },
  { id: 'content', icon: '📚', label: 'ZPD Content Picker' },
  { id: 'simulation', icon: '🎮', label: 'Live Simulation' },
  { id: 'architecture', icon: '🔗', label: 'Architecture' },
];

export default function Sidebar({ activePanel, onNavigate }) {
  const [online, setOnline] = useState(null);

  useEffect(() => {
    const check = () => checkHealth().then(() => setOnline(true)).catch(() => setOnline(false));
    check();
    const interval = setInterval(check, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <nav className="sidebar">
      <div className="sidebar-header">
        <div className="logo-icon">C3</div>
        <div className="logo-text">
          <span className="logo-title">PLCE</span>
          <span className="logo-sub">Content Engine</span>
        </div>
      </div>
      <ul className="nav-list">
        {NAV_ITEMS.map(item => (
          <li key={item.id} className={`nav-item ${activePanel === item.id ? 'active' : ''}`} onClick={() => onNavigate(item.id)}>
            <span className="nav-icon">{item.icon}</span>
            <span className="nav-label">{item.label}</span>
          </li>
        ))}
      </ul>
      <div className="sidebar-footer">
        <div className="service-status">
          <span className={`status-dot ${online === true ? 'online' : online === false ? 'offline' : ''}`}></span>
          <span className="status-text">{online === true ? 'C3 Online — Port 8012' : online === false ? 'C3 Offline' : 'Checking...'}</span>
        </div>
      </div>
    </nav>
  );
}
