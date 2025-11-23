const Sprite = require("./Sprite");
const { Events, Channels } = require("./Events");

/**
 * Text Class
 * * Manages a Text entity.
 * Extends Sprite but overrides packing to send Text-specific events.
 */
class Text extends Sprite {
  constructor(id0, id1, isNew = true) {
    // Initialize parent with isNew=false so it doesn't send SPRITE_ADD
    super(id0, id1, false);

    this.textString = "";
    this.fontPath = "";
    this.fontSize = 12.0;

    this.isNewText = isNew;
  }

  /**
   * Sets text string.
   * * @param {string} text
   * @param {boolean} [notifyEngine=true]
   */
  setText(text, notifyEngine = true) {
    if (this.textString !== text) {
      this.textString = text;
      if (notifyEngine) {
        this.dirtyFlags["text"] = true;
      }
    }
  }

  /**
   * Sets font properties.
   * * @param {string} fontPath
   * @param {number} fontSize
   */
  setFont(fontPath, fontSize) {
    this.fontPath = fontPath;
    this.fontSize = fontSize;
  }

  getText() {
    return this.textString;
  }

  /**
   * Generates data for TEXT_ADD.
   * * @returns {Array<number|string>}
   */
  getInitialAddData() {
    const pos = this.getPosition();
    const col = this.getColor();
    const fontPathLength = Buffer.byteLength(this.fontPath, "utf8");
    const textLength = Buffer.byteLength(this.textString, "utf8");

    return [
      this.id0,
      this.id1,
      pos.x,
      pos.y,
      pos.z,
      col.r,
      col.g,
      col.b,
      col.a,
      this.fontSize,
      fontPathLength,
      textLength,
      this.fontPath,
      this.textString,
    ];
  }

  /**
   * Overrides parent packDirtyEvents.
   * * @param {Object} packer
   * @param {boolean} [clear=true]
   */
  packDirtyEvents(packer, clear = true) {
    if (this.isNewText) {
      if (!this.fontPath) {
        console.error("Text: Cannot pack TEXT_ADD, no font path set.");
        return;
      }

      packer.add(Channels.RENDERER, Events.TEXT_ADD, this.getInitialAddData());

      this.isNewText = false;
      this.clearDirtyFlags();
      return;
    }

    // Call parent to handle move/color/etc
    super.packDirtyEvents(packer, false);

    if (this.dirtyFlags["text"]) {
      packer.add(Channels.RENDERER, Events.TEXT_SET_STRING, [
        this.id0,
        this.id1,
        Buffer.byteLength(this.textString, "utf8"),
        this.textString,
      ]);
    }

    if (clear) {
      this.clearDirtyFlags();
    }
  }
}

module.exports = Text;
