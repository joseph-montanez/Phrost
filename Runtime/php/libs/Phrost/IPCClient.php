<?php

namespace Phrost;
use Exception;

/**
 * Phrost IPC Client
 *
 * This class handles all the low-level, cross-platform socket/pipe
 * communication with the Swift IPC server.
 */
class IPCClient
{
    /** @var resource|Socket|null */
    private $pipe = null;
    private bool $isWindows;
    private bool $isConnected = false;

    public function __construct()
    {
        $this->isWindows = strtoupper(substr(PHP_OS, 0, 3)) === "WIN";
    }

    /**
     * Connects to the Swift IPC server.
     * @throws Exception if connection fails.
     */
    public function connect(): void
    {
        if ($this->isConnected) {
            return;
        }

        if ($this->isWindows) {
            // --- Windows Connection (Named Pipe) ---
            $pipePath = "\\\\.\\pipe\\PhrostEngine";
            echo "Attempting to connect to Windows pipe: $pipePath...\n";
            $this->pipe = @fopen($pipePath, "r+");

            if (!$this->pipe) {
                throw new Exception(
                    "Failed to open pipe. Is the Swift server (PhrostIPC.exe) running?\n",
                );
            }
            stream_set_blocking($this->pipe, true);
        } else {
            // --- macOS/Linux Connection (UNIX Domain Socket) ---
            $pipePath = "/tmp/PhrostEngine.socket";
            echo "Attempting to connect to UNIX socket: $pipePath...\n";

            if (!extension_loaded("sockets")) {
                throw new Exception(
                    "The 'sockets' extension is not enabled in your php.ini.",
                );
            }

            $this->pipe = @socket_create(AF_UNIX, SOCK_STREAM, 0);
            if (!$this->pipe) {
                throw new Exception(
                    "socket_create() failed: " .
                    socket_strerror(socket_last_error()),
                );
            }

            $connected = @socket_connect($this->pipe, $pipePath);
            if (!$connected) {
                throw new Exception(
                    "socket_connect() failed: " .
                    socket_strerror(socket_last_error($this->pipe)) .
                    ". Is the Swift server running?\n",
                );
            }
            socket_set_block($this->pipe);
        }

        $this->isConnected = true;
        echo "Connected! Entering game loop...\n";
        echo "Blocking now...\n";
    }

    /**
     * Disconnects from the server.
     */
    public function disconnect(): void
    {
        if (!$this->isConnected || !$this->pipe) {
            return;
        }

        if ($this->isWindows) {
            if (is_resource($this->pipe)) {
                fclose($this->pipe);
            }
        } else {
            if (is_resource($this->pipe) || $this->pipe instanceof \Socket) {
                socket_close($this->pipe);
            }
        }
        $this->pipe = null;
        $this->isConnected = false;
        echo "Disconnected.\n";
    }

    /**
     * Runs the main game loop, calling the update callback each frame.
     *
     * @param callable $updateCallback The user's game logic function, e.g., 'Phrost_Update'
     * It must accept: (int $elapsed, float $dt, string $eventsBlob)
     * It must return: (string $commandBlob)
     */
    public function run(callable $updateCallback): void
    {
        if (!$this->isConnected) {
            throw new Exception("Cannot run: Not connected.");
        }

        $elapsed = 0;

        try {
            while (true) {
                // 1. Read frame data from Swift
                $frameData = $this->readFrame();
                if ($frameData === false) {
                    echo "Pipe broken (read failed). Exiting loop.\n";
                    break;
                }

                // 2. Call the user's game logic function
                $commandBlob = $updateCallback(
                    $elapsed,
                    $frameData["dt"],
                    $frameData["eventsBlob"],
                );

                if ($commandBlob === false) {
                    echo "[PHP Logic] Game logic signaled graceful quit.\n";
                    break;
                }

                // 3. Write commands back to Swift
                if ($this->writeFrame($commandBlob) === false) {
                    echo "Pipe broken (write failed). Exiting loop.\n";
                    break;
                }

                $elapsed++;
            }
        } catch (Exception $e) {
            echo "An error occurred during the loop: " .
                $e->getMessage() .
                "\n";
            error_log(
                "PHP Client Exception: " .
                $e->getMessage() .
                "\n" .
                $e->getTraceAsString(),
            );
        }
    }

