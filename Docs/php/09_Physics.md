# Phrost\PhysicsBody Documentation

The `Phrost\PhysicsBody` class is a high-level interface for creating and controlling a physics object within the Phrost engine.

---

## Core Concept: The "Remote Control"

It's critical to understand that the `PhysicsBody` object in PHP is **not** the simulation. It is a "remote control" for the *real* physics body that lives and is simulated inside the engine.

* **PHP's Job (Sending Commands):** Your job is to send commands to the engine.
    * **State Changes:** When you call `$body->setVelocity(10, 0)`, you are setting a "dirty flag". At the end of the frame, `packDirtyEvents()` sends a `PHYSICS_SET_VELOCITY` command to the engine.
    * **Immediate Actions:** When you call `$body->applyImpulse($packer, 0, -100)`, you are sending a `PHYSICS_APPLY_IMPULSE` command *immediately*.

* **The Engine's Job (Sending Feedback):** The engine runs the simulation and sends feedback *back* to PHP.
    * **Sync:** The engine constantly sends `PHYSICS_SYNC_TRANSFORM` events to tell PHP the *actual* position, velocity, and rotation of the body.
    * **Collisions:** The engine sends `PHYSICS_COLLISION_BEGIN` events when bodies touch.

> **Key Takeaway:** Getters like `$body->getVelocity()` only return the *last value you set in PHP*. They do **not** tell you the body's current simulated velocity from the engine. You *must* listen for `PHYSICS_SYNC_TRANSFORM` events for that information.

---

## How to Use: A Full Workflow

Here is the complete step-by-step process for creating and managing a physics body.

### Step 1: Create the Body
First, create an instance of `PhysicsBody` with a unique ID.

```php
<?php
use Phrost\PhysicsBody;
use Phrost\Id;

// 1. Generate an ID and a key
$id = Id::generate();
$key = Id::toHex($id);

// 2. Create the PhysicsBody object
$playerBody = new PhysicsBody($id[0], $id[1]);
```

### Step 2: Configure Properties (Required)

Before the first `packDirtyEvents()` call, you must define the body's physical properties.

```php
<?php
// 3. Set core physics properties
$playerBody->setConfig(
    0, // bodyType: 0=dynamic, 1=static, 2=kinematic
    0, // shapeType: 0=box, 1=circle
    1.0, // mass
    0.7, // friction
    0.1, // elasticity (bounciness)
    1 // lockRotation = true
); //

// 4. Set shape dimensions
// For a box (shapeType 0):
$playerBody->setShape(32.0, 48.0); // 32px wide, 48px tall
// For a circle (shapeType 1):
// $playerBody->setShape(16.0, 0.0); // 16px radius, height is ignored
```

### Step 3: Set Initial State (Optional)

You can set the body's starting position or velocity _before_ it's added to the engine.

```php
<?php
// 5. Set initial position
$playerBody->setPosition(100.0, 50.0, false);

// 6. Set initial velocity (great for projectiles)
$playerBody->setVelocity(500.0, 0.0, false);
```

### Step 4: Pack and Store (First Frame)

Store the object and call `packDirtyEvents()`. This sends the `PHYSICS_ADD_BODY` command.

```php
<?php
// Store it
$world["physicsBodies"][$key] = $playerBody;

// In your main loop, pack its events.
// This sends the PHYSICS_ADD_BODY event.
// It will ALSO send PHYSICS_SET_VELOCITY if you set it above.
$playerBody->packDirtyEvents($packer);
```

* * *

Updating the Body (Sending Commands)
------------------------------------------

You control the body by calling its methods. These methods are in two categories:

### State-Based Updates (Dirty Flags)

These methods update the object's local state and set a dirty flag. The command is only sent when you call `packDirtyEvents()` at the end of the frame.

*   `setPosition(float $x, float $y)`: Teleports the body to a new position.

*   `setVelocity(float $x, float $y)`: Sets the body's velocity. This is perfect for player movement (e.g., setting X velocity to 200 while a key is held).

*   `setRotation(float $angleInRadians)`: Sets the body's angle.

```php
<?php
// --- In Phrost_Update() ---

// Example: Player movement
$targetVx = 0.0;
if (isset($world["inputState"][Keycode::LEFT])) {
    $targetVx = -200.0;
}
if (isset($world["inputState"][Keycode::RIGHT])) {
    $targetVx = 200.0;
}

// Get current Y velocity from our local copy (we don't want to stop gravity)
$currentVy = $playerBody->getVelocity()["y"];
$playerBody->setVelocity($targetVx, $currentVy);

// ...
// At the end of the loop:
$playerBody->packDirtyEvents($packer); // Sends PHYSICS_SET_VELOCITY
```

### Immediate-Action Events

These methods send a command to the engine _immediately_. They require the `$packer` as a direct argument.

*   `applyForce(ChannelPacker $packer, float $forceX, float $forceY)`: Applies a continuous force (like a rocket booster).

*   `applyImpulse(ChannelPacker $packer, float $impulseX, float $impulseY)`: Applies an instant "kick" (like a jump or explosion).

*   `remove(ChannelPacker $packer)`: Sends the `PHYSICS_REMOVE_BODY` command.

```php
<?php
// --- In Phrost_Update() ---

// Example: Player jump
if (isset($world["inputState"][Keycode::UP]) && $playerBody->isOnGround) {
    // Apply an immediate upward impulse for the jump
    $playerBody->applyImpulse($packer, 0.0, -500.0);
    $playerBody->isOnGround = false; // (Custom logic to prevent double-jump)
}
```

* * *

Receiving Feedback (Listening to the Engine)
-----------------------------------------------

To make your sprites _follow_ your physics bodies, you **must** listen for the `PHYSICS_SYNC_TRANSFORM` event in your `Phrost_Update` loop.

```php
<?php
// --- In Phrost_Update() ---
$events = PackFormat::unpack($eventsBlob);

foreach ($events as $event) {
    if ($event["type"] === Events::PHYSICS_SYNC_TRANSFORM->value) {
        /**
        * $event = [
        * 'id1' => 12345, 'id2' => 67890,
        * 'positionX' => 102.5, 'positionY' => 54.2,
        * 'angle' => 0.15, ...
        * ]
        */

        // Find the matching sprite
        $key = Id::toHex([$event["id1"], $event["id2"]]);
        if (isset($world["sprites"][$key])) {
            /** @var Sprite $sprite */
            $sprite = $world["sprites"][$key];

            // Sync the sprite's position to the physics body's actual position
            $sprite->setPosition(
                $event["positionX"],
                $event["positionY"],
                $sprite->getPosition()["z"] // Keep the sprite's Z-depth
            );

            $sprite->setRotate(0, 0, $event["angle"]);
        }
    }

    if ($event["type"] === Events::PHYSICS_COLLISION_BEGIN->value) {
        // Handle collision logic...
    }
}
```
