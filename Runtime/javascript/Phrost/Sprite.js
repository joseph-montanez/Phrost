const { Events, Channels } = require("./Events");

/**
 * Sprite Class
 * * Base entity for visual objects.
 * Manages properties like position, scale, rotation, color, and texture.
 */
class Sprite {
  /**
   * @param {number} id0 - Primary ID
   * @param {number} id1 - Secondary ID
   * @param {boolean} [isNew=true] - Whether this is a new sprite
   */
  constructor(id0, id1, isNew = true) {
    this.id0 = id0;
    this.id1 = id1;

    this.position = { x: 0.0, y: 0.0, z: 0.0 };
    this.size = { width: 1.0, height: 1.0 };
    this.color = { r: 255, g: 255, b: 255, a: 255 };
    /** @type {?string} */
    this.texturePath = null;
    this.rotate = { x: 0.0, y: 0.0, z: 0.0 };
    this.speed = { x: 0.0, y: 0.0 };
    this.scale = { x: 1.0, y: 1.0, z: 1.0 };
    this.textureId = 0;

    /** @type {?{x: number, y: number, w: number, h: number}} */
    this.sourceRect = null;

    /** @type {Object.<string, boolean>} */
    this.dirtyFlags = {};

    /** @type {boolean} */
    this.isNew = isNew;
  }

  /**
   * Updates the sprite logic (basic physics movement).
   * * @param {number} dt
   */
  update(dt) {
    if (this.speed.x === 0.0 && this.speed.y === 0.0) {
      return;
    }
    this.setPosition(
      this.position.x + this.speed.x * dt,
      this.position.y + this.speed.y * dt,
      this.position.z,
    );
  }

  /**
   * Sets position.
   * * @param {number} x
   * @param {number} y
   * @param {number} z
   * @param {boolean} [notifyEngine=true]
   */
  setPosition(x, y, z, notifyEngine = true) {
    if (
      this.position.x !== x ||
      this.position.y !== y ||
      this.position.z !== z
    ) {
      this.position.x = x;
      this.position.y = y;
      this.position.z = z;
      if (notifyEngine) {
        this.dirtyFlags["position"] = true;
      }
    }
  }

  /**
   * Sets size dimensions.
   * * @param {number} width
   * @param {number} height
   * @param {boolean} [notifyEngine=true]
   */
  setSize(width, height, notifyEngine = true) {
    if (this.size.width !== width || this.size.height !== height) {
      this.size.width = width;
      this.size.height = height;
      if (notifyEngine) {
        this.dirtyFlags["size"] = true;
      }
    }
  }

  /**
   * Sets color.
   * * @param {number} r
   * @param {number} g
   * @param {number} b
   * @param {number} a
   * @param {boolean} [notifyEngine=true]
   */
  setColor(r, g, b, a, notifyEngine = true) {
    if (
      this.color.r !== r ||
      this.color.g !== g ||
      this.color.b !== b ||
      this.color.a !== a
    ) {
      this.color.r = r;
      this.color.g = g;
      this.color.b = b;
      this.color.a = a;
      if (notifyEngine) {
        this.dirtyFlags["color"] = true;
      }
    }
  }

  /**
   * Sets texture path.
   * * @param {string} path
   * @param {boolean} [notifyEngine=true]
   */
  setTexturePath(path, notifyEngine = true) {
    if (this.texturePath !== path) {
      this.texturePath = path;
      if (notifyEngine) {
        this.dirtyFlags["texture"] = true;
      }
    }
  }

  /**
   * Sets rotation (radians).
   * * @param {number} x
   * @param {number} y
   * @param {number} z
   * @param {boolean} [notifyEngine=true]
   */
  setRotate(x, y, z, notifyEngine = true) {
    if (this.rotate.x !== x || this.rotate.y !== y || this.rotate.z !== z) {
      this.rotate.x = x;
      this.rotate.y = y;
      this.rotate.z = z;
      if (notifyEngine) {
        this.dirtyFlags["rotate"] = true;
      }
    }
  }

  /**
   * Sets velocity speed.
   * * @param {number} x
   * @param {number} y
   * @param {boolean} [notifyEngine=true]
   */
  setSpeed(x, y, notifyEngine = true) {
    if (this.speed.x !== x || this.speed.y !== y) {
      this.speed.x = x;
      this.speed.y = y;
      if (notifyEngine) {
        this.dirtyFlags["speed"] = true;
      }
    }
  }

  /**
   * Sets scale.
   * * @param {number} x
   * @param {number} y
   * @param {number} z
   * @param {boolean} [notifyEngine=true]
   */
  setScale(x, y, z, notifyEngine = true) {
    if (this.scale.x !== x || this.scale.y !== y || this.scale.z !== z) {
      this.scale.x = x;
      this.scale.y = y;
      this.scale.z = z;
      if (notifyEngine) {
        this.dirtyFlags["scale"] = true;
      }
    }
  }

  /**
   * Sets the horizontal flip state by modifying X scale.
   * * @param {boolean} isFlipped
   * @param {boolean} [notifyEngine=true]
   */
  setFlip(isFlipped, notifyEngine = true) {
    const currentAbsScaleX = Math.abs(this.scale.x);
    const newScaleX = isFlipped ? -currentAbsScaleX : currentAbsScaleX;

    this.setScale(newScaleX, this.scale.y, this.scale.z, notifyEngine);
  }

