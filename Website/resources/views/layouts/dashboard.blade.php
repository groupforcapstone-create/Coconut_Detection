<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('page_title', 'Admin') | Coconut Admin</title>
    <link rel="icon" type="image/png" href="{{ asset('coconut.png') }}">
    <link rel="shortcut icon" href="{{ asset('coconut.png') }}">
    <link rel="apple-touch-icon" href="{{ asset('coconut.png') }}">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Manrope:wght@400;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <link rel="stylesheet" href="{{ asset('css/admin-dashboard.css') }}">
    @yield('head')
</head>
<body class="admin-shell @yield('body_class')">
    <div class="app-shell">
        @include('partials.sidebar')

        <div class="main-container">
            <nav class="topbar">
                @include('partials.navbar')
            </nav>

            <main class="content-body">
                @yield('content')
            </main>
        </div>
    </div>

    <button type="button" class="sidebar-overlay" data-sidebar-close aria-label="Close sidebar"></button>

    <script>
        (() => {
            const body = document.body;
            const desktopQuery = window.matchMedia('(min-width: 1025px)');
            const toggleButtons = document.querySelectorAll('[data-sidebar-toggle]');
            const closeButtons = document.querySelectorAll('[data-sidebar-close]');
            const storageKey = 'coconut-admin-sidebar-collapsed';

            function getExpandedState() {
                return desktopQuery.matches
                    ? !body.classList.contains('sidebar-collapsed')
                    : body.classList.contains('sidebar-open');
            }

            function syncAria() {
                const expanded = getExpandedState();
                toggleButtons.forEach((button) => {
                    button.setAttribute('aria-expanded', expanded ? 'true' : 'false');
                });
            }

            function closeMobileSidebar() {
                body.classList.remove('sidebar-open');
                syncAria();
            }

            function syncSidebarMode() {
                if (desktopQuery.matches) {
                    body.classList.remove('sidebar-open');
                    const collapsed = window.localStorage.getItem(storageKey) === 'true';
                    body.classList.toggle('sidebar-collapsed', collapsed);
                } else {
                    body.classList.remove('sidebar-collapsed');
                }

                syncAria();
            }

            function toggleSidebar() {
                if (desktopQuery.matches) {
                    const nextCollapsed = !body.classList.contains('sidebar-collapsed');
                    body.classList.toggle('sidebar-collapsed', nextCollapsed);
                    window.localStorage.setItem(storageKey, nextCollapsed ? 'true' : 'false');
                } else {
                    body.classList.toggle('sidebar-open');
                }

                syncAria();
            }

            toggleButtons.forEach((button) => {
                button.addEventListener('click', toggleSidebar);
            });

            closeButtons.forEach((button) => {
                button.addEventListener('click', closeMobileSidebar);
            });

            document.addEventListener('keydown', (event) => {
                if (event.key === 'Escape' && body.classList.contains('sidebar-open')) {
                    closeMobileSidebar();
                }
            });

            desktopQuery.addEventListener('change', syncSidebarMode);
            window.addEventListener('resize', syncAria);
            document.addEventListener('DOMContentLoaded', syncSidebarMode);
            syncSidebarMode();
        })();
    </script>
    @yield('scripts')
</body>
</html>
