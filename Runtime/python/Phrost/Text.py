import enum
import sys
from typing import Any, List

# Import from other converted files
from Sprite import Sprite

# Imports from your existing adapter file
# (Assuming it's saved as phrost_adapter.py)
try:
    from Phrost import CommandPacker, Events
except ImportError:
    print(
        "Could not import CommandPacker/Events. Please ensure phrost_adapter.py is in the same directory."
    )

    # Define dummy classes for the script to be syntactically valid
    class CommandPacker:
        def add(self, event_type, data):
            pass

    class Events(enum.IntEnum):
        TEXT_ADD = 300
        TEXT_SET_STRING = 301


class Text(Sprite):
    """
    Manages a Text entity.

    Extends Sprite to inherit properties like position, color, and scale,
    but overrides the event packing to send Text-specific events.
    """

    def __init__(self, id0: int, id1: int, is_new: bool = True):
        # We force the parent 'isNew' to False to *never* send SPRITE_ADD
        super().__init__(id0, id1, is_new=False)

        # --- Private Text State ---
        self.text_string: str = ""
        self.font_path: str = ""
        self.font_size: float = 12.0

        # We use a separate 'is_new' flag to control TEXT_ADD
        self.is_new_text: bool = is_new

    def set_text(self, text: str, notify_engine: bool = True) -> None:
        """Sets the text string and marks it as dirty."""
        if self.text_string != text:
            self.text_string = text
            if notify_engine:
                self.dirty_flags["text"] = True

    def set_font(self, font_path: str, font_size: float) -> None:
        """
        Sets the font properties.
        NOTE: Based on available events, font and size can only be set at creation.
        """
        self.font_path = font_path
        self.font_size = font_size

    def get_text(self) -> str:
        return self.text_string

    def get_initial_add_data(self) -> List[Any]:
        """
        Generates the data array for the initial TEXT_ADD event.
        The packer expects strings to be pre-encoded bytes.
        """
        position = self.get_position()
        color = self.get_color()

        font_path_bytes = self.font_path.encode("utf-8")
        text_bytes = self.text_string.encode("utf-8")

        return [
            self.id0,
            self.id1,
            position["x"],
            position["y"],
            position["z"],
            color["r"],
            color["g"],
            color["b"],
            color["a"],
            self.font_size,
            len(font_path_bytes),  # fontPathLength
            len(text_bytes),  # textLength
            font_path_bytes,  # fontPath bytes
            text_bytes,  # text bytes
        ]

    def pack_dirty_events(self, packer: CommandPacker) -> None:
        """
        Overrides the parent pack_dirty_events.

        If new, it sends TEXT_ADD.
        If existing, it calls the parent's packer (to handle move, color, etc.)
        and then packs its own text-specific updates.
        """
        if self.is_new_text:
            if not self.font_path:
                print(
                    "Phrost.Text: Cannot pack TEXT_ADD event, no font path was set.",
                    file=sys.stderr,
                )
                return

            # Send the full TEXT_ADD event
            packer.add(Events.TEXT_ADD, self.get_initial_add_data())

            # Mark as no longer new and clear all other flags
            self.is_new_text = False
            self.clear_dirty_flags()
            return  # Exit

        # Pack parent events (move, color, scale, etc.)
        # The parent's pack_dirty_events will also call clear_dirty_flags()
        # for the flags it has processed.
        super().pack_dirty_events(packer, clear=False)

        # Pack text-specific events
        if "text" in self.dirty_flags:
            text_bytes = self.text_string.encode("utf-8")
            text_length = len(text_bytes)

            packer.add(
                Events.TEXT_SET_STRING,
                [
                    self.id0,
                    self.id1,
                    text_length,
                    text_bytes,  # Pass bytes
                ],
            )

        # Clear all flags *again* to catch any child-specific flags.
        # This is safe even if parent already cleared some.
        self.clear_dirty_flags()
