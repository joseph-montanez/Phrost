const SpriteAnimated = require("../Phrost/SpriteAnimated");

/**
 * Warrior Class
 * * Represents the player's visual sprite entity.
 * Handles animation states (idle, run, attack).
 */
class Warrior extends SpriteAnimated {
  /**
   * @param {number} id0
   * @param {number} id1
   * @param {boolean} [isNew=true]
   */
  constructor(id0, id1, isNew = true) {
    super(id0, id1, isNew);
  }

  /**
   * Custom hydration method to restore state after JSON parsing.
   * This replaces PHP's __unserialize.
   * * @param {Object} data - Plain object from JSON.parse
   */
  hydrate(data) {
    // Restore standard properties
    Object.assign(this, data);

    // Re-initialize animations because functions/logic aren't saved in JSON
    this.initializeAnimations();
    console.log(
      `Warrior ${this.id0} has been hydrated and animations rebuilt.`,
    );
  }

  /**
   * Defines the animations for the Warrior.
   */
  initializeAnimations() {
    // Clear existing animations
    this.animations = {};

    // --- Define grid parameters ---
    const frameWidth = 64;
    const frameHeight = 44;
    const paddingX = 5;
    const paddingY = 0;
    const spriteSheetColumns = 6;

    // --- "idle" animation (Row 1) ---
    const idleStartY = (frameHeight + paddingY) * 0;
    const idleFrames = SpriteAnimated.generateFixedFrames(
      0, // startX
      idleStartY, // startY
      frameWidth,
      frameHeight,
      6, // frameCount
      0.1, // duration
      spriteSheetColumns,
      paddingX,
      paddingY,
    );
    this.addAnimation("idle", idleFrames);

    // --- "run" animation (Row 2) ---
    const runStartY = (frameHeight + paddingY) * 1;
    const runFrames = SpriteAnimated.generateFixedFrames(
      0,
      runStartY,
      frameWidth,
      frameHeight,
      8,
      0.08,
      spriteSheetColumns,
      paddingX,
      paddingY,
    );
    this.addAnimation("run", runFrames);

    // --- "attack" animation (Row 3) ---
    const attackStartY = (frameHeight + paddingY) * 2;
    const attackFrames = SpriteAnimated.generateFixedFrames(
      0,
      attackStartY,
      frameWidth,
      frameHeight,
      14,
      0.08,
      spriteSheetColumns,
      paddingX,
      paddingY,
    );
    this.addAnimation("attack", attackFrames);
  }

  /**
   * @param {number} dt
   */
  update(dt) {
    // Advance animation frame
    super.update(dt);

    // Logic: If non-looping animation finished, go back to idle
    if (!this.loops && !this.isPlaying) {
      this.play("idle", true, false);
    }
  }
}

module.exports = Warrior;
