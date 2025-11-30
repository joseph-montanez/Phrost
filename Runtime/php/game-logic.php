<?php

use Game\Warrior;
use Game\WarriorBody;
use Phrost\Camera;
use Phrost\ChannelPacker;
use Phrost\Events;
use Phrost\Id;
use Phrost\Keycode;
use Phrost\LiveReload;
use Phrost\Mod;
use Phrost\PackFormat;
use Phrost\Sprite;
use Phrost\SpriteAnimated;
use Phrost\Tiled;
use Phrost\Window;
use Phrost\UI;
use Phrost\PhysicsBody;

// --- Constants ---
const FPS_SAMPLE_SIZE = 60;

// --- Global State Initialization ---
global $world, $shutdown_flag_path, $save_path;

$shutdown_flag_path = __DIR__ . "/../shutdown.flag";
$save_path = __DIR__ . "/../save.data";

$world = [
    "window" => new Window("Animation Demo", 800, 450),
    "camera" => new Camera(800.0, 450.0),
    "sprites" => [], // Associative array for all sprites
    "physicsBodies" => [],
    "fps" => 0.0,
    "smoothed_fps" => 0.0,
    "fps_samples" => [],
    "assetsLoaded" => false,
    "mapInfo" => [],
    "playerKey" => null,
    "inputState" => [],
    "physicsDebug" => false,
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

    // Use @ to suppress warnings from corrupt data
    $existing_world = @unserialize($data);

    // Check for a 'false' return, which indicates an error
    // (unless the data was *actually* the boolean 'false')
    if ($existing_world === false && $data !== serialize(false)) {
        echo "Failed to unserialize saved data. It may be corrupt. Starting fresh.\n";

        // Delete the corrupt save file
        if (is_file($save_path)) {
            unlink($save_path);
        }
    } else {
        $world = $existing_world;
        echo "World state restored.\n";
    }

    // Re-initialize transient objects and re-inject paths
    if (!isset($world["liveReload"])) {
        $world["liveReload"] = new LiveReload($shutdown_flag_path, $save_path);
    } else {
        // Re-inject paths, since they are not serialized
        $world["liveReload"]->setPaths($shutdown_flag_path, $save_path);
    }
}

/**
 * Main game loop function.
 * @throws Exception
 */
