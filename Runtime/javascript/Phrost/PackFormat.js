const EventModule = require("./Events");

// Safety check to ensure Events loaded correctly
if (!EventModule || !EventModule.Events) {
  throw new Error(
    "PackFormat: Failed to load Events enum. Check Events.js export.",
  );
}

const { Events } = EventModule;

/**
 * Map of Event types to their specific packing format strings.
 */
const EVENT_FORMAT_MAP = {
  [Events.SPRITE_ADD]:
    "qid1/qid2/epositionX/epositionY/epositionZ/escaleX/escaleY/escaleZ/esizeW/esizeH/erotationX/erotationY/erotationZ/Cr/Cg/Cb/Ca/x4_padding/espeedX/espeedY",
  [Events.SPRITE_REMOVE]: "qid1/qid2",
  [Events.SPRITE_MOVE]: "qid1/qid2/epositionX/epositionY/epositionZ",
  [Events.SPRITE_SCALE]: "qid1/qid2/escaleX/escaleY/escaleZ",
  [Events.SPRITE_RESIZE]: "qid1/qid2/esizeW/esizeH",
  [Events.SPRITE_ROTATE]: "qid1/qid2/erotationX/erotationY/erotationZ",
  [Events.SPRITE_COLOR]: "qid1/qid2/Cr/Cg/Cb/Ca/x4_padding",
  [Events.SPRITE_SPEED]: "qid1/qid2/espeedX/espeedY",
  [Events.SPRITE_TEXTURE_LOAD]:
    "qid1/qid2/VfilenameLength/x4_padding/a*filename",
  [Events.SPRITE_TEXTURE_SET]: "qid1/qid2/QtextureId",
  [Events.SPRITE_SET_SOURCE_RECT]: "qid1/qid2/gx/gy/gw/gh",

  [Events.GEOM_ADD_POINT]:
    "qid1/qid2/ez/Cr/Cg/Cb/Ca/CisScreenSpace/x3_padding/gx/gy",
  [Events.GEOM_ADD_LINE]:
    "qid1/qid2/ez/Cr/Cg/Cb/Ca/CisScreenSpace/x3_padding/gx1/gy1/gx2/gy2",
  [Events.GEOM_ADD_RECT]:
    "qid1/qid2/ez/Cr/Cg/Cb/Ca/CisScreenSpace/x3_padding/gx/gy/gw/gh",
  [Events.GEOM_ADD_FILL_RECT]:
    "qid1/qid2/ez/Cr/Cg/Cb/Ca/CisScreenSpace/x3_padding/gx/gy/gw/gh",
  [Events.GEOM_ADD_PACKED]:
    "qid1/qid2/ez/Cr/Cg/Cb/Ca/CisScreenSpace/x2_padding/VprimitiveType/Vcount",
  [Events.GEOM_REMOVE]: "qid1/qid2",
  [Events.GEOM_SET_COLOR]: "qid1/qid2/Cr/Cg/Cb/Ca/x4_padding",

  [Events.INPUT_KEYUP]: "lscancode/Vkeycode/Smod/CisRepeat/x_padding",
  [Events.INPUT_KEYDOWN]: "lscancode/Vkeycode/Smod/CisRepeat/x_padding",
  [Events.INPUT_MOUSEUP]: "gx/gy/Cbutton/Cclicks/x2_padding",
  [Events.INPUT_MOUSEDOWN]: "gx/gy/Cbutton/Cclicks/x2_padding",
  [Events.INPUT_MOUSEMOTION]: "gx/gy/gxrel/gyrel",

  [Events.WINDOW_TITLE]: "a256title",
  [Events.WINDOW_RESIZE]: "lw/lh",
  [Events.WINDOW_FLAGS]: "Qflags",

  [Events.TEXT_ADD]:
    "qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4_padding1/gfontSize/VfontPathLength/VtextLength/x4_padding2/a*fontPath/a*text",
  [Events.TEXT_SET_STRING]: "qid1/qid2/VtextLength/x4_padding/a*text",

  [Events.AUDIO_LOAD]: "VpathLength/a*path",
  [Events.AUDIO_LOADED]: "QaudioId",
  [Events.AUDIO_PLAY]: "QaudioId",
  [Events.AUDIO_STOP_ALL]: "C_unused",
  [Events.AUDIO_SET_MASTER_VOLUME]: "gvolume",
  [Events.AUDIO_PAUSE]: "QaudioId",
  [Events.AUDIO_STOP]: "QaudioId",
  [Events.AUDIO_UNLOAD]: "QaudioId",
  [Events.AUDIO_SET_VOLUME]: "QaudioId/gvolume/x4_padding",

  [Events.PHYSICS_ADD_BODY]:
    "qid1/qid2/epositionX/epositionY/CbodyType/CshapeType/ClockRotation/x5_padding/emass/efriction/eelasticity/ewidth/eheight",
  [Events.PHYSICS_REMOVE_BODY]: "qid1/qid2",
  [Events.PHYSICS_APPLY_FORCE]: "qid1/qid2/eforceX/eforceY",
  [Events.PHYSICS_APPLY_IMPULSE]: "qid1/qid2/eimpulseX/eimpulseY",
  [Events.PHYSICS_SET_VELOCITY]: "qid1/qid2/evelocityX/evelocityY",
  [Events.PHYSICS_SET_POSITION]: "qid1/qid2/epositionX/epositionY",
  [Events.PHYSICS_SET_ROTATION]: "qid1/qid2/eangleInRadians",
  [Events.PHYSICS_COLLISION_BEGIN]: "qid1_A/qid2_A/qid1_B/qid2_B",
  [Events.PHYSICS_COLLISION_SEPARATE]: "qid1_A/qid2_A/qid1_B/qid2_B",
  [Events.PHYSICS_SYNC_TRANSFORM]:
    "qid1/qid2/epositionX/epositionY/eangle/evelocityX/evelocityY/eangularVelocity/CisSleeping/x7_padding",

  [Events.PLUGIN]: "CeventId",
  [Events.PLUGIN_LOAD]: "VchannelNo/VpathLength/a*path",
  [Events.PLUGIN_UNLOAD]: "CpluginId",
  [Events.PLUGIN_SET]: "CpluginId",
  [Events.PLUGIN_EVENT_STACKING]: "CeventId/x_padding",
  [Events.PLUGIN_SUBSCRIBE_EVENT]: "CpluginId/x3_padding/VchannelNo",
  [Events.PLUGIN_UNSUBSCRIBE_EVENT]: "CpluginId/x3_padding/VchannelNo",

  [Events.CAMERA_SET_POSITION]: "epositionX/epositionY",
  [Events.CAMERA_MOVE]: "edeltaX/edeltaY",
  [Events.CAMERA_SET_ZOOM]: "ezoom",
  [Events.CAMERA_SET_ROTATION]: "eangleInRadians",
  [Events.CAMERA_FOLLOW_ENTITY]: "qid1/qid2",
  [Events.CAMERA_STOP_FOLLOWING]: "C_unused",

  [Events.SCRIPT_SUBSCRIBE]: "VchannelNo/x4_padding",
  [Events.SCRIPT_UNSUBSCRIBE]: "VchannelNo/x4_padding",
};

