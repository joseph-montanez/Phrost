const { Events } = require("./Events");
const { PackFormat } = require("./PackFormat");

/**
 * Phrost Command Packer
 * * Handles packing events into binary streams for the engine.
 * It manages alignment (padding to 8-byte boundaries) and specific binary formats.
 */
class CommandPacker {
  /**
   * @param {number} [chunkSize=0] - If > 0, events are buffered and flushed in chunks.
   * @param {?function(number, number): void} [chunkCallback=null] - Callback executed when a chunk is flushed.
   */
  constructor(chunkSize = 0, chunkCallback = null) {
    /** @type {Buffer[]} Internal stream of packed bytes */
    this.eventStream = [];
    /** @type {number} Total running byte length of eventStream */
    this.eventStreamLength = 0;

    this.commandCount = 0;
    this.eventBuffer = [];
    this.chunkSize = chunkSize;
    this.chunkCallback = chunkCallback;

    // Cache for pure format strings used in generic packing
    this.pureFormatCache = {};
  }

  /**
   * Adds an event to the packer.
   * * @param {number} type - The Event type (from Events enum).
   * @param {Array|Object} data - The data associated with the event.
   */
  add(type, data) {
    if (this.chunkSize > 0) {
      this.eventBuffer.push({ type, data });
      if (this.eventBuffer.length >= this.chunkSize) {
        this.packBufferedEvents();
      }
    } else {
      this.packEvent(type, data);
    }
  }

  /**
   * Packs a string and adds padding to align to 8 bytes.
   * * @private
   * @param {string} str
   * @returns {Buffer}
   */
  packStringAligned(str) {
    const buf = Buffer.from(str, "utf8");
    const len = buf.length;
    const padding = (8 - (len % 8)) % 8;

    if (padding === 0) return buf;

    return Buffer.concat([buf, Buffer.alloc(padding)]);
  }

  /**
   * Adds padding to the current stream to ensure 8-byte alignment.
   * * @private
   */
  padToBoundary() {
    const currentLen = this.eventStreamLength;
    const padding = (8 - (currentLen % 8)) % 8;
    if (padding > 0) {
      const padBuf = Buffer.alloc(padding);
      this.eventStream.push(padBuf);
      this.eventStreamLength += padding;
    }
  }

  /**
   * Appends a buffer to the stream and updates length.
   * * @private
   * @param {Buffer} buf
   */
  append(buf) {
    this.eventStream.push(buf);
    this.eventStreamLength += buf.length;
  }

