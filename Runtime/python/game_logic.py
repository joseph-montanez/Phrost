"""
Python translation of the Phrost game logic.
This file contains *only* your game's state and logic.
"""

import os
import pickle  # The Python equivalent of serialize/unserialize
import platform
import random
import sys
from typing import Union

# --- FIX: Add script's directory and subdirectories to the Python path ---
script_dir = os.path.dirname(os.path.abspath(__file__))
phrost_dir = os.path.join(script_dir, "Phrost")  # Path to the 'Phrost' subdirectory

# Add main script directory (for game_logic, ipc_client)
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

# Add Phrost subdirectory (for phrost.py)
if phrost_dir not in sys.path:
    sys.path.insert(0, phrost_dir)
# --- End of fix ---

# --- Includes & Imports ---
# Import all the stub classes and functions
from Audio import Audio
from Keycode import Keycode
from Sprite import Sprite
from Text import Text
from Window import Window

# Import from the main Phrost.py module
from Phrost import (
    CommandPacker,
    Events,
    Id_Generate,
    PackFormat,
)

# --- Constants ---
FPS_SAMPLE_SIZE = 60

# --- Global State Initialization ---
BASE_DIR = os.path.dirname(__file__)
FONT_PATH = os.path.join(BASE_DIR, "Roboto-Regular.ttf")
AUDIO_PATH = os.path.join(BASE_DIR, "snoozy beats - neon dreams.wav")

# Create Text objects
fps_text_id = Id_Generate()
fps_text = Text(fps_text_id[0], fps_text_id[1])
fps_text.set_font(FONT_PATH, 24.0)
fps_text.set_text("FPS: ...", False)
fps_text.set_position(10.0, 10.0, 100.0, False)
fps_text.set_color(255, 255, 255, 255, False)

logic_text_id = Id_Generate()
logic_text = Text(logic_text_id[0], logic_text_id[1])
logic_text.set_font(FONT_PATH, 24.0)
logic_text.set_text("Logic: Python", False)  # Default to Python!
logic_text.set_position(10.0, 40.0, 100.0, False)
logic_text.set_color(255, 255, 255, 255, False)

# Create Audio object
music_track = Audio(AUDIO_PATH)

WORLD = {
    "window": Window("Bunny Benchmark (Python)", 800, 450),
    "sprites": {},  # The dictionary of all Sprite objects
    "textObjects": {
        "fps": fps_text,
        "logic": logic_text,
    },
    "musicTrack": music_track,
    "spritesCount": 0,
    "pluginOn": False,
    "pluginLoaded": False,
    "chunkSize": 0,
    "mouseX": 0,
    "mouseY": 0,
    "fps": 0.0,
    "smoothed_fps": 0.0,
    "fps_samples": [],
    "musicPlaying": False,
    "assetsLoaded": False,
    "eventStacking": True,
}

# Pack initial window setup
initial_packer = CommandPacker()
WORLD["window"].set_resizable(True)
WORLD["window"].pack_dirty_events(initial_packer)
WORLD["__initial_packer"] = initial_packer

# --- End Global State ---


def Phrost_Sleep() -> bytes:
    """
    Called by Phrost when the Python state is about to be saved.
    Uses pickle to serialize the entire WORLD dictionary.
    """
    global WORLD
    return pickle.dumps(WORLD)


def Phrost_Wake(data: bytes):
    """
    Called by Phrost to restore the Python state.
    Uses pickle to deserialize the data into the WORLD dictionary.
    """
    global WORLD
    WORLD = pickle.loads(data)


