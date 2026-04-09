<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Products extends Model 
{
    use HasFactory;

    /**
     * The table associated with the model.
     * Ensure this matches your migration (usually 'products').
     */
    protected $table = 'products';

    /**
     * The attributes that are mass assignable.
     * FIX: 'location' is now included to match your new migration.
     */
    protected $fillable = [
        'seller_id',
        'coconut_variety',
        'lifespan',
        'definition',
        'price',
        'quantity',
        'location',
        'image_path',
        'is_active',
    ];

    /**
     * The attributes that should be cast.
     */
    protected $casts = [
        'price' => 'decimal:2',
        'quantity' => 'integer',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Automatically append these to JSON responses (useful for Flutter).
     */
    protected $appends = [
        'image_url',
    ];

    /**
     * RELATIONSHIP: Product belongs to a Seller.
     * Matches the 'Sellers' model class and 'seller_id' foreign key.
     */
    public function seller(): BelongsTo
    {
        return $this->belongsTo(Sellers::class, 'seller_id');
    }

    /**
     * ACCESSOR: Full Image URL.
     * FIX: Cleans the path to ensure we never get 'storage/storage/'
     */
    public function getImageUrlAttribute(): ?string
    {
        if (!$this->image_path) {
            return null;
        }

        // Remove any accidental 'storage/' prefix before prepending the asset link
        $cleanPath = str_replace('storage/', '', $this->image_path);
        
        return asset('storage/' . $cleanPath);
    }
}