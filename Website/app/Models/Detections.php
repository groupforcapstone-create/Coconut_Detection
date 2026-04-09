<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Detections extends Model
{
    use HasFactory;

    protected $table = 'detections';

    protected $fillable = [
        'variety_name',
        'confidence',
        'lifespan',
        'definition',
        'address',
    ];

    protected $casts = [
        'confidence' => 'float',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
