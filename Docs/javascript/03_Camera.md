Phrost Camera Documentation (JS)
================================

The `Camera` class manages the viewport, including pan, zoom, and rotation.

Core Concept: Dirty Flags
-------------------------

Similar to `Window`, the `Camera` tracks state changes.

1.  Call `camera.setZoom(2.0)`.
    
2.  Dirty flag is set.
    
3.  Call `camera.packDirtyEvents(packer)`.
    
4.  `CAMERA_SET_ZOOM` event is generated.
    

How to Use
----------

Here is the complete step-by-step process for managing the camera.

### Step 1: Initialization

You typically create your `Camera` object once when your script initializes and store it in the global `$world` array.

```JavaScript
    import { Camera } from 'phrost/camera';
    import { ChannelPacker } from 'phrost/core';
    
    // 1. Create camera (x, y, zoom)
    const camera = new Camera(0.0, 0.0, 1.0);
    
    world.camera = camera;
    
    // 2. Pack initial state
    const packer = new ChannelPacker();
    camera.packDirtyEvents(packer);
    
    Phrost_Run(packer.finalize());
```

### Step 2: Updating State

In your `Phrost_Update` loop, you can call setter methods to change the camera's properties. These methods all set dirty flags.


```JavaScript
    // --- Inside Phrost_Update() ---
    
    const camera = world.camera;
    const dtSeconds = dt / 1000.0;
    
    // Example: Follow player
    if (world.playerSprite) {
        const playerPos = world.playerSprite.getPosition();
        camera.setPosition(playerPos.x, playerPos.y);
    }
    
    // Example: Pan with keys
    const panSpeed = 200.0 * dtSeconds;
    if (world.inputState[Keycode.LEFT]) {
        camera.move(-panSpeed, 0);
    }
    if (world.inputState[Keycode.RIGHT]) {
        camera.move(panSpeed, 0);
    }
    
    // Example: Zoom
    if (world.inputState[Keycode.Q]) {
        const newZoom = Math.max(0.1, camera.getZoom() - (1.0 * dtSeconds));
        camera.setZoom(newZoom);
    }
```

### Step 3: Pack Events

At the end of every `Phrost_Update` frame, you must call `packDirtyEvents()`. This will check all the dirty flags set in Step 2 and send the corresponding events to the renderer.

```JavaScript
    // --- End of Phrost_Update() ---
    
    world.camera.packDirtyEvents(packer);
    return packer.finalize();
```
