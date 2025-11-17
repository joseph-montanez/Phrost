<?php
// --- Configuration ---
use Phrost\IPCClient;

error_reporting(E_ALL);
ini_set("display_errors", "1");
ini_set("memory_limit", -1);

// --- Includes ---
require_once __DIR__ . "/vendor/autoload.php";

// --- Application Entry Point ---
gc_disable();

$client = new IPCClient();

try {
    // Load the game state if it exists
    if (is_file(__DIR__ . "/../save.data")) {
        Phrost_Wake(file_get_contents(__DIR__ . "/../save.data"));
    }
    // 1. Connect to the Swift server
    $client->connect();

    // 2. Run the main loop
    // This will call the 'Phrost_Update' function (from game-logic.php)
    // every frame until the connection is lost.
    $client->run("Phrost_Update");
} catch (Exception $e) {
    // Catch connection errors or other fatal exceptions
    echo "An error occurred: " . $e->getMessage() . "\n";
    error_log(
        "PHP Client Exception: " .
            $e->getMessage() .
            "\n" .
            $e->getTraceAsString(),
    );
} finally {
    // 3. Always disconnect gracefully
    $client->disconnect();
}
