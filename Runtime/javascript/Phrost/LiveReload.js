const fs = require("fs");
const path = require("path");
const { Events, Channels } = require("./Events");
const Mod = require("./Mod");

/**
 * LiveReload Class
 * * Handles hot-reloading and state management.
 */
class LiveReload {
  /**
   * @param {string} shutdownFlagPath
   * @param {string} savePath
   */
  constructor(shutdownFlagPath, savePath) {
    this.shutdownFlagPath = shutdownFlagPath;
    this.savePath = savePath;
    this.resetPending = false;
  }

  /**
   * Re-injects paths after unserialization (if applicable in JS).
   * * @param {string} shutdownFlagPath
   * @param {string} savePath
   */
  setPaths(shutdownFlagPath, savePath) {
    this.shutdownFlagPath = shutdownFlagPath;
    this.savePath = savePath;
  }

  isResetPending() {
    return this.resetPending;
  }

  /**
   * Polls for live reload signals.
   * Should be called once per frame.
   * * @param {boolean} [isLoaded=false]
   */
  poll(isLoaded = false) {
    // Note: Synchronous file ops are used here to match PHP behavior
    // and simplicity in the game loop structure.

    if (!isLoaded && fs.existsSync(this.savePath)) {
      // In JS, we assume Phrost_Wake and Phrost_Sleep are global or imported functions
      // handling the state restoration.
      try {
        const saveContent = fs.readFileSync(this.savePath, "utf8");
        if (saveContent && saveContent.trim().length > 0) {
          if (typeof global.Phrost_Wake === "function") {
            global.Phrost_Wake(saveContent);
          }
        } else {
          console.log(
            "Save.data file was empty or unreadable. Starting fresh.",
          );
          fs.unlinkSync(this.savePath);
        }
      } catch (e) {
        console.error("Error reading save file:", e);
      }
    }

    if (fs.existsSync(this.shutdownFlagPath)) {
      try {
        const flagContent = fs
          .readFileSync(this.shutdownFlagPath, "utf8")
          .trim();

        // Delete flag immediately
        fs.unlinkSync(this.shutdownFlagPath);

        if (flagContent === "reset") {
          console.log("Hard reset detected. Skipping save and unloading.");
          // Unloading signal
          console.log("unloading");
          process.exit(0); // Exit code 10 for reload/shutdown
        } else {
          console.log("Saving state before unloading...");
          if (typeof global.Phrost_Sleep === "function") {
            const state = global.Phrost_Sleep();
            fs.writeFileSync(this.savePath, state);
          }

          console.log("unloading");
          process.exit(0);
        }
      } catch (e) {
        console.error("Error processing shutdown flag:", e);
      }
    }
  }

  /**
   * Triggers reset on event match.
   * * @param {Object} event
   * @param {number} keycode
   * @param {number} mod
   */
  resetOnEvent(event, keycode, mod) {
    if (event.keycode === keycode && event.mod & mod) {
      console.log("Hard Reset Triggered! Pending for next frame.");
      this.resetPending = true;
    }
  }

  /**
   * Performs a hard reset of the application state.
   * * @param {Object} world - World object containing sprites and bodies.
   * @param {Object} packer - ChannelPacker
   */
  reset(world, packer) {
    // Unload sprites
    if (world.sprites) {
      for (const spriteId in world.sprites) {
        const sprite = world.sprites[spriteId];
        // Check if sprite has remove method or construct event manually
        if (typeof sprite.remove === "function") {
          // Assuming sprite has remove method, otherwise:
          packer.add(Channels.RENDERER, Events.SPRITE_REMOVE, [
            sprite.id0,
            sprite.id1,
          ]);
        } else {
          packer.add(Channels.RENDERER, Events.SPRITE_REMOVE, [
            sprite.id0,
            sprite.id1,
          ]);
        }
      }
    }

    // Unload physics bodies
    if (world.physicsBodies) {
      for (const bodyId in world.physicsBodies) {
        const body = world.physicsBodies[bodyId];
        packer.add(Channels.PHYSICS, Events.PHYSICS_REMOVE_BODY, [
          body.id0,
          body.id1,
        ]);
      }
    }

    if (fs.existsSync(this.savePath)) {
      fs.unlinkSync(this.savePath);
    }

    fs.writeFileSync(this.shutdownFlagPath, "reset");
    this.resetPending = false;
  }

  /**
   * Triggers shutdown on event match.
   * * @param {Object} event
   * @param {number} keycode
   * @param {number} mod
   */
  shutdownOnEvent(event, keycode, mod) {
    let modMatch = false;
    modMatch = mod === Mod.NONE ? true : event.mod & mod;

    if (event.keycode === keycode && modMatch) {
      console.log("Shutting down");
      this.shutdown();
    }
  }

  /**
   * Triggers immediate hard shutdown.
   */
  shutdown() {
    process.exit(10);
  }
}

module.exports = LiveReload;
