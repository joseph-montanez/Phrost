const path = require("path");
const fs = require("fs");
const os = require("os");

// --- Imports ---
const Window = require("./Window");
const Camera = require("./Camera");
const ChannelPacker = require("./ChannelPacker");
const PackFormat = require("./PackFormat");
const LiveReload = require("./LiveReload");
const Id = require("./Id");
const { Events, Channels } = require("./Events");
const Keycode = require("./Keycode");
const Mod = require("./Mod");
const Sprite = require("./Sprite");
const Text = require("./Text");
const Audio = require("./Audio");

// --- Constants ---
const FPS_SAMPLE_SIZE = 60;

// --- Global State Initialization ---
const SHUTDOWN_FLAG_PATH = path.join(__dirname, "../shutdown.flag");
const SAVE_PATH = path.join(__dirname, "../save.data");

const fontPath = path.join(__dirname, "assets/Roboto-Regular.ttf");
const audioPath = path.join(__dirname, "assets/snoozy beats - neon dreams.wav");

// Create Text objects
const fpsTextId = Id.generate(); // [BigInt, BigInt]
const fpsText = new Text(fpsTextId[0], fpsTextId[1]);
fpsText.setFont(fontPath, 24.0);
fpsText.setText("FPS: ...", false);
fpsText.setPosition(10.0, 10.0, 100.0, false);
fpsText.setColor(255, 255, 255, 255, false);

const logicTextId = Id.generate();
const logicText = new Text(logicTextId[0], logicTextId[1]);
logicText.setFont(fontPath, 24.0);
logicText.setText("Logic: JS", false);
logicText.setPosition(10.0, 40.0, 100.0, false);
logicText.setColor(255, 255, 255, 255, false);

// Create Audio object
const musicTrack = new Audio(audioPath);

// The main world state object
let world = {
  window: new Window("Bunny Benchmark (JS)", 800, 450),
  camera: new Camera(800.0 / 2, 450.0 / 2),
  sprites: {}, // Map<stringHex, Sprite>
  textObjects: {
    fps: fpsText,
    logic: logicText,
  },
  musicTrack: musicTrack,
  spritesCount: 0,
  activeLogic: "JS",
  pluginLoaded: false,
  chunkSize: 0,
  inputState: {},
  mouseX: 0,
  mouseY: 0,
  fps: 0.0,
  smoothed_fps: 0.0,
  fps_samples: [],
  musicPlaying: false,
  assetsLoaded: false,
  eventStacking: true,
  liveReload: new LiveReload(SHUTDOWN_FLAG_PATH, SAVE_PATH),
  __initial_packer: new ChannelPacker(),
};

// Pack initial window setup
world.window.setResizable(true);
world.window.packDirtyEvents(world.__initial_packer);

/**
 * Called by Phrost when the state is about to be saved.
 * * @returns {string} JSON string of world state
 */
function Phrost_Sleep() {
  const worldToSave = { ...world };
  delete worldToSave.__initial_packer; // Don't save the packer

  // We use a custom replacer or just rely on standard serialization.
  // Since JS classes lose methods on JSON.stringify, we hydrate them in Wake.
  return JSON.stringify(worldToSave);
}

/**
 * Called by Phrost to restore the state.
 * * @param {string} data - JSON string
 */
