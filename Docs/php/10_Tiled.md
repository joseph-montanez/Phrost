# Phrost\Tiled Documentation

The `Phrost\Tiled` class is a static utility class designed to parse a Tiled map file (`.tmx`) and its associated tileset (`.tsx`). Its primary job is to automatically populate your `$world` array with all the necessary `Sprite` and `PhysicsBody` objects defined in your map.

---

## How to Use

`Tiled` provides a single static method, `loadMap`. You typically call this once inside your `if (!$world["assetsLoaded"])` block in `game-logic.php`.

```php
<?php
use Phrost\Tiled;
use Phrost\ChannelPacker;

// --- Inside Phrost_Update(), during initial asset loading ---

if (!$world["assetsLoaded"]) {
    // 1. Create a packer
    $packer = new ChannelPacker();

    // 2. Call the static loader
    Tiled::loadMap(
        $world,  // Pass the global $world (by reference)
        $packer, // Pass the packer
        __DIR__ . "/../assets/my_level.tmx" // Path to your .tmx file
    );

    // ... load other assets ...

    $world["assetsLoaded"] = true;
    return $packer->finalize();
}
```


* * *

⚙️ How It Works
---------------

The `loadMap` method performs several steps automatically:

1.  **Loads Files:** It loads and parses the main `.tmx` map file. It then finds the path to the `.tsx` tileset file within the map data and loads that as well.

2.  **Stores Map Info:** It saves useful information, like tile dimensions and texture paths, into the `$world["mapInfo"]` array for you to reference later.

3.  **Iterates Layers:** It loops through each `<layer>` in your `.tmx` file in the order they are defined.

4.  **Creates Sprites:** For every non-empty tile (where GID > 0), it automatically:

    *   Generates a unique `Id`.

    *   Creates a new `Sprite` object.

    *   Sets the `texturePath` (from the tileset).

    *   Calculates and sets the `position` based on the tile's (x, y) location and layer.

    *   Sets the `size` (from the map's tile dimensions).

    *   Calculates and sets the `sourceRect` by finding the tile's (x, y) pixel coordinate on the spritesheet.

    *   Adds the new sprite to `$world["sprites"]` and calls `packDirtyEvents($packer)` to send the `SPRITE_ADD` command to the engine.

5.  **Handles Z-Depth:** Layers are processed in order. The first layer is drawn at `z=0.0`, the next at `z=1.0`, and so on, ensuring correct visual stacking.


* * *

Physics & Collision Layers
-----------------------------

The `Tiled` loader has special support for automatically creating your game's static collision geometry.

To mark a layer in your map as a "collision layer," you must add a **custom boolean property** to that layer in the Tiled editor.

*   **Name:** `collision`

*   **Type:** `bool`

*   **Value:** `true` (checked)


### The Collision Logic

When `loadMap` encounters a layer with this exact property:

1.  It creates the visual `Sprite` for each tile on that layer, just as it does for any other layer.

2.  Immediately after creating the sprite, it **also creates a `PhysicsBody`** using the **exact same ID**.


This new `PhysicsBody` is automatically configured to be a static, immovable object:

*   **Body Type:** `static` (type 1).

*   **Shape:** A box matching the tile's width and height.

*   **Position:** Set to match the tile's world position.


It then adds the body to `$world["physicsBodies"]` and calls `packDirtyEvents($packer)` to send the `PHYSICS_ADD_BODY` command. This instantly populates your world with a static, tile-based collision map that perfectly matches your visuals.