def Phrost_Update(
    elapsed: int, dt: float, events_blob: bytes = b""
) -> Union[bytes, bool]:
    """
    This is the main game loop function.
    """
    global WORLD

    if not WORLD["eventStacking"]:
        return b""  # Return empty bytes

    window: Window = WORLD["window"]
    music: Audio = WORLD["musicTrack"]
    fps_text: Text = WORLD["textObjects"]["fps"]
    logic_text: Text = WORLD["textObjects"]["logic"]

    # --- FPS Calculation ---
    if dt > 0:
        WORLD["fps"] = 1.0 / dt
        WORLD["fps_samples"].append(dt)
        if len(WORLD["fps_samples"]) > FPS_SAMPLE_SIZE:
            WORLD["fps_samples"].pop(0)  # Remove oldest sample

        average_dt = sum(WORLD["fps_samples"]) / len(WORLD["fps_samples"])
        WORLD["smoothed_fps"] = 1.0 / average_dt

    max_sprite = 50000
    events = PackFormat.unpack(events_blob)

    # --- Packer Setup ---
    if "__initial_packer" in WORLD:
        packer = WORLD.pop("__initial_packer")  # Use it only once
    else:
        packer = CommandPacker(WORLD["chunkSize"])

    # --- Initial Asset Loading ---
    if not WORLD["assetsLoaded"]:
        print("Requesting audio load...")
        music.load(packer)

        print("Creating text sprites...")
        fps_text.pack_dirty_events(packer)  # Sends TEXT_ADD
        logic_text.pack_dirty_events(packer)  # Sends TEXT_ADD

        WORLD["assetsLoaded"] = True

    # --- Window Title Update ---
    if not WORLD["pluginOn"]:
        window.set_title(
            f"Bunny Benchmark (Python) | Sprites: {WORLD['spritesCount']} | "
            f"FPS: {WORLD['smoothed_fps']:.0f}"
        )

    # --- Text Updates ---
    fps_text.set_text(f"FPS: {WORLD['smoothed_fps']:.0f}")
    fps_text.pack_dirty_events(packer)  # Sends TEXT_SET_STRING if changed

    logic_text.set_text("Logic: Zig" if WORLD["pluginOn"] else "Logic: Python")
    logic_text.pack_dirty_events(packer)  # Sends TEXT_SET_STRING if changed

    window.pack_dirty_events(packer)

    # --- Input Event Handling ---
    add_sprites = False
    for event in events:
        if "type" not in event:
            continue

        event_type = event["type"]

        # --- Mouse Events ---
        if event_type == Events.INPUT_MOUSEMOTION.value:
            WORLD["mouseX"] = event.get("x", 0)
            WORLD["mouseY"] = event.get("y", 0)
        elif event_type == Events.INPUT_MOUSEDOWN.value:
            add_sprites = True

        # --- Window Resize Event ---
        elif event_type == Events.WINDOW_RESIZE.value:
            print(event)
            window.set_size(event.get("w", 800), event.get("h", 600))

        # --- Keyboard Events ---
        elif event_type == Events.INPUT_KEYDOWN.value:
            keycode = event.get("keycode")
            if not keycode:
                continue

            if keycode == Keycode.A:
                add_sprites = True

            elif keycode == Keycode.B:
                WORLD["eventStacking"] = not WORLD["eventStacking"]
                stack_str = "ON" if WORLD["eventStacking"] else "OFF"
                print(f"Turning PLUGIN_EVENT_STACKING {stack_str}")
                packer.add(
                    Events.PLUGIN_EVENT_STACKING, [1 if WORLD["eventStacking"] else 0]
                )

            # --- Audio Controls ---
            elif (
                keycode == Keycode.P and music.isLoaded() and not WORLD["musicPlaying"]
            ):
                music.play(packer)
                WORLD["musicPlaying"] = True
                print("Playing audio...")
            elif keycode == Keycode.O:
                Audio.stopAll(packer)
                WORLD["musicPlaying"] = False
                print("Stopping all audio...")

            # --- Plugin Toggle ---
            elif keycode == Keycode.D:  # 'D' for Zig (was default)
                WORLD["pluginOn"] = not WORLD["pluginOn"]
                if not WORLD["pluginLoaded"]:
                    system = platform.system()
                    if system == "Darwin":
                        lib_ext = "lib/libzig_phrost_plugin.dylib"
                    elif system == "Windows":
                        lib_ext = "bin/zig_phrost_plugin.dll"
                    elif system == "Linux":
                        lib_ext = ".so"  # Adjust as needed
                    else:
                        raise Exception(f"Unsupported OS: {system}")

                    path = os.path.realpath(
                        os.path.join(
                            BASE_DIR, "..", "Plugins", "zig-plugin", "zig-out", lib_ext
                        )
                    )
                    path_bytes = path.encode("utf-8")
                    packer.add(Events.PLUGIN_LOAD, [len(path_bytes), path_bytes])
                    WORLD["pluginLoaded"] = True

            elif keycode == Keycode.R:  # 'R' for Rust
                print("Loading Rust Plugin...")
                system = platform.system()
                if system == "Darwin":
                    lib_name = "librust_phrost_plugin.dylib"
                elif system == "Windows":
                    lib_name = "rust_phrost_plugin.dll"
                elif system == "Linux":
                    lib_name = "librust_phrost_plugin.so"
                else:
                    raise Exception(f"Unsupported OS: {system}")

                path = os.path.realpath(
                    os.path.join(
                        BASE_DIR,
                        "..",
                        "Plugins",
                        "rust-plugin",
                        "target",
                        "release",
                        lib_name,
                    )
                )

                if not os.path.exists(path):
                    print(
                        f"Error: Could not find Rust plugin at {path}", file=sys.stderr
                    )
                else:
                    path_bytes = path.encode("utf-8")
                    packer.add(Events.PLUGIN_LOAD, [len(path_bytes), path_bytes])
                    WORLD["pluginLoaded"] = True
                    WORLD["pluginOn"] = True

            elif keycode == Keycode.M:
                packer.add(Events.PLUGIN_UNLOAD, [1])
                WORLD["pluginOn"] = False

            # --- Debug Keys ---
            elif keycode == Keycode.G:
                WORLD["chunkSize"] += 10
                print(f"Chunk size increased to {WORLD['chunkSize']}")
            elif keycode == Keycode.H:
                WORLD["chunkSize"] = max(0, WORLD["chunkSize"] - 10)
                print(f"Chunk size decreased to {WORLD['chunkSize']}")

            elif keycode == Keycode.Q:
                return False  # Signal quit

        # --- Internal Event Handling ---

        elif event_type == Events.SPRITE_TEXTURE_SET.value:
            key = f"{event.get('id1')}-{event.get('id2')}"
            if key in WORLD["sprites"]:
                sprite = WORLD["sprites"][key]
                sprite.set_texture_id(event.get("textureId", 0))

        elif event_type == Events.SPRITE_ADD.value:
            sprite = Sprite(event["id1"], event["id2"], False)
            sprite.set_position(
                event["positionX"], event["positionY"], event["positionZ"], False
            )
            sprite.set_scale(event["scaleX"], event["scaleY"], event["scaleZ"], False)
            sprite.set_size(event["sizeW"], event["sizeH"], False)
            sprite.set_rotate(
                event["rotationX"], event["rotationY"], event["rotationZ"], False
            )
            sprite.set_color(event["r"], event["g"], event["b"], event["a"], False)
            sprite.set_speed(event["speedX"], event["speedY"], False)
            WORLD["sprites"][sprite.key] = sprite
            WORLD["spritesCount"] += 1

        elif event_type == Events.SPRITE_MOVE.value:
            key = f"{event['id1']}-{event['id2']}"
            if key in WORLD["sprites"]:
                sprite = WORLD["sprites"][key]
                sprite.set_position(
                    event["positionX"], event["positionY"], event["positionZ"], False
                )

        elif event_type == Events.SPRITE_SPEED.value:
            key = f"{event['id1']}-{event['id2']}"
            if key in WORLD["sprites"]:
                sprite = WORLD["sprites"][key]
                sprite.set_speed(event["speedX"], event["speedY"], False)

        elif event_type == Events.AUDIO_LOADED.value:
            audio_id = event.get("audioId")
            if audio_id is not None:
                music.set_loaded_id(audio_id)
                print(f"Audio loaded with ID: {audio_id}")

    # --- Main Game Logic ---
    if not WORLD["pluginOn"]:
        size = window.get_size()
        boundary_left = 12
        boundary_right = size["width"] - 12
        boundary_top = 16
        boundary_bottom = size["height"] - 16
        hotspot_offset_x = 16
        hotspot_offset_y = 16

        for sprite in WORLD["sprites"].values():
            sprite.update(dt)  # Internal position update
            pos = sprite.get_position()
            speed = sprite.get_speed()

            new_speed_x, new_speed_y = speed["x"], speed["y"]
            new_pos_x, new_pos_y = pos["x"], pos["y"]

            hotspot_x = pos["x"] + hotspot_offset_x
            hotspot_y = pos["y"] + hotspot_offset_y

            if hotspot_x > boundary_right:
                new_speed_x *= -1
                new_pos_x = boundary_right - hotspot_offset_x
            elif hotspot_x < boundary_left:
                new_speed_x *= -1
                new_pos_x = boundary_left - hotspot_offset_x

            if hotspot_y > boundary_bottom:
                new_speed_y *= -1
                new_pos_y = boundary_bottom - hotspot_offset_y
            elif hotspot_y < boundary_top:
                new_speed_y *= -1
                new_pos_y = boundary_top - hotspot_offset_y

            if new_speed_x != speed["x"] or new_speed_y != speed["y"]:
                sprite.set_speed(
                    new_speed_x, new_speed_y, notify_engine=False
                )  # No need to re-pack

            if new_pos_x != pos["x"] or new_pos_y != pos["y"]:
                sprite.set_position(
                    new_pos_x, new_pos_y, pos["z"], notify_engine=False
                )  # No need to re-pack

            # Manually set dirty=True to pack updates
            sprite.is_dirty = True
            sprite.pack_dirty_events(packer)

    # --- Add Sprites Loop ---
    if not WORLD["pluginOn"]:
        if add_sprites and WORLD["spritesCount"] < max_sprite:
            x, y = WORLD["mouseX"], WORLD["mouseY"]
            new_sprites = []
            for _ in range(1000):
                id_ = Id_Generate()
                sprite = Sprite(id_[0], id_[1])
                sprite.set_position(x, y, 0.0)
                sprite.set_size(32.0, 32.0)
                sprite.set_color(
                    random.randint(50, 240),
                    random.randint(80, 240),
                    random.randint(100, 240),
                    255,
                )
                sprite.set_speed(
                    random.uniform(-250.0, 250.0), random.uniform(-250.0, 250.0)
                )
                sprite.set_texture_path(os.path.join(BASE_DIR, "wabbit_alpha.png"))

                WORLD["sprites"][sprite.key] = sprite
                new_sprites.append(sprite)

            for sprite in new_sprites:
                sprite.pack_dirty_events(packer)  # Packs SPRITE_ADD

            WORLD["spritesCount"] += 1000

    # --- Finalize & Return ---
    return packer.finalize()
