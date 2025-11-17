<?php
// This file contains *only* your game's state and logic.

// --- Includes ---
foreach (glob(__DIR__ . "/Phrost/*.php") as $filename) {
    require_once $filename;
}

// --- Imports ---
// Import all necessary classes from the Phrost namespace
use Phrost\Audio;
use Phrost\Id;
use Phrost\Keycode;
use Phrost\Mod;
use Phrost\PackFormat;
use Phrost\Sprite;
use Phrost\Text;
use Phrost\Window;
use Phrost\ChannelPacker;
use Phrost\LiveReload;
use Phrost\Events;

// --- Constants ---
const FPS_SAMPLE_SIZE = 60;

// --- Global State Initialization ---
global $world, $shutdown_flag_path, $save_path;

$shutdown_flag_path = __DIR__ . "/../shutdown.flag";
$save_path = __DIR__ . "/../save.data";

$fontPath = __DIR__ . "/Roboto-Regular.ttf";
$audioPath = __DIR__ . "/snoozy beats - neon dreams.wav";

// Create Text objects
$fpsTextId = Id::generate();
$fpsText = new Text($fpsTextId[0], $fpsTextId[1]);
$fpsText->setFont($fontPath, 24.0);
$fpsText->setText("FPS: ...", false);
$fpsText->setPosition(10.0, 10.0, 100.0, false);
$fpsText->setColor(255, 255, 255, 255, false);

$logicTextId = Id::generate();
$logicText = new Text($logicTextId[0], $logicTextId[1]);
$logicText->setFont($fontPath, 24.0);
$logicText->setText("Logic: PHP", false);
$logicText->setPosition(10.0, 40.0, 100.0, false);
$logicText->setColor(255, 255, 255, 255, false);

// Create Audio object
$musicTrack = new Audio($audioPath);

$world = [
    "window" => new Window("Bunny Benchmark", 800, 450), // Initial window
    "sprites" => [], // The associative array of all Sprite objects
    "textObjects" => [
        // Store text objects
        "fps" => $fpsText,
        "logic" => $logicText,
    ],
    "musicTrack" => $musicTrack, // Store Audio object
    "spritesCount" => 0, // Total number of sprites
    "activeLogic" => "PHP", // Which logic is currently running: "PHP", "Zig", or "Rust"
    "pluginLoaded" => false, // If plugin is loaded
    "chunkSize" => 0, // (For debugging)
    "mouseX" => 0, // Last known mouse X
    "mouseY" => 0, // Last known mouse Y
    "fps" => 0.0, // Instantaneous FPS
    "smoothed_fps" => 0.0, // Smoothed FPS
    "fps_samples" => [], // Array of frame times for smoothing
    "musicPlaying" => false,
    "assetsLoaded" => false,
    "eventStacking" => true, // From main.php
    "liveReload" => new LiveReload($shutdown_flag_path, $save_path),
];

// Pack initial window setup (for both runners)
$world["__initial_packer"] = new Phrost\ChannelPacker();
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

    // Use @ to suppress warnings from corrupt data
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
 * This is the fully refactored main game loop function.
 */
