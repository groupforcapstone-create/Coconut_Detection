<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            
            // Link to the sellers table
            $table->foreignId('seller_id')->constrained('sellers')->cascadeOnDelete();
            
            $table->string('coconut_variety');
            $table->string('lifespan');
            $table->text('definition');
            $table->decimal('price', 10, 2);
            $table->unsignedInteger('quantity');

            /**
             * THE FULL FIX: Added 'location' column.
             * This matches the 'location' key being sent by your Flutter logic.
             */
            $table->string('location')->nullable();

            $table->string('image_path')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};