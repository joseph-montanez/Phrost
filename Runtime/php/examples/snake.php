<?php

use Phrost\Geometry;
use Phrost\Id;
use Phrost\Keycode;
use Phrost\PackFormat;
use Phrost\Window;
use Phrost\Events;
use Phrost\ChannelPacker;
use Phrost\LiveReload;
use Phrost\Text;
use Phrost\Mod;
use Phrost\Camera;

// --- Constants ---
const SQUARE_SIZE = 31;
const SNAKE_LENGTH = 256;
const MOVE_INTERVAL = 0.08;

// --- Global State Initialization ---
global $world, $shutdown_flag_path, $save_path;

$shutdown_flag_path = __DIR__ . "/../shutdown.flag";
$save_path = __DIR__ . "/../save.data";

$screenWidth = 800;
$screenHeight = 450;

$world = [
    "window" => new Window("Classic Game: Snake", $screenWidth, $screenHeight),
    "camera" => new Camera($screenWidth / 2.0, $screenHeight / 2.0),
    "liveReload" => new LiveReload($shutdown_flag_path, $save_path),
    "assetsLoaded" => false,

    // Game State
    "gameOver" => false,
    "pause" => false,
    "offset" => ["x" => 0, "y" => 0],
    "screenWidth" => $screenWidth,
    "screenHeight" => $screenHeight,

    // Snake Data
    "snakePos" => [],
    "snakeGeoms" => [],
    "speed" => ["x" => 0, "y" => 0],
    "nextSpeed" => ["x" => 0, "y" => 0],
    "allowMove" => false,
    "moveTimer" => 0.0,

    // Food Data
    "food" => ["x" => 0, "y" => 0, "active" => false],
    "foodGeom" => null,

    // UI
    "texts" => [],
];

// Pack initial window setup
$world["__initial_packer"] = new ChannelPacker();
$world["window"]->setResizable(false);
$world["window"]->packDirtyEvents($world["__initial_packer"]);

// Pack initial camera setup so it's correct on frame 1
$world["camera"]->packDirtyEvents($world["__initial_packer"]);

// --- Standard Phrost Lifecycle Methods ---

function Phrost_Sleep(): string
{
    global $world;
    unset($world["__initial_packer"]);
    return serialize($world);
}

function Phrost_Wake(string $data): void
{
    global $world, $save_path, $shutdown_flag_path;
    $existing_world = @unserialize($data);

    if ($existing_world === false) {
        if (is_file($save_path)) {
            unlink($save_path);
        }
    } else {
        $world = $existing_world;
    }

    if (!isset($world["liveReload"])) {
        $world["liveReload"] = new LiveReload($shutdown_flag_path, $save_path);
    } else {
        $world["liveReload"]->setPaths($shutdown_flag_path, $save_path);
    }
}

// --- Game Logic Functions ---

function InitGame()
{
    global $world;

    $world["gameOver"] = false;
    $world["pause"] = false;
    $world["allowMove"] = false;
    $world["moveTimer"] = 0.0;

    $world["offset"]["x"] = $world["screenWidth"] % SQUARE_SIZE;
    $world["offset"]["y"] = $world["screenHeight"] % SQUARE_SIZE;

    // Reset geometry arrays if restarting
    $world["snakeGeoms"] = [];
    $world["snakePos"] = [];

    // Initial Snake
    $startX = (int) ($world["offset"]["x"] / 2);
    $startY = (int) ($world["offset"]["y"] / 2);

    $world["snakePos"][] = ["x" => $startX, "y" => $startY];

    $world["speed"] = ["x" => SQUARE_SIZE, "y" => 0];
    $world["nextSpeed"] = ["x" => SQUARE_SIZE, "y" => 0];

    // Reset Food
    $world["food"]["active"] = false;
    $world["foodGeom"] = null;

    // Ensure Camera is reset if game restarts (optional, but good safety)
    if (isset($world["camera"])) {
        $world["camera"]->setPosition(
            $world["screenWidth"] / 2.0,
            $world["screenHeight"] / 2.0,
        );
    }
}

