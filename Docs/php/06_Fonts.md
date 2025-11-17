# Phrost\Text Documentation

The `Phrost\Text` class provides a high-level way to render text to the screen.

---

## Core Concept: A Specialized Sprite

The `Text` class is a specialized version of the `Sprite` class.

* **It EXTENDS `Sprite`:** This means it inherits all of the `Sprite`'s useful properties and methods, such as `setPosition()`, `setColor()`, and `setScale()`. You can move, tint, and resize text just like a regular sprite.
* **It OVERRIDES `packDirtyEvents()`:** This is the key difference. Instead of sending `SPRITE_ADD`, the `Text` class sends text-specific events:
    * **On creation:** It sends a `TEXT_ADD` event, which includes the font path, font size, color, position, and initial string.
    * **On update:** If you change the text string, it sends a `TEXT_SET_STRING` event.
    * **On move/color:** If you change the position or color, it *still uses the parent `Sprite` methods* to send `SPRITE_MOVE` or `SPRITE_COLOR` events.

> **Important:** The font and font size can only be set **at creation**. The engine does not currently support events for changing the font of existing text.

---

## How to Use: A Full Workflow

Here is the complete step-by-step process for creating and updating text.

### Step 1: Create the Text Object

First, create an instance of `Text`, giving it a unique ID.

```php
<?php
use Phrost\Text;
use Phrost\Id;

// 1. Generate an ID and a key
$id = Id::generate();
$key = Id::toHex($id);

// 2. Create the Text object
$myText = new Text($id[0], $id[1]);
```

### Step 2: Set Font, Text, and Position

Before you can pack the event, you **must** set the font path and font size. You should also set its initial text and position.

```php
<?php
// 3. Set font properties (REQUIRED before first pack)
$myText->setFont(__DIR__ . "/../assets/my-font.ttf", 16.0); //

// 4. Set initial string
$myText->setText("Hello, World!"); //

// 5. Set position (using the method from the parent Sprite class)
$myText->setPosition(50.0, 50.0, 0.0);
```

### Step 3: Pack and Store (First Frame)

Store the object and call `packDirtyEvents()`. On this first call, it will see the `isNewText` flag and send the full `TEXT_ADD` event to the engine.


```php
<?php
// Store it
$world["textElements"][$key] = $myText;

// In your main loop, pack its events.
// This sends the TEXT_ADD event.
$myText->packDirtyEvents($packer);
```

### Step 4: Update the Text (Later Frames)

To change the text on a later frame, just use the `setText()` method again. This will set a dirty flag.

```php
<?php
// --- In a later frame ---

// This sets the $dirtyFlags["text"] = true
$myText->setText("New String: " . $elapsed); //

// You can also move it at the same time
$myText->setPosition(50.0, 100.0, 0.0);

// This will pack both TEXT_SET_STRING and SPRITE_MOVE
$myText->packDirtyEvents($packer);
```
