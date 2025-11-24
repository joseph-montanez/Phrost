const fs = require("fs");
const path = require("path");
const IPCClient = require("./Phrost/IPClient");
const { Phrost_Update, Phrost_Wake } = require("./game-logic");

// --- Main Entry Point ---

const SAVE_DATA_PATH = path.join(__dirname, "../save.data");

async function main() {
  const client = new IPCClient();

  try {
    // Load game state if exists
    if (fs.existsSync(SAVE_DATA_PATH)) {
      const saveData = fs.readFileSync(SAVE_DATA_PATH, "utf8");
      Phrost_Wake(saveData);
    }

    // 1. Connect
    await client.connect();

    // 2. Run Main Loop
    // The run method expects a callback that accepts (elapsed, dt, eventsBlob)
    // We pass our logic function directly.
    await client.run(Phrost_Update);
  } catch (err) {
    console.error("Client Exception:", err);
  } finally {
    // 3. Disconnect
    client.disconnect();
  }
}

// Execute
main();
