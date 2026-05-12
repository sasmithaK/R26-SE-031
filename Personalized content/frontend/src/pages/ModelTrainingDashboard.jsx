import React, { useState } from 'react';
import axios from 'axios';
import { Cpu, Play, AlertTriangle, Loader, CheckCircle2, BarChart2, Grid, PieChart } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend } from 'recharts';

export default function ModelTrainingDashboard() {
  const [loading, setLoading] = useState(false);
  const [metrics, setMetrics] = useState(null);
  const [error, setError] = useState(null);

  const handleTrain = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.post('http://localhost:8000/train-model');
      setMetrics(response.data.metrics);
    } catch (err) {
      setError(err.response?.data?.detail || "Training failed. Make sure database is populated.");
    } finally {
      setLoading(false);
    }
  };

  const getFeatureData = () => {
    if (!metrics?.feature_importances) return [];
    return metrics.feature_importances.map(f => ({
      feature: f.feature,
      Importance: Number((f.importance * 100).toFixed(2))
    }));
  };

  const renderConfusionMatrix = () => {
    if (!metrics?.confusion_matrix || !metrics?.labels) return null;
    
    return (
      <div className="overflow-x-auto">
        <table className="w-full text-sm text-left text-slate-300">
          <thead className="text-xs text-slate-400 uppercase bg-slate-950/50">
            <tr>
              <th className="px-4 py-3">True \\ Predicted</th>
              {metrics.labels.map(label => (
                <th key={label} className="px-4 py-3 font-medium text-center border-b border-slate-800">{label}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {metrics.confusion_matrix.map((row, i) => (
              <tr key={i} className="border-b border-slate-800 hover:bg-slate-800/30">
                <td className="px-4 py-3 font-medium text-slate-200 border-r border-slate-800">
                  {metrics.labels[i]}
                </td>
                {row.map((val, j) => {
                  const isCorrect = i === j;
                  const bgClass = val > 0 
                    ? (isCorrect ? 'bg-emerald-500/20 text-emerald-400 font-bold' : 'bg-red-500/20 text-red-400 font-bold') 
                    : 'text-slate-500';
                  return (
                    <td key={j} className={`px-4 py-3 text-center ${bgClass}`}>
                      {val}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  };

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-20">
      <header className="mb-8 flex justify-between items-center bg-slate-900 border border-slate-800 p-6 rounded-2xl">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">Model Evaluation Dashboard</h1>
          <p className="text-slate-400">Train and rigorously evaluate the Random Forest classification engine.</p>
        </div>
        <button 
          onClick={handleTrain}
          disabled={loading}
          className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 px-8 rounded-xl flex items-center gap-3 transition-colors shadow-lg shadow-blue-500/20 disabled:opacity-50"
        >
          {loading ? <Loader className="w-6 h-6 animate-spin" /> : <Play className="w-6 h-6 fill-current" />}
          {loading ? 'Training...' : 'Start Training Pipeline'}
        </button>
      </header>

      {error && (
        <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-xl flex items-start gap-3">
          <AlertTriangle className="w-6 h-6 text-red-400 shrink-0 mt-0.5" />
          <p className="text-red-300 font-medium">{error}</p>
        </div>
      )}

      {metrics && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 animate-in fade-in zoom-in duration-500">
          
          {/* HIGH LEVEL METRICS */}
          <div className="lg:col-span-4 bg-slate-900 border border-emerald-500/30 rounded-2xl p-8 relative overflow-hidden flex flex-col justify-between">
            <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/10 rounded-bl-full blur-2xl"></div>
            
            <div>
              <h2 className="text-2xl font-bold text-white mb-8 flex items-center gap-3">
                <CheckCircle2 className="w-8 h-8 text-emerald-400" /> 
                Model Validated
              </h2>
              
              <div className="space-y-6">
                <div className="bg-slate-800/50 border border-slate-700 p-6 rounded-xl">
                  <p className="text-sm text-slate-400 font-medium mb-1">Testing Accuracy</p>
                  <div className="flex items-end gap-3">
                    <p className="text-4xl font-bold text-white">{(metrics.accuracy * 100).toFixed(1)}%</p>
                    <p className="text-emerald-400 font-medium mb-1">+ High Precision</p>
                  </div>
                </div>
                
                <div className="bg-slate-800/50 border border-slate-700 p-6 rounded-xl">
                  <p className="text-sm text-slate-400 font-medium mb-1">Macro F1-Score</p>
                  <div className="flex items-end gap-3">
                    <p className="text-4xl font-bold text-white">{(metrics.f1_score * 100).toFixed(1)}%</p>
                    <p className="text-blue-400 font-medium mb-1">Balanced Classes</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* FEATURE IMPORTANCE GRAPH */}
          <div className="lg:col-span-8 bg-slate-900 border border-slate-800 rounded-2xl p-8 flex flex-col">
            <h2 className="text-xl font-bold text-white mb-2 flex items-center gap-3">
              <BarChart2 className="w-6 h-6 text-blue-400" /> 
              Feature Importance Analysis
            </h2>
            <p className="text-sm text-slate-400 mb-6">Identifies which monitoring metrics have the strongest influence on the model's decision.</p>
            
            <div className="flex-1 min-h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={getFeatureData()} layout="vertical" margin={{ top: 0, right: 30, left: 40, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" horizontal={true} vertical={false} />
                  <XAxis type="number" stroke="#94a3b8" fontSize={12} domain={[0, 100]} tickFormatter={(val) => `${val}%`} />
                  <YAxis dataKey="feature" type="category" stroke="#94a3b8" fontSize={12} width={120} tick={{fill: '#cbd5e1'}} />
                  <Tooltip 
                    cursor={{fill: '#1e293b'}}
                    contentStyle={{ backgroundColor: '#0f172a', border: '1px solid #1e293b', borderRadius: '8px', color: '#fff' }}
                    formatter={(value) => [`${value}%`, 'Importance']}
                  />
                  <Bar dataKey="Importance" fill="#3b82f6" radius={[0, 4, 4, 0]} barSize={20} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* CONFUSION MATRIX */}
          <div className="lg:col-span-8 bg-slate-900 border border-slate-800 rounded-2xl p-8">
            <h2 className="text-xl font-bold text-white mb-2 flex items-center gap-3">
              <Grid className="w-6 h-6 text-indigo-400" /> 
              Confusion Matrix (Test Data)
            </h2>
            <p className="text-sm text-slate-400 mb-6">Examines exactly where the model successfully predicts or confuses specific learner types.</p>
            {renderConfusionMatrix()}
          </div>

          {/* CLASS DISTRIBUTION */}
          <div className="lg:col-span-4 bg-slate-900 border border-slate-800 rounded-2xl p-8">
            <h2 className="text-xl font-bold text-white mb-2 flex items-center gap-3">
              <PieChart className="w-6 h-6 text-amber-400" /> 
              Training Class Distribution
            </h2>
            <p className="text-sm text-slate-400 mb-6">Ensures the dataset provides balanced learning exposure.</p>
            
            <div className="space-y-3">
              {metrics?.class_distribution?.map((item) => (
                <div key={item.learner_type} className="flex items-center justify-between p-3 bg-slate-800/50 border border-slate-700/50 rounded-lg">
                  <span className="text-sm font-medium text-slate-300">{item.learner_type}</span>
                  <span className="text-sm font-bold text-blue-400 bg-blue-500/10 px-3 py-1 rounded-full">
                    {item.count.toLocaleString()}
                  </span>
                </div>
              ))}
            </div>
          </div>

        </div>
      )}
      
      {!metrics && !loading && !error && (
        <div className="flex flex-col items-center justify-center py-32 bg-slate-900/30 border border-slate-800 border-dashed rounded-3xl mt-8">
          <Cpu className="w-20 h-20 text-slate-700 mb-6" />
          <h3 className="text-2xl font-bold text-slate-300">No Models Active in Memory</h3>
          <p className="text-slate-500 mt-2 text-lg">Click the blue button above to pull data, train, and evaluate the AI.</p>
        </div>
      )}
    </div>
  );
}
