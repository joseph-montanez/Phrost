<?php
// --- Configuration ---
error_reporting(E_ALL);
ini_set("display_errors", "1");

// --- Includes ---
foreach (glob(__DIR__ . "/Phrost/*.php") as $filename) {
    require_once $filename;
}

// --- Imports ---
use Phrost\Geometry;
use Phrost\Id;
use Phrost\Keycode;
use Phrost\Mod;
use Phrost\PackFormat;
use Phrost\Text;
use Phrost\Window;
use Phrost\Events;
use Phrost\ChannelPacker;
use Phrost\LiveReload;

// --- Constants ---
const FPS_SAMPLE_SIZE = 60;

// --- Global State Initialization ---
global $world, $shutdown_flag_path, $save_path;

$shutdown_flag_path = __DIR__ . "/../shutdown.flag";
$save_path = __DIR__ . "/../save.data";

$fontPath = __DIR__ . "/Roboto-Regular.ttf"; // Make sure this font exists

// Create Text objects for UI
$textObjects = [];
$textY = 10.0;
$textSpacing = 22.0;

$fpsTextId = Id::generate();
$fpsText = new Text($fpsTextId[0], $fpsTextId[1]);
$fpsText->setFont($fontPath, 18.0);
$fpsText->setText("FPS: ...", false);
$fpsText->setPosition(10.0, $textY, 100.0, false);
$textObjects["fps"] = $fpsText;
$textY += $textSpacing;

$logicTextId = Id::generate();
$logicText = new Text($logicTextId[0], $logicTextId[1]);
$logicText->setText("Logic: Geometry", false);
$logicText->setFont($fontPath, 18.0);
$logicText->setPosition(10.0, $textY, 100.0, false);
$textObjects["logic"] = $logicText;
$textY += $textSpacing + 10;

// Help Text
$help1Id = Id::generate();
$help1 = new Text($help1Id[0], $help1Id[1]);
$help1->setFont($fontPath, 16.0);
$help1->setText("[Click] to add a Point", false);
$help1->setPosition(10.0, $textY, 100.0, false);
$textObjects["help1"] = $help1;
$textY += $textSpacing;

$help2Id = Id::generate();
$help2 = new Text($help2Id[0], $help2Id[1]);
$help2->setFont($fontPath, 16.0);
$help2->setText("[L] to add a Line", false);
$help2->setPosition(10.0, $textY, 100.0, false);
$textObjects["help2"] = $help2;
$textY += $textSpacing;

$help3Id = Id::generate();
$help3 = new Text($help3Id[0], $help3Id[1]);
$help3->setFont($fontPath, 16.0);
$help3->setText("[B] to add a Box (Rect)", false);
$help3->setPosition(10.0, $textY, 100.0, false);
$textObjects["help3"] = $help3;
$textY += $textSpacing;

$help4Id = Id::generate();
$help4 = new Text($help4Id[0], $help4Id[1]);
$help4->setFont($fontPath, 16.0);
$help4->setText("[C] for new Colors, [R] to Remove all", false);
$help4->setPosition(10.0, $textY, 100.0, false);
$textObjects["help4"] = $help4;
$textY += $textSpacing;

// <-- NEW HELP TEXT -->
$help5Id = Id::generate();
$help5 = new Text($help5Id[0], $help5Id[1]);
$help5->setFont($fontPath, 16.0);
$help5->setText("[U] to add a Screen-Space UI Rect", false);
$help5->setPosition(10.0, $textY, 100.0, false);
$textObjects["help5"] = $help5;

$world = [
    "window" => new Window("Geometry Demo", 800, 600),
    "textObjects" => $textObjects,
    "geometry" => [], // Store all our geometry objects here
    "chunkSize" => 0,
    "mouseX" => 0,
    "mouseY" => 0,
    "fps" => 0.0,
    "smoothed_fps" => 0.0,
    "fps_samples" => [],
    "assetsLoaded" => false,
    "liveReload" => new LiveReload($shutdown_flag_path, $save_path),
];

// [NEW] Pack initial window setup
$world["__initial_packer"] = new ChannelPacker();
$world["window"]->setResizable(true);
$world["window"]->packDirtyEvents($world["__initial_packer"]);
// --- End Global State ---

/**
 * Called by Phrost when the PHP state is about to be saved.
 */
function Phrost_Sleep(): string
{
    global $world;
    unset($world["__initial_packer"]);
    return serialize($world);
}

/**
 * Called by Phrost to restore the PHP state.
 */
