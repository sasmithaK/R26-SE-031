import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Send, Loader, Database } from 'lucide-react';

export default function Simulator() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    mean_hesitation: 2800,
    std_hesitation: 500,
    mean_correction: 0.1,
    std_correction: 0.04,
    session_count: 20,
    cognitive_load: 0,
    hesitation_time_ms: 1500,
    erratic_clicks: 0
  });

  const handleChange = (e) => {
    const { name, value, type } = e.target;
    let parsedValue = value;
    if (type === 'range' || type === 'number') {
      parsedValue = Number(value);
    }
    setFormData({
      ...formData,
      [name]: parsedValue
    });
  };

  const handleSimulate = async () => {
    setLoading(true);
    try {
      // Pass data to results page via state
      navigate('/results', { state: { learnerData: formData } });
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const fetchFromDB = async () => {
    // In a real implementation this would fetch the exact row from local MongoDB
    // For now we just populate the exact requested baseline payload
    setFormData({
      mean_hesitation: 2800,
      std_hesitation: 500,
      mean_correction: 0.1,
      std_correction: 0.04,
      session_count: 20,
      cognitive_load: 0,
      hesitation_time_ms: 1500,
      erratic_clicks: 0
    });
  };

  const InputGroup = ({ title, children }) => (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 mb-6">
      <h2 className="text-lg font-semibold text-white mb-4 border-b border-slate-800 pb-2">{title}</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {children}
      </div>
    </div>
  );

  const RangeInput = ({ label, name, min, max, step = 1 }) => (
    <div>
      <div className="flex justify-between items-center mb-1">
        <label className="text-sm font-medium text-slate-300">{label}</label>
        <span className="text-xs text-blue-400 font-mono bg-blue-500/10 px-2 py-0.5 rounded">{formData[name]}</span>
      </div>
      <input 
        type="range" 
        name={name} 
        min={min} 
        max={max} 
        step={step}
        value={formData[name]} 
        onChange={handleChange}
        className="w-full accent-blue-500 h-2 bg-slate-800 rounded-lg appearance-none cursor-pointer"
      />
    </div>
  );

  return (
    <div className="space-y-6 pb-20">
      <header className="mb-8 flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">Monitoring Input Simulator</h1>
          <p className="text-slate-400">Mock the 9 behavioral metrics output by the Monitoring Service.</p>
        </div>
        <div className="flex gap-4">
          <button 
            onClick={fetchFromDB}
            className="bg-slate-800 hover:bg-slate-700 text-white font-medium py-3 px-4 rounded-xl flex items-center gap-2 transition-colors border border-slate-700"
          >
            <Database className="w-5 h-5" />
            Load from DB
          </button>
          <button 
            onClick={handleSimulate}
            disabled={loading}
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-6 rounded-xl flex items-center gap-2 transition-colors shadow-lg shadow-blue-500/20"
          >
            {loading ? <Loader className="w-5 h-5 animate-spin" /> : <Send className="w-5 h-5" />}
            Run Prediction
          </button>
        </div>
      </header>

      <InputGroup title="1. Baseline Metrics (student_baseline collection)">
        <RangeInput label="Mean Hesitation (ms)" name="mean_hesitation" min="500" max="10000" step="100" />
        <RangeInput label="Std Hesitation (ms)" name="std_hesitation" min="100" max="3000" step="50" />
        <RangeInput label="Mean Correction Rate" name="mean_correction" min="0" max="1" step="0.01" />
        <RangeInput label="Std Correction Rate" name="std_correction" min="0" max="1" step="0.01" />
        <RangeInput label="Session Count" name="session_count" min="1" max="100" />
      </InputGroup>

      <InputGroup title="2. Current Session Metrics (latest_telemetry collection)">
        <RangeInput label="Current Hesitation (ms)" name="hesitation_time_ms" min="500" max="10000" step="100" />
        <RangeInput label="Erratic Clicks" name="erratic_clicks" min="0" max="20" />
        <RangeInput label="Cognitive Load (0-Low, 2-High)" name="cognitive_load" min="0" max="2" />
      </InputGroup>

    </div>
  );
}
