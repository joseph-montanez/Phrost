import enum
from typing import Any, Dict, List

# Imports from your existing adapter file
# (Assuming it's saved as phrost_adapter.py)
try:
    from Phrost import CommandPacker, Events
except ImportError:
    print(
        "Could not import CommandPacker/Events. Please ensure phrost_adapter.py is in the same directory."
    )


class PhysicsBody:
    """
    Manages a Physics Body entity.

    This class tracks the *desired* state (e.g., "set velocity to X")
    and sends commands to the physics engine. It does not track the
    simulated state (which is handled by PHYSICS_SYNC_TRANSFORM events).
    """

    def __init__(self, id0: int, id1: int, is_new: bool = True):
        self.id0: int = id0
        self.id1: int = id1

        # --- Private State Properties ---
        self.position: Dict[str, float] = {"x": 0.0, "y": 0.0}
        self.velocity: Dict[str, float] = {"x": 0.0, "y": 0.0}
        self.rotation: float = 0.0  # in radians

        # --- Configuration (set at creation) ---
        self.body_type: int = 0  # 0=dynamic, 1=static, 2=kinematic
        self.shape_type: int = 0  # 0=box, 1=circle
        self.mass: float = 1.0
        self.friction: float = 0.5
        self.elasticity: float = 0.5
        self.width: float = 1.0
        self.height: float = 1.0

        self.dirty_flags: Dict[str, bool] = {}
        self.is_new: bool = is_new

    # --- Configuration Setters (for initialization) ---

    def set_config(
        self,
        body_type: int,
        shape_type: int,
        mass: float,
        friction: float,
        elasticity: float,
    ) -> None:
        """Set the core physics properties."""
        self.body_type = body_type
        self.shape_type = shape_type
        self.mass = mass
        self.friction = friction
        self.elasticity = elasticity

    def set_shape(self, width: float, height: float) -> None:
        """
        Set the shape dimensions.
        :param width: For Box: width. For Circle: radius.
        :param height: For Box: height. For Circle: ignored.
        """
        self.width = width
        self.height = height

    # --- State Setters (with Dirty Tracking) ---

    def set_position(self, x: float, y: float, notify_engine: bool = True) -> None:
        if self.position["x"] != x or self.position["y"] != y:
            self.position["x"] = x
            self.position["y"] = y
            if notify_engine:
                self.dirty_flags["position"] = True

    def set_velocity(self, x: float, y: float, notify_engine: bool = True) -> None:
        if self.velocity["x"] != x or self.velocity["y"] != y:
            self.velocity["x"] = x
            self.velocity["y"] = y
            if notify_engine:
                self.dirty_flags["velocity"] = True

    def set_rotation(self, angle_in_radians: float, notify_engine: bool = True) -> None:
        if self.rotation != angle_in_radians:
            self.rotation = angle_in_radians
            if notify_engine:
                self.dirty_flags["rotation"] = True

    # --- Immediate Event Methods (No Dirty Flags) ---

    def apply_force(
        self, packer: CommandPacker, force_x: float, force_y: float
    ) -> None:
        packer.add(
            Events.PHYSICS_APPLY_FORCE,
            [self.id0, self.id1, force_x, force_y],
        )

    def apply_impulse(
        self, packer: CommandPacker, impulse_x: float, impulse_y: float
    ) -> None:
        packer.add(
            Events.PHYSICS_APPLY_IMPULSE,
            [self.id0, self.id1, impulse_x, impulse_y],
        )

    def remove(self, packer: CommandPacker) -> None:
        packer.add(Events.PHYSICS_REMOVE_BODY, [self.id0, self.id1])

    def _get_initial_add_data(self) -> List[Any]:
        return [
            self.id0,
            self.id1,
            self.position["x"],
            self.position["y"],
            self.body_type,
            self.shape_type,
            # 6 bytes padding are handled by the CommandPacker's struct format
            self.mass,
            self.friction,
            self.elasticity,
            self.width,
            self.height,
        ]

    def pack_dirty_events(self, packer: CommandPacker) -> None:
        if self.is_new:
            # Send the full ADD_BODY event
            packer.add(Events.PHYSICS_ADD_BODY, self._get_initial_add_data())

            # If velocity was set before creation, send it immediately after.
            # This is common for projectiles.
            if self.velocity["x"] != 0.0 or self.velocity["y"] != 0.0:
                packer.add(
                    Events.PHYSICS_SET_VELOCITY,
                    [self.id0, self.id1, self.velocity["x"], self.velocity["y"]],
                )

            self.is_new = False
            self.clear_dirty_flags()
            return

        if not self.dirty_flags:
            return

        if "position" in self.dirty_flags:
            packer.add(
                Events.PHYSICS_SET_POSITION,
                [self.id0, self.id1, self.position["x"], self.position["y"]],
            )

        if "velocity" in self.dirty_flags:
            packer.add(
                Events.PHYSICS_SET_VELOCITY,
                [self.id0, self.id1, self.velocity["x"], self.velocity["y"]],
            )

        if "rotation" in self.dirty_flags:
            packer.add(
                Events.PHYSICS_SET_ROTATION,
                [self.id0, self.id1, self.rotation],
            )

        self.clear_dirty_flags()

    def clear_dirty_flags(self) -> None:
        self.dirty_flags = {}
