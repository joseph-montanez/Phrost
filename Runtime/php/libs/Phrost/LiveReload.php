<?php

namespace Phrost;

use JetBrains\PhpStorm\NoReturn;

class LiveReload
{
    protected ?string $shutdown_flag_path = null;
    protected ?string $save_path = null;
    protected bool $resetPending = false;

    /**
     * LiveReload constructor.
     *
     * @param string $shutdown_flag_path Path to the file used as a signal for shutdown/reset.
     * @param string $save_path Path to the file where the application state will be saved.
     */
    public function __construct(string $shutdown_flag_path, string $save_path)
    {
        $this->shutdown_flag_path = $shutdown_flag_path;
        $this->save_path = $save_path;
        $this->resetPending = false;
    }

    /**
     * Re-injects paths after unserialization, as they are transient.
     *
     * @param string $shutdown_flag_path Path to the file used as a signal for shutdown/reset.
     * @param string $save_path Path to the file where the application state will be saved.
     * @return void
     */
    public function setPaths(
        string $shutdown_flag_path,
        string $save_path,
    ): void {
        $this->shutdown_flag_path = $shutdown_flag_path;
        $this->save_path = $save_path;
    }

    /**
     * Checks if a hard reset is pending.
     *
     * @return bool True if a reset has been requested, false otherwise.
     */
    public function isResetPending(): bool
    {
        return $this->resetPending;
    }

    /**
     * Polls for live reload signals.
     * This method should be called repeatedly (e.g., once per frame).
     *
     * It checks for two conditions:
     * 1. If a save file exists and the state is not yet loaded, it attempts to load (wake) from it.
     * 2. If a shutdown flag file exists, it reads the content to determine whether to
     * perform a hard reset (if "reset") or a stateful save and unload.
     *
     * @param bool $isLoaded Indicates if the main application state is already loaded.
     * @return void This function may terminate the script execution with `die()`.
     */
    public function poll($isLoaded = false): void
    {
        if (!$isLoaded && is_file($this->save_path)) {
            $save_content = file_get_contents(__DIR__ . "/../save.data");

            // Check if content was read successfully AND is not empty
            if (!empty($save_content)) {
                Phrost_Wake($save_content);
            } else {
                echo "Save.data file was empty or unreadable. Starting fresh.\n";
                // Delete the bad file so we don't try again
                unlink(__DIR__ . "/../save.data");
            }
        }

        if (is_file($this->shutdown_flag_path)) {
            // Read the flag's content (e.g., "reset" or "save")
            $flagContent = trim(file_get_contents($this->shutdown_flag_path));

            // Delete the flag *immediately* so we don't loop
            unlink($this->shutdown_flag_path);

            if ($flagContent === "reset") {
                echo "Hard reset detected. Skipping save and unloading.\n";
                // We just die to force a reload. The *next* load will be clean
                // because reset() already deleted save.data.
                die("unloading"); // <-- THIS IS THE FIX
            } else {
                // Flag was empty, "save", or anything else:
                echo "Saving state before unloading...\n";
                file_put_contents($this->save_path, Phrost_Sleep());

                // This is the magic string the engine needs to see
                die("unloading");
            }
        }
    }

    /**
     * Triggers on matching event, the reset of world data
     *
     * @param array{keycode: int, mod: int} $event
     * @param int $keycode
     * @param int $mod
     * @return void
     */
    public function resetOnEvent(array $event, int $keycode, int $mod): void
    {
        if ($event["keycode"] === $keycode && $event["mod"] & $mod) {
            echo "Hard Reset Triggered! Pending for next frame.\n";
            $this->resetPending = true; // <-- JUST SET THE FLAG
        }
    }

    /**
     * Performs a hard reset of the application state.
     *
     * This involves:
     * 1. Sending commands to remove all sprites and physics bodies from the engine.
     * 2. Deleting the `save.data` file to prevent a reload from state.
     * 3. Creating the shutdown flag file with "reset" content to signal the engine.
     * 4. Clearing the pending reset flag.
     *
     * @param array $world The main world array containing 'sprites' and 'physicsBodies'.
     * @param ChannelPacker $packer The packer instance to send cleanup commands.
     * @return void
     */
    public function reset(array $world, ChannelPacker $packer): void
    {
        // Unload sprites and bodies before reset.
        foreach ($world["sprites"] as $sprite_id => $sprite) {
            $packer->add(Channels::RENDERER->value, Events::SPRITE_REMOVE, [
                $sprite->id0,
                $sprite->id1,
            ]);
        }
        foreach ($world["physicsBodies"] as $physics_body_id => $physicsBody) {
            $packer->add(
                Channels::PHYSICS->value,
                Events::PHYSICS_REMOVE_BODY,
                [$physicsBody->id0, $physicsBody->id1],
            );
        }

        if (is_file($this->save_path)) {
            unlink($this->save_path);
        }

        // Create the shutdown flag with "reset" content
        file_put_contents($this->shutdown_flag_path, "reset");

        // We are no longer pending
        $this->resetPending = false;
    }

    /**
     * Triggers on matching event, the shutdown of game engine
     *
     * @param array{keycode: int, mod: int} $event
     * @param int $keycode
     * @param int $mod
     * @return void
     */
    public function shutdownOnEvent(array $event, int $keycode, int $mod): void
    {
        $mod_match = false;

        $mod_match = $mod === Mod::NONE ?: $event["mod"] & $mod;

        if ($event["keycode"] === $keycode && $mod_match) {
            echo "Shutting down\n";
            $this->shutdown();
        }
    }

    /**
     * Triggers an immediate, hard shutdown of the entire engine.
     * Exits with a specific exit code (10) that the parent process monitors.
     */
    #[NoReturn]
    public function shutdown(): void
    {
        // Hard coded value to trigger shutdown from outside process
        exit(10);
    }
}
