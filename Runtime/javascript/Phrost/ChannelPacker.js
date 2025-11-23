const CommandPacker = require("./CommandPacker");

/**
 * Manages packing events into multiple "channels".
 * * Wraps multiple CommandPacker instances. When finalized, produces a single binary blob:
 * 1. Channel Count (u32) + Padding (u32)
 * 2. Index Table [Channel ID (u32), Channel Size (u32)] * N
 * 3. Data Blobs
 */
class ChannelPacker {
  constructor() {
    /** @type {Object.<number, CommandPacker>} */
    this.channelPackers = {};
  }

  /**
   * Adds an event to a specific channel.
   * * @param {number} channelId - The channel ID.
   * @param {number} type - The Event type.
   * @param {Array|Object} data - The event data.
   */
  add(channelId, type, data) {
    if (!this.channelPackers[channelId]) {
      // Create new packer, disable internal buffering (chunkSize 0)
      this.channelPackers[channelId] = new CommandPacker(0);
    }
    this.channelPackers[channelId].add(type, data);
  }

  /**
   * Finalizes all channel packers and combines them into a single binary blob.
   * * @returns {Buffer}
   */
  finalize() {
    const channelIds = Object.keys(this.channelPackers)
      .map(Number)
      .sort((a, b) => a - b);

    if (channelIds.length === 0) {
      return Buffer.alloc(0);
    }

    const indexTableParts = [];
    const dataBlobParts = [];

    for (const channelId of channelIds) {
      const packer = this.channelPackers[channelId];
      const channelBlob = packer.finalize();
      const channelSize = channelBlob.length;

      // Index Table Entry: [ID (4)] + [Size (4)] = 8 bytes
      const entry = Buffer.alloc(8);
      entry.writeUInt32LE(channelId, 0);
      entry.writeUInt32LE(channelSize, 4);
      indexTableParts.push(entry);

      dataBlobParts.push(channelBlob);
    }

    // 1. Pack Count + Padding to 8 bytes (Vx4)
    const header = Buffer.alloc(8);
    header.writeUInt32LE(channelIds.length, 0);

    // 2. Combine everything
    return Buffer.concat([header, ...indexTableParts, ...dataBlobParts]);
  }

  /**
   * Gets total events across all channels.
   * @returns {number}
   */
  getTotalEventCount() {
    let total = 0;
    for (const id in this.channelPackers) {
      total += this.channelPackers[id].getTotalEventCount();
    }
    return total;
  }
}

module.exports = ChannelPacker;
