<?php

namespace Phrost;

/**
 * Manages a Physics Body entity.
 *
 * This class tracks the *desired* state (e.g., "set velocity to X")
 * and sends commands to the physics engine. It does not track the
 * simulated state (which is handled by PHYSICS_SYNC_TRANSFORM events).
 */
class PhysicsBody
{
    public readonly int $id0;
    public readonly int $id1;

    // --- Private State Properties ---
    private array $position = ["x" => 0.0, "y" => 0.0];
    private array $velocity = ["x" => 0.0, "y" => 0.0];
    private float $rotation = 0.0; // in radians
    private float $angularVelocity = 0.0;
    private bool $isSleeping = false;

    // --- Configuration (set at creation) ---
    private int $bodyType = 0; // 0=dynamic, 1=static, 2=kinematic
    private int $shapeType = 0; // 0=box, 1=circle
    private float $mass = 1.0;
    private float $friction = 0.5;
    private float $elasticity = 0.5;
    private float $width = 1.0;
    private float $height = 1.0;
    public int $lockRotation = 0;

    private array $dirtyFlags = [];
    private bool $isNew = true;

    public function __construct(int $id0, int $id1, bool $isNew = true)
    {
        $this->id0 = $id0;
        $this->id1 = $id1;
        $this->isNew = $isNew;
    }

    // --- Configuration Setters (for initialization) ---

    /**
     * Set the core physics properties.
     */
    public function setConfig(
        int $bodyType,
        int $shapeType,
        float $mass,
        float $friction,
        float $elasticity,
        int $lockRotation = 0,
    ): void {
        $this->bodyType = $bodyType;
        $this->shapeType = $shapeType;
        $this->mass = $mass;
        $this->friction = $friction;
        $this->elasticity = $elasticity;
        $this->lockRotation = $lockRotation;
    }

    /**
     * Set the shape dimensions.
     * @param float $width For Box: width. For Circle: radius.
     * @param float $height For Box: height. For Circle: ignored.
     */
    public function setShape(float $width, float $height): void
    {
        $this->width = $width;
        $this->height = $height;
    }

    // --- State Setters (with Dirty Tracking) ---

    public function setPosition(
        float $x,
        float $y,
        bool $notifyEngine = true,
    ): void {
        if ($this->position["x"] !== $x || $this->position["y"] !== $y) {
            $this->position["x"] = $x;
            $this->position["y"] = $y;
            if ($notifyEngine) {
                $this->dirtyFlags["position"] = true;
            }
        }
    }

    public function setVelocity(
        float $x,
        float $y,
        bool $notifyEngine = true,
    ): void {
        if ($this->velocity["x"] !== $x || $this->velocity["y"] !== $y) {
            $this->velocity["x"] = $x;
            $this->velocity["y"] = $y;
            if ($notifyEngine) {
                $this->dirtyFlags["velocity"] = true;
            }
        }
    }

    public function setRotation(
        float $angleInRadians,
        bool $notifyEngine = true,
    ): void {
        if ($this->rotation !== $angleInRadians) {
            $this->rotation = $angleInRadians;
            if ($notifyEngine) {
                $this->dirtyFlags["rotation"] = true;
            }
        }
    }

    public function setAngularVelocity(
        float $radPerSecond,
        bool $notifyEngine = true,
    ): void {
        if ($this->angularVelocity !== $radPerSecond) {
            $this->angularVelocity = $radPerSecond;
            if ($notifyEngine) {
                $this->dirtyFlags["angularVelocity"] = true;
            }
        }
    }

    public function setIsSleeping(
        bool $isSleeping,
        bool $notifyEngine = true,
    ): void {
        if ($this->isSleeping !== $isSleeping) {
            $this->isSleeping = $isSleeping;
            if ($notifyEngine) {
                $this->dirtyFlags["isSleeping"] = true;
            }
        }
    }

    // --- Immediate Event Methods (No Dirty Flags) ---

