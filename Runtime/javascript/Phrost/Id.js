const crypto = require("crypto");

/**
 * Phrost Id Generator
 * * Handles generation of 128-bit random identifiers split into two 64-bit integers.
 */
class Id {
  /**
   * Generates 16 random bytes and returns them as two 64-bit integers (BigInt).
   * * @returns {Array<bigint>} An array containing two BigInts [part1, part2].
   */
  static generate() {
    const b = crypto.randomBytes(16);
    // PHP's unpack("J") is 64-bit unsigned long long (big endian)
    const p1 = b.readBigUInt64BE(0);
    const p2 = b.readBigUInt64BE(8);
    return [p1, p2];
  }

  /**
   * Converts the 2-part integer array back into a 16-byte buffer.
   * * @param {Array<bigint>} ints - Array of two BigInts.
   * @returns {Buffer} The 16-byte buffer.
   */
  static toBytes(ints) {
    const buffer = Buffer.alloc(16);
    buffer.writeBigUInt64BE(ints[0], 0);
    buffer.writeBigUInt64BE(ints[1], 8);
    return buffer;
  }

  /**
   * Converts the 2-part integer array into a 32-character hex string.
   * * @param {Array<bigint>} ints - Array of two BigInts.
   * @returns {string} The hex string.
   */
  static toHex(ints) {
    return this.toBytes(ints).toString("hex");
  }

  /**
   * Converts the 2-part integer array into the "human-readable" UUID string.
   * Formats as 8-4-4-4-12.
   * * @param {Array<bigint>} ints - Array of two BigInts.
   * @returns {string} The formatted UUID string.
   */
  static toHuman(ints) {
    const hex = this.toHex(ints);
    // 8-4-4-4-12 format
    return `${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}`;
  }
}

module.exports = Id;
