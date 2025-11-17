Phrost Input Handling
------------------------

Input is sent from the engine to PHP as events in the `$eventsBlob`. You receive two main types of key events: `INPUT_KEYDOWN` and `INPUT_KEYUP`. A `KEYDOWN` event may fire multiple times if the key is held down (key repeat), while `KEYUP` fires once when the key is released.

The event payload contains three important pieces of information:

*   `$event["keycode"]`: The layout-aware key (e.g., 'W').

*   `$event["scancode"]`: The physical location-aware key (e.g., the key in the 'W' position).

*   `$event["mod"]`: A bitmask of modifier keys (e.g., Ctrl, Shift).


How you use this information depends on whether you are checking for a single-press action (like "Attack") or a continuous "held" state (like "Move Right").

* * *

Keycode vs. Scancode
--------------------

Understanding the difference between `Keycode` and `Scancode` is essential for good input controls.

### `Keycode` (Layout-Aware)

A **Keycode** represents the _character or symbol_ printed on the keycap, according to the user's current keyboard layout.

*   **File:** `Keycode.php`

*   **Example:** `Keycode::W` (value 119).

*   **When to use it:** Use `Keycode` for any action tied to the _letter_ itself, such as menu shortcuts or in-game actions. The `game-logic.php` file uses this for animation toggles (e.g., "Press 'I' for Idle").

*   **Limitation:** If you map movement to `Keycode::W` for "up," a user with an **AZERTY** layout (where 'W' and 'Z' are swapped) will have to press the 'Z' key to move up, which feels wrong.


### `Scancode` (Position-Aware)

A **Scancode** represents the _physical position_ of the key on the keyboard, regardless of what letter is printed on it.

*   **File:** `Scancode.php`

*   **Example:** `Scancode::W` (value 26).

*   **When to use it:** Use `Scancode` for movement controls, commonly "WASD". By mapping "up" to `Scancode::W`, you are mapping to the _key in that position_.

*   **Benefit:** The AZERTY user's "up" key is 'Z', but it is in the same _physical spot_ as the QWERTY 'W' key. It has the same `Scancode`. This means your controls will work perfectly for both layouts without any changes.


> **Best Practice:** Use **Scancode** for movement controls (WASD) and **Keycode** for everything else (menus, actions, etc.).

* * *

Handling Continuous Input (The `inputState` Buffer)
---------------------------------------------------

Relying on `KEYDOWN` events for movement is unreliable due to key repeat. The best practice, as seen in `game-logic.php`, is to use an **input state buffer**.

This is simply an associative array in your `$world` that keeps a real-time snapshot of which keys are _currently being held down_.

### 1. Setup

In your global state, initialize an empty `inputState` array:

```php
<?php
$world = [
    // ...
    "inputState" => [],
    // ...
];
```

### 2. Update the State

Inside your event loop, you add and remove keys from the state. This automatically handles key repeats.

```php
<?php
// Inside Phrost_Update() event loop
foreach ($events as $event) {
    if ($event["type"] === Events::INPUT_KEYDOWN->value) {
        // A key was pressed. Add it to the state.
        // If it's already true (from key-repeat), this changes nothing.
        $world["inputState"][$event["keycode"]] = true; //
    }

    if ($event["type"] === Events::INPUT_KEYUP->value) {
        // A key was released. Remove it from the state.
        if (isset($world["inputState"][$event["keycode"]])) {
            unset($world["inputState"][$event["keycode"]]); //
        }
    }
}
```
### 3. Use the State

Now, in your main game logic (outside the event loop), you can check this array to see if a key is _currently_ held down.

```php
<?php
// --- In Phrost_Update(), *after* the event loop ---

/** @var ?WarriorBody $playerBody */
$playerBody = $world["physicsBodies"][$world["playerKey"]] ?? null;

$targetVx = 0.0;

// Check the state, not the event
if (isset($world["inputState"][Keycode::LEFT])) { //
    $targetVx = -200.0;
}
if (isset($world["inputState"][Keycode::RIGHT])) { //
    $targetVx = 200.0;
}

// Get the body's current Y velocity so we don't overwrite gravity
$currentVy = $playerBody ? $playerBody->getVelocity()["y"] : 0.0;
$playerBody?->setVelocity($targetVx, $currentVy);
```

This pattern results in smooth, continuous movement as long as the key is held, and it stops instantly when the key is released.

* * *

Handling Modifiers (Ctrl, Shift, Alt)
-------------------------------------

The input event also provides a `$event["mod"]` value. This is a bitmask containing the state of all modifier keys. To check if a modifier was held, use a bitwise AND (`&`) with the constants from `Mod.php`.

The `game-logic.php` file uses this to check for **Ctrl+R** to trigger a reset.

```php
<?php
// Inside the INPUT_KEYDOWN event check:
/** @var LiveReload $live_reload */
$live_reload = $world["liveReload"];

// Check if the keycode is 'R' AND if the 'mod' value
// contains the CTRL bit.
$live_reload->resetOnEvent($event, Keycode::R, Mod::CTRL); //

// The resetOnEvent method implementation:
public function resetOnEvent(array $event, int $keycode, int $mod): void
{
    // if ($event["keycode"] === 114 && $event["mod"] & 192)
    if ($event["keycode"] === $keycode && $event["mod"] & $mod) {
        echo "Hard Reset Triggered! Pending for next frame.\n";
        $this->resetPending = true;
    }
}
```
