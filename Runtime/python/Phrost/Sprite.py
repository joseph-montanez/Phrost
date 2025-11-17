from typing import Any, Dict, List, Optional

from ChannelPacker import ChannelPacker
from Channels import Channels
from Events import Events


class Sprite:
    def __init__(self, id0: int, id1: int, is_new: bool = True):
        self.id0: int = id0
        self.id1: int = id1
        # readonly in Python is just a convention (prefix with _)
        # but for a direct port, we'll keep them public.

        self.position: Dict[str, float] = {"x": 0.0, "y": 0.0, "z": 0.0}
        self.size: Dict[str, float] = {"width": 1.0, "height": 1.0}
        self.color: Dict[str, int] = {"r": 255, "g": 255, "b": 255, "a": 255}
        self.texture_path: Optional[str] = None
        self.rotate: Dict[str, float] = {"x": 0.0, "y": 0.0, "z": 0.0}
        self.speed: Dict[str, float] = {"x": 0.0, "y": 0.0}
        self.scale: Dict[str, float] = {"x": 1.0, "y": 1.0, "z": 1.0}

        self.source_rect: Optional[Dict[str, float]] = None
        self.texture_id: int = 0

        # Stores which properties have changed since the last event pack.
        self.dirty_flags: Dict[str, bool] = {}
        # Flag to track if this sprite was just created.
        self.is_new: bool = is_new

    def update(self, dt: float) -> None:
        if self.speed["x"] == 0.0 and self.speed["y"] == 0.0:
            return
        self.set_position(
            self.position["x"] + self.speed["x"] * dt,
            self.position["y"] + self.speed["y"] * dt,
            self.position["z"],
        )

    def set_position(
        self, x: float, y: float, z: float, notify_engine: bool = True
    ) -> None:
        if (
            self.position["x"] != x
            or self.position["y"] != y
            or self.position["z"] != z
        ):
            self.position["x"] = x
            self.position["y"] = y
            self.position["z"] = z
            if notify_engine:
                self.dirty_flags["position"] = True

    def set_size(self, width: float, height: float, notify_engine: bool = True) -> None:
        if self.size["width"] != width or self.size["height"] != height:
            self.size["width"] = width
            self.size["height"] = height
            if notify_engine:
                self.dirty_flags["size"] = True

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

    def set_texture_path(self, path: str, notify_engine: bool = True) -> None:
        if self.texture_path != path:
            self.texture_path = path
            if notify_engine:
                self.dirty_flags["texture"] = True

    def set_rotate(
        self, x: float, y: float, z: float, notify_engine: bool = True
    ) -> None:
        if self.rotate["x"] != x or self.rotate["y"] != y or self.rotate["z"] != z:
            self.rotate["x"] = x
            self.rotate["y"] = y
            self.rotate["z"] = z
            if notify_engine:
                self.dirty_flags["rotate"] = True

    def set_speed(self, x: float, y: float, notify_engine: bool = True) -> None:
        if self.speed["x"] != x or self.speed["y"] != y:
            self.speed["x"] = x
            self.speed["y"] = y
            if notify_engine:
                self.dirty_flags["speed"] = True

    def set_scale(
        self, x: float, y: float, z: float, notify_engine: bool = True
    ) -> None:
        if self.scale["x"] != x or self.scale["y"] != y or self.scale["z"] != z:
            self.scale["x"] = x
            self.scale["y"] = y
            self.scale["z"] = z
            if notify_engine:
                self.dirty_flags["scale"] = True

    def set_flip(self, is_flipped: bool, notify_engine: bool = True) -> None:
        """
        Sets the horizontal flip state of the sprite by modifying its X scale.
        """
        # Get the current absolute X scale
        current_abs_scale_x = abs(self.scale["x"])

        # Determine the new X scale
        new_scale_x = -current_abs_scale_x if is_flipped else current_abs_scale_x

        # Use the existing set_scale method to apply the change
        # This will automatically handle the dirty flag
        self.set_scale(
            new_scale_x,
            self.scale["y"],
            self.scale["z"],
            notify_engine,
        )

    def set_source_rect(
        self, x: float, y: float, w: float, h: float, notify_engine: bool = True
    ) -> None:
        """Sets the source rectangle for texture mapping."""
        new_rect = {"x": x, "y": y, "w": w, "h": h}
        if self.source_rect != new_rect:
            self.source_rect = new_rect
            if notify_engine:
                self.dirty_flags["source_rect"] = True

    def set_texture_id(self, texture_id: int) -> None:
        self.texture_id = texture_id

    # --- Getters (for reading state) ---
    def get_position(self) -> Dict[str, float]:
        return self.position

    def get_speed(self) -> Dict[str, float]:
        return self.speed

    def get_scale(self) -> Dict[str, float]:
        return self.scale

    def get_rotation(self) -> Dict[str, float]:
        return self.rotate

    def get_color(self) -> Dict[str, int]:
        return self.color

    def get_id(self) -> List[int]:
        return [self.id0, self.id1]

    def get_texture_id(self) -> int:
        return self.texture_id

    def get_source_rect(self) -> Optional[Dict[str, float]]:
        """Gets the source rectangle for texture mapping."""
        return self.source_rect

    def get_initial_add_data(self) -> List[Any]:
        """Generates the data array for the initial SPRITE_ADD event."""
        return [
            self.id0,
            self.id1,
            self.position["x"],
            self.position["y"],
            self.position["z"],
            self.scale["x"],
            self.scale["y"],
            self.scale["z"],
            self.size["width"],
            self.size["height"],
            self.rotate["x"],
            self.rotate["y"],
            self.rotate["z"],
            self.color["r"],
            self.color["g"],
            self.color["b"],
            self.color["a"],
            self.speed["x"],
            self.speed["y"],
        ]

    # --- THIS METHOD IS NOW CORRECTED ---
    def pack_dirty_events(self, packer: ChannelPacker, clear=True) -> None:
        """
        Checks all dirty flags and adds the corresponding events
        to the ChannelPacker.
        """
        # --- All 'packer.add' calls now include the Channel ID ---
        RENDER_CHANNEL = Channels.RENDERER.value

        if self.is_new:
            # Send the full SPRITE_ADD event
            packer.add(RENDER_CHANNEL, Events.SPRITE_ADD, self.get_initial_add_data())

            # Also send the texture load event if a texture was set
            if self.texture_path is not None:
                filename_bytes = self.texture_path.encode("utf-8")
                filename_length = len(filename_bytes)
                packer.add(
                    RENDER_CHANNEL,
                    Events.SPRITE_TEXTURE_LOAD,
                    [
                        self.id0,
                        self.id1,
                        filename_length,
                        filename_bytes,  # Pass bytes
                    ],
                )

            # Also send source rect if it was set during initialization
            if self.source_rect is not None:
                packer.add(
                    RENDER_CHANNEL,
                    Events.SPRITE_SET_SOURCE_RECT,
                    [
                        self.id0,
                        self.id1,
                        self.source_rect["x"],
                        self.source_rect["y"],
                        self.source_rect["w"],
                        self.source_rect["h"],
                    ],
                )

            # Mark as no longer new and clear all other flags
            self.is_new = False
            self.clear_dirty_flags()
            return  # Exit

        # --- REGULAR DIRTY CHECK ---
        if not self.dirty_flags:
            return  # Nothing to do

        if "position" in self.dirty_flags:
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_MOVE,
                [
                    self.id0,
                    self.id1,
                    self.position["x"],
                    self.position["y"],
                    self.position["z"],
                ],
            )

        if "scale" in self.dirty_flags:
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_SCALE,
                [
                    self.id0,
                    self.id1,
                    self.scale["x"],
                    self.scale["y"],
                    self.scale["z"],
                ],
            )

        if "size" in self.dirty_flags:
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_RESIZE,
                [
                    self.id0,
                    self.id1,
                    self.size["width"],
                    self.size["height"],
                ],
            )

        if "rotate" in self.dirty_flags:
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_ROTATE,
                [
                    self.id0,
                    self.id1,
                    self.rotate["x"],
                    self.rotate["y"],
                    self.rotate["z"],
                ],
            )

        if "color" in self.dirty_flags:
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_COLOR,
                [
                    self.id0,
                    self.id1,
                    self.color["r"],
                    self.color["g"],
                    self.color["b"],
                    self.color["a"],
                ],
            )

        if "speed" in self.dirty_flags:
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_SPEED,
                [
                    self.id0,
                    self.id1,
                    self.speed["x"],
                    self.speed["y"],
                ],
            )

        if "texture" in self.dirty_flags:
            filename = self.texture_path or ""
            filename_bytes = filename.encode("utf-8")
            filename_length = len(filename_bytes)
            packer.add(
                RENDER_CHANNEL,
                Events.SPRITE_TEXTURE_LOAD,
                [
                    self.id0,
                    self.id1,
                    filename_length,
                    filename_bytes,  # Pass bytes
                ],
            )

        if "source_rect" in self.dirty_flags:
            if self.source_rect is not None:
                packer.add(
                    RENDER_CHANNEL,
                    Events.SPRITE_SET_SOURCE_RECT,
                    [
                        self.id0,
                        self.id1,
                        self.source_rect["x"],
                        self.source_rect["y"],
                        self.source_rect["w"],
                        self.source_rect["h"],
                    ],
                )

        if clear:
            self.clear_dirty_flags()

    def clear_dirty_flags(self) -> None:
        self.dirty_flags = {}
