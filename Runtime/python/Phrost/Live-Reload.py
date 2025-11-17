import os
import pathlib
import sys
from typing import Any, Callable, Dict, NoReturn, Optional

from ChannelPacker import ChannelPacker
from Channels import Channels
from Events import Events

# This is the path used in poll() which is relative to this file
# (equivalent to __DIR__ . "/../save.data")
_HARDCODED_SAVE_PATH = pathlib.Path(__file__).parent / "../save.data"


class LiveReload:
    def __init__(
        self,
        shutdown_flag_path: str,
        save_path: str,
        # --- ADD THESE ARGUMENTS ---
        # We type-hint 'Callable' which is Python's way of saying 'function'
        wake_func: Callable[[bytes], None],
        sleep_func: Callable[[], bytes],
    ):
        self.shutdown_flag_path: Optional[str] = shutdown_flag_path
        self.save_path: Optional[str] = save_path
        self.reset_pending: bool = False

        # --- STORE THE FUNCTIONS ON SELF ---
        self.phrost_wake = wake_func
        self.phrost_sleep = sleep_func

    def set_paths(self, shutdown_flag_path: str, save_path: str):
        """
        Re-injects paths after potential un-pickling (unserialization).
        """
        self.shutdown_flag_path = shutdown_flag_path
        self.save_path = save_path

    def is_reset_pending(self) -> bool:
        return self.reset_pending

    def poll(self, is_loaded: bool = False):
        # This logic uses a hard-coded path, matching the PHP file
        if not is_loaded and os.path.isfile(_HARDCODED_SAVE_PATH):
            try:
                with open(_HARDCODED_SAVE_PATH, "rb") as f:
                    save_content = f.read()

                # Check if content was read successfully AND is not empty
                if save_content:
                    self.phrost_wake(save_content)
                else:
                    print("Save.data file was empty. Starting fresh.")
                    # Delete the bad file so we don't try again
                    os.remove(_HARDCODED_SAVE_PATH)

            except IOError as e:
                print(f"Save.data file was unreadable: {e}. Starting fresh.")
                try:
                    os.remove(_HARDCODED_SAVE_PATH)
                except OSError:
                    pass  # Failed to delete, but we'll proceed anyway

        if self.shutdown_flag_path and os.path.isfile(self.shutdown_flag_path):
            # Read the flag's content (e.g., "reset" or "save")
            try:
                with open(self.shutdown_flag_path, "r") as f:
                    flag_content = f.read().strip()
            except IOError:
                flag_content = ""  # Treat as "save" if unreadable

            # Delete the flag *immediately* so we don't loop
            try:
                os.remove(self.shutdown_flag_path)
            except OSError as e:
                print(f"Warning: Could not delete shutdown flag: {e}")

            if flag_content == "reset":
                print("Hard reset detected. Skipping save and unloading.")
                # We just exit to force a reload. The *next* load will be clean
                # because reset() already deleted save.data.
                print("unloading")  # <-- THIS IS THE FIX
                sys.exit(0)  # Use sys.exit(0) for a clean exit
            else:
                # Flag was empty, "save", or anything else:
                print("Saving state before unloading...")
                if self.save_path:
                    try:
                        save_data = self.phrost_sleep()
                        with open(self.save_path, "wb") as f:
                            f.write(save_data)
                    except IOError as e:
                        print(f"Error writing save file: {e}")

                # This is the magic string the engine needs to see
                print("unloading")
                sys.exit(0)

    def reset_on_event(self, event: Dict[str, int], keycode: int, mod: int):
        """
        Triggers on matching event, the reset of world data
        """
        if event.get("keycode") == keycode and (event.get("mod", 0) & mod):
            print("Hard Reset Triggered! Pending for next frame.")
            self.reset_pending = True

    def reset(self, world: Dict[str, Any], packer: ChannelPacker):
        # Unload sprites and bodies before reset.
        for sprite_id, sprite in world.get("sprites", {}).items():
            packer.add(
                Channels.RENDERER.value,
                Events.SPRITE_REMOVE,
                [sprite.id0, sprite.id1],
            )

        for physics_body_id, physics_body in world.get("physicsBodies", {}).items():
            packer.add(
                Channels.PHYSICS.value,
                Events.PHYSICS_REMOVE_BODY,
                [physics_body.id0, physics_body.id1],
            )

        # This method uses the configurable self.save_path
        if self.save_path and os.path.isfile(self.save_path):
            try:
                os.remove(self.save_path)
            except OSError as e:
                print(f"Could not remove save file: {e}")

        # Create the shutdown flag with "reset" content
        if self.shutdown_flag_path:
            try:
                with open(self.shutdown_flag_path, "w") as f:
                    f.write("reset")
            except IOError as e:
                print(f"Could not write reset flag: {e}")

        # We are no longer pending
        self.reset_pending = False

    def shutdown_on_event(self, event: Dict[str, int], keycode: int, mod: int):
        """
        Triggers on matching event, the shutdown of game engine
        """
        if event.get("keycode") == keycode and (event.get("mod", 0) & mod):
            print("Shutting down")
            self.shutdown()

    def shutdown(self) -> NoReturn:
        """
        Hard coded value to trigger shutdown from outside process
        """
        sys.exit(10)
