@extends('layouts.dashboard')

@section('page_title', 'Real-Time AI Monitor')
@section('body_class', 'page-detections')

@section('head')
<link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
@endsection

@section('content')
<div class="ai-monitor-page">
    <section class="monitor-status-card">
        <div class="monitor-status-copy">
            <div id="ai-dot" class="ai-dot" style="background: #94a3b8; box-shadow: 0 0 10px #94a3b8;"></div>

            <div>
                <div class="monitor-eyebrow">AI Model</div>
                <div class="monitor-title">
                    Status:
                    <span id="ai-status" style="color: #94a3b8;">INITIALIZING</span>
                </div>
                <div id="last-ping" class="monitor-note">Waiting for heartbeat...</div>
            </div>
        </div>

        <div class="monitor-actions">
            <button id="auto-btn" type="button" class="monitor-secondary-btn">
                <i class="fas fa-sync-alt"></i>
                <span id="auto-text">AUTO: ON</span>
            </button>

            <button id="wake-btn" type="button" class="monitor-primary-btn">
                <i class="fas fa-bolt"></i>
                <span id="btn-text">REFRESH</span>
            </button>
        </div>
    </section>

    <section class="monitor-console">
        <div class="console-header">
            <div class="console-header-left">
                <div class="console-dots">
                    <span class="console-dot red"></span>
                    <span class="console-dot yellow"></span>
                    <span class="console-dot green"></span>
                </div>

                <span class="console-label">System_Activity_Log</span>
            </div>

            <div class="console-version">v1.0.4-stable</div>
        </div>

        <div id="log-container">
            <div style="color: #8b949e;">[SYSTEM] Rebooting Model...</div>
            <div style="color: #8b949e;">[SYSTEM] Initiating Server...</div>
        </div>
    </section>
</div>
@endsection

@section('scripts')
<script>
    const AI_BACKEND_URL = 'https://coconut-ai-backend.onrender.com';
    const logContainer = document.getElementById('log-container');
    const statusText = document.getElementById('ai-status');
    const statusDot = document.getElementById('ai-dot');
    const pingText = document.getElementById('last-ping');
    const wakeBtn = document.getElementById('wake-btn');
    const btnText = document.getElementById('btn-text');
    const autoBtn = document.getElementById('auto-btn');
    const autoText = document.getElementById('auto-text');
    let autoRefreshEnabled = true;
    let autoRefreshTimer = null;

    function addLog(message, type = 'info') {
        const time = new Date().toLocaleTimeString('en-US', { hour12: false });
        const div = document.createElement('div');
        let color = '#c9d1d9';

        if (type === 'success') color = '#7ee787';
        if (type === 'error') color = '#f85149';
        if (type === 'warning') color = '#d29922';
        if (type === 'system') color = '#58a6ff';

        div.innerHTML = `<span style="color: #484f58;">[${time}]</span> <span style="color: ${color};">${message}</span>`;
        logContainer.appendChild(div);
        logContainer.scrollTop = logContainer.scrollHeight;
    }

    function addJsonLog(label, obj) {
        const time = new Date().toLocaleTimeString('en-US', { hour12: false });
        const div = document.createElement('div');
        const json = JSON.stringify(obj);

        div.innerHTML = `<span style="color: #484f58;">[${time}]</span> <span style="color: #58a6ff;">${label}</span> <span style="color: #c9d1d9; font-family: 'Fira Code', monospace;">${json}</span>`;
        logContainer.appendChild(div);
        logContainer.scrollTop = logContainer.scrollHeight;
    }

    function getCleanStatus(rawStatus) {
        if (!rawStatus) return 'SLEEPING';

        const status = rawStatus.toLowerCase();

        if (status.includes('live')) return 'LIVE';
        if (status.includes('waking')) return 'WAKING UP';

        return 'SLEEPING';
    }

    function getStatusColor(cleanStatus) {
        if (cleanStatus === 'LIVE') return '#16a34a';
        if (cleanStatus === 'WAKING UP') return '#38bdf8';

        return '#94a3b8';
    }

    function updateWakeButton(cleanStatus) {
        if (cleanStatus === 'SLEEPING') {
            btnText.textContent = 'WAKE';
            wakeBtn.style.background = '#f59e0b';
            wakeBtn.style.boxShadow = '0 4px 14px rgba(245, 158, 11, 0.35)';
        } else {
            btnText.textContent = 'REFRESH';
            wakeBtn.style.background = '#16a34a';
            wakeBtn.style.boxShadow = '0 4px 14px rgba(22, 163, 74, 0.3)';
        }
    }

    function setAutoRefresh(enabled) {
        autoRefreshEnabled = enabled;
        autoText.textContent = enabled ? 'AUTO: ON' : 'AUTO: OFF';
        autoBtn.style.background = enabled ? '#0f172a' : '#111827';
        autoBtn.style.color = enabled ? '#e2e8f0' : '#94a3b8';

        if (autoRefreshTimer) {
            clearInterval(autoRefreshTimer);
            autoRefreshTimer = null;
        }

        if (enabled) {
            autoRefreshTimer = setInterval(updateDashboard, 60000);
        }
    }

    async function updateDashboard() {
        btnText.textContent = 'PINGING...';
        wakeBtn.style.opacity = '0.7';
        wakeBtn.disabled = true;

        try {
            const response = await fetch(`${AI_BACKEND_URL}/`, {
                method: 'GET',
                headers: { Accept: 'application/json' }
            });

            const result = await response.json();
            const rawStatus = result.ai_model_status || 'Sleeping';
            const cleanStatus = getCleanStatus(rawStatus);
            const color = getStatusColor(cleanStatus);

            statusText.textContent = cleanStatus;
            statusText.style.color = color;
            statusDot.style.background = color;
            statusDot.style.boxShadow = `0 0 12px ${color}`;
            pingText.textContent = `Last Heartbeat: ${new Date().toLocaleTimeString()}`;
            updateWakeButton(cleanStatus);

            if (cleanStatus === 'LIVE') {
                addLog(`Success: Server is ${rawStatus}. AI Model engine ready.`, 'success');
            } else if (cleanStatus === 'WAKING UP') {
                addLog('Warning: Server is WAKING UP. Spin-up in progress (approx 30s).', 'warning');
            } else {
                addLog('Notice: Server returned SLEEPING state.', 'system');
            }

            addJsonLog('Backend Response:', result);
        } catch (error) {
            statusText.textContent = 'SLEEPING';
            const color = getStatusColor('SLEEPING');
            statusText.style.color = color;
            statusDot.style.background = color;
            statusDot.style.boxShadow = `0 0 10px ${color}`;
            updateWakeButton('SLEEPING');
            addLog('Error: Connection timeout. Render instance may be spun down.', 'error');
        } finally {
            updateWakeButton(statusText.textContent);
            wakeBtn.style.opacity = '1';
            wakeBtn.disabled = false;
        }
    }

    wakeBtn.addEventListener('click', () => {
        addLog('Action: Manual refresh requested by Admin.', 'system');
        updateDashboard();
    });

    autoBtn.addEventListener('click', () => {
        setAutoRefresh(!autoRefreshEnabled);
        addLog(`Auto Refresh ${autoRefreshEnabled ? 'Enabled' : 'Disabled'}.`, 'system');
    });

    document.addEventListener('DOMContentLoaded', () => {
        updateDashboard();
        setAutoRefresh(false);
    });
</script>
@endsection
