<?php

namespace Phrost;

/**
 * Helper class to enable fluent syntax like ->onClick(...)
 */
class UIInteraction
{
    private bool $triggered;

    public function __construct(bool $triggered)
    {
        $this->triggered = $triggered;
    }

    /**
     * Executes the callback immediately if the element was clicked.
     */
    public function onClick(callable $callback): self
    {
        if ($this->triggered) {
            $callback();
        }
        return $this;
    }
}
