# Sprite & SpriteAnimated Documentation

This guide explains how to use the `Sprite` and `SpriteAnimated` classes, which are fundamental to rendering any visual object in Phrost.

* **`Phrost\Sprite`**: The base class for all renderable 2D objects. It manages properties like position, size, color, and texture.
* **`Phrost\SpriteAnimated`**: An extension of `Sprite` that adds powerful logic to manage frame-by-frame animations by automatically updating the sprite's texture region (`sourceRect`).

---

## Phrost\Sprite (The Base Class)

The `Sprite` class is the foundation for any entity you want to draw to the screen.

### Core Concept: The "Dirty Flag" System

A `Sprite` object is highly efficient. It **does not** send an update event to the engine on every single frame. Instead, it uses a "dirty flag" system:

1.  **You change a property:** You call a setter method, like `$sprite->setPosition(100, 50, 0)`.
2.  **A flag is set:** The method updates the PHP object's property and sets an internal flag, e.g., `$this->dirtyFlags["position"] = true`.
3.  **You pack events:** At the end of your `Phrost_Update` loop, you call `$sprite->packDirtyEvents($packer)`.
4.  **Events are sent:** The `packDirtyEvents` method checks all dirty flags. If `$dirtyFlags["position"]` is true, it adds a `SPRITE_MOVE` event to the packer. If no flags are set, it does nothing.

When a sprite is first created, its `$isNew` flag is true. The *first* time `packDirtyEvents` is called, it will send the all-in-one `SPRITE_ADD` event and a `SPRITE_TEXTURE_LOAD` event (if a texture path was set).

### Example: Creating a Basic Sprite

```php
<?php
use Phrost\Sprite;
use Phrost\Id;

// --- Inside Phrost_Update() or an init function ---

// 1. Generate an ID and a key
$id = Id::generate();
$key = Id::toHex($id);

// 2. Create the Sprite object
$mySprite = new Sprite($id[0], $id[1]);

// 3. Set its properties. This sets the dirty flags.
$mySprite->setPosition(100.0, 50.0, 0.0);
$mySprite->setSize(32, 32);
$mySprite->setTexturePath(__DIR__ . "/../my-texture.png");

// 4. Store it
$world["sprites"][$key] = $mySprite;

// 5. In the update loop, pack its events.
// On the first call, this sends SPRITE_ADD.
// On later calls, it sends SPRITE_MOVE only if setPosition() was called.
$mySprite->packDirtyEvents($packer);
```

## Phrost\SpriteAnimated (The Animation Class)

This class extends `Sprite` and adds all the logic needed to play frame-by-frame animations.

How It Works

The "magic" of `SpriteAnimated` is that it **automates the "dirty flag" system** for animations.

1. You define animations (like "idle" or "run") by providing a list of texture coordinates (`x, y, w, h`) and durations for each frame.

2. You call `$sprite->play("run", true)` to start an animation.

3. In the main loop, you must call `$sprite->update($dt)`. This method checks if enough time (`$dt`) has passed to advance to the next frame.

4. When it's time for a new frame, update() calls an internal applyFrame().

5. `applyFrame()` simply calls the parent's `$this->setSourceRect(...)` method.

6. This sets the `dirtyFlags["source_rect"] = true`.

7. When you call `$sprite->packDirtyEvents($packer)`, it sees this flag and sends a `SPRITE_SET_SOURCE_RECT` event to the engine.

The engine knows nothing about "animations"; it only knows how to change a sprite's source rectangle. The `SpriteAnimated` class handles all the state, timing, and looping logic in pure PHP.

## How to Use (The Warrior Example)

The best way to use `SpriteAnimated` is to create your own class that extends it, as seen in `Warrior.php`.

### 1. Extend the Class

Create a class for your entity. This gives you a place to define its specific animations and logic.

```php
<?php
namespace App;
use Phrost\SpriteAnimated;

class Warrior extends SpriteAnimated
{
    // ... animation definitions will go here ...
}
```

### 2. Define Animations

Inside your new class, create a method to define your animations. The `generateFixedFrames` helper is perfect for grid-based sprite sheets.

