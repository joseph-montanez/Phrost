<?php
// --- Configuration ---
// Show all errors, critical for debugging
error_reporting(E_ALL);
// Display errors directly in the output (don't use in production)
ini_set("display_errors", "1");
ini_set("memory_limit", -1);

// --- Includes ---
// Load the main Phrost bridge functions
require_once __DIR__ . "/phrost.php";
// Load all Phrost helper classes (e.g., Sprite, Window, Text)
foreach (glob(__DIR__ . "/Phrost/*.php") as $filename) {
    require_once $filename;
}

// Load the single source of truth for all game logic
require_once __DIR__ . "/sprite-animation.php";

// --- Application Entry Point ---
gc_disable();

// Access the $world array that was defined in game-logic.php
global $world;

// Start the Phrost engine!
// This calls into Swift, initializes SDL, and starts the main loop.
// It passes an empty string "" for the initial commands, because
// game-logic.php is designed to send its *own* initial commands
// on the first frame of Phrost_Update (using the "__initial_packer").
Phrost_Run("");
