import atexit
import gc
import os
import sys

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

from game_logic import Phrost_Sleep, Phrost_Update, Phrost_Wake
from ipc_client import IPCClient

# --- Configuration ---
# (Error reporting is on by default in Python)
# (memory_limit is less of a concern, but can be set with 'resource' module if needed)

# --- Application Entry Point ---
gc.disable()

client = IPCClient()
SAVE_FILE = os.path.join(os.path.dirname(__file__), "save.data")


@atexit.register
def shutdown():
    """Called on script exit, equivalent to register_shutdown_function."""
    print("Saving game state!")
    try:
        # Save the game state
        save_data = Phrost_Sleep()
        with open(SAVE_FILE, "wb") as f:
            f.write(save_data)
    except Exception as e:
        print(f"Failed to save game state: {e}", file=sys.stderr)


try:
    # Load the game state if it exists
    if os.path.isfile(SAVE_FILE):
        print("Loading previous game state...")
        with open(SAVE_FILE, "rb") as f:
            Phrost_Wake(f.read())

    # 1. Connect to the Swift server
    client.connect()

    # 2. Run the main loop
    # This will call 'Phrost_Update' (from game_logic.py)
    # every frame until the connection is lost.
    client.run(Phrost_Update)

except Exception as e:
    # Catch connection errors or other fatal exceptions
    print(f"An error occurred: {e}", file=sys.stderr)
    import traceback

    traceback.print_exc()
finally:
    # 3. Always disconnect gracefully
    client.disconnect()

    # Re-enable GC on exit just in case
    gc.enable()
