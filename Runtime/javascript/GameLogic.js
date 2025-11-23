const path = require("path");
const fs = require("fs");

// Import Engine Classes
const Window = require("./Phrost/Window");
const Camera = require("./Phrost/Camera");
const ChannelPacker = require("./Phrost/ChannelPacker");
const { PackFormat } = require("./Phrost/PackFormat");
const LiveReload = require("./Phrost/LiveReload");
const Tiled = require("./Phrost/Tiled");
const Id = require("./Phrost/Id");
const { Events } = require("./Phrost/Events");
const Keycode = require("./Phrost/Keycode");
const Mod = require("./Phrost/Mod");
const Sprite = require("./Phrost/Sprite");
const SpriteAnimated = require("./Phrost/SpriteAnimated");

// Import Game Classes
const Warrior = require("./src/Warrior");
const WarriorBody = require("./src/WarriorBody");

// --- Global State Initialization ---
const SHUTDOWN_FLAG_PATH = path.join(__dirname, "../shutdown.flag");
const SAVE_PATH = path.join(__dirname, "../save.data");

// The main world state object
let world = {
  window: new Window("Animation Demo (JS)", 800, 450),
  camera: new Camera(800.0, 450.0),
  sprites: {}, // Map<stringHex, Sprite>
  physicsBodies: {}, // Map<stringHex, PhysicsBody>
  assetsLoaded: false,
  mapInfo: {},
  playerKey: null,
  inputState: {},
  liveReload: new LiveReload(SHUTDOWN_FLAG_PATH, SAVE_PATH),
  __initial_packer: new ChannelPacker(), // Initial setup packer
};

// Pack initial window setup immediately
world.window.setResizable(true);
world.window.packDirtyEvents(world.__initial_packer);

/**
 * Called to save state.
 * * @returns {string} JSON string of world state
 */
function Phrost_Sleep() {
  delete world.__initial_packer; // Don't save the packer

  // We need to tag objects with their class type so we can hydrate them later.
  // JSON.stringify won't save class info.
  const state = JSON.stringify(world, (key, value) => {
    // Custom replacer could go here if needed, but for now standard JSON is fine
    // provided we handle hydration in Wake.
    // Note: We add a _className property to our classes if we want automatic detection,
    // or we rely on knowing where specific objects live (like world.sprites).
    return value;
  });
  return state;
}

/**
 * Called to restore state.
 * * @param {string} data - JSON string
 */
function Phrost_Wake(data) {
  try {
    const savedWorld = JSON.parse(data);

    // Restore primitive properties
    world.assetsLoaded = savedWorld.assetsLoaded;
    world.mapInfo = savedWorld.mapInfo;
    world.playerKey = savedWorld.playerKey;
    world.inputState = savedWorld.inputState || {};

    // Restore Window & Camera
    if (savedWorld.window) {
      Object.assign(world.window, savedWorld.window);
      // Re-initialize flags object if it was flattened
    }
    if (savedWorld.camera) {
      Object.assign(world.camera, savedWorld.camera);
    }

    // --- Hydrate Sprites ---
    world.sprites = {};
    for (const key in savedWorld.sprites) {
      const spriteData = savedWorld.sprites[key];
      let sprite;

      // Heuristic to determine type. In a real engine, save a "type" field.
      // For this demo, if it has 'animations' prop, it's a Warrior/SpriteAnimated.
      if (spriteData.animations || key === world.playerKey) {
        // It's our Warrior
        // JSON saves numbers as regular numbers. Our IDs need to be BigInt for the ID class?
        // Actually, the constructor takes numbers.
        // However, Id.generate() returns BigInts.
        // If saved as string/number in JSON, we might need conversion.
        // Let's assume standard number safety for now or strings.
        sprite = new Warrior(
          BigInt(spriteData.id0),
          BigInt(spriteData.id1),
          false,
        );
        sprite.hydrate(spriteData);
      } else {
        // Standard Tile Sprite
        sprite = new Sprite(
          BigInt(spriteData.id0),
          BigInt(spriteData.id1),
          false,
        );
        Object.assign(sprite, spriteData);
      }
      world.sprites[key] = sprite;
    }

    // --- Hydrate Physics Bodies ---
    world.physicsBodies = {};
    for (const key in savedWorld.physicsBodies) {
      const bodyData = savedWorld.physicsBodies[key];
      let body;

      if (key === world.playerKey) {
        body = new WarriorBody(
          BigInt(bodyData.id0),
          BigInt(bodyData.id1),
          false,
        );
        body.hydrate(bodyData);
      } else {
        body = new WarriorBody(
          BigInt(bodyData.id0),
          BigInt(bodyData.id1),
          false,
        );
        Object.assign(body, bodyData);
      }
      world.physicsBodies[key] = body;
    }

    console.log("World state restored.");
  } catch (e) {
    console.error("Failed to parse save data. Starting fresh.", e);
    if (fs.existsSync(SAVE_PATH)) {
      fs.unlinkSync(SAVE_PATH);
    }
  }

  // Re-init LiveReload
  world.liveReload = new LiveReload(SHUTDOWN_FLAG_PATH, SAVE_PATH);
}

