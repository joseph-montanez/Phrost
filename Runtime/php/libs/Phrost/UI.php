<?php

namespace Phrost;

class UI
{
    // Flags for ImGui (You can expand this list based on cimgui.h)
    public const WINDOW_FLAGS_NONE = 0;
    public const WINDOW_FLAGS_NO_RESIZE = 2;
    public const WINDOW_FLAGS_NO_MOVE = 4;
    public const WINDOW_FLAGS_NO_TITLE_BAR = 1;

    // Stores IDs clicked this frame: [id => true]
    private static array $clickedIds = [];

    /**
     * Call this at the start of Phrost_Update with the unpacked events.
     * It filters out UI interactions so widgets can check them later.
     */
    public static function processEvents(array $events): void
    {
        self::$clickedIds = [];
        foreach ($events as $event) {
            if (
                isset($event["type"]) &&
                $event["type"] === Events::UI_ELEMENT_CLICKED->value
            ) {
                self::$clickedIds[$event["elementId"]] = true;
            }
        }
    }

    /**
     * Starts a new window.
     * @param ChannelPacker $packer
     * @param string $title Window Title
     * @param float $x Position X (-1 for auto)
     * @param float $y Position Y (-1 for auto)
     * @param float $w Width (0 for auto)
     * @param float $h Height (0 for auto)
     * @param int $flags Window flags
     */
    public static function beginWindow(
        ChannelPacker $packer,
        string $title,
        float $x = -1.0,
        float $y = -1.0,
        float $w = 0.0,
        float $h = 0.0,
        int $flags = 0,
    ): void {
        $packer->add(Channels::RENDERER->value, Events::UI_BEGIN_WINDOW, [
            $x,
            $y,
            $w,
            $h,
            $flags,
            strlen($title),
            $title,
        ]);
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
