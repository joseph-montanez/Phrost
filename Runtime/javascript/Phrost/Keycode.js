const Scancode = require("./Scancode");

/**
 * Keycode Class
 * * Defines Keycode constants and helper methods.
 * Maps Scan Codes to Key Codes using bitmasks.
 */
class Keycode {
  static get SCANCODE_MASK() {
    return 1 << 30;
  }
  static get EXTENDED_MASK() {
    return 1 << 29;
  }

  /**
   * Converts a Scancode to a Keycode.
   * * @param {number} scancode - The Scancode value.
   * @returns {number} The resulting Keycode.
   */
  static fromScancode(scancode) {
    return scancode | this.SCANCODE_MASK;
  }

  static get UNKNOWN() {
    return 0;
  }
  static get RETURN() {
    return 13;
  }
  static get ESCAPE() {
    return 27;
  }
  static get BACKSPACE() {
    return 8;
  }
  static get TAB() {
    return 9;
  }
  static get SPACE() {
    return 32;
  }
  static get EXCLAIM() {
    return 33;
  }
  static get DBLAPOSTROPHE() {
    return 34;
  }
  static get HASH() {
    return 35;
  }
  static get DOLLAR() {
    return 36;
  }
  static get PERCENT() {
    return 37;
  }
  static get AMPERSAND() {
    return 38;
  }
  static get APOSTROPHE() {
    return 39;
  }
  static get LEFTPAREN() {
    return 40;
  }
  static get RIGHTPAREN() {
    return 41;
  }
  static get ASTERISK() {
    return 42;
  }
  static get PLUS() {
    return 43;
  }
  static get COMMA() {
    return 44;
  }
  static get MINUS() {
    return 45;
  }
  static get PERIOD() {
    return 46;
  }
  static get SLASH() {
    return 47;
  }
  static get KEY_0() {
    return 48;
  }
  static get KEY_1() {
    return 49;
  }
  static get KEY_2() {
    return 50;
  }
  static get KEY_3() {
    return 51;
  }
  static get KEY_4() {
    return 52;
  }
  static get KEY_5() {
    return 53;
  }
  static get KEY_6() {
    return 54;
  }
  static get KEY_7() {
    return 55;
  }
  static get KEY_8() {
    return 56;
  }
  static get KEY_9() {
    return 57;
  }
  static get COLON() {
    return 58;
  }
  static get SEMICOLON() {
    return 59;
  }
  static get LESS() {
    return 60;
  }
  static get EQUALS() {
    return 61;
  }
  static get GREATER() {
    return 62;
  }
  static get QUESTION() {
    return 63;
  }
  static get AT() {
    return 64;
  }
  static get LEFTBRACKET() {
    return 91;
  }
  static get BACKSLASH() {
    return 92;
  }
  static get RIGHTBRACKET() {
    return 93;
  }
  static get CARET() {
    return 94;
  }
  static get UNDERSCORE() {
    return 95;
  }
  static get GRAVE() {
    return 96;
  }
  static get A() {
    return 97;
  }
  static get B() {
    return 98;
  }
  static get C() {
    return 99;
  }
  static get D() {
    return 100;
  }
  static get E() {
    return 101;
  }
  static get F() {
    return 102;
  }
  static get G() {
    return 103;
  }
  static get H() {
    return 104;
  }
  static get I() {
    return 105;
  }
  static get J() {
    return 106;
  }
  static get K() {
    return 107;
  }
  static get L() {
    return 108;
  }
  static get M() {
    return 109;
  }
  static get N() {
    return 110;
  }
  static get O() {
    return 111;
  }
  static get P() {
    return 112;
  }
  static get Q() {
    return 113;
  }
  static get R() {
    return 114;
  }
  static get S() {
    return 115;
  }
  static get T() {
    return 116;
  }
  static get U() {
    return 117;
  }
  static get V() {
    return 118;
  }
  static get W() {
    return 119;
  }
  static get X() {
    return 120;
  }
  static get Y() {
    return 121;
  }
  static get Z() {
    return 122;
  }
  static get LEFTBRACE() {
    return 123;
  }
  static get PIPE() {
    return 124;
  }
  static get RIGHTBRACE() {
    return 125;
  }
  static get TILDE() {
    return 126;
  }
  static get DELETE() {
    return 127;
  }
  static get PLUSMINUS() {
    return 177;
  }