  /**
   * Sets the source rectangle for texture mapping.
   * * @param {number} x
   * @param {number} y
   * @param {number} w
   * @param {number} h
   * @param {boolean} [notifyEngine=true]
   */
  setSourceRect(x, y, w, h, notifyEngine = true) {
    // Simple value check logic
    if (
      !this.sourceRect ||
      this.sourceRect.x !== x ||
      this.sourceRect.y !== y ||
      this.sourceRect.w !== w ||
      this.sourceRect.h !== h
    ) {
      this.sourceRect = { x, y, w, h };
      if (notifyEngine) {
        this.dirtyFlags["source_rect"] = true;
      }
    }
  }

  setTextureId(textureId) {
    this.textureId = textureId;
  }

  // --- Getters ---
  getPosition() {
    return this.position;
  }
  getSpeed() {
    return this.speed;
  }
  getScale() {
    return this.scale;
  }
  getRotation() {
    return this.rotate;
  }
  getColor() {
    return this.color;
  }
  getId() {
    return [this.id0, this.id1];
  }
  getTextureId() {
    return this.textureId;
  }
  getSourceRect() {
    return this.sourceRect;
  }

  /**
   * Generates data array for initial SPRITE_ADD.
   * * @returns {Array<number>}
   */
  getInitialAddData() {
    return [
      this.id0,
      this.id1,
      this.position.x,
      this.position.y,
      this.position.z,
      this.scale.x,
      this.scale.y,
      this.scale.z,
      this.size.width,
      this.size.height,
      this.rotate.x,
      this.rotate.y,
      this.rotate.z,
      this.color.r,
      this.color.g,
      this.color.b,
      this.color.a,
      this.speed.x,
      this.speed.y,
    ];
  }

  /**
   * Packs dirty events.
   * * @param {Object} packer
   * @param {boolean} [clear=true]
   */
  packDirtyEvents(packer, clear = true) {
    if (this.isNew) {
      // Send full SPRITE_ADD
      packer.add(
        Channels.RENDERER,
        Events.SPRITE_ADD,
        this.getInitialAddData(),
      );

      // Send texture load if set
      if (this.texturePath) {
        const filename = this.texturePath;
        const filenameLength = Buffer.byteLength(filename, "utf8");
        packer.add(Channels.RENDERER, Events.SPRITE_TEXTURE_LOAD, [
          this.id0,
          this.id1,
          filenameLength,
          filename,
        ]);
      }

      // Send source rect if set
      if (this.sourceRect) {
        packer.add(Channels.RENDERER, Events.SPRITE_SET_SOURCE_RECT, [
          this.id0,
          this.id1,
          this.sourceRect.x,
          this.sourceRect.y,
          this.sourceRect.w,
          this.sourceRect.h,
        ]);
      }

      this.isNew = false;
      this.clearDirtyFlags();
      return;
    }

    if (Object.keys(this.dirtyFlags).length === 0) {
      return;
    }

    if (this.dirtyFlags["position"]) {
      packer.add(Channels.RENDERER, Events.SPRITE_MOVE, [
        this.id0,
        this.id1,
        this.position.x,
        this.position.y,
        this.position.z,
      ]);
    }

    if (this.dirtyFlags["scale"]) {
      packer.add(Channels.RENDERER, Events.SPRITE_SCALE, [
        this.id0,
        this.id1,
        this.scale.x,
        this.scale.y,
        this.scale.z,
      ]);
    }

    if (this.dirtyFlags["size"]) {
      packer.add(Channels.RENDERER, Events.SPRITE_RESIZE, [
        this.id0,
        this.id1,
        this.size.width,
        this.size.height,
      ]);
    }

    if (this.dirtyFlags["rotate"]) {
      packer.add(Channels.RENDERER, Events.SPRITE_ROTATE, [
        this.id0,
        this.id1,
        this.rotate.x,
        this.rotate.y,
        this.rotate.z,
      ]);
    }

    if (this.dirtyFlags["color"]) {
      packer.add(Channels.RENDERER, Events.SPRITE_COLOR, [
        this.id0,
        this.id1,
        this.color.r,
        this.color.g,
        this.color.b,
        this.color.a,
      ]);
    }

    if (this.dirtyFlags["speed"]) {
      packer.add(Channels.RENDERER, Events.SPRITE_SPEED, [
        this.id0,
        this.id1,
        this.speed.x,
        this.speed.y,
      ]);
    }

    if (this.dirtyFlags["texture"]) {
      const filename = this.texturePath || "";
      const filenameLength = Buffer.byteLength(filename, "utf8");
      packer.add(Channels.RENDERER, Events.SPRITE_TEXTURE_LOAD, [
        this.id0,
        this.id1,
        filenameLength,
        filename,
      ]);
    }

    if (this.dirtyFlags["source_rect"] && this.sourceRect) {
      packer.add(Channels.RENDERER, Events.SPRITE_SET_SOURCE_RECT, [
        this.id0,
        this.id1,
        this.sourceRect.x,
        this.sourceRect.y,
        this.sourceRect.w,
        this.sourceRect.h,
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

module.exports = Sprite;
