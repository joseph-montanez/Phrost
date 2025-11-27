import Foundation
import PhrostEngineCore
import SwiftSDL

// Platform-specific imports
#if os(Windows)
    import WinSDK
#elseif os(Linux)
    import Glibc
#elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
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
#endif

// --- Constants ---
let DEFAULT_PIPE_NAME = "\\\\.\\pipe\\PhrostEngine"  // Windows Named Pipe
let DEFAULT_UNIX_SOCKET = "/tmp/PhrostEngine.socket"  // Fallback for pipes on macOS/Linux
let DEFAULT_TCP_PORT: UInt16 = 8080

// --- Unified Connection Abstraction ---
// This allows us to use the same loop for Pipes (HANDLE/FD) and Sockets (SOCKET/FD)
enum ConnectionHandle {
    #if os(Windows)
        case pipe(HANDLE)
        case socket(SOCKET)
    #else
        case fd(CInt)  // On macOS/Linux, both Sockets and Pipes are File Descriptors
    #endif
}

// --- Low-Level Read/Write Helpers ---

func rawRead(handle: ConnectionHandle, bytesToRead: Int) -> Data? {
    if bytesToRead == 0 { return Data() }
    var data = Data(capacity: bytesToRead)
    var totalRead = 0

    let bufferSize = 8192
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while totalRead < bytesToRead {
        let toRead = min(bufferSize, bytesToRead - totalRead)
        var bytesReadThisCall: Int = 0

        #if os(Windows)
            switch handle {
            case .pipe(let hPipe):
                // Original Named Pipe Logic
                var readBytes: DWORD = 0
                let ok = buffer.withUnsafeMutableBufferPointer {
                    ReadFile(hPipe, $0.baseAddress, DWORD(toRead), &readBytes, nil)
                }
                if !ok || readBytes == 0 { return nil }
                bytesReadThisCall = Int(readBytes)

            case .socket(let sock):
                // New TCP Socket Logic
                let res = buffer.withUnsafeMutableBufferPointer {
                    recv(sock, $0.baseAddress, Int32(toRead), 0)
                }
                if res <= 0 { return nil }
                bytesReadThisCall = Int(res)
            }
        #else
            // POSIX (macOS/Linux) - Original Logic preserved (read works for both)
            guard case .fd(let fd) = handle else { return nil }
            let res = buffer.withUnsafeMutableBufferPointer {
                read(fd, $0.baseAddress, toRead)
            }
            if res <= 0 { return nil }
            bytesReadThisCall = res
        #endif

        data.append(buffer, count: bytesReadThisCall)
        totalRead += bytesReadThisCall
    }
    return data
}

func rawWrite(handle: ConnectionHandle, data: Data) -> Bool {
    if data.isEmpty { return true }
    var totalWritten = 0
    let bytesToWrite = data.count

    while totalWritten < bytesToWrite {
        let toWrite = bytesToWrite - totalWritten
        var bytesWrittenThisCall: Int = 0

        #if os(Windows)
            switch handle {
            case .pipe(let hPipe):
                // Original Named Pipe Logic
                var written: DWORD = 0
                let ok = data.withUnsafeBytes {
                    let ptr = $0.baseAddress!.advanced(by: totalWritten)
                    return WriteFile(hPipe, ptr, DWORD(toWrite), &written, nil)
                }
                if !ok { return false }
                bytesWrittenThisCall = Int(written)

            case .socket(let sock):
                // New TCP Socket Logic
                let res = data.withUnsafeBytes {
                    let ptr = $0.baseAddress!.advanced(by: totalWritten)
                    return send(sock, ptr.assumingMemoryBound(to: CChar.self), Int32(toWrite), 0)
                }
                if res == SOCKET_ERROR { return false }
                bytesWrittenThisCall = Int(res)
            }
        #else
            // POSIX (macOS/Linux) - Original Logic preserved
            guard case .fd(let fd) = handle else { return false }
            let res = data.withUnsafeBytes {
                let ptr = $0.baseAddress!.advanced(by: totalWritten)
                return write(fd, ptr, toWrite)
            }
            if res <= 0 { return false }
            bytesWrittenThisCall = res
        #endif

        totalWritten += bytesWrittenThisCall
    }
    return true
}