function Phrost_Update(int $elapsed, float $dt, string $eventsBlob = ""): string
{
    global $world;

    //-- Live reloading feature for IPC support
    /** @var LiveReload $live_reload */
    $live_reload = $world["liveReload"];

    // Look for live reload events. This will die() if flag is present.
    $live_reload->poll($world["assetsLoaded"]);

    /** @var Window $window */
    $window = $world["window"];

    /** @var Camera $camera */
    $camera = $world["camera"];

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

    $events = PackFormat::unpack($eventsBlob);

    UI::processEvents($events);

    // --- Packer Setup ---
    if (isset($world["__initial_packer"])) {
        $packer = $world["__initial_packer"];
        unset($world["__initial_packer"]); // Use it only once
    } else {
        $packer = new ChannelPacker();
    }

    // Check if a reset was requested on the *previous* frame.
    if ($live_reload->isResetPending()) {
        echo "Executing deferred reset. Sending remove commands.\n";

        // This function now just packs events and creates the flag
        $live_reload->reset($world, $packer);

        // Return the packer with the remove commands.
        // The script will end here for this frame.
        // On the *next* frame, poll() will see the flag and die("unloading").
        return $packer->finalize();
    }

    // --- Initial Asset Loading ---
    if (!$world["assetsLoaded"]) {
        // -- Load Map
        Tiled::loadMap($world, $packer, __DIR__ . "/assets/map.tmx");

        // --- Create the Warrior ---
        $id = Id::generate();
        $warrior = new Warrior($id[0], $id[1]);
        $warrior->setPosition(100.0, 40.0, 0.0);
        $warrior->setSize(64, 44);
        $warrior->setTexturePath(__DIR__ . "/assets/Warrior_Sheet-Effect.png");

        // Call the new function to set animations for the first time
        $warrior->initializeAnimations();

        // Start playing the 'idle' animation
        $warrior->play("idle", true); // Loop 'idle'

        $key = Id::toHex([$warrior->id0, $warrior->id1]);
        $world["sprites"][$key] = $warrior;
        $warrior->packDirtyEvents($packer);

        // --- Create the Warrior Physics Body ---
        $warriorBody = new WarriorBody($id[0], $id[1]); // Use SAME ID

        // Configure as a dynamic (moveable) box
        $warriorBody->setConfig(
            0, // bodyType: 0=dynamic
            0, // shapeType: 0=box
            1.0, // mass
            0.2, // friction (low friction is fine for velocity control)
            0.0, // elasticity (no bounce)
            1, // lockRotation = true
        );

        // Set a hitbox shape (e.g., 32 wide, 40 tall)
        $warriorBody->setShape(32.0, 40.0);

        // Set initial position (must match sprite)
        $warriorBody->setPosition(100.0, 40.0, false);

        // Store and pack
        $world["physicsBodies"][$key] = $warriorBody;
        $world["playerKey"] = $key;
        $warriorBody->packDirtyEvents($packer);

        // Set up the window
        $window->setSize(800, 450);
        $window->packDirtyEvents($packer);

        $world["assetsLoaded"] = true;
        echo "Assets loaded successfully!\n";
    }

    //-- Cache player lookup values

    /** @var $playerKey string Hexadecimal value of ID1,ID2 */
    $playerKey = $world["playerKey"] ?? null;

    /** @var ?WarriorBody $playerBody */
    $playerBody = null;
    if ($playerKey && isset($world["physicsBodies"][$playerKey])) {
        $playerBody = $world["physicsBodies"][$playerKey];
    }

    /** @var ?Warrior $playerSprite */
    $playerSprite = null;
    if ($playerKey && isset($world["sprites"][$playerKey])) {
        $playerSprite = $world["sprites"][$playerKey];
    }

    // --- Window Title Update ---
    $window->setTitle(
        "Warrior Animation Demo (Press 'I' for Idle, 'A' for Attack)",
    );
    $window->packDirtyEvents($packer);

    // --- Input Event Handling ---
    foreach ($events as $event) {
        if (!isset($event["type"])) {
            continue;
        }

        // --- Window Resize Event ---
        if ($event["type"] === Events::WINDOW_RESIZE->value) {
            $world["window"]->setSize($event["w"], $event["h"]);
        }

        // --- Keyboard Events ---
        if ($event["type"] === Events::INPUT_KEYDOWN->value) {
            $world["inputState"][$event["keycode"]] = true;

            $live_reload->resetOnEvent($event, Keycode::R, Mod::CTRL);
            $live_reload->shutdownOnEvent($event, Keycode::Q, Mod::NONE);

            // --- Animation Toggles ---
            if ($event["keycode"] === Keycode::I) {
                // Play 'idle' animation, looping
                foreach ($world["sprites"] as $sprite) {
                    if ($sprite instanceof SpriteAnimated) {
                        echo "Playing idle animation\n";
                        $sprite->play("idle", true, true); // loop, force restart
                    }
                }
            }
            if ($event["keycode"] === Keycode::A) {
                // Play 'attack' animation, once
                foreach ($world["sprites"] as $sprite) {
                    if ($sprite instanceof SpriteAnimated) {
                        // Play 'attack', no loop, force restart
                        echo "Playing attack animation\n";
                        $sprite->play("attack", false, true);
                    }
                }
            }
            // --- End Animation Toggles ---
            if ($event["keycode"] === Keycode::D) {
                // 1. Toggle state
                $world["physicsDebug"] = !$world["physicsDebug"];

                // 2. Send command to engine
                PhysicsBody::setDebugMode($packer, $world["physicsDebug"]);

                echo "Physics Debug: " .
                    ($world["physicsDebug"] ? "ON" : "OFF") .
                    "\n";
            }
        } // End KeyDown

        if ($event["type"] === Events::INPUT_KEYUP->value) {
            // Clear the key state
            if (isset($world["inputState"][$event["keycode"]])) {
                unset($world["inputState"][$event["keycode"]]);
            }
        } // End KeyUp

        // Handle texture loaded event
        if ($event["type"] === Events::SPRITE_TEXTURE_SET->value) {
            if (isset($event["id1"], $event["id2"], $event["textureId"])) {
                $key = Id::toHex([$event["id1"], $event["id2"]]);
                if (isset($world["sprites"][$key])) {
                    /** @var Sprite $sprite */
                    $sprite = $world["sprites"][$key];
                    $sprite->setTextureId($event["textureId"]);
                }
            }
        }

        // This event must be sent *from* your engine *to* PHP
        // every frame for the player body.
        if ($event["type"] === Events::PHYSICS_SYNC_TRANSFORM->value) {
            /**
             * @var $event array{
             * type: int,
             * timestamp: int,
             * id1: int,
             * id2: int,
             * positionX: float,
             * positionY: float,
             * angle: float,
             * velocityX: float,
             * velocityY: float,
             * angularVelocity: float,
             * isSleeping: int
             * }
             */

            $key = Id::toHex([$event["id1"], $event["id2"]]);
            if (isset($world["physicsBodies"][$key])) {
                /** @var WarriorBody $body */
                $body = $world["physicsBodies"][$key];
                $body->setVelocity(
                    $event["velocityX"],
                    $event["velocityY"],
                    false,
                );
                $body->setRotation($event["angle"], false);
                $body->setAngularVelocity($event["angularVelocity"], false);
                $body->setIsSleeping($event["isSleeping"] === 1, false);

                //-- Camera
                if ($key === $world["playerKey"]) {
                    /** @var \Phrost\Camera $camera */
                    $camera = $world["camera"];
                    /** @var Window $window */
                    $window = $world["window"];

                    // Center camera on player
                    // (Player's world X) - (Half screen width)
                    $winSize = $window->getSize();
                    $camX = $event["positionX"]; // - ($winSize['width'] / 2.0);
                    $camY = $event["positionY"]; // - ($winSize['height'] / 2.0);

                    // TODO: Add clamping logic here if you want
                    // e.g., $camX = max(0, min($camX, $world["mapInfo"]["width"] - $window->getWidth()));

                    $camera->setPosition($camX, $camY);
                }
            }

            if (isset($world["sprites"][$key])) {
                /** @var Sprite $sprite */
                $sprite = $world["sprites"][$key];
                $old_position = $sprite->getPosition();
                $old_rotation = $sprite->getRotation();
                $sprite->setPosition(
                    $event["positionX"],
                    $event["positionY"],
                    $old_position["z"],
                );
                $sprite->setRotate(
                    $old_rotation["x"],
                    $old_rotation["y"],
                    $event["angle"],
                );
            }
        }

        if ($event["type"] === Events::PHYSICS_COLLISION_BEGIN->value) {
            // Tell the player object to process the event.
            // We pass *only* the parts of the world it needs.
            $playerBody?->processCollisionEvent(
                $event,
                $world["physicsBodies"],
            );
        }
    } // End foreach event

    // --- Player Movement Logic ---
    // Tell the player to update itself, passing its dependencies.
    // PHP knows to pass $world["inputState"] by reference
    // because the method definition for update() has the &.
    $playerBody?->update($world["inputState"], $packer);
    // --- End Player Movement Logic ---

    // --- State-Based Animation Logic ---
    if ($playerSprite && $playerBody) {
        $targetVx = 0.0;
        if (isset($world["inputState"][Keycode::LEFT])) {
            $targetVx = -1.0;
        }
        if (isset($world["inputState"][Keycode::RIGHT])) {
            $targetVx = 1.0;
        }

        // Don't interrupt a non-looping animation (like 'attack')
        // Use the new getter methods
        if ($playerSprite->isLooping() || !$playerSprite->isPlaying()) {
            // We are clear to set a new state (idle or run)
            if ($targetVx != 0.0) {
                // --- Moving ---
                // Play 'run' animation, loop it, don't force restart if already running
                $playerSprite->play("run", true, false);

                // Flip the sprite based on direction
                // setFlip(true) = flipped (facing left)
                // setFlip(false) = not flipped (facing right)
                $playerSprite->setFlip($targetVx < 0);
            } else {
                // --- Not Moving ---
                // Play 'idle' animation, loop it, don't force restart if already idle
                $playerSprite->play("idle", true, false);
            }
        }
    }
    // --- End State-Based Animation Logic ---

    // --- Main Game Logic ---
    foreach ($world["sprites"] as $sprite) {
        // Check if it's an animatable sprite
        if ($sprite instanceof SpriteAnimated) {
            // This single call handles frame progression
            $sprite->update($dt);
            $sprite->packDirtyEvents($packer);
        }
    }
    unset($sprite);

    // --- Camera Update ---
    /** @var \Phrost\Camera $camera */
    $camera = $world["camera"];
    $camera->packDirtyEvents($packer);

    // --- UI ---
    $WIN_DEBUG_ID = 50;
    $BTN_RESET_ID = 100;
    $BTN_ATTACK_ID = 101;

    if ($world["showDebug"] ?? true) {
        // Start a Window
        // Set Window Position
        UI::setNextWindowPos($packer, 10, 10, UI::COND_FIRST_USE_EVER);
        // Set Window Size
        UI::setNextWindowSize($packer, 300, 150, UI::COND_FIRST_USE_EVER);
        // Create Window
        UI::beginWindow($packer, $WIN_DEBUG_ID, "Debug Control")->onClose(
            function () use (&$world) {
                // This runs immediately if the window was closed this frame
                $world["showDebug"] = false;
                echo "Debug Window Closed via Fluent Syntax.\n";
            },
        );

        // Add some Text
        UI::text($packer, "FPS: " . number_format($world["smoothed_fps"], 1));
        UI::text($packer, "Entities: " . count($world["sprites"]));

        // Add Buttons
        UI::button(
            $packer,
            $BTN_RESET_ID,
            "Toggle Physics Debug",
            200,
            30,
        )->onClick(function () use ($world, $packer) {
            echo "UI: Toggle Debug Clicked\n";
            $world["physicsDebug"] = !$world["physicsDebug"];
            PhysicsBody::setDebugMode($packer, $world["physicsDebug"]);
        });

        UI::button($packer, $BTN_ATTACK_ID, "Player Attack", 200, 30)->onClick(
            function () use ($playerSprite) {
                if ($playerSprite) {
                    echo "UI: Attack Clicked\n";
                    $playerSprite->play("attack", false, true);
                }
            },
        );

        // End Window
        UI::endWindow($packer);
    }

    // --- Finalize & Return ---
    return $packer->finalize();
}
