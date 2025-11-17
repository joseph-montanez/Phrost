<?php

namespace Game;

use Phrost\ChannelPacker;
use Phrost\Id;
use Phrost\Keycode;
use Phrost\PhysicsBody;

class WarriorBody extends PhysicsBody
{
    public bool $isOnGround = false;

    public function onCollision(PhysicsBody $otherBody): void
    {
        // Player has collided with another physics body (ground, wall, etc.)
        // This will reset the jump ability.
        if (!$this->isOnGround) {
            echo "Player landed on ground.\n";
            $this->isOnGround = true;
        }
    }

    /**
     * It checks if a collision event involves this specific player and,
     * if so, calls onCollision.
     *
     * @param array $event The collision event data.
     * @param array $allBodies The list of all physics bodies from $world.
     */
    public function processCollisionEvent(array $event, array $allBodies): void
    {
        // Check if this body (self) is part of this collision
        $isPlayerA =
            $event["id1_A"] === $this->id0 && $event["id2_A"] === $this->id1;
        $isPlayerB =
            $event["id1_B"] === $this->id0 && $event["id2_B"] === $this->id1;

        if ($isPlayerA || $isPlayerB) {
            // The player is involved. Find the *other* object.
            $otherKey = $isPlayerA
                ? Id::toHex([$event["id1_B"], $event["id2_B"]])
                : Id::toHex([$event["id1_A"], $event["id2_A"]]);

            // If the other object exists, call our internal onCollision method
            if (isset($allBodies[$otherKey])) {
                $this->onCollision($allBodies[$otherKey]);
            }
        }
    }

    /**
     * Runs every frame to process input and update player state.
     *
     * @param array &$inputState The global input state (passed by reference).
     * @param ChannelPacker $packer The binary event packer.
     */
    public function update(array &$inputState, ChannelPacker $packer): void
    {
        $moveSpeed = 250.0; // Target horizontal speed
        $targetVx = 0.0; // Default to no horizontal movement

        // Check for left/right input
        if (isset($inputState[Keycode::LEFT])) {
            $targetVx = -$moveSpeed;
        }
        if (isset($inputState[Keycode::RIGHT])) {
            $targetVx = $moveSpeed;
        }

        // Get the current vertical velocity
        $currentV = $this->getVelocity();
        $currentVy = $currentV["y"];

        // --- Jumping (Still uses Impulse) ---
        if (isset($inputState[Keycode::UP])) {
            if ($this->isOnGround) {
                echo "Jumping!\n";
                // 'self' is now $this
                $this->applyImpulse($packer, 0.0, -400.0);
                $this->isOnGround = false; // Set state

                // "Consume" the jump input from the referenced array
                unset($inputState[Keycode::UP]);
            } else {
                echo "No Jumping!\n";
            }
        }

        // --- Set the Final Velocity ---
        $this->setVelocity($targetVx, $currentVy);

        // Finally, pack any events this body generated (setVelocity, applyImpulse)
        $this->packDirtyEvents($packer);
    }
}
