<?php

namespace Phrost;

final class Keycode
{
    private function __construct() {}
    public const SCANCODE_MASK = 1 << 30;
    public const EXTENDED_MASK = 1 << 29;
    public static function fromScancode(Scancode $scancode): int
    {
        return $scancode->value | self::SCANCODE_MASK;
    }
    public const UNKNOWN = 0;
    public const RETURN = 13;
    public const ESCAPE = 27;
    public const BACKSPACE = 8;
    public const TAB = 9;
    public const SPACE = 32;
    public const EXCLAIM = 33;
    public const DBLAPOSTROPHE = 34;
    public const HASH = 35;
    public const DOLLAR = 36;
    public const PERCENT = 37;
    public const AMPERSAND = 38;
    public const APOSTROPHE = 39;
    public const LEFTPAREN = 40;
    public const RIGHTPAREN = 41;
    public const ASTERISK = 42;
    public const PLUS = 43;
    public const COMMA = 44;
    public const MINUS = 45;
    public const PERIOD = 46;
    public const SLASH = 47;
    public const KEY_0 = 48;
    public const KEY_1 = 49;
    public const KEY_2 = 50;
    public const KEY_3 = 51;
    public const KEY_4 = 52;
    public const KEY_5 = 53;
    public const KEY_6 = 54;
    public const KEY_7 = 55;
    public const KEY_8 = 56;
    public const KEY_9 = 57;
    public const COLON = 58;
    public const SEMICOLON = 59;
    public const LESS = 60;
    public const EQUALS = 61;
    public const GREATER = 62;
    public const QUESTION = 63;
    public const AT = 64;
    public const LEFTBRACKET = 91;
    public const BACKSLASH = 92;
    public const RIGHTBRACKET = 93;
    public const CARET = 94;
    public const UNDERSCORE = 95;
    public const GRAVE = 96;
    public const A = 97;
    public const B = 98;
    public const C = 99;
    public const D = 100;
    public const E = 101;
    public const F = 102;
    public const G = 103;
    public const H = 104;
    public const I = 105;
    public const J = 106;
    public const K = 107;
    public const L = 108;
    public const M = 109;
    public const N = 110;
    public const O = 111;
    public const P = 112;
    public const Q = 113;
    public const R = 114;
    public const S = 115;
    public const T = 116;
    public const U = 117;
    public const V = 118;
    public const W = 119;
    public const X = 120;
    public const Y = 121;
    public const Z = 122;
    public const LEFTBRACE = 123;
    public const PIPE = 124;
    public const RIGHTBRACE = 125;
    public const TILDE = 126;
    public const DELETE = 127;
    public const PLUSMINUS = 177;
    public const CAPSLOCK = self::SCANCODE_MASK | Scancode::CAPSLOCK->value;
    public const F1 = self::SCANCODE_MASK | Scancode::F1->value;
    public const F2 = self::SCANCODE_MASK | Scancode::F2->value;
    public const F3 = self::SCANCODE_MASK | Scancode::F3->value;
    public const F4 = self::SCANCODE_MASK | Scancode::F4->value;
    public const F5 = self::SCANCODE_MASK | Scancode::F5->value;
    public const F6 = self::SCANCODE_MASK | Scancode::F6->value;
    public const F7 = self::SCANCODE_MASK | Scancode::F7->value;
    public const F8 = self::SCANCODE_MASK | Scancode::F8->value;
    public const F9 = self::SCANCODE_MASK | Scancode::F9->value;
    public const F10 = self::SCANCODE_MASK | Scancode::F10->value;
    public const F11 = self::SCANCODE_MASK | Scancode::F11->value;
    public const F12 = self::SCANCODE_MASK | Scancode::F12->value;
    public const PRINTSCREEN =
        self::SCANCODE_MASK | Scancode::PRINTSCREEN->value;
    public const SCROLLLOCK = self::SCANCODE_MASK | Scancode::SCROLLLOCK->value;
    public const PAUSE = self::SCANCODE_MASK | Scancode::PAUSE->value;
    public const INSERT = self::SCANCODE_MASK | Scancode::INSERT->value;
    public const HOME = self::SCANCODE_MASK | Scancode::HOME->value;
    public const PAGEUP = self::SCANCODE_MASK | Scancode::PAGEUP->value;
    public const END = self::SCANCODE_MASK | Scancode::END->value;
    public const PAGEDOWN = self::SCANCODE_MASK | Scancode::PAGEDOWN->value;
    public const RIGHT = self::SCANCODE_MASK | Scancode::RIGHT->value;
    public const LEFT = self::SCANCODE_MASK | Scancode::LEFT->value;
    public const DOWN = self::SCANCODE_MASK | Scancode::DOWN->value;
    public const UP = self::SCANCODE_MASK | Scancode::UP->value;
    public const NUMLOCKCLEAR =
        self::SCANCODE_MASK | Scancode::NUMLOCKCLEAR->value;
    public const KP_DIVIDE = self::SCANCODE_MASK | Scancode::KP_DIVIDE->value;
    public const KP_MULTIPLY =
        self::SCANCODE_MASK | Scancode::KP_MULTIPLY->value;
    public const KP_MINUS = self::SCANCODE_MASK | Scancode::KP_MINUS->value;
    public const KP_PLUS = self::SCANCODE_MASK | Scancode::KP_PLUS->value;
    public const KP_ENTER = self::SCANCODE_MASK | Scancode::KP_ENTER->value;
    public const KP_1 = self::SCANCODE_MASK | Scancode::KP_1->value;
    public const KP_2 = self::SCANCODE_MASK | Scancode::KP_2->value;
    public const KP_3 = self::SCANCODE_MASK | Scancode::KP_3->value;
    public const KP_4 = self::SCANCODE_MASK | Scancode::KP_4->value;
    public const KP_5 = self::SCANCODE_MASK | Scancode::KP_5->value;
    public const KP_6 = self::SCANCODE_MASK | Scancode::KP_6->value;
    public const KP_7 = self::SCANCODE_MASK | Scancode::KP_7->value;
    public const KP_8 = self::SCANCODE_MASK | Scancode::KP_8->value;
    public const KP_9 = self::SCANCODE_MASK | Scancode::KP_9->value;
    public const KP_0 = self::SCANCODE_MASK | Scancode::KP_0->value;
    public const KP_PERIOD = self::SCANCODE_MASK | Scancode::KP_PERIOD->value;
    public const APPLICATION =
        self::SCANCODE_MASK | Scancode::APPLICATION->value;
    public const POWER = self::SCANCODE_MASK | Scancode::POWER->value;
    public const KP_EQUALS = self::SCANCODE_MASK | Scancode::KP_EQUALS->value;
    public const F13 = self::SCANCODE_MASK | Scancode::F13->value;
    public const F14 = self::SCANCODE_MASK | Scancode::F14->value;
    public const F15 = self::SCANCODE_MASK | Scancode::F15->value;
    public const F16 = self::SCANCODE_MASK | Scancode::F16->value;
    public const F17 = self::SCANCODE_MASK | Scancode::F17->value;
    public const F18 = self::SCANCODE_MASK | Scancode::F18->value;
    public const F19 = self::SCANCODE_MASK | Scancode::F19->value;
    public const F20 = self::SCANCODE_MASK | Scancode::F20->value;
    public const F21 = self::SCANCODE_MASK | Scancode::F21->value;
    public const F22 = self::SCANCODE_MASK | Scancode::F22->value;
    public const F23 = self::SCANCODE_MASK | Scancode::F23->value;
    public const F24 = self::SCANCODE_MASK | Scancode::F24->value;
    public const EXECUTE = self::SCANCODE_MASK | Scancode::EXECUTE->value;
    public const HELP = self::SCANCODE_MASK | Scancode::HELP->value;
    public const MENU = self::SCANCODE_MASK | Scancode::MENU->value;
    public const SELECT = self::SCANCODE_MASK | Scancode::SELECT->value;
    public const STOP = self::SCANCODE_MASK | Scancode::STOP->value;
    public const AGAIN = self::SCANCODE_MASK | Scancode::AGAIN->value;
    public const UNDO = self::SCANCODE_MASK | Scancode::UNDO->value;
    public const CUT = self::SCANCODE_MASK | Scancode::CUT->value;
    public const COPY = self::SCANCODE_MASK | Scancode::COPY->value;
    public const PASTE = self::SCANCODE_MASK | Scancode::PASTE->value;
    public const FIND = self::SCANCODE_MASK | Scancode::FIND->value;
    public const MUTE = self::SCANCODE_MASK | Scancode::MUTE->value;
    public const VOLUMEUP = self::SCANCODE_MASK | Scancode::VOLUMEUP->value;
    public const VOLUMEDOWN = self::SCANCODE_MASK | Scancode::VOLUMEDOWN->value;
    public const KP_COMMA = self::SCANCODE_MASK | Scancode::KP_COMMA->value;
    public const KP_EQUALSAS400 =
        self::SCANCODE_MASK | Scancode::KP_EQUALSAS400->value;
    public const ALTERASE = self::SCANCODE_MASK | Scancode::ALTERASE->value;
    public const SYSREQ = self::SCANCODE_MASK | Scancode::SYSREQ->value;
    public const CANCEL = self::SCANCODE_MASK | Scancode::CANCEL->value;
    public const CLEAR = self::SCANCODE_MASK | Scancode::CLEAR->value;
    public const PRIOR = self::SCANCODE_MASK | Scancode::PRIOR->value;
    public const RETURN2 = self::SCANCODE_MASK | Scancode::RETURN2->value;
    public const SEPARATOR = self::SCANCODE_MASK | Scancode::SEPARATOR->value;
    public const OUT = self::SCANCODE_MASK | Scancode::OUT->value;
    public const OPER = self::SCANCODE_MASK | Scancode::OPER->value;
    public const CLEARAGAIN = self::SCANCODE_MASK | Scancode::CLEARAGAIN->value;
    public const CRSEL = self::SCANCODE_MASK | Scancode::CRSEL->value;
    public const EXSEL = self::SCANCODE_MASK | Scancode::EXSEL->value;
    public const KP_00 = self::SCANCODE_MASK | Scancode::KP_00->value;
    public const KP_000 = self::SCANCODE_MASK | Scancode::KP_000->value;
    public const THOUSANDSSEPARATOR =
        self::SCANCODE_MASK | Scancode::THOUSANDSSEPARATOR->value;
    public const DECIMALSEPARATOR =
        self::SCANCODE_MASK | Scancode::DECIMALSEPARATOR->value;
    public const CURRENCYUNIT =
        self::SCANCODE_MASK | Scancode::CURRENCYUNIT->value;
    public const CURRENCYSUBUNIT =
        self::SCANCODE_MASK | Scancode::CURRENCYSUBUNIT->value;
    public const KP_LEFTPAREN =
        self::SCANCODE_MASK | Scancode::KP_LEFTPAREN->value;
    public const KP_RIGHTPAREN =
        self::SCANCODE_MASK | Scancode::KP_RIGHTPAREN->value;
    public const KP_LEFTBRACE =
        self::SCANCODE_MASK | Scancode::KP_LEFTBRACE->value;
    public const KP_RIGHTBRACE =
        self::SCANCODE_MASK | Scancode::KP_RIGHTBRACE->value;
    public const KP_TAB = self::SCANCODE_MASK | Scancode::KP_TAB->value;
    public const KP_BACKSPACE =
        self::SCANCODE_MASK | Scancode::KP_BACKSPACE->value;
    public const KP_A = self::SCANCODE_MASK | Scancode::KP_A->value;
    public const KP_B = self::SCANCODE_MASK | Scancode::KP_B->value;
    public const KP_C = self::SCANCODE_MASK | Scancode::KP_C->value;
    public const KP_D = self::SCANCODE_MASK | Scancode::KP_D->value;
    public const KP_E = self::SCANCODE_MASK | Scancode::KP_E->value;
    public const KP_F = self::SCANCODE_MASK | Scancode::KP_F->value;
    public const KP_XOR = self::SCANCODE_MASK | Scancode::KP_XOR->value;
    public const KP_POWER = self::SCANCODE_MASK | Scancode::KP_POWER->value;
    public const KP_PERCENT = self::SCANCODE_MASK | Scancode::KP_PERCENT->value;
    public const KP_LESS = self::SCANCODE_MASK | Scancode::KP_LESS->value;
    public const KP_GREATER = self::SCANCODE_MASK | Scancode::KP_GREATER->value;
    public const KP_AMPERSAND =
        self::SCANCODE_MASK | Scancode::KP_AMPERSAND->value;
    public const KP_DBLAMPERSAND =
        self::SCANCODE_MASK | Scancode::KP_DBLAMPERSAND->value;
    public const KP_VERTICALBAR =
        self::SCANCODE_MASK | Scancode::KP_VERTICALBAR->value;
    public const KP_DBLVERTICALBAR =
        self::SCANCODE_MASK | Scancode::KP_DBLVERTICALBAR->value;
    public const KP_COLON = self::SCANCODE_MASK | Scancode::KP_COLON->value;
    public const KP_HASH = self::SCANCODE_MASK | Scancode::KP_HASH->value;
    public const KP_SPACE = self::SCANCODE_MASK | Scancode::KP_SPACE->value;
    public const KP_AT = self::SCANCODE_MASK | Scancode::KP_AT->value;
    public const KP_EXCLAM = self::SCANCODE_MASK | Scancode::KP_EXCLAM->value;
    public const KP_MEMSTORE =
        self::SCANCODE_MASK | Scancode::KP_MEMSTORE->value;
    public const KP_MEMRECALL =
        self::SCANCODE_MASK | Scancode::KP_MEMRECALL->value;
    public const KP_MEMCLEAR =
        self::SCANCODE_MASK | Scancode::KP_MEMCLEAR->value;
    public const KP_MEMADD = self::SCANCODE_MASK | Scancode::KP_MEMADD->value;
    public const KP_MEMSUBTRACT =
        self::SCANCODE_MASK | Scancode::KP_MEMSUBTRACT->value;
    public const KP_MEMMULTIPLY =
        self::SCANCODE_MASK | Scancode::KP_MEMMULTIPLY->value;
    public const KP_MEMDIVIDE =
        self::SCANCODE_MASK | Scancode::KP_MEMDIVIDE->value;
    public const KP_PLUSMINUS =
        self::SCANCODE_MASK | Scancode::KP_PLUSMINUS->value;
    public const KP_CLEAR = self::SCANCODE_MASK | Scancode::KP_CLEAR->value;
    public const KP_CLEARENTRY =
        self::SCANCODE_MASK | Scancode::KP_CLEARENTRY->value;
    public const KP_BINARY = self::SCANCODE_MASK | Scancode::KP_BINARY->value;
    public const KP_OCTAL = self::SCANCODE_MASK | Scancode::KP_OCTAL->value;
    public const KP_DECIMAL = self::SCANCODE_MASK | Scancode::KP_DECIMAL->value;
    public const KP_HEXADECIMAL =
        self::SCANCODE_MASK | Scancode::KP_HEXADECIMAL->value;
    public const LCTRL = self::SCANCODE_MASK | Scancode::LCTRL->value;
    public const LSHIFT = self::SCANCODE_MASK | Scancode::LSHIFT->value;
    public const LALT = self::SCANCODE_MASK | Scancode::LALT->value;
    public const LGUI = self::SCANCODE_MASK | Scancode::LGUI->value;
    public const RCTRL = self::SCANCODE_MASK | Scancode::RCTRL->value;
    public const RSHIFT = self::SCANCODE_MASK | Scancode::RSHIFT->value;
    public const RALT = self::SCANCODE_MASK | Scancode::RALT->value;
    public const RGUI = self::SCANCODE_MASK | Scancode::RGUI->value;
    public const MODE = self::SCANCODE_MASK | Scancode::MODE->value;
    public const SLEEP = self::SCANCODE_MASK | Scancode::SLEEP->value;
    public const WAKE = self::SCANCODE_MASK | Scancode::WAKE->value;
    public const CHANNEL_INCREMENT =
        self::SCANCODE_MASK | Scancode::CHANNEL_INCREMENT->value;
    public const CHANNEL_DECREMENT =
        self::SCANCODE_MASK | Scancode::CHANNEL_DECREMENT->value;
    public const MEDIA_PLAY = self::SCANCODE_MASK | Scancode::MEDIA_PLAY->value;
    public const MEDIA_PAUSE =
        self::SCANCODE_MASK | Scancode::MEDIA_PAUSE->value;
    public const MEDIA_RECORD =
        self::SCANCODE_MASK | Scancode::MEDIA_RECORD->value;
    public const MEDIA_FAST_FORWARD =
        self::SCANCODE_MASK | Scancode::MEDIA_FAST_FORWARD->value;
    public const MEDIA_REWIND =
        self::SCANCODE_MASK | Scancode::MEDIA_REWIND->value;
    public const MEDIA_NEXT_TRACK =
        self::SCANCODE_MASK | Scancode::MEDIA_NEXT_TRACK->value;
    public const MEDIA_PREVIOUS_TRACK =
        self::SCANCODE_MASK | Scancode::MEDIA_PREVIOUS_TRACK->value;
    public const MEDIA_STOP = self::SCANCODE_MASK | Scancode::MEDIA_STOP->value;
    public const MEDIA_EJECT =
        self::SCANCODE_MASK | Scancode::MEDIA_EJECT->value;
    public const MEDIA_PLAY_PAUSE =
        self::SCANCODE_MASK | Scancode::MEDIA_PLAY_PAUSE->value;
    public const MEDIA_SELECT =
        self::SCANCODE_MASK | Scancode::MEDIA_SELECT->value;
    public const AC_NEW = self::SCANCODE_MASK | Scancode::AC_NEW->value;
    public const AC_OPEN = self::SCANCODE_MASK | Scancode::AC_OPEN->value;
    public const AC_CLOSE = self::SCANCODE_MASK | Scancode::AC_CLOSE->value;
    public const AC_EXIT = self::SCANCODE_MASK | Scancode::AC_EXIT->value;
    public const AC_SAVE = self::SCANCODE_MASK | Scancode::AC_SAVE->value;
    public const AC_PRINT = self::SCANCODE_MASK | Scancode::AC_PRINT->value;
    public const AC_PROPERTIES =
        self::SCANCODE_MASK | Scancode::AC_PROPERTIES->value;
    public const AC_SEARCH = self::SCANCODE_MASK | Scancode::AC_SEARCH->value;
    public const AC_HOME = self::SCANCODE_MASK | Scancode::AC_HOME->value;
    public const AC_BACK = self::SCANCODE_MASK | Scancode::AC_BACK->value;
    public const AC_FORWARD = self::SCANCODE_MASK | Scancode::AC_FORWARD->value;
    public const AC_STOP = self::SCANCODE_MASK | Scancode::AC_STOP->value;
    public const AC_REFRESH = self::SCANCODE_MASK | Scancode::AC_REFRESH->value;
    public const AC_BOOKMARKS =
        self::SCANCODE_MASK | Scancode::AC_BOOKMARKS->value;
    public const SOFTLEFT = self::SCANCODE_MASK | Scancode::SOFTLEFT->value;
    public const SOFTRIGHT = self::SCANCODE_MASK | Scancode::SOFTRIGHT->value;
    public const CALL = self::SCANCODE_MASK | Scancode::CALL->value;
    public const ENDCALL = self::SCANCODE_MASK | Scancode::ENDCALL->value;
    public const LEFT_TAB = self::EXTENDED_MASK | 0x01;
    public const LEVEL5_SHIFT = self::EXTENDED_MASK | 0x02;
    public const MULTI_KEY_COMPOSE = self::EXTENDED_MASK | 0x03;
    public const LMETA = self::EXTENDED_MASK | 0x04;
    public const RMETA = self::EXTENDED_MASK | 0x05;
    public const LHYPER = self::EXTENDED_MASK | 0x06;
    public const RHYPER = self::EXTENDED_MASK | 0x07;
}
