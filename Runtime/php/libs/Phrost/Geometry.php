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

    // --- Polygon-specific data ---
    /** @var array<array{float, float}> Array of [x, y] vertex pairs */
    private array $polygonVertices = [];

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
        $this->polygonVertices = [];
    }

    public function setLine(float $x1, float $y1, float $x2, float $y2): void
    {
        $this->type = GeomType::LINE;
        $this->shapeData = [$x1, $y1, $x2, $y2];
        $this->polygonVertices = [];
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
        $this->polygonVertices = [];
    }

    /**
     * Sets this geometry as a polygon.
     *
     * @param array<array{float, float}> $vertices Array of [x, y] vertex pairs.
     *        Must have at least 3 vertices for a valid polygon.
     *        Example: [[100, 50], [50, 150], [150, 150]] for a triangle
     * @param bool $filled If true, renders as filled polygon. If false, renders outline only.
     */
    public function setPolygon(array $vertices, bool $filled = true): void
    {
        if (count($vertices) < 3) {
            error_log("Phrost\Geometry: Polygon requires at least 3 vertices.");
            return;
        }

        $this->type = $filled ? GeomType::POLYGON : GeomType::POLYGON_OUTLINE;
        $this->polygonVertices = $vertices;
        $this->shapeData = []; // Not used for polygons
    }

    /**
     * Convenience method to set a regular polygon (circle approximation, star, etc.)
     *
     * @param float $centerX Center X coordinate
     * @param float $centerY Center Y coordinate
     * @param float $radius Distance from center to vertices
     * @param int $sides Number of sides (3 = triangle, 4 = square, 5 = pentagon, etc.)
     * @param float $rotationDegrees Rotation offset in degrees
     * @param bool $filled If true, renders as filled polygon
     */
    public function setRegularPolygon(
        float $centerX,
        float $centerY,
        float $radius,
        int $sides,
        float $rotationDegrees = 0.0,
        bool $filled = true,
    ): void {
        if ($sides < 3) {
            error_log(
                "Phrost\Geometry: Regular polygon requires at least 3 sides.",
            );
            return;
        }

        $vertices = [];
        $rotationRad = deg2rad($rotationDegrees);
        $angleStep = (2 * M_PI) / $sides;

        for ($i = 0; $i < $sides; $i++) {
            $angle = $rotationRad + $i * $angleStep;
            $x = $centerX + $radius * cos($angle);
            $y = $centerY + $radius * sin($angle);
            $vertices[] = [$x, $y];
        }

        $this->setPolygon($vertices, $filled);
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

    /**
     * Returns the data array for non-polygon geometry types.
     */
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

    /**
     * Returns the data array for polygon geometry types.
     * Format: id1, id2, z, r, g, b, a, isScreenSpace, vertexCount, ...vertices
     */
    private function getPolygonAddData(): array
    {
        $vertexCount = count($this->polygonVertices);

        // Flatten vertices: [[x1,y1], [x2,y2]] -> [x1, y1, x2, y2]
        $flatVertices = [];
        foreach ($this->polygonVertices as $vertex) {
            $flatVertices[] = (float) $vertex[0];
            $flatVertices[] = (float) $vertex[1];
        }

        return [
            $this->id0,
            $this->id1,
            $this->z,
            $this->color["r"],
            $this->color["g"],
            $this->color["b"],
            $this->color["a"],
            $this->isScreenSpace ? 1 : 0,
            $vertexCount,
            ...$flatVertices,
        ];
    }

    /**
     * Checks if this geometry is a polygon type.
     */
    private function isPolygonType(): bool
    {
        return $this->type === GeomType::POLYGON ||
            $this->type === GeomType::POLYGON_OUTLINE;
    }

    public function packDirtyEvents(ChannelPacker $packer): void
    {
        if ($this->isNew) {
            if ($this->type === null) {
                error_log(
                    "Phrost\Geometry: Cannot pack ADD event, no shape was set (use setPoint, setLine, setRect, or setPolygon).",
                );
                return;
            }

            // Get the correct Event enum case from the GeomType
            $eventEnum = Events::from($this->type->value);

            // Use appropriate data format based on type
            if ($this->isPolygonType()) {
                $packer->add(
                    Channels::RENDERER->value,
                    $eventEnum,
                    $this->getPolygonAddData(),
                );
            } else {
                $packer->add(
                    Channels::RENDERER->value,
                    $eventEnum,
                    $this->getInitialAddData(),
                );
            }

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