function Phrost_Update(int $elapsed, float $dt, string $eventsBlob = ""): string
{
    global $world;

    $live_reload = $world["liveReload"];
    $live_reload->poll($world["assetsLoaded"]);

    $events = PackFormat::unpack($eventsBlob);

    if (isset($world["__initial_packer"])) {
        $packer = $world["__initial_packer"];
        unset($world["__initial_packer"]);
    } else {
        $packer = new ChannelPacker();
    }

    // Live Reload Reset
    if ($live_reload->isResetPending()) {
        $live_reload->reset($world, $packer);
        return $packer->finalize();
    }

    // --- Asset Loading / Initialization ---
    if (!$world["assetsLoaded"]) {
        InitGame();

        // Setup Grid Lines
        $cols = (int) ($world["screenWidth"] / SQUARE_SIZE) + 1;
        $rows = (int) ($world["screenHeight"] / SQUARE_SIZE) + 1;
        $offX = $world["offset"]["x"] / 2;
        $offY = $world["offset"]["y"] / 2;

        for ($i = 0; $i < $cols; $i++) {
            $id = Id::generate();
            $line = new Geometry($id[0], $id[1]);
            $x = SQUARE_SIZE * $i + $offX;
            $line->setLine($x, $offY, $x, $world["screenHeight"] - $offY);
            $line->setColor(200, 200, 200, 255, false);
            $line->setZ(-10.0);
            $line->packDirtyEvents($packer);
        }

        for ($i = 0; $i < $rows; $i++) {
            $id = Id::generate();
            $line = new Geometry($id[0], $id[1]);
            $y = SQUARE_SIZE * $i + $offY;
            $line->setLine($offX, $y, $world["screenWidth"] - $offX, $y);
            $line->setColor(200, 200, 200, 255, false);
            $line->setZ(-10.0);
            $line->packDirtyEvents($packer);
        }

        // Setup UI Text
        $tId = Id::generate();
        $world["texts"]["info"] = new Text($tId[0], $tId[1]);
        $world["texts"]["info"]->setFont(
            __DIR__ . "/../assets/Roboto-Regular.ttf",
            20.0,
        );
        $world["texts"]["info"]->setPosition(
            $world["screenWidth"] / 2 - 100,
            $world["screenHeight"] / 2 - 50,
            99.0,
            false,
        );
        $world["texts"]["info"]->setColor(128, 128, 128, 255, false);
        $world["texts"]["info"]->setText("", false);
        $world["texts"]["info"]->packDirtyEvents($packer);

        $world["assetsLoaded"] = true;
    }

    // --- Input Handling ---
    foreach ($events as $event) {
        if ($event["type"] === Events::INPUT_KEYDOWN->value) {
            $live_reload->resetOnEvent($event, Keycode::R, Mod::CTRL);
            $live_reload->shutdownOnEvent($event, Keycode::Q, Mod::NONE);

            $k = $event["keycode"];

            if ($world["gameOver"]) {
                if ($k === Keycode::RETURN) {
                    // Restart: Remove old geometry
                    foreach ($world["snakeGeoms"] as $g) {
                        $g->remove($packer);
                    }
                    if ($world["foodGeom"]) {
                        $world["foodGeom"]->remove($packer);
                    }
                    InitGame();
                    $world["texts"]["info"]->setText("");
                    $world["texts"]["info"]->packDirtyEvents($packer);
                }
            } else {
                if ($k === Keycode::P) {
                    $world["pause"] = !$world["pause"];
                    $msg = $world["pause"] ? "GAME PAUSED" : "";
                    $world["texts"]["info"]->setText($msg);
                    $world["texts"]["info"]->packDirtyEvents($packer);
                }

                if (!$world["pause"]) {
                    $curr = $world["speed"];
                    if ($k === Keycode::RIGHT && $curr["x"] == 0) {
                        $world["nextSpeed"] = ["x" => SQUARE_SIZE, "y" => 0];
                    }
                    if ($k === Keycode::LEFT && $curr["x"] == 0) {
                        $world["nextSpeed"] = ["x" => -SQUARE_SIZE, "y" => 0];
                    }
                    if ($k === Keycode::UP && $curr["y"] == 0) {
                        $world["nextSpeed"] = ["x" => 0, "y" => -SQUARE_SIZE];
                    }
                    if ($k === Keycode::DOWN && $curr["y"] == 0) {
                        $world["nextSpeed"] = ["x" => 0, "y" => SQUARE_SIZE];
                    }
                }
            }
        }
    }

    // --- Update Logic ---
    if (!$world["gameOver"] && !$world["pause"]) {
        $world["moveTimer"] += $dt;

        if ($world["moveTimer"] >= MOVE_INTERVAL) {
            $world["moveTimer"] = 0;

            $world["speed"] = $world["nextSpeed"];

            $head = $world["snakePos"][0];
            $newHead = [
                "x" => $head["x"] + $world["speed"]["x"],
                "y" => $head["y"] + $world["speed"]["y"],
            ];

            // Wall Collision
            $limitX = $world["screenWidth"] - $world["offset"]["x"];
            $limitY = $world["screenHeight"] - $world["offset"]["y"];

            if (
                $newHead["x"] > $limitX ||
                $newHead["y"] > $limitY ||
                $newHead["x"] < 0 ||
                $newHead["y"] < 0
            ) {
                $world["gameOver"] = true;
            }

            // Self Collision
            foreach ($world["snakePos"] as $seg) {
                if ($seg["x"] == $newHead["x"] && $seg["y"] == $newHead["y"]) {
                    $world["gameOver"] = true;
                    break;
                }
            }

            if (!$world["gameOver"]) {
                array_unshift($world["snakePos"], $newHead);

                // Food Spawn
                if (!$world["food"]["active"]) {
                    $valid = false;
                    while (!$valid) {
                        $cols = $world["screenWidth"] / SQUARE_SIZE - 1;
                        $rows = $world["screenHeight"] / SQUARE_SIZE - 1;

                        $rx =
                            rand(0, (int) $cols) * SQUARE_SIZE +
                            $world["offset"]["x"] / 2;
                        $ry =
                            rand(0, (int) $rows) * SQUARE_SIZE +
                            $world["offset"]["y"] / 2;

                        $valid = true;
                        foreach ($world["snakePos"] as $seg) {
                            if ($seg["x"] == $rx && $seg["y"] == $ry) {
                                $valid = false;
                                break;
                            }
                        }

                        if ($valid) {
                            $world["food"]["active"] = true;
                            $world["food"]["x"] = $rx;
                            $world["food"]["y"] = $ry;

                            if ($world["foodGeom"]) {
                                $world["foodGeom"]->remove($packer);
                            }

                            $fid = Id::generate();
                            $fGeom = new Geometry($fid[0], $fid[1]);
                            $fGeom->setRect(
                                $rx,
                                $ry,
                                SQUARE_SIZE,
                                SQUARE_SIZE,
                                true,
                            );
                            $fGeom->setColor(135, 206, 235, 255, false);
                            $fGeom->packDirtyEvents($packer);
                            $world["foodGeom"] = $fGeom;
                        }
                    }
                }

                // Eat Food
                $ateFood = false;
                $fx = $world["food"]["x"];
                $fy = $world["food"]["y"];
                $fw = SQUARE_SIZE;
                $fh = SQUARE_SIZE;

                if (
                    $newHead["x"] < $fx + $fw &&
                    $newHead["x"] + SQUARE_SIZE > $fx &&
                    ($newHead["y"] < $fy + $fh &&
                        $newHead["y"] + SQUARE_SIZE > $fy)
                ) {
                    $ateFood = true;
                    $world["food"]["active"] = false;
                    if ($world["foodGeom"]) {
                        $world["foodGeom"]->remove($packer);
                        $world["foodGeom"] = null;
                    }
                }

                if (!$ateFood) {
                    $tail = array_pop($world["snakePos"]);
                    $key = $tail["x"] . "_" . $tail["y"];
                    if (isset($world["snakeGeoms"][$key])) {
                        $world["snakeGeoms"][$key]->remove($packer);
                        unset($world["snakeGeoms"][$key]);
                    }
                }

                // Draw Head
                $hid = Id::generate();
                $hGeom = new Geometry($hid[0], $hid[1]);
                $hGeom->setRect(
                    $newHead["x"],
                    $newHead["y"],
                    SQUARE_SIZE,
                    SQUARE_SIZE,
                    true,
                );

                // Color head Dark Blue
                $hGeom->setColor(0, 82, 172, 255, false);
                $hGeom->packDirtyEvents($packer);

                $headKey = $newHead["x"] . "_" . $newHead["y"];
                $world["snakeGeoms"][$headKey] = $hGeom;

                // Color previous head Blue
                if (count($world["snakePos"]) > 1) {
                    $oldHeadPos = $world["snakePos"][1];
                    $oldKey = $oldHeadPos["x"] . "_" . $oldHeadPos["y"];
                    if (isset($world["snakeGeoms"][$oldKey])) {
                        $world["snakeGeoms"][$oldKey]->setColor(
                            0,
                            121,
                            241,
                            255,
                        );
                        $world["snakeGeoms"][$oldKey]->packDirtyEvents($packer);
                    }
                }
            }
        }
    }

    // Handle Game Over UI
    if ($world["gameOver"]) {
        $world["texts"]["info"]->setText("PRESS [ENTER] TO PLAY AGAIN");
        $world["texts"]["info"]->packDirtyEvents($packer);
    }

    // Even if static, calling this flushes dirty flags if we change it later
    $world["camera"]->packDirtyEvents($packer);

    return $packer->finalize();
}
