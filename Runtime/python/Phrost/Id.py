import secrets
import struct
from typing import Tuple

class Id:
    """
    Provides static methods for generating and handling 16-byte (128-bit) IDs
    by splitting them into two 64-bit integers.
    """

    @staticmethod
    def generate() -> Tuple[int, int]:
        """
        Generates 16 random bytes and returns them as two 64-bit integers.

        Note: Assumes 64-bit integers are unsigned and little-endian,
        matching PHP's 'J' pack format on a typical x86/ARM machine.
        """
        # 1. Generates 16 random bytes
        b = secrets.token_bytes(16)

        # 2. Split into two 8-byte parts
        p1 = b[:8]  # First 8 bytes
        p2 = b[8:]  # Second 8 bytes

        # 3. Unpack each part as an unsigned 64-bit little-endian integer ('<Q')
        # This is the Python equivalent of PHP's unpack("J", ...)
        return (
            struct.unpack("<Q", p1)[0],
            struct.unpack("<Q", p2)[0]
        )

    @staticmethod
    def to_bytes(ints: Tuple[int, int]) -> bytes:
        """
        Converts the 2-part integer tuple back into the 16-byte binary string.
        """
        # Pack each integer as an unsigned 64-bit little-endian integer ('<Q')
        # This is the Python equivalent of PHP's pack("J", ...)
        p1 = struct.pack("<Q", ints[0])
        p2 = struct.pack("<Q", ints[1])

        return p1 + p2

    @staticmethod
    def to_hex(ints: Tuple[int, int]) ->
