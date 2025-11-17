Zig Plugin Architecture & Phrost Event System
-----------------------------------------------------

This document explains the Phrost engine's binary, event-driven architecture. This system allows high-performance game logic, written in compiled languages like Zig, to be loaded as a plugin and run by the core engine, side-by-side with or in place of PHP scripting.

* * *

### 1. The Core Event System

The engine's foundation is a language-agnostic, event-driven model. All communication is handled by sending and receiving binary data "blobs."

#### 1.1. Channels 📬

Channels are used to route outgoing commands from a plugin (Zig) to the correct engine subsystem. Think of them as delivery addresses. The primary channels are defined in `phrost.zig`:

*   `renderer = 0`: For all drawing commands (sprites, geometry).

*   `input = 1`: For configuring input (not typically sent _to_).

*   `physics = 2`: For creating bodies and applying forces.

*   `audio = 3`: For playing/stopping sounds.

*   `gui = 4`: (Unused in provided files).

*   `window = 5`: For changing the window title or size.

*   `script = 6`: For script-to-script or plugin-to-script communication.


When your Zig plugin wants to draw a sprite, it packs a `spriteAdd` event into the **`renderer` channel's** command buffer.

#### 1.2. Events

Events are the specific commands or notifications. The `Events` enum defines every possible message, such as:

*   **Outgoing (Plugin -> Engine):** `spriteAdd` , `physicsApplyForce` , `audioPlay` , `windowTitle`.

*   **Incoming (Engine -> Plugin):** `inputKeydown` , `inputMousemotion` , `physicsCollisionBegin` , `windowResize`.


#### 1.3. Payloads

A payload is the data associated with an event. Every event has a corresponding `extern struct` that defines its exact binary layout, C-style.

For example, the `spriteMove` event uses `PackedSpriteMoveEvent` :

Code snippet

```zig
pub const PackedSpriteMoveEvent = extern struct {
    id1: i64, // Primary ID of the sprite.
    id2: i64, // Secondary ID of the sprite.
    positionX: f64, // New X position.
    positionY: f64, // New Y position.
    positionZ: f64, // New Z position (depth).
};
```

This strict, C-compatible layout is what allows any language (PHP, Zig, Swift) to read and write data reliably.

* * *

### 2. How Zig Hooks into the Engine

A Zig plugin is a **C-compatible dynamic library** (`.dll`, `.dylib`, or `.so`) that the Phrost engine can load at runtime. The engine hooks into the plugin by calling four specific, exported C-style functions.

#### 2.1. The Build Target

Your `build.zig` file must compile the code as a dynamic library and link libc (for `malloc`/`free`) .

Code snippet

```zig
// build.zig
const lib = b.addLibrary(.{
    .linkage = .dynamic, // <-- Creates .dll/.so/.dylib
    .name = "zig_phrost_plugin",
    .root_module = lib_mod,
});
lib.linkLibC(); // <-- Allows use of c.malloc/c.free [cite: 294]
b.installArtifact(lib);
```

#### 2.2. The Plugin Lifecycle (The 4 Exported Functions)

The Phrost engine looks for these four function names. Your `main.zig` file **must** export them.

1.  **`export fn Phrost_Wake(out_length: *i32) ?*anyopaque`**

    *   **When:** Called once when the plugin is first loaded _or_ when the application regains focus (e.g., on mobile).

    *   **Purpose:** To initialize the plugin's state and "catch up" the engine.

    *   **Action:** In your code, this function initializes the `world` struct , tries to load `save.dat` , and—critically—**re-emits all `spriteAdd` and `packTextureLoad` commands** for every sprite loaded from the save file. This repopulates the engine's renderer with the sprites that the Zig plugin knows about.

