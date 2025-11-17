# Phrost\Audio Documentation

The `Phrost\Audio` class manages a single audio track using a "retained mode" approach. This means the PHP object holds the state (like volume) and automatically sends update commands to the engine when its properties change.

---

## Core Concept: Asynchronous Loading & Hydration

Unlike sprites, audio files are not ready to use immediately. They must be loaded by the engine in the background. This requires a 3-step "handshake":

1.  **Request (PHP -> Engine):** You first create an `Audio` object and call its `$audio->load()` method. In your main loop, `packDirtyEvents()` sees this and sends an `AUDIO_LOAD` event to the engine.
2.  **Load (Engine):** The engine receives the request and begins loading the audio file from disk.
3.  **Response (Engine -> PHP):** When the engine finishes, it sends an `AUDIO_LOADED` event *back* to your PHP script. This event contains the new engine-side `audioId` for that sound.
4.  **Hydrate (PHP):** Your `Phrost_Update` function *must* catch this `AUDIO_LOADED` event, find the correct `Audio` object, and call its `$audio->setLoadedId(int $audioId)` method.

An `Audio` object **will not** send `play`, `pause`, `stop`, or `setVolume` commands to the engine until `setLoadedId()` has been called and it is "hydrated".

---

## How to Use: A Full Workflow

Here is the complete step-by-step process for loading and playing a sound.

### Step 1: Create and Store the Audio Object

First, create an instance of the `Audio` class and store it somewhere accessible, like your global `$world` array.

```php
<?php
use Phrost\Audio;

// In your global state initialization
global $world;
$world["sounds"] = [
    "jump" => new Audio(__DIR__ . "/../assets/jump.wav", 0.8), // Path and optional volume
    "music" => new Audio(__DIR__ . "/../assets/music.ogg", 0.5)
];
```

### Step 2: Request the Load

During your asset loading phase (e.g., inside `if (!$world["assetsLoaded"])`), you must call `load()` on the audio objects you want to use.

```php

<?php
// Inside the if (!$world["assetsLoaded"]) block in Phrost_Update()

// This sets the "load" dirty flag
$world["sounds"]["jump"]->load(); //
$world["sounds"]["music"]->load(); //

// ...
// The packDirtyEvents() call at the end of the init block
// will send the AUDIO_LOAD commands to the engine.
```

### Step 3: Handle the Engine's Response (Hydration)

In your main `Phrost_Update` event loop, you must watch for the `AUDIO_LOADED` event to "hydrate" your objects.

> **Note:** The `AUDIO_LOADED` event only contains an `audioId`. To link this ID back to the correct `Audio` object (e.g., "jump" or "music"), you may need to rely on the order of events or modify your engine to send back more identifying information.
>
> This example assumes you can identify the sound that was loaded (e.g., by matching it to the first non-loaded object).

```php
<?php
// Inside the main foreach ($events as $event) loop in Phrost_Update()

if ($event["type"] === Events::AUDIO_LOADED->value) {
    $newAudioId = $event["audioId"]; //

    // Find the first sound object that is waiting for an ID
    foreach ($world["sounds"] as $key => $audio) {
        if (!$audio->isLoaded()) { //
            $audio->setLoadedId($newAudioId); //
            echo "Audio '{$key}' is loaded and ready (ID: {$newAudioId})!\n";

            // If volume was set before, it will now be synced

            // We found our match, stop searching
            break;
        }
    }
}
```

### Step 4: Control the Audio

Once an object is loaded, you can call its control methods. These methods simply set dirty flags.

```php
<?php
// Example: Play the jump sound on a key press
if (isset($world["inputState"][Keycode::SPACE]) && $world["sounds"]["jump"]->isLoaded()) {
    $world["sounds"]["jump"]->play(); //
}

// Example: Play the music
if (!$world["sounds"]["music"]->isPlaying) { // (Assuming you add an isPlaying property)
    $world["sounds"]["music"]->play(); //
}
```

### Step 5: Pack Events in the Main Loop

Finally, at the end of every `Phrost_Update` frame, you must call `packDirtyEvents()` on all your audio objects. This sends any queued commands (like "play" or "setVolume") to the engine.

```php
<?php
// At the end of Phrost_Update()

foreach ($world["sounds"] as $audio) {
    $audio->packDirtyEvents($packer); //
}

return $packer->finalize();
```

* * *

Static (Fire-and-Forget) Methods
----------------------------------

The `Audio` class also provides static methods for global audio control. These send commands immediately and do not require an `Audio` instance.

### Stop All Sounds

Instantly stops all audio currently playing in the engine.

```php
<?php
// Stops everything
Audio::stopAll($packer);
```

### Set Master Volume

Sets the global master volume for all sounds.

```php
<?php
// Set master volume to 50%
Audio::setMasterVolume($packer, 0.5); //
```
