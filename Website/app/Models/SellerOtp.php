<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SellerOtp extends Model
{
    protected $table = 'seller_otps';

    protected $fillable = [
        'phone_number',
        'purpose',
        'code_hash',
        'expires_at',
        'consumed_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
