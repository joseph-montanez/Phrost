import sys
from typing import Any, Dict, List, Optional

# Import from the other converted file
from GeomType import GeomType

# Imports from your existing adapter file
# (Assuming it's saved as phrost_adapter.py)
try:
    from Phrost import CommandPacker, Events
except ImportError:
    print(
        "Could not import CommandPacker/Events. Please ensure phrost_adapter.py is in the same directory."
    )


class Geometry:
    """
    Manages a Geometry primitive.
    Based on the engine events, geometry is "write-once".
    You can add it, remove it, and change its color, but not
    its position or shape.
    """

    def __init__(self, id0: int, id1: int, is_new: bool = True):
        self.id0: int = id0
        self.id1: int = id1

        # --- Private State Properties ---
        self.color: Dict[str, int] = {"r": 255, "g": 255, "b": 255, "a": 255}
        self.z: float = 0.0

        # --- Configuration (set at creation) ---
        self.type: Optional[GeomType] = None
        # [x1, y1] or [x1, y1, x2, y2] or [x, y, w, h]
        self.shape_data: List[float] = []

        self.dirty_flags: Dict[str, bool] = {}
        self.is_new: bool = is_new

    # --- Configuration Setters (for initialization) ---

    def set_z(self, z: float) -> None:
        self.z = z

    def set_point(self, x: float, y: float) -> None:
        self.type = GeomType.POINT
        self.shape_data = [x, y]

    def set_line(self, x1: float, y1: float, x2: float, y2: float) -> None:
        self.type = GeomType.LINE
        self.shape_data = [x1, y1, x2, y2]

    def set_rect(
        self, x: float, y: float, w: float, h: float, filled: bool = False
    ) -> None:
        self.type = GeomType.FILL_RECT if filled else GeomType.RECT
        self.shape_data = [x, y, w, h]

    # --- State Setter (with Dirty Tracking) ---

    def set_color(
        self, r: int, g: int, b: int, a: int, notify_engine: bool = True
    ) -> None:
        if (
            self.color["r"] != r
            or self.color["g"] != g
            or self.color["b"] != b
            or self.color["a"] != a
        ):
            self.color["r"] = r
            self.color["g"] = g
            self.color["b"] = b
            self.color["a"] = a
            if notify_engine:
                self.dirty_flags["color"] = True

    def remove(self, packer: CommandPacker) -> None:
        packer.add(Events.GEOM_REMOVE, [self.id0, self.id1])

    # --- Event Generation ---

    def _get_initial_add_data(self) -> List[Any]:
        """
        Data must match GEOM_ADD_* format:
        id1, id2, z, r, g, b, a, ...shape
        """
        return [
            self.id0,
            self.id1,
            self.z,
            self.color["r"],
            self.color["g"],
            self.color["b"],
            self.color["a"],
            *self.shape_data,  # Unpack the shape data
        ]

    def pack_dirty_events(self, packer: CommandPacker) -> None:
        if self.is_new:
            if self.type is None:
                print(
                    "Phrost.Geometry: Cannot pack ADD event, "
                    "no shape was set (use set_point, set_line, or set_rect).",
                    file=sys.stderr,
                )
                return

            # Get the correct Event enum case from the GeomType
            event_enum = Events(self.type.value)
            packer.add(event_enum, self._get_initial_add_data())

            self.is_new = False
            self.clear_dirty_flags()
            return

        if not self.dirty_flags:
            return

        if "color" in self.dirty_flags:
            packer.add(
                Events.GEOM_SET_COLOR,
                [
                    self.id0,
                    self.id1,
                    self.color["r"],
                    self.color["g"],
                    self.color["b"],
                    self.color["a"],
                ],
            )

        self.clear_dirty_flags()

    def clear_dirty_flags(self) -> None:
        self.dirty_flags = {}
