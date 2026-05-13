import { useState } from 'react';
import Sidebar from './components/Sidebar';
import OverviewPage from './pages/OverviewPage';
import MasteryPage from './pages/MasteryPage';
import ContentPage from './pages/ContentPage';
import SimulationPage from './pages/SimulationPage';
import ArchitecturePage from './pages/ArchitecturePage';

const TITLES = {
  overview: 'System Overview',
  mastery: 'BKT Mastery Tracker',
  content: 'ZPD Content Picker',
  simulation: 'Live Simulation',
  architecture: 'Architecture',
};

export default function App() {
  const [activePanel, setActivePanel] = useState('overview');

  return (
    <>
      <Sidebar activePanel={activePanel} onNavigate={setActivePanel} />
      <main className="main-content">
        <header className="topbar">
          <h1 className="page-title">{TITLES[activePanel]}</h1>
          <div className="topbar-actions">
            <span className="badge">R26-SE-031</span>
            <span className="badge accent">v2.0</span>
          </div>
        </header>
        <section className="panel active">
          {activePanel === 'overview' && <OverviewPage />}
          {activePanel === 'mastery' && <MasteryPage />}
          {activePanel === 'content' && <ContentPage />}
          {activePanel === 'simulation' && <SimulationPage />}
          {activePanel === 'architecture' && <ArchitecturePage />}
        </section>
      </main>
    </>
  );
}
