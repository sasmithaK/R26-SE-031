import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation } from 'react-router-dom';
import ModelTrainingDashboard from './pages/ModelTrainingDashboard';
import Simulator from './pages/Simulator';
import ResultsDashboard from './pages/ResultsDashboard';
import { Activity, Database, Cpu, UserCheck, Network } from 'lucide-react';

function Navigation() {
  const location = useLocation();
  const isActive = (path) => location.pathname === path;

  const links = [
    { path: '/', name: 'Model Training', icon: <Cpu className="w-5 h-5" /> },
    { path: '/simulator', name: 'Simulator', icon: <Activity className="w-5 h-5" /> },
    { path: '/results', name: 'Results', icon: <UserCheck className="w-5 h-5" /> }
  ];

  return (
    <nav className="w-64 bg-slate-900 border-r border-slate-800 p-6 flex flex-col h-screen fixed left-0 top-0">
      <div className="flex items-center gap-3 mb-10">
        <div className="w-10 h-10 rounded-lg bg-blue-600 flex items-center justify-center shadow-lg shadow-blue-500/20">
          <Activity className="w-6 h-6 text-white" />
        </div>
        <div>
          <h1 className="font-bold text-white leading-tight">CPE Engine</h1>
          <p className="text-xs text-slate-400">Phase 01: Classification</p>
        </div>
      </div>
      
      <div className="flex flex-col gap-2">
        {links.map((link) => (
          <Link
            key={link.path}
            to={link.path}
            className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${
              isActive(link.path) 
                ? 'bg-blue-600/10 text-blue-400 font-medium border border-blue-500/20' 
                : 'text-slate-400 hover:text-white hover:bg-slate-800'
            }`}
          >
            {link.icon}
            {link.name}
          </Link>
        ))}
      </div>
    </nav>
  );
}

function App() {
  return (
    <Router>
      <div className="flex min-h-screen bg-slate-950 text-slate-200">
        <Navigation />
        <main className="flex-1 ml-64 p-8 overflow-y-auto h-screen">
          <div className="max-w-7xl mx-auto">
            <Routes>
              <Route path="/" element={<ModelTrainingDashboard />} />
              <Route path="/simulator" element={<Simulator />} />
              <Route path="/results" element={<ResultsDashboard />} />
            </Routes>
          </div>
        </main>
      </div>
    </Router>
  );
}

export default App;
