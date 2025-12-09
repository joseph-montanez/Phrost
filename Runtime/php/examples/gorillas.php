<?php

use Phrost\Id;
use Phrost\Keycode;
use Phrost\PackFormat;
use Phrost\Window;
use Phrost\Events;
use Phrost\ChannelPacker;
use Phrost\LiveReload;
use Phrost\Text;
use Phrost\PhysicsBody;
use Phrost\Camera;
use Phrost\Sprite;
use Phrost\Geometry;

// --- Constants ---
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;
const MAX_BUILDINGS = 15;
const MAX_PLAYERS = 2;

// *** IMPORTANT: You need a 1x1 white pixel image here ***
const TEXTURE_PATH = __DIR__ . "/assets/white.png";

// --- Global State ---
global $world, $shutdown_flag_path, $save_path;

$shutdown_flag_path = __DIR__ . "/../shutdown.flag";
$save_path = __DIR__ . "/../save.data";

$world = [
    "window" => new Window("Gorillas", SCREEN_WIDTH, SCREEN_HEIGHT),
    "camera" => new Camera(SCREEN_WIDTH / 2.0, SCREEN_HEIGHT / 2.0),
    "liveReload" => new LiveReload($shutdown_flag_path, $save_path),
    "assetsLoaded" => false,
    "gameOver" => false,
    "playerTurn" => 0,
    "ballOnAir" => false,

    // Entities
    "players" => [],
    "buildings" => [],
    "ball" => null,

    // UI & Input
    "uiText" => null,
    // [CHANGED] Arrow indicator using multiple geometry objects
    "aimArrow" => [
        "shaft" => null, // Main line of the arrow
        "headLeft" => null, // Left side of arrowhead
        "headRight" => null, // Right side of arrowhead
    ],
    "mouse" => ["x" => 0, "y" => 0],
    "mouseDown" => false,
];

// Initial Pack
$world["__initial_packer"] = new ChannelPacker();
$world["window"]->setResizable(false);
$world["window"]->packDirtyEvents($world["__initial_packer"]);
$world["camera"]->packDirtyEvents($world["__initial_packer"]);

// --- Lifecycle ---
function Phrost_Sleep(): string
{
    global $world;
    unset($world["__initial_packer"]);
    return serialize($world);
}
function Phrost_Wake(string $data): void
{
    global $world, $save_path, $shutdown_flag_path;
    $world = unserialize($data);
    $world["liveReload"] = new LiveReload($shutdown_flag_path, $save_path);
}

// --- Helpers ---

function createEntity(
    $packer,
    $x,
    $y,
    $w,
    $h,
    $color,
    $isDynamic,
    $shapeType = 0,
) {
    $id = Id::generate();

    // Sprite
    $sprite = new Sprite($id[0], $id[1]);
    $sprite->setTexturePath(TEXTURE_PATH);
    $sprite->setPosition($x, $y, 0.0);
    $sprite->setSize($w, $h);
    $sprite->setColor($color[0], $color[1], $color[2], 255, false);
    $sprite->packDirtyEvents($packer);

    // Body
    $body = new PhysicsBody($id[0], $id[1]);
    $type = $isDynamic ? 0 : 1;
    $mass = $isDynamic ? 1 : 0.0;

    $body->setConfig($type, $shapeType, $mass, 0.5, 0.0, 1);
    $body->setShape($w, $h);
    $body->setPosition($x, $y, true);
    $body->packDirtyEvents($packer);

    return ["ids" => $id, "sprite" => $sprite, "body" => $body];
}

/**
 * Creates a line geometry object
 */
function createLine(
    $packer,
    $x1,
    $y1,
    $x2,
    $y2,
    $r,
    $g,
    $b,
    $a,
    $z = 50.0,
): Geometry {
    $id = Id::generate();
    $line = new Geometry($id[0], $id[1]);
    $line->setLine($x1, $y1, $x2, $y2);
    $line->setZ($z);
    $line->setColor($r, $g, $b, $a, false);
    $line->packDirtyEvents($packer);
    return $line;
}

/**
 * Removes the entire arrow (all geometry parts)
 */
function removeAimArrow($packer): void
{
    global $world;

    if ($world["aimArrow"]["shaft"] !== null) {
        $world["aimArrow"]["shaft"]->remove($packer);
        $world["aimArrow"]["shaft"] = null;
    }
    if ($world["aimArrow"]["headLeft"] !== null) {
        $world["aimArrow"]["headLeft"]->remove($packer);
        $world["aimArrow"]["headLeft"] = null;
    }
    if ($world["aimArrow"]["headRight"] !== null) {
        $world["aimArrow"]["headRight"]->remove($packer);
        $world["aimArrow"]["headRight"] = null;
    }
}

