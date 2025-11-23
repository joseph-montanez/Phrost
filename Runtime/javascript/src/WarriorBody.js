const PhysicsBody = require("../Phrost/PhysicsBody");
const Id = require("../Phrost/Id");
const Keycode = require("../Phrost/Keycode");
const { Channels, Events } = require("../Phrost/Events");

/**
 * WarriorBody Class
 * * Represents the physical body of the player.
 * Handles input processing, movement physics, and collision responses.
 */
class WarriorBody extends PhysicsBody {
  /**
   * @param {number} id0
   * @param {number} id1
   * @param {boolean} [isNew=true]
   */
  constructor(id0, id1, isNew = true) {
    super(id0, id1, isNew);
    this.isOnGround = false;
  }

  /**
   * Restores state from a plain JSON object.
   * * @param {Object} data
   */
  hydrate(data) {
    Object.assign(this, data);
  }

  /**
   * Handle collision logic.
   * * @param {PhysicsBody} otherBody
   */
  onCollision(otherBody) {
    // Reset jump ability on ground collision
    if (!this.isOnGround) {
      console.log("Player landed on ground.");
      this.isOnGround = true;
    }
  }

  /**
   * Checks if a collision event involves this body.
   * * @param {Object} event - Collision event data
   * @param {Object} allBodies - Map of all physics bodies
   */
  processCollisionEvent(event, allBodies) {
    // Standardize all Event IDs to Unsigned 64-bit BigInts
    const id0_A = Id.asUnsigned(event.id1_A);
    const id1_A = Id.asUnsigned(event.id2_A);
    const id0_B = Id.asUnsigned(event.id1_B);
    const id1_B = Id.asUnsigned(event.id2_B);

    // Standardize our own IDs (in case they are stored as signed/negative)
    const myId0 = Id.asUnsigned(this.id0);
    const myId1 = Id.asUnsigned(this.id1);

    // Compare to check if we are Entity A or Entity B
    const isPlayerA = id0_A === myId0 && id1_A === myId1;
    const isPlayerB = id0_B === myId0 && id1_B === myId1;

    if (isPlayerA || isPlayerB) {
      // Get the ID of the OTHER entity
      // Note: We can pass the BigInts directly to Id.toHex() now.
      const otherKey = isPlayerA
        ? Id.toHex([id0_B, id1_B])
        : Id.toHex([id0_A, id1_A]);

      if (allBodies[otherKey]) {
        this.onCollision(allBodies[otherKey]);
      }
    }
  }

  /**
   * Processes input and updates physics state.
   * * @param {Object} inputState - Reference to global input state
   * @param {Object} packer - ChannelPacker
   */
  update(inputState, packer) {
    const moveSpeed = 250.0;
    let targetVx = 0.0;

    if (inputState[Keycode.LEFT]) {
      targetVx = -moveSpeed;
    }
    if (inputState[Keycode.RIGHT]) {
      targetVx = moveSpeed;
    }

    const currentV = this.getVelocity();
    const currentVy = currentV.y;

    // --- Jumping ---
    if (inputState[Keycode.UP]) {
      if (this.isOnGround) {
        console.log("Jumping!");
        this.applyImpulse(packer, 0.0, -400.0);
        this.isOnGround = false;

        // Consume input
        delete inputState[Keycode.UP];
      } else {
        // console.log("No Jumping (Airborne)");
      }
    }

    // --- Set Velocity ---
    this.setVelocity(targetVx, currentVy);

    // Pack changes
    this.packDirtyEvents(packer);
  }
}

module.exports = WarriorBody;
