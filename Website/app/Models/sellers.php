<?php

namespace App\Models;

// Using Authenticatable allows this model to handle API tokens and login logic
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Sellers extends Authenticatable 
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The table associated with the model.
     */
    protected $table = 'sellers';

    /**
     * The attributes that are mass assignable.
     * * FIX: Added 'profile_photo_path'. Without this, Laravel blocks 
     * the image URL sent from Flutter for security reasons.
     */
    protected $fillable = [
        'full_name',
        'email',
        'phone_number',
        'location',
        'password',
        'profile_photo_path', // <--- REQUIRED to save your uploaded photo
    ];

    /**
     * The attributes that should be hidden for serialization.
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * The attributes that should be cast.
     */
    protected $casts = [
        'password' => 'hashed',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * RELATIONSHIP: One Seller has Many Products.
     * * FIX: Check your database 'products' table. If the owner column 
     * is named 'user_id', change 'seller_id' below to 'user_id'.
     */
    public function products(): HasMany
    {
        // This links the Seller ID to the products they posted
        return $this->hasMany(Products::class, 'seller_id');
    }

    /**
     * RELATIONSHIP: One Seller has Many Scan Histories.
     */
    public function scanHistories(): HasMany
    {
        return $this->hasMany(ScanHistory::class, 'seller_id');
    }
}
