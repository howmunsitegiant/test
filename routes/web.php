<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Health check endpoint for ECS/Docker
Route::get('/health', function () {
    return response()->json(['status' => 'ok'], 200);
});
