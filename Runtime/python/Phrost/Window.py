import enum
from typing import Any, Dict

# Import from other converted files
from WindowFlags import WindowFlags

# Imports from your existing adapter file
# (Assuming it's saved as phrost_adapter.py)
try:
    from Phrost import CommandPacker, Events
except ImportError:
    print(
        "Could not import CommandPacker/Events. Please ensure phrost_adapter.py is in the same directory."
    )


class Window:
    def __init__(self, title: str, width: int, height: int):
        # --- Private State Properties ---
        self.title: str = title
        self.size: Dict[str, int] = {"width": width, "height": height}

        # Stores the boolean state of all flags.
        self.flags: Dict[str, bool] = {
            "fullscreen": False,
            "opengl": False,
            "occluded": False,
            "hidden": False,
            "borderless": False,
            "resizable": False,
            "minimized": False,
            "maximized": False,
            "mouse_grabbed": False,
            "input_focus": False,
            "mouse_focus": False,
            "external": False,
            "modal": False,
            "high_pixel_density": False,
            "mouse_capture": False,
            "mouse_relative_mode": False,
            "always_on_top": False,
            "utility": False,
            "tooltip": False,
            "popup_menu": False,
            "keyboard_grabbed": False,
            "vulkan": False,
            "metal": False,
            "transparent": False,
            "not_focusable": False,
        }

        # Stores which properties have changed.
        self.dirty_flags: Dict[str, bool] = {}
        # Flag to track if this is the first update
        self.is_new: bool = True

    # --- Setters (with Dirty Tracking) ---

    def set_title(self, new_title: str, notify_engine: bool = True) -> None:
        if self.title != new_title:
            self.title = new_title
            if notify_engine:
                self.dirty_flags["title"] = True

    def set_size(self, width: int, height: int, notify_engine: bool = True) -> None:
        if self.size["width"] != width or self.size["height"] != height:
            self.size["width"] = width
            self.size["height"] = height
            if notify_engine:
                self.dirty_flags["resize"] = True

    # --- Flag Setters (Examples) ---

    def set_resizable(self, enabled: bool, notify_engine: bool = True) -> None:
        if self.flags["resizable"] != enabled:
            self.flags["resizable"] = enabled
            if notify_engine:
                self.dirty_flags["flags"] = True

    def set_fullscreen(self, enabled: bool, notify_engine: bool = True) -> None:
        if self.flags["fullscreen"] != enabled:
            self.flags["fullscreen"] = enabled
            if notify_engine:
                self.dirty_flags["flags"] = True

    def set_borderless(self, enabled: bool, notify_engine: bool = True) -> None:
        if self.flags["borderless"] != enabled:
            self.flags["borderless"] = enabled
            if notify_engine:
                self.dirty_flags["flags"] = True

    def set_hidden(self, enabled: bool, notify_engine: bool = True) -> None:
        if self.flags["hidden"] != enabled:
            self.flags["hidden"] = enabled
            if notify_engine:
                self.dirty_flags["flags"] = True

    def set_mouse_grabbed(self, enabled: bool, notify_engine: bool = True) -> None:
        if self.flags["mouse_grabbed"] != enabled:
            self.flags["mouse_grabbed"] = enabled
            if notify_engine:
                self.dirty_flags["flags"] = True

    def toggle_flag(self, flag_name: str, notify_engine: bool = True) -> None:
        """Generic setter to toggle any flag by its string name."""
        if flag_name in self.flags:
            self.flags[flag_name] = not self.flags[flag_name]
            if notify_engine:
                self.dirty_flags["flags"] = True

    def set_flag(
        self, flag_name: str, enabled: bool, notify_engine: bool = True
    ) -> None:
        """Generic setter to enable/disable any flag by its string name."""
        if flag_name in self.flags and self.flags[flag_name] != enabled:
            self.flags[flag_name] = enabled
            if notify_engine:
                self.dirty_flags["flags"] = True

    # --- Getters ---

    def get_title(self) -> str:
        return self.title

    def get_size(self) -> Dict[str, int]:
        return self.size

    def is_flag_enabled(self, flag_name: str) -> bool:
        return self.flags.get(flag_name, False)

    def _calculate_flags_bitmask(self) -> int:
        """Calculates the complete bitmask from all boolean flags."""
        mask = 0
        if self.flags["fullscreen"]:
            mask |= WindowFlags.FULLSCREEN
        if self.flags["opengl"]:
            mask |= WindowFlags.OPENGL
        if self.flags["occluded"]:
            mask |= WindowFlags.OCCLUDED
        if self.flags["hidden"]:
            mask |= WindowFlags.HIDDEN
        if self.flags["borderless"]:
            mask |= WindowFlags.BORDERLESS
        if self.flags["resizable"]:
            mask |= WindowFlags.RESIZABLE
        if self.flags["minimized"]:
            mask |= WindowFlags.MINIMIZED
        if self.flags["maximized"]:
            mask |= WindowFlags.MAXIMIZED
        if self.flags["mouse_grabbed"]:
            mask |= WindowFlags.MOUSE_GRABBED
        if self.flags["input_focus"]:
            mask |= WindowFlags.INPUT_FOCUS
        if self.flags["mouse_focus"]:
            mask |= WindowFlags.MOUSE_FOCUS
        if self.flags["external"]:
            mask |= WindowFlags.EXTERNAL
        if self.flags["modal"]:
            mask |= WindowFlags.MODAL
        if self.flags["high_pixel_density"]:
            mask |= WindowFlags.HIGH_PIXEL_DENSITY
        if self.flags["mouse_capture"]:
            mask |= WindowFlags.MOUSE_CAPTURE
        if self.flags["mouse_relative_mode"]:
            mask |= WindowFlags.MOUSE_RELATIVE_MODE
        if self.flags["always_on_top"]:
            mask |= WindowFlags.ALWAYS_ON_TOP
        if self.flags["utility"]:
            mask |= WindowFlags.UTILITY
        if self.flags["tooltip"]:
            mask |= WindowFlags.TOOLTIP
        if self.flags["popup_menu"]:
            mask |= WindowFlags.POPUP_MENU
        if self.flags["keyboard_grabbed"]:
            mask |= WindowFlags.KEYBOARD_GRABBED
        if self.flags["vulkan"]:
            mask |= WindowFlags.VULKAN
        if self.flags["metal"]:
            mask |= WindowFlags.METAL
        if self.flags["transparent"]:
            mask |= WindowFlags.TRANSPARENT
        if self.flags["not_focusable"]:
            mask |= WindowFlags.NOT_FOCUSABLE
        return mask

    # --- Event Generation ---

    def pack_dirty_events(self, packer: CommandPacker) -> None:
        # The packer's <256s format for WINDOW_TITLE requires bytes

        if self.is_new:
            # Send all initial state
            title_bytes = self.title.encode("utf-8")
            packer.add(Events.WINDOW_TITLE, [title_bytes])

            packer.add(
                Events.WINDOW_RESIZE,
                [
                    self.size["width"],
                    self.size["height"],
                ],
            )
            packer.add(
                Events.WINDOW_FLAGS,
                [
                    self._calculate_flags_bitmask(),
                ],
            )

            self.is_new = False
            self.clear_dirty_flags()
            return

        if not self.dirty_flags:
            return  # Nothing to do

        if "title" in self.dirty_flags:
            title_bytes = self.title.encode("utf-8")
            packer.add(Events.WINDOW_TITLE, [title_bytes])

        if "resize" in self.dirty_flags:
            packer.add(
                Events.WINDOW_RESIZE,
                [
                    self.size["width"],
                    self.size["height"],
                ],
            )

        if "flags" in self.dirty_flags:
            packer.add(
                Events.WINDOW_FLAGS,
                [
                    self._calculate_flags_bitmask(),
                ],
            )

        self.clear_dirty_flags()

    def clear_dirty_flags(self) -> None:
        self.dirty_flags = {}
