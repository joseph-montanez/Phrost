import Foundation
import PhrostEngineCore
import SwiftSDL

// Platform-specific imports
#if os(Windows)
    import WinSDK  // Core C APIs for Windows
#elseif os(Linux)
    import Glibc  // Core C APIs for Linux
#elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin  // Core C APIs for Apple platforms
#else
    #error("Unsupported platform for core C library import")
#endif

// --- Windows-Specific Helpers ---
#if os(Windows)
    /// Converts a Swift String to a PWSTR (Windows wide-character string).
    /// The caller is responsible for deallocating the returned pointer.
    func swiftStringToPWSTR(_ str: String) -> PWSTR {
        let utf16 = str.utf16
        let pwstr = (Array(utf16) + [0]).withUnsafeBufferPointer {
            let ptr = UnsafeMutablePointer<WCHAR>.allocate(capacity: $0.count)
            ptr.initialize(from: $0.baseAddress!, count: $0.count)
            return PWSTR(ptr)
        }
        return pwstr
    }

    /// Reads a specific number of bytes from a Windows pipe HANDLE.
    func readPipe(handle: HANDLE?, bytesToRead: Int) -> Data? {
        guard let handle = handle else {
            print("readPipe failed: handle is nil.")
            return nil
        }
        guard bytesToRead >= 0 else {
            print("readPipe failed: bytesToRead cannot be negative.")
            return nil
        }
        if bytesToRead == 0 { return Data() }

        var data = Data(capacity: bytesToRead)
        var totalBytesRead: Int = 0
        let bufferSize = 8192
        var readBuffer = [UInt8](repeating: 0, count: bufferSize)

        while totalBytesRead < bytesToRead {
            let bytesRemaining = bytesToRead - totalBytesRead
            let bytesToReadThisCall = min(bufferSize, bytesRemaining)
            var bytesReadThisCall: DWORD = 0
            let ok = readBuffer.withUnsafeMutableBufferPointer { bufPtr in
                ReadFile(
                    handle, bufPtr.baseAddress, DWORD(bytesToReadThisCall), &bytesReadThisCall, nil)
            }
            let lastError = GetLastError()
            if !ok || bytesReadThisCall == 0 {
                print(
                    "readPipe failed. Bytes read: \(bytesReadThisCall). Error: \(lastError). Client disconnected."
                )
                return nil
            }
            data.append(readBuffer, count: Int(bytesReadThisCall))
            totalBytesRead += Int(bytesReadThisCall)
        }
        return data
    }

    /// Writes Data to a Windows pipe HANDLE.
    func writePipe(handle: HANDLE?, data: Data) -> Bool {
        guard let handle = handle else {
            print("writePipe failed: handle is nil.")
            return false
        }
        if data.isEmpty { return true }

        var totalBytesWritten: Int = 0
        let bytesToWrite = data.count
        while totalBytesWritten < bytesToWrite {
            let bytesRemaining = bytesToWrite - totalBytesWritten
            var bytesWrittenThisCall: DWORD = 0
            let bytesToWriteThisCall = min(bytesRemaining, Int(DWORD.max))
            if bytesToWriteThisCall <= 0 { break }
            let ok = data.withUnsafeBytes { dataPtr in
                let ptr = dataPtr.baseAddress!.advanced(by: totalBytesWritten)
                return WriteFile(
                    handle, ptr, DWORD(bytesToWriteThisCall), &bytesWrittenThisCall, nil)
            }
            let lastError = GetLastError()
            if !ok {
                print(
                    "writePipe failed. Wrote \(bytesWrittenThisCall) bytes. Error: \(lastError). Client disconnected."
                )
                return false
            }
            if bytesWrittenThisCall == 0 && bytesToWriteThisCall > 0 {
                print("writePipe warning: WriteFile wrote 0 bytes unexpectedly.")
                return false
            }
            totalBytesWritten += Int(bytesWrittenThisCall)
        }
        return totalBytesWritten == bytesToWrite
    }
#endif  // os(Windows)

