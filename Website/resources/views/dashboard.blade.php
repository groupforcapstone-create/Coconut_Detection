@extends('layouts.dashboard')

@section('page_title', 'Admin Overview')
@section('body_class', 'page-dashboard')

@section('content')
<div class="dashboard-wrapper">
    <header class="header-minimal">
        <div class="header-welcome">
            <h1>Hello, Admin 👋</h1>
            <p class="text-muted">Coconut Variety Recognizer system monitor.</p>
        </div>

        <div class="hide-mobile">
            <span class="status-pill">
                <span class="status-dot" style="background: var(--brand-green);"></span>
                System Operational
            </span>
        </div>
    </header>

    <section class="ai-card">
        <div id="ai-dot" class="ai-dot" style="background: #94a3b8; box-shadow: 0 0 10px #94a3b8;"></div>

        <div>
            <div class="ai-title">AI Model</div>
            <div id="ai-status" class="ai-value" style="color: #94a3b8;">INITIALIZING</div>
            <div class="ai-sub">Remote Inference Engine (Render)</div>
        </div>

        <div class="ai-actions">
            <span id="wake-note" class="wake-note">Checking heartbeat...</span>

            <button id="wake-btn" class="btn-wake" type="button">
                <i class="fas fa-sync-alt"></i>
                <span>Refresh</span>
            </button>
        </div>
    </section>

    <div class="metric-grid">
        <div class="stat-card">
            <div class="stat-icon">
                <i class="fas fa-users"></i>
            </div>
            <div class="stat-content">
                <span class="label-muted">Verified Sellers</span>
                <div class="value-bold">{{ number_format($totalSellers) }}</div>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon">
                <i class="fas fa-user-shield"></i>
            </div>
            <div class="stat-content">
                <span class="label-muted">Latest Onboarded</span>
                <div class="value-bold">
                    {{ $recentSellers->isNotEmpty() ? $recentSellers->first()->full_name : 'No sellers' }}
                </div>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon">
                <i class="fas fa-check-circle"></i>
            </div>
            <div class="stat-content">
                <span class="label-muted">API Health</span>
                <div class="value-bold" style="color: var(--brand-green);">Stable</div>
            </div>
        </div>
    </div>

    <section class="section-container">
        <div class="section-head">
            <h2>Recent Activity</h2>
            <a href="{{ route('sellers.index') }}" class="btn-link-all">
                View All Merchants
                <i class="fas fa-external-link-alt" style="font-size: 10px;"></i>
            </a>
        </div>

        <div class="table-header-labels">
            <span>Merchant Identity</span>
            <span>Operating Location</span>
            <span>Registration</span>
            <span style="text-align: right;">Profile</span>
        </div>

        <div class="data-table-wrap">
            @foreach($recentSellers as $seller)
                <div class="data-row">
                    <div class="user-info">
                        <div class="avatar-lite">{{ strtoupper(substr($seller->full_name, 0, 1)) }}</div>

                        <div class="user-details">
                            <span class="text-name">{{ $seller->full_name }}</span>
                            <span class="text-sub">{{ $seller->email }}</span>

                            <div class="user-meta-compact">
                                <span>
                                    <i class="fas fa-map-marker-alt" style="color: var(--brand-green);"></i>
                                    {{ $seller->location ?? 'Global' }}
                                </span>
                                <span>
                                    <i class="far fa-calendar-alt"></i>
                                    {{ $seller->created_at->diffForHumans() }}
                                </span>
                            </div>
                        </div>
                    </div>

                    <div class="location-cell">
                        <span class="pill">
                            <i class="fas fa-map-marker-alt" style="color: var(--brand-green);"></i>
                            {{ $seller->location ?? 'Global' }}
                        </span>
                    </div>

                    <div class="date-cell">
                        <span class="text-date">{{ $seller->created_at->diffForHumans() }}</span>
                    </div>

                    <div class="action-cell">
                        <a href="{{ route('sellers.detail', $seller->id) }}" class="btn-view-profile" title="View Details">
                            <i class="fas fa-chevron-right"></i>
                        </a>
                    </div>
                </div>
            @endforeach
        </div>
    </section>
</div>
@endsection

@section('scripts')
<script>
    const AI_BACKEND_URL = 'https://coconut-ai-backend.onrender.com';
    const wakeBtn = document.getElementById('wake-btn');
    const statusEl = document.getElementById('ai-status');
    const dotEl = document.getElementById('ai-dot');
    const noteEl = document.getElementById('wake-note');

    function getDisplayStatus(rawStatus) {
        if (!rawStatus) return 'SLEEPING';
        const status = rawStatus.toLowerCase();

        if (status.includes('live')) return 'LIVE';
        if (status.includes('waking')) return 'WAKING UP';

        return 'SLEEPING';
    }

    function statusColor(displayStatus) {
        if (displayStatus === 'LIVE') return '#16a34a';
        if (displayStatus === 'WAKING UP') return '#38bdf8';

        return '#94a3b8';
    }

    function applyStatus(rawStatus) {
        if (!statusEl || !dotEl) return;

        const displayStatus = getDisplayStatus(rawStatus);
        const color = statusColor(displayStatus);

        statusEl.textContent = displayStatus;
        statusEl.style.color = color;
        dotEl.style.background = color;
        dotEl.style.boxShadow = `0 0 12px ${color}`;
    }

    async function wakeAi() {
        if (wakeBtn) {
            wakeBtn.disabled = true;
            wakeBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i><span>Pinging...</span>';
        }

        if (noteEl) noteEl.textContent = 'Syncing with Render...';

        try {
            const response = await fetch(`${AI_BACKEND_URL}/`, {
                method: 'GET',
                headers: { Accept: 'application/json' }
            });

            const data = await response.json();
            applyStatus(data.ai_model_status);

            if (noteEl) noteEl.textContent = 'Last synced: Just now';
        } catch (error) {
            applyStatus('SLEEPING');

            if (noteEl) noteEl.textContent = 'Backend unreachable';
        } finally {
            if (wakeBtn) {
                wakeBtn.disabled = false;
                wakeBtn.innerHTML = '<i class="fas fa-sync-alt"></i><span>Refresh</span>';
            }
        }
    }

    if (wakeBtn) {
        wakeBtn.addEventListener('click', wakeAi);
    }

    document.addEventListener('DOMContentLoaded', () => {
        wakeAi();
        setInterval(wakeAi, 120000);
    });
</script>
@endsection
