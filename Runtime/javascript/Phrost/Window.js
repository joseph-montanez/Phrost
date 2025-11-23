const { Events, Channels } = require("./Events");
const WindowFlags = require("./WindowFlags");

/**
 * Window Class
 * * Manages the application window state and properties.
 * synchronizes state changes (title, size, flags) with the engine.
 */
class Window {
  /**
   * @param {string} title
   * @param {number} width
   * @param {number} height
   */
  constructor(title, width, height) {
    // --- Private State Properties ---
    this.title = title;
    this.size = { width: width, height: height };

    /**
     * Stores the boolean state of all flags.
     * @type {Object.<string, boolean>}
     */
    this.flags = {
      fullscreen: false,
      opengl: false,
      occluded: false,
      hidden: false,
      borderless: false,
      resizable: false,
      minimized: false,
      maximized: false,
      mouse_grabbed: false,
      input_focus: false,
      mouse_focus: false,
      external: false,
      modal: false,
      high_pixel_density: false,
      mouse_capture: false,
      mouse_relative_mode: false,
      always_on_top: false,
      utility: false,
      tooltip: false,
      popup_menu: false,
      keyboard_grabbed: false,
      vulkan: false,
      metal: false,
      transparent: false,
      not_focusable: false,
    };

    /**
     * Stores which properties have changed.
     * @type {Object.<string, boolean>}
     */
    this.dirtyFlags = {};

    /**
     * Flag to track if this is the first update.
     * @type {boolean}
     */
    this.isNew = true;
  }

  // --- Setters (with Dirty Tracking) ---

  /**
   * Sets the window title.
   * * @param {string} newTitle
   * @param {boolean} [notifyEngine=true]
   */
  setTitle(newTitle, notifyEngine = true) {
    if (this.title !== newTitle) {
      this.title = newTitle;
      if (notifyEngine) {
        this.dirtyFlags["title"] = true;
      }
    }
  }

  /**
   * Sets the window dimensions.
   * * @param {number} width
   * @param {number} height
   * @param {boolean} [notifyEngine=true]
   */
  setSize(width, height, notifyEngine = true) {
    if (this.size.width !== width || this.size.height !== height) {
      this.size.width = width;
      this.size.height = height;
      if (notifyEngine) {
        this.dirtyFlags["resize"] = true;
      }
    }
  }

  // --- Flag Setters (Examples) ---

  setResizable(enabled, notifyEngine = true) {
    this.setFlag("resizable", enabled, notifyEngine);
  }

  setFullscreen(enabled, notifyEngine = true) {
    this.setFlag("fullscreen", enabled, notifyEngine);
  }

  setBorderless(enabled, notifyEngine = true) {
    this.setFlag("borderless", enabled, notifyEngine);
  }

  setHidden(enabled, notifyEngine = true) {
    this.setFlag("hidden", enabled, notifyEngine);
  }

  setMouseGrabbed(enabled, notifyEngine = true) {
    this.setFlag("mouse_grabbed", enabled, notifyEngine);
  }

  /**
   * Generic setter to toggle any flag by its string name.
   * * @param {string} flagName
   * @param {boolean} [notifyEngine=true]
   */
  toggleFlag(flagName, notifyEngine = true) {
    if (this.flags.hasOwnProperty(flagName)) {
      this.flags[flagName] = !this.flags[flagName];
      if (notifyEngine) {
        this.dirtyFlags["flags"] = true;
      }
    }
  }

  /**
   * Generic setter to enable/disable any flag by its string name.
   * * @param {string} flagName
   * @param {boolean} enabled
   * @param {boolean} [notifyEngine=true]
   */
  setFlag(flagName, enabled, notifyEngine = true) {
    if (
      this.flags.hasOwnProperty(flagName) &&
      this.flags[flagName] !== enabled
    ) {
      this.flags[flagName] = enabled;
      if (notifyEngine) {
        this.dirtyFlags["flags"] = true;
      }
    }
  }

  // --- Getters ---

  getTitle() {
    return this.title;
  }
  getSize() {
    return this.size;
  }
  isFlagEnabled(flagName) {
    return this.flags[flagName] || false;
  }

