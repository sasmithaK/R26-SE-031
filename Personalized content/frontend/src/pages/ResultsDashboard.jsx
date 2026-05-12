import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { UserCircle, Activity, BrainCircuit, AlertCircle, CheckCircle2 } from 'lucide-react';
import axios from 'axios';

export default function ResultsDashboard() {
  const location = useLocation();
  const navigate = useNavigate();
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      const learnerData = location.state?.learnerData;
      if (!learnerData) {
        navigate('/simulator');
        return;
      }
      
      try {
        const response = await axios.post('http://localhost:8000/predict', learnerData);
        setResults(response.data);
      } catch (err) {
        setError(err.response?.data?.detail || "Prediction failed. Ensure models are trained.");
      } finally {
        setLoading(false);
      }
    };
    
    fetchData();
  }, [location.state, navigate]);

  if (loading) {
    return (
      <div className="h-full flex flex-col items-center justify-center space-y-4">
        <div className="w-16 h-16 border-4 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xl text-slate-300 animate-pulse">Running Classification Pipeline...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-full flex items-center justify-center">
        <div className="bg-red-500/10 border border-red-500/20 p-8 rounded-2xl max-w-md text-center">
          <AlertCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-white mb-2">Error</h2>
          <p className="text-red-200 mb-6">{error}</p>
          <button 
            onClick={() => navigate('/training')}
            className="bg-red-500 hover:bg-red-600 text-white px-6 py-2 rounded-lg font-medium transition-colors"
          >
            Go to Model Training
          </button>
        </div>
      </div>
    );
  }

  const getMetricLabel = (key, value) => {
    if (key.includes("hesitation")) return value > 4000 ? "High" : value > 2000 ? "Medium" : "Low";
    if (key === "erratic_clicks") return value > 3 ? "High" : value > 0 ? "Medium" : "Low";
    if (key === "cognitive_load") return value === 2 ? "High" : value === 1 ? "Medium" : "Low";
    return "Medium";
  };

  return (
    <div className="space-y-6 pb-20 max-w-5xl mx-auto">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2 flex items-center gap-3">
          <BrainCircuit className="w-8 h-8 text-blue-500" />
          Learner Classification Results
        </h1>
        <p className="text-slate-400">Single-label Random Forest classification based on monitoring metrics.</p>
      </header>

      {/* STUDENT PROFILE CARD */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-slate-900 border border-blue-500/30 rounded-2xl p-8 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/10 rounded-bl-full blur-2xl"></div>
          
          <div className="flex items-center gap-4 mb-8 border-b border-slate-800 pb-6">
            <div className="p-4 bg-blue-500/20 rounded-full">
              <UserCircle className="w-10 h-10 text-blue-400" />
            </div>
            <div>
              <p className="text-sm text-slate-400 font-medium">Student ID</p>
              <p className="text-2xl font-bold text-white font-mono">STU_001</p>
            </div>
          </div>

          <div className="space-y-6">
            <div>
              <p className="text-sm text-slate-400 font-medium mb-1">Predicted Type:</p>
              <p className="text-3xl font-bold text-blue-400 bg-blue-500/10 inline-block px-4 py-2 rounded-lg border border-blue-500/20">
                {results?.prediction?.predicted_type}
              </p>
            </div>

            <div>
              <p className="text-sm text-slate-400 font-medium mb-1 flex items-center gap-2">
                Model Confidence:
                <span className="text-emerald-400 font-bold">{results?.prediction?.confidence}%</span>
              </p>
              <div className="w-full bg-slate-800 rounded-full h-3 mt-2 overflow-hidden">
                <div 
                  className="bg-emerald-500 h-3 rounded-full transition-all duration-1000"
                  style={{ width: `${results?.prediction?.confidence}%` }}
                ></div>
              </div>
            </div>
          </div>
        </div>

        {/* MODEL OUTPUT REASONING */}
        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-8 flex flex-col justify-center">
          <div className="mb-6 flex items-center gap-3 text-emerald-400">
            <CheckCircle2 className="w-6 h-6" />
            <h2 className="text-xl font-bold text-white">Model Output Reason</h2>
          </div>
          
          <div className="p-6 bg-slate-800/50 rounded-xl border border-slate-700/50">
            <p className="text-lg text-slate-300 leading-relaxed italic">
              "{results?.prediction?.reason}"
            </p>
          </div>

          <div className="mt-8 bg-blue-500/10 p-4 rounded-lg border border-blue-500/20">
            <p className="text-sm text-blue-300">
              <strong>System Action:</strong> This profile will be stored in the Learner Database and used to automatically adjust the reading UI and generate personalized content in Phase 2.
            </p>
          </div>
        </div>
      </div>

      {/* BEHAVIOR METRICS TABLE */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-8 mt-6">
        <h2 className="text-xl font-bold text-white mb-6 flex items-center gap-3">
          <Activity className="w-6 h-6 text-indigo-400" />
          Raw Behavior Metrics
        </h2>
        
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-800">
                <th className="pb-4 text-slate-400 font-medium">Metric</th>
                <th className="pb-4 text-slate-400 font-medium">Raw Value</th>
                <th className="pb-4 text-slate-400 font-medium">Indicator Level</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {Object.entries(results?.behavioral_metrics || {}).map(([key, value]) => (
                <tr key={key} className="hover:bg-slate-800/30 transition-colors">
                  <td className="py-4 text-slate-300 font-mono text-sm">
                    {key}
                  </td>
                  <td className="py-4 text-blue-400 font-medium">
                    {Number(value).toFixed(2)}
                  </td>
                  <td className="py-4">
                    <span className={`px-3 py-1 rounded-full text-xs font-medium border ${
                      getMetricLabel(key, value) === 'High' 
                        ? 'bg-red-500/10 text-red-400 border-red-500/20' 
                        : getMetricLabel(key, value) === 'Medium'
                          ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                          : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                    }`}>
                      {getMetricLabel(key, value)}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