// --- macOS-Specific Helpers ---
#if os(macOS)
    /// Reads a specific number of bytes from a POSIX file descriptor.
    func readPipe(fd: CInt, bytesToRead: Int) -> Data? {
        guard fd >= 0 else {
            print("readPipe failed: invalid file descriptor.")
            return nil
        }
        guard bytesToRead >= 0 else {
            print("readPipe failed: bytesToRead cannot be negative.")
            return nil
        }
        if bytesToRead == 0 { return Data() }

        var data = Data(capacity: bytesToRead)
        var totalBytesRead: Int = 0
        let bufferSize = 8192
        var readBuffer = [UInt8](repeating: 0, count: bufferSize)

        while totalBytesRead < bytesToRead {
            let bytesRemaining = bytesToRead - totalBytesRead
            let bytesToReadThisCall = min(bufferSize, bytesRemaining)
            var bytesReadThisCall: Int = 0

            bytesReadThisCall = readBuffer.withUnsafeMutableBufferPointer { bufPtr in
                Darwin.read(fd, bufPtr.baseAddress, bytesToReadThisCall)
            }

            if bytesReadThisCall < 0 {
                // Error
                print(
                    "readPipe failed. Error: \(String(cString: strerror(errno))). Client disconnected."
                )
                return nil
            } else if bytesReadThisCall == 0 {
                // EOF (Client disconnected)
                print("readPipe failed. Read 0 bytes (EOF). Client disconnected.")
                return nil
            }

            data.append(readBuffer, count: Int(bytesReadThisCall))
            totalBytesRead += Int(bytesReadThisCall)
        }
        return data
    }

    /// Writes Data to a POSIX file descriptor.
    func writePipe(fd: CInt, data: Data) -> Bool {
        guard fd >= 0 else {
            print("writePipe failed: invalid file descriptor.")
            return false
        }
        if data.isEmpty { return true }

        var totalBytesWritten: Int = 0
        let bytesToWrite = data.count
        while totalBytesWritten < bytesToWrite {
            let bytesRemaining = bytesToWrite - totalBytesWritten
            var bytesWrittenThisCall: Int = 0

            bytesWrittenThisCall = data.withUnsafeBytes { dataPtr in
                let ptr = dataPtr.baseAddress!.advanced(by: totalBytesWritten)
                return Darwin.write(fd, ptr, bytesRemaining)
            }

            if bytesWrittenThisCall <= 0 {
                if bytesWrittenThisCall < 0 {
                    print(
                        "writePipe failed. Error: \(String(cString: strerror(errno))). Client disconnected."
                    )
                } else {
                    print("writePipe warning: write wrote 0 bytes unexpectedly.")
                }
                return false
            }

            totalBytesWritten += Int(bytesWrittenThisCall)
        }
        return totalBytesWritten == bytesToWrite
    }
#endif  // os(macOS)

// --- Manages the IPC Thread ---
final class IPCServer: @unchecked Sendable {

    // --- Platform-specific properties ---
    #if os(Windows)
        private let pipeName: String
        private var pipeHandle: HANDLE?  // This is the persistent server pipe
    #elseif os(macOS)
        private let pipePath: String
        private var listeningSocket: CInt = -1  // Server's persistent listening socket FD
        private var clientSocket: CInt = -1  // Connected client's FD
    #endif

    // --- Platform-agnostic properties ---
    private var serverThread: Thread?

    // Condition for synchronizing frame data between threads
    private let frameCondition = NSCondition()
    private var eventDataToSend: Data?
    private var commandDataReceived: Data?

    // Condition + flags for synchronizing server startup
    private let startupCondition = NSCondition()
    private var serverReady: Bool = false  // Guarded by startupCondition
    private var startupError: Bool = false  // Guarded by startupCondition

    private enum State {
        case initializing
        case waitingForClient
        case connected
        case closed
    }

