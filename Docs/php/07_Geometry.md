# Phrost\Geometry Documentation

The `Phrost\Geometry` class provides a high-level way to draw simple, primitive shapes like points, lines, and rectangles.

---

## Core Concept: "Write-Once" Shapes

The `Geometry` class is fundamentally different from `Sprite`. Based on the engine's events, geometry is considered **"write-once"**.

This means:
* You **create** a shape (e.g., a line with specific coordinates) and send it to the engine once.
* After creation, you **CANNOT** move, resize, or change its shape.
* You **CAN** change its color.
* You **CAN** remove it from the screen.

This class is ideal for debug drawing or map boundaries.

### World-space vs. Screen-space

By default, all geometry exists in **World-space**, meaning it moves with the camera (just like a `Sprite`).

You can optionally flag geometry as **Screen-space**, which "sticks" it to the screen. This is ideal for UI elements like health bars, menus, or score displays that should not move when the camera moves.

---

## How to Use: A Full Workflow

Here is the complete step-by-step process for creating and managing a geometry object.

### Step 1: Create the Geometry Object
First, create an instance of `Geometry`, giving it a unique ID.

```php
<?php
use Phrost\Geometry;
use Phrost\Id;

// 1. Generate an ID and a key
$id = Id::generate();
$key = Id::toHex($id);

// 2. Create the Geometry object
$myLine = new Geometry($id[0], $id[1]);
```


### Step 2: Configure the Shape (Required)

Before you can draw anything, you **must** call one of the configuration methods to define its shape. This can only be done once, before the first `packDirtyEvents()` call.

You can also set its color, Z-depth (draw order), or screen-space flag at this time.

```php
<?php
// --- Choose ONE shape ---

// Option A: Configure as a Line
$myLine->setLine(10.0, 10.0, 100.0, 10.0);

// Option B: Configure as a Filled Rectangle
$myRect = new Geometry($id[0], $id[1]);
$myRect->setRect(50.0, 50.0, 200.0, 100.0, $filled = true);

// Option C: Configure as an Outline Rectangle
$myRect->setRect(50.0, 50.0, 200.0, 100.0, $filled = false);

// Option D: Configure as a Point
$myPoint = new Geometry($id[0], $id[1]);
$myPoint->setPoint(25.0, 25.0); //

// --- Optional Configuration ---
$myLine->setColor(255, 0, 0, 255); // Set color to red
$myLine->setZ(10.0); // Set draw depth
```
#### New in this version: Setting Screen-Space

To make a UI element that doesn't move with the camera, call `setIsScreenSpace(true)` **before** you pack the event.

```php
<?php
// Create a UI panel
$uiPanel = new Geometry($id[0], $id[1]);
$uiPanel->setRect(10, 10, 200, 50, true); // 10px from top-left
$uiPanel->setColor(0, 0, 0, 150); // Semi-transparent black
$uiPanel->setZ(100.0); // Draw on top of everything

// --- THIS IS THE NEW FLAG ---
$uiPanel->setIsScreenSpace(true); //

// Now, when $uiPanel->packDirtyEvents() is called,
// it will be "stuck" to the screen at (10, 10).
```

### Step 3: Pack and Store (First Frame)

Store the object and call `packDirtyEvents()`. On this first call, it will see the `isNew` flag and send the correct `GEOM_ADD_LINE`, `GEOM_ADD_RECT`, etc. event to the engine.

```php
<?php
// Store it
$world["geometry"][$key] = $myLine;
$world["ui"][$key] = $uiPanel;

// In your main loop, pack its events.
// This sends the GEOM_ADD_LINE event.
$myLine->packDirtyEvents($packer);
// This sends the GEOM_ADD_FILL_RECT event with the screen-space flag.
$uiPanel->packDirtyEvents($packer);
```

* * *

Updating Geometry
--------------------

As mentioned, your options for updating geometry are limited. You **cannot** change a shape's coordinates, type (line/rect), or its `isScreenSpace` flag after it has been created.

### Changing Color

This is the only property you can change after creation. The `setColor()` method works just like in the `Sprite` class, using a dirty flag.

```php
<?php
// --- In a later frame ---

// This sets the $dirtyFlags["color"] = true
$myLine->setColor(0, 255, 0, 255); // Change to green

// This will see the dirty flag and pack a GEOM_SET_COLOR event
$myLine->packDirtyEvents($packer); //
```

### Removing Geometry

To remove the shape, call the `remove()` method. This is a direct command that immediately adds a `GEOM_REMOVE` event to the packer.

```php
<?php
// --- To remove the line ---

// This immediately packs the GEOM_REMOVE event
$myLine->remove($packer); //

// You should also remove it from your world array
unset($world["geometry"][$key]);
```
