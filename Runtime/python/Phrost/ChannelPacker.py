import struct
from enum import IntEnum
from typing import Any, Dict, List

from Events import Events


class CommandPacker:
    """
    A stub implementation of CommandPacker, based on its implied
    interface in ChannelPacker.

    A real CommandPacker would pack individual events into a binary format.
    This stub just tracks event count and returns a simple blob.
    """

    def __init__(self, chunk_size: int):
        # chunk_size is 0 in the ChannelPacker, implying buffering is disabled.
        self.chunk_size = chunk_size
        self.events: List[tuple[Events, List[Any]]] = []

    def add(self, event_type: Events, data: List[Any]):
        """Adds an event to be packed."""
        # A real implementation would pack this into an internal buffer.
        self.events.append((event_type, data))

    def finalize(self) -> bytes:
        """
        Finalizes the packet.

        The PHP code implies this returns a complete binary blob for one channel,
        which starts with its own event count.
        """
        event_count = len(self.events)

        # Create a dummy blob: [Event Count (u32)] + [dummy data]
        # A real implementation would serialize all events from self.events.
        # We use '<I' for unsigned 32-bit little-endian, same as PHP's 'V'.
        dummy_event_data = b"EVENT_STUB" * event_count
        output = struct.pack("<I", event_count) + dummy_event_data

        # Clear events for reuse
        self.events = []
        return output

    def get_total_event_count(self) -> int:
        """Gets the total number of buffered events."""
        return len(self.events)


# --- End of Stubbed Dependencies ---


# --- Main Translation from ChannelPacker.php ---


class Channels(IntEnum):
    """Equivalent to the 'Channels' enum in PHP."""

    RENDERER = 0
    INPUT = 1
    PHYSICS = 2
    AUDIO = 3
    GUI = 4
    WINDOW = 5
    SCRIPT = 6


class ChannelPacker:
    """
    Manages packing events into multiple "channels".

    This class contains multiple CommandPacker instances, one for each channel.
    When finalized, it produces a single binary blob structured as:

    1. Channel Count (u32)
    2. Index Table   [Channel ID (u32), Channel Size (u32)] * N
    3. Data Blobs    [Channel 0 Data]...[Channel N Data]

    Each "Channel Data" blob is the complete output from a single CommandPacker
    (i.e., it starts with its own internal event count).
    """

    def __init__(self):
        """
        Initializes the ChannelPacker.
        """
        # Stores the individual packer for each channel.
        self.channel_packers: Dict[int, CommandPacker] = {}

    def add(self, channel_id: int, event_type: Events, data: List[Any]):
        """
        Adds an event to a specific channel.

        If the channel doesn't exist, a new CommandPacker is created for it.

        Args:
            channel_id: The channel to add this event to (e.g., Channels.RENDERER.value).
            event_type: The event type (from the Events enum).
            data: The event data.
        """
        if channel_id not in self.channel_packers:
            # Create a new packer for this channel.
            # We set chunk_size to 0 to disable internal buffering
            # in CommandPacker, as ChannelPacker handles the final flush.
            self.channel_packers[channel_id] = CommandPacker(0)

        self.channel_packers[channel_id].add(event_type, data)

    def finalize(self) -> bytes:
        """
        Finalizes all channel packers and combines them into a single binary blob
        prefixed with the channel index.

        Returns:
            The complete binary blob as bytes.
        """
        if not self.channel_packers:
            return b""

        # Sort by channel ID to ensure a consistent order (like PHP's ksort)
        sorted_channel_ids = sorted(self.channel_packers.keys())

        index_table = bytearray()
        data_blobs = bytearray()
        channel_count = len(self.channel_packers)

        for channel_id in sorted_channel_ids:
            packer = self.channel_packers[channel_id]

            # Get the finalized blob for this channel (starts with its own event count)
            channel_blob = packer.finalize()
            channel_size = len(channel_blob)  # equiv. to PHP's strlen() on binary

            # Add to the index table: [Channel ID (u32), Channel Size (u32)]
            # '<II' is two unsigned 32-bit little-endian integers (equiv. to "VV" in PHP)
            index_table += struct.pack("<II", channel_id, channel_size)

            # Add this channel's data to the main data blob
            data_blobs += channel_blob

        # 1. Pack the total number of channels
        # '<I' is one unsigned 32-bit little-endian integer (equiv. to "V" in PHP)
        output = bytearray(struct.pack("<I", channel_count))
        # 2. Append the index table
        output += index_table
        # 3. Append the concatenated data blobs
        output += data_blobs

        # Clear the packers for reuse
        self.channel_packers = {}

        return bytes(output)

    def get_total_event_count(self) -> int:
        """
        Gets the total number of events buffered across all channels.
        """
        total = 0
        for packer in self.channel_packers.values():
            total += packer.get_total_event_count()
        return total
