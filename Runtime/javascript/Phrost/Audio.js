const { Events, Channels } = require("./Events");

/**
 * Audio Class
 * * Manages a single Audio track using a "retained mode" state.
 * Tracks its own state and generates a list of commands when packDirtyEvents() is called.
 */
class Audio {
  /**
   * @param {string} path - Absolute path to the audio file.
   * @param {number} [initialVolume=1.0]
   */
  constructor(path, initialVolume = 1.0) {
    this.path = path;
    this.volume = initialVolume;

    /** @type {?number} */
    this.audioId = null;
    this.isLoaded = false;

    /** @type {boolean} Flag for if initial load command sent */
    this.loadCommandSent = false;

    /** @type {Object.<string, boolean>} */
    this.dirtyFlags = {};
  }

  /**
   * Call this when you receive the AUDIO_LOADED event from the engine.
   * * @param {number} audioId
   */
  setLoadedId(audioId) {
    this.audioId = audioId;
    this.isLoaded = true;

    // If volume was set before loading was confirmed, sync it now.
    if (this.volume !== 1.0) {
      this.dirtyFlags["volume"] = true;
    }
  }

  /**
   * Queues this audio file to be loaded by the engine.
   * * @param {boolean} [notifyEngine=true]
   */
  load(notifyEngine = true) {
    if (!this.loadCommandSent) {
      if (notifyEngine) {
        this.dirtyFlags["load"] = true;
      }
      this.loadCommandSent = true;
    }
  }

  /**
   * Queues a command to play this audio.
   * * @param {boolean} [notifyEngine=true]
   */
  play(notifyEngine = true) {
    if (this.isLoaded && notifyEngine) {
      this.dirtyFlags["play"] = true;
      // Play overrides pause/stop
      delete this.dirtyFlags["pause"];
      delete this.dirtyFlags["stop"];
    }
  }

  /**
   * Queues a command to pause this audio.
   * * @param {boolean} [notifyEngine=true]
   */
  pause(notifyEngine = true) {
    if (this.isLoaded && notifyEngine) {
      this.dirtyFlags["pause"] = true;
      delete this.dirtyFlags["play"];
      delete this.dirtyFlags["stop"];
    }
  }

  /**
   * Queues a command to stop this audio.
   * * @param {boolean} [notifyEngine=true]
   */
  stop(notifyEngine = true) {
    if (this.isLoaded && notifyEngine) {
      this.dirtyFlags["stop"] = true;
      delete this.dirtyFlags["play"];
      delete this.dirtyFlags["pause"];
    }
  }

  /**
   * Sets volume.
   * * @param {number} volume
   * @param {boolean} [notifyEngine=true]
   */
  setVolume(volume, notifyEngine = true) {
    const newVolume = Math.max(0.0, volume);
    if (this.volume !== newVolume) {
      this.volume = newVolume;
      if (this.isLoaded && notifyEngine) {
        this.dirtyFlags["volume"] = true;
      }
    }
  }

  /**
   * Unloads the audio.
   * * @param {boolean} [notifyEngine=true]
   */
  unload(notifyEngine = true) {
    if (this.isLoaded) {
      if (notifyEngine) {
        this.dirtyFlags["unload"] = true;
      }
    }
    this.isLoaded = false;
    this.loadCommandSent = false;
    this.audioId = null;
    this.volume = 1.0;
  }

  /**
   * Packs dirty events.
   * * @param {Object} packer
   * @param {boolean} [clear=true]
   */
  packDirtyEvents(packer, clear = true) {
    if (Object.keys(this.dirtyFlags).length === 0) {
      return;
    }

    // Handle Unload first
    if (this.dirtyFlags["unload"]) {
      packer.add(Channels.RENDERER, Events.AUDIO_UNLOAD, [this.audioId]);
      if (clear) {
        this.clearDirtyFlags();
      }
      return;
    }

    // Handle Load
    if (this.dirtyFlags["load"]) {
      packer.add(Channels.RENDERER, Events.AUDIO_LOAD, [
        Buffer.byteLength(this.path, "utf8"),
        this.path,
      ]);
    }

    if (!this.isLoaded) {
      if (clear) {
        // Only clear load flag, keep others for post-hydration
        delete this.dirtyFlags["load"];
      }
      return;
    }

    // Play/Pause/Stop
    if (this.dirtyFlags["stop"]) {
      packer.add(Channels.RENDERER, Events.AUDIO_STOP, [this.audioId]);
    } else if (this.dirtyFlags["pause"]) {
      packer.add(Channels.RENDERER, Events.AUDIO_PAUSE, [this.audioId]);
    } else if (this.dirtyFlags["play"]) {
      packer.add(Channels.RENDERER, Events.AUDIO_PLAY, [this.audioId]);
    }

    // Volume
    if (this.dirtyFlags["volume"]) {
      packer.add(Channels.RENDERER, Events.AUDIO_SET_VOLUME, [
        this.audioId,
        this.volume,
      ]);
    }

    if (clear) {
      this.clearDirtyFlags();
    }
  }

  clearDirtyFlags() {
    this.dirtyFlags = {};
  }

  /**
   * Static helper to stop all audio.
   * * @param {Object} packer
   */
  static stopAll(packer) {
    packer.add(Channels.RENDERER, Events.AUDIO_STOP_ALL, []);
  }

  /**
   * Static helper to set master volume.
   * * @param {Object} packer
   * @param {number} volume
   */
  static setMasterVolume(packer, volume) {
    packer.add(Channels.RENDERER, Events.AUDIO_SET_MASTER_VOLUME, [volume]);
  }
}

module.exports = Audio;
