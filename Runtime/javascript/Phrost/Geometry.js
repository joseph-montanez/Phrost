const { Events, Channels } = require("./Events");
const GeomType = require("./GeomType");

/**
 * Manages a Geometry primitive.
 * * Based on the engine events, geometry is "write-once".
 * You can add it, remove it, and change its color, but not
 * its position or shape.
 */
class Geometry {
  /**
   * @param {number} id0 - Primary Identifier
   * @param {number} id1 - Secondary Identifier
   * @param {boolean} [isNew=true] - Whether this is a new geometry
   */
  constructor(id0, id1, isNew = true) {
    this.id0 = id0;
    this.id1 = id1;

    // --- Private State Properties ---
    /** @type {{r: number, g: number, b: number, a: number}} */
    this.color = { r: 255, g: 255, b: 255, a: 255 };
    /** @type {number} */
    this.z = 0.0;
    /** @type {boolean} */
    this.isScreenSpace = false;

    // --- Configuration (set at creation) ---
    /** @type {?number} */
    this.type = null;
    /** @type {Array<number>} */
    this.shapeData = []; // [x1, y1] etc.

    /** @type {Object.<string, boolean>} */
    this.dirtyFlags = {};
    this.isNew = isNew;
  }

  // --- Configuration Setters (for initialization) ---

  /**
   * Sets the Z-depth of the geometry.
   * * @param {number} z
   */
  setZ(z) {
    this.z = z;
  }

  /**
   * Sets this geometry to be "screen space" (unaffected by camera).
   * This must be called BEFORE the first packDirtyEvents().
   * * @param {boolean} flag
   */
  setIsScreenSpace(flag) {
    this.isScreenSpace = flag;
  }

  /**
   * Sets the geometry as a Point.
   * * @param {number} x
   * @param {number} y
   */
  setPoint(x, y) {
    this.type = GeomType.POINT;
    this.shapeData = [x, y];
  }

  /**
   * Sets the geometry as a Line.
   * * @param {number} x1
   * @param {number} y1
   * @param {number} x2
   * @param {number} y2
   */
  setLine(x1, y1, x2, y2) {
    this.type = GeomType.LINE;
    this.shapeData = [x1, y1, x2, y2];
  }

  /**
   * Sets the geometry as a Rectangle.
   * * @param {number} x
   * @param {number} y
   * @param {number} w
   * @param {number} h
   * @param {boolean} [filled=false]
   */
  setRect(x, y, w, h, filled = false) {
    this.type = filled ? GeomType.FILL_RECT : GeomType.RECT;
    this.shapeData = [x, y, w, h];
  }

  // --- State Setter (with Dirty Tracking) ---

  /**
   * Sets the color of the geometry.
   * * @param {number} r - Red (0-255)
   * @param {number} g - Green (0-255)
   * @param {number} b - Blue (0-255)
   * @param {number} a - Alpha (0-255)
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
   * Queues a remove command for this geometry.
   * * @param {Object} packer - The ChannelPacker instance.
   */
  remove(packer) {
    packer.add(Channels.RENDERER, Events.GEOM_REMOVE, [this.id0, this.id1]);
  }

  // --- Event Generation ---

  /**
   * Helper to construct the initial ADD data array.
   * * @private
   * @returns {Array<number>}
   */
  getInitialAddData() {
    // Data must match GEOM_ADD_* format:
    // id1, id2, z, r, g, b, a, isScreenSpace, ...shape
    return [
      this.id0,
      this.id1,
      this.z,
      this.color.r,
      this.color.g,
      this.color.b,
      this.color.a,
      this.isScreenSpace ? 1 : 0,
      ...this.shapeData,
    ];
  }

  /**
   * Checks all dirty flags and adds the corresponding events to the packer.
   * * @param {Object} packer - The ChannelPacker instance.
   */
  packDirtyEvents(packer) {
    if (this.isNew) {
      if (this.type === null) {
        console.error(
          "Geometry: Cannot pack ADD event, no shape was set (use setPoint, setLine, or setRect).",
        );
        return;
      }

      // In JS, we use the int value directly from GeomType which matches Events values
      // If GeomType values match Events values exactly, we use type directly.
      const eventEnum = this.type;

      packer.add(Channels.RENDERER, eventEnum, this.getInitialAddData());

      this.isNew = false;
      this.clearDirtyFlags();
      return;
    }

    if (Object.keys(this.dirtyFlags).length === 0) {
      return;
    }

    if (this.dirtyFlags["color"]) {
      packer.add(Channels.RENDERER, Events.GEOM_SET_COLOR, [
        this.id0,
        this.id1,
        this.color.r,
        this.color.g,
        this.color.b,
        this.color.a,
      ]);
    }

    this.clearDirtyFlags();
  }

  /**
   * Clears all dirty flags.
   */
  clearDirtyFlags() {
    this.dirtyFlags = {};
  }
}

module.exports = Geometry;
