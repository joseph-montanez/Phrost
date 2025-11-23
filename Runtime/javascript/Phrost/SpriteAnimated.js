const Sprite = require("./Sprite");

/**
 * SpriteAnimated Class
 * * Manages an Animated Sprite entity.
 * Extends Sprite to inherit all properties and adds animation logic.
 */
class SpriteAnimated extends Sprite {
  constructor(id0, id1, isNew = true) {
    super(id0, id1, isNew);

    /** @type {Object.<string, Array<Object>>} Map of animation names to frame arrays */
    this.animations = {};

    this.currentAnimationName = null;
    this.currentFrameIndex = 0;
    this.frameTimer = 0.0;
    this.loops = true;
    this.isPlaying = false;
    this.animationSpeed = 1.0;
  }

  /**
   * Generates a frame array for a fixed-grid spritesheet.
   * * @param {number} startX
   * @param {number} startY
   * @param {number} frameWidth
   * @param {number} frameHeight
   * @param {number} frameCount
   * @param {number} durationPerFrame
   * @param {number} columns
   * @param {number} [paddingX=0]
   * @param {number} [paddingY=0]
   * @returns {Array<Object>} Frame array.
   */
  static generateFixedFrames(
    startX,
    startY,
    frameWidth,
    frameHeight,
    frameCount,
    durationPerFrame,
    columns,
    paddingX = 0,
    paddingY = 0,
  ) {
    const frames = [];
    for (let i = 0; i < frameCount; i++) {
      const col = i % columns;
      const row = Math.floor(i / columns);

      frames.push({
        x: startX + col * (frameWidth + paddingX),
        y: startY + row * (frameHeight + paddingY),
        w: frameWidth,
        h: frameHeight,
        duration: durationPerFrame,
      });
    }
    return frames;
  }

  /**
   * Adds a new animation definition.
   * * @param {string} name
   * @param {Array<Object>} frames - Array of {x, y, w, h, duration}
   */
  addAnimation(name, frames) {
    this.animations[name] = frames;
  }

  /**
   * Plays a defined animation.
   * * @param {string} name
   * @param {boolean} [loops=true]
   * @param {boolean} [forceRestart=false]
   */
  play(name, loops = true, forceRestart = false) {
    if (!this.animations[name]) {
      console.error(`AnimatedSprite: Unknown animation '${name}'`);
      return;
    }

    if (!forceRestart && this.currentAnimationName === name && this.isPlaying) {
      return; // Already playing
    }

    this.currentAnimationName = name;
    this.loops = loops;
    this.isPlaying = true;
    this.frameTimer = 0.0;
    this.currentFrameIndex = 0;

    this.applyFrame(this.currentFrameIndex);
  }

  stop() {
    this.isPlaying = false;
  }

  resume() {
    if (this.currentAnimationName) {
      this.isPlaying = true;
    }
  }

  setAnimationSpeed(speed) {
    this.animationSpeed = Math.max(0.01, speed);
  }

  /**
   * Updates the animation state.
   * * @param {number} dt
   */
  update(dt) {
    super.update(dt);

    if (
      !this.isPlaying ||
      !this.currentAnimationName ||
      !this.animations[this.currentAnimationName]
    ) {
      return;
    }

    const animation = this.animations[this.currentAnimationName];
    const frame = animation[this.currentFrameIndex];

    const duration = frame.duration / this.animationSpeed;

    this.frameTimer += dt;

    if (this.frameTimer >= duration) {
      this.frameTimer -= duration;

      let nextFrameIndex = this.currentFrameIndex + 1;

      if (nextFrameIndex >= animation.length) {
        if (this.loops) {
          nextFrameIndex = 0;
        } else {
          nextFrameIndex = this.currentFrameIndex;
          this.isPlaying = false;
        }
      }

      if (nextFrameIndex !== this.currentFrameIndex) {
        this.currentFrameIndex = nextFrameIndex;
        this.applyFrame(this.currentFrameIndex);
      }
    }
  }

  /**
   * @private
   * @param {number} frameIndex
   */
  applyFrame(frameIndex) {
    const frames = this.animations[this.currentAnimationName];
    if (!frames || !frames[frameIndex]) return;

    const frame = frames[frameIndex];
    this.setSourceRect(frame.x, frame.y, frame.w, frame.h);
  }

  isLooping() {
    return this.loops;
  }
  isPlaying() {
    return this.isPlaying;
  }
}

module.exports = SpriteAnimated;