/**
 * Main game loop function.
 * * @param {number} elapsed
 * @param {number} dt
 * @param {Buffer} eventsBlob
 * @returns {Buffer} Command blob
 */
function Phrost_Update(elapsed, dt, eventsBlob) {
  const liveReload = world.liveReload;
  liveReload.poll(world.assetsLoaded);

  const window = world.window;
  const camera = world.camera;

  // Unpack events (Buffer -> Array of Objects)
  const events = PackFormat.unpack(eventsBlob); // unpack needs to handle Buffer

  // Setup Packer
  let packer;
  if (world.__initial_packer) {
    packer = world.__initial_packer;
    delete world.__initial_packer;
  } else {
    packer = new ChannelPacker();
  }

  // Check pending reset
  if (liveReload.isResetPending()) {
    console.log("Executing deferred reset.");
    liveReload.reset(world, packer);
    return packer.finalize();
  }

  // --- Initial Asset Loading ---
  if (!world.assetsLoaded) {
    // Load Map
    Tiled.loadMap(world, packer, path.join(__dirname, "assets/map.tmx"));

    // Create Warrior
    const id = Id.generate(); // [BigInt, BigInt]
    const warrior = new Warrior(id[0], id[1]);
    warrior.setPosition(100.0, 40.0, 0.0);
    warrior.setSize(64, 44);
    warrior.setTexturePath(
      path.join(__dirname, "assets/Warrior_Sheet-Effect.png"),
    );

    warrior.initializeAnimations();
    warrior.play("idle", true);

    const key = Id.toHex(id);
    world.sprites[key] = warrior;
    warrior.packDirtyEvents(packer);

    // Create Physics Body
    const warriorBody = new WarriorBody(id[0], id[1]);
    warriorBody.setConfig(0, 0, 1.0, 0.2, 0.0, 1); // Dynamic, Box, Mass 1, Friction 0.2, Elasticity 0, LockRot
    warriorBody.setShape(32.0, 40.0);
    warriorBody.setPosition(100.0, 40.0, false);

    world.physicsBodies[key] = warriorBody;
    world.playerKey = key;
    warriorBody.packDirtyEvents(packer);

    window.setSize(800, 450);
    window.packDirtyEvents(packer);

    world.assetsLoaded = true;
    console.log("Assets loaded successfully!");
  }

  // --- Player Lookup ---
  const playerKey = world.playerKey;
  const playerBody = playerKey ? world.physicsBodies[playerKey] : null;
  const playerSprite = playerKey ? world.sprites[playerKey] : null;

  window.setTitle("Warrior Animation Demo (JS) - 'I' Idle, 'A' Attack");
  window.packDirtyEvents(packer);

  // --- Input Event Handling ---
  for (const event of events) {
    if (event.type === undefined) continue;

    if (event.type === Events.WINDOW_RESIZE) {
      window.setSize(event.w, event.h);
    }

    if (event.type === Events.INPUT_KEYDOWN) {
      world.inputState[event.keycode] = true;

      liveReload.resetOnEvent(event, Keycode.R, Mod.CTRL);
      liveReload.shutdownOnEvent(event, Keycode.Q, Mod.NONE);

      if (event.keycode === Keycode.I) {
        for (const key in world.sprites) {
          const s = world.sprites[key];
          if (s instanceof SpriteAnimated) s.play("idle", true, true);
        }
      }
      if (event.keycode === Keycode.A) {
        for (const key in world.sprites) {
          const s = world.sprites[key];
          if (s instanceof SpriteAnimated) s.play("attack", false, true);
        }
      }
    }

    if (event.type === Events.INPUT_KEYUP) {
      delete world.inputState[event.keycode];
    }

    if (event.type === Events.SPRITE_TEXTURE_SET) {
      // Texture ID set logic
      if (event.id1 && event.id2 && event.textureId) {
        // FIX: Cast to Unsigned to prevent RangeError on large IDs
        const k = Id.toHex([
          BigInt.asUintN(64, BigInt(event.id1)),
          BigInt.asUintN(64, BigInt(event.id2)),
        ]);
        if (world.sprites[k]) {
          world.sprites[k].setTextureId(event.textureId);
        }
      }
    }

    if (event.type === Events.PHYSICS_SYNC_TRANSFORM) {
      const k = Id.toHex([
        BigInt.asUintN(64, BigInt(event.id1)),
        BigInt.asUintN(64, BigInt(event.id2)),
      ]);

      if (world.physicsBodies[k]) {
        const body = world.physicsBodies[k];
        body.setVelocity(event.velocityX, event.velocityY, false);
        body.setRotation(event.angle, false);
        body.setAngularVelocity(event.angularVelocity, false);
        body.setIsSleeping(event.isSleeping === 1, false);

        // Camera follow player
        if (k === world.playerKey) {
          camera.setPosition(event.positionX, event.positionY);
        }
      }

      if (world.sprites[k]) {
        const sprite = world.sprites[k];
        const oldPos = sprite.getPosition();
        const oldRot = sprite.getRotation();
        sprite.setPosition(event.positionX, event.positionY, oldPos.z);
        sprite.setRotate(oldRot.x, oldRot.y, event.angle);
      }
    }

    if (event.type === Events.PHYSICS_COLLISION_BEGIN) {
      if (playerBody) {
        playerBody.processCollisionEvent(event, world.physicsBodies);
      }
    }
  }

  // --- Player Update ---
  if (playerBody) {
    playerBody.update(world.inputState, packer);
  }

  // --- Animation Logic ---
  if (playerSprite && playerBody) {
    let targetVx = 0.0;
    if (world.inputState[Keycode.LEFT]) targetVx = -1.0;
    if (world.inputState[Keycode.RIGHT]) targetVx = 1.0;

    if (playerSprite.isLooping() || !playerSprite.isPlaying()) {
      if (targetVx !== 0.0) {
        playerSprite.play("run", true, false);
        playerSprite.setFlip(targetVx < 0);
      } else {
        playerSprite.play("idle", true, false);
      }
    }
  }

  // --- Main Loop ---
  for (const key in world.sprites) {
    const sprite = world.sprites[key];
    if (sprite instanceof SpriteAnimated) {
      sprite.update(dt);
      sprite.packDirtyEvents(packer);
    }
  }

  camera.packDirtyEvents(packer);

  return packer.finalize();
}

// Export the global methods for the Main entry point
module.exports = {
  Phrost_Update,
  Phrost_Sleep,
  Phrost_Wake,
};