function Phrost_Wake(data) {
  try {
    const savedWorld = JSON.parse(data);

    // Restore primitives
    world.spritesCount = savedWorld.spritesCount || 0;
    world.activeLogic = savedWorld.activeLogic || "JS";
    world.pluginLoaded = savedWorld.pluginLoaded;
    world.chunkSize = savedWorld.chunkSize;
    world.inputState = savedWorld.inputState || {};
    world.mouseX = savedWorld.mouseX;
    world.mouseY = savedWorld.mouseY;
    world.musicPlaying = savedWorld.musicPlaying;
    world.assetsLoaded = savedWorld.assetsLoaded;
    world.eventStacking = savedWorld.eventStacking;

    // Hydrate Window
    if (savedWorld.window) Object.assign(world.window, savedWorld.window);
    // Hydrate Camera
    if (savedWorld.camera) Object.assign(world.camera, savedWorld.camera);

    // Hydrate Audio
    if (savedWorld.musicTrack) {
      Object.assign(world.musicTrack, savedWorld.musicTrack);
      // Re-set prototype to Audio class
      Object.setPrototypeOf(world.musicTrack, Audio.prototype);
    }

    // Hydrate Text Objects
    if (savedWorld.textObjects) {
      if (savedWorld.textObjects.fps) {
        Object.assign(world.textObjects.fps, savedWorld.textObjects.fps);
        Object.setPrototypeOf(world.textObjects.fps, Text.prototype);
      }
      if (savedWorld.textObjects.logic) {
        Object.assign(world.textObjects.logic, savedWorld.textObjects.logic);
        Object.setPrototypeOf(world.textObjects.logic, Text.prototype);
      }
    }

    // Hydrate Sprites
    world.sprites = {};
    for (const key in savedWorld.sprites) {
      const sData = savedWorld.sprites[key];
      // Convert ID strings back to BigInt if necessary (Id class expects BigInt internally mostly)
      // Constructor takes whatever, usually numbers/BigInts.
      const sprite = new Sprite(BigInt(sData.id0), BigInt(sData.id1), false);
      Object.assign(sprite, sData);
      world.sprites[key] = sprite;
    }

    console.log("World state restored.");
  } catch (e) {
    console.error("Failed to parse saved data. Starting fresh.", e);
    if (fs.existsSync(SAVE_PATH)) {
      fs.unlinkSync(SAVE_PATH);
    }
  }

  // Re-init LiveReload
  world.liveReload = new LiveReload(SHUTDOWN_FLAG_PATH, SAVE_PATH);
}

/**
 * Main game loop.
 * * @param {number} elapsed
 * @param {number} dt
 * @param {Buffer} eventsBlob
 * @returns {Buffer}
 */
