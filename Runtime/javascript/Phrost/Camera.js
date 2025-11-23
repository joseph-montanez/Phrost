const { Events, Channels } = require("./Events");

/**
 * Camera Class
 * * Manages the viewport camera state and synchronizes it with the engine.
 */
class Camera {
  /**
   * @param {number} [initialX=0.0]
   * @param {number} [initialY=0.0]
   * @param {number} [initialZoom=1.0]
   */
  constructor(initialX = 0.0, initialY = 0.0, initialZoom = 1.0) {
    this.position = { x: initialX, y: initialY };
    this.zoom = initialZoom;
    this.rotation = 0.0; // in radians

    /** @type {Object.<string, boolean>} */
    this.dirtyFlags = {};

    /** @type {boolean} */
    this.isNew = true;
  }

  /**
   * Sets the camera's absolute top-left position in the world.
   * * @param {number} x
   * @param {number} y
   * @param {boolean} [notifyEngine=true]
   */
  setPosition(x, y, notifyEngine = true) {
    if (this.position.x !== x || this.position.y !== y) {
      this.position.x = x;
      this.position.y = y;
      if (notifyEngine) {
        this.dirtyFlags["position"] = true;
      }
    }
  }

  /**
   * Moves the camera by a relative amount.
   * * @param {number} dx
   * @param {number} dy
   * @param {boolean} [notifyEngine=true]
   */
  move(dx, dy, notifyEngine = true) {
    if (dx !== 0.0 || dy !== 0.0) {
      this.position.x += dx;
      this.position.y += dy;
      if (notifyEngine) {
        this.dirtyFlags["position"] = true;
      }
    }
  }

  /**
   * Sets the camera's zoom level.
   * 1.0 = no zoom, 2.0 = zoomed in (2x).
   * * @param {number} zoom
   * @param {boolean} [notifyEngine=true]
   */
  setZoom(zoom, notifyEngine = true) {
    if (this.zoom !== zoom) {
      this.zoom = zoom;
      if (notifyEngine) {
        this.dirtyFlags["zoom"] = true;
      }
    }
  }

  /**
   * Sets the camera's rotation.
   * * @param {number} angleInRadians
   * @param {boolean} [notifyEngine=true]
   */
  setRotation(angleInRadians, notifyEngine = true) {
    if (this.rotation !== angleInRadians) {
      this.rotation = angleInRadians;
      if (notifyEngine) {
        this.dirtyFlags["rotation"] = true;
      }
    }
  }

  // --- Getters ---

  getPosition() {
    return this.position;
  }

  getZoom() {
    return this.zoom;
  }

  getRotation() {
    return this.rotation;
  }

  /**
   * Checks all dirty flags and adds the corresponding events
   * to the ChannelPacker.
   * * @param {Object} packer - The ChannelPacker instance.
   * @param {boolean} [clear=true] - Whether to clear dirty flags after packing.
   */
  packDirtyEvents(packer, clear = true) {
    if (this.isNew) {
      // On first run, send all state to the engine
      packer.add(Channels.RENDERER, Events.CAMERA_SET_POSITION, [
        this.position.x,
        this.position.y,
      ]);
      packer.add(Channels.RENDERER, Events.CAMERA_SET_ZOOM, [this.zoom]);
      packer.add(Channels.RENDERER, Events.CAMERA_SET_ROTATION, [
        this.rotation,
      ]);

      this.isNew = false;
      this.clearDirtyFlags();
      return; // Exit
    }

    // --- REGULAR DIRTY CHECK ---
    if (Object.keys(this.dirtyFlags).length === 0) {
      return; // Nothing to do
    }

    if (this.dirtyFlags["position"]) {
      packer.add(Channels.RENDERER, Events.CAMERA_SET_POSITION, [
        this.position.x,
        this.position.y,
      ]);
    }

    if (this.dirtyFlags["zoom"]) {
      packer.add(Channels.RENDERER, Events.CAMERA_SET_ZOOM, [this.zoom]);
    }

    if (this.dirtyFlags["rotation"]) {
      packer.add(Channels.RENDERER, Events.CAMERA_SET_ROTATION, [
        this.rotation,
      ]);
    }

    if (clear) {
      this.clearDirtyFlags();
    }
  }

  clearDirtyFlags() {
    this.dirtyFlags = {};
  }
}

module.exports = Camera;