    // Separate lock ONLY for runtime state changes after startup
    private let stateLock = NSLock()
    private var _state: State = .initializing
    private var state: State {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _state
        }
        set {
            stateLock.lock()
            _state = newValue
            stateLock.unlock()
        }
    }

    public var isConnected: Bool { self.state == .connected }
    public var hasStartupFailed: Bool {
        startupCondition.lock()
        defer { startupCondition.unlock() }
        return self.startupError
    }

    /// Initializes the server with a platform-specific name.
    /// - Parameter pipeName: On Windows: `\\.\pipe\MyPipe`. On macOS, this will be
    ///   transformed to `/tmp/MyPipe.socket`.
    init(pipeName: String) {
        #if os(Windows)
            self.pipeName = pipeName
        #elseif os(macOS)
            // Transform the Windows pipe name to a POSIX path
            let baseName = pipeName.replacingOccurrences(of: "\\\\.\\pipe\\", with: "")
            self.pipePath = "/tmp/\(baseName).socket"
            print("[IPCServer] Using POSIX socket path: \(self.pipePath)")
        #endif
    }

    /// Starts the server thread and waits until it's ready or fails.
    /// Returns true if the server is ready, false on failure.
    func startAndWaitForReady() -> Bool {
        print("[MainThread] Starting IPC server thread...")
        startupCondition.lock()  // Lock startup BEFORE creating thread

        let thread = Thread { [weak self] in
            self?.runServerLoop()
        }
        self.serverThread = thread
        thread.start()

        print("[MainThread] Waiting for server thread to become ready...")
        while !serverReady && !startupError {
            startupCondition.wait()
        }

        let reportedError = self.startupError
        let reportedReady = self.serverReady
        print(
            "[MainThread] Woke up from startup wait. Ready=\(reportedReady), Error=\(reportedError)"
        )
        startupCondition.unlock()  // Unlock AFTER checking flags

        if reportedError || !reportedReady {
            print("[MainThread] Server thread reported startup error or did not become ready.")
            self.close()  // Ensure cleanup if startup failed
            return false
        }

        print("[MainThread] Server thread is ready and waiting for client.")
        return true
    }

    /// Signals the server thread to close.
    func close() {
        stateLock.lock()
        let currentState = self._state
        guard currentState != .closed else {
            stateLock.unlock()
            print("Close called but already closed.")
            return
        }
        print("Closing IPC server (current state: \(currentState))...")
        self._state = .closed
        stateLock.unlock()

        // Wake up threads waiting on conditions
        frameCondition.lock()
        frameCondition.signal()
        frameCondition.unlock()
        startupCondition.lock()
        startupCondition.signal()
        startupCondition.unlock()

        // --- MODIFIED: Unblock the blocking call (ConnectNamedPipe / accept) ---
        // The server loop is now responsible for its own handle/socket cleanup.
        // We just need to unblock it so it can see the `.closed` state.
        #if os(Windows)
            // Unblock ConnectNamedPipe if it was waiting
            if currentState == .waitingForClient || currentState == .initializing {
                print("Attempting to unblock ConnectNamedPipe...")
                let widePipeName = swiftStringToPWSTR(self.pipeName)
                defer { widePipeName.deallocate() }
                let hDummy = CreateFileW(
                    widePipeName, DWORD(GENERIC_READ) | DWORD(GENERIC_WRITE), DWORD(0), nil,
                    DWORD(OPEN_EXISTING), DWORD(0), nil)
                if hDummy != INVALID_HANDLE_VALUE {
                    CloseHandle(hDummy)
                    print("Dummy client connected and closed.")
                } else {
                    print(
                        "Could not create dummy client (Error: \(GetLastError())). This might be okay if already closed/connected."
                    )
                }
            }
        #elseif os(macOS)
            // Unblock accept() if it was waiting
            if currentState == .waitingForClient || currentState == .initializing {
                print("Attempting to unblock accept() with a dummy connection...")
                var dummyAddr = sockaddr_un()
                dummyAddr.sun_family = sa_family_t(AF_UNIX)

                let sunPathSize = MemoryLayout.size(ofValue: dummyAddr.sun_path)
                _ = withUnsafeMutablePointer(to: &dummyAddr.sun_path.0) {
                    strncpy($0, self.pipePath, sunPathSize - 1)
                }

                let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

                let hDummy = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
                if hDummy >= 0 {
                    _ = withUnsafePointer(to: &dummyAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                            Darwin.connect(hDummy, saPtr, addrLen)
                        }
                    }
                    Darwin.close(hDummy)
                    print("Dummy client connection attempt finished.")
                } else {
                    print("Could not create dummy client socket.")
                }
            }
        #endif

        print("IPC Server close actions finished.")
    }

    /// --- Called by the ENGINE (Main Thread) ---
    /// This function blocks the main thread until the IPC thread
    /// has successfully sent/received data from the client.
    @MainActor
    func sendEventsAndGetCommands(eventData: Data, deltaSec: Double) -> Data {

        // --- MODIFIED: Don't block if not connected ---
        // If we aren't connected, we can't send. Return immediately.
        // The server thread is busy waiting for a connection, not for our data.
        if self.state != .connected {
            return Data()
        }

        frameCondition.lock()

        // Format: [Total Payload Length (UInt32)] + [Delta Sec (Double)] + [Event Data (Bytes)]
        let payloadLength = MemoryLayout<Double>.size + eventData.count
        var totalLength = UInt32(payloadLength)
        var dataToSend = Data(capacity: MemoryLayout<UInt32>.size + payloadLength)

        // 1. Prepend the total length of the *following* data (dt + events)
        dataToSend.append(Data(bytes: &totalLength, count: MemoryLayout<UInt32>.size))
        // 2. Append the delta time (dt)
        var dt = deltaSec
        dataToSend.append(Data(bytes: &dt, count: MemoryLayout<Double>.size))
        // 3. Append the actual event data
        dataToSend.append(eventData)

        // Give the fully constructed data to the IPC thread
        self.eventDataToSend = dataToSend

        // Signal the IPC thread that data is ready
        frameCondition.signal()

        // --- MODIFIED: Wait only while connected ---
        // Wait for the IPC thread to signal back with command data
        while self.commandDataReceived == nil && self.state == .connected {
            frameCondition.wait()
        }

        // We were woken up. Get the command data.
        let data = self.commandDataReceived ?? Data()
        self.commandDataReceived = nil  // Clear it for the next frame

        frameCondition.unlock()

        // If state changed to non-connected *while we were waiting*, return empty.
        if self.state != .connected {
            print("[MainThread][sendEvents] Client disconnected while waiting for command data.")
            return Data()
        }

        return data
    }

    /// --- Unblocks the main thread on disconnect ---
    /// This is called from runServerLoop when a read/write fails.
    nonisolated private func handleClientDisconnect() {
        print("[ServerThread] Client disconnected.")

        // Set state back to waiting
        self.state = .waitingForClient

        // Unblock the main thread if it's waiting in sendEventsAndGetCommands
        frameCondition.lock()
        self.commandDataReceived = Data()  // Give it an empty response
        frameCondition.signal()
        frameCondition.unlock()

        // Clean up the *client-specific* handles/sockets
        #if os(Windows)
            if let handle = self.pipeHandle {
                DisconnectNamedPipe(handle)
            }
        #elseif os(macOS)
            stateLock.lock()
            if self.clientSocket >= 0 {
                Darwin.close(self.clientSocket)
                self.clientSocket = -1
            }
            stateLock.unlock()
        #endif
    }

    /// --- Runs on the separate IPC THREAD ---
    nonisolated private func runServerLoop() {

        #if os(macOS)
            // This prevents the server from crashing if a client disconnects while
            // we are trying to write to the socket. The write() call will
            // instead return -1, and errno will be set to EPIPE (Broken Pipe).
            // Our readPipe/writePipe functions already handle this return value.
            signal(SIGPIPE, SIG_IGN)
        #endif

        #if os(Windows)
            // --- Windows Server Loop Logic ---
            let widePipeName = swiftStringToPWSTR(self.pipeName)
            defer { widePipeName.deallocate() }

            let pipeMode = PIPE_TYPE_BYTE | PIPE_WAIT
            let bufferSize: DWORD = 1024 * 1024

            print("[ServerThread] Creating named pipe...")
            let hPipe = CreateNamedPipeW(
                widePipeName, DWORD(PIPE_ACCESS_DUPLEX), DWORD(pipeMode), DWORD(1), bufferSize,
                bufferSize, 0, nil)

            if hPipe == INVALID_HANDLE_VALUE {
                print("[ServerThread] Failed to create named pipe. Error: \(GetLastError())")
                startupCondition.lock()
                self.startupError = true
                startupCondition.signal()
                startupCondition.unlock()
                return
            }
            print("[ServerThread] Named pipe created successfully (Handle: \(hPipe)).")

            // --- MODIFIED: Store the persistent pipe handle ---
            stateLock.lock()
            self.pipeHandle = hPipe
            stateLock.unlock()

            // --- Signal readiness ---
            startupCondition.lock()
            if self.state != .closed {
                print("[ServerThread] Signaling main thread: Server Ready.")
                self.serverReady = true
            } else {
                print("[ServerThread] Server was closed during init. Cleaning up.")
                self.startupError = true
            }
            startupCondition.signal()
            startupCondition.unlock()

            if self.startupError {
                CloseHandle(hPipe)
                return
            }

            // --- MODIFIED: Mega-loop to accept multiple connections ---
            while self.state != .closed {
                self.state = .waitingForClient
                print("[ServerThread] Waiting for client connection...")

                // --- 1. Block until client connects ---
                if !ConnectNamedPipe(hPipe, nil) {
                    let lastError = GetLastError()
                    if self.state == .closed {
                        print(
                            "[ServerThread] Exiting: Closed while waiting for connection (ConnectNamedPipe returned false)."
                        )
                        break  // Exit mega-loop
                    }
                    if lastError != ERROR_PIPE_CONNECTED {
                        print("[ServerThread] Failed to connect named pipe. Error: \(lastError)")
                        // This is a server error, break the loop and exit thread
                        self.state = .closed
                        frameCondition.lock()
                        frameCondition.signal()
                        frameCondition.unlock()
                        break  // Exit mega-loop
                    }
                    print(
                        "[ServerThread] Client connected before ConnectNamedPipe call (ERROR_PIPE_CONNECTED)."
                    )
                }

                if self.state == .closed {
                    print("[ServerThread] Exiting: Closed immediately after client connection.")
                    DisconnectNamedPipe(hPipe)
                    break  // Exit mega-loop
                }

                print("[ServerThread] Client connected.")
                self.state = .connected

                // --- 2. Main Communication Loop (Inner) ---
                while self.state == .connected {
                    frameCondition.lock()
                    while self.eventDataToSend == nil && self.state == .connected {
                        frameCondition.wait()
                    }

                    if self.state != .connected {
                        // Can be .closed (server shutdown) or .waitingForClient (disconnect)
                        print("[ServerThread] Closing loop (state check after wait).")
                        frameCondition.unlock()
                        break  // Exit inner loop
                    }

                    guard let dataToSend = self.eventDataToSend else {
                        frameCondition.unlock()
                        continue
                    }
                    self.eventDataToSend = nil
                    frameCondition.unlock()

                    guard writePipe(handle: self.pipeHandle, data: dataToSend) else {
                        handleClientDisconnect()
                        break  // Exit inner loop
                    }

                    guard let lengthHeaderData = readPipe(handle: self.pipeHandle, bytesToRead: 4)
                    else {
                        handleClientDisconnect()
                        break  // Exit inner loop
                    }

                    let commandLength = lengthHeaderData.withUnsafeBytes {
                        $0.load(as: UInt32.self)
                    }
                    var commandData = Data()

                    if commandLength > 0 {
                        guard
                            let data = readPipe(
                                handle: self.pipeHandle, bytesToRead: Int(commandLength))
                        else {
                            handleClientDisconnect()
                            break  // Exit inner loop
                        }
                        commandData = data
                    }

                    frameCondition.lock()
                    if self.state == .connected {
                        self.commandDataReceived = commandData
                        frameCondition.signal()
                    }
                    frameCondition.unlock()
                }  // End inner communication loop
            }  // End mega-loop

            // --- 3. Final Server Cleanup ---
            print("[ServerThread] IPC Server thread loop finished.")
            stateLock.lock()
            if let handle = self.pipeHandle {
                print("[ServerThread] Final cleanup: Closing pipe handle.")
                DisconnectNamedPipe(handle)
                CloseHandle(handle)
                self.pipeHandle = nil
            }
            stateLock.unlock()

        #elseif os(macOS)
            // --- macOS Server Loop Logic ---

            // 1. Clean up old socket file, if any
            unlink(self.pipePath)  // Best effort, ignore error

            // 2. Create socket
            let localListeningSocket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            guard localListeningSocket >= 0 else {
                print(
                    "[ServerThread] Failed to create socket. Error: \(String(cString: strerror(errno)))"
                )
                startupCondition.lock()
                self.startupError = true
                startupCondition.signal()
                startupCondition.unlock()
                return
            }
            print("[ServerThread] Socket created (FD: \(localListeningSocket)).")

            // 3. Bind socket to path
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)

            let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
            _ = withUnsafeMutablePointer(to: &addr.sun_path.0) {
                strncpy($0, self.pipePath, sunPathSize - 1)
            }

            let addrLen = socklen_t(
                MemoryLayout.size(ofValue: addr.sun_family) + strlen(self.pipePath) + 1)

            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    Darwin.bind(localListeningSocket, saPtr, addrLen)
                }
            }

            guard bindResult == 0 else {
                print(
                    "[ServerThread] Failed to bind socket to \(self.pipePath). Error: \(String(cString: strerror(errno)))"
                )
                Darwin.close(localListeningSocket)
                startupCondition.lock()
                self.startupError = true
                startupCondition.signal()
                startupCondition.unlock()
                return
            }
            print("[ServerThread] Socket bound to path.")

            // 4. Listen for connections
            guard Darwin.listen(localListeningSocket, 5) == 0 else {
                print(
                    "[ServerThread] Failed to listen on socket. Error: \(String(cString: strerror(errno)))"
                )
                Darwin.close(localListeningSocket)
                unlink(self.pipePath)
                startupCondition.lock()
                self.startupError = true
                startupCondition.signal()
                startupCondition.unlock()
                return
            }

            // 5. Signal main thread: Ready
            startupCondition.lock()
            if self.state != .closed {
                print("[ServerThread] Signaling main thread: Server Ready.")
                stateLock.lock()
                self.listeningSocket = localListeningSocket  // Store the persistent FD
                stateLock.unlock()
                self.serverReady = true
            } else {
                print(
                    "[ServerThread] Server state is closed immediately after listen. Cleaning up."
                )
                Darwin.close(localListeningSocket)
                unlink(self.pipePath)
                self.startupError = true
                print("[ServerThread] Signaling main thread: Startup Error (was closed).")
            }
            startupCondition.signal()
            startupCondition.unlock()

            guard !self.startupError else {
                print("[ServerThread] Exiting runServerLoop early due to closed state during init.")
                return
            }

            // --- MODIFIED: Mega-loop to accept multiple connections ---
            while self.state != .closed {

                // --- 1. Block until client connects (accept) ---
                self.state = .waitingForClient
                print("[ServerThread] Waiting for client connection (accept)...")
                let localClientSocket = Darwin.accept(localListeningSocket, nil, nil)

                if localClientSocket < 0 {
                    if self.state == .closed {
                        print(
                            "[ServerThread] Exiting: Closed while waiting for connection (accept failed, likely intended)."
                        )
                    } else {
                        print(
                            "[ServerThread] Failed to accept client connection. Error: \(String(cString: strerror(errno)))"
                        )
                        // This is a server error, break loop and exit thread
                        self.state = .closed
                        frameCondition.lock()
                        frameCondition.signal()
                        frameCondition.unlock()
                    }
                    break  // Exit mega-loop
                }

                if self.state == .closed {
                    print("[ServerThread] Exiting: Closed immediately after client connection.")
                    Darwin.close(localClientSocket)
                    break  // Exit mega-loop
                }

                print("[ServerThread] Client connected (FD: \(localClientSocket)).")
                stateLock.lock()
                self.clientSocket = localClientSocket  // Store the client FD
                stateLock.unlock()
                self.state = .connected

                // --- 2. Main Communication Loop (Inner) ---
                while self.state == .connected {
                    frameCondition.lock()
                    while self.eventDataToSend == nil && self.state == .connected {
                        frameCondition.wait()
                    }

                    if self.state != .connected {
                        print("[ServerThread] Closing loop (state check after wait).")
                        frameCondition.unlock()
                        break  // Exit inner loop
                    }

                    guard let dataToSend = self.eventDataToSend else {
                        frameCondition.unlock()
                        continue
                    }
                    self.eventDataToSend = nil
                    frameCondition.unlock()

                    guard writePipe(fd: self.clientSocket, data: dataToSend) else {
                        handleClientDisconnect()
                        break  // Exit inner loop
                    }

                    guard let lengthHeaderData = readPipe(fd: self.clientSocket, bytesToRead: 4)
                    else {
                        handleClientDisconnect()
                        break  // Exit inner loop
                    }

                    let commandLength = lengthHeaderData.withUnsafeBytes {
                        $0.load(as: UInt32.self)
                    }
                    var commandData = Data()

                    if commandLength > 0 {
                        guard
                            let data = readPipe(
                                fd: self.clientSocket, bytesToRead: Int(commandLength))
                        else {
                            handleClientDisconnect()
                            break  // Exit inner loop
                        }
                        commandData = data
                    }

                    frameCondition.lock()
                    if self.state == .connected {
                        self.commandDataReceived = commandData
                        frameCondition.signal()
                    }
                    frameCondition.unlock()
                }  // End inner communication loop
            }  // End mega-loop

            // --- 3. Final Server Cleanup ---
            print("[ServerThread] IPC Server thread loop finished.")
            stateLock.lock()
            if self.clientSocket >= 0 {
                print("[ServerThread] Final cleanup: Closing client socket.")
                Darwin.close(self.clientSocket)
                self.clientSocket = -1
            }
            if self.listeningSocket >= 0 {
                print("[ServerThread] Final cleanup: Closing listening socket.")
                Darwin.close(self.listeningSocket)
                self.listeningSocket = -1
            }
            stateLock.unlock()
            unlink(self.pipePath)  // Final file cleanup

        #endif  // os(macOS)

        // Final state update (platform-agnostic)
        if self.state != .closed {
            self.state = .closed
            frameCondition.lock()
            frameCondition.signal()
            frameCondition.unlock()
        }
        print("[ServerThread] runServerLoop finished.")
    }
}

