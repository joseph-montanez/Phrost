/**
 * WindowFlags Class
 * * Defines the bitmask constants for Window configuration.
 * Mapped to 64-bit integer flags.
 */
class WindowFlags {
  // Since JS numbers are doubles (53-bit integer precision), we can safely use hex up to 0x1FFFFFFFFFFFFF.
  // However, PHP defined these as 64-bit. We should use BigInt to be safe for the larger flags.

  static get FULLSCREEN() {
    return 0x0000000000000001n;
  }
  static get OPENGL() {
    return 0x0000000000000002n;
  }
  static get OCCLUDED() {
    return 0x0000000000000004n;
  }
  static get HIDDEN() {
    return 0x0000000000000008n;
  }
  static get BORDERLESS() {
    return 0x0000000000000010n;
  }
  static get RESIZABLE() {
    return 0x0000000000000020n;
  }
  static get MINIMIZED() {
    return 0x0000000000000040n;
  }
  static get MAXIMIZED() {
    return 0x0000000000000080n;
  }
  static get MOUSE_GRABBED() {
    return 0x0000000000000100n;
  }
  static get INPUT_FOCUS() {
    return 0x0000000000000200n;
  }
  static get MOUSE_FOCUS() {
    return 0x0000000000000400n;
  }
  static get EXTERNAL() {
    return 0x0000000000000800n;
  }
  static get MODAL() {
    return 0x0000000000001000n;
  }
  static get HIGH_PIXEL_DENSITY() {
    return 0x0000000000002000n;
  }
  static get MOUSE_CAPTURE() {
    return 0x0000000000004000n;
  }
  static get MOUSE_RELATIVE_MODE() {
    return 0x0000000000008000n;
  }
  static get ALWAYS_ON_TOP() {
    return 0x0000000000010000n;
  }
  static get UTILITY() {
    return 0x0000000000020000n;
  }
  static get TOOLTIP() {
    return 0x0000000000040000n;
  }
  static get POPUP_MENU() {
    return 0x0000000000080000n;
  }
  static get KEYBOARD_GRABBED() {
    return 0x0000000000100000n;
  }
  static get VULKAN() {
    return 0x0000000010000000n;
  }
  static get METAL() {
    return 0x0000000020000000n;
  }
  static get TRANSPARENT() {
    return 0x0000000040000000n;
  }
  static get NOT_FOCUSABLE() {
    return 0x0000000080000000n;
  }
}

module.exports = WindowFlags;
