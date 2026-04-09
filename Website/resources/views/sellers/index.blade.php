@extends('layouts.dashboard')

@section('page_title', 'Sellers Directory')
@section('body_class', 'page-sellers-directory')

@section('head')
<link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
@endsection

@section('content')
<div class="directory-container">
    <header class="directory-header">
        <div>
            <h1>Sellers Directory</h1>
            <p class="text-muted">Manage and monitor your verified merchant network.</p>
        </div>

        <div class="directory-summary">
            <span class="directory-summary-label">{{ $search ? 'Search Results' : 'Active Partners' }}</span>
            <span class="directory-summary-value">{{ $sellers->total() }}</span>
        </div>
    </header>

    <form method="GET" action="{{ route('sellers.index') }}" class="directory-search-bar">
        <div class="directory-search-input-wrap">
            <i class="fas fa-search directory-search-icon"></i>
            <input
                type="text"
                name="search"
                value="{{ $search }}"
                class="directory-search-input"
                placeholder="Search seller name, email, location, or phone"
                aria-label="Search sellers"
            >
        </div>

        <button type="submit" class="directory-search-btn">
            <i class="fas fa-search"></i>
            <span>Search</span>
        </button>

        @if($search)
            <a href="{{ route('sellers.index') }}" class="directory-search-clear">
                <i class="fas fa-times"></i>
                <span>Clear</span>
            </a>
        @endif
    </form>

    @if($search)
        <div class="directory-search-meta">
            Showing results for <strong>"{{ $search }}"</strong>
        </div>
    @endif

    <div class="table-surface">
        <div class="directory-table-wrap">
            <table class="directory-table">
                <thead>
                    <tr>
                        <th width="80">#</th>
                        <th>Merchant Identity</th>
                        <th>Operating Location</th>
                        <th>Join Date</th>
                        <th style="text-align: right; padding-right: 30px;">Management</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($sellers as $seller)
                        <tr>
                            <td data-label="ID">
                                <span class="ref-badge">
                                    {{ str_pad($loop->iteration + ($sellers->currentPage() - 1) * $sellers->perPage(), 2, '0', STR_PAD_LEFT) }}
                                </span>
                            </td>

                            <td data-label="Merchant">
                                <div class="directory-merchant">
                                    <div class="initial-avatar">{{ strtoupper(substr($seller->full_name, 0, 1)) }}</div>

                                    <div class="directory-merchant-copy">
                                        <a href="{{ route('sellers.detail', $seller->id) }}" class="merchant-link">{{ $seller->full_name }}</a>
                                        <div class="text-muted">{{ $seller->email }}</div>
                                    </div>
                                </div>
                            </td>

                            <td data-label="Location">
                                <div class="directory-location">
                                    <i class="fas fa-map-marker-alt" style="color: var(--brand-green);"></i>
                                    <span>{{ $seller->location ?? 'Global' }}</span>
                                </div>
                            </td>

                            <td data-label="Joined">
                                <div class="directory-date">
                                    <i class="far fa-calendar-alt"></i>
                                    <span>{{ $seller->created_at->format('M d, Y') }}</span>
                                </div>
                            </td>

                            <td data-label="Actions" style="text-align: right; padding-right: 24px;">
                                <div class="directory-actions">
                                    <a href="{{ route('sellers.detail', $seller->id) }}" class="btn-profile">
                                        <i class="fas fa-user-cog"></i>
                                        View Profile
                                    </a>

                                    <form action="{{ route('sellers.destroy', $seller->id) }}" method="POST" onsubmit="return confirm('Archive this merchant? This action will remove them from the active directory.')">
                                        @csrf
                                        @method('DELETE')

                                        <button type="submit" class="btn-delete-lite" title="Delete Merchant">
                                            <i class="fas fa-trash-alt"></i>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5">
                                <div class="empty-state">
                                    <i class="fas fa-users-slash" style="font-size: 40px; color: var(--border); margin-bottom: 15px; display: block;"></i>
                                    <p>{{ $search ? 'No sellers matched your search.' : 'No merchant partners found in the registry.' }}</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <div class="pagination-wrapper">
        {{ $sellers->links() }}
    </div>
</div>
@endsection