// --- Main Entry Point --- (Completely platform-agnostic)
@main
struct PhrostIPC {

    @MainActor
    static func main() {
        print("[MainThread] Application started.")

        // This name is now handled conditionally by the IPCServer's init
        let server = IPCServer(pipeName: "\\\\.\\pipe\\PhrostEngine")

        guard server.startAndWaitForReady() else {
            print("[MainThread] IPC Server failed to start or was closed during startup. Exiting.")
            return
        }

        print("[MainThread] Initializing Phrost Engine...")
        guard
            let engine = PhrostEngine(
                title: "Phrost Engine (IPC Server)",
                width: 640,
                height: 480,
                flags: 0
            )
        else {
            print("[MainThread] Failed to initialize Phrost Engine. Closing server.")
            server.close()
            return
        }
        print("[MainThread] Phrost Engine Initialized Successfully.")

        let updateCallback = { (frameCount: Int, deltaSec: Double, eventData: Data) -> Data in
            // Wait for connection if we just started
            if !server.isConnected {
                // Don't burn CPU, just wait a bit for a client to connect
                Thread.sleep(forTimeInterval: 0.1)
                // return Data() // We'll let sendEventsAndGetCommands handle this
            }

            // This call is blocking (if connected) or non-blocking (if disconnected)
            let commandData = server.sendEventsAndGetCommands(
                eventData: eventData, deltaSec: deltaSec)

            // --- MODIFIED: Do NOT stop the engine on disconnect ---
            // The server is now waiting for a new client, so the engine should keep running.
            if !server.isConnected {
                // Optional: Log that we are waiting
                if frameCount % 60 == 0 {  // Log once per second
                    print("[MainThread] Waiting for client to connect...")
                }
            }
            return commandData
        }

        print("[MainThread] Starting engine run loop...")
        engine.run(updateCallback: updateCallback)

        print("[MainThread] Engine loop finished. PhrostIPC shutting down.")
        server.close()
        print("[MainThread] PhrostIPC main function finished.")
    }
}
