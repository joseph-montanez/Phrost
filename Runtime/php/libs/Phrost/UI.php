<?php

namespace Phrost;

class UI
{
    // --- Flags for ImGui ---
    public const int WINDOW_FLAGS_NONE = 0;
    public const int WINDOW_FLAGS_NO_RESIZE = 2;
    public const int WINDOW_FLAGS_NO_MOVE = 4;
    public const int WINDOW_FLAGS_NO_TITLE_BAR = 1;

    // --- Conditions for SetNextWindow* ---
    public const int COND_ALWAYS = 1; // Set the variable every frame
    public const int COND_ONCE = 2; // Set the variable once per runtime session (only the first call will succeed)
    public const int COND_FIRST_USE_EVER = 4; // Set the variable if the object/window has no persistently saved data (no entry in .ini file)
    public const int COND_APPEARING = 8; // Set the variable if the object/window is appearing after being hidden/inactive (or the first time)

    // --- State Tracking ---
    // Stores IDs clicked this frame: [id => true]
    private static array $clickedIds = [];
    // Stores Window IDs closed this frame: [id => true]
    private static array $closedWindowIds = [];

    /**
     * Call this at the start of Phrost_Update with the unpacked events.
     * It filters out UI interactions so widgets can check them later.
     */
    public static function processEvents(array $events): void
    {
        self::$clickedIds = [];
        self::$closedWindowIds = [];

        foreach ($events as $event) {
            if (!isset($event["type"])) {
                continue;
            }

            // Track Button Clicks
            if ($event["type"] === Events::UI_ELEMENT_CLICKED->value) {
                self::$clickedIds[$event["elementId"]] = true;
            }

            // Track Window Close (X button)
            if ($event["type"] === Events::UI_WINDOW_CLOSED->value) {
                self::$closedWindowIds[$event["windowId"]] = true;
            }
        }
    }

    /**
     * Check if a specific window ID was closed this frame.
     */
    public static function wasWindowClosed(int $windowId): bool
    {
        return isset(self::$closedWindowIds[$windowId]);
    }

    /**
     * Sets the position of the NEXT window to be created.
     * Call this BEFORE beginWindow().
     *
     * @param float $pivotX (0.0 = Left, 0.5 = Center, 1.0 = Right)
     * @param float $pivotY (0.0 = Top, 0.5 = Center, 1.0 = Bottom)
     */
    public static function setNextWindowPos(
        ChannelPacker $packer,
        float $x,
        float $y,
        int $condition = self::COND_ALWAYS,
        float $pivotX = 0.0,
        float $pivotY = 0.0,
    ): void {
        $packer->add(
            Channels::RENDERER->value,
            Events::UI_SET_NEXT_WINDOW_POS,
            [$x, $y, $condition, $pivotX, $pivotY],
        );
    }

    /**
     * Sets the size of the NEXT window to be created.
     * Call this BEFORE beginWindow().
     */
    public static function setNextWindowSize(
        ChannelPacker $packer,
        float $w,
        float $h,
        int $condition = self::COND_ALWAYS,
    ): void {
        $packer->add(
            Channels::RENDERER->value,
            Events::UI_SET_NEXT_WINDOW_SIZE,
            [$w, $h, $condition],
        );
    }

    /**
     * Starts a new window.
     * NOTE: Position and Size are now controlled via setNextWindowPos/Size.
     *
     * @param int $id Unique ID for this window (used for Close events).
     */
    public static function beginWindow(
        ChannelPacker $packer,
        int $id,
        string $title,
        int $flags = 0,
    ): UIInteraction {
        // <--- Return Type Changed
        $packer->add(Channels::RENDERER->value, Events::UI_BEGIN_WINDOW, [
            $id,
            $flags,
            strlen($title),
            $title,
        ]);

        // Check if this Window ID was closed this frame
        $wasClosed = isset(self::$closedWindowIds[$id]);

        return new UIInteraction($wasClosed);
    }

    /**
     * Ends the current window.
     */
    public static function endWindow(ChannelPacker $packer): void
    {
        // _unused byte required by struct
        $packer->add(Channels::RENDERER->value, Events::UI_END_WINDOW, [0]);
    }

    /**
     * Adds a text label.
     */
    public static function text(ChannelPacker $packer, string $text): void
    {
        $packer->add(Channels::RENDERER->value, Events::UI_TEXT, [
            strlen($text),
            $text,
        ]);
    }

    /**
     * Adds a button and returns an interaction handler.
     */
    public static function button(
        ChannelPacker $packer,
        int $id,
        string $label,
        float $w = 0.0,
        float $h = 0.0,
    ): UIInteraction {
        // 1. Pack the draw command
        $packer->add(Channels::RENDERER->value, Events::UI_BUTTON, [
            $id,
            $w,
            $h,
            strlen($label),
            $label,
        ]);

        // Check if this ID was clicked this frame
        $wasClicked = isset(self::$clickedIds[$id]);

        // Return helper to allow chaining ->onClick(...)
        return new UIInteraction($wasClicked);
    }
}
