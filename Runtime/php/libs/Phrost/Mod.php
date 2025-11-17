<?php
namespace Phrost;

// This file defines the bitmask values for the 'mod' field
// in key events.
final class Mod
{
    private function __construct() {}

    public const NONE = 0x0000;
    public const LSHIFT = 0x0001;
    public const RSHIFT = 0x0002;
    public const SHIFT = 0x0003; // LSHIFT | RSHIFT
    public const LCTRL = 0x0040;
    public const RCTRL = 0x0080;
    public const CTRL = 0x00c0; // LCTRL | RCTRL
    public const LALT = 0x0100;
    public const RALT = 0x0200;
    public const ALT = 0x0300; // LALT | RALT
    public const LGUI = 0x0400; // Windows/Cmd key
    public const RGUI = 0x0800; // Windows/Cmd key
    public const GUI = 0x0c00; // LGUI | RGUI
    public const NUM = 0x1000; // Num Lock
    public const CAPS = 0x2000; // Caps Lock
    public const MODE = 0x4000; // AltGr
}
