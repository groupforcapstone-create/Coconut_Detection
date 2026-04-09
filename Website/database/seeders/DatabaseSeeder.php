<?php

namespace Database\Seeders;

// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        DB::table('users')->updateOrInsert(
            ['email' => 'groupforcapstone@gmail.com'],
            [
                'full_name' => 'Default Admin',
                'password' => Hash::make('admin@123'),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        DB::table('users')->updateOrInsert(
            ['email' => 'jamesyacolicol@gmail.com'],
            [
                'full_name' => 'Default Admin',
                'password' => Hash::make('admin@123'),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );



    }
}
