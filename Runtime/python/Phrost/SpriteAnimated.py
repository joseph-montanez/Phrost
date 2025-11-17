import sys
from typing import Any, Dict, List, Optional

# Imports from your existing adapter file
# (Assuming it's saved as Phrost.py)
try:
    from Phrost import CommandPacker, Events
except ImportError:
    print(
        "Could not import CommandPacker/Events. Please ensure Phrost.py is in the same directory.",
        file=sys.stderr,
    )

# Import the base Sprite class from the file you provided
try:
    from Sprite import Sprite
except ImportError:
    print(
        "Could not import Sprite. Please ensure Sprite.py is in the same directory.",
        file=sys.stderr,
    )


class SpriteAnimated(Sprite):
    """
    Manages an Animated Sprite entity.

    Extends Sprite to inherit all properties (position, color, etc.)
    and adds logic to automatically update the source rectangle
    over time based on defined animations.
    """

    def __init__(self, id0: int, id1: int, is_new: bool = True):
        # Call the parent Sprite's constructor
        super().__init__(id0, id1, is_new)

        # --- Animation-specific properties ---
        self.animations: Dict[str, List[Dict[str, Any]]] = {}
        self.current_animation_name: Optional[str] = None
        self.current_frame_index: int = 0
        self.frame_timer: float = 0.0
        self.loops: bool = True
        self.is_playing: bool = False
        self.animation_speed: float = 1.0  # 1.0 = normal, 2.0 = double

    @staticmethod
    def generate_fixed_frames(
        start_x: int,
        start_y: int,
        frame_width: int,
        frame_height: int,
        frame_count: int,
        duration_per_frame: float,
        columns: int,
        padding_x: int = 0,
        padding_y: int = 0,
    ) -> List[Dict[str, Any]]:
        """
        Generates a frame list for a fixed-grid spritesheet.
        """
        frames: List[Dict[str, Any]] = []
        for i in range(frame_count):
            # Use integer division // (like floor())
            col = i % columns
            row = i // columns

            frames.append(
                {
                    "x": start_x + col * (frame_width + padding_x),
                    "y": start_y + row * (frame_height + padding_y),
                    "w": frame_width,
                    "h": frame_height,
                    "duration": duration_per_frame,
                }
            )
        return frames

    def add_animation(self, name: str, frames: List[Dict[str, Any]]) -> None:
        """
        Adds a new animation definition.
        'frames' is a list of dicts:
        [{'x': 0, 'y': 0, 'w': 32, 'h': 32, 'duration': 0.1}, ...]
        """
        self.animations[name] = frames

    def play(self, name: str, loops: bool = True, force_restart: bool = False) -> None:
        """
        Plays a defined animation.
        """
        if name not in self.animations:
            print(f"AnimatedSprite: Unknown animation '{name}'", file=sys.stderr)
            return

        if (
            not force_restart
            and self.current_animation_name == name
            and self.is_playing
        ):
            return  # Already playing this

        self.current_animation_name = name
        self.loops = loops
        self.is_playing = True
        self.frame_timer = 0.0
        self.current_frame_index = 0

        # Immediately apply the first frame
        self._apply_frame(self.current_frame_index)

    def stop(self) -> None:
        """Stops the animation, holding on the current frame."""
        self.is_playing = False

    def resume(self) -> None:
        """Resumes the animation from the current frame."""
        if self.current_animation_name:
            self.is_playing = True

    def set_animation_speed(self, speed: float) -> None:
        """
        Sets the playback speed multiplier.
        1.0 is normal, 2.0 is double speed, 0.5 is half speed.
        """
        self.animation_speed = max(0.01, speed)  # Avoid division by zero

    def update(self, dt: float) -> None:
        """
        Updates the animation state.
        This should be called every frame from your main game loop.
        """
        # First, call the parent update to handle movement
        super().update(dt)

        if (
            not self.is_playing
            or not self.current_animation_name
            or self.current_animation_name not in self.animations
        ):
            return

        animation = self.animations[self.current_animation_name]
        if not animation:  # Check if animation is empty
            return

        frame = animation[self.current_frame_index]

        # Get the frame's duration, adjusted by the animation speed
        duration = frame["duration"] / self.animation_speed

        # Add this frame's delta time
        self.frame_timer += dt

        # Time to advance to the next frame?
        if self.frame_timer >= duration:
            # Carry over any excess time
            self.frame_timer -= duration

            next_frame_index = self.current_frame_index + 1

            # Check if we've reached the end of the animation
            if next_frame_index >= len(animation):
                if self.loops:
                    next_frame_index = 0  # Loop back to start
                else:
                    next_frame_index = self.current_frame_index  # Stay on last
                    self.is_playing = False

            # If the frame changed, apply it
            if next_frame_index != self.current_frame_index:
                self.current_frame_index = next_frame_index
                self._apply_frame(self.current_frame_index)

    def _apply_frame(self, frame_index: int) -> None:
        """
        Internal helper to apply a frame's source rect.
        (Marked with _ as a "protected" method)
        """
        animation_name = self.current_animation_name
        if not animation_name or animation_name not in self.animations:
            return

        animation = self.animations[animation_name]
        if not (0 <= frame_index < len(animation)):
            return  # Frame index is out of bounds

        frame = animation[frame_index]

        # Use the parent Sprite's method. This will automatically
        # set the 'source_rect' dirty flag!
        self.set_source_rect(
            frame["x"],
            frame["y"],
            frame["w"],
            frame["h"],
        )
