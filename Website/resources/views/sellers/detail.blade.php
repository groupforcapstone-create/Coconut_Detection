@extends('layouts.dashboard')

@section('page_title', 'Seller Profile: ' . $seller->full_name)
@section('body_class', 'page-seller-detail')

@section('content')
<div class="profile-container">
    <div class="top-nav">
        <a href="{{ route('sellers.index') }}" class="btn-back">
            <i class="fas fa-arrow-left"></i>
            Back to Directory
        </a>

        <span class="top-nav-label">Secure Admin Portal</span>
    </div>

    <div class="hero-card">
        <div class="hero-avatar">
            @if($seller->profile_photo_path)
                @php
                    $cleanPath = str_replace(['storage/', 'public/'], '', $seller->profile_photo_path);
                    $finalUrl = asset('storage/' . $cleanPath);
                @endphp

                <img
                    src="{{ $finalUrl }}"
                    alt="Profile"
                    onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name={{ urlencode($seller->full_name) }}&background=16a34a&color=fff';"
                >
            @else
                {{ strtoupper(substr($seller->full_name, 0, 1)) }}
            @endif
        </div>

        <div class="hero-info">
            <div class="verify-pill">
                <i class="fas fa-check-circle"></i>
                Verified Merchant
            </div>

            <h2>{{ $seller->full_name }}</h2>
            <p class="hero-meta">Member since {{ $seller->created_at->format('F Y') }}</p>
        </div>
    </div>

    <div class="stats-grid">
        <div class="stat-box">
            <div class="stat-icon"><i class="fas fa-envelope"></i></div>
            <label>Email Address</label>
            <p>{{ $seller->email }}</p>
        </div>

        <div class="stat-box">
            <div class="stat-icon"><i class="fas fa-phone-alt"></i></div>
            <label>Phone Number</label>
            <p>{{ $seller->phone_number ?? 'Not Provided' }}</p>
        </div>

        <div class="stat-box">
            <div class="stat-icon"><i class="fas fa-map-marker-alt"></i></div>
            <label>Store Location</label>
            <p>{{ $seller->location ?? 'Global' }}</p>
        </div>

        <div class="stat-box">
            <div class="stat-icon"><i class="fas fa-fingerprint"></i></div>
            <label>Merchant ID</label>
            <p>#{{ str_pad($seller->id, 4, '0', STR_PAD_LEFT) }}</p>
        </div>
    </div>

    <div class="section-title">
        <i class="fas fa-seedling" style="color: var(--brand-green);"></i>
        <span>Seedling Inventory</span>
        <span class="inventory-count-pill">{{ $seller->products->count() }} Items</span>
    </div>

    @forelse($seller->products as $product)
        <div class="product-card">
            <div class="img-wrapper">
                @if($product->image_path)
                    @php
                        $productPath = str_replace('storage/', '', $product->image_path);
                    @endphp

                    <img
                        src="{{ asset('storage/' . $productPath) }}"
                        alt="Seedling"
                        onerror="this.onerror=null; this.src='https://placehold.co/400x300?text=No+Image';"
                    >
                @else
                    <div style="height: 100%; display: flex; align-items: center; justify-content: center; background: #f1f5f9; color: #cbd5e1;">
                        <i class="fas fa-image fa-3x"></i>
                    </div>
                @endif
            </div>

            <div class="product-content">
                <div class="variety-name">{{ $product->coconut_variety }}</div>
                <p class="product-desc">{{ Str::limit($product->definition, 120) }}</p>

                <div class="meta-tags">
                    <div class="tag">
                        <i class="fas fa-hourglass-half"></i>
                        {{ $product->lifespan }}
                    </div>

                    <div class="tag">
                        <i class="fas fa-map-marker-alt"></i>
                        {{ $product->location }}
                    </div>
                </div>
            </div>

            <div class="price-side">
                <span class="price-label">Unit Price</span>
                <div class="price-value">₱{{ number_format($product->price, 2) }}</div>
                <div class="stock-pill">In Stock: <b>{{ $product->quantity }}</b></div>
            </div>
        </div>
    @empty
        <div class="empty-products">
            <i class="fas fa-box-open fa-3x" style="color: #cbd5e1; margin-bottom: 20px; display: block;"></i>
            <p>No products found for this seller.</p>
        </div>
    @endforelse
</div>
@endsection