// --- IPC Server Class ---
final class IPCServer: @unchecked Sendable {

    enum Mode {
        case pipes  // Default (Named Pipes on Win, Unix Domain Sockets on Mac/Linux)
        case sockets(port: UInt16)  // New TCP Mode
    }

    private let mode: Mode
    private var serverThread: Thread?

    // Thread Sync
    private let frameCondition = NSCondition()
    private var eventDataToSend: Data?
    private var commandDataReceived: Data?

    // Startup Sync
    private let startupCondition = NSCondition()
    private var serverReady: Bool = false
    private var startupError: Bool = false

    // State
    private enum State { case initializing, waitingForClient, connected, closed }
    private let stateLock = NSLock()
    private var _state: State = .initializing

    // Platform Handles
    #if os(Windows)
        private var pipeHandle: HANDLE?  // For Named Pipes
        private var listenSocket: SOCKET = INVALID_SOCKET  // For TCP
    #else
        private var listenFD: CInt = -1  // For both Unix Sockets and TCP
    #endif

    // Current Active Client
    private var activeClient: ConnectionHandle?

    init(mode: Mode) {
        self.mode = mode
    }

    var isConnected: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _state == .connected
    }

    func startAndWaitForReady() -> Bool {
        startupCondition.lock()
        self.serverThread = Thread { [weak self] in self?.runServerLoop() }
        self.serverThread?.start()

        while !serverReady && !startupError { startupCondition.wait() }
        let success = serverReady && !startupError
        startupCondition.unlock()
        return success
    }

    func close() {
        stateLock.lock()
        guard _state != .closed else {
            stateLock.unlock()
            return
        }
        _state = .closed
        stateLock.unlock()

        // Wake up threads
        frameCondition.lock()
        frameCondition.signal()
        frameCondition.unlock()
        startupCondition.lock()
        startupCondition.signal()
        startupCondition.unlock()

        // Force unblock sockets/pipes
        forceUnblockAccept()
    }

    private func forceUnblockAccept() {
        // Logic to create a dummy connection to self to break out of accept() calls
        #if os(Windows)
            switch mode {
            case .sockets(let port):
                // Create dummy TCP connection to localhost:port
                var wsa: WSAData = WSAData()
                let version: UInt16 = 0x0202  // MAKEWORD(2, 2) replacement
                if WSAStartup(version, &wsa) == 0 {
                    // FIXED: Cast rawValue to Int32 for socket()
                    let sock = socket(AF_INET, Int32(SOCK_STREAM), Int32(IPPROTO_TCP.rawValue))
                    if sock != INVALID_SOCKET {
                        var addr = sockaddr_in()
                        addr.sin_family = ADDRESS_FAMILY(AF_INET)
                        addr.sin_port = port.bigEndian
                        // 127.0.0.1 -> 16777343 (Little Endian representation of 7F 00 00 01)
                        addr.sin_addr.S_un.S_addr = 16_777_343

                        withUnsafePointer(to: &addr) {
                            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                                connect(sock, sa, Int32(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                        closesocket(sock)
                    }
                }
            case .pipes:
                // Dummy pipe open logic (CreateFile)
                let pipeName = swiftStringToPWSTR(DEFAULT_PIPE_NAME)
                defer { pipeName.deallocate() }
                let h = CreateFileW(
                    pipeName, DWORD(GENERIC_READ), 0, nil, DWORD(OPEN_EXISTING), 0, nil)
                if h != INVALID_HANDLE_VALUE { CloseHandle(h) }
            }
        #else
            // POSIX Unblocking
            // We create a dummy socket to connect to ourselves to unblock 'accept()'
            let sock = socket(AF_UNIX, SOCK_STREAM, 0)
            if sock >= 0 {
                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                let path = DEFAULT_UNIX_SOCKET
                let _ = withUnsafeMutablePointer(to: &addr.sun_path.0) {
                    strncpy($0, path, 103)
                }
                let _ = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        connect(sock, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
                    }
                }
                #if os(Linux)
                    Glibc.close(sock)
                #else
                    Darwin.close(sock)
                #endif
            }
        #endif
    }

    @MainActor
    func sendEventsAndGetCommands(eventData: Data, deltaSec: Double) -> Data {
        if !isConnected { return Data() }

        frameCondition.lock()

        // Prepare Payload: [Len(4)][DT(8)][Events...]
        var payload = Data()
        let totalLen = UInt32(8 + eventData.count)  // 8 bytes for Double dt
        var lenBytes = totalLen
        var dtBytes = deltaSec

        payload.append(Data(bytes: &lenBytes, count: 4))
        payload.append(Data(bytes: &dtBytes, count: 8))
        payload.append(eventData)

        self.eventDataToSend = payload
        frameCondition.signal()

        while self.commandDataReceived == nil && isConnected {
            frameCondition.wait()
        }

        let result = self.commandDataReceived ?? Data()
        self.commandDataReceived = nil
        frameCondition.unlock()

        return result
    }

    // --- Server Thread Logic ---
    private func runServerLoop() {
        print("[IPC] Server Thread Started. Mode: \(self.mode)")

        #if os(macOS) || os(Linux)
            signal(SIGPIPE, SIG_IGN)
        #endif

        #if os(Windows)
            // Initialize Winsock if needed for Sockets mode
            if case .sockets = mode {
                var wsaData = WSAData()
                let version: UInt16 = 0x0202  // MAKEWORD(2, 2) replacement
                let res = WSAStartup(version, &wsaData)
                if res != 0 {
                    print("[IPC] WSAStartup failed: \(res)")
                    failStartup()
                    return
                }
            }
        #endif

        // 1. Initialize Listener
        if !setupListener() {
            failStartup()
            return
        }

        // Ready Signal
        startupCondition.lock()
        if _state != .closed { serverReady = true }
        startupCondition.signal()
        startupCondition.unlock()

        // 2. Accept Loop
        while true {
            stateLock.lock()
            if _state == .closed {
                stateLock.unlock()
                break
            }
            _state = .waitingForClient
            stateLock.unlock()

            print("[IPC] Waiting for client connection...")

            guard let client = acceptConnection() else {
                if isClosed() { break }
                continue  // Retry on error
            }

            print("[IPC] Client Connected!")

            stateLock.lock()
            self.activeClient = client
            _state = .connected
            stateLock.unlock()

            // 3. Communication Loop
            processClientLoop(client: client)

            // Cleanup Client
            print("[IPC] Client Disconnected.")
            cleanupClient(client: client)

            stateLock.lock()
            self.activeClient = nil
            stateLock.unlock()
        }

        cleanupServer()
    }

    private func isClosed() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _state == .closed
    }

    private func failStartup() {
        startupCondition.lock()
        startupError = true
        startupCondition.signal()
        startupCondition.unlock()
    }

    // --- Protocol Logic ---

    private func processClientLoop(client: ConnectionHandle) {
        while true {
            // Wait for Main Thread to give us data
            frameCondition.lock()
            while eventDataToSend == nil && isConnected {
                frameCondition.wait()
            }

            if !isConnected {
                frameCondition.unlock()
                break
            }
            let payload = eventDataToSend!
            eventDataToSend = nil
            frameCondition.unlock()

            // Send
            if !rawWrite(handle: client, data: payload) { break }

            // Read Header (4 bytes len)
            guard let header = rawRead(handle: client, bytesToRead: 4) else { break }
            let cmdLen = header.withUnsafeBytes { $0.load(as: UInt32.self) }

            var cmdData = Data()
            if cmdLen > 0 {
                guard let body = rawRead(handle: client, bytesToRead: Int(cmdLen)) else { break }
                cmdData = body
            }

            // Return to Main Thread
            frameCondition.lock()
            commandDataReceived = cmdData
            frameCondition.signal()
            frameCondition.unlock()
        }

        // If we broke out, ensure main thread is unblocked
        frameCondition.lock()
        if commandDataReceived == nil { commandDataReceived = Data() }
        frameCondition.signal()
        frameCondition.unlock()
    }

    // --- Platform Specific Setup ---

    private func setupListener() -> Bool {
        #if os(Windows)
            switch mode {
            case .pipes:
                // --- ORIGINAL WINDOWS PIPE LOGIC ---
                let pipeName = swiftStringToPWSTR(DEFAULT_PIPE_NAME)
                defer { pipeName.deallocate() }

                let hPipe = CreateNamedPipeW(
                    pipeName,
                    DWORD(PIPE_ACCESS_DUPLEX),
                    DWORD(PIPE_TYPE_BYTE | PIPE_WAIT),
                    DWORD(PIPE_UNLIMITED_INSTANCES),
                    1024 * 1024, 1024 * 1024, 0, nil
                )
                if hPipe == INVALID_HANDLE_VALUE { return false }
                self.pipeHandle = hPipe
                return true

            case .sockets(let port):
                // --- NEW WINDOWS SOCKET LOGIC ---
                // FIXED: Use Int32(IPPROTO_TCP.rawValue)
                let sock = socket(AF_INET, Int32(SOCK_STREAM), Int32(IPPROTO_TCP.rawValue))
                if sock == INVALID_SOCKET { return false }

                var addr = sockaddr_in()
                addr.sin_family = ADDRESS_FAMILY(AF_INET)
                addr.sin_port = port.bigEndian
                addr.sin_addr.S_un.S_addr = 0  // INADDR_ANY

                let bindRes = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        bind(sock, sa, Int32(MemoryLayout<sockaddr_in>.size))
                    }
                }

                if bindRes == SOCKET_ERROR { return false }
                if listen(sock, 5) == SOCKET_ERROR { return false }

                self.listenSocket = sock
                return true
            }

        #else
            // POSIX Implementation
            var fd: CInt = -1
            var addr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            switch mode {
            case .pipes:
                // --- ORIGINAL UNIX SOCKET LOGIC ---
                unlink(DEFAULT_UNIX_SOCKET)
                fd = socket(AF_UNIX, SOCK_STREAM, 0)
                if fd < 0 { return false }

                var unAddr = sockaddr_un()
                unAddr.sun_family = sa_family_t(AF_UNIX)
                let path = DEFAULT_UNIX_SOCKET
                _ = withUnsafeMutablePointer(to: &unAddr.sun_path.0) {
                    strncpy($0, path, 103)
                }
                let unAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

                let bindRes = withUnsafePointer(to: &unAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        bind(fd, $0, unAddrLen)
                    }
                }
                if bindRes < 0 { return false }
                if listen(fd, 5) < 0 { return false }

            case .sockets(let port):
                // --- NEW POSIX TCP SOCKET LOGIC ---
                fd = socket(AF_INET, SOCK_STREAM, 0)
                if fd < 0 { return false }

                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = port.bigEndian
                #if os(Linux)
                    addr.sin_addr.s_addr = 0
                #else
                    addr.sin_addr.s_addr = 0  // INADDR_ANY
                #endif

                let bindRes = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        bind(fd, $0, addrLen)
                    }
                }
                if bindRes < 0 { return false }
                if listen(fd, 5) < 0 { return false }
            }
            self.listenFD = fd
            return true
        #endif
    }

    private func acceptConnection() -> ConnectionHandle? {
        #if os(Windows)
            switch mode {
            case .pipes:
                // --- ORIGINAL WINDOWS PIPE ACCEPT ---
                guard let h = self.pipeHandle else { return nil }
                // Blocking wait for connection
                if ConnectNamedPipe(h, nil) || GetLastError() == ERROR_PIPE_CONNECTED {
                    return .pipe(h)
                }
                return nil

            case .sockets:
                // --- NEW WINDOWS SOCKET ACCEPT ---
                let clientSock = accept(self.listenSocket, nil, nil)
                if clientSock == INVALID_SOCKET { return nil }

                // Disable Nagle (TCP_NODELAY)
                // FIXED: Use Int32 for flag instead of BOOL, cast IPPROTO_TCP.rawValue
                var flag: Int32 = 1
                let flagSize = Int32(MemoryLayout<Int32>.size)

                _ = withUnsafePointer(to: &flag) { flagPtr in
                    flagPtr.withMemoryRebound(to: CChar.self, capacity: Int(flagSize)) { charPtr in
                        setsockopt(
                            clientSock, Int32(IPPROTO_TCP.rawValue), Int32(TCP_NODELAY), charPtr,
                            flagSize)
                    }
                }

                return .socket(clientSock)
            }
        #else
            // POSIX (Accept works for both Unix Domain Sockets and TCP)
            let clientFD = accept(self.listenFD, nil, nil)
            if clientFD < 0 { return nil }
            return .fd(clientFD)
        #endif
    }

    private func cleanupClient(client: ConnectionHandle) {
        #if os(Windows)
            switch client {
            case .pipe(let h):
                DisconnectNamedPipe(h)
            case .socket(let s):
                closesocket(s)
            }
        #else
            if case .fd(let f) = client {
                #if os(Linux)
                    Glibc.close(f)
                #else
                    Darwin.close(f)
                #endif
            }
        #endif
    }

    private func cleanupServer() {
        #if os(Windows)
            if let h = pipeHandle { CloseHandle(h) }
            if listenSocket != INVALID_SOCKET { closesocket(listenSocket) }
            if case .sockets = mode { WSACleanup() }
        #else
            if listenFD >= 0 {
                #if os(Linux)
                    Glibc.close(listenFD)
                #else
                    Darwin.close(listenFD)
                #endif
            }
            if case .pipes = mode { unlink(DEFAULT_UNIX_SOCKET) }
        #endif
    }
}

