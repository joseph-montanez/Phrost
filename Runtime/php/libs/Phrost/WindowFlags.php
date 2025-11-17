<?php

namespace Phrost;

final class WindowFlags
{
    private function __construct() {}
    public const FULLSCREEN = 0x0000000000000001;
    public const OPENGL = 0x0000000000000002;
    public const OCCLUDED = 0x0000000000000004;
    public const HIDDEN = 0x0000000000000008;
    public const BORDERLESS = 0x0000000000000010;
    public const RESIZABLE = 0x0000000000000020;
    public const MINIMIZED = 0x0000000000000040;
    public const MAXIMIZED = 0x0000000000000080;
    public const MOUSE_GRABBED = 0x0000000000000100;
    public const INPUT_FOCUS = 0x0000000000000200;
    public const MOUSE_FOCUS = 0x0000000000000400;
    public const EXTERNAL = 0x0000000000000800;
    public const MODAL = 0x0000000000001000;
    public const HIGH_PIXEL_DENSITY = 0x0000000000002000;
    public const MOUSE_CAPTURE = 0x0000000000004000;
    public const MOUSE_RELATIVE_MODE = 0x0000000000008000;
    public const ALWAYS_ON_TOP = 0x0000000000010000;
    public const UTILITY = 0x0000000000020000;
    public const TOOLTIP = 0x0000000000040000;
    public const POPUP_MENU = 0x0000000000080000;
    public const KEYBOARD_GRABBED = 0x0000000000100000;
    public const VULKAN = 0x0000000010000000;
    public const METAL = 0x0000000020000000;
    public const TRANSPARENT = 0x0000000040000000;
    public const NOT_FOCUSABLE = 0x0000000080000000;
}