/**
 * Map of pack codes to their byte sizes.
 */
const SIZE_MAP = {
  a: 1,
  A: 1,
  Z: 1,
  h: 0.5,
  H: 0.5,
  c: 1,
  C: 1,
  s: 2,
  S: 2,
  n: 2,
  v: 2,
  l: 4,
  L: 4,
  N: 4,
  V: 4,
  i: 4,
  I: 4,
  f: 4,
  g: 4,
  G: 4,
  q: 8,
  Q: 8,
  J: 8,
  P: 8,
  d: 8,
  e: 8,
  E: 8,
  x: 1,
  X: -1,
  "@": 0,
};

/**
 * Cache for storing parsed format info.
 * @type {Object.<number, {format: string, size: number}>}
 */
const cache = {};

class PackFormat {
  /**
   * Retrieves format information for a specific event type.
   * * @param {number} eventTypeValue - The integer value of the event (from Events enum).
   * @returns {?{format: string, size: number}} An object containing the format string and calculated size in bytes, or null if not found.
   */
  static getInfo(eventTypeValue) {
    if (cache[eventTypeValue]) {
      return cache[eventTypeValue];
    }

    const descriptiveFormat = EVENT_FORMAT_MAP[eventTypeValue];
    if (!descriptiveFormat) {
      return null;
    }

    let totalSize = 0;
    const parts = descriptiveFormat.split("/");

    // Dynamic events that have variable length strings or complex structures
    const dynamicEvents = [
      Events.SPRITE_TEXTURE_LOAD,
      Events.PLUGIN_LOAD,
      Events.TEXT_ADD,
      Events.TEXT_SET_STRING,
      Events.AUDIO_LOAD,
      Events.GEOM_ADD_PACKED,
    ];

    for (const part of parts) {
      const match = part.match(/^([a-zA-Z])(\*|\d*)/);
      if (match) {
        const code = match[1];
        const repeater = match[2];

        if (repeater === "*") {
          if (dynamicEvents.includes(eventTypeValue)) {
            break; // Stop calculating fixed size for dynamic events
          } else {
            break;
          }
        }

        const count =
          repeater === "" || isNaN(parseInt(repeater)) ? 1 : parseInt(repeater);
        const size = SIZE_MAP[code] || 0;
        totalSize += count * size;
      }
    }

    const result = { format: descriptiveFormat, size: totalSize };
    cache[eventTypeValue] = result;
    return result;
  }

