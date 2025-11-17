import os
import socket
import struct
import sys
from typing import Callable, Optional, Dict, Union


class IPCClient:
    """
    Phrost IPC Client (Python)

    This class handles all the low-level, cross-platform socket/pipe
    communication with the Swift IPC server.
    """

    def __init__(self):
        self.is_windows: bool = os.name == "nt"
        self.pipe: Optional[Union[socket.socket, "file"]] = None
        self.is_connected: bool = False

    def connect(self):
        """Connects to the Swift IPC server."""
        if self.is_connected:
            return

        try:
            if self.is_windows:
                # --- Windows Connection (Named Pipe) ---
                pipe_path = r"\\.\pipe\PhrostEngine"
                print(f"Attempting to connect to Windows pipe: {pipe_path}...")

                # 'r+b' is critical for binary read/write
                self.pipe = open(pipe_path, "r+b")
                # Windows pipes are blocking by default, similar to stream_set_blocking

            else:
                # --- macOS/Linux Connection (UNIX Domain Socket) ---
                pipe_path = "/tmp/PhrostEngine.socket"
                print(f"Attempting to connect to UNIX socket: {pipe_path}...")

                self.pipe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.pipe.connect(pipe_path)
                # Sockets are blocking by default, similar to socket_set_block

            self.is_connected = True
            print("Connected! Entering game loop...")
            print("Blocking now...")

        except (FileNotFoundError, ConnectionRefusedError) as e:
            server_name = "PhrostIPC.exe" if self.is_windows else "Swift server"
            raise Exception(
                f"Connection failed. Is the {server_name} running?\nError: {e}"
            )
        except Exception as e:
            raise Exception(f"An unexpected error occurred: {e}")

    def disconnect(self):
        """Disconnects from the server."""
        if not self.is_connected or not self.pipe:
            return

        try:
            self.pipe.close()
        except Exception as e:
            print(f"Error during disconnect: {e}", file=sys.stderr)
        finally:
            self.pipe = None
            self.is_connected = False
            print("Disconnected.")

    def run(self, update_callback: Callable[[int, float, bytes], Union[bytes, bool]]):
        """
        Runs the main game loop, calling the update callback each frame.

        :param update_callback: The user's game logic function.
            Accepts: (elapsed: int, dt: float, events_blob: bytes)
            Returns: (command_blob: bytes) or False to quit.
        """
        if not self.is_connected:
            raise Exception("Cannot run: Not connected.")

        elapsed = 0
        try:
            while True:
                # 1. Read frame data from Swift
                frame_data = self.read_frame()
                if frame_data is None:
                    print("Pipe broken (read failed). Exiting loop.")
                    break

                # 2. Call the user's game logic function
                command_blob = update_callback(
                    elapsed, frame_data["dt"], frame_data["events_blob"]
                )

                if command_blob is False:
                    print("[Python Logic] Game logic signaled graceful quit.")
                    break

                # 3. Write commands back to Swift
                if not self.write_frame(command_blob):
                    print("Pipe broken (write failed). Exiting loop.")
                    break

                elapsed += 1
        except Exception as e:
            print(f"An error occurred during the loop: {e}", file=sys.stderr)
            import traceback

            traceback.print_exc()

    def read_frame(self) -> Optional[Dict[str, Union[float, bytes]]]:
        """
        Reads one full "frame" of data from the Swift server.
        Format: [4-byte length][8-byte double dt][event_blob]
        """
        # 1. Read Length Header (4 bytes, unsigned long, little-endian)
        len_header = self.read_all(4)
        if len_header is None:
            return None

        try:
            # '<L' = unsigned long, little-endian (matches PHP 'V')
            total_length = struct.unpack("<L", len_header)[0]
        except struct.error:
            print("Failed to unpack header.", file=sys.stderr)
            return None

        # 2. Read Payload (dt + events)
        if total_length < 8:
            print(
                f"Payload too small: {total_length} bytes, expected >= 8.",
                file=sys.stderr,
            )
            return None

        # Read DT (8 bytes, double)
        dt_data = self.read_all(8)
        if dt_data is None:
            print("Failed to read delta-time.", file=sys.stderr)
            return None

        # 'd' = double (matches PHP 'd')
        dt = struct.unpack("d", dt_data)[0]

        # Read Events (Remaining bytes)
        event_payload_length = total_length - 8
        events_blob = b""
        if event_payload_length > 0:
            events_blob = self.read_all(event_payload_length)
            if events_blob is None:
                print("Failed to read event payload.", file=sys.stderr)
                return None

        return {"dt": dt, "events_blob": events_blob}

    def write_frame(self, command_blob: bytes) -> bool:
        """
        Writes one full "frame" of commands to the Swift server.
        Format: [4-byte length][command_blob]
        """
        try:
            cmd_len = len(command_blob)
            # '<L' = unsigned long, little-endian (matches PHP 'V')
            out_data = struct.pack("<L", cmd_len) + command_blob
            return self.write_all(out_data)
        except Exception as e:
            print(f"write_frame failed: {e}", file=sys.stderr)
            return False

    def read_all(self, length: int) -> Optional[bytes]:
        """Unified read function. Reads exactly 'length' bytes."""
        if length == 0:
            return b""

        buffer = bytearray()
        bytes_remaining = length
        try:
            while bytes_remaining > 0:
                if self.is_windows:
                    data = self.pipe.read(bytes_remaining)
                else:
                    data = self.pipe.recv(bytes_remaining)

                if not data:
                    print(
                        f"Pipe closed (read 0 bytes). Bytes remaining: {bytes_remaining}",
                        file=sys.stderr,
                    )
                    return None

                buffer.extend(data)
                bytes_remaining -= len(data)
            return bytes(buffer)
        except (IOError, socket.error) as e:
            print(f"read_all failed: {e}", file=sys.stderr)
            return None

    def write_all(self, data: bytes) -> bool:
        """Unified write function. Writes all data."""
        try:
            if self.is_windows:
                # For Windows pipes opened as files, we loop the write
                # just like your PHP code to ensure all data is sent.
                total_written = 0
                total_to_write = len(data)
                view = memoryview(data)  # Avoids string copies
                while total_written < total_to_write:
                    written = self.pipe.write(view[total_written:])
                    if written is None or written == 0:
                        print("Write returned 0 bytes.", file=sys.stderr)
                        return False
                    total_written += written
                self.pipe.flush()  # Essential for Windows pipes
            else:
                # Sockets have 'sendall' which handles the loop for us
                self.pipe.sendall(data)
            return True
        except (IOError, socket.error) as e:
            print(f"write_all failed: {e}", file=sys.stderr)
            return False