2.  **`export fn Phrost_Update(ticks: u64, dt: f64, eventsBlob: ?*const anyopaque, eventsLength: i32, out_length: *i32) ?*anyopaque`**

    *   **When:** Called **every single frame** by the game loop. This is your `game_logic.zig`.

    *   **Purpose:** The main entry point for all game logic.

    *   **Action:** This function is a 3-step process:

        1.  **Process Events:** It receives the `eventsBlob` (all input, physics, etc.) and uses `processIncomingEvents` to unpack it and update the `world` state (e.g., `world.mouseX`).

        2.  **Run Logic:** It calls your game logic functions, like `updateAndMoveSprites` and `spawnNewSprites` .

        3.  **Return Commands:** It packs all _new_ commands (like `spriteMove` ) into channel buffers and returns a final, channel-packed blob to the engine .

3.  **`export fn Phrost_Sleep()`**

    *   **When:** Called once when the plugin is about to be unloaded _or_ when the application loses focus (e.g., on mobile).

    *   **Purpose:** To persist the game state.

    *   **Action:** This function's _only_ job is to save the current state. It serializes the `world.sprites` list directly into the `save.dat` file .

4.  **`export fn Phrost_Free(data_ptr: ?*anyopaque) void`**

    *   **When:** Called by the engine immediately after it finishes processing a command blob returned from `Phrost_Update` or `Phrost_Wake`.

    *   **Purpose:** To free the memory that Zig allocated for the command blob.

    *   **Action:** It calls `c.free(ptr)` to release the memory allocated by `c.malloc` in the `finalizeAndReturn` function. This prevents memory leaks.


* * *

### 3. Zig Event & Channel Handling (In Practice)

This is the practical workflow inside your `Phrost_Update` function.

#### 3.1. Receiving: Unpacking the _Flat_ Event Blob (Engine -> Zig)

The `eventsBlob` passed _into_ `Phrost_Update` is a **flat binary blob**. It is _not_ channel-packed. Its format is:

`[Event Count: u32][Event 1 Header][Event 1 Payload][Event 2 Header][Event 2 Payload]...`

Your `process_events.zig` file handles this:

1.  It initializes an `EventUnpacker` directly on the raw `blob_slice`.

2.  It enters a `while(true)` loop that robustly reads one event at a time.

3.  **Inside the loop:**

    *   It reads the `event_type_raw: u32`.

    *   It discards the 8-byte timestamp.

    *   It looks up the `payload_size` using `event_payload_sizes`.

    *   It does a `switch(event_type)` to handle the event.

    *   For example, `inputMousemotion` reads the `PackedMouseMotionEvent` and updates `world.mouseX` and `world.mouseY` .

    *   `windowResize` reads its payload to update `world.windowWidth` and `world.windowHeight` , which are then used for sprite boundary checks .


#### 3.2. Sending: Packing the _Channel-Packed_ Command Blob (Zig -> Engine)

The `?*anyopaque` pointer returned _from_ `Phrost_Update` is a **channel-packed binary blob**. Its format is more complex, designed for efficient routing by the engine:

`[Channel Count: u32][Channel 1 Index][Channel 2 Index]...[Channel 1 Data Blob][Channel 2 Data Blob]...`

Your `main.zig`'s `finalizeAndReturn` function builds this using two helper structs:

1.  **`ph.CommandPacker`**: This packs _individual events_ into a specific channel's buffer (which is just an `std.ArrayList(u8)`).

    *   In `Phrost_Update`, you create separate packers for each channel you use: `packer_render` and `packer_window`.

    *   When game logic runs, `updateAndMoveSprites` calls `packer_render.pack(ph.Events.spriteMove, ...)`.

    *   `updateWindowTitle` calls `packer_window.pack(ph.Events.windowTitle, ...)`.

2.  **`ph.ChannelPacker`**: This is the _finalizer_. It takes all the individual channel buffers and combines them into the final blob format described above.

    *   `finalizeAndReturn` creates a `channel_inputs` array containing the `renderer` and `window` data blobs.

    *   It calls `ph.ChannelPacker.finalize(...)` to write this final blob into `world.final_command_buffer`.

    *   Finally, it `c.malloc`'s a new buffer, copies the final blob into it, and returns the pointer to the engine .


* * *

### 4\. Loading and Toggling the Zig Plugin from PHP

Your PHP snippet is the "key" that tells the engine to start this entire Zig plugin process.

#### 4.1. Loading the Plugin (Your PHP Snippet)