```php
<?php
// Inside App\Warrior class
public function initializeAnimations(): void
{
    $this->animations = []; // Clear old animations

    $frameWidth = 64;
    $frameHeight = 44;
    $paddingX = 5;
    $paddingY = 0;
    $spriteSheetColumns = 6;

    // --- "idle" animation (Row 1) ---
    $idleStartY = ($frameHeight + $paddingY) * 0;
    $idleFrames = SpriteAnimated::generateFixedFrames(
        0, $idleStartY,
        $frameWidth, $frameHeight,
        6, // 6 frames
        0.1, // 0.1 seconds per frame
        $spriteSheetColumns,
        $paddingX, $paddingY
    );
    $this->addAnimation("idle", $idleFrames);

    // --- "run" animation (Row 2) ---
    $runStartY = ($frameHeight + $paddingY) * 1;
    $runFrames = SpriteAnimated::generateFixedFrames(
        0, $runStartY,
        $frameWidth, $frameHeight,
        8, // 8 frames
        0.08, // 0.08 seconds per frame
        $spriteSheetColumns,
        $paddingX, $paddingY
    );
    $this->addAnimation("run", $runFrames);
}
```

### 3. Create and Play in `game-logic.php`

When you create your `Warrior`, you call your new method and then `play()` to start.

```php
<?php
// --- Inside Phrost_Update() ---

// --- Create the Warrior ---
$id = Id::generate();
$warrior = new Warrior($id[0], $id[1]);
$warrior->setPosition(100.0, 40.0, 0.0);
$warrior->setSize(64, 44);
$warrior->setTexturePath(__DIR__ . "/../Warrior_Sheet-Effect.png");

// Call the new function to set animations
$warrior->initializeAnimations();

// Start playing the 'idle' animation
$warrior->play("idle", true); // Loop 'idle'

$key = Id::toHex([$warrior->id0, $warrior->id1]);
$world["sprites"][$key] = $warrior;
```

### 4. Update in the Main Loop

In `Phrost_Update`, you must call `update()` on every animated sprite. This is what advances its frame timer.

```php
<?php
// --- Inside Phrost_Update() ---

foreach ($world["sprites"] as $sprite) {
    if ($sprite instanceof SpriteAnimated) {
        // This advances the animation frame
        $sprite->update($dt); //

        // This sends the SPRITE_SET_SOURCE_RECT if the frame changed
        $sprite->packDirtyEvents($packer); //
    }
}
```

### Example: State-Based Animation

You can easily control animations based on game state, like player movement. The `isLooping()` and `isPlaying()` getters are essential for this.

This example from `game-logic.php` shows how to play a "run" or "idle" animation without interrupting a non-looping "attack" animation.

```php
<?php
// --- Inside Phrost_Update() ---

if ($playerSprite && $playerBody) {
    $targetVx = 0.0;
    // ... logic to set $targetVx based on input ...

    // Don't interrupt a non-looping animation (like 'attack')
    if ($playerSprite->isLooping() || !$playerSprite->isPlaying()) { //
        if ($targetVx != 0.0) {
            // Play 'run' animation, loop it, don't force restart
            $playerSprite->play("run", true, false); //
        } else {
            // Play 'idle' animation, loop it, don't force restart
            $playerSprite->play("idle", true, false); //
        }
    }
}
```

## Live Reload & Serialization

The Phrost live reload feature works by **serializing** your entire global `$world` state (using `Phrost_Sleep`) and then **unserializing** it (using `Phrost_Wake`) when the code is reloaded.

**The Problem:** When an object like `Warrior` is unserialized, it's just a "bag of data." Its complex properties (like the `$animations` array) are restored, but any _logic_ needed to build them is not re-run. If you change your animation timings in the code, the reloaded object will still have the _old_ animation data.

**The Solution:** Use PHP's magic `__serialize()` and `__unserialize()` methods.

The `Warrior` class provides a perfect template:

`__serialize()`

This is called by PHP just _before_ `serialize($world)` in `Phrost_Sleep`. Its job is to return an array of all the data that needs to be saved. The simplest way is to just save everything.

```php
<?php
// Inside App\Warrior class
public function __serialize(): array
{
    // This gets all properties (public, protected, private)
    // from this class and its parent (SpriteAnimated, Sprite)
    return get_object_vars($this); //
}
```

`__unserialize()`

This is called by PHP just after `unserialize($data)` in `Phrost_Wake`. Its job is to restore the data and re-run any initialization logic.

```php
<?php
// Inside App\Warrior class
public function __unserialize(array $data): void
{
    // This loop restores all the saved properties
    foreach ($data as $key => $value) {
        $this->{$key} = $value;
    } //

    // --- THIS IS THE CRITICAL STEP ---
    // Now that all properties (like id0, id1) are restored,
    // we re-run our animation builder. This ensures the
    // $animations array is fresh after a live reload.
    $this->initializeAnimations(); //

    echo "Warrior {$this->id0} has unserialized and rebuilt animations.\n";
}
```

By adding these two methods to your `SpriteAnimated` child classes, you ensure that they are fully and correctly restored after every live reload.
