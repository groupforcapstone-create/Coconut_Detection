<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint; // <--- Siguraduhin na nandito ito
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Palitan ang (Table $table) ng (Blueprint $table)
        Schema::create('detections', function (Blueprint $table) {
            $table->id();
            $table->string('variety_name');
            $table->float('confidence');
            $table->string('lifespan')->nullable();
            $table->text('definition')->nullable();
            $table->string('address')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('detections');
    }
};