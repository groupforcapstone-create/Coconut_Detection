<div class="topbar-row">
    <div class="topbar-leading">
        <button
            type="button"
            class="topbar-toggle"
            data-sidebar-toggle
            aria-controls="sidebar"
            aria-expanded="true"
            aria-label="Toggle sidebar"
        >
            <i class="fas fa-bars"></i>
        </button>

        <div class="topbar-title-group">
            <span class="topbar-kicker">Admin Portal</span>
            <h1 class="topbar-title">@yield('page_title', 'Overview')</h1>
        </div>
    </div>

    <div class="topbar-trailing">
        

        <div class="topbar-user-badge">
            {{ strtoupper(substr(auth()->user()->full_name ?? 'A', 0, 1)) }}
        </div>
    </div>
</div>
