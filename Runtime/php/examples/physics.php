<?php
// --- Configuration ---
error_reporting(E_ALL);
ini_set("display_errors", "1");

// --- Includes ---
foreach (glob(__DIR__ . "/Phrost/*.php") as $filename) {
    require_once $filename;
}

// --- Imports ---
use Phrost\Audio;
use Phrost\Id;
use Phrost\Keycode;
use Phrost\Mod;
use Phrost\PackFormat;
use Phrost\PhysicsBody;
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
$logicText->setText("Logic: Physics", false);
$logicText->setPosition(10.0, 40.0, 100.0, false);
$logicText->setColor(255, 255, 255, 255, false);

// Create static PhysicsBody objects for walls (position/shape set in Update)
$wallTop = new PhysicsBody(Id::generate()[0], Id::generate()[1]);
$wallBottom = new PhysicsBody(Id::generate()[0], Id::generate()[1]);
$wallLeft = new PhysicsBody(Id::generate()[0], Id::generate()[1]);
$wallRight = new PhysicsBody(Id::generate()[0], Id::generate()[1]);

$world = [
    "window" => new Window("Bunny Benchmark", 800, 450),
    "sprites" => [],
    "physicsBodies" => [], // Store physics bodies
    "textObjects" => [
        "fps" => $fpsText,
        "logic" => $logicText,
    ],
    "physicsWalls" => [
        "top" => $wallTop,
        "bottom" => $wallBottom,
        "left" => $wallLeft,
        "right" => $wallRight,
    ],
    "musicTrack" => new Audio($audioPath),
    "spritesCount" => 0,
    "chunkSize" => 0,
    "mouseX" => 0,
    "mouseY" => 0,
    "fps" => 0.0,
    "smoothed_fps" => 0.0,
    "fps_samples" => [],
    "musicPlaying" => false,
    "assetsLoaded" => false,
    "liveReload" => new LiveReload($shutdown_flag_path, $save_path),
];

