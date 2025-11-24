Getting Started (JavaScript)
----------------------------

### Download A Release

Phrost has pre-built releases for Windows available on [GitHub](https://github.com/joseph-montanez/Phrost/releases "null").

### Run `Phrost`

There will be several files in the release folder. The `Phrost` file is the executable that you will run to start the game.

### Folder Structure

    Release/
    └── Phrost (Runs the game and JS runtime)
    ├── game/
    │   ├── assets/
    │   ├── main.js       <-- Entry Point
    │   ├── game-logic.js <-- Game Loop
    │   └── src/
    │       └── Warrior.js
    

### JS Source Location

Edit your JavaScript source files in the `game` directory.

### What Files To Edit?

`game/game-logic.js` will be your main file to work with, however `assets/main.js` will be your main entry point.

### Required Functions

Phrost expects three global functions to be declared in your JavaScript environment:

*   `function Phrost_Update(elapsed, dt, eventsBlob)`: string
    
*   `function Phrost_Sleep()`: string
    
*   `function Phrost_Wake(data)`: void
    

`game/game-logic.js` usually has these functions defined, you can start editing them to implement your game logic.

### The ID System (UUIDs)

Most entities (like sprites and physics bodies) and their events require two 64-bit integer IDs (`id1`, `id2`).

*   **Engine Performance:** Uses 128-bit UUIDs (split into two 64-bit integers).
    
*   **JavaScript Handling:** JavaScript numbers are double-precision floats. They cannot safely store 64-bit integers without losing precision. Phrost uses the `Id` helper class to manage these safely.
    

#### The Standard Workflow

1.  **Generate an ID:** The `Id.generate()` method returns an array containing the two ID parts.
```JavaScript
        import { Id } from 'phrost/id';
        
        // Returns an array [id1, id2]
        const id = Id.generate(); 
```
    
2.  **Create Entities:** Pass these two ID parts to your object constructors.
```JavaScript
        import { Warrior } from './src/Warrior.js';
        
        // Pass the two ID parts to the constructor
        const warrior = new Warrior(id[0], id[1]);
```
    
3.  **Create a Key (String):** To store objects in a JavaScript object (map), convert the ID array to a hex string.
```JavaScript
        // Converts the ID array to a hex string for use as an object key
        const key = Id.toHex(id);
```  
    
4.  **Store in World:**
```JavaScript
        world.sprites[key] = warrior;
        world.playerKey = key;
```
    
5.  **Handling IDs from Events (CRITICAL):** When reading IDs from engine events (like `PHYSICS_SYNC_TRANSFORM` or `COLLISION`), the raw values in the event object might be interpreted as signed integers or floats. **You must wrap them using `Id.asUnsigned()`** to ensure they are treated correctly before using them to reconstruct a key.
```JavaScript
        if (event.type === Events.PHYSICS_SYNC_TRANSFORM) {
            // CONVERT RAW EVENT DATA TO UNSIGNED IDS
            const id1 = Id.asUnsigned(event.id1);
            const id2 = Id.asUnsigned(event.id2);
        
            // Reconstruct the key to find your object
            const key = Id.toHex([id1, id2]);
        
            if (world.sprites[key]) {
                world.sprites[key].updateTransform(event);
            }
        }
```
    

### Channels

Channels route messages between the script, renderer, and physics engine.

By default, your JS script listens to:

*   `0: RENDERER`
    
*   `2: PHYSICS`
    
*   `6: SCRIPT`
    
```JavaScript
    export const Channels = {
        RENDERER: 0,
        INPUT: 1,
        PHYSICS: 2,
        AUDIO: 3,
        GUI: 4,
        WINDOW: 5,
        SCRIPT: 6
    };
```

You can subscribe/unsubscribe to custom channels:

```JavaScript
    // Subscribe to Channel 22
    packer.add(Channels.RENDERER, Events.SCRIPT_SUBSCRIBE, [22]);
    
    // Unsubscribe from Channel 22
    packer.add(Channels.RENDERER, Events.SCRIPT_UNSUBSCRIBE, [22]);
```

### Events & Phrost\_Update

The logic is event-driven. `Phrost_Update` runs every frame.

#### Receiving Events

`Phrost_Update` receives a binary `eventsBlob`. You must unpack it using `PackFormat.unpack()`.

```JavaScript
    import { PackFormat, Events, Keycode, ChannelPacker } from 'phrost/core';
    
    function Phrost_Update(elapsed, dt, eventsBlob) {
        // 1. Unpack the blob
        const events = PackFormat.unpack(eventsBlob);
    
        for (const event of events) {
            if (!event.type) continue;
    
            // Example: Input
            if (event.type === Events.INPUT_KEYDOWN) {
                if (event.keycode === Keycode.R) {
                    console.log("R pressed");
                }
            }
            
            // Example: Window Resize
            if (event.type === Events.WINDOW_RESIZE) {
                // Note: pass false to avoid infinite loops (see Window docs)
                world.window.setSize(event.w, event.h, false);
            }
        }
        
        // ... Update Game Logic ...
        
        // 2. Pack and Return
        const packer = new ChannelPacker();
        
        // Let high-level objects pack themselves
        world.window.packDirtyEvents(packer);
        
        // Manual packing example
        if (shouldPlaySound) {
            packer.add(Channels.AUDIO, Events.AUDIO_PLAY, ["bgm_01"]);
        }
        
        return packer.finalize();
    }
```