  /**
   * Core logic to pack a single event.
   * * @private
   * @param {number} type
   * @param {Array|Object} data
   */
  packEvent(type, data) {
    // ALIGNMENT FIX: Header is now 16 bytes (4 type + 8 reserved + 4 padding)
    // pack("VQx4", typeValue, 0) -> V (u32le), Q (u64le), x4 (4 nulls)
    const header = Buffer.alloc(16);
    header.writeUInt32LE(type, 0);
    header.writeBigUInt64LE(0n, 4); // Reserved/Timestamp placeholder
    // bytes 12-15 are padding (0)
    this.append(header);

    // Normalize data to array if it's not already (handles named params if implemented later)
    const d = Array.isArray(data) ? data : Object.values(data);

    if (type === Events.SPRITE_TEXTURE_LOAD) {
      // q(i64), q(i64), V(u32), x4
      const fixedBuf = Buffer.alloc(24);
      // FIX: Apply BigInt.asIntN to these two lines
      fixedBuf.writeBigInt64LE(BigInt.asIntN(64, BigInt(d[0])), 0);
      fixedBuf.writeBigInt64LE(BigInt.asIntN(64, BigInt(d[1])), 8);

      fixedBuf.writeUInt32LE(d[2], 16);
      // x4 padding at end
      this.append(fixedBuf);
      this.append(this.packStringAligned(d[3]));
    } else if (type === Events.PLUGIN_LOAD) {
      // V(u32)
      const fixedBuf = Buffer.alloc(4);
      fixedBuf.writeUInt32LE(d[0], 0);
      this.append(fixedBuf);

      // Pad fixed part to 8 bytes manually as per PHP logic
      this.append(Buffer.alloc(4));

      this.append(this.packStringAligned(d[1]));
    } else if (type === Events.AUDIO_LOAD) {
      if (d.length !== 2) {
        console.error(
          "CommandPacker (AUDIO_LOAD): Incorrect data count, expected 2.",
        );
        return;
      }
      // V(u32) + x4
      const fixedBuf = Buffer.alloc(8);
      fixedBuf.writeUInt32LE(d[0], 0);
      this.append(fixedBuf);
      this.append(this.packStringAligned(d[1]));
    } else if (type === Events.TEXT_ADD) {
      // Custom large struct: qqeeeCCCCx4gVVx4
      // size: 8+8 + 8+8+8 + 1+1+1+1+4 + 4+4+4+4 = 64 bytes
      const fixedBuf = Buffer.alloc(64);
      let off = 0;
      fixedBuf.writeBigInt64LE(BigInt.asIntN(64, BigInt(d[0])), off);
      off += 8;
      fixedBuf.writeBigInt64LE(BigInt.asIntN(64, BigInt(d[1])), off);
      off += 8;
      fixedBuf.writeDoubleLE(d[2], off);
      off += 8;
      fixedBuf.writeDoubleLE(d[3], off);
      off += 8;
      fixedBuf.writeDoubleLE(d[4], off);
      off += 8;
      fixedBuf.writeUInt8(d[5], off);
      off += 1;
      fixedBuf.writeUInt8(d[6], off);
      off += 1;
      fixedBuf.writeUInt8(d[7], off);
      off += 1;
      fixedBuf.writeUInt8(d[8], off);
      off += 1;
      off += 4; // x4 padding
      fixedBuf.writeFloatLE(d[9], off);
      off += 4;
      fixedBuf.writeUInt32LE(d[10], off);
      off += 4;
      fixedBuf.writeUInt32LE(d[11], off);
      off += 4;
      // x4 padding
      this.append(fixedBuf);

      this.append(this.packStringAligned(d[12])); // fontPath
      this.append(this.packStringAligned(d[13])); // text
    } else if (type === Events.TEXT_SET_STRING) {
      // qqVx4 -> 24 bytes
      const fixedBuf = Buffer.alloc(24);
      fixedBuf.writeBigInt64LE(BigInt.asIntN(64, BigInt(d[0])), 0);
      fixedBuf.writeBigInt64LE(BigInt.asIntN(64, BigInt(d[1])), 8);
      fixedBuf.writeUInt32LE(d[2], 16);
      this.append(fixedBuf);
      this.append(this.packStringAligned(d[3]));
    } else {
      // --- Generic Fixed-Size Event Packing ---
      const payloadInfo = PackFormat.getInfo(type);
      if (payloadInfo) {
        const pureFormat = this.getPureFormat(payloadInfo.format);
        if (pureFormat || d.length > 0) {
          const buffer = this.packValues(pureFormat, d);
          this.append(buffer);
        }
      }
    }

    // Ensure the ENTIRE event ends on an 8-byte boundary
    this.padToBoundary();
    this.commandCount++;
  }