@main
struct PhrostIPC {
    @MainActor
    static func main() {
        print("[Main] Starting PhrostIPC...")

        // --- CLI Argument Parsing ---
        let args = CommandLine.arguments
        var ipcMode = IPCServer.Mode.pipes  // Default

        for i in 0..<args.count {
            if args[i] == "--mode" && i + 1 < args.count {
                let val = args[i + 1]
                if val == "sockets" {
                    var port: UInt16 = 8080
                    // Look for --port
                    if let pIdx = args.firstIndex(of: "--port"), pIdx + 1 < args.count {
                        port = UInt16(args[pIdx + 1]) ?? 8080
                    }
                    ipcMode = .sockets(port: port)
                }
            }
        }

        let server = IPCServer(mode: ipcMode)

        if !server.startAndWaitForReady() {
            print("[Main] Server failed to start.")
            return
        }

        print("[Main] Initializing Engine...")
        guard let engine = PhrostEngine(title: "Phrost Engine", width: 640, height: 480, flags: 0)
        else {
            server.close()
            return
        }

        let updateCallback = { (frameCount: Int, deltaSec: Double, eventData: Data) -> Data in
            if !server.isConnected { Thread.sleep(forTimeInterval: 0.1) }
            return server.sendEventsAndGetCommands(eventData: eventData, deltaSec: deltaSec)
        }

        engine.run(updateCallback: updateCallback)
        server.close()
    }
}
