Phrost Input Handling (JS)
==========================

Input is received in `Phrost_Update` via the `eventsBlob`. You get `INPUT_KEYDOWN` and `INPUT_KEYUP` events.

The event payload contains:

*   `event.keycode`: Layout-aware key (e.g., 'W').
    
*   `event.scancode`: Physical position-aware key (e.g., location of W).
    
*   `event.mod`: Modifier bitmask (Ctrl, Shift, etc).
    

Handling Continuous Input (Input State Buffer)
----------------------------------------------

Relying solely on `KEYDOWN` events is choppy due to key repeat delays. The standard pattern is to maintain an `inputState` object.

### 1. Setup

Initialize an empty object in your world state.
```JavaScript
    const world = {
        // ...
        inputState: {}, // Empty object acting as a map
        // ...
    };
```

### 2. Update the State

In your event loop, set keys to `true` on down and `delete` (or set false) on up.
```JavaScript
    import { Events } from 'phrost/core';
    
    // Inside Phrost_Update loop
    for (const event of events) {
        if (event.type === Events.INPUT_KEYDOWN) {
            // Mark key as held
            world.inputState[event.keycode] = true;
        }
    
        if (event.type === Events.INPUT_KEYUP) {
            // Remove key from state
            delete world.inputState[event.keycode];
        }
    }
```

### 3. Use the State

Check the state object during your logic update (after the event loop).
```JavaScript
    import { Keycode } from 'phrost/core';
    
    // --- Logic Phase ---
    const playerBody = world.physicsBodies[world.playerKey];
    let targetVx = 0.0;
    
    // Check state object
    if (world.inputState[Keycode.LEFT]) {
        targetVx = -200.0;
    }
    if (world.inputState[Keycode.RIGHT]) {
        targetVx = 200.0;
    }
    
    if (playerBody) {
        const currentVy = playerBody.getVelocity().y;
        playerBody.setVelocity(targetVx, currentVy);
    }
```
    

Handling Modifiers
------------------

Use bitwise operators to check `event.mod`.
```JavaScript
    import { Mod, Keycode } from 'phrost/core';
    
    // Inside INPUT_KEYDOWN check
    if (event.keycode === Keycode.R) {
        // Check if CTRL bit is set
        if (event.mod & Mod.CTRL) {
            console.log("Ctrl + R pressed: Resetting...");
            liveReload.reset();
        }
    }
```
