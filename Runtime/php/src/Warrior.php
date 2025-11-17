<?php

namespace Game;

use Phrost\SpriteAnimated;

class Warrior extends SpriteAnimated
{
    /**
     * Called by PHP right before serialize().
     *
     * @return array The data to be serialized.
     */
    public function __serialize(): array
    {
        // get_object_vars($this) is the simplest way to get all
        // properties (public, protected, and private) from this
        // class and its parents.
        return get_object_vars($this);
    }

    /**
     * Called by PHP right after unserialize().
     *
     * @param array $data The array returned from __serialize().
     */
    public function __unserialize(array $data): void
    {
        // This loop restores all the saved properties,
        // including readonly properties, which is a key feature.
        foreach ($data as $key => $value) {
            // Note: This works even for protected/private properties
            // from parent classes, which was a major issue with __wakeup.
            $this->{$key} = $value;
        }

        // Now, run our custom re-initialization logic
        // just like we did with __wakeup().
        $this->initializeAnimations();
        echo "Warrior {$this->id0} has unserialized and rebuilt animations.\n";
    }

    /**
     * This is your old `defineWarriorAnimations` function,
     * now a method of the Warrior class.
     */
    public function initializeAnimations(): void
    {
        // Clear any existing animations, in case this is a refresh
        $this->animations = [];

        // --- Define your grid parameters ---
        $frameWidth = 64;
        $frameHeight = 44;
        $paddingX = 5;
        $paddingY = 0;
        $spriteSheetColumns = 6;

        // --- "idle" animation (Row 1) ---
        // Per your rule: (Row 1 - 1) = 0
        $idleStartY = ($frameHeight + $paddingY) * 0;
        $idleFrames = SpriteAnimated::generateFixedFrames(
            0, // startX
            $idleStartY, // startY (Row 1)
            $frameWidth,
            $frameHeight,
            6, // 6 frames total
            0.1, // duration
            $spriteSheetColumns, // Grid has 6 columns
            $paddingX,
            $paddingY,
        );
        $this->addAnimation("idle", $idleFrames);

        // --- "run" animation (Row 2) ---
        // Per your rule: (Row 2 - 1) = 1
        $runStartY = ($frameHeight + $paddingY) * 1;
        $runFrames = SpriteAnimated::generateFixedFrames(
            0, // startX
            $runStartY, // startY (Row 2)
            $frameWidth,
            $frameHeight,
            8, // 8 frames total
            0.08, // duration
            $spriteSheetColumns, // Grid has 6 columns
            $paddingX,
            $paddingY,
        );
        $this->addAnimation("run", $runFrames);

        // --- "attack" animation (Spills from Row 3) ---
        // Per your rule: (Row 3 - 1) = 2
        $attackStartY = ($frameHeight + $paddingY) * 2; // Row 3
        $attackFrames = SpriteAnimated::generateFixedFrames(
            0, // startX
            $attackStartY, // startY (Row 3)
            $frameWidth,
            $frameHeight,
            14, // 14 frames total
            0.08, // duration
            $spriteSheetColumns, // The grid width (6)
            $paddingX,
            $paddingY,
        );
        $this->addAnimation("attack", $attackFrames);
    }

    public function update(float $dt): void
    {
        // This advances the animation frame and updates $this->isPlaying.
        parent::update($dt);

        // Check the parent's properties directly!
        if (!$this->loops && !$this->isPlaying) {
            // echo "Animation '{$this->currentAnimationName}' finished, returning to idle.\n";
            $this->play("idle", true, false); // loop, don't force
        }
    }
}