  static get CAPSLOCK() {
    return this.SCANCODE_MASK | Scancode.CAPSLOCK;
  }
  static get F1() {
    return this.SCANCODE_MASK | Scancode.F1;
  }
  static get F2() {
    return this.SCANCODE_MASK | Scancode.F2;
  }
  static get F3() {
    return this.SCANCODE_MASK | Scancode.F3;
  }
  static get F4() {
    return this.SCANCODE_MASK | Scancode.F4;
  }
  static get F5() {
    return this.SCANCODE_MASK | Scancode.F5;
  }
  static get F6() {
    return this.SCANCODE_MASK | Scancode.F6;
  }
  static get F7() {
    return this.SCANCODE_MASK | Scancode.F7;
  }
  static get F8() {
    return this.SCANCODE_MASK | Scancode.F8;
  }
  static get F9() {
    return this.SCANCODE_MASK | Scancode.F9;
  }
  static get F10() {
    return this.SCANCODE_MASK | Scancode.F10;
  }
  static get F11() {
    return this.SCANCODE_MASK | Scancode.F11;
  }
  static get F12() {
    return this.SCANCODE_MASK | Scancode.F12;
  }
  static get PRINTSCREEN() {
    return this.SCANCODE_MASK | Scancode.PRINTSCREEN;
  }
  static get SCROLLLOCK() {
    return this.SCANCODE_MASK | Scancode.SCROLLLOCK;
  }
  static get PAUSE() {
    return this.SCANCODE_MASK | Scancode.PAUSE;
  }
  static get INSERT() {
    return this.SCANCODE_MASK | Scancode.INSERT;
  }
  static get HOME() {
    return this.SCANCODE_MASK | Scancode.HOME;
  }
  static get PAGEUP() {
    return this.SCANCODE_MASK | Scancode.PAGEUP;
  }
  static get END() {
    return this.SCANCODE_MASK | Scancode.END;
  }
  static get PAGEDOWN() {
    return this.SCANCODE_MASK | Scancode.PAGEDOWN;
  }
  static get RIGHT() {
    return this.SCANCODE_MASK | Scancode.RIGHT;
  }
  static get LEFT() {
    return this.SCANCODE_MASK | Scancode.LEFT;
  }
  static get DOWN() {
    return this.SCANCODE_MASK | Scancode.DOWN;
  }
  static get UP() {
    return this.SCANCODE_MASK | Scancode.UP;
  }
  static get NUMLOCKCLEAR() {
    return this.SCANCODE_MASK | Scancode.NUMLOCKCLEAR;
  }
  static get KP_DIVIDE() {
    return this.SCANCODE_MASK | Scancode.KP_DIVIDE;
  }
  static get KP_MULTIPLY() {
    return this.SCANCODE_MASK | Scancode.KP_MULTIPLY;
  }
  static get KP_MINUS() {
    return this.SCANCODE_MASK | Scancode.KP_MINUS;
  }
  static get KP_PLUS() {
    return this.SCANCODE_MASK | Scancode.KP_PLUS;
  }
  static get KP_ENTER() {
    return this.SCANCODE_MASK | Scancode.KP_ENTER;
  }
  static get KP_1() {
    return this.SCANCODE_MASK | Scancode.KP_1;
  }
  static get KP_2() {
    return this.SCANCODE_MASK | Scancode.KP_2;
  }
  static get KP_3() {
    return this.SCANCODE_MASK | Scancode.KP_3;
  }
  static get KP_4() {
    return this.SCANCODE_MASK | Scancode.KP_4;
  }
  static get KP_5() {
    return this.SCANCODE_MASK | Scancode.KP_5;
  }
  static get KP_6() {
    return this.SCANCODE_MASK | Scancode.KP_6;
  }
  static get KP_7() {
    return this.SCANCODE_MASK | Scancode.KP_7;
  }
  static get KP_8() {
    return this.SCANCODE_MASK | Scancode.KP_8;
  }
  static get KP_9() {
    return this.SCANCODE_MASK | Scancode.KP_9;
  }
  static get KP_0() {
    return this.SCANCODE_MASK | Scancode.KP_0;
  }
  static get KP_PERIOD() {
    return this.SCANCODE_MASK | Scancode.KP_PERIOD;
  }
  static get APPLICATION() {
    return this.SCANCODE_MASK | Scancode.APPLICATION;
  }
  static get POWER() {
    return this.SCANCODE_MASK | Scancode.POWER;
  }
  static get KP_EQUALS() {
    return this.SCANCODE_MASK | Scancode.KP_EQUALS;
  }
  static get F13() {
    return this.SCANCODE_MASK | Scancode.F13;
  }
  static get F14() {
    return this.SCANCODE_MASK | Scancode.F14;
  }
  static get F15() {
    return this.SCANCODE_MASK | Scancode.F15;
  }
  static get F16() {
    return this.SCANCODE_MASK | Scancode.F16;
  }
  static get F17() {
    return this.SCANCODE_MASK | Scancode.F17;
  }
  static get F18() {
    return this.SCANCODE_MASK | Scancode.F18;
  }
  static get F19() {
    return this.SCANCODE_MASK | Scancode.F19;
  }
  static get F20() {
    return this.SCANCODE_MASK | Scancode.F20;
  }
  static get F21() {
    return this.SCANCODE_MASK | Scancode.F21;
  }
  static get F22() {
    return this.SCANCODE_MASK | Scancode.F22;
  }
  static get F23() {
    return this.SCANCODE_MASK | Scancode.F23;
  }
  static get F24() {
    return this.SCANCODE_MASK | Scancode.F24;
  }
  static get EXECUTE() {
    return this.SCANCODE_MASK | Scancode.EXECUTE;
  }
  static get HELP() {
    return this.SCANCODE_MASK | Scancode.HELP;
  }
  static get MENU() {
    return this.SCANCODE_MASK | Scancode.MENU;
  }
  static get SELECT() {
    return this.SCANCODE_MASK | Scancode.SELECT;
  }
  static get STOP() {
    return this.SCANCODE_MASK | Scancode.STOP;
  }
  static get AGAIN() {
    return this.SCANCODE_MASK | Scancode.AGAIN;
  }
  static get UNDO() {
    return this.SCANCODE_MASK | Scancode.UNDO;
  }
  static get CUT() {
    return this.SCANCODE_MASK | Scancode.CUT;
  }
  static get COPY() {
    return this.SCANCODE_MASK | Scancode.COPY;
  }
  static get PASTE() {
    return this.SCANCODE_MASK | Scancode.PASTE;
  }
  static get FIND() {
    return this.SCANCODE_MASK | Scancode.FIND;
  }
  static get MUTE() {
    return this.SCANCODE_MASK | Scancode.MUTE;
  }
  static get VOLUMEUP() {
    return this.SCANCODE_MASK | Scancode.VOLUMEUP;
  }
  static get VOLUMEDOWN() {
    return this.SCANCODE_MASK | Scancode.VOLUMEDOWN;
  }
  static get KP_COMMA() {
    return this.SCANCODE_MASK | Scancode.KP_COMMA;
  }
  static get KP_EQUALSAS400() {
    return this.SCANCODE_MASK | Scancode.KP_EQUALSAS400;
  }
  static get ALTERASE() {
    return this.SCANCODE_MASK | Scancode.ALTERASE;
  }
  static get SYSREQ() {
    return this.SCANCODE_MASK | Scancode.SYSREQ;
  }
  static get CANCEL() {
    return this.SCANCODE_MASK | Scancode.CANCEL;
  }
  static get CLEAR() {
    return this.SCANCODE_MASK | Scancode.CLEAR;
  }
  static get PRIOR() {
    return this.SCANCODE_MASK | Scancode.PRIOR;
  }
  static get RETURN2() {
    return this.SCANCODE_MASK | Scancode.RETURN2;
  }
  static get SEPARATOR() {
    return this.SCANCODE_MASK | Scancode.SEPARATOR;
  }
  static get OUT() {
    return this.SCANCODE_MASK | Scancode.OUT;
  }
  static get OPER() {
    return this.SCANCODE_MASK | Scancode.OPER;
  }
  static get CLEARAGAIN() {
    return this.SCANCODE_MASK | Scancode.CLEARAGAIN;
  }
  static get CRSEL() {
    return this.SCANCODE_MASK | Scancode.CRSEL;
  }
  static get EXSEL() {
    return this.SCANCODE_MASK | Scancode.EXSEL;
  }
  static get KP_00() {
    return this.SCANCODE_MASK | Scancode.KP_00;
  }
  static get KP_000() {
    return this.SCANCODE_MASK | Scancode.KP_000;
  }
  static get THOUSANDSSEPARATOR() {
    return this.SCANCODE_MASK | Scancode.THOUSANDSSEPARATOR;
  }
  static get DECIMALSEPARATOR() {
    return this.SCANCODE_MASK | Scancode.DECIMALSEPARATOR;
  }
  static get CURRENCYUNIT() {
    return this.SCANCODE_MASK | Scancode.CURRENCYUNIT;
  }
  static get CURRENCYSUBUNIT() {
    return this.SCANCODE_MASK | Scancode.CURRENCYSUBUNIT;
  }
  static get KP_LEFTPAREN() {
    return this.SCANCODE_MASK | Scancode.KP_LEFTPAREN;
  }
  static get KP_RIGHTPAREN() {
    return this.SCANCODE_MASK | Scancode.KP_RIGHTPAREN;
  }
  static get KP_LEFTBRACE() {
    return this.SCANCODE_MASK | Scancode.KP_LEFTBRACE;
  }
  static get KP_RIGHTBRACE() {
    return this.SCANCODE_MASK | Scancode.KP_RIGHTBRACE;
  }
  static get KP_TAB() {
    return this.SCANCODE_MASK | Scancode.KP_TAB;
  }
  static get KP_BACKSPACE() {
    return this.SCANCODE_MASK | Scancode.KP_BACKSPACE;
  }
  static get KP_A() {
    return this.SCANCODE_MASK | Scancode.KP_A;
  }
  static get KP_B() {
    return this.SCANCODE_MASK | Scancode.KP_B;
  }
  static get KP_C() {
    return this.SCANCODE_MASK | Scancode.KP_C;
  }
  static get KP_D() {
    return this.SCANCODE_MASK | Scancode.KP_D;
  }
  static get KP_E() {
    return this.SCANCODE_MASK | Scancode.KP_E;
  }
  static get KP_F() {
    return this.SCANCODE_MASK | Scancode.KP_F;
  }
  static get KP_XOR() {
    return this.SCANCODE_MASK | Scancode.KP_XOR;
  }
  static get KP_POWER() {
    return this.SCANCODE_MASK | Scancode.KP_POWER;
  }
  static get KP_PERCENT() {
    return this.SCANCODE_MASK | Scancode.KP_PERCENT;
  }
  static get KP_LESS() {
    return this.SCANCODE_MASK | Scancode.KP_LESS;
  }
  static get KP_GREATER() {
    return this.SCANCODE_MASK | Scancode.KP_GREATER;
  }
  static get KP_AMPERSAND() {
    return this.SCANCODE_MASK | Scancode.KP_AMPERSAND;
  }
  static get KP_DBLAMPERSAND() {
    return this.SCANCODE_MASK | Scancode.KP_DBLAMPERSAND;
  }
  static get KP_VERTICALBAR() {
    return this.SCANCODE_MASK | Scancode.KP_VERTICALBAR;
  }
  static get KP_DBLVERTICALBAR() {
    return this.SCANCODE_MASK | Scancode.KP_DBLVERTICALBAR;
  }
  static get KP_COLON() {
    return this.SCANCODE_MASK | Scancode.KP_COLON;
  }
  static get KP_HASH() {
    return this.SCANCODE_MASK | Scancode.KP_HASH;
  }
  static get KP_SPACE() {
    return this.SCANCODE_MASK | Scancode.KP_SPACE;
  }
  static get KP_AT() {
    return this.SCANCODE_MASK | Scancode.KP_AT;
  }
  static get KP_EXCLAM() {
    return this.SCANCODE_MASK | Scancode.KP_EXCLAM;
  }
  static get KP_MEMSTORE() {
    return this.SCANCODE_MASK | Scancode.KP_MEMSTORE;
  }
  static get KP_MEMRECALL() {
    return this.SCANCODE_MASK | Scancode.KP_MEMRECALL;
  }
  static get KP_MEMCLEAR() {
    return this.SCANCODE_MASK | Scancode.KP_MEMCLEAR;
  }
  static get KP_MEMADD() {
    return this.SCANCODE_MASK | Scancode.KP_MEMADD;
  }
  static get KP_MEMSUBTRACT() {
    return this.SCANCODE_MASK | Scancode.KP_MEMSUBTRACT;
  }
  static get KP_MEMMULTIPLY() {
    return this.SCANCODE_MASK | Scancode.KP_MEMMULTIPLY;
  }
  static get KP_MEMDIVIDE() {
    return this.SCANCODE_MASK | Scancode.KP_MEMDIVIDE;
  }
  static get KP_PLUSMINUS() {
    return this.SCANCODE_MASK | Scancode.KP_PLUSMINUS;
  }
  static get KP_CLEAR() {
    return this.SCANCODE_MASK | Scancode.KP_CLEAR;
  }
  static get KP_CLEARENTRY() {
    return this.SCANCODE_MASK | Scancode.KP_CLEARENTRY;
  }
  static get KP_BINARY() {
    return this.SCANCODE_MASK | Scancode.KP_BINARY;
  }
  static get KP_OCTAL() {
    return this.SCANCODE_MASK | Scancode.KP_OCTAL;
  }
  static get KP_DECIMAL() {
    return this.SCANCODE_MASK | Scancode.KP_DECIMAL;
  }
  static get KP_HEXADECIMAL() {
    return this.SCANCODE_MASK | Scancode.KP_HEXADECIMAL;
  }
  static get LCTRL() {
    return this.SCANCODE_MASK | Scancode.LCTRL;
  }
  static get LSHIFT() {
    return this.SCANCODE_MASK | Scancode.LSHIFT;
  }
  static get LALT() {
    return this.SCANCODE_MASK | Scancode.LALT;
  }
  static get LGUI() {
    return this.SCANCODE_MASK | Scancode.LGUI;
  }
  static get RCTRL() {
    return this.SCANCODE_MASK | Scancode.RCTRL;
  }
  static get RSHIFT() {
    return this.SCANCODE_MASK | Scancode.RSHIFT;
  }
  static get RALT() {
    return this.SCANCODE_MASK | Scancode.RALT;
  }
  static get RGUI() {
    return this.SCANCODE_MASK | Scancode.RGUI;
  }
  static get MODE() {
    return this.SCANCODE_MASK | Scancode.MODE;
  }
  static get SLEEP() {
    return this.SCANCODE_MASK | Scancode.SLEEP;
  }
  static get WAKE() {
    return this.SCANCODE_MASK | Scancode.WAKE;
  }
  static get CHANNEL_INCREMENT() {
    return this.SCANCODE_MASK | Scancode.CHANNEL_INCREMENT;
  }
  static get CHANNEL_DECREMENT() {
    return this.SCANCODE_MASK | Scancode.CHANNEL_DECREMENT;
  }
  static get MEDIA_PLAY() {
    return this.SCANCODE_MASK | Scancode.MEDIA_PLAY;
  }
  static get MEDIA_PAUSE() {
    return this.SCANCODE_MASK | Scancode.MEDIA_PAUSE;
  }
  static get MEDIA_RECORD() {
    return this.SCANCODE_MASK | Scancode.MEDIA_RECORD;
  }
  static get MEDIA_FAST_FORWARD() {
    return this.SCANCODE_MASK | Scancode.MEDIA_FAST_FORWARD;
  }
  static get MEDIA_REWIND() {
    return this.SCANCODE_MASK | Scancode.MEDIA_REWIND;
  }
  static get MEDIA_NEXT_TRACK() {
    return this.SCANCODE_MASK | Scancode.MEDIA_NEXT_TRACK;
  }
  static get MEDIA_PREVIOUS_TRACK() {
    return this.SCANCODE_MASK | Scancode.MEDIA_PREVIOUS_TRACK;
  }
  static get MEDIA_STOP() {
    return this.SCANCODE_MASK | Scancode.MEDIA_STOP;
  }
  static get MEDIA_EJECT() {
    return this.SCANCODE_MASK | Scancode.MEDIA_EJECT;
  }
  static get MEDIA_PLAY_PAUSE() {
    return this.SCANCODE_MASK | Scancode.MEDIA_PLAY_PAUSE;
  }
  static get MEDIA_SELECT() {
    return this.SCANCODE_MASK | Scancode.MEDIA_SELECT;
  }
  static get AC_NEW() {
    return this.SCANCODE_MASK | Scancode.AC_NEW;
  }
  static get AC_OPEN() {
    return this.SCANCODE_MASK | Scancode.AC_OPEN;
  }
  static get AC_CLOSE() {
    return this.SCANCODE_MASK | Scancode.AC_CLOSE;
  }
  static get AC_EXIT() {
    return this.SCANCODE_MASK | Scancode.AC_EXIT;
  }
  static get AC_SAVE() {
    return this.SCANCODE_MASK | Scancode.AC_SAVE;
  }
  static get AC_PRINT() {
    return this.SCANCODE_MASK | Scancode.AC_PRINT;
  }
  static get AC_PROPERTIES() {
    return this.SCANCODE_MASK | Scancode.AC_PROPERTIES;
  }
  static get AC_SEARCH() {
    return this.SCANCODE_MASK | Scancode.AC_SEARCH;
  }
  static get AC_HOME() {
    return this.SCANCODE_MASK | Scancode.AC_HOME;
  }
  static get AC_BACK() {
    return this.SCANCODE_MASK | Scancode.AC_BACK;
  }
  static get AC_FORWARD() {
    return this.SCANCODE_MASK | Scancode.AC_FORWARD;
  }
  static get AC_STOP() {
    return this.SCANCODE_MASK | Scancode.AC_STOP;
  }
  static get AC_REFRESH() {
    return this.SCANCODE_MASK | Scancode.AC_REFRESH;
  }
  static get AC_BOOKMARKS() {
    return this.SCANCODE_MASK | Scancode.AC_BOOKMARKS;
  }
  static get SOFTLEFT() {
    return this.SCANCODE_MASK | Scancode.SOFTLEFT;
  }
  static get SOFTRIGHT() {
    return this.SCANCODE_MASK | Scancode.SOFTRIGHT;
  }
  static get CALL() {
    return this.SCANCODE_MASK | Scancode.CALL;
  }
  static get ENDCALL() {
    return this.SCANCODE_MASK | Scancode.ENDCALL;
  }
  static get LEFT_TAB() {
    return this.EXTENDED_MASK | 0x01;
  }
  static get LEVEL5_SHIFT() {
    return this.EXTENDED_MASK | 0x02;
  }
  static get MULTI_KEY_COMPOSE() {
    return this.EXTENDED_MASK | 0x03;
  }
  static get LMETA() {
    return this.EXTENDED_MASK | 0x04;
  }
  static get RMETA() {
    return this.EXTENDED_MASK | 0x05;
  }
  static get LHYPER() {
    return this.EXTENDED_MASK | 0x06;
  }
  static get RHYPER() {
    return this.EXTENDED_MASK | 0x07;
  }
}

module.exports = Keycode;
