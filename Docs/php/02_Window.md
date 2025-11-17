# Phrost\Window Documentation

The `Phrost\Window` class is a high-level, "retained mode" state object for managing the game window. It controls properties like the title, size, and window behaviors (e.g., resizable, fullscreen).

---

## Core Concept: The "Dirty Flag" System

Like other Phrost classes (`Sprite`, `PhysicsBody`, etc.), the `Window` object works by tracking its *desired* state in PHP.

1.  **You change a property:** You call a method like `$window->setTitle("New Title")`.
2.  **A flag is set:** The method updates the PHP object's internal state and sets a "dirty flag" (e.g., `$dirtyFlags["title"] = true`).
3.  **You pack events:** At the end of your `Phrost_Update` loop, you call `$window->packDirtyEvents($packer)`.
4.  **Events are sent:** The `packDirtyEvents` method checks all dirty flags. If `$dirtyFlags["title"]` is true, it adds a `WINDOW_TITLE` event to the packer.

When the `Window` object is first created, its `$isNew` flag is `true`. The *very first time* `packDirtyEvents()` is called, it sends *all* initial state (title, size, and flags) to the engine at once.

---

## How to Use: A Full Workflow

Here is the complete step-by-step process for managing the window.

### Step 1: Initialization (in `game-logic.php`)

You typically create your `Window` object once when your script initializes and store it in the global `$world` array.

```php
<?php
use Phrost\Window;
use Phrost\ChannelPacker;

// --- At the bottom of game-logic.php ---

// 1. Create the window object
$window = new Window("My Phrost Game", 1280, 720); //
// 2. Set initial flags
$window->setResizable(true, false); // Set state without notifying (will be sent by 'isNew')

$world = [
    "window" => $window,
    // ... other state
];

// 3. Pack the initial 'isNew' events
$packer = new ChannelPacker();
$window->packDirtyEvents($packer); //

Phrost_Run($packer->finalize());
```

### Step 2: Updating State (Sending Commands)

In your `Phrost_Update` loop, you can call setter methods to change the window's properties.

```php
<?php
// --- Inside Phrost_Update() ---

/** @var Window $window */
$window = $world["window"];

// Example: Update the title
$window->setTitle("My Game | FPS: " . $world["smoothed_fps"]); //

// Example: Toggle borderless mode on key press
if ($event["type"] === Events::INPUT_KEYDOWN->value && $event["keycode"] === Keycode::B) {
    $isBorderless = $window->isFlagEnabled("borderless"); //
    $window->setBorderless(!$isBorderless); //
}

// At the end of the loop, this packs WINDOW_TITLE or WINDOW_FLAGS
// events *only if* they actually changed.
$window->packDirtyEvents($packer); //
```

* * *

Handling Window Flags
------------------------

Window flags control behaviors like "resizable", "fullscreen", and "borderless".

You can set these using specific helper methods:

*   `$window->setResizable(bool $enabled)`

*   `$window->setFullscreen(bool $enabled)`

*   `$window->setBorderless(bool $enabled)`


Or you can use generic helpers for any flag:

*   `$window->setFlag(string $flagName, bool $enabled)`

*   `$window->toggleFlag(string $flagName)`


When _any_ flag is changed, `$dirtyFlags["flags"]` is set to `true`. When `packDirtyEvents()` runs, it calls the private `calculateFlagsBitmask()` method. This method reads all boolean flags and creates a single integer bitmask by OR-ing values from the `WindowFlags` class. This complete bitmask is then sent to the engine in a `WINDOW_FLAGS` event.

* * *

Reacting to Engine Events (Very Important!)
----------------------------------------------

The `Window` object can also be changed by the _user_ (e.g., manually resizing the window). When this happens, the engine sends an event _to_ PHP.

You **must** listen for these events and update your PHP `Window` object to stay in sync.

**Crucially, when you update the object _in response_ to an engine event, you must pass `false` as the `$notifyEngine` parameter.** This updates the PHP state _without_ setting a dirty flag, which prevents an infinite loop.

```php
<?php
// --- Inside Phrost_Update() ---

$events = PackFormat::unpack($eventsBlob);
/** @var Window $window */
$window = $world["window"];

foreach ($events as $event) {

    if ($event["type"] === Events::WINDOW_RESIZE->value) {

        // --- THIS IS THE CORRECT WAY ---
        // Update the PHP state, but set $notifyEngine to false
        // so it doesn't try to send a WINDOW_RESIZE command back.
        $window->setSize($event["w"], $event["h"], false); //

        // Now you can react to the new size
        $world["camera"]->setSize($event["w"], $event["h"]);
    }
}
```
