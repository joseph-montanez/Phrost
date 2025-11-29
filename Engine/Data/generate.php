<?php

// --- Autoload Adapters ---
require_once __DIR__ . "/LanguageAdapter.php";
require_once __DIR__ . "/AdapterHelpers.php";
foreach (glob(__DIR__ . "/adapters/*.php") as $filename) {
    require_once $filename;
}

// --- Configuration ---
$jsonFile = __DIR__ . "/structs.json";
$outputBaseDir = __DIR__ . "/out";

// --- Directories to ensure exist ---
$outputDirs = [
    $outputBaseDir . "/php",
    $outputBaseDir . "/swift",
    $outputBaseDir . "/zig",
    $outputBaseDir . "/c",
    $outputBaseDir . "/rust",
    $outputBaseDir . "/python",
];

// --- Main Execution ---
echo "Starting universal code generation...\n";

// --- Prepare output directories ---
echo "Checking output directories...\n";
foreach ($outputDirs as $dir) {
    if (!is_dir($dir)) {
        echo "Creating directory: {$dir}\n";
        if (!mkdir($dir, 0777, true)) {
            die("Error: Failed to create directory {$dir}\n");
        }
    }
}
// --- End directory prep ---

if (!file_exists($jsonFile)) {
    die("Error: {$jsonFile} not found.\n");
}

$jsonString = file_get_contents($jsonFile);
$data = json_decode($jsonString, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    die("Error parsing JSON: " . json_last_error_msg() . "\n");
}

$allStructs = $data["structs"];

// --- Prepare Data (Do this ONCE) ---
$allEnums = [];
$uniqueStructs = [];
$groupedStructs = [];

foreach ($allStructs as $struct) {
    // 1. Group by category
    $category = getCategory($struct["eventId"]);
    if (!isset($groupedStructs[$category])) {
        $groupedStructs[$category] = [];
    }
    $groupedStructs[$category][] = $struct;

    // 2. Get unique enums
    if (!isset($allEnums[$struct["eventId"]])) {
        $allEnums[$struct["eventId"]] = $struct["enumName"];
    }

    // 3. Get unique structs
    if (!isset($uniqueStructs[$struct["name"]])) {
        $uniqueStructs[$struct["name"]] = $struct;
    }
}

// Sort for clean output
ksort($allEnums, SORT_NUMERIC);
ksort($uniqueStructs, SORT_STRING);

// --- List of all adapters to run ---
$adapters = [
    new PhpAdapter(),
    new SwiftAdapter(),
    new ZigAdapter(),
    new CAdapter(),
    new RustAdapter(),
    new PythonAdapter(),
];

// --- Run Generation ---
foreach ($adapters as $adapter) {
    echo "Running " . get_class($adapter) . "...\n";
    $adapter->generate(
        $jsonFile,
        $allEnums,
        $uniqueStructs,
        $groupedStructs,
        $allStructs,
    );
}

echo "All generation complete.\n";

/**
 * Universal helper function. Maps an event ID to a category name.
 */
function getCategory(int $id): string
{
    if ($id >= 0 && $id < 100) {
        return "sprite";
    } // Includes Geometry
    if ($id >= 100 && $id < 200) {
        return "input";
    }
    if ($id >= 200 && $id < 300) {
        return "window";
    }
    if ($id >= 300 && $id < 400) {
        return "text";
    }
    if ($id >= 400 && $id < 500) {
        return "audio";
    }
    if ($id >= 500 && $id < 600) {
        return "physics";
    }
    if ($id >= 1000 && $id < 1100) {
        return "plugin";
    }
    if ($id >= 2000 && $id < 3000) {
        return "camera";
    }
    if ($id >= 3000 && $id < 4000) {
        return "script";
    }
    if ($id >= 4000 && $id < 5000) {
        return "ui";
    }
    return "unknown";
}
