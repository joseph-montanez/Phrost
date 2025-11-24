Phrost Window Documentation (JS)
================================

The `Window` class is a high-level state object for managing the game window properties like title, size, and fullscreen state.

Core Concept: The "Dirty Flag" System
-------------------------------------

Like other Phrost classes, the JS `Window` object tracks its _desired_ state locally.

1.  **You change a property:** `window.setTitle("New Title")`.
    
2.  **A flag is set:** The object marks itself internally (e.g., `this.dirtyFlags.title = true`).
    
3.  **You pack events:** Call `window.packDirtyEvents(packer)` at the end of the frame.
    
4.  **Events are sent:** If flags are true, events are added to the packer.
    

When created, `isNew` is true, ensuring all state is sent on the first frame.

How to Use
----------

### Step 1: Initialization

Create the object in your global `world` state (or equivalent module scope).

```JavaScript
    import { Window } from 'phrost/window';
    import { ChannelPacker } from 'phrost/core';
    
    // 1. Create the window object
    const window = new Window("My Phrost Game", 1280, 720);
    
    // 2. Set initial flags
    window.setResizable(true, false); 
    
    // Store in world state
    world.window = window;
    
    // 3. Pack initial events immediately
    const packer = new ChannelPacker();
    window.packDirtyEvents(packer);
    
    // Run the engine
    Phrost_Run(packer.finalize());
```

### Step 2: Updating State

Use setters in your update loop.

```JavaScript
    // --- Inside Phrost_Update() ---
    
    const window = world.window;
    
    // Update title
    window.setTitle(`My Game | FPS: ${world.smoothed_fps}`);
    
    // Toggle borderless on key press
    if (event.type === Events.INPUT_KEYDOWN && event.keycode === Keycode.B) {
        const isBorderless = window.isFlagEnabled("borderless");
        window.setBorderless(!isBorderless);
    }
    
    // Pack events at the end
    window.packDirtyEvents(packer);
```

Reacting to Engine Events (Important)
-------------------------------------

If the user resizes the window manually, the engine sends a `WINDOW_RESIZE` event. You must update your JS object to match, but you **must not** send that command back to the engine (infinite loop risk).

Pass `false` as the last argument (`notifyEngine`) to update state silently.

```JavaScript
    // --- Inside Phrost_Update() ---
    
    const events = PackFormat.unpack(eventsBlob);
    const window = world.window;
    
    for (const event of events) {
        if (event.type === Events.WINDOW_RESIZE) {
            // Update JS state, but DO NOT send command back
            window.setSize(event.w, event.h, false); 
            
            // React to size change (e.g., update camera)
            world.camera.setSize(event.w, event.h);
        }
    }
```