/**
 * Creates an arrow from origin pointing in the direction of the velocity vector
 *
 * @param float $originX Starting X position
 * @param float $originY Starting Y position
 * @param float $vecX Direction vector X component
 * @param float $vecY Direction vector Y component
 * @param float $maxLength Maximum visual length of the arrow
 */
function createAimArrow(
    $packer,
    $originX,
    $originY,
    $vecX,
    $vecY,
    $maxLength = 200.0,
): void {
    global $world;

    // Remove existing arrow first
    removeAimArrow($packer);

    // Calculate length
    $length = sqrt($vecX * $vecX + $vecY * $vecY);

    if ($length < 10) {
        // Too short, don't draw
        return;
    }

    // Normalize the direction
    $dirX = $vecX / $length;
    $dirY = $vecY / $length;

    // Clamp length for visual purposes
    $displayLength = min($length, $maxLength);

    // Calculate end point of the shaft
    $endX = $originX + $dirX * $displayLength;
    $endY = $originY + $dirY * $displayLength;

    // Arrow color - bright yellow/orange gradient based on power
    $power = min($length / $maxLength, 1.0);
    $r = 255;
    $g = (int) (255 - $power * 100); // Goes from yellow to orange as power increases
    $b = 0;
    $a = 220;

    // Create the main shaft
    $world["aimArrow"]["shaft"] = createLine(
        $packer,
        $originX,
        $originY,
        $endX,
        $endY,
        $r,
        $g,
        $b,
        $a,
        50.0,
    );

    // --- Create arrowhead ---
    // Arrowhead size proportional to arrow length
    $headSize = max(15, $displayLength * 0.15);
    $headAngle = 0.5; // ~28 degrees in radians

    // Calculate perpendicular vector for arrowhead
    $perpX = -$dirY;
    $perpY = $dirX;

    // Arrowhead points (positioned at the end of the shaft)
    // Left wing of arrowhead
    $headLeftX = $endX - $dirX * $headSize + $perpX * $headSize * 0.5;
    $headLeftY = $endY - $dirY * $headSize + $perpY * $headSize * 0.5;

    // Right wing of arrowhead
    $headRightX = $endX - $dirX * $headSize - $perpX * $headSize * 0.5;
    $headRightY = $endY - $dirY * $headSize - $perpY * $headSize * 0.5;

    // Create arrowhead lines
    $world["aimArrow"]["headLeft"] = createLine(
        $packer,
        $endX,
        $endY,
        $headLeftX,
        $headLeftY,
        $r,
        $g,
        $b,
        $a,
        50.0,
    );
    $world["aimArrow"]["headRight"] = createLine(
        $packer,
        $endX,
        $endY,
        $headRightX,
        $headRightY,
        $r,
        $g,
        $b,
        $a,
        50.0,
    );
}

function InitGame(ChannelPacker $packer)
{
    global $world;

    $world["gameOver"] = false;
    $world["ballOnAir"] = false;
    $world["playerTurn"] = 0;

    if (isset($world["camera"])) {
        $world["camera"]->setPosition(SCREEN_WIDTH / 2.0, SCREEN_HEIGHT / 2.0);
        $world["camera"]->packDirtyEvents($packer);
    }

    // Cleanup
    if ($world["ball"]) {
        $world["ball"]["body"]->remove($packer);
        $world["ball"]["sprite"]->remove($packer);
        $world["ball"] = null;
    }
    foreach ($world["buildings"] as $b) {
        $b["body"]->remove($packer);
        $b["sprite"]->remove($packer);
    }
    $world["buildings"] = [];
    foreach ($world["players"] as $p) {
        $p["body"]->remove($packer);
        $p["sprite"]->remove($packer);
    }
    $world["players"] = [];

    // Remove any existing aim arrow
    removeAimArrow($packer);

    // --- Generate Buildings ---
    $currentWidth = 0;
    $buildingRelativeError = 30;
    $relativeWidth = 100 / (100 - $buildingRelativeError);
    $avgWidth = (SCREEN_WIDTH * $relativeWidth) / MAX_BUILDINGS + 1;

    for ($i = 0; $i < MAX_BUILDINGS; $i++) {
        $w = rand(
            (int) (($avgWidth * (100 - $buildingRelativeError / 2)) / 100 + 1),
            (int) (($avgWidth * (100 + $buildingRelativeError)) / 100),
        );
        $hPercent = rand(20, 60);
        $h = (int) ((SCREEN_HEIGHT * $hPercent) / 100) + 1;

        $centerX = $currentWidth + $w / 2.0;
        $centerY = SCREEN_HEIGHT - $h / 2.0;
        $gray = rand(120, 200);

        $ent = createEntity(
            $packer,
            $centerX,
            $centerY,
            $w,
            $h,
            [$gray, $gray, $gray],
            false,
        );
        $world["buildings"][] = $ent;

        $currentWidth += $w;
    }

    // --- Generate Players ---
    for ($i = 0; $i < MAX_PLAYERS; $i++) {
        $isLeft = $i % 2 == 0;
        $px = $isLeft ? rand(50, 200) : rand(600, 750);
        $py = 100;

        $color = $isLeft ? [0, 0, 255] : [255, 0, 0];
        $ent = createEntity($packer, $px, $py, 40, 40, $color, true);

        $ent["isAlive"] = true;
        $ent["isLeft"] = $isLeft;
        $ent["x"] = $px;
        $ent["y"] = $py;

        $world["players"][$i] = $ent;
    }

    // UI Text
    if (!isset($world["uiText"])) {
        $tid = Id::generate();
        $world["uiText"] = new Text($tid[0], $tid[1]);
        $world["uiText"]->setFont(__DIR__ . "/assets/Roboto-Regular.ttf", 20.0);
        $world["uiText"]->setPosition(10, 10, 100.0, false);
        $world["uiText"]->setColor(50, 50, 50, 255, false);
    }
    $world["uiText"]->setText("Player 1 Turn (Drag Mouse)");
    $world["uiText"]->packDirtyEvents($packer);

    PhysicsBody::setDebugMode($packer, false);
}

