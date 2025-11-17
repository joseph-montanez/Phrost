<?php

namespace Phrost;

/**
 * Manages a Geometry primitive.
 *
 * Based on the engine events, geometry is "write-once".
 * You can add it, remove it, and change its color, but not
 * its position or shape.
 */
class Geometry
{
    public readonly int $id0;
    public readonly int $id1;

    // --- Private State Properties ---
    private array $color = ["r" => 255, "g" => 255, "b" => 255, "a" => 255];
    private float $z = 0.0;
    private bool $isScreenSpace = false;

    // --- Configuration (set at creation) ---
    private ?GeomType $type = null;
    private array $shapeData = []; // [x1, y1] or [x1, y1, x2, y2] or [x, y, w, h]

    private array $dirtyFlags = [];
    private bool $isNew = true;

    public function __construct(int $id0, int $id1, bool $isNew = true)
    {
        $this->id0 = $id0;
        $this->id1 = $id1;
        $this->isNew = $isNew;
    }

    // --- Configuration Setters (for initialization) ---
    public function setZ(float $z): void
    {
        $this->z = $z;
    }

    /**
     * Sets this geometry to be "screen space" (unaffected by camera).
     * This must be called BEFORE the first packDirtyEvents().
     */
    public function setIsScreenSpace(bool $flag): void
    {
        $this->isScreenSpace = $flag;
    }

    public function setPoint(float $x, float $y): void
    {
        $this->type = GeomType::POINT;
        $this->shapeData = [$x, $y];
    }

    public function setLine(float $x1, float $y1, float $x2, float $y2): void
    {
        $this->type = GeomType::LINE;
        $this->shapeData = [$x1, $y1, $x2, $y2];
    }

    public function setRect(
        float $x,
        float $y,
        float $w,
        float $h,
        bool $filled = false,
    ): void {
        $this->type = $filled ? GeomType::FILL_RECT : GeomType::RECT;
        $this->shapeData = [$x, $y, $w, $h];
    }

    // --- State Setter (with Dirty Tracking) ---
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

    public function remove(ChannelPacker $packer): void
    {
        $packer->add(Channels::RENDERER->value, Events::GEOM_REMOVE, [
            $this->id0,
            $this->id1,
        ]);
    }

    // --- Event Generation ---

    private function getInitialAddData(): array
    {
        // Data must match GEOM_ADD_* format:
        // id1, id2, z, r, g, b, a, isScreenSpace, ...shape
        return [
            $this->id0,
            $this->id1,
            $this->z,
            $this->color["r"],
            $this->color["g"],
            $this->color["b"],
            $this->color["a"],
            $this->isScreenSpace ? 1 : 0,
            ...$this->shapeData,
        ];
    }

    public function packDirtyEvents(ChannelPacker $packer): void
    {
        if ($this->isNew) {
            if ($this->type === null) {
                error_log(
                    "Phrost\Geometry: Cannot pack ADD event, no shape was set (use setPoint, setLine, or setRect).",
                );
                return;
            }

            // Get the correct Event enum case from the GeomType
            $eventEnum = Events::from($this->type->value);
            $packer->add(
                Channels::RENDERER->value,
                $eventEnum,
                $this->getInitialAddData(),
            );

            $this->isNew = false;
            $this->clearDirtyFlags();
            return;
        }

        if (empty($this->dirtyFlags)) {
            return;
        }

        if (isset($this->dirtyFlags["color"])) {
            $packer->add(Channels::RENDERER->value, Events::GEOM_SET_COLOR, [
                $this->id0,
                $this->id1,
                $this->color["r"],
                $this->color["g"],
                $this->color["b"],
                $this->color["a"],
            ]);
        }

        $this->clearDirtyFlags();
    }

    public function clearDirtyFlags(): void
    {
        $this->dirtyFlags = [];
    }
}