    /**
     * Reads one full "frame" of data from the Swift server.
     * @return array|false ['dt' => float, 'eventsBlob' => string] or false on failure
     */
    private function readFrame(): bool|array
    {
        // 1. Read Length Header
        $lenHeader = $this->read_all(4);
        if ($lenHeader === false) {
            return false;
        }

        $unpackedHeader = unpack("VtotalLength", $lenHeader);
        if (!$unpackedHeader) {
            error_log("Failed to unpack header.");
            return false;
        }
        $totalLength = $unpackedHeader["totalLength"];

        // 2. Read Payload (dt + events)
        if ($totalLength < 8) {
            error_log("Payload too small: $totalLength bytes, expected >= 8.");
            return false;
        }

        // Read DT (8 bytes)
        $dtData = $this->read_all(8);
        if ($dtData === false) {
            error_log("Failed to read delta-time.");
            return false;
        }
        $dt = unpack("d", $dtData)[1];

        // Read Events (Remaining bytes)
        $eventPayloadLength = $totalLength - 8;
        $eventsBlob = "";
        if ($eventPayloadLength > 0) {
            $eventsBlob = $this->read_all($eventPayloadLength);
            if ($eventsBlob === false) {
                error_log("Failed to read event payload.");
                return false;
            }
        }

        return ["dt" => $dt, "eventsBlob" => $eventsBlob];
    }

    /**
     * Writes one full "frame" of commands to the Swift server.
     * @return bool true on success, false on failure
     */
    private function writeFrame(string $commandBlob): bool
    {
        $cmdLen = strlen($commandBlob);
        $outData = pack("V", $cmdLen) . $commandBlob;

        if ($this->write_all($outData) === false) {
            return false;
        }

        if ($this->isWindows) {
            fflush($this->pipe);
        }
        return true;
    }

    /**
     * Unified read function. Reads exactly $length bytes.
     * @return string|false
     */
    private function read_all($length): string|bool
    {
        if ($length == 0) {
            return "";
        }
        $buffer = "";
        $bytesRemaining = $length;
        while ($bytesRemaining > 0) {
            $data = "";
            if ($this->isWindows) {
                $data = @fread($this->pipe, $bytesRemaining);
            } else {
                $data = @socket_read(
                    $this->pipe,
                    $bytesRemaining,
                    PHP_BINARY_READ,
                );
            }

            if ($data === false) {
                $errorMsg = $this->isWindows
                    ? "fread failed"
                    : "socket_read failed: " .
                    socket_strerror(socket_last_error($this->pipe));
                error_log($errorMsg);
                return false;
            }
            if ($data === "") {
                error_log(
                    "Pipe closed (read 0 bytes). Bytes remaining: $bytesRemaining",
                );
                return false;
            }

            $buffer .= $data;
            $bytesRemaining -= strlen($data);
        }
        return $buffer;
    }

    /**
     * Unified write function. Writes all data.
     * @param string $data Data to write
     * @return int|false bytes written or false on failure
     */
    private function write_all($data): int|bool
    {
        $totalToWrite = strlen($data);
        $totalWritten = 0;

        while ($totalWritten < $totalToWrite) {
            $bytesToWrite = substr($data, $totalWritten);
            $written = 0;

            if ($this->isWindows) {
                $written = @fwrite($this->pipe, $bytesToWrite);
            } else {
                $written = @socket_write(
                    $this->pipe,
                    $bytesToWrite,
                    strlen($bytesToWrite),
                );
            }

            if ($written === false) {
                $errorMsg = $this->isWindows
                    ? "fwrite failed"
                    : "socket_write failed: " .
                    socket_strerror(socket_last_error($this->pipe));
                error_log($errorMsg);
                return false;
            }
            if ($written === 0) {
                error_log("Write returned 0 bytes.");
                return false;
            }
            $totalWritten += $written;
        }
        return $totalWritten;
    }
}
