<?php

namespace Phrost;

class Window
{
    // --- Private State Properties ---
    private string $title = "Phrost";
    private array $size = ["width" => 800, "height" => 600];

    /**
     * Stores the boolean state of all flags.
     */
    private array $flags = [
        "fullscreen" => false,
        "opengl" => false,
        "occluded" => false,
        "hidden" => false,
        "borderless" => false,
        "resizable" => false,
        "minimized" => false,
        "maximized" => false,
        "mouse_grabbed" => false,
        "input_focus" => false,
        "mouse_focus" => false,
        "external" => false,
        "modal" => false,
        "high_pixel_density" => false,
        "mouse_capture" => false,
        "mouse_relative_mode" => false,
        "always_on_top" => false,
        "utility" => false,
        "tooltip" => false,
        "popup_menu" => false,
        "keyboard_grabbed" => false,
        "vulkan" => false,
        "metal" => false,
        "transparent" => false,
        "not_focusable" => false,
    ];

    /**
     * Stores which properties have changed.
     */
    private array $dirtyFlags = [];

    /**
     * Flag to track if this is the first update,
     * so we send all initial state events.
     */
    private bool $isNew = true;

    // --- Constructor ---
    public function __construct(string $title, int $width, int $height)
    {
        $this->title = $title;
        $this->size["width"] = $width;
        $this->size["height"] = $height;
    }

    // --- Setters (with Dirty Tracking) ---

    public function setTitle(string $newTitle, bool $notifyEngine = true): void
    {
        if ($this->title !== $newTitle) {
            $this->title = $newTitle;
            if ($notifyEngine) {
                $this->dirtyFlags["title"] = true;
            }
        }
    }

    public function setSize(
        int $width,
        int $height,
        bool $notifyEngine = true,
    ): void {
        if (
            $this->size["width"] !== $width ||
            $this->size["height"] !== $height
        ) {
            $this->size["width"] = $width;
            $this->size["height"] = $height;
            if ($notifyEngine) {
                $this->dirtyFlags["resize"] = true;
            }
        }
    }

    // --- Flag Setters (Examples) ---