  /**
   * Unpacks a binary blob into an array of event objects.
   * This is the reverse operation of the packer and is used to read events from the engine.
   * * @param {Buffer} eventsBlob
   * @returns {Array<Object>} Array of event objects
   */
  static unpack(eventsBlob) {
    const events = [];
    const blobLength = eventsBlob.length;
    if (blobLength < 8) {
      return [];
    } // Need at least count(4) + padding(4)

    // UNPACK COUNT + SKIP PADDING
    const eventCount = eventsBlob.readUInt32LE(0);
    // Bytes 4-7 are padding, so we start reading events at offset 8
    let offset = 8;

    for (let i = 0; i < eventCount; i++) {
      // ALIGNMENT FIX: Header is now 16 bytes (4+8+4)
      const headerSize = 16;
      if (offset + headerSize > blobLength) {
        break;
      }

      const eventType = eventsBlob.readUInt32LE(offset);
      // const timestamp = eventsBlob.readBigUInt64LE(offset + 4); // Reserved
      offset += headerSize;

      // --- Variable Event Handling ---
      if (eventType === Events.SPRITE_TEXTURE_LOAD) {
        // qid1(8)/qid2(8)/filenameLength(4)/x4padding(4) = 24 bytes
        const fixedPartSize = 24;
        if (offset + fixedPartSize > blobLength) break;

        const id1 = eventsBlob.readBigInt64LE(offset);
        const id2 = eventsBlob.readBigInt64LE(offset + 8);
        const filenameLength = eventsBlob.readUInt32LE(offset + 16);
        offset += fixedPartSize;

        // String Padding
        const strPadding = (8 - (filenameLength % 8)) % 8;
        if (offset + filenameLength + strPadding > blobLength) break;

        let filename = "";
        if (filenameLength > 0) {
          filename = eventsBlob.toString(
            "utf8",
            offset,
            offset + filenameLength,
          );
        }
        offset += filenameLength + strPadding;

        events.push({ type: eventType, id1, id2, filenameLength, filename });
      } else if (eventType === Events.PLUGIN_LOAD) {
        // Map: VchannelNo/VpathLength/a*path
        // V(4) + V(4) = 8 bytes
        const fixedPartSize = 8;
        if (offset + fixedPartSize > blobLength) break;

        const channelNo = eventsBlob.readUInt32LE(offset);
        const pathLength = eventsBlob.readUInt32LE(offset + 4);
        offset += fixedPartSize;

        const strPadding = (8 - (pathLength % 8)) % 8;
        if (offset + pathLength + strPadding > blobLength) break;

        let pathStr = "";
        if (pathLength > 0) {
          pathStr = eventsBlob.toString("utf8", offset, offset + pathLength);
        }
        offset += pathLength + strPadding;

        events.push({ type: eventType, channelNo, pathLength, path: pathStr });
      } else if (eventType === Events.AUDIO_LOAD) {
        // Map: VpathLength/a*path
        // V(4) = 4 bytes. NO PADDING defined in map between Length and String.
        // However, we must align the *string* after reading it.
        const fixedPartSize = 4;
        if (offset + fixedPartSize > blobLength) break;

        const pathLength = eventsBlob.readUInt32LE(offset);
        offset += fixedPartSize;

        const strPadding = (8 - (pathLength % 8)) % 8;
        if (offset + pathLength + strPadding > blobLength) break;

        let pathStr = "";
        if (pathLength > 0) {
          pathStr = eventsBlob.toString("utf8", offset, offset + pathLength);
        }
        offset += pathLength + strPadding;

        events.push({ type: eventType, pathLength, path: pathStr });
      } else if (eventType === Events.TEXT_ADD) {
        // Custom large struct: 64 bytes
        const fixedPartSize = 64;
        if (offset + fixedPartSize > blobLength) break;

        // Read struct manually or via helper
        // qid1/qid2/epositionX/epositionY/epositionZ/Cr/Cg/Cb/Ca/x4/gfontSize/VfontPathLength/VtextLength/x4
        let tempOff = offset;
        const id1 = eventsBlob.readBigInt64LE(tempOff);
        tempOff += 8;
        const id2 = eventsBlob.readBigInt64LE(tempOff);
        tempOff += 8;
        // ... skip reading all properties for unpack unless specifically needed for JS logic side
        // For typical game logic, we mostly need IDs or specific return values from engine.
        // But let's read lengths to skip string data correctly.

        const fontPathLength = eventsBlob.readUInt32LE(offset + 52);
        const textLength = eventsBlob.readUInt32LE(offset + 56);
        offset += fixedPartSize;

        // Font Path
        let fpPadding = (8 - (fontPathLength % 8)) % 8;
        if (offset + fontPathLength + fpPadding > blobLength) break;
        // const fontPath = eventsBlob.toString('utf8', offset, offset + fontPathLength);
        offset += fontPathLength + fpPadding;

        // Text
        let txtPadding = (8 - (textLength % 8)) % 8;
        if (offset + textLength + txtPadding > blobLength) break;
        // const text = eventsBlob.toString('utf8', offset, offset + textLength);
        offset += textLength + txtPadding;

        events.push({ type: eventType, id1, id2 });
      } else if (eventType === Events.TEXT_SET_STRING) {
        const fixedPartSize = 24;
        if (offset + fixedPartSize > blobLength) break;

        const id1 = eventsBlob.readBigInt64LE(offset);
        const id2 = eventsBlob.readBigInt64LE(offset + 8);
        const textLength = eventsBlob.readUInt32LE(offset + 16);
        offset += fixedPartSize;

        const strPadding = (8 - (textLength % 8)) % 8;
        if (offset + textLength + strPadding > blobLength) break;
        offset += textLength + strPadding;

        events.push({ type: eventType, id1, id2 });
      } else {
        // --- Fixed Size Handling ---
        const payloadInfo = this.getInfo(eventType);

        if (payloadInfo) {
          const payloadSize = payloadInfo.size;
          if (offset + payloadSize > blobLength) break;

          // Only unpack data if we need it in JS (e.g., Input, Window Resize, Physics Sync)
          // We need a generic unpacker here based on format string
          const eventData = this.unpackPayload(
            eventsBlob,
            offset,
            payloadInfo.format,
          );
          eventData.type = eventType;
          events.push(eventData);

          offset += payloadSize;
        } else {
          // Unknown event type, can't skip safely without size info
          console.warn(`Unknown event type ${eventType} in stream.`);
          break;
        }
      }

      // ALIGNMENT FIX: Skip trailing padding for the whole event
      const padding = (8 - (offset % 8)) % 8;
      offset += padding;
    }
    return events;
  }