// Pack initial window setup
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
 * This is the main game loop function, called once per frame by the Swift/SDL host.
 * (Functions and logic from the old entry point are merged here)
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
    /** @var Audio $music */
    $music = $world["musicTrack"];

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

    // --- Event Unpacking ---
    $events = PackFormat::unpack($eventsBlob);

    // Create a new ChannelPacker
    if (isset($world["__initial_packer"])) {
        $packer = $world["__initial_packer"];
        unset($world["__initial_packer"]);
    } else {
        $packer = new ChannelPacker($world["chunkSize"]);
    }

    // Check for deferred reset
    if ($live_reload->isResetPending()) {
        echo "Executing deferred reset. Sending remove commands.\n";
        $live_reload->reset($world, $packer);
        return $packer->finalize();
    }

    if (!$world["assetsLoaded"]) {
        // Use the Audio class to request the load
        echo "Requesting audio load...\n";
        $music->load(); // No packer needed, object tracks dirty state
        $music->packDirtyEvents($packer);

        // Pack the initial "add" events for our Text objects
        echo "Creating text sprites...\n";
        $world["textObjects"]["fps"]->packDirtyEvents($packer);
        $world["textObjects"]["logic"]->packDirtyEvents($packer);

        // --- ADD STATIC PHYSICS WALLS (using PhysicsBody class) ---
        echo "Adding physics walls...\n";
        $winSize = $world["window"]->getSize();
        $thickness = 100.0;
        $elasticity = 0.5; // Bounciness

        /** @var PhysicsBody $wall */
        // Top Wall
        $wall = $world["physicsWalls"]["top"];
        $wall->setPosition($winSize["width"] / 2.0, -$thickness / 2.0, false);
        $wall->setShape($winSize["width"], $thickness);
        $wall->setConfig(1, 0, 0.0, 0.0, $elasticity); // Static, Box
        $wall->packDirtyEvents($packer); // Sends PHYSICS_ADD_BODY

        // Bottom Wall
        $wall = $world["physicsWalls"]["bottom"];
        $wall->setPosition(
            $winSize["width"] / 2.0,
            $winSize["height"] + $thickness / 2.0,
            false,
        );
        $wall->setShape($winSize["width"], $thickness);
        $wall->setConfig(1, 0, 0.0, 0.0, $elasticity); // Static, Box
        $wall->packDirtyEvents($packer);

        // Left Wall
        $wall = $world["physicsWalls"]["left"];
        $wall->setPosition(-$thickness / 2.0, $winSize["height"] / 2.0, false);
        $wall->setShape($thickness, $winSize["height"]);
        $wall->setConfig(1, 0, 0.0, 0.0, $elasticity); // Static, Box
        $wall->packDirtyEvents($packer);

        // Right Wall
        $wall = $world["physicsWalls"]["right"];
        $wall->setPosition(
            $winSize["width"] + $thickness / 2.0,
            $winSize["height"] / 2.0,
            false,
        );
        $wall->setShape($thickness, $winSize["height"]);
        $wall->setConfig(1, 0, 0.0, 0.0, $elasticity); // Static, Box
        $wall->packDirtyEvents($packer);
        // --- End Physics Walls ---

        $world["assetsLoaded"] = true;
    }

    // --- Window Title Update ---
    $window->setTitle(
        sprintf(
            "Bunny Benchmark | Sprites: %d | FPS: %.0f",
            $world["spritesCount"],
            $world["smoothed_fps"],
        ),
    );

    // --- FPS Text Update ---
    /** @var Text $fpsText */
    $fpsText = $world["textObjects"]["fps"];
    $fpsText->setText(sprintf("FPS: %.0f", $world["smoothed_fps"]));
    $fpsText->packDirtyEvents($packer); // Sends TEXT_SET_STRING if changed

    // --- Logic Text Update ---
    /** @var Text $logicText */
    $logicText = $world["textObjects"]["logic"];
    $logicText->setText("Logic: Physics"); // Class handles not sending if unchanged
    $logicText->packDirtyEvents($packer);

    // Pack any window changes (e.g., title)
    $window->packDirtyEvents($packer);

    // --- Input Event Handling ---
    $add_sprites = false;

    foreach ($events as $event) {
        // --- Mouse Events ---
        if ($event["type"] === Events::INPUT_MOUSEMOTION->value) {
            $world["mouseX"] = $event["x"];
            $world["mouseY"] = $event["y"];
        }
        if ($event["type"] === Events::INPUT_MOUSEDOWN->value) {
            $add_sprites = true;
        }

        if ($event["type"] === Events::WINDOW_RESIZE->value) {
            $world["window"]->setSize($event["w"], $event["h"]);
            // TODO: You would need to update the wall positions/shapes here
        }

        // --- Keyboard Events ---
        if ($event["type"] === Events::INPUT_KEYDOWN->value) {
            // LiveReload hooks
            $live_reload->resetOnEvent($event, Keycode::R, Mod::CTRL);
            $live_reload->shutdownOnEvent($event, Keycode::Q, Mod::NONE);
            // ---

            if ($event["keycode"] === Keycode::A) {
                $add_sprites = true;
            }

            // Use Audio class
            if (
                $event["keycode"] === Keycode::P &&
                $music->isLoaded() &&
                !$world["musicPlaying"]
            ) {
                $music->play(); // No packer needed
                $music->packDirtyEvents($packer);
                $world["musicPlaying"] = true;
                echo "Playing audio...\n";
            }
            if ($event["keycode"] === Keycode::O) {
                Audio::stopAll($packer); // Use static method
                $world["musicPlaying"] = false;
                echo "Stopping all audio...\n";
            }
        }

        // --- Internal Event Handling ---
        if ($event["type"] === Events::SPRITE_TEXTURE_SET->value) {
            $key = Id::toHex([$event["id1"], $event["id2"]]);
            if (isset($world["sprites"][$key])) {
                /** @var Sprite $sprite */
                $sprite = $world["sprites"][$key];
                $sprite->setTextureId($event["textureId"]);
            }
        }

        // Use Audio class
        if ($event["type"] === Events::AUDIO_LOADED->value) {
            /** @var $event array{audioId:int} */
            $music->setLoadedId($event["audioId"]);
            echo "Audio loaded with ID: " . $event["audioId"] . "\n";
        }

        // --- Physics Event Handling ---
        if ($event["type"] === Events::PHYSICS_COLLISION_BEGIN->value) {
            $keyA = "{$event["id1_A"]}-{$event["id2_A"]}";
            $keyB = "{$event["id1_B"]}-{$event["id2_B"]}";

            if (
                isset($world["sprites"][$keyA]) ||
                isset($world["sprites"][$keyB])
            ) {
                // echo "Wabbit collision $keyA with $keyB detected!\n";
            }
        }

        // Handle Physics Sync for both Sprite and PhysicsBody
        if ($event["type"] === Events::PHYSICS_SYNC_TRANSFORM->value) {
            $key = Id::toHex([$event["id1"], $event["id2"]]);

            // Update the Sprite object (visuals)
            if (isset($world["sprites"][$key])) {
                /** @var Sprite $sprite */
                $sprite = $world["sprites"][$key];
                $sprite->setPosition(
                    $event["positionX"],
                    $event["positionY"],
                    $sprite->getPosition()["z"],
                    false, // Don't notify engine, prevent loop
                );
                $sprite->setRotation(0.0, 0.0, $event["rotationZ"], false);
            }

            // Update the PhysicsBody object (internal state)
            if (isset($world["physicsBodies"][$key])) {
                /** @var PhysicsBody $body */
                $body = $world["physicsBodies"][$key];
                $body->setPosition(
                    $event["positionX"],
                    $event["positionY"],
                    false,
                );
                $body->setRotation($event["rotationZ"], false);
            }
        }
    } // --- End Event Loop ---

    // --- Add Sprites Loop ---
    if ($add_sprites && $world["spritesCount"] < $maxSprite) {
        $x = $world["mouseX"];
        $y = $world["mouseY"];
        $max = 5;

        for ($i = 0; $i < $max; $i++) {
            $id = Id::generate();
            $key = Id::toHex([$id[0], $id[1]]);

            // --- 1. Create Sprite ---
            $sprite = new Sprite($id[0], $id[1]);
            $sprite->setPosition($x, $y, 0.0);
            $sprite->setSize(32.0, 32.0);
            $sprite->setColor(
                rand(50, 240),
                rand(80, 240),
                rand(100, 240),
                255,
            );
            $sprite->setTexturePath(__DIR__ . "/wabbit_alpha.png");

            // Set initial velocity
            $initialSpeedX = (float) rand(-250, 250);
            $initialSpeedY = (float) rand(-550, -250); // Shoot upwards
            $sprite->setSpeed($initialSpeedX, $initialSpeedY, false); // Store for logic, but don't pack

            // --- 2. Create PhysicsBody ---
            $body = new PhysicsBody($id[0], $id[1]);
            // Set properties *before* calling pack, using `false`
            $body->setPosition($x, $y, false);
            $body->setVelocity($initialSpeedX, $initialSpeedY, false);
            $body->setConfig(0, 0, 1.0, 0.5, 0.7); // Dynamic, Box, mass, friction, elasticity
            $body->setShape(32.0, 32.0);

            // --- 3. Store and Pack ---
            $world["sprites"][$key] = $sprite;
            $world["physicsBodies"][$key] = $body;

            // This packs SPRITE_ADD and SPRITE_TEXTURE_LOAD
            $sprite->packDirtyEvents($packer);
            // This packs PHYSICS_ADD_BODY and PHYSICS_SET_VELOCITY
            $body->packDirtyEvents($packer);
        }

        $world["spritesCount"] += $max;
    }

    // --- Finalize & Return ---
    $finalBlob = $packer->finalize();
    return $finalBlob;
}