  /**
   * Packs values into a buffer based on a pure format string (stripped of field names).
   * Replicates PHP's pack() for supported codes.
   * * @private
   * @param {string} format
   * @param {Array} values
   * @returns {Buffer}
   */
  packValues(format, values) {
    // Calculate size first to allocate buffer
    // We use the PackFormat helper logic simplified here or dynamic buffer
    // For simplicity in JS, we'll iterate format codes

    const codes = format.match(/[a-zA-Z]\d*|\*|@/g) || [];
    const bufferParts = [];
    let valIndex = 0;

    for (const codeStr of codes) {
      const code = codeStr.charAt(0);
      const countStr = codeStr.substring(1);
      const count =
        countStr === "" || countStr === "*" ? 1 : parseInt(countStr);

      for (let i = 0; i < count; i++) {
        if (valIndex >= values.length && code !== "x") break;

        let val = values[valIndex];

        // Handle padding (doesn't consume value)
        if (code === "x") {
          bufferParts.push(Buffer.alloc(1));
          continue;
        }

        valIndex++; // Consume value

        switch (code) {
          case "c": {
            const b = Buffer.alloc(1);
            b.writeInt8(val, 0);
            bufferParts.push(b);
            break;
          }
          case "C": {
            const b = Buffer.alloc(1);
            b.writeUInt8(val, 0);
            bufferParts.push(b);
            break;
          }
          case "s": {
            const b = Buffer.alloc(2);
            b.writeInt16LE(val, 0);
            bufferParts.push(b);
            break;
          }
          case "S":
          case "n":
          case "v": {
            const b = Buffer.alloc(2);
            b.writeUInt16LE(val, 0);
            bufferParts.push(b);
            break;
          }
          case "l":
          case "i": {
            const b = Buffer.alloc(4);
            b.writeInt32LE(val, 0);
            bufferParts.push(b);
            break;
          }
          case "L":
          case "V":
          case "I":
          case "N": {
            const b = Buffer.alloc(4);
            b.writeUInt32LE(val, 0);
            bufferParts.push(b);
            break;
          }
          case "q": {
            const b = Buffer.alloc(8);
            // Cast to signed 64-bit to prevent RangeError on large unsigned IDs
            // This preserves the binary bit pattern.
            b.writeBigInt64LE(BigInt.asIntN(64, BigInt(val)), 0);
            bufferParts.push(b);
            break;
          }
          case "Q":
          case "J":
          case "P": {
            const b = Buffer.alloc(8);
            b.writeBigUInt64LE(BigInt(val), 0);
            bufferParts.push(b);
            break;
          }
          case "f":
          case "g": {
            const b = Buffer.alloc(4);
            b.writeFloatLE(val, 0);
            bufferParts.push(b);
            break;
          }
          case "d":
          case "e":
          case "E": {
            const b = Buffer.alloc(8);
            b.writeDoubleLE(val, 0);
            bufferParts.push(b);
            break;
          }
          case "a": {
            // 'a' in PHP pack usually takes one argument and pads/cuts to length if count is specific
            // In this parser context, 'a256' means a fixed 256 byte block.
            // The generic parser usually handles simple types. Strings are mostly handled in specific blocks above.
            // However, WINDOW_TITLE uses 'a256'.
            let buf = Buffer.alloc(count); // Alloc fixed size
            if (typeof val === "string") {
              buf.write(val, 0, count, "utf8");
            }
            bufferParts.push(buf);
            i = count; // Skip inner loop, we handled the whole count
            break;
          }
        }
      }
    }
    return Buffer.concat(bufferParts);
  }

  /**
   * Converts a descriptive format (e.g. "qid1/qid2") into a pure format code string (e.g. "qq").
   * * @private
   * @param {string} descriptiveFormat
   * @returns {string}
   */
  getPureFormat(descriptiveFormat) {
    if (this.pureFormatCache[descriptiveFormat]) {
      return this.pureFormatCache[descriptiveFormat];
    }
    let pure = "";
    const parts = descriptiveFormat.split("/");
    for (const part of parts) {
      const match = part.match(/^([a-zA-Z])(\*|\d*)/);
      if (match) {
        const code = match[1];
        const count = match[2];
        if (count === "*") break;
        pure += code + count;
      }
    }
    this.pureFormatCache[descriptiveFormat] = pure;
    return pure;
  }

  /**
   * Packs buffered events.
   * @private
   */
  packBufferedEvents() {
    if (this.eventBuffer.length === 0) return;

    for (const event of this.eventBuffer) {
      this.packEvent(event.type, event.data);
    }

    if (this.chunkCallback) {
      this.chunkCallback(this.eventBuffer.length, this.commandCount);
    }
    this.eventBuffer = [];
  }

  /**
   * Flushes pending buffers.
   */
  flush() {
    if (this.eventBuffer.length > 0) {
      this.packBufferedEvents();
    }
  }

  /**
   * Finalizes the stream and returns the binary Buffer.
   * * @returns {Buffer}
   */
  finalize() {
    this.flush();
    if (this.commandCount === 0) {
      return Buffer.alloc(0);
    }

    // ALIGNMENT FIX: Pad the Command Count to 8 bytes (Vx4)
    const countBuf = Buffer.alloc(8);
    countBuf.writeUInt32LE(this.commandCount, 0);
    // Bytes 4-7 are padding (0)

    return Buffer.concat([countBuf, ...this.eventStream]);
  }

  getBufferCount() {
    return this.eventBuffer.length;
  }

  getTotalEventCount() {
    return this.commandCount + this.eventBuffer.length;
  }
}

module.exports = CommandPacker;
