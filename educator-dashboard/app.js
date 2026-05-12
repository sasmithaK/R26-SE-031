let progressChart = null;

async function fetchStudentData() {
    const studentId = document.getElementById('studentIdInput').value || 'STU_DEMO_01';
    document.getElementById('display-student-id').textContent = `Student: ${studentId}`;
    
    document.getElementById('chart-loading').style.display = 'block';
    
    try {
        const response = await fetch(`http://localhost:8002/api/v1/progress/${studentId}`);
        if (!response.ok) throw new Error('Data not found');
        const data = await response.json();
        
        renderChart(data.history);
        updateStats(data.history);
        
        document.getElementById('chart-loading').style.display = 'none';
    } catch (err) {
        document.getElementById('chart-loading').textContent = 'Error loading data. Ensure Content Service is running on port 8002.';
        console.error(err);
    }
}

function renderChart(historyData) {
    const ctx = document.getElementById('progressChart').getContext('2d');
    
    if (progressChart) {
        progressChart.destroy();
    }

    // Group history by skill
    const skillMap = {};
    historyData.forEach(entry => {
        if (!skillMap[entry.skill_id]) {
            skillMap[entry.skill_id] = { dates: [], values: [] };
        }
        // Use local time for display
        const date = new Date(entry.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        skillMap[entry.skill_id].dates.push(date);
        skillMap[entry.skill_id].values.push(entry.mastery);
    });

    const colors = ['#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#06B6D4', '#F97316', '#14B8A6', '#6366F1'];
    
    const datasets = Object.keys(skillMap).map((skill_id, idx) => {
        return {
            label: skill_id,
            data: skillMap[skill_id].values,
            borderColor: colors[idx % colors.length],
            backgroundColor: colors[idx % colors.length] + '20', // Add transparency
            borderWidth: 2,
            tension: 0.3,
            fill: true
        };
    });

    // Use the dates from the first skill that has data as labels (assuming similar timestamps for demo)
    // For a robust app, we'd unify the X axis, but for this demo, sequential indices or unified times work.
    let labels = [];
    if (Object.keys(skillMap).length > 0) {
        const firstSkill = Object.keys(skillMap)[0];
        labels = skillMap[firstSkill].dates;
    }

    progressChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: datasets
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'right' },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: 1.0,
                    title: { display: true, text: 'Mastery Level' }
                },
                x: {
                    title: { display: true, text: 'Time' }
                }
            }
        }
    });
}

function updateStats(historyData) {
    if (historyData.length === 0) return;

    // Get the latest entries for each skill
    const latestMastery = {};
    historyData.forEach(entry => {
        latestMastery[entry.skill_id] = entry.mastery;
    });

    const skills = Object.values(latestMastery);
    const avgMastery = skills.reduce((a, b) => a + b, 0) / skills.length;
    
    document.getElementById('overall-mastery').textContent = `${(avgMastery * 100).toFixed(1)}%`;

    // High risk skills (< 0.4)
    const riskSkills = Object.keys(latestMastery).filter(k => latestMastery[k] < 0.4);
    
    if (riskSkills.length > 0) {
        document.getElementById('risk-skills').textContent = riskSkills.join(', ');
        document.getElementById('risk-skills').style.color = 'var(--danger)';
        document.getElementById('risk-skills').style.fontSize = '1rem';
        
        document.getElementById('decay-warning').style.display = 'block';
    } else {
        document.getElementById('risk-skills').textContent = 'None';
        document.getElementById('risk-skills').style.color = 'var(--success)';
        document.getElementById('decay-warning').style.display = 'none';
    }

    // Set trend
    const trendEl = document.getElementById('mastery-trend');
    if (avgMastery > 0.5) {
        trendEl.className = 'stat-trend trend-up';
        trendEl.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 6l-9.5 9.5-5-5L1 18"/><path d="M17 6h6v6"/></svg> On track`;
    } else {
        trendEl.className = 'stat-trend trend-down';
        trendEl.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 18l-9.5-9.5-5 5L1 6"/><path d="M17 18h6v-6"/></svg> Needs attention`;
    }
}

// Initial fetch
window.onload = fetchStudentData;
