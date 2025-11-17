<?php

namespace Phrost;

/**
 * Manages a single Audio track using a "retained mode" state.
 *
 * This class tracks its own state and generates a list of commands
 * when packDirtyEvents() is called.
 */
class Audio
{
    public readonly string $path;
    private ?int $audioId = null;
    private bool $isLoaded = false;

    /**
     * Flag to track if the initial AUDIO_LOAD command has been sent.
     * This is the equivalent of Sprite's `$isNew`.
     */
    private bool $loadCommandSent = false;

    private float $volume = 1.0;

    /**
     * Stores which properties have changed since the last event pack.
     */
    protected array $dirtyFlags = [];

    /**
     * @param string $path The absolute path to the audio file.
     * @param float $initialVolume The initial volume (0.0 to 1.0).
     */
    public function __construct(string $path, float $initialVolume = 1.0)
    {
        $this->path = $path;
        $this->volume = $initialVolume;
    }

    /**
     * Call this when you receive the AUDIO_LOADED event from the engine
     * to notify this object of its engine-side ID.
     *
     * This is the "hydration" step.
     */
    public function setLoadedId(int $audioId): void
    {
        $this->audioId = $audioId;
        $this->isLoaded = true;

        // If volume was set before loading was confirmed,
        // flag it as dirty to sync with the engine.
        if ($this->volume !== 1.0) {
            $this->dirtyFlags["volume"] = true;
        }
    }

    public function isLoaded(): bool
    {
        return $this->isLoaded;
    }

    public function getAudioId(): ?int
    {
        return $this->audioId;
    }

    public function getVolume(): float
    {
        return $this->volume;
    }

    /**
     * Queues this audio file to be loaded by the engine.
     * This only needs to be called once.
     */
    public function load(bool $notifyEngine = true): void
    {
        if (!$this->loadCommandSent) {
            if ($notifyEngine) {
                $this->dirtyFlags["load"] = true;
            }
            // We set this immediately to prevent multiple load commands
            // from being queued, even if notifyEngine is false.
            $this->loadCommandSent = true;
        }
    }

    /**
     * Queues a command to play this audio.
     */
    public function play(bool $notifyEngine = true): void
    {
        if ($this->isLoaded && $notifyEngine) {
            $this->dirtyFlags["play"] = true;
            // Play overrides pause
            unset($this->dirtyFlags["pause"], $this->dirtyFlags["stop"]);
        }
    }

    /**
     * Queues a command to pause this audio.
     */
    public function pause(bool $notifyEngine = true): void
    {
        if ($this->isLoaded && $notifyEngine) {
            $this->dirtyFlags["pause"] = true;
            // Pause overrides play
            unset($this->dirtyFlags["play"], $this->dirtyFlags["stop"]);
        }
    }

    /**
     * Queues a command to stop and rewind this audio.
     */
    public function stop(bool $notifyEngine = true): void
    {
        if ($this->isLoaded && $notifyEngine) {
            $this->dirtyFlags["stop"] = true;
            // Stop overrides play and pause
            unset($this->dirtyFlags["play"], $this->dirtyFlags["pause"]);
        }
    }

    /**
     * Queues a command to set the volume for this specific sound.
     *
     * @param float $volume (e.g., 0.0 to 1.0)
     */
    public function setVolume(float $volume, bool $notifyEngine = true): void
    {
        $newVolume = max(0.0, $volume);
        if ($this->volume !== $newVolume) {
            $this->volume = $newVolume;
            if ($this->isLoaded && $notifyEngine) {
                $this->dirtyFlags["volume"] = true;
            }
        }
    }

    /**
     * Queues a command to unload this audio, freeing engine memory.
     * Resets this object's state.
     */
    public function unload(bool $notifyEngine = true): void
    {
        if ($this->isLoaded) {
            if ($notifyEngine) {
                $this->dirtyFlags["unload"] = true;
            }
        }

        // Reset the local state regardless of notifyEngine
        // This makes the object reusable.
        $this->isLoaded = false;
        $this->loadCommandSent = false; // Can be loaded again
        $this->audioId = null;
        $this->volume = 1.0;
    }

    /**
     * Checks all dirty flags and adds the corresponding events
     * to the CommandPacker.
     */
    public function packDirtyEvents(
        ChannelPacker $packer,
        bool $clear = true,
    ): void {
        if (empty($this->dirtyFlags)) {
            return; // Nothing to do
        }

        // Handle Unload first, as it invalidates all other commands
        if (isset($this->dirtyFlags["unload"])) {
            $packer->add(Channels::RENDERER->value, Events::AUDIO_UNLOAD, [
                $this->audioId,
            ]);
            if ($clear) {
                $this->clearDirtyFlags();
            }
            return; // Don't pack any other commands
        }

        // Handle Load (only if not loaded)
        if (isset($this->dirtyFlags["load"])) {
            $packer->add(Channels::RENDERER->value, Events::AUDIO_LOAD, [
                strlen($this->path),
                $this->path,
            ]);
        }

        // --- Other commands only apply if the audio is loaded ---
        if (!$this->isLoaded) {
            if ($clear) {
                // Clear only the 'load' flag, keep other flags (like 'volume')
                // so they can be applied once setLoadedId() is called.
                unset($this->dirtyFlags["load"]);
            }
            return;
        }

        // Handle play/pause/stop (mutually exclusive)
        if (isset($this->dirtyFlags["stop"])) {
            $packer->add(Channels::RENDERER->value, Events::AUDIO_STOP, [
                $this->audioId,
            ]);
        } elseif (isset($this->dirtyFlags["pause"])) {
            $packer->add(Channels::RENDERER->value, Events::AUDIO_PAUSE, [
                $this->audioId,
            ]);
        } elseif (isset($this->dirtyFlags["play"])) {
            $packer->add(Channels::RENDERER->value, Events::AUDIO_PLAY, [
                $this->audioId,
            ]);
        }

        // Handle volume
        if (isset($this->dirtyFlags["volume"])) {
            $packer->add(Channels::RENDERER->value, Events::AUDIO_SET_VOLUME, [
                $this->audioId,
                $this->volume,
            ]);
        }

        if ($clear) {
            $this->clearDirtyFlags();
        }
    }

    public function clearDirtyFlags(): void
    {
        $this->dirtyFlags = [];
    }

    /**
     * Stops all currently playing audio.
     */
    public static function stopAll(ChannelPacker $packer): void
    {
        $packer->add(Channels::RENDERER->value, Events::AUDIO_STOP_ALL, []);
    }

    /**
     * Sets the master volume for all audio.
     * @param float $volume (e.g., 0.0 to 1.0)
     */
    public static function setMasterVolume(
        ChannelPacker $packer,
        float $volume,
    ): void {
        $packer->add(
            Channels::RENDERER->value,
            Events::AUDIO_SET_MASTER_VOLUME,
            [$volume],
        );
    }
}