// --- Update ---

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

    if ($live_reload->isResetPending()) {
        $live_reload->reset($world, $packer);
        return $packer->finalize();
    }

    if (!$world["assetsLoaded"]) {
        InitGame($packer);
        $world["assetsLoaded"] = true;
    }

    foreach ($events as $event) {
        if ($event["type"] === Events::INPUT_KEYDOWN->value) {
            if ($event["keycode"] === Keycode::RETURN && $world["gameOver"]) {
                InitGame($packer);
            }
        }
        if ($event["type"] === Events::INPUT_MOUSEMOTION->value) {
            $world["mouse"]["x"] = $event["x"];
            $world["mouse"]["y"] = $event["y"];
        }
        if ($event["type"] === Events::INPUT_MOUSEDOWN->value) {
            $world["mouseDown"] = true;
        }

        // --- SHOOTING ---
        if ($event["type"] === Events::INPUT_MOUSEUP->value) {
            $world["mouseDown"] = false;

            // Hide aim arrow on mouse release
            removeAimArrow($packer);

            if (!$world["gameOver"] && !$world["ballOnAir"]) {
                $pIndex = $world["playerTurn"];

                // Safety check - ensure player exists
                if (!isset($world["players"][$pIndex])) {
                    continue;
                }

                $currPlayer = $world["players"][$pIndex];

                // Use the player's current tracked position
                $px = $currPlayer["x"];
                $py = $currPlayer["y"];
                $isLeft = $currPlayer["isLeft"];

                // Offset spawn position based on which side the player is on
                // Blue player (left side) throws from top-right
                // Red player (right side) throws from top-left
                $offsetX = $isLeft ? 25 : -25;
                $spawnX = $px + $offsetX;
                $spawnY = $py - 30; // Just above player's head

                $dx = $spawnX - $world["mouse"]["x"];
                $dy = $spawnY - $world["mouse"]["y"];

                // Ball Entity (Dynamic, Circle shape=1)
                $ent = createEntity(
                    $packer,
                    $spawnX,
                    $spawnY,
                    20,
                    20,
                    [128, 0, 0],
                    true,
                    1,
                );

                // Set Velocity
                $ent["body"]->applyImpulse($packer, $dx * 9.0, $dy * 9.0);

                $world["ball"] = $ent;
                $world["ballOnAir"] = true;
            }
        }

        // [FIXED] Use explicit array index instead of reference to ensure positions persist correctly
        if ($event["type"] === Events::PHYSICS_SYNC_TRANSFORM->value) {
            $eid0 = $event["id1"];
            $eid1 = $event["id2"];
            $x = $event["positionX"];
            $y = $event["positionY"];

            foreach ($world["players"] as $idx => $p) {
                if ($p["ids"][0] === $eid0 && $p["ids"][1] === $eid1) {
                    $world["players"][$idx]["x"] = $x;
                    $world["players"][$idx]["y"] = $y;
                    $world["players"][$idx]["sprite"]->setPosition($x, $y, 0.0);
                    $world["players"][$idx]["sprite"]->setRotate(
                        0,
                        0,
                        $event["angle"],
                    );
                    break;
                }
            }

            if (
                $world["ball"] &&
                $world["ball"]["ids"][0] === $eid0 &&
                $world["ball"]["ids"][1] === $eid1
            ) {
                $world["ball"]["sprite"]->setPosition($x, $y, 0.0);
                if (
                    $y > SCREEN_HEIGHT + 50 ||
                    $x < -50 ||
                    $x > SCREEN_WIDTH + 50
                ) {
                    $world["ballOnAir"] = false;
                    $world["ball"]["body"]->remove($packer);
                    $world["ball"]["sprite"]->remove($packer);
                    $world["ball"] = null;
                    if (!$world["gameOver"]) {
                        // Explicitly calculate next turn
                        $currentTurn = $world["playerTurn"];
                        $nextTurn = ($currentTurn + 1) % MAX_PLAYERS;
                        $world["playerTurn"] = $nextTurn;

                        $world["uiText"]->setText(
                            "Player " . ($world["playerTurn"] + 1) . " Turn",
                        );
                        $world["uiText"]->packDirtyEvents($packer);
                    }
                }
            }
        }

        if ($event["type"] === Events::PHYSICS_COLLISION_BEGIN->value) {
            if ($world["ballOnAir"] && $world["ball"]) {
                $bId0 = $world["ball"]["ids"][0];
                $bId1 = $world["ball"]["ids"][1];

                // Check if ball is involved in collision (could be object A or B)
                $isBallA =
                    $event["id1_A"] === $bId0 && $event["id2_A"] === $bId1;
                $isBallB =
                    $event["id1_B"] === $bId0 && $event["id2_B"] === $bId1;

                if ($isBallA || $isBallB) {
                    // Get the OTHER object's IDs (not the ball)
                    $otherId0 = $isBallA ? $event["id1_B"] : $event["id1_A"];
                    $otherId1 = $isBallA ? $event["id2_B"] : $event["id2_A"];

                    $hitPlayer = false;
                    $hitSelf = false;
                    $hitPlayerIdx = -1;

                    // Check if we hit a player
                    foreach ($world["players"] as $idx => $p) {
                        if (
                            $p["ids"][0] === $otherId0 &&
                            $p["ids"][1] === $otherId1
                        ) {
                            $hitPlayer = true;
                            $hitPlayerIdx = $idx;
                            // Check if it's the current player (self-hit)
                            if ($idx === $world["playerTurn"]) {
                                $hitSelf = true;
                            }
                            break;
                        }
                    }

                    // Handle self-hit: just ignore it, let the ball continue
                    if ($hitSelf) {
                        // Do nothing - ball passes through self
                        continue;
                    }

                    // Handle hitting opponent
                    if ($hitPlayer && !$hitSelf) {
                        $p = $world["players"][$hitPlayerIdx];
                        $world["gameOver"] = true;
                        $world["players"][$hitPlayerIdx]["isAlive"] = false;
                        $p["body"]->remove($packer);
                        $p["sprite"]->remove($packer);
                        $world["uiText"]->setText(
                            "Player " .
                                ($hitPlayerIdx + 1) .
                                " HIT! [Enter] to Reset.",
                        );
                        $world["uiText"]->packDirtyEvents($packer);
                    }

                    // Remove ball on any collision (except self-hit which we skipped)
                    $world["ballOnAir"] = false;
                    $world["ball"]["body"]->remove($packer);
                    $world["ball"]["sprite"]->remove($packer);
                    $world["ball"] = null;

                    // Switch turns after any collision (unless game is over)
                    if (!$world["gameOver"]) {
                        // Explicitly calculate next turn
                        $currentTurn = $world["playerTurn"];
                        $nextTurn = ($currentTurn + 1) % MAX_PLAYERS;
                        $world["playerTurn"] = $nextTurn;

                        $world["uiText"]->setText(
                            "Player " . ($world["playerTurn"] + 1) . " Turn",
                        );
                        $world["uiText"]->packDirtyEvents($packer);
                    }
                }
            }
        }
    }

    // --- UPDATE AIM ARROW ---
    // Draw an arrow from the throw position showing shooting direction and power
    if ($world["mouseDown"] && !$world["ballOnAir"] && !$world["gameOver"]) {
        $pIndex = $world["playerTurn"];

        if (isset($world["players"][$pIndex])) {
            $currPlayer = $world["players"][$pIndex];

            // Calculate throw origin (same as spawn position)
            $offsetX = $currPlayer["isLeft"] ? 25 : -25;
            $playerX = $currPlayer["x"] + $offsetX;
            $playerY = $currPlayer["y"] - 30;

            // Calculate shooting direction vector (away from mouse)
            $vecX = $playerX - $world["mouse"]["x"];
            $vecY = $playerY - $world["mouse"]["y"];

            // Create the arrow pointing in the throw direction
            createAimArrow($packer, $playerX, $playerY, $vecX, $vecY, 200.0);
        }
    }

    $world["camera"]->packDirtyEvents($packer);

    return $packer->finalize();
}