    public function applyForce(
        ChannelPacker $packer,
        float $forceX,
        float $forceY,
    ): void {
        $packer->add(Channels::PHYSICS->value, Events::PHYSICS_APPLY_FORCE, [
            $this->id0,
            $this->id1,
            $forceX,
            $forceY,
        ]);
    }

    public function applyImpulse(
        ChannelPacker $packer,
        float $impulseX,
        float $impulseY,
    ): void {
        $packer->add(Channels::PHYSICS->value, Events::PHYSICS_APPLY_IMPULSE, [
            $this->id0,
            $this->id1,
            $impulseX,
            $impulseY,
        ]);
    }

    public function remove(ChannelPacker $packer): void
    {
        $packer->add(Channels::PHYSICS->value, Events::PHYSICS_REMOVE_BODY, [
            $this->id0,
            $this->id1,
        ]);
    }

    private function getInitialAddData(): array
    {
        return [
            $this->id0,
            $this->id1,
            $this->position["x"],
            $this->position["y"],
            $this->bodyType,
            $this->shapeType,
            $this->lockRotation,
            // 5 bytes padding are handled by pack()
            $this->mass,
            $this->friction,
            $this->elasticity,
            $this->width,
            $this->height,
        ];
    }

    /**
     * Returns the current velocity of the physics body.
     *
     * @return array{x:float, y:float} An array containing the x and y components of the velocity.
     */
    public function getVelocity(): array
    {
        return $this->velocity;
    }

    public function getAngularVelocity(): float
    {
        return $this->angularVelocity;
    }

    public function getIsSleeping(): bool
    {
        return $this->isSleeping;
    }

    /**
     * Toggles the physics engine's debug rendering mode (green bounding boxes).
     */
    public static function setDebugMode(
        ChannelPacker $packer,
        bool $enabled,
    ): void {
        // Maps to PACK_PHYSICS_SET_DEBUG_MODE = "Cenabled/x3_padding"
        // The packer handles the padding automatically via the format map.
        $packer->add(Channels::PHYSICS->value, Events::PHYSICS_SET_DEBUG_MODE, [
            $enabled ? 1 : 0,
        ]);
    }

    public function packDirtyEvents(ChannelPacker $packer): void
    {
        if ($this->isNew) {
            // Send the full ADD_BODY event
            $packer->add(
                Channels::PHYSICS->value,
                Events::PHYSICS_ADD_BODY,
                $this->getInitialAddData(),
            );

            // If velocity was set before creation, send it immediately after.
            // This is common for projectiles.
            if ($this->velocity["x"] !== 0.0 || $this->velocity["y"] !== 0.0) {
                $packer->add(
                    Channels::PHYSICS->value,
                    Events::PHYSICS_SET_VELOCITY,
                    [
                        $this->id0,
                        $this->id1,
                        $this->velocity["x"],
                        $this->velocity["y"],
                    ],
                );
            }

            $this->isNew = false;
            $this->clearDirtyFlags();
            return;
        }

        if (empty($this->dirtyFlags)) {
            return;
        }

        if (isset($this->dirtyFlags["position"])) {
            $packer->add(
                Channels::PHYSICS->value,
                Events::PHYSICS_SET_POSITION,
                [
                    $this->id0,
                    $this->id1,
                    $this->position["x"],
                    $this->position["y"],
                ],
            );
        }

        if (isset($this->dirtyFlags["velocity"])) {
            $packer->add(
                Channels::PHYSICS->value,
                Events::PHYSICS_SET_VELOCITY,
                [
                    $this->id0,
                    $this->id1,
                    $this->velocity["x"],
                    $this->velocity["y"],
                ],
            );
        }

        if (isset($this->dirtyFlags["rotation"])) {
            $packer->add(
                Channels::PHYSICS->value,
                Events::PHYSICS_SET_ROTATION,
                [$this->id0, $this->id1, $this->rotation],
            );
        }

        $this->clearDirtyFlags();
    }

    public function clearDirtyFlags(): void
    {
        $this->dirtyFlags = [];
    }
}
