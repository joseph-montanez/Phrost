<?php

namespace Phrost;

class Sprite
{
    public readonly int $id0;
    public readonly int $id1;

    protected array $position = ["x" => 0.0, "y" => 0.0, "z" => 0.0];
    protected array $size = ["width" => 1.0, "height" => 1.0];
    protected array $color = ["r" => 255, "g" => 255, "b" => 255, "a" => 255];
    protected ?string $texturePath = null;
    protected array $rotate = ["x" => 0.0, "y" => 0.0, "z" => 0.0];
    protected array $speed = ["x" => 0.0, "y" => 0.0];
    protected array $scale = ["x" => 1.0, "y" => 1.0, "z" => 1.0];
    protected int $textureId = 0;

    /**
     * Stores the source rectangle ['x', 'y', 'w', 'h']
     */
    protected ?array $sourceRect = null;

    /**
     * Stores which properties have changed since the last event pack.
     */
    protected array $dirtyFlags = [];

    /**
     * Flag to track if this sprite was just created.
     */
    protected bool $isNew = true;

    public function __construct(int $id0, int $id1, $isNew = true)
    {
        $this->id0 = $id0;
        $this->id1 = $id1;
        $this->isNew = $isNew;
    }

    public function update(float $dt): void
    {
        if ($this->speed["x"] === 0.0 && $this->speed["y"] === 0.0) {
            return;
        }
        $this->setPosition(
            $this->position["x"] + $this->speed["x"] * $dt,
            $this->position["y"] + $this->speed["y"] * $dt,
            $this->position["z"],
        );
    }

    public function setPosition(
        float $x,
        float $y,
        float $z,
        bool $notifyEngine = true,
    ): void {
        if (
            $this->position["x"] !== $x ||
            $this->position["y"] !== $y ||
            $this->position["z"] !== $z
        ) {
            $this->position["x"] = $x;
            $this->position["y"] = $y;
            $this->position["z"] = $z;
            if ($notifyEngine) {
                $this->dirtyFlags["position"] = true;
            }
        }
    }

    public function setSize(
        float $width,
        float $height,
        bool $notifyEngine = true,
    ): void {
        if (
            $this->size["width"] !== $width ||
            $this->size["height"] !== $height
        ) {
            $this->size["width"] = $width;
            $this->size["height"] = $height;
            if ($notifyEngine) {
                $this->dirtyFlags["size"] = true;
            }
        }
    }

    public function setColor(
        int $r,
        int $g,
        int $b,
        int $a,
        bool $notifyEngine = true,
    ): void {
        if (
            $this->color["r"] !== $r ||
            $this->color["g"] !== $g ||
            $this->color["b"] !== $b ||
            $this->color["a"] !== $a
        ) {
            $this->color["r"] = $r;
            $this->color["g"] = $g;
            $this->color["b"] = $b;
            $this->color["a"] = $a;
            if ($notifyEngine) {
                $this->dirtyFlags["color"] = true;
            }
        }
    }

    public function setTexturePath(
        string $path,
        bool $notifyEngine = true,
    ): void {
        if ($this->texturePath !== $path) {
            $this->texturePath = $path;
            if ($notifyEngine) {
                $this->dirtyFlags["texture"] = true;
            }
        }
    }

    public function setRotate(
        float $x,
        float $y,
        float $z,
        bool $notifyEngine = true,
    ): void {
        if (
            $this->rotate["x"] !== $x ||
            $this->rotate["y"] !== $y ||
            $this->rotate["z"] !== $z
        ) {
            $this->rotate["x"] = $x;
            $this->rotate["y"] = $y;
            $this->rotate["z"] = $z;
            if ($notifyEngine) {
                $this->dirtyFlags["rotate"] = true;
            }
        }
    }

    public function setSpeed(
        float $x,
        float $y,
        bool $notifyEngine = true,
    ): void {
        if ($this->speed["x"] !== $x || $this->speed["y"] !== $y) {
            $this->speed["x"] = $x;
            $this->speed["y"] = $y;
            if ($notifyEngine) {
                $this->dirtyFlags["speed"] = true;
            }
        }
    }

    public function setScale(
        float $x,
        float $y,
        float $z,
        bool $notifyEngine = true,
    ): void {
        if (
            $this->scale["x"] !== $x ||
            $this->scale["y"] !== $y ||
            $this->scale["z"] !== $z
        ) {
            $this->scale["x"] = $x;
            $this->scale["y"] = $y;
            $this->scale["z"] = $z;
            if ($notifyEngine) {
                $this->dirtyFlags["scale"] = true;
            }
        }
    }

    /**
     * Sets the horizontal flip state of the sprite by modifying its X scale.
     *
     * @param bool $isFlipped True to flip horizontally (face left), false for normal (face right).
     * @param bool $notifyEngine Pass the change to the engine.
     */
    public function setFlip(bool $isFlipped, bool $notifyEngine = true): void
    {
        // Get the current absolute X scale
        $currentAbsScaleX = abs($this->scale["x"]);

        // Determine the new X scale
        $newScaleX = $isFlipped ? -$currentAbsScaleX : $currentAbsScaleX;

        // Use the existing setScale method to apply the change
        // This will automatically handle the dirty flag
        $this->setScale(
            $newScaleX,
            $this->scale["y"],
            $this->scale["z"],
            $notifyEngine,
        );
    }

    /**
     * Sets the source rectangle for texture mapping.
     */
    public function setSourceRect(
        float $x,
        float $y,
        float $w,
        float $h,
        bool $notifyEngine = true,
    ): void {
        $newRect = ["x" => $x, "y" => $y, "w" => $w, "h" => $h];
        if ($this->sourceRect !== $newRect) {
            $this->sourceRect = $newRect;
            if ($notifyEngine) {
                $this->dirtyFlags["source_rect"] = true;
            }
        }
    }