function Phrost_Update(elapsed, dt, eventsBlob) {
  // -- Live reloading feature ---
  const live_reload = world.liveReload;
  live_reload.poll(world.assetsLoaded);

  const window = world.window;
  const camera = world.camera;
  const music = world.musicTrack;
  const fpsText = world.textObjects.fps;
  const logicText = world.textObjects.logic;

  // --- FPS Calculation ---
  if (dt > 0) {
    world.fps = 1.0 / dt;
    world.fps_samples.push(dt);
    if (world.fps_samples.length > FPS_SAMPLE_SIZE) {
      world.fps_samples.shift();
    }
    const sum = world.fps_samples.reduce((a, b) => a + b, 0);
    const average_dt = sum / world.fps_samples.length;
    world.smoothed_fps = 1.0 / average_dt;
  }

  const maxSprite = 50000;
  const events = PackFormat.unpack(eventsBlob); // Handle Buffer

  // --- Packer Setup ---
  let packer;
  if (world.__initial_packer) {
    packer = world.__initial_packer;
    delete world.__initial_packer;
  } else {
    packer = new ChannelPacker();
  }

  // Check for deferred reset
  if (live_reload.isResetPending()) {
    console.log("Executing deferred reset. Sending remove commands.");
    live_reload.reset(world, packer);
    return packer.finalize();
  }

  // --- Initial Asset Loading ---
  if (!world.assetsLoaded) {
    console.log("Requesting audio load...");
    music.load();
    music.packDirtyEvents(packer);

    console.log("Creating text sprites...");
    fpsText.packDirtyEvents(packer);
    logicText.packDirtyEvents(packer);

    window.setSize(800, 450);
    window.packDirtyEvents(packer);

    world.assetsLoaded = true;
  }

  // --- Window Title & Text Update ---
  if (world.activeLogic === "JS") {
    window.setTitle(
      `Bunny Benchmark (JS) | Sprites: ${world.spritesCount} | FPS: ${world.smoothed_fps.toFixed(0)}`,
    );
  }

  fpsText.setText(`FPS: ${world.smoothed_fps.toFixed(0)}`);
  fpsText.packDirtyEvents(packer);

  logicText.setText("Logic: " + world.activeLogic);
  logicText.packDirtyEvents(packer);

  window.packDirtyEvents(packer);

  // --- Input Event Handling ---
  for (const event of events) {
    if (event.type === undefined) continue;

    // --- Mouse Events ---
    if (event.type === Events.INPUT_MOUSEMOTION) {
      world.mouseX = event.x || 0;
      world.mouseY = event.y || 0;
    }
    if (event.type === Events.INPUT_MOUSEDOWN) {
      world.inputState["MOUSE_LEFT"] = true;
    }
    if (event.type === Events.INPUT_MOUSEUP) {
      delete world.inputState["MOUSE_LEFT"];
    }

    // --- Window Resize Event ---
    if (event.type === Events.WINDOW_RESIZE) {
      window.setSize(event.w, event.h);
    }

    // --- Keyboard Events ---
    if (event.type === Events.INPUT_KEYDOWN) {
      if (event.keycode === undefined) continue;

      world.inputState[event.keycode] = true;

      live_reload.resetOnEvent(event, Keycode.R, Mod.CTRL);
      live_reload.shutdownOnEvent(event, Keycode.Q, Mod.NONE);

      // --- Toggles ---

      // Toggle Event Stacking
      if (event.keycode === Keycode.B) {
        world.eventStacking = !world.eventStacking;
        console.log(
          "Turning PLUGIN_EVENT_STACKING " +
            (world.eventStacking ? "ON" : "OFF"),
        );
        packer.add(Channels.PLUGIN, Events.PLUGIN_EVENT_STACKING, [
          world.eventStacking ? 1 : 0,
        ]);
      }

      // Audio Controls
      if (
        event.keycode === Keycode.P &&
        music.isLoaded &&
        !world.musicPlaying
      ) {
        music.play();
        music.packDirtyEvents(packer);
        world.musicPlaying = true;
      }
      if (event.keycode === Keycode.O) {
        Audio.stopAll(packer);
        world.musicPlaying = false;
      }

      // Toggle Logic (JS / Zig)
      if (event.keycode === Keycode.D) {
        if (world.activeLogic === "Zig") {
          world.activeLogic = "JS";
        } else {
          world.activeLogic = "Zig";
        }
        // Load Zig plugin if needed
        if (!world.pluginLoaded) {
          // Note: In Node.js, we'd use process.platform to determine lib name
          // But Node loads .node files via require, or FFI.
          // We send the path to the engine, which loads the native DLL/Dylib.
          let libExtension;
          if (os.platform() === "darwin")
            libExtension = "libzig_phrost_plugin.dylib";
          else if (os.platform() === "linux")
            libExtension = "libzig_phrost_plugin.so";
          else libExtension = "zig_phrost_plugin.dll";

          const libPath = path.join(__dirname, libExtension);
          const pathLen = Buffer.byteLength(libPath, "utf8");

          packer.add(Channels.PLUGIN, Events.PLUGIN_LOAD, [pathLen, libPath]);
          world.pluginLoaded = true;
        }
      }

      // Load Rust
      if (event.keycode === Keycode.R && !(event.mod & Mod.CTRL)) {
        console.log("Loading Rust Plugin...");
        let libName;
        if (os.platform() === "darwin") libName = "librust_phrost_plugin.dylib";
        else if (os.platform() === "linux")
          libName = "librust_phrost_plugin.so";
        else libName = "rust_phrost_plugin.dll";

        const libPath = path.join(__dirname, libName);
        if (!fs.existsSync(libPath)) {
          console.error("Error: Could not find Rust plugin.");
        } else {
          const pathLen = Buffer.byteLength(libPath, "utf8");
          packer.add(Channels.PLUGIN, Events.PLUGIN_LOAD, [pathLen, libPath]);
          world.pluginLoaded = true;
          world.activeLogic = "Rust";
        }
      }

      // Unload Plugin
      if (event.keycode === Keycode.M) {
        packer.add(Channels.PLUGIN, Events.PLUGIN_UNLOAD, [1]);
        world.activeLogic = "JS";
      }

      // Debug Keys
      if (event.keycode === Keycode.G) {
        world.chunkSize += 10;
      }
      if (event.keycode === Keycode.H) {
        world.chunkSize = Math.max(0, world.chunkSize - 10);
      }
    }

    if (event.type === Events.INPUT_KEYUP) {
      delete world.inputState[event.keycode];
    }

    // --- Texture Handling ---
    if (event.type === Events.SPRITE_TEXTURE_SET) {
      if (event.id1 && event.id2 && event.textureId) {
        const key = Id.toHex([BigInt(event.id1), BigInt(event.id2)]);
        if (world.sprites[key]) {
          world.sprites[key].setTextureId(event.textureId);
        }
      }
    }

    // --- Audio Loaded ---
    if (event.type === Events.AUDIO_LOADED) {
      music.setLoadedId(event.audioId);
      console.log("Audio loaded with ID: " + event.audioId);
    }

    // --- External Movement (e.g. from Plugins) ---
    if (event.type === Events.SPRITE_MOVE) {
      const key = Id.toHex([BigInt(event.id1), BigInt(event.id2)]);
      if (world.sprites[key]) {
        world.sprites[key].setPosition(
          event.positionX,
          event.positionY,
          event.positionZ,
          false,
        );
      }
    }
  } // End foreach events

  // --- Main Game Logic ---

  // 1. Add Sprites
  if (world.activeLogic === "JS") {
    const shouldAdd =
      world.inputState[Keycode.A] || world.inputState["MOUSE_LEFT"];

    if (shouldAdd && world.spritesCount < maxSprite) {
      const x = world.mouseX;
      const y = world.mouseY;
      const texturePath = path.join(__dirname, "assets/wabbit_alpha.png");

      for (let i = 0; i < 1000; i++) {
        const id = Id.generate();
        const sprite = new Sprite(id[0], id[1]);
        sprite.setPosition(x, y, 0.0);
        sprite.setSize(32.0, 32.0);
        sprite.setColor(
          Math.floor(Math.random() * (240 - 50) + 50),
          Math.floor(Math.random() * (240 - 80) + 80),
          Math.floor(Math.random() * (240 - 100) + 100),
          255,
        );
        sprite.setSpeed(Math.random() * 500 - 250, Math.random() * 500 - 250);
        sprite.setTexturePath(texturePath);

        const key = Id.toHex(id);
        world.sprites[key] = sprite;
        sprite.packDirtyEvents(packer);
      }
      world.spritesCount += 1000;
    }

    // 2. Update Sprite Positions (Bunny Benchmark Logic)
    const size = window.getSize();
    const boundary_left = 12;
    const boundary_right = size.width - 12;
    const boundary_top = 16;
    const boundary_bottom = size.height - 16;
    const hotspot_offset_x = 16;
    const hotspot_offset_y = 16;

    for (const key in world.sprites) {
      const sprite = world.sprites[key];
      sprite.update(dt);

      const pos = sprite.getPosition();
      const speed = sprite.getSpeed();
      let newSpeedX = speed.x;
      let newSpeedY = speed.y;
      let newPosX = pos.x;
      let newPosY = pos.y;

      const hotspot_x = pos.x + hotspot_offset_x;
      const hotspot_y = pos.y + hotspot_offset_y;

      if (hotspot_x > boundary_right) {
        newSpeedX *= -1;
        newPosX = boundary_right - hotspot_offset_x;
      } else if (hotspot_x < boundary_left) {
        newSpeedX *= -1;
        newPosX = boundary_left - hotspot_offset_x;
      }

      if (hotspot_y > boundary_bottom) {
        newSpeedY *= -1;
        newPosY = boundary_bottom - hotspot_offset_y;
      } else if (hotspot_y < boundary_top) {
        newSpeedY *= -1;
        newPosY = boundary_top - hotspot_offset_y;
      }

      if (newSpeedX !== speed.x || newSpeedY !== speed.y) {
        sprite.setSpeed(newSpeedX, newSpeedY, true);
      }
      if (newPosX !== pos.x || newPosY !== pos.y) {
        sprite.setPosition(newPosX, newPosY, pos.z, true);
      }
      sprite.packDirtyEvents(packer);
    }
  }

  // --- Camera Update ---
  camera.packDirtyEvents(packer);

  // --- Finalize & Return ---
  return packer.finalize();
}

module.exports = {
  Phrost_Update,
  Phrost_Sleep,
  Phrost_Wake,
};