  /**
   * Helper to unpack a specific format string from a buffer.
   * * @param {Buffer} buffer
   * @param {number} offset
   * @param {string} format
   */
  static unpackPayload(buffer, offset, format) {
    const result = {};
    const parts = format.split("/");
    let currentOffset = offset;

    for (const part of parts) {
      const match = part.match(/^([a-zA-Z])(\*|\d*)(.*)/);
      if (!match) continue;

      const code = match[1];
      const countStr = match[2];
      const name = match[3]; // Variable name
      const count =
        countStr === "" || isNaN(parseInt(countStr)) ? 1 : parseInt(countStr);

      // Only process named fields (skip padding 'x')
      if (code === "x") {
        currentOffset += count;
        continue;
      }

      // We currently assume count=1 for simplicity in receiving events from Engine -> JS
      // Most complex arrays (like strings) are handled in the custom blocks above.
      // Simple structs usually have count 1 for basic types.

      let value;
      switch (code) {
        case "c":
          value = buffer.readInt8(currentOffset);
          currentOffset += 1;
          break;
        case "C":
          value = buffer.readUInt8(currentOffset);
          currentOffset += 1;
          break;
        case "s":
          value = buffer.readInt16LE(currentOffset);
          currentOffset += 2;
          break;
        case "S":
        case "n":
        case "v":
          value = buffer.readUInt16LE(currentOffset);
          currentOffset += 2;
          break;
        case "l":
        case "i":
          value = buffer.readInt32LE(currentOffset);
          currentOffset += 4;
          break;
        case "L":
        case "V":
        case "I":
        case "N":
          value = buffer.readUInt32LE(currentOffset);
          currentOffset += 4;
          break;
        case "q":
          value = buffer.readBigInt64LE(currentOffset);
          currentOffset += 8;
          break;
        case "Q":
        case "J":
        case "P":
          value = buffer.readBigUInt64LE(currentOffset);
          currentOffset += 8;
          break;
        case "f":
        case "g":
          value = buffer.readFloatLE(currentOffset);
          currentOffset += 4;
          break;
        case "d":
        case "e":
        case "E":
          value = buffer.readDoubleLE(currentOffset);
          currentOffset += 8;
          break;
        case "a":
          // Fixed string buffer (like WINDOW_TITLE a256)
          value = buffer
            .toString("utf8", currentOffset, currentOffset + count)
            .replace(/\0/g, "");
          currentOffset += count;
          break;
        default:
          // Skip unknown size
          break;
      }

      if (name) {
        result[name] = value;
      }
    }
    return result;
  }
}

module.exports = { PackFormat, EVENT_FORMAT_MAP };
