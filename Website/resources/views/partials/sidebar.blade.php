<aside id="sidebar" class="sidebar-panel" aria-label="Sidebar navigation">
    <div class="sidebar-inner">
        <button type="button" class="sidebar-mobile-close" data-sidebar-close aria-label="Close sidebar">
            <i class="fas fa-times"></i>
        </button>

        <div class="sidebar-user-card">
            <div class="sidebar-avatar">
                {{ strtoupper(substr(auth()->user()->full_name ?? 'A', 0, 1)) }}
            </div>
            <div class="sidebar-profile-copy">
                <strong>{{ auth()->user()->full_name ?? 'Admin' }}</strong>
                <span>System Admin</span>
            </div>
        </div>

        <span class="sidebar-section-label">Navigation</span>

        <nav class="sidebar-nav">
            <a href="{{ route('dashboard') }}" class="sidebar-link {{ request()->routeIs('dashboard') ? 'active' : '' }}">
                <i class="fas fa-chart-pie"></i>
                <span class="sidebar-link-label">Dashboard</span>
            </a>

            <a href="{{ route('detections.index') }}" class="sidebar-link {{ request()->routeIs('detections.*') ? 'active' : '' }}">
                <i class="fas fa-robot"></i>
                <span class="sidebar-link-label">AI Model</span>
            </a>

            <a href="{{ route('sellers.index') }}" class="sidebar-link {{ request()->routeIs('sellers.*') ? 'active' : '' }}">
                <i class="fas fa-store-alt"></i>
                <span class="sidebar-link-label">Sellers</span>
            </a>
        </nav>
        
        <div class="sidebar-footer">
            <form action="{{ route('logout') }}" method="POST">
                @csrf
                <button type="submit" class="logout-btn-final">
                    <i class="fas fa-power-off"></i>
                    <span class="sidebar-link-label">Log Out</span>
                </button>
            </form>
        </div>
    </div>
</aside>