Here is an analysis of your provided code:

```php
<?php
if (!$world["pluginLoaded"]) {
    // 1. Determine the correct library file name
    $libExtension = match (PHP_OS_FAMILY) {
        "Darwin" => "libzig_phrost_plugin.dylib",
        "Linux" => "libzig_phrost_plugin.so",
        "Windows" => "zig_phrost_plugin.dll",
        // ...
    };
    $path = realpath(__DIR__ . "/" . $libExtension);

    // 2. Send the PLUGIN_LOAD event
    $packer->add(Phrost\Events::PLUGIN_LOAD, [
        strlen($path),
        $path,
    ]);
    $world["pluginLoaded"] = true;
}
```

This code snippet is _missing two components_ based on the Phrost API definitions:

1.  **Missing Channel:** The `ChannelPacker`'s `add()` method, as shown in `01_Getting-Started.md`, requires the _channel_ as the first argument (e.g., `Channels::RENDERER->value`). Plugin-related events should almost certainly be sent to the `RENDERER` or `SCRIPT` channel.

2.  **Incomplete Payload:** The `PLUGIN_LOAD` event (`1001` ) uses `PackedPluginLoadHeaderEvent`. This struct requires `channelNo: u32` (the channel the plugin should _initially subscribe to_) and `pathLength: u32`.


A **corrected** version of your PHP command, assuming it should go to the `RENDERER` channel and subscribe the plugin to the `SCRIPT` channel (`6`), would look like this:

```php
// Corrected PHP for loading a plugin
$packer->add(
    Channels::RENDERER->value,     // 1. Send this command TO the renderer
    Phrost\Events::PLUGIN_LOAD,    // 2. The event type is PLUGIN_LOAD
    [
        Channels::SCRIPT->value,   // 3. Payload[0]: (channelNo) Subscribe plugin to SCRIPT channel
        strlen($path),             // 4. Payload[1]: (pathLength) [cite: 85]
        $path                      // 5. Payload[2]: The path string itself
    ]
);
```

When the engine receives this, it loads the dynamic library at `$path`, finds the `Phrost_...` functions, and assigns the plugin an ID (e.g., `0`).

#### 4.2. Activating and Toggling the Plugin (The Missing Step)

Your PHP code _loads_ the plugin, but it **does not activate it**. Loading just makes the plugin available. To _toggle_ the active logic from "PHP" to "Zig," you must send the `PLUGIN_SET` event.

*   `Events::pluginSet = 1003`

*   `PackedPluginSetEvent = extern struct { pluginId: u8 }`


The Phrost engine itself is `pluginId 255` (a special value for the internal PHP script). Your newly loaded Zig plugin is likely `pluginId 0`.

Therefore, to correctly implement the toggle, your PHP logic should be:

```php
<?php
// --- Corrected PHP Logic for Toggling ---

if ($event["keycode"] === Keycode::D) {
    // 1. Load the plugin ONCE
    if (!$world["pluginLoaded"]) {
        // (Do the $packer->add(..., Events::PLUGIN_LOAD, ...) from above)
        $world["pluginLoaded"] = true;
        $world["zigPluginId"] = 0; // Assume the first loaded plugin is ID 0
        $world["phpPluginId"] = 255; // Internal PHP script ID
    }

    // 2. Toggle the active logic
    if ($world["activeLogic"] === "Zig") {
        $world["activeLogic"] = "PHP";
        $packer->add(
            Channels::RENDERER->value,
            Events::PLUGIN_SET,
            [$world["phpPluginId"]] // Activate PHP [cite: 6, 87]
        );
    } else {
        $world["activeLogic"] = "Zig";
        $packer->add(
            Channels::RENDERER->value,
            Events::PLUGIN_SET,
            [$world["zigPluginId"]] // Activate Zig [cite: 6, 87]
        );
    }
}
```

When the engine receives `PLUGIN_SET` with `pluginId 0`, it stops calling the PHP `Phrost_Update` function and starts calling your Zig `Phrost_Update` function every frame. When it receives `pluginId 255`, it switches back.
