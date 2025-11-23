const { Events, Channels } = require("./Events");

/**
 * PhysicsBody Class
 * * Manages a Physics Body entity.
 * Tracks the *desired* state (e.g., "set velocity to X") and sends commands to the physics engine.
 * It does not track the simulated state (which is handled by PHYSICS_SYNC_TRANSFORM events).
 */
class PhysicsBody {
  /**
   * @param {number} id0 - Primary ID
   * @param {number} id1 - Secondary ID
   * @param {boolean} [isNew=true] - Whether this is a new body
   */
  constructor(id0, id1, isNew = true) {
    this.id0 = id0;
    this.id1 = id1;

    // --- Private State Properties ---
    this.position = { x: 0.0, y: 0.0 };
    this.velocity = { x: 0.0, y: 0.0 };
    this.rotation = 0.0; // in radians
    this.angularVelocity = 0.0;
    this.isSleeping = false;

    // --- Configuration (set at creation) ---
    this.bodyType = 0; // 0=dynamic, 1=static, 2=kinematic
    this.shapeType = 0; // 0=box, 1=circle
    this.mass = 1.0;
    this.friction = 0.5;
    this.elasticity = 0.5;
    this.width = 1.0;
    this.height = 1.0;
    this.lockRotation = 0;

    /** @type {Object.<string, boolean>} */
    this.dirtyFlags = {};
    this.isNew = isNew;
  }

  // --- Configuration Setters (for initialization) ---

  /**
   * Set the core physics properties.
   * * @param {number} bodyType
   * @param {number} shapeType
   * @param {number} mass
   * @param {number} friction
   * @param {number} elasticity
   * @param {number} [lockRotation=0]
   */
  setConfig(bodyType, shapeType, mass, friction, elasticity, lockRotation = 0) {
    this.bodyType = bodyType;
    this.shapeType = shapeType;
    this.mass = mass;
    this.friction = friction;
    this.elasticity = elasticity;
    this.lockRotation = lockRotation;
  }

  /**
   * Set the shape dimensions.
   * * @param {number} width - For Box: width. For Circle: radius.
   * @param {number} height - For Box: height. For Circle: ignored.
   */
  setShape(width, height) {
    this.width = width;
    this.height = height;
  }

  // --- State Setters (with Dirty Tracking) ---

  /**
   * Sets the body's position.
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
   * Sets the body's linear velocity.
   * * @param {number} x
   * @param {number} y
   * @param {boolean} [notifyEngine=true]
   */
  setVelocity(x, y, notifyEngine = true) {
    if (this.velocity.x !== x || this.velocity.y !== y) {
      this.velocity.x = x;
      this.velocity.y = y;
      if (notifyEngine) {
        this.dirtyFlags["velocity"] = true;
      }
    }
  }

  /**
   * Sets the body's rotation.
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

  /**
   * Sets the body's angular velocity.
   * * @param {number} radPerSecond
   * @param {boolean} [notifyEngine=true]
   */
  setAngularVelocity(radPerSecond, notifyEngine = true) {
    if (this.angularVelocity !== radPerSecond) {
      this.angularVelocity = radPerSecond;
      if (notifyEngine) {
        this.dirtyFlags["angularVelocity"] = true;
      }
    }
  }

  /**
   * Sets whether the body is sleeping.
   * * @param {boolean} isSleeping
   * @param {boolean} [notifyEngine=true]
   */
  setIsSleeping(isSleeping, notifyEngine = true) {
    if (this.isSleeping !== isSleeping) {
      this.isSleeping = isSleeping;
      if (notifyEngine) {
        this.dirtyFlags["isSleeping"] = true;
      }
    }
  }

  // --- Immediate Event Methods (No Dirty Flags) ---

  /**
   * Applies a force to the body.
   * * @param {Object} packer - ChannelPacker
   * @param {number} forceX
   * @param {number} forceY
   */
  applyForce(packer, forceX, forceY) {
    packer.add(Channels.PHYSICS, Events.PHYSICS_APPLY_FORCE, [
      this.id0,
      this.id1,
      forceX,
      forceY,
    ]);
  }

  /**
   * Applies an impulse to the body.
   * * @param {Object} packer - ChannelPacker
   * @param {number} impulseX
   * @param {number} impulseY
   */
  applyImpulse(packer, impulseX, impulseY) {
    packer.add(Channels.PHYSICS, Events.PHYSICS_APPLY_IMPULSE, [
      this.id0,
      this.id1,
      impulseX,
      impulseY,
    ]);
  }

  /**
   * Removes the body from the engine.
   * * @param {Object} packer
   */
  remove(packer) {
    packer.add(Channels.PHYSICS, Events.PHYSICS_REMOVE_BODY, [
      this.id0,
      this.id1,
    ]);
  }

  /**
   * Helper to construct initial ADD data array.
   * * @private
   * @returns {Array<number>}
   */
  getInitialAddData() {
    return [
      this.id0,
      this.id1,
      this.position.x,
      this.position.y,
      this.bodyType,
      this.shapeType,
      this.lockRotation,
      // 5 bytes padding are handled by packer based on struct def
      // But wait, PHP provided raw values.
      // Our packer.add() expects pure values matching the format string.
      // PACK_PHYSICS_ADD_BODY = ".../ClockRotation/x5_padding/emass..."
      // The 'x5' in the format string handles the padding automatically.
      // We do NOT pass padding values in the data array for 'x' codes.
      this.mass,
      this.friction,
      this.elasticity,
      this.width,
      this.height,
    ];
  }

  /**
   * Returns the current velocity.
   * @returns {{x: number, y: number}}
   */
  getVelocity() {
    return this.velocity;
  }

  getAngularVelocity() {
    return this.angularVelocity;
  }

  getIsSleeping() {
    return this.isSleeping;
  }

  /**
   * Packs dirty events.
   * * @param {Object} packer
   */
  packDirtyEvents(packer) {
    if (this.isNew) {
      // Send the full ADD_BODY event
      packer.add(
        Channels.PHYSICS,
        Events.PHYSICS_ADD_BODY,
        this.getInitialAddData(),
      );

      // If velocity was set before creation, send it immediately after.
      if (this.velocity.x !== 0.0 || this.velocity.y !== 0.0) {
        packer.add(Channels.PHYSICS, Events.PHYSICS_SET_VELOCITY, [
          this.id0,
          this.id1,
          this.velocity.x,
          this.velocity.y,
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
      packer.add(Channels.PHYSICS, Events.PHYSICS_SET_POSITION, [
        this.id0,
        this.id1,
        this.position.x,
        this.position.y,
      ]);
    }

    if (this.dirtyFlags["velocity"]) {
      packer.add(Channels.PHYSICS, Events.PHYSICS_SET_VELOCITY, [
        this.id0,
        this.id1,
        this.velocity.x,
        this.velocity.y,
      ]);
    }

    if (this.dirtyFlags["rotation"]) {
      packer.add(Channels.PHYSICS, Events.PHYSICS_SET_ROTATION, [
        this.id0,
        this.id1,
        this.rotation,
      ]);
    }

    this.clearDirtyFlags();
  }

  clearDirtyFlags() {
    this.dirtyFlags = {};
  }
}

module.exports = PhysicsBody;
