<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * This creates the 'sellers' table with all necessary columns.
     */
    public function up(): void
    {
        Schema::create('sellers', function (Blueprint $table) {
            $table->id();
            $table->string('full_name');
            
            // Unique email for login and identification
            $table->string('email')->unique();
            
            /** * Phone Number: 11 digits (e.g., 09289230563)
             * Stored as string to preserve the leading '0'.
             */
            $table->string('phone_number', 11)->unique(); 
            
            $table->string('location')->nullable();

            /**
             * FIX: Added profile_photo_path column.
             * This stores the string path to the image in the storage folder.
             * It is nullable because a user might not upload a photo immediately.
             */
            $table->string('profile_photo_path')->nullable();

            $table->string('password'); // Stores the Bcrypt hashed password
            $table->timestamps(); // Creates created_at and updated_at

            // Indexing phone_number for optimized login performance
            $table->index('phone_number');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sellers');
    }
};