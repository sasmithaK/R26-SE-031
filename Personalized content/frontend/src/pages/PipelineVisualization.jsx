import React from 'react';
import { Database, Filter, BrainCircuit, UserCheck, ArrowRight, Zap, Scale, Layers } from 'lucide-react';

export default function PipelineVisualization() {
  const steps = [
    {
      title: "1. Data Ingestion",
      icon: <Database className="w-8 h-8 text-blue-400" />,
      description: "Raw behavioral telemetry is pulled from two MongoDB collections (Baseline & Latest Telemetry).",
      details: ["Mean Hesitation", "Erratic Clicks", "Cognitive Load", "Correction Rate"]
    },
    {
      title: "2. Feature Engineering",
      icon: <Filter className="w-8 h-8 text-indigo-400" />,
      description: "Mathematical normalization (StandardScaler) ensures that large numbers don't bias the model.",
      details: ["Outlier Removal", "Mean Centering", "Unit Variance Scaling"]
    },
    {
      title: "3. Random Forest Logic",
      icon: <BrainCircuit className="w-8 h-8 text-emerald-400" />,
      description: "An ensemble of 100 Decision Trees evaluates the data patterns simultaneously.",
      details: ["Parallel Evaluation", "Pattern Recognition", "Weighted Voting"]
    },
    {
      title: "4. Profile Classification",
      icon: <UserCheck className="w-8 h-8 text-amber-400" />,
      description: "The system outputs the most probable learner category and a human-readable reason.",
      details: ["Type: Struggling Reader", "Confidence: 92%", "Reasoning Logs"]
    }
  ];

  return (
    <div className="space-y-10 pb-20 max-w-6xl mx-auto">
      <header className="text-center">
        <h1 className="text-4xl font-bold text-white mb-4">How the AI Works</h1>
        <p className="text-slate-400 text-lg max-w-2xl mx-auto">
          Take a look under the hood of the Content Personalization Engine and see how we transform raw data into personalized learner profiles.
        </p>
      </header>

      {/* PIPELINE FLOW */}
      <div className="relative">
        {/* Connection Line */}
        <div className="absolute top-1/2 left-0 w-full h-1 bg-slate-800 -translate-y-1/2 hidden lg:block z-0"></div>
        
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-8 relative z-10">
          {steps.map((step, index) => (
            <div key={index} className="bg-slate-900 border border-slate-800 p-6 rounded-2xl flex flex-col items-center text-center group hover:border-blue-500/50 transition-all duration-300">
              <div className="p-4 bg-slate-950 rounded-full mb-6 border border-slate-800 group-hover:scale-110 transition-transform">
                {step.icon}
              </div>
              <h3 className="text-xl font-bold text-white mb-3">{step.title}</h3>
              <p className="text-sm text-slate-400 leading-relaxed mb-6">
                {step.description}
              </p>
              
              <div className="w-full space-y-2">
                {step.details.map((detail, dIdx) => (
                  <div key={dIdx} className="text-xs font-mono bg-slate-950 text-slate-500 py-1.5 px-3 rounded-lg border border-slate-800">
                    {detail}
                  </div>
                ))}
              </div>

              {index < steps.length - 1 && (
                <div className="mt-8 lg:hidden">
                  <ArrowRight className="w-6 h-6 text-slate-700 rotate-90" />
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* LOGIC DEEP DIVE */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mt-16">
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-10">
          <div className="flex items-center gap-4 mb-6">
            <Zap className="w-10 h-10 text-yellow-400" />
            <h2 className="text-2xl font-bold text-white">Why Random Forest?</h2>
          </div>
          <p className="text-slate-300 leading-relaxed mb-8 text-lg">
            Unlike a single "if/else" rule, a Random Forest builds an entire forest of **100 independent decision trees**. Each tree looks at a random subset of data. This prevents the model from making mistakes based on outliers or "lucky" data.
          </p>
          <div className="space-y-4">
            <div className="flex gap-4 items-start">
              <div className="mt-1"><Layers className="w-5 h-5 text-blue-400" /></div>
              <div>
                <h4 className="text-white font-bold">Ensemble Learning</h4>
                <p className="text-sm text-slate-400">By combining multiple trees, the overall accuracy increases significantly.</p>
              </div>
            </div>
            <div className="flex gap-4 items-start">
              <div className="mt-1"><Scale className="w-5 h-5 text-blue-400" /></div>
              <div>
                <h4 className="text-white font-bold">Unbiased Decisions</h4>
                <p className="text-sm text-slate-400">The model evaluates all 8 features fairly through normalization.</p>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-blue-600 rounded-3xl p-10 flex flex-col justify-center text-white relative overflow-hidden shadow-2xl shadow-blue-500/20">
          <div className="absolute -bottom-10 -right-10 w-64 h-64 bg-white/10 rounded-full blur-3xl"></div>
          <h2 className="text-3xl font-bold mb-4">Goal: Total Personalization</h2>
          <p className="text-blue-50 text-lg leading-relaxed mb-8">
            This classification is the **foundation**. Once the AI knows exactly how a student learns, it can automatically rewrite textbooks, change font spacings, or add extra audio cues in Phase 02.
          </p>
          <div className="bg-white/10 border border-white/20 p-6 rounded-2xl backdrop-blur-sm">
            <p className="text-sm font-bold uppercase tracking-wider mb-2 opacity-80">Next Phase</p>
            <p className="text-xl font-bold">Dynamic Content Generation & Adaptation</p>
          </div>
        </div>
      </div>
    </div>
  );
}