function Phrost_Update(int $elapsed, float $dt, string $eventsBlob = ""): string
{
    global $world;

    //-- Live reloading feature ---
    /** @var LiveReload $live_reload */
    $live_reload = $world["liveReload"];
    $live_reload->poll($world["assetsLoaded"]);
    //---

    /** @var Window $window */
    $window = $world["window"];
    /** @var Audio $music */
    $music = $world["musicTrack"];
    /** @var Text $fpsText */
    $fpsText = $world["textObjects"]["fps"];
    /** @var Text $logicText */
    $logicText = $world["textObjects"]["logic"];

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

    $maxSprite = 50000;
    $events = PackFormat::unpack($eventsBlob);

    // --- Packer Setup ---
    // Use the pre-filled packer on the *first frame*, then create new ones.
    if (isset($world["__initial_packer"])) {
        $packer = $world["__initial_packer"];
        unset($world["__initial_packer"]); // Use it only once
    } else {
        $packer = new ChannelPacker();
    }

    // Check for deferred reset
    if ($live_reload->isResetPending()) {
        echo "Executing deferred reset. Sending remove commands.\n";
        $live_reload->reset($world, $packer);
        return $packer->finalize();
    }
    // ---

    // --- Initial Asset Loading ---
    if (!$world["assetsLoaded"]) {
        echo "Requesting audio load...\n";
        $music->load();
        $music->packDirtyEvents($packer);

        echo "Creating text sprites...\n";
        $fpsText->packDirtyEvents($packer); // Sends TEXT_ADD
        $logicText->packDirtyEvents($packer); // Sends TEXT_ADD

        // Initialize window size
        $window->setSize(800, 450);
        $window->packDirtyEvents($packer);

        $world["assetsLoaded"] = true;
    }

    // --- Window Title Update ---
    if ($world["activeLogic"] === "PHP") {
        $window->setTitle(
            sprintf(
                "Bunny Benchmark | Sprites: %d | FPS: %.0f",
                $world["spritesCount"],
                $world["smoothed_fps"],
            ),
        );
    }

    // --- Text Updates ---
    $fpsText->setText(sprintf("FPS: %.0f", $world["smoothed_fps"]));
    $fpsText->packDirtyEvents($packer); // Sends TEXT_SET_STRING if changed

    $logicText->setText("Logic: " . $world["activeLogic"]);
    $logicText->packDirtyEvents($packer); // Sends TEXT_SET_STRING if changed

    $window->packDirtyEvents($packer);

    // --- Input Event Handling ---
    $add_sprites = false;
    foreach ($events as $event) {
        if (!isset($event["type"])) {
            continue;
        }

        // --- Mouse Events ---
        if ($event["type"] === Events::INPUT_MOUSEMOTION->value) {
            $world["mouseX"] = $event["x"] ?? 0;
            $world["mouseY"] = $event["y"] ?? 0;
        }
        if ($event["type"] === Events::INPUT_MOUSEDOWN->value) {
            $add_sprites = true;
        }

        // --- Window Resize Event ---
        if ($event["type"] === Events::WINDOW_RESIZE->value) {
            var_dump($event);
            $world["window"]->setSize($event["w"], $event["h"]);
        }

        // --- Keyboard Events ---
        if ($event["type"] === Events::INPUT_KEYDOWN->value) {
            if (!isset($event["keycode"])) {
                continue;
            }

            // LiveReload hooks
            $live_reload->resetOnEvent($event, Keycode::R, Mod::CTRL);
            $live_reload->shutdownOnEvent($event, Keycode::Q, Mod::NONE);
            // ---

            if ($event["keycode"] === Keycode::A) {
                $add_sprites = true;
            }

            if ($event["keycode"] === Keycode::B) {
                $world["eventStacking"] = !$world["eventStacking"];
                echo "Turning PLUGIN_EVENT_STACKING " .
                    ($world["eventStacking"] ? "ON" : "OFF") .
                    "\n";
                $packer->add(Events::PLUGIN_EVENT_STACKING, [
                    $world["eventStacking"] ? 1 : 0,
                ]);
            }

            // Audio Controls
            if (
                $event["keycode"] === Keycode::P &&
                $music->isLoaded() &&
                !$world["musicPlaying"]
            ) {
                $music->play();
                $music->packDirtyEvents($packer);
                $world["musicPlaying"] = true;
                echo "Playing audio...\n";
            }
            if ($event["keycode"] === Keycode::O) {
                Audio::stopAll($packer);
                $world["musicPlaying"] = false;
                echo "Stopping all audio...\n";
            }

            // --- Plugin Toggle ---
            if ($event["keycode"] === Keycode::D) {
                if ($world["activeLogic"] === "Zig") {
                    $world["activeLogic"] = "PHP";
                } else {
                    $world["activeLogic"] = "Zig";
                }

                if (!$world["pluginLoaded"]) {
                    $libExtension = match (PHP_OS_FAMILY) {
                        "Darwin" => "libzig_phrost_plugin.dylib",
                        "Linux" => "libzig_phrost_plugin.so",
                        "Windows" => "zig_phrost_plugin.dll",
                        default => throw new \Exception(
                            "Unsupported OS: " . PHP_OS_FAMILY,
                        ),
                    };
                    $path = realpath(__DIR__ . "/" . $libExtension);
                    $packer->add(Phrost\Events::PLUGIN_LOAD, [
                        strlen($path),
                        $path,
                    ]);
                    $world["pluginLoaded"] = true;
                }
            }

            if ($event["keycode"] === Keycode::R) {
                // Note: This conflicts with CTRL+R for reload
                // 'R' for Rust
                echo "Loading Rust Plugin...\n";
                $libName = match (PHP_OS_FAMILY) {
                    "Darwin" => "librust_phrost_plugin.dylib",
                    "Linux" => "librust_phrost_plugin.so",
                    "Windows" => "rust_phrost_plugin.dll",
                    default => throw new \Exception(
                        "Unsupported OS: " . PHP_OS_FAMILY,
                    ),
                };
                $path = realpath(__DIR__ . "/" . $libName);

                if (!$path) {
                    echo "Error: Could not find Rust plugin at " .
                        __DIR__ .
                        "/../Plugins/rust-plugin/target/release/$libName\n";
                } else {
                    $packer->add(Phrost\Events::PLUGIN_LOAD, [
                        strlen($path),
                        $path,
                    ]);
                    $world["pluginLoaded"] = true;
                    $world["activeLogic"] = "Rust";
                }
            }

            if ($event["keycode"] === Keycode::M) {
                $packer->add(Phrost\Events::PLUGIN_UNLOAD, [1]);
                $world["activeLogic"] = "PHP";
            }

            // --- Debug Keys (Chunk Size) ---
            if ($event["keycode"] === Keycode::G) {
                $world["chunkSize"] += 10;
                echo "Chunk size increased to " . $world["chunkSize"] . "\n";
            }
            if ($event["keycode"] === Keycode::H) {
                $world["chunkSize"] = max(0, $world["chunkSize"] - 10);
                echo "Chunk size decreased to " . $world["chunkSize"] . "\n";
            }

            // Note: Keycode::Q is now handled by shutdownOnEvent
        } // End Keydown

        // --- Internal Event Handling ---

        if ($event["type"] === Events::SPRITE_TEXTURE_SET->value) {
            if (isset($event["id1"], $event["id2"], $event["textureId"])) {
                $key = Id::toHex([$event["id1"], $event["id2"]]);
                if (isset($world["sprites"][$key])) {
                    /** @var Sprite $sprite */
                    $sprite = $world["sprites"][$key];
                    $sprite->setTextureId($event["textureId"]);
                }
            } else {
                error_log("Received incomplete SPRITE_TEXTURE_SET event.");
            }
        }

        if ($event["type"] === Events::SPRITE_ADD->value) {
            $sprite = new Sprite($event["id1"], $event["id2"], false);
            $sprite->setPosition(
                $event["positionX"],
                $event["positionY"],
                $event["positionZ"],
                false,
            );
            $sprite->setScale(
                $event["scaleX"],
                $event["scaleY"],
                $event["scaleZ"],
                false,
            );
            $sprite->setSize($event["sizeW"], $event["sizeH"], false);
            $sprite->setRotate(
                $event["rotationX"],
                $event["rotationY"],
                $event["rotationZ"],
                false,
            );
            $sprite->setColor(
                $event["r"],
                $event["g"],
                $event["b"],
                $event["a"],
                false,
            );
            $sprite->setSpeed($event["speedX"], $event["speedY"], false);
            $key = Id::toHex([$sprite->id0, $sprite->id1]);
            $world["sprites"][$key] = $sprite;
            $world["spritesCount"]++;
        }

        if ($event["type"] === Events::SPRITE_MOVE->value) {
            $key = Id::toHex([$event["id1"], $event["id2"]]);
            $sprite = $world["sprites"][$key];
            $sprite->setPosition(
                $event["positionX"],
                $event["positionY"],
                $event["positionZ"],
                false,
            );
        }

        if ($event["type"] === Events::SPRITE_SPEED->value) {
            $key = Id::toHex([$event["id1"], $event["id2"]]);
            $sprite = $world["sprites"][$key];
            $sprite->setSpeed($event["speedX"], $event["speedY"], false);
        }

        if ($event["type"] === Events::AUDIO_LOADED->value) {
            /** @var $event array{audioId:int} */
            $music->setLoadedId($event["audioId"]);
            echo "Audio loaded with ID: " . $event["audioId"] . "\n";
        }
    } // End foreach event

    // --- Main Game Logic ---
    if ($world["activeLogic"] === "PHP") {
        $size = $world["window"]->getSize();
        foreach ($world["sprites"] as $sprite) {
            $sprite->update($dt);
            $pos = $sprite->getPosition();
            $speed = $sprite->getSpeed();
            $newSpeedX = $speed["x"];
            $newSpeedY = $speed["y"];
            $newPosX = $pos["x"];
            $newPosY = $pos["y"];

            $boundary_left = 12;
            $boundary_right = $size["width"] - 12;
            $boundary_top = 16;
            $boundary_bottom = $size["height"] - 16;
            $hotspot_offset_x = 16;
            $hotspot_offset_y = 16;
            $hotspot_x = $pos["x"] + $hotspot_offset_x;
            $hotspot_y = $pos["y"] + $hotspot_offset_y;

            if ($hotspot_x > $boundary_right) {
                $newSpeedX *= -1;
                $newPosX = $boundary_right - $hotspot_offset_x;
            } elseif ($hotspot_x < $boundary_left) {
                $newSpeedX *= -1;
                $newPosX = $boundary_left - $hotspot_offset_x;
            }

            if ($hotspot_y > $boundary_bottom) {
                $newSpeedY *= -1;
                $newPosY = $boundary_bottom - $hotspot_offset_y;
            } elseif ($hotspot_y < $boundary_top) {
                $newSpeedY *= -1;
                $newPosY = $boundary_top - $hotspot_offset_y;
            }

            if ($newSpeedX !== $speed["x"] || $newSpeedY !== $speed["y"]) {
                $sprite->setSpeed($newSpeedX, $newSpeedY);
            }
            if ($newPosX !== $pos["x"] || $newPosY !== $pos["y"]) {
                $sprite->setPosition($newPosX, $newPosY, $pos["z"]);
            }
            $sprite->packDirtyEvents($packer);
        }
        unset($sprite);
    }

    // --- Add Sprites Loop ---
    if ($world["activeLogic"] === "PHP") {
        if ($add_sprites && $world["spritesCount"] < $maxSprite) {
            $x = $world["mouseX"];
            $y = $world["mouseY"];
            for ($i = 0; $i < 1000; $i++) {
                $id = Id::generate();
                $sprite = new Sprite($id[0], $id[1]);
                $sprite->setPosition($x, $y, 0.0);
                $sprite->setSize(32.0, 32.0);
                $sprite->setColor(
                    rand(50, 240),
                    rand(80, 240),
                    rand(100, 240),
                    255,
                );
                $sprite->setSpeed(
                    (float) rand(-250, 250),
                    (float) rand(-250, 250),
                );
                $sprite->setTexturePath(__DIR__ . "/wabbit_alpha.png");
                $key = Id::toHex([$sprite->id0, $sprite->id1]);
                $world["sprites"][$key] = $sprite;
                $sprite->packDirtyEvents($packer);
            }
            $world["spritesCount"] += 1000;
        }
    }

    // --- Finalize & Return ---
    return $packer->finalize();
}