function Phrost_Wake(string $data): void
{
    global $world, $save_path, $shutdown_flag_path;

    $existing_world = @unserialize($data);

    if ($existing_world === false && $data !== serialize(false)) {
        echo "Failed to unserialize saved data. It may be corrupt. Starting fresh.\n";
        if (is_file($save_path)) {
            unlink($save_path);
        }
    } else {
        $world = $existing_world;
        echo "World state restored.\n";
    }

    // Re-initialize transient objects
    if (!isset($world["liveReload"])) {
        $world["liveReload"] = new LiveReload($shutdown_flag_path, $save_path);
    } else {
        $world["liveReload"]->setPaths($shutdown_flag_path, $save_path);
    }
}

/**
 * This is the main game loop function.
 */
function Phrost_Update(int $elasped, float $dt, string $eventsBlob = ""): string
{
    global $world;

    //-- Live reloading feature ---
    /** @var LiveReload $live_reload */
    $live_reload = $world["liveReload"];
    $live_reload->poll($world["assetsLoaded"]);
    //---

    /** @var Window $window */
    $window = $world["window"];

    // --- FPS Calculation ---
    if ($dt > 0) {
        $world["fps"] = 1.0 / $dt;
        $world["fps_samples"][] = $dt;
        if (count($world["fps_samples"]) > FPS_SAMPLE_SIZE) {
            array_shift($world["fps_samples"]);
        }
        $average_dt =
            array_sum($world["fps_samples"]) / count($world["fps_samples"]);
        $world["smoothed_fps"] = 1.0 / $average_dt;
    }

    // --- Event Unpacking ---
    $events = PackFormat::unpack($eventsBlob);

    // Create a new ChannelPacker
    if (isset($world["__initial_packer"])) {
        $packer = $world["__initial_packer"];
        unset($world["__initial_packer"]);
    } else {
        $packer = new ChannelPacker();
    }

    // [NEW] Check for deferred reset
    if ($live_reload->isResetPending()) {
        echo "Executing deferred reset. Sending remove commands.\n";
        $live_reload->reset($world, $packer);
        return $packer->finalize();
    }
    // ---

    if (!$world["assetsLoaded"]) {
        echo "Creating text objects...\n";
        // Pack the initial "add" events for our Text objects
        $world["textObjects"]["fps"]->packDirtyEvents($packer);
        $world["textObjects"]["logic"]->packDirtyEvents($packer);
        $world["textObjects"]["help1"]->packDirtyEvents($packer);
        $world["textObjects"]["help2"]->packDirtyEvents($packer);
        $world["textObjects"]["help3"]->packDirtyEvents($packer);
        $world["textObjects"]["help4"]->packDirtyEvents($packer);
        $world["textObjects"]["help5"]->packDirtyEvents($packer); // <-- ADDED

        // --- Add a static line and rect ---
        echo "Adding initial geometry...\n";
        $winSize = $world["window"]->getSize();

        // Add a line across the top
        $id = Id::generate();
        $key = Id::toHex([$id[0], $id[1]]);
        $line = new Geometry($id[0], $id[1]);
        $line->setLine(10, 150, $winSize["width"] - 10, 150);
        $line->setColor(255, 0, 0, 255, false); // Red
        $line->setZ(-1.0);
        $world["geometry"][$key] = $line;

        // Add a filled rect
        $id = Id::generate();
        $key = Id::toHex([$id[0], $id[1]]);
        $rect = new Geometry($id[0], $id[1]);
        $rect->setRect(10, 160, 100, 50, true); // Filled rect
        $rect->setColor(0, 0, 255, 128, false); // Blue, semi-transparent
        $world["geometry"][$key] = $rect;

        $world["assetsLoaded"] = true;
    }

    // --- Window Title Update ---
    $window->setTitle(
        sprintf(
            "Geometry Demo | Primitives: %d | FPS: %.0f",
            count($world["geometry"]),
            $world["smoothed_fps"],
        ),
    );

    // --- FPS Text Update ---
    /** @var Text $fpsText */
    $fpsText = $world["textObjects"]["fps"];
    $fpsText->setText(sprintf("FPS: %.0f", $world["smoothed_fps"]));
    $fpsText->packDirtyEvents($packer); // Sends TEXT_SET_STRING if changed

    // Pack any window changes (e.g., title)
    $window->packDirtyEvents($packer);

    // --- Input Event Handling ---
    foreach ($events as $event) {
        // --- Mouse Events ---
        if ($event["type"] === Events::INPUT_MOUSEMOTION->value) {
            $world["mouseX"] = $event["x"];
            $world["mouseY"] = $event["y"];
        }
        if ($event["type"] === Events::INPUT_MOUSEDOWN->value) {
            // Add a new point where the user clicked
            $id = Id::generate();
            $key = Id::toHex([$id[0], $id[1]]);
            $point = new Geometry($id[0], $id[1]);
            $point->setPoint($event["x"], $event["y"]);
            $point->setColor(255, 255, 0, 255, false); // Yellow
            $world["geometry"][$key] = $point;
        }

        if ($event["type"] === Events::WINDOW_RESIZE->value) {
            $world["window"]->setSize($event["w"], $event["h"]);
        }

        // --- Keyboard Events ---
        if ($event["type"] === Events::INPUT_KEYDOWN->value) {
            // [NEW] LiveReload hooks
            $live_reload->resetOnEvent($event, Keycode::R, Mod::CTRL); // Note: 'R' is now Ctrl+R
            $live_reload->shutdownOnEvent($event, Keycode::Q, Mod::NONE);
            // ---

            // 'C' -> Change Color
            if ($event["keycode"] === Keycode::C) {
                // Change all geometry to a new random color
                foreach ($world["geometry"] as $geom) {
                    /** @var Geometry $geom */
                    $geom->setColor(
                        rand(50, 255),
                        rand(50, 255),
                        rand(50, 255),
                        255,
                    );
                }
                echo "GEOM_SET_COLOR event(s) queued.\n";
            }

            // 'R' -> Remove All (Note: this is now R without Ctrl)
            if ($event["keycode"] === Keycode::R) {
                // Remove all geometry
                foreach ($world["geometry"] as $geom) {
                    /** @var Geometry $geom */
                    $geom->remove($packer); // Queues GEOM_REMOVE event
                }
                $world["geometry"] = []; // Clear from our state
                echo "GEOM_REMOVE event(s) queued.\n";
            }

            // 'L' -> Add a random line
            if ($event["keycode"] === Keycode::L) {
                $winSize = $world["window"]->getSize();
                $id = Id::generate();
                $key = Id::toHex([$id[0], $id[1]]);
                $line = new Geometry($id[0], $id[1]);
                $line->setLine(
                    rand(0, $winSize["width"]),
                    rand(0, $winSize["height"]),
                    rand(0, $winSize["width"]),
                    rand(0, $winSize["height"]),
                );
                $line->setColor(0, 255, 0, 255, false); // Green
                $world["geometry"][$key] = $line;
            }

            // 'B' -> Add a random Box (Rect)
            if ($event["keycode"] === Keycode::B) {
                $winSize = $world["window"]->getSize();
                $id = Id::generate();
                $key = Id::toHex([$id[0], $id[1]]);
                $rect = new Geometry($id[0], $id[1]);
                $rect->setRect(
                    rand(0, $winSize["width"] - 50),
                    rand(0, $winSize["height"] - 50),
                    rand(10, 80),
                    rand(10, 80),
                    (bool) rand(0, 1), // 50/50 filled or outline
                );
                $rect->setColor(255, 0, 255, 200, false); // Magenta
                $world["geometry"][$key] = $rect;
            }

            // 'U' -> Add a UI (Screen-Space) Rect
            if ($event["keycode"] === Keycode::U) {
                $id = Id::generate();
                $key = Id::toHex([$id[0], $id[1]]);
                $uiRect = new Geometry($id[0], $id[1]);
                $uiRect->setRect(10, 275, 250, 50, true); // Filled rect
                $uiRect->setColor(255, 255, 255, 50, false); // Faint white
                $uiRect->setZ(99.0); // Draw on top of text
                $uiRect->setIsScreenSpace(true); // <-- SET THE FLAG
                $world["geometry"][$key] = $uiRect;
                echo "Added screen-space UI rect.\n";
            }
        }
    } // --- End Event Loop ---

    // --- Pack Geometry Events ---
    // This is key: the Geometry class handles its own dirty flags.
    // On first frame, it sends GEOM_ADD_*
    // When we call $geom->setColor(), it sets a dirty flag and sends GEOM_SET_COLOR
    foreach ($world["geometry"] as $geom) {
        $geom->packDirtyEvents($packer);
    }

    // --- Finalize & Return ---
    $finalBlob = $packer->finalize();
    return $finalBlob;
}
