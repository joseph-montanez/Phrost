## Getting Started

### Download A Release

Phrost has pre-built releases for Windows available on [GitHub](https://github.com/joseph-montanez/Phrost/releases).

### Run `Phrost`

There will be several files in the release folder. The `Phrost` file is the executable that you will run to start the game. 

### Folder Structure

```
Release/
└── Phrost (Runs the game and PHP runtime)
├── game/
│   ├── assets
│   ├── main.php
│   ├── game-logic.php
│   └── src/
│       └── Warrior.php
├── runtime/
│   ├── php.exe
```

### PHP Source Location

Edit your PHP source files in the `game` directory.

### What Files To Edit?

`game/game-logic.php` will be your main file to work with, however `assets/main.php` will be your main entry point.

### Required Functions

Phrost expects three functions in PHP to be declared:

 - function Phrost_Update(int $elasped, float $dt, string $eventsBlob = ""): string
 - function Phrost_Sleep(): string
 - function Phrost_Wake(string $data): void

`game/game-logic.php` already has these functions defined, you can start editing them to implement your game logic.


### The ID System (UUIDs)

You will notice that most entities (like sprites and physics bodies) and their events require two 64-bit integer IDs. In the code, you'll often see these as `$id[0]` and `$id[1]` or `id1` and `id2`.

These two integers work together to form a complete 128-bit **UUID** (Universally Unique Identifier).

This system is used for a critical performance reason:

* **Engine Performance:** Sending two 64-bit numbers to the game engine is extremely fast. It's much more efficient than sending a 36-character UUID string (e.g., "550e8400-e29b-41d4-a716-446655440000"), which the engine would have to parse.
* **PHP Readability:** While fast for the engine, a two-part integer array isn't a good key for a PHP associative array. You need a simple, unique string.

To solve this, Phrost provides the `Phrost\Id` helper class. This class lets you easily generate IDs and convert them into a format that is useful in PHP.

#### The Standard Workflow

The typical workflow in your `game-logic.php` file demonstrates this perfectly:

1.  **Generate an ID:** First, you generate a new, unique ID. This returns a two-element array containing two 64-bit integers.
    ```php
    $id = Id::generate(); // Returns [int, int]
    ```

2.  **Create Entities:** You pass these two integers to your object constructors. This is how the engine will identify them.
    ```php
    $warrior = new Warrior($id[0], $id[1]);
    $warriorBody = new WarriorBody($id[0], $id[1]); // Use the *same* ID
    ```

3.  **Create a PHP Key:** To store these objects in the `$world` array, you convert the ID into a simple, 32-character hexadecimal string using `Id::toHex()`.
    ```php
    $key = Id::toHex($id);
    ```

4.  **Store in `world`:** This hex key is perfect for use in your PHP associative array, making it easy to find objects later.
    ```php
    $world["sprites"][$key] = $warrior;
    $world["physicsBodies"][$key] = $warriorBody;
    $world["playerKey"] = $key;
    ```

Now, when you receive an incoming event (like a `PHYSICS_SYNC_TRANSFORM`), you can get its `id1` and `id2` values, convert them to a hex key using `Id::toHex()`, and instantly find the correct `Warrior` or `WarriorBody` object in your `$world` array to update.

### Channels

Channels are used to route messages between different parts of the game engine. Think of them as radio frequencies. The **scripting engine** (your PHP code) sends messages to the **renderer** (to draw things) and **physics engine** (to move things) and also listens for messages from them.

By default, your PHP script listens to three channels:
* `0: RENDERER` (e.g., events from the renderer)
* `2: PHYSICS` (e.g., collision events)
* `6: SCRIPT` (e.g., events from other scripts or plugins)

Here are the default channel definitions:

```php
<?php
enum Channels: int
{
    case RENDERER = 0;
    case INPUT = 1;
    case PHYSICS = 2;
    case AUDIO = 3;
    case GUI = 4;
    case WINDOW = 5;
    case SCRIPT = 6;
}

```

You can also tell the scripting engine to listen to (subscribe) or stop listening to (unsubscribe) any channel. This is useful for communicating with custom plugins.

  **Note**: To change the script's subscriptions, you must send the request to the RENDERER channel.

```php
<?php
// -- Subscribe to Channel 22
// This is a custom channel. You could use this for a plugin
// to send unique events to your PHP script.
$packer->add(Channels::RENDERER->value, Events::SCRIPT_SUBSCRIBE, [22]);

// -- Unsubscribe from Channel 22
// Stop receiving events on this custom channel.
$packer->add(Channels::RENDERER->value, Events::SCRIPT_UNSUBSCRIBE, [22]);
```

### Events

The engine is **event-driven**. Your game logic lives inside the Phrost_Update function, which runs on every frame.

Your job in this function is to do two things:

1. **Receive Events**: Process incoming events (like "Mouse Clicked" or "Physics Collision") that happened since the last frame.

2. **Send Events**: Create and send new events (like "Draw Line" or "Play Sound") back to the engine.

This all happens in a single "tick" or frame:

1. The engine calls `Phrost_Update(..., $eventsBlob)`. The `$eventsBlob` string contains all incoming events (input, physics, etc.).

2. Your PHP code **unpacks** this `$eventsBlob` to see what happened.

3. Your code runs your game logic (e.g., `if (KEY_PRESSED) { $player->x += 1; }`).

4. Your code **packs** new events (e.g., `DrawPlayer($player->x)`) into a new binary string using a **Packer**.

5. Your function **returns** this new binary string to the engine, which then draws, plays audio, etc.

#### Receiving Events (Processing Input)

The `Phrost_Update` function receives all incoming events as a single binary string in the `$eventsBlob` parameter.

To process them, you must first **unpack** this blob using the static `PackFormat::unpack()` method. This returns an array of event arrays, each corresponding to an event from the engine.

```php
<?php
use Phrost\PackFormat;
use Phrost\Events;
use Phrost\Keycode;
use Phrost\ChannelPacker; // Use the correct packer

// ... inside Phrost_Update()

// 1. UNPACK $eventsBlob
// Use the correct static method from the PackFormat class
$events = PackFormat::unpack($eventsBlob); //

// Loop through the array of incoming event maps
foreach ($events as $event) { //
    if (!isset($event["type"])) {
        continue;
    }

    // Example: Handle a keydown event
    if ($event["type"] === Events::INPUT_KEYDOWN->value) { //
        // $event is an array: ['type' => 101, 'keycode' => 82, ...]
        if ($event["keycode"] === Keycode::R) {
            // User pressed 'R'
        }
    }

    // Example: Handle a window resize event
    if ($event["type"] === Events::WINDOW_RESIZE->value) { //
        // $event is an array: ['type' => 201, 'w' => 1024, 'h' => 768]
        $world["window"]->setSize($event["w"], $event["h"]);
    }
}
```

*(**Note:** The exact method for unpacking the `$eventsBlob` will be detailed in the Event Unpacking documentation.)*

#### Sending Events (Using Channels)

To send commands back to the engine, you must use the `Phrost\ChannelPacker`. This object manages packing your events into the correct channels (e.g., `RENDERER`, `PHYSICS`, `AUDIO`).

At the end of the function, you must call `return $packer->finalize();` to get the final binary string.

#### The Easy Way (Using PHP Classes)

High-level classes like `Window`, `Sprite`, or `Camera` will automatically add their events to the correct channels when you pass them the packer.

```php
<?php
// --- Inside Phrost_Update() ---

// 1. Create the correct packer
$packer = new ChannelPacker(); //

// 2. Pass the packer to high-level objects
// The Window class knows to add its events to the WINDOW channel.
$world["window"]->setTitle("My Game Title");
$world["window"]->packDirtyEvents($packer);

// The Sprite class knows to add its events to the RENDERER channel.
$playerSprite->play("run", true);
$playerSprite->packDirtyEvents($packer);

// The Camera class adds to the RENDERER channel.
$camera->packDirtyEvents($packer);

// 3. Return the finalized string
return $packer->finalize();
```

#### The Manual Way (Low-Level Packing)

You can also add events to channels manually. The `add()` method on `ChannelPacker` requires the **Channel ID** as the first argument.

```php
<?php
// --- Inside Phrost_Update() ---

$packer = new ChannelPacker();

// Manually add an event to the RENDERER channel
$packer->add(
    Channels::RENDERER->value,  // <-- The Channel ID is required
    Events::GEOM_ADD_LINE,      // <-- The Event Type
    [ /* ... data array ... */ ] // <-- The Payload
);

// Manually add an event to the PHYSICS channel
$packer->add(
    Channels::PHYSICS->value,   // <-- Specify the PHYSICS channel
    Events::PHYSICS_APPLY_FORCE,
    [ $playerId1, $playerId2, 500.0, 0.0 ] // id1, id2, forceX, forceY
);

return $packer->finalize();
```
