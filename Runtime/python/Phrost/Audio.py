import enum
from typing import Dict, Optional

# Imports from your existing adapter file
try:
    from Phrost import CommandPacker, Events
except ImportError:
    print(
        "Could not import CommandPacker/Events. Please ensure Phrost.py is in the same directory."
    )


class Audio:
    """
    Manages a single Audio track using a "retained mode" state.

    This class tracks its own state and generates a list of commands
    when pack_dirty_events() is called.
    """

    def __init__(self, path: str, initial_volume: float = 1.0):
        """
        :param path: The absolute path to the audio file.
        :param initial_volume: The initial volume (0.0 to 1.0).
        """
        self.path: str = path
        self.audio_id: Optional[int] = None  # This is the u64 ID from the engine
        self.is_loaded: bool = False

        # Flag to track if the initial AUDIO_LOAD command has been sent.
        self.load_command_sent: bool = False

        self.volume: float = initial_volume

        # Stores which properties have changed since the last event pack.
        self.dirty_flags: Dict[str, bool] = {}

    def set_loaded_id(self, audio_id: int) -> None:
        """
        Call this when you receive the AUDIO_LOADED event from the engine
        to notify this object of its engine-side ID.
        """
        self.audio_id = audio_id
        self.is_loaded = True

        # If volume was set before loading was confirmed,
        # flag it as dirty to sync with the engine.
        if self.volume != 1.0:
            self.dirty_flags["volume"] = True

    def isLoaded(self) -> bool:
        return self.is_loaded

    def get_audio_id(self) -> Optional[int]:
        return self.audio_id

    def get_volume(self) -> float:
        return self.volume

    # --- State-Changing Methods (with dirty tracking) ---

    def load(self, notify_engine: bool = True) -> None:
        """
        Queues this audio file to be loaded by the engine.
        This only needs to be called once.
        """
        if not self.load_command_sent:
            if notify_engine:
                self.dirty_flags["load"] = True
            # Set this immediately to prevent multiple load commands
            self.load_command_sent = True

    def play(self, notify_engine: bool = True) -> None:
        """Queues a command to play this audio."""
        if self.is_loaded and notify_engine:
            self.dirty_flags["play"] = True
            # Play overrides pause and stop
            self.dirty_flags.pop("pause", None)
            self.dirty_flags.pop("stop", None)
        elif not self.load_command_sent:
            # Auto-load if play is called before load
            self.load(notify_engine)

    def pause(self, notify_engine: bool = True) -> None:
        """Queues a command to pause this audio."""
        if self.is_loaded and notify_engine:
            self.dirty_flags["pause"] = True
            # Pause overrides play and stop
            self.dirty_flags.pop("play", None)
            self.dirty_flags.pop("stop", None)

    def stop(self, notify_engine: bool = True) -> None:
        """Queues a command to stop and rewind this audio."""
        if self.is_loaded and notify_engine:
            self.dirty_flags["stop"] = True
            # Stop overrides play and pause
            self.dirty_flags.pop("play", None)
            self.dirty_flags.pop("pause", None)

    def set_volume(self, volume: float, notify_engine: bool = True) -> None:
        """
        Queues a command to set the volume for this specific sound.
        :param volume: Volume level (e.g., 0.0 to 1.0)
        """
        new_volume = max(0.0, volume)
        if self.volume != new_volume:
            self.volume = new_volume
            # Only flag if loaded; set_loaded_id handles the pre-load case
            if self.is_loaded and notify_engine:
                self.dirty_flags["volume"] = True

    def unload(self, notify_engine: bool = True) -> None:
        """
        Queues a command to unload this audio, freeing engine memory.
        Resets this object's state.
        """
        if self.is_loaded:
            if notify_engine:
                self.dirty_flags["unload"] = True

        # Reset the local state regardless of notify_engine
        self.is_loaded = False
        self.load_command_sent = False  # Can be loaded again
        self.audio_id = None
        self.volume = 1.0  # Reset to default

    # --- Packing and Global Controls ---

    def pack_dirty_events(self, packer: CommandPacker, clear: bool = True) -> None:
        """
        Checks all dirty flags and adds the corresponding events
        to the CommandPacker.
        """
        if not self.dirty_flags:
            return  # Nothing to do

        # Handle Unload first, as it invalidates all other commands
        if "unload" in self.dirty_flags:
            packer.add(Events.AUDIO_UNLOAD, [self.audio_id])
            if clear:
                self.clear_dirty_flags()
            return  # Don't pack any other commands

        # Handle Load (only if not loaded)
        if "load" in self.dirty_flags:
            path_bytes = self.path.encode("utf-8")
            path_length = len(path_bytes)
            packer.add(Events.AUDIO_LOAD, [path_length, path_bytes])

        # Other commands only apply if the audio is loaded
        if not self.is_loaded:
            if clear:
                # Clear only the 'load' flag, keep others (like 'volume')
                self.dirty_flags.pop("load", None)
            return

        # Handle play/pause/stop (mutually exclusive)
        if "stop" in self.dirty_flags:
            packer.add(Events.AUDIO_STOP, [self.audio_id])
        elif "pause" in self.dirty_flags:
            packer.add(Events.AUDIO_PAUSE, [self.audio_id])
        elif "play" in self.dirty_flags:
            packer.add(Events.AUDIO_PLAY, [self.audio_id])

        # Handle volume
        if "volume" in self.dirty_flags:
            packer.add(Events.AUDIO_SET_VOLUME, [self.audio_id, self.volume])

        if clear:
            self.clear_dirty_flags()

    def clear_dirty_flags(self) -> None:
        self.dirty_flags = {}

    # --- Static methods for global audio controls (Immediate Mode) ---

    @staticmethod
    def stopAll(packer: CommandPacker) -> None:
        """Stops all currently playing audio."""
        packer.add(Events.AUDIO_STOP_ALL, [])

    @staticmethod
    def set_master_volume(packer: CommandPacker, volume: float) -> None:
        """
        Sets the master volume for all audio.
        :param volume: (e.g., 0.0 to 1.0)
        """
        packer.add(Events.AUDIO_SET_MASTER_VOLUME, [volume])
