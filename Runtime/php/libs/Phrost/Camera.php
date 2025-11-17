<?php

namespace Phrost;

class Camera
{
    protected array $position = ["x" => 0.0, "y" => 0.0];
    protected float $zoom = 1.0;
    protected float $rotation = 0.0; // in radians

    /**
     * Stores which properties have changed since the last event pack.
     */
    protected array $dirtyFlags = [];

    /**
     * Flag to track if this is the first time packing events.
     */
    protected bool $isNew = true;

    public function __construct(
        float $initialX = 0.0,
        float $initialY = 0.0,
        float $initialZoom = 1.0,
    ) {
        $this->position["x"] = $initialX;
        $this->position["y"] = $initialY;
        $this->zoom = $initialZoom;
        $this->rotation = 0.0;
        $this->isNew = true;
    }

    /**
     * Sets the camera's absolute top-left position in the world.
     */
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

    /**
     * Moves the camera by a relative amount.
     */
    public function move(float $dx, float $dy, bool $notifyEngine = true): void
    {
        if ($dx !== 0.0 || $dy !== 0.0) {
            $this->position["x"] += $dx;
            $this->position["y"] += $dy;
            if ($notifyEngine) {
                $this->dirtyFlags["position"] = true;
            }
        }
    }

    /**
     * Sets the camera's zoom level.
     * 1.0 = no zoom, 2.0 = zoomed in (2x).
     */
    public function setZoom(float $zoom, bool $notifyEngine = true): void
    {
        if ($this->zoom !== $zoom) {
            $this->zoom = $zoom;
            if ($notifyEngine) {
                $this->dirtyFlags["zoom"] = true;
            }
        }
    }

    /**
     * Sets the camera's rotation.
     */
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

    // --- Getters ---
    public function getPosition(): array
    {
        return $this->position;
    }

    public function getZoom(): float
    {
        return $this->zoom;
    }

    public function getRotation(): float
    {
        return $this->rotation;
    }

    /**
     * Checks all dirty flags and adds the corresponding events
     * to the ChannelPacker.
     */
    public function packDirtyEvents(ChannelPacker $packer, $clear = true): void
    {
        if ($this->isNew) {
            // On first run, send all state to the engine
            $packer->add(
                Channels::RENDERER->value,
                Events::CAMERA_SET_POSITION,
                [$this->position["x"], $this->position["y"]],
            );
            $packer->add(Channels::RENDERER->value, Events::CAMERA_SET_ZOOM, [
                $this->zoom,
            ]);
            $packer->add(
                Channels::RENDERER->value,
                Events::CAMERA_SET_ROTATION,
                [$this->rotation],
            );

            $this->isNew = false;
            $this->clearDirtyFlags();
            return; // Exit
        }

        // --- REGULAR DIRTY CHECK ---
        if (empty($this->dirtyFlags)) {
            return; // Nothing to do
        }

        if (isset($this->dirtyFlags["position"])) {
            $packer->add(
                Channels::RENDERER->value,
                Events::CAMERA_SET_POSITION,
                [$this->position["x"], $this->position["y"]],
            );
        }

        if (isset($this->dirtyFlags["zoom"])) {
            $packer->add(Channels::RENDERER->value, Events::CAMERA_SET_ZOOM, [
                $this->zoom,
            ]);
        }

        if (isset($this->dirtyFlags["rotation"])) {
            $packer->add(
                Channels::RENDERER->value,
                Events::CAMERA_SET_ROTATION,
                [$this->rotation],
            );
        }

        if ($clear) {
            $this->clearDirtyFlags();
        }
    }

    public function clearDirtyFlags(): void
    {
        $this->dirtyFlags = [];
    }
}
