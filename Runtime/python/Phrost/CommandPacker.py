import struct
import sys
from typing import Any, Callable, Dict, List, Optional

from Events import Events
from PackFormat import PackFormat


# --- CommandPacker Class ---
class CommandPacker:
    def __init__(self, chunk_size: int = 0, chunk_callback: Optional[Callable] = None):
        self._event_stream = bytearray()
        self._command_count = 0
        self._event_buffer: List[Dict[str, Any]] = []
        self._chunk_size = chunk_size
        self._chunk_callback = chunk_callback

    def add(self, event_type: Events, data: list):
        """
        Adds a new event to the packer.

        :param event_type: The Events enum member.
        :param data: A list of arguments for the event, matching the
                     struct definition. For dynamic events, the final
                     arguments must be pre-encoded bytes.
        """
        if self._chunk_size > 0:
            self._event_buffer.append({"type": event_type, "data": data})
            if len(self._event_buffer) >= self._chunk_size:
                self._pack_buffered_events()
        else:
            self._pack_event(event_type, data)

    def _pack_event(self, event_type: Events, data: list):
        type_value = event_type.value
        try:
            # Pack header: <I (type) <Q (timestamp) = 12 bytes
            self._event_stream.extend(struct.pack("<IQ", type_value, 0))
        except struct.error as e:
            print(
                f"CommandPacker ({event_type.name}): Failed to pack header: {e}",
                file=sys.stderr,
            )
            return

        try:
            # --- Manual Packing for Variable-Length Events ---
            # These events have a (format, size) for their *header*
            # and expect raw bytes as their final argument(s).

            if event_type == Events.SPRITE_TEXTURE_LOAD:
                # data = [id0(q), id1(q), filenameLength(I), filename_bytes(b"")]
                if len(data) != 4:
                    raise ValueError(f"TEXTURE_LOAD: Expected 4 args, got {len(data)}")
                fmt, _ = PackFormat.get_info(type_value)  # ("<qqI4x", 24)
                self._event_stream.extend(struct.pack(fmt, data[0], data[1], data[2]))
                self._event_stream.extend(data[3])  # data[3] is already bytes

            elif event_type == Events.PLUGIN_LOAD:
                # data = [pathLength(I), path_bytes(b"")]
                if len(data) != 2:
                    raise ValueError(f"PLUGIN_LOAD: Expected 2 args, got {len(data)}")
                fmt, _ = PackFormat.get_info(type_value)  # ("<I", 4)
                self._event_stream.extend(struct.pack(fmt, data[0]))
                self._event_stream.extend(data[1])  # data[1] is already bytes

            elif event_type == Events.AUDIO_LOAD:
                # data = [pathLength(I), path_bytes(b"")]
                if len(data) != 2:
                    raise ValueError(f"AUDIO_LOAD: Expected 2 args, got {len(data)}")
                fmt, _ = PackFormat.get_info(type_value)  # ("<I", 4)
                self._event_stream.extend(struct.pack(fmt, data[0]))
                self._event_stream.extend(data[1])  # data[1] is already bytes

            elif event_type == Events.TEXT_ADD:
                # data = [id0(q), id1(q), ..., fontPath_bytes(b""), text_bytes(b"")]
                if len(data) != 14:
                    raise ValueError(f"TEXT_ADD: Expected 14 args, got {len(data)}")
                fmt, _ = PackFormat.get_info(type_value)  # ("<qqdddBBBB4xfII4x", 64)
                self._event_stream.extend(
                    struct.pack(
                        fmt,
                        data[0],
                        data[1],
                        data[2],
                        data[3],
                        data[4],  # id, pos
                        data[5],
                        data[6],
                        data[7],
                        data[8],  # rgba
                        data[9],
                        data[10],
                        data[11],  # fontSize, fontPathLen, textLen
                    )
                )
                self._event_stream.extend(data[12])  # fontPath_bytes
                self._event_stream.extend(data[13])  # text_bytes

            elif event_type == Events.TEXT_SET_STRING:
                # data = [id0(q), id1(q), textLength(I), text_bytes(b"")]
                if len(data) != 4:
                    raise ValueError(
                        f"TEXT_SET_STRING: Expected 4 args, got {len(data)}"
                    )
                fmt, _ = PackFormat.get_info(type_value)  # ("<qqI4x", 24)
                self._event_stream.extend(struct.pack(fmt, data[0], data[1], data[2]))
                self._event_stream.extend(data[3])  # text_bytes

            else:
                # --- Fixed-Size Event Packing Logic ---
                payload_info = PackFormat.get_info(type_value)
                if payload_info is None:
                    raise ValueError(
                        f"Could not get payload info for {event_type.name}"
                    )

                fmt, size = payload_info

                if not fmt and data:
                    raise ValueError(
                        f"Format is empty but data was provided for {event_type.name}"
                    )

                if fmt:
                    # fmt is the pre-compiled struct string (e.g., "<qqd")
                    self._event_stream.extend(struct.pack(fmt, *data))

            self._command_count += 1

        except (struct.error, ValueError, TypeError) as e:
            print(
                f"CommandPacker ({event_type.name}): Error during pack! {e}",
                file=sys.stderr,
            )
            print(f"  Data: {data}", file=sys.stderr)

    def _pack_buffered_events(self):
        if not self._event_buffer:
            return
        for event in self._event_buffer:
            self._pack_event(event["type"], event["data"])

        if self._chunk_callback:
            self._chunk_callback(len(self._event_buffer), self._command_count)

        self._event_buffer = []

    def flush(self):
        if self._event_buffer:
            self._pack_buffered_events()

    def finalize(self) -> bytes:
        self.flush()
        if self._command_count == 0:
            return b""
        # Prepend count (<I) and return the full byte stream
        return struct.pack("<I", self._command_count) + self._event_stream

    def get_buffer_count(self) -> int:
        return len(self._event_buffer)

    def get_total_event_count(self) -> int:
        return self._command_count + len(self._event_buffer)


# --- End CommandPacker Class ---