    /**
     * Sets the texture ID for the sprite.
     */
    public function setTextureId(int $textureId): void
    {
        $this->textureId = $textureId;
    }

    // --- Getters (for reading state) ---
    public function getPosition(): array
    {
        return $this->position;
    }
    public function getSpeed(): array
    {
        return $this->speed;
    }

    public function getScale(): array
    {
        return $this->scale;
    }

    public function getRotation(): array
    {
        return $this->rotate;
    }

    public function getColor(): array
    {
        return $this->color;
    }

    public function getId(): array
    {
        return [$this->id0, $this->id1];
    }

    public function getTextureId(): int
    {
        return $this->textureId;
    }

    /**
     * Gets the source rectangle for texture mapping.
     */
    public function getSourceRect(): ?array
    {
        return $this->sourceRect;
    }

    /**
     * Generates the data array for the initial SPRITE_ADD event.
     */
    public function getInitialAddData(): array
    {
        return [
            $this->id0,
            $this->id1,
            $this->position["x"],
            $this->position["y"],
            $this->position["z"],
            $this->scale["x"],
            $this->scale["y"],
            $this->scale["z"],
            $this->size["width"],
            $this->size["height"],
            $this->rotate["x"],
            $this->rotate["y"],
            $this->rotate["z"],
            $this->color["r"],
            $this->color["g"],
            $this->color["b"],
            $this->color["a"],
            $this->speed["x"],
            $this->speed["y"],
        ];
    }

    /**
     * Checks all dirty flags and adds the corresponding events
     * to the CommandPacker.
     */
    public function packDirtyEvents(ChannelPacker $packer, $clear = true): void
    {
        if ($this->isNew) {
            // Send the full SPRITE_ADD event
            $packer->add(
                Channels::RENDERER->value,
                Events::SPRITE_ADD,
                $this->getInitialAddData(),
            );

            // Also send the texture load event if a texture was set
            if (isset($this->texturePath)) {
                $filename = $this->texturePath;
                $filenameLength = strlen($filename);
                $packer->add(
                    Channels::RENDERER->value,
                    Events::SPRITE_TEXTURE_LOAD,
                    [$this->id0, $this->id1, $filenameLength, $filename],
                );
            }

            // Also send source rect if it was set during initialization
            if (isset($this->sourceRect)) {
                $packer->add(
                    Channels::RENDERER->value,
                    Events::SPRITE_SET_SOURCE_RECT,
                    [
                        $this->id0,
                        $this->id1,
                        $this->sourceRect["x"],
                        $this->sourceRect["y"],
                        $this->sourceRect["w"],
                        $this->sourceRect["h"],
                    ],
                );
            }

            // Mark as no longer new and clear all other flags
            $this->isNew = false;
            $this->clearDirtyFlags();
            return; // Exit
        }

        if (empty($this->dirtyFlags)) {
            return; // Nothing to do
        }

        if (isset($this->dirtyFlags["position"])) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_MOVE, [
                $this->id0,
                $this->id1,
                $this->position["x"],
                $this->position["y"],
                $this->position["z"],
            ]);
        }

        if (isset($this->dirtyFlags["scale"])) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_SCALE, [
                $this->id0,
                $this->id1,
                $this->scale["x"],
                $this->scale["y"],
                $this->scale["z"],
            ]);
        }

        if (isset($this->dirtyFlags["size"])) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_RESIZE, [
                $this->id0,
                $this->id1,
                $this->size["width"],
                $this->size["height"],
            ]);
        }

        if (isset($this->dirtyFlags["rotate"])) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_ROTATE, [
                $this->id0,
                $this->id1,
                $this->rotate["x"],
                $this->rotate["y"],
                $this->rotate["z"],
            ]);
        }

        if (isset($this->dirtyFlags["color"])) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_COLOR, [
                $this->id0,
                $this->id1,
                $this->color["r"],
                $this->color["g"],
                $this->color["b"],
                $this->color["a"],
            ]);
        }

        if (isset($this->dirtyFlags["speed"])) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_SPEED, [
                $this->id0,
                $this->id1,
                $this->speed["x"],
                $this->speed["y"],
            ]);
        }

        if (isset($this->dirtyFlags["texture"])) {
            $filename = $this->texturePath ?? "";
            $filenameLength = strlen($filename);
            $packer->add(
                Channels::RENDERER->value,
                Events::SPRITE_TEXTURE_LOAD,
                [$this->id0, $this - id1, $filenameLength, $filename],
            );
        }

        // --- NEW DIRTY CHECK ---
        if (isset($this->dirtyFlags["source_rect"])) {
            if (isset($this->sourceRect)) {
                $packer->add(
                    Channels::RENDERER->value,
                    Events::SPRITE_SET_SOURCE_RECT,
                    [
                        $this->id0,
                        $this->id1,
                        $this->sourceRect["x"],
                        $this->sourceRect["y"],
                        $this->sourceRect["w"],
                        $this->sourceRect["h"],
                    ],
                );
            }
        }

        if ($clear) {
            $this->clearDirtyFlags();
        }
    }

    public function clearDirtyFlags(): void
    {
        $this->dirtyFlags = [];
    }

    /**
     * Removes the sprite from the engine.
     */
    public function remove(ChannelPacker $packer): void
    {
        $packer->add(Channels::RENDERER->value, Events::SPRITE_REMOVE, [
            $this->id0,
            $this->id1,
        ]);

        // Clear flags so we don't accidentally try to pack updates
        // for a sprite that no longer exists in the engine.
        $this->clearDirtyFlags();
    }
}
