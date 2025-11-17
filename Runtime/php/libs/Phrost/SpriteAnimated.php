<?php

namespace Phrost;

/**
 * Manages an Animated Sprite entity.
 *
 * Extends Sprite to inherit all properties (position, color, etc.)
 * and adds logic to automatically update the source rectangle
 * over time based on defined animations.
 */
class SpriteAnimated extends Sprite
{
    /** @var array<string, array<int, array<string, mixed>>> */
    protected array $animations = [];

    protected ?string $currentAnimationName = null;
    protected int $currentFrameIndex = 0;
    protected float $frameTimer = 0.0;
    protected bool $loops = true;
    protected bool $isPlaying = false;
    protected float $animationSpeed = 1.0; // 1.0 = normal speed, 2.0 = double speed

    /**
     * Generates a frame array for a fixed-grid spritesheet.
     *
     * @param int $startX The top-left X coordinate of the first frame.
     * @param int $startY The top-left Y coordinate of the first frame.
     * @param int $frameWidth The width of each frame.
     * @param int $frameHeight The height of each frame.
     * @param int $frameCount The total number of frames in the animation.
     * @param float $durationPerFrame The time (in seconds) to show each frame.
     * @param int $columns The number of columns in the spritesheet grid.
     * @param int $paddingX Horizontal padding between frames.
     * @param int $paddingY Vertical padding between frames.
     * @return array The animation frame definition array.
     */
    public static function generateFixedFrames(
        int $startX,
        int $startY,
        int $frameWidth,
        int $frameHeight,
        int $frameCount,
        float $durationPerFrame,
        int $columns,
        int $paddingX = 0,
        int $paddingY = 0,
    ): array {
        $frames = [];
        for ($i = 0; $i < $frameCount; $i++) {
            $col = $i % $columns;
            $row = floor($i / $columns);

            $frames[] = [
                "x" => $startX + $col * ($frameWidth + $paddingX),
                "y" => $startY + $row * ($frameHeight + $paddingY),
                "w" => $frameWidth,
                "h" => $frameHeight,
                "duration" => $durationPerFrame,
            ];
        }
        return $frames;
    }

    /**
     * Adds a new animation definition.
     *
     * This handles "irregular" frames, where each frame can have
     * a different size and duration.
     *
     * @param string $name The name of the animation (e.g., "walk", "idle").
     * @param array $frames An array of frame definitions.
     * Each frame is an array:
     * ['x' => int, 'y' => int, 'w' => int, 'h' => int, 'duration' => float]
     */
    public function addAnimation(string $name, array $frames): void
    {
        $this->animations[$name] = $frames;
    }

    /**
     * Plays a defined animation.
     *
     * @param string $name The name of the animation to play.
     * @param bool $loops Whether the animation should loop.
     * @param bool $forceRestart If false, continues playing if already on this animation.
     */
    public function play(
        string $name,
        bool $loops = true,
        bool $forceRestart = false,
    ): void {
        if (!isset($this->animations[$name])) {
            error_log("AnimatedSprite: Unknown animation '{$name}'");
            return;
        }

        if (
            !$forceRestart &&
            $this->currentAnimationName === $name &&
            $this->isPlaying
        ) {
            return; // Already playing this
        }

        $this->currentAnimationName = $name;
        $this->loops = $loops;
        $this->isPlaying = true;
        $this->frameTimer = 0.0;
        $this->currentFrameIndex = 0;

        // Immediately apply the first frame
        $this->applyFrame($this->currentFrameIndex);
    }

    /**
     * Stops the animation, holding on the current frame.
     */
    public function stop(): void
    {
        $this->isPlaying = false;
    }

    /**
     * Resumes the animation from the current frame.
     */
    public function resume(): void
    {
        if ($this->currentAnimationName) {
            $this->isPlaying = true;
        }
    }

    /**
     * Sets the playback speed multiplier.
     * 1.0 is normal, 2.0 is double speed, 0.5 is half speed.
     */
    public function setAnimationSpeed(float $speed): void
    {
        $this->animationSpeed = max(0.01, $speed); // Avoid division by zero
    }

    /**
     * Updates the animation state.
     * This should be called every frame from your main game loop.
     *
     * @param float $dt Delta time (time since last frame).
     */
    public function update(float $dt): void
    {
        // First, call the parent update to handle movement
        parent::update($dt);

        if (
            !$this->isPlaying ||
            !$this->currentAnimationName ||
            !isset($this->animations[$this->currentAnimationName])
        ) {
            return;
        }

        $animation = $this->animations[$this->currentAnimationName];
        $frame = $animation[$this->currentFrameIndex];

        // Get the frame's duration, adjusted by the animation speed
        $duration = $frame["duration"] / $this->animationSpeed;

        // Add this frame's delta time
        $this->frameTimer += $dt;

        // Time to advance to the next frame?
        if ($this->frameTimer >= $duration) {
            // Carry over any excess time
            $this->frameTimer -= $duration;

            $nextFrameIndex = $this->currentFrameIndex + 1;

            // Check if we've reached the end of the animation
            if ($nextFrameIndex >= count($animation)) {
                if ($this->loops) {
                    $nextFrameIndex = 0; // Loop back to start
                } else {
                    $nextFrameIndex = $this->currentFrameIndex; // Stay on last frame
                    $this->isPlaying = false;
                }
            }

            // If the frame changed, apply it
            if ($nextFrameIndex !== $this->currentFrameIndex) {
                $this->currentFrameIndex = $nextFrameIndex;
                $this->applyFrame($this->currentFrameIndex);
            }
        }
    }

    /**
     * Internal helper to apply a frame's source rect.
     */
    protected function applyFrame(int $frameIndex): void
    {
        if (
            !isset($this->animations[$this->currentAnimationName][$frameIndex])
        ) {
            return;
        }

        $frame = $this->animations[$this->currentAnimationName][$frameIndex];

        // Use the parent Sprite's method. This will automatically
        // set the 'source_rect' dirty flag!
        $this->setSourceRect(
            $frame["x"],
            $frame["y"],
            $frame["w"],
            $frame["h"],
        );
    }

    /**
     * Checks if the current animation is set to loop.
     * @return bool
     */
    public function isLooping(): bool
    {
        return $this->loops;
    }

    /**
     * Checks if an animation is currently playing.
     * @return bool
     */
    public function isPlaying(): bool
    {
        return $this->isPlaying;
    }
}
