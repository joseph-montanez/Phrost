/**
 * Mod Class
 * * Defines the bitmask values for the 'mod' field in key events.
 */
class Mod {
  static get NONE() {
    return 0x0000;
  }
  static get LSHIFT() {
    return 0x0001;
  }
  static get RSHIFT() {
    return 0x0002;
  }
  static get SHIFT() {
    return 0x0003;
  } // LSHIFT | RSHIFT
  static get LCTRL() {
    return 0x0040;
  }
  static get RCTRL() {
    return 0x0080;
  }
  static get CTRL() {
    return 0x00c0;
  } // LCTRL | RCTRL
  static get LALT() {
    return 0x0100;
  }
  static get RALT() {
    return 0x0200;
  }
  static get ALT() {
    return 0x0300;
  } // LALT | RALT
  static get LGUI() {
    return 0x0400;
  } // Windows/Cmd key
  static get RGUI() {
    return 0x0800;
  } // Windows/Cmd key
  static get GUI() {
    return 0x0c00;
  } // LGUI | RGUI
  static get NUM() {
    return 0x1000;
  } // Num Lock
  static get CAPS() {
    return 0x2000;
  } // Caps Lock
  static get MODE() {
    return 0x4000;
  } // AltGr
}

module.exports = Mod;
