# Phrost\LiveReload Documentation

The `Phrost\LiveReload` class is a utility that enables hot-reloading of your PHP game logic. It allows you to save changes to your PHP files and see them reflected in the running game *without* restarting the main `PhrostBinary` executable.

It works by serializing your entire `$world` state, telling the engine to reload the script, and then unserializing the state back into the new script.

---

## Core Concept: File-Based Polling

The live reload system works by watching for a specific file: `shutdown.flag`.

1.  **Polling:** The `LiveReload::poll()` method is called at the very beginning of every `Phrost_Update` frame.
2.  **Flag Check:** `poll()` checks if the `shutdown.flag` file exists. This file is typically created by an external tool (like a file watcher in your IDE or a build script) when you save a `.php` file.
3.  **Magic String:** If the flag is found, the class performs a "save" or "reset" operation and then calls `die("unloading")`.
4.  **Engine Reload:** The Phrost engine is built to watch the output of the PHP script. When it sees the exact string "unloading", it knows it must terminate the current PHP process and start a new one, thus reloading all the PHP files from scratch.

---

## How to Use: A Full Workflow

Using the `LiveReload` class requires setup in `game-logic.php` at both initialization and in the main loop.

### 1. Initialization
When your script first starts, create an instance of `LiveReload` and store it in your global `$world` array.

```php
<?php
use Phrost\LiveReload;
use Phrost\ChannelPacker;

// --- At the bottom of game-logic.php ---

// Define the paths
$shutdown_flag_path = __DIR__ . "/../../shutdown.flag";
$save_path = __DIR__ . "/../../save.data";

$world = [
    "window" => new Window("My Game", 800, 600),
    // ...
    "liveReload" => new LiveReload($shutdown_flag_path, $save_path), //
    "assetsLoaded" => false,
];

Phrost_Run($packer->finalize());
```


### 2. Polling (In `Phrost_Update`)

The **very first thing** you do inside `Phrost_Update` must be to call `poll()`.

```php
<?php
function Phrost_Update(int $elapsed, float $dt, string $eventsBlob = ""): string
{
    global $world;

    // --- 1. POLL FOR RELOAD ---
    // This MUST be the first call. If it reloads, it will die("unloading")
    // and the rest of the function will not run.
    /** @var LiveReload $live_reload */
    $live_reload = $world["liveReload"];
    $live_reload->poll($world["assetsLoaded"]); //

    // ... rest of your game loop ...
}
```

### 3. Handling `Phrost_Wake`

When the script reloads, `poll()` will check for the `save.data` file. If it exists, `poll()` will call `Phrost_Wake()` with its contents.

However, the file paths (`$shutdown_flag_path`, `$save_path`) are not saved during serialization. You **must** re-inject them inside `Phrost_Wake`.


```php
<?php
function Phrost_Wake(string $data): void
{
    global $world, $save_path, $shutdown_flag_path;

    $world = unserialize($data);
    echo "World state restored.\n";

    // --- RE-INJECT TRANSIENT PROPERTIES ---
    if (!isset($world["liveReload"])) {
        $world["liveReload"] = new LiveReload($shutdown_flag_path, $save_path);
    } else {
        // Re-inject paths into the existing object
        $world["liveReload"]->setPaths($shutdown_flag_path, $save_path); //
    }
}
```

* * *

The Two Reload Modes
-----------------------

The system supports two different kinds of reloads, controlled by the content of the `shutdown.flag` file.

### 1. "Save" (Stateful Reload)

This is the default. It saves your game's state and reloads the code.

1.  An external process creates `shutdown.flag` (file can be empty or contain "save").

2.  `poll()` sees the flag.

3.  `poll()` calls `Phrost_Sleep()`, which serializes the entire `$world` array.

4.  The serialized string is saved to `save.data`.

5.  `poll()` calls `die("unloading")`.

6.  The engine reloads the PHP script.

7.  The new script's `poll()` method sees `save.data` exists.

8.  `poll()` calls `Phrost_Wake()`, which restores the `$world`.


**Result:** The game continues exactly where it left off, but with your new PHP code.

### 2. "Reset" (Hard Reset)

This clears all engine state and `save.data`, starting the game from scratch as if it were just launched. This is triggered by in-game key commands (e.g., **Ctrl+R**).

This is a **two-frame process** to ensure the engine is properly cleaned.

*   **Frame 1: Request (e.g., Ctrl+R is pressed)**

    1.  Your code in `Phrost_Update` calls `live_reload->resetOnEvent(...)`.

    2.  `resetOnEvent` does _not_ reset. It only sets an internal flag: `$this->resetPending = true`.

    3.  The frame finishes normally.

*   **Frame 2: Action & Cleanup**

    1.  `poll()` runs, but does nothing.

    2.  Your `Phrost_Update` function checks `if ($live_reload->isResetPending())`. This is now `true`.

    3.  You call `$live_reload->reset($world, $packer)`.

    4.  `reset()` packs `SPRITE_REMOVE` and `PHYSICS_REMOVE_BODY` events for _every single entity_ in your `$world`. This tells the engine to clear its memory.

    5.  `reset()` **deletes** `save.data`.

    6.  `reset()` **creates** `shutdown.flag` with the text `"reset"`.

    7.  The function returns. The `$packer` sends all the REMOVE commands to the engine.

*   **Frame 3: Reload**

    1.  `poll()` runs. It sees `shutdown.flag` exists and its content is `"reset"`.

    2.  It _skips_ the save logic and immediately calls `die("unloading")`.

    3.  The engine reloads the PHP script.

*   **Frame 4: Fresh Start**

    1.  The new script starts. `poll()` runs.

    2.  `save.data` does _not_ exist (it was deleted in Frame 2).

    3.  The game proceeds to your `if (!$world["assetsLoaded"])` block and loads everything from scratch.


* * *

Shutting Down
----------------

The class also provides a `shutdown()` method, which simply calls `exit(10)`. This is a hard-coded value the `PhrostBinary` executable can be programmed to listen for as a signal to quit entirely.
