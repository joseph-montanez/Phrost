<?php

namespace Phrost;

/**
 * Manages a Text entity.
 *
 * Extends Sprite to inherit properties like position, color, and scale,
 * but overrides the event packing to send Text-specific events.
 */
class Text extends Sprite
{
    // --- Private Text State ---
    private string $textString = "";
    private string $fontPath = "";
    private float $fontSize = 12.0;

    /**
     * We use a separate 'isNew' flag to control TEXT_ADD,
     * while forcing the parent Sprite class to *never* send SPRITE_ADD.
     */
    private bool $isNewText;

    public function __construct(int $id0, int $id1, bool $isNew = true)
    {
        parent::__construct($id0, $id1, false);

        $this->isNewText = $isNew;
    }

    /**
     * Sets the text string and marks it as dirty.
     */
    public function setText(string $text, bool $notifyEngine = true): void
    {
        if ($this->textString !== $text) {
            $this->textString = $text;
            if ($notifyEngine) {
                $this->dirtyFlags["text"] = true;
            }
        }
    }

    /**
     * Sets the font properties.
     * NOTE: Based on available events, font and size can only be set at creation.
     */
    public function setFont(string $fontPath, float $fontSize): void
    {
        $this->fontPath = $fontPath;
        $this->fontSize = $fontSize;
    }

    public function getText(): string
    {
        return $this->textString;
    }

    /**
     * Generates the data array for the initial TEXT_ADD event.
     */
    public function getInitialAddData(): array
    {
        $position = $this->getPosition();
        $color = $this->getColor();
        $fontPathLength = strlen($this->fontPath);
        $textLength = strlen($this->textString);

        return [
            $this->id0,
            $this->id1,
            $position["x"],
            $position["y"],
            $position["z"],
            $color["r"],
            $color["g"],
            $color["b"],
            $color["a"],
            $this->fontSize,
            $fontPathLength,
            $textLength,
            $this->fontPath,
            $this->textString,
        ];
    }

    /**
     * Overrides the parent packDirtyEvents.
     *
     * If new, it sends TEXT_ADD.
     * If existing, it calls the parent's packer (to handle move, color, etc.)
     * and then packs its own text-specific updates.
     */
    public function packDirtyEvents(ChannelPacker $packer, $clear = true): void
    {
        if ($this->isNewText) {
            if (empty($this->fontPath)) {
                error_log(
                    "Phrost\Text: Cannot pack TEXT_ADD event, no font path was set.",
                );
                return;
            }

            // Send the full TEXT_ADD event
            $packer->add(
                Channels::RENDERER->value,
                Events::TEXT_ADD,
                $this->getInitialAddData(),
            );

            // Mark as no longer new and clear all other flags
            $this->isNewText = false;
            $this->clearDirtyFlags();
            return; // Exit
        }

        parent::packDirtyEvents($packer, false);

        if (isset($this->dirtyFlags["text"])) {
            $packer->add(Channels::RENDERER->value, Events::TEXT_SET_STRING, [
                $this->id0,
                $this->id1,
                strlen($this->textString),
                $this->textString,
            ]);
        }

        $this->clearDirtyFlags();
    }
}