  /**
   * Calculates the complete bitmask from all boolean flags.
   * * @private
   * @returns {bigint} The 64-bit bitmask.
   */
  calculateFlagsBitmask() {
    let mask = 0n;

    if (this.flags["fullscreen"]) mask |= WindowFlags.FULLSCREEN;
    if (this.flags["opengl"]) mask |= WindowFlags.OPENGL;
    if (this.flags["occluded"]) mask |= WindowFlags.OCCLUDED;
    if (this.flags["hidden"]) mask |= WindowFlags.HIDDEN;
    if (this.flags["borderless"]) mask |= WindowFlags.BORDERLESS;
    if (this.flags["resizable"]) mask |= WindowFlags.RESIZABLE;
    if (this.flags["minimized"]) mask |= WindowFlags.MINIMIZED;
    if (this.flags["maximized"]) mask |= WindowFlags.MAXIMIZED;
    if (this.flags["mouse_grabbed"]) mask |= WindowFlags.MOUSE_GRABBED;
    if (this.flags["input_focus"]) mask |= WindowFlags.INPUT_FOCUS;
    if (this.flags["mouse_focus"]) mask |= WindowFlags.MOUSE_FOCUS;
    if (this.flags["external"]) mask |= WindowFlags.EXTERNAL;
    if (this.flags["modal"]) mask |= WindowFlags.MODAL;
    if (this.flags["high_pixel_density"])
      mask |= WindowFlags.HIGH_PIXEL_DENSITY;
    if (this.flags["mouse_capture"]) mask |= WindowFlags.MOUSE_CAPTURE;
    if (this.flags["mouse_relative_mode"])
      mask |= WindowFlags.MOUSE_RELATIVE_MODE;
    if (this.flags["always_on_top"]) mask |= WindowFlags.ALWAYS_ON_TOP;
    if (this.flags["utility"]) mask |= WindowFlags.UTILITY;
    if (this.flags["tooltip"]) mask |= WindowFlags.TOOLTIP;
    if (this.flags["popup_menu"]) mask |= WindowFlags.POPUP_MENU;
    if (this.flags["keyboard_grabbed"]) mask |= WindowFlags.KEYBOARD_GRABBED;
    if (this.flags["vulkan"]) mask |= WindowFlags.VULKAN;
    if (this.flags["metal"]) mask |= WindowFlags.METAL;
    if (this.flags["transparent"]) mask |= WindowFlags.TRANSPARENT;
    if (this.flags["not_focusable"]) mask |= WindowFlags.NOT_FOCUSABLE;

    return mask;
  }

  // --- Event Generation ---

  /**
   * Packs dirty events into the packer.
   * * @param {Object} packer - ChannelPacker
   */
  packDirtyEvents(packer) {
    // --- Handle "isNew" flag first ---
    if (this.isNew) {
      // Send all initial state
      packer.add(Channels.RENDERER, Events.WINDOW_TITLE, [this.title]);
      packer.add(Channels.RENDERER, Events.WINDOW_RESIZE, [
        this.size.width,
        this.size.height,
      ]);
      packer.add(Channels.RENDERER, Events.WINDOW_FLAGS, [
        this.calculateFlagsBitmask(),
      ]);

      this.isNew = false;
      this.clearDirtyFlags();
      return;
    }

    // --- REGULAR DIRTY CHECK ---
    if (Object.keys(this.dirtyFlags).length === 0) {
      return; // Nothing to do
    }

    if (this.dirtyFlags["title"]) {
      packer.add(Channels.RENDERER, Events.WINDOW_TITLE, [this.title]);
    }

    if (this.dirtyFlags["resize"]) {
      packer.add(Channels.RENDERER, Events.WINDOW_RESIZE, [
        this.size.width,
        this.size.height,
      ]);
    }

    if (this.dirtyFlags["flags"]) {
      packer.add(Channels.RENDERER, Events.WINDOW_FLAGS, [
        this.calculateFlagsBitmask(),
      ]);
    }

    this.clearDirtyFlags();
  }

  clearDirtyFlags() {
    this.dirtyFlags = {};
  }
}

module.exports = Window;
