Phrost\\Camera Documentation
============================

The `Phrost\Camera` class is a high-level, "retained mode" state object for managing the game's viewport. It controls the camera's position (pan), zoom, and rotation.

Core Concept: The "Dirty Flag" System
-------------------------------------

Like other Phrost classes (`Sprite`, `Window`, etc.), the `Camera` object works by tracking its _desired_ state in PHP.

1.  **You change a property:** You call a method like `$camera->setZoom(2.0)`.

2.  **A flag is set:** The method updates the PHP object's internal state and sets a "dirty flag" (e.g., `$dirtyFlags["zoom"] = true`).

3.  **You pack events:** At the end of your `Phrost_Update` loop, you call `$camera->packDirtyEvents($packer)`.

4.  **Events are sent:** The `packDirtyEvents` method checks all dirty flags. If `$dirtyFlags["zoom"]` is true, it adds a `CAMERA_SET_ZOOM` event to the packer.


When the `Camera` object is first created, its `$isNew` flag is `true`. The _very first time_ `packDirtyEvents()` is called, it sends _all_ of its state (position, zoom, and rotation) to the engine at once. After that, it only sends events for properties that have changed.

How to Use: A Full Workflow
---------------------------

Here is the complete step-by-step process for managing the camera.

### Step 1: Initialization (in `game-logic.php`)

You typically create your `Camera` object once when your script initializes and store it in the global `$world` array.
```php
<?php
use Phrost\Camera;
use Phrost\ChannelPacker;

// --- At the bottom of game-logic.php ---

// 1. Create the camera object
// (e.g., centered on 0,0 with 1.0 zoom)
$camera = new Camera(0.0, 0.0, 1.0);

$world = [
    "camera" => $camera,
    // ... other state
];

// 2. Pack the initial 'isNew' events
$packer = new ChannelPacker();
$camera->packDirtyEvents($packer); //

Phrost_Run($packer->finalize());
```

### Step 2: Updating State (Sending Commands)

In your `Phrost_Update` loop, you can call setter methods to change the camera's properties. These methods all set dirty flags.

```php
<?php
// --- Inside Phrost_Update() ---

/** @var Camera $camera */
$camera = $world["camera"];
$dt_seconds = $dt / 1000.0;

// Example: Follow the player sprite
if (isset($world["playerSprite"])) {
    $playerPos = $world["playerSprite"]->getPosition();
    $camera->setPosition($playerPos["x"], $playerPos["y"]);
}

// Example: Pan the camera with arrow keys
$panSpeed = 200.0 * $dt_seconds; // 200 pixels per second
if (isset($world["inputState"][Keycode::LEFT])) {
    $camera->move(-$panSpeed, 0);
}
if (isset($world["inputState"][Keycode::RIGHT])) {
    $camera->move($panSpeed, 0);
}

// Example: Zoom with Q and E
if (isset($world["inputState"][Keycode::Q])) {
    $newZoom = $camera->getZoom() - (1.0 * $dt_seconds);
    $camera->setZoom($newZoom > 0.1 ? $newZoom : 0.1); // Clamp at 0.1
}
if (isset($world["inputState"][Keycode::E])) {
    $camera->setZoom($camera->getZoom() + (1.0 * $dt_seconds));
}
```

### Step 3: Pack Events in the Main Loop

At the end of every `Phrost_Update` frame, you must call `packDirtyEvents()`. This will check all the dirty flags set in Step 2 and send the corresponding events to the renderer.

```php
<?php
// --- At the end of Phrost_Update() ---

// ... pack other events (sprites, physics, etc.) ...

// Pack camera events
$world["camera"]->packDirtyEvents($packer);

return $packer->finalize();
```