    public function setResizable(bool $enabled, bool $notifyEngine = true): void
    {
        if ($this->flags["resizable"] !== $enabled) {
            $this->flags["resizable"] = $enabled;
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    public function setFullscreen(
        bool $enabled,
        bool $notifyEngine = true,
    ): void {
        if ($this->flags["fullscreen"] !== $enabled) {
            $this->flags["fullscreen"] = $enabled;
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    public function setBorderless(
        bool $enabled,
        bool $notifyEngine = true,
    ): void {
        if ($this->flags["borderless"] !== $enabled) {
            $this->flags["borderless"] = $enabled;
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    public function setHidden(bool $enabled, bool $notifyEngine = true): void
    {
        if ($this->flags["hidden"] !== $enabled) {
            $this->flags["hidden"] = $enabled;
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    public function setMouseGrabbed(
        bool $enabled,
        bool $notifyEngine = true,
    ): void {
        if ($this->flags["mouse_grabbed"] !== $enabled) {
            $this->flags["mouse_grabbed"] = $enabled;
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    /**
     * Generic setter to toggle any flag by its string name.
     */
    public function toggleFlag(
        string $flagName,
        bool $notifyEngine = true,
    ): void {
        if (array_key_exists($flagName, $this->flags)) {
            $this->flags[$flagName] = !$this->flags[$flagName];
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    /**
     * Generic setter to enable/disable any flag by its string name.
     */
    public function setFlag(
        string $flagName,
        bool $enabled,
        bool $notifyEngine = true,
    ): void {
        if (
            array_key_exists($flagName, $this->flags) &&
            $this->flags[$flagName] !== $enabled
        ) {
            $this->flags[$flagName] = $enabled;
            if ($notifyEngine) {
                $this->dirtyFlags["flags"] = true;
            }
        }
    }

    // --- Getters ---

    public function getTitle(): string
    {
        return $this->title;
    }
    public function getSize(): array
    {
        return $this->size;
    }
    public function isFlagEnabled(string $flagName): bool
    {
        return $this->flags[$flagName] ?? false;
    }

    /**
     * Calculates the complete bitmask from all boolean flags.
     */
    private function calculateFlagsBitmask(): int
    {
        $mask = 0;

        // This MUST match the order and names in your $flags array
        // and your WindowFlags class

        if ($this->flags["fullscreen"]) {
            $mask |= WindowFlags::FULLSCREEN;
        }
        if ($this->flags["opengl"]) {
            $mask |= WindowFlags::OPENGL;
        }
        if ($this->flags["occluded"]) {
            $mask |= WindowFlags::OCCLUDED;
        }
        if ($this->flags["hidden"]) {
            $mask |= WindowFlags::HIDDEN;
        }
        if ($this->flags["borderless"]) {
            $mask |= WindowFlags::BORDERLESS;
        }
        if ($this->flags["resizable"]) {
            $mask |= WindowFlags::RESIZABLE;
        }
        if ($this->flags["minimized"]) {
            $mask |= WindowFlags::MINIMIZED;
        }
        if ($this->flags["maximized"]) {
            $mask |= WindowFlags::MAXIMIZED;
        }
        if ($this->flags["mouse_grabbed"]) {
            $mask |= WindowFlags::MOUSE_GRABBED;
        }
        if ($this->flags["input_focus"]) {
            $mask |= WindowFlags::INPUT_FOCUS;
        }
        if ($this->flags["mouse_focus"]) {
            $mask |= WindowFlags::MOUSE_FOCUS;
        }
        if ($this->flags["external"]) {
            $mask |= WindowFlags::EXTERNAL;
        }
        if ($this->flags["modal"]) {
            $mask |= WindowFlags::MODAL;
        }
        if ($this->flags["high_pixel_density"]) {
            $mask |= WindowFlags::HIGH_PIXEL_DENSITY;
        }
        if ($this->flags["mouse_capture"]) {
            $mask |= WindowFlags::MOUSE_CAPTURE;
        }
        if ($this->flags["mouse_relative_mode"]) {
            $mask |= WindowFlags::MOUSE_RELATIVE_MODE;
        }
        if ($this->flags["always_on_top"]) {
            $mask |= WindowFlags::ALWAYS_ON_TOP;
        }
        if ($this->flags["utility"]) {
            $mask |= WindowFlags::UTILITY;
        }
        if ($this->flags["tooltip"]) {
            $mask |= WindowFlags::TOOLTIP;
        }
        if ($this->flags["popup_menu"]) {
            $mask |= WindowFlags::POPUP_MENU;
        }
        if ($this->flags["keyboard_grabbed"]) {
            $mask |= WindowFlags::KEYBOARD_GRABBED;
        }
        if ($this->flags["vulkan"]) {
            $mask |= WindowFlags::VULKAN;
        }
        if ($this->flags["metal"]) {
            $mask |= WindowFlags::METAL;
        }
        if ($this->flags["transparent"]) {
            $mask |= WindowFlags::TRANSPARENT;
        }
        if ($this->flags["not_focusable"]) {
            $mask |= WindowFlags::NOT_FOCUSABLE;
        }

        return $mask;
    }

    // --- Event Generation ---

    public function packDirtyEvents(ChannelPacker $packer): void
    {
        // --- Handle "isNew" flag first ---
        if ($this->isNew) {
            // Send all initial state
            $packer->add(Channels::RENDERER->value, Events::WINDOW_TITLE, [
                $this->title,
            ]);
            $packer->add(Channels::RENDERER->value, Events::WINDOW_RESIZE, [
                $this->size["width"],
                $this->size["height"],
            ]);
            $packer->add(Channels::RENDERER->value, Events::WINDOW_FLAGS, [
                $this->calculateFlagsBitmask(),
            ]);

            $this->isNew = false;
            $this->clearDirtyFlags();
            return;
        }

        // --- REGULAR DIRTY CHECK ---
        if (empty($this->dirtyFlags)) {
            return; // Nothing to do
        }

        if (isset($this->dirtyFlags["title"])) {
            $packer->add(Channels::RENDERER->value, Events::WINDOW_TITLE, [
                $this->title,
            ]);
        }

        if (isset($this->dirtyFlags["resize"])) {
            $packer->add(Channels::RENDERER->value, Events::WINDOW_RESIZE, [
                $this->size["width"],
                $this->size["height"],
            ]);
        }

        if (isset($this->dirtyFlags["flags"])) {
            // As requested, send the *complete* bitmask if any flag changes
            $packer->add(Channels::RENDERER->value, Events::WINDOW_FLAGS, [
                $this->calculateFlagsBitmask(),
            ]);
        }

        $this->clearDirtyFlags();
    }

    public function clearDirtyFlags(): void
    {
        $this->dirtyFlags = [];
    }
}
