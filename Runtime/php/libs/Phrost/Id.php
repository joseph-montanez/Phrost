<?php

namespace Phrost;

class Id
{
    /**
     * Generates 16 random bytes and returns them as two 64-bit integers.
     */
    public static function generate(): array
    {
        $b = random_bytes(16);
        $p1 = substr($b, 0, 8);
        $p2 = substr($b, 8, 8);
        return [unpack("J", $p1)[1], unpack("J", $p2)[1]];
    }

    /**
     * Converts the 2-part integer array back into the 16-byte binary string.
     */
    public static function toBytes(array $ints): string
    {
        $p1 = pack("J", $ints[0]);
        $p2 = pack("J", $ints[1]);

        return $p1 . $p2;
    }

    /**
     * Converts the 2-part integer array into a 32-character hex string.
     */
    public static function toHex(array $ints): string
    {
        return bin2hex(self::toBytes($ints));
    }

    /**
     * Converts the 2-part integer array into the "human-readable" UUID string
     * by formatting the output of toHex().
     */
    public static function toHuman(array $ints): string
    {
        // --- Yes! Just use toHex() first ---
        $hex = self::toHex($ints);

        // Use sscanf to parse the 32-char hex string into the 8-4-4-4-12 format
        $parts = sscanf($hex, "%8s%4s%4s%4s%12s");

        // Format the parts with hyphens
        return vsprintf("%s-%s-%s-%s-%s", $parts);
    }
}
