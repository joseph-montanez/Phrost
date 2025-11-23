const net = require("net");
const os = require("os");

/**
 * Phrost IPC Client
 * * Handles low-level socket/pipe communication with the Swift IPC server.
 * Supports Windows Named Pipes and UNIX Domain Sockets.
 */
class IPCClient {
  constructor() {
    this.isWindows = os.platform() === "win32";
    this.socket = null;
    this.isConnected = false;
  }

  /**
   * Connects to the Swift IPC server.
   * * @returns {Promise<void>} Resolves when connected, rejects on error.
   */
  connect() {
    return new Promise((resolve, reject) => {
      if (this.isConnected) return resolve();

      let pipePath;
      if (this.isWindows) {
        pipePath = "\\\\.\\pipe\\PhrostEngine";
        console.log(`Attempting to connect to Windows pipe: ${pipePath}...`);
      } else {
        pipePath = "/tmp/PhrostEngine.socket";
        console.log(`Attempting to connect to UNIX socket: ${pipePath}...`);
      }

      this.socket = net.createConnection(pipePath);

      this.socket.on("connect", () => {
        this.isConnected = true;
        console.log("Connected! Entering game loop...");
        resolve();
      });

      this.socket.on("error", (err) => {
        console.error("Socket error:", err);
        reject(err);
      });

      this.socket.on("close", () => {
        this.isConnected = false;
        this.socket = null;
        console.log("Disconnected.");
      });
    });
  }

  /**
   * Disconnects from the server.
   */
  disconnect() {
    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
      this.isConnected = false;
    }
  }

  /**
   * Reads a specific number of bytes from the socket.
   * Helper for the main loop logic.
   * * @private
   * @param {number} length
   * @returns {Promise<Buffer>}
   */
  readBytes(length) {
    return new Promise((resolve, reject) => {
      if (!this.socket || this.socket.destroyed)
        return reject(new Error("Socket closed"));

      // If data is already in buffer, read it
      const chunk = this.socket.read(length);
      if (chunk) {
        if (chunk.length < length) {
          // This edge case requires buffering accumulation logic which standard net.Socket handles via 'readable'
          // But for strict framing, we often need a loop.
          // Simplified approach: Wait for 'readable' if null.
          // Note: net.Socket.read(n) returns null if n bytes aren't available.
          // We need to push back? No, standard pattern below:
        } else {
          return resolve(chunk);
        }
      }

      // Data not ready, wait for readable
      const onReadable = () => {
        const chunk = this.socket.read(length);
        if (chunk) {
          this.socket.off("readable", onReadable);
          this.socket.off("error", onError);
          this.socket.off("close", onClose);
          resolve(chunk);
        }
      };

      const onError = (err) => {
        cleanup();
        reject(err);
      };

      const onClose = () => {
        cleanup();
        reject(new Error("Socket closed during read"));
      };

      const cleanup = () => {
        this.socket.off("readable", onReadable);
        this.socket.off("error", onError);
        this.socket.off("close", onClose);
      };

      this.socket.on("readable", onReadable);
      this.socket.on("error", onError);
      this.socket.on("close", onClose);
    });
  }

  /**
   * Simpler Synchronous-style Read Loop logic wrapper for Node.js async streams.
   * Since Node is async, we can't block cleanly like PHP.
   * We must use an async loop.
   * * @param {function(number, number, Buffer): Buffer} updateCallback
   * callback(elapsed, dt, eventsBlob) -> commandBlob
   */
  async run(updateCallback) {
    if (!this.isConnected) {
      throw new Error("Cannot run: Not connected.");
    }

    let elapsed = 0;

    try {
      while (this.isConnected) {
        // 1. Read Length Header (4 bytes)
        let lenHeader;
        try {
          lenHeader = await this.readBytes(4);
        } catch (e) {
          break;
        } // socket closed

        const totalLength = lenHeader.readUInt32LE(0);

        if (totalLength < 8) {
          console.error(`Payload too small: ${totalLength} bytes.`);
          break;
        }

        // 2. Read DT (8 bytes)
        const dtData = await this.readBytes(8);
        const dt = dtData.readDoubleLE(0);

        // 3. Read Events
        const eventPayloadLength = totalLength - 8;
        let eventsBlob = Buffer.alloc(0);
        if (eventPayloadLength > 0) {
          eventsBlob = await this.readBytes(eventPayloadLength);
        }

        // 4. User Logic
        const commandBlob = updateCallback(elapsed, dt, eventsBlob);
        if (commandBlob === false || commandBlob === null) {
          console.log("Game logic signaled quit.");
          break;
        }

        // 5. Write Frame
        const cmdLen = commandBlob.length;
        const header = Buffer.alloc(4);
        header.writeUInt32LE(cmdLen, 0);

        this.socket.write(header);
        this.socket.write(commandBlob);
        // Node flushes automatically, but we can force strict sequence by await if needed,
        // though socket.write is usually sufficient.

        elapsed++;
      }
    } catch (err) {
      console.error("Error in game loop:", err);
    } finally {
      this.disconnect();
    }
  }
}

module.exports = IPCClient;
