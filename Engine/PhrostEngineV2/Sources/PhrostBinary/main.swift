import Foundation

// --- Platform-Specific Imports ---
#if os(Windows)
    import WinSDK  // Import the Windows SDK for file watching
#endif

// --- Configuration Struct ---
// This struct maps directly to the settings.json file
struct AppSettings: Codable {
    let serverExecutableName: String  // Path to the server executable (e.g., "engine/PhrostIPC")
    let clientInterpreterName: String
    let clientScriptName: String
    let clientInterpreterParams: [String]?
    let watchDirectoryName: String  // Path to the hot-reload directory (e.g., "assets")
    let watchExclusions: [String]?  // Optional array of exclusion patterns
    let clientLogging: Bool?

    // --- NEW: IPC Configuration ---
    let ipcMode: String?  // "pipes" (default) or "sockets"
    let ipcPort: Int?  // Default 8080
}

// --- Find App Directory ---
guard let wrapperURL = Bundle.main.executableURL else {
    fatalError(
        """
        [Wrapper] Error: Could not find the wrapper's (PhrostBinary) own executable URL.
        This should not happen. Please try rebuilding the project.
        """
    )
}
print("[Wrapper] Wrapper executable is at: \(wrapperURL.path)")

let appDirectoryURL = wrapperURL.deletingLastPathComponent()
print("[Wrapper] App bundle directory is: \(appDirectoryURL.path)")

// --- Logger ---
let logFileURL = appDirectoryURL.appendingPathComponent("phrost.log")
let logger = Logger(logFileURL: logFileURL)

// --- Load Settings from JSON ---
let settings: AppSettings
let settingsURL = appDirectoryURL.appendingPathComponent("settings.json")

do {
    print("[Wrapper] Loading configuration from: \(settingsURL.path)")
    let settingsData = try Data(contentsOf: settingsURL)
    settings = try JSONDecoder().decode(AppSettings.self, from: settingsData)

    print(
        "[Wrapper] Config loaded. Server: \(settings.serverExecutableName), Client: \(settings.clientInterpreterName)"
    )

} catch {
    fatalError(
        """
        [Wrapper] Error: Failed to load or parse 'settings.json'.
        Make sure the file exists in \(appDirectoryURL.path) and is valid JSON.
        Error details: \(error.localizedDescription)
        """
    )
}

// --- Extract IPC Settings Globally ---
// We do this here so both the Server setup and the Client Relauncher can use them.
let globalIpcMode = settings.ipcMode ?? "pipes"
let globalIpcPort = settings.ipcPort ?? 8080

// --- Find All Relative Paths ---

func findRelativeURL(forName name: String, isExecutable: Bool) -> URL {
    // This correctly handles paths like "runtime/php" or "engine/PhrostIPC"
    var fileURL = appDirectoryURL.appendingPathComponent(name)

    #if os(Windows)
        if isExecutable {
            fileURL.appendPathExtension("exe")
        }
    #endif

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        fatalError(
            """
            [Wrapper] Error: Missing required file!
            Could not find: \(name)
            Expected it to be in the app directory:
            \(appDirectoryURL.path)
            """
        )
    }

    print("✅ [Wrapper] Found \(name) at: \(fileURL.path)")
    return fileURL
}

// Find all our required files (now using the 'settings' object)
let serverExecutableURL = findRelativeURL(
    forName: settings.serverExecutableName, isExecutable: true)
let clientExecutableURL = findRelativeURL(
    forName: settings.clientInterpreterName, isExecutable: true)
let clientScriptURL = findRelativeURL(forName: settings.clientScriptName, isExecutable: false)

// --- Configure Server Process ---
let serverProcess = Process()
serverProcess.executableURL = serverExecutableURL

// NEW: Pass IPC settings to Server
var serverArgs = [String]()
serverArgs.append("--mode")
serverArgs.append(globalIpcMode)

if globalIpcMode == "sockets" {
    serverArgs.append("--port")
    serverArgs.append(String(globalIpcPort))
}

serverProcess.arguments = serverArgs
print("[Wrapper] Server arguments set to: \(serverArgs.joined(separator: " "))")

// --- Configure Client Process ---
var clientProcess = Process()
clientProcess.executableURL = clientExecutableURL

// Build the arguments array dynamically
var clientArgs = [String]()
if let params = settings.clientInterpreterParams {
    clientArgs.append(contentsOf: params)
}
clientArgs.append(clientScriptURL.path)  // Add the script path

// NEW: Pass IPC settings to Client Script (as arguments the script can read)
clientArgs.append(globalIpcMode)
clientArgs.append(String(globalIpcPort))

clientProcess.arguments = clientArgs
print("[Wrapper] Client arguments set to: \(clientArgs.joined(separator: " "))")

if settings.clientLogging ?? true {
    // Default to TRUE if the setting is missing from JSON
    setupClientLogging(for: clientProcess, logger: logger)
} else {
    Task {
        await logger.log(
            "ℹ️ [Wrapper] Client logging disabled via settings. No terminal window should appear.")
    }
}

// --- Setup Signal Handling & State ---

// We must keep these alive for the lifetime of the app.
#if os(macOS) || os(Linux)
    // --- Polling mechanism state ---
    var fileMonitorTask: Task<Void, Never>?
    var fileStates = [String: Date]()  // Dictionary to store file path: modificationDate
#elseif os(Windows)
    var dirHandle: HANDLE = INVALID_HANDLE_VALUE
#endif
var isRelaunching = false  // This is thread-safe because it's only accessed from the MainActor

let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signal(SIGINT, SIG_IGN)

signalSource.setEventHandler {
    print("\n[Wrapper] Caught SIGINT. Terminating child processes...")

    #if os(macOS) || os(Linux)
        fileMonitorTask?.cancel()  // Stop the polling task
    #elseif os(Windows)
        if dirHandle != INVALID_HANDLE_VALUE {
            CloseHandle(dirHandle)  // This will stop the ReadDirectoryChangesW loop
        }
    #endif

    if serverProcess.isRunning {
        print("[Wrapper] Stopping server (PID: \(serverProcess.processIdentifier))...")
        serverProcess.terminate()
    }

    // --- Send shutdown flag to client ---
    if clientProcess.isRunning {
        print("[Wrapper] Sending shutdown signal (flag file) to client...")

        let flagURL =
            appDirectoryURL
            .appendingPathComponent("shutdown.flag")

        try? Data().write(to: flagURL)  // "touch" the file

        // Give it 800ms to shut down gracefully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if clientProcess.isRunning {
                print("[Wrapper] Client did not exit. Forcing termination.")
                clientProcess.terminate()  // Force kill
            }
            exit(0)  // Exit the wrapper
        }
    } else {
        exit(0)  // Client wasn't running, just exit
    }
}
signalSource.resume()

// --- Define Termination Handlers (Lifecycle Management) ---
serverProcess.terminationHandler = { process in
    // We are on a background thread. Dispatch to main to safely access clientProcess.
    DispatchQueue.main.async {
        print("---")
        print("[Wrapper] SERVER process terminated.")
        print("[Wrapper] Exit code: \(process.terminationStatus)")
        print("[Wrapper] Reason: \(process.terminationReason.rawValue)")
        print("---")

        if clientProcess.isRunning {
            print("[Wrapper] Server died. Terminating client...")
            clientProcess.terminate()
        }

        print("[Wrapper] Server process exited. Shutting down wrapper.")
        exit(0)
    }
}

let clientTerminationHandler: @Sendable (Process) -> Void = { process in
    // We are on a background thread. Dispatch to main to safely access serverProcess.
    DispatchQueue.main.async {
        print("---")
        print("[Wrapper] CLIENT process terminated.")
        print("[Wrapper] Exit code: \(process.terminationStatus)")
        print("[Wrapper] Reason: \(process.terminationReason.rawValue)")
        print("---")

        // A hot-reload is in progress. We *must* relaunch.
        if isRelaunching {
            print("[Wrapper] Client exited for hot-reload. Relaunching...")
            launchNewClient()  // This function will reset the isRelaunching flag

        }
        // No hot-reload, but client exited cleanly (Code 0).
        // This handles in-game resets (Ctrl+R) or graceful exits (like 'Q').
        else if process.terminationStatus == 0 {
            print("[Wrapper] Client exited gracefully (Code 0). Relaunching...")
            launchNewClient()

        }
        // No hot-reload, but client exited with code 10.
        // Exits the engine gracefully.
        else if process.terminationStatus == 10 {
            print("[Wrapper] Client exited with code 10. Shutting down server...")
            if serverProcess.isRunning {
                serverProcess.terminate()
            }
        }
        // No hot-reload, and client crashed (non-zero code).
        else {
            print(
                "❌ [Wrapper] Client process crashed or exited unexpectedly (Code: \(process.terminationStatus)). Server remains running."
            )
        }
    }
}
clientProcess.terminationHandler = clientTerminationHandler

// Make a reusable, thread-safe function to relaunch the client
@Sendable
func relaunchClient() {
    // This print will now happen *after* the OS event is confirmed
    print("\n🔥 [Watcher] Relaunching client...")

    // Dispatch to main queue to safely modify clientProcess
    DispatchQueue.main.async {
        guard !isRelaunching else {
            print("ℹ️ [Watcher] Relaunch already in progress. Ignoring.")
            return
        }
        isRelaunching = true  // Set the flag

        // Just write the flag. The termination handler will do the rest.
        if clientProcess.isRunning {
            print("[Watcher] Sending shutdown signal (flag file) to client...")
            let flagURL =
                appDirectoryURL
                .appendingPathComponent("shutdown.flag")
            try? Data().write(to: flagURL)
            // We just wait.
            // The client will get a server update, see the flag,
            // call die(), and its terminationHandler will fire.
        } else {
            // Client wasn't running, so just launch it.
            // The termination handler won't fire, so we must call this here.
            print("[Watcher] Client was not running. Launching...")
            launchNewClient()
        }
    }
}

// Helper function to just launch the new client
// This ensures it only runs *after* the old one is confirmed dead
@Sendable
func launchNewClient() {
    // Dispatch all work to the MainActor,
    // making this function safe to call from any thread.
    DispatchQueue.main.async {
        print("[Watcher] Relaunching client...")
        let newClientProcess = Process()
        newClientProcess.executableURL = clientExecutableURL
        newClientProcess.terminationHandler = clientTerminationHandler  // Reuse handler

        // UPDATED: Build the arguments array dynamically
        var newClientArgs = [String]()
        if let params = settings.clientInterpreterParams {
            newClientArgs.append(contentsOf: params)
        }
        newClientArgs.append(clientScriptURL.path)

        // NEW: Pass IPC settings for Hot-Reloaded Client
        newClientArgs.append(globalIpcMode)
        newClientArgs.append(String(globalIpcPort))

        newClientProcess.arguments = newClientArgs
        print("[Watcher] Relaunching client with args: \(newClientArgs.joined(separator: " "))")

        if settings.clientLogging ?? true {
            setupClientLogging(for: newClientProcess, logger: logger)
        }

        do {
            try newClientProcess.run()
            clientProcess = newClientProcess  // Modifies @MainActor global
            print(
                "[Watcher] New client is running with PID: \(clientProcess.processIdentifier)")
        } catch {
            print(
                "❌ [Watcher] Failed to restart client: \(error.localizedDescription)")
            if serverProcess.isRunning {
                serverProcess.terminate()
            }
        }

        isRelaunching = false  // Modifies @MainActor global
    }
}

#if os(Windows)
    struct SendableHandle: @unchecked Sendable {
        let handle: HANDLE
    }
#endif

@MainActor
// This function will set up a monitor on the configured asset directory
func setupAssetWatcher() {
    let assetsURL = appDirectoryURL.appendingPathComponent(settings.watchDirectoryName)

    // First, check if the directory exists
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: assetsURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
    else {
        print(
            "⚠️ [Watcher] '\(settings.watchDirectoryName)' directory not found at \(assetsURL.path). Hot-reload disabled."
        )
        return
    }

    // Resolve the symlink to get the REAL path
    let realAssetsURL = assetsURL.resolvingSymlinksInPath()
    print("👀 [Watcher] Link path is: \(assetsURL.path)")
    print("👀 [Watcher] Real path is: \(realAssetsURL.path)")
    // ---------------------------------

    // --- Parse exclusion rules ---
    let exclusions = settings.watchExclusions ?? []
    var dirsToSkip = [String]()
    var suffixesToSkip = [String]()

    for pattern in exclusions {
        if pattern.starts(with: "*.") {
            suffixesToSkip.append(String(pattern.dropFirst(1)))  // e.g., ".data"
        } else if pattern.starts(with: "/**/") {
            // This is a simple implementation for the requested patterns
            dirsToSkip.append(String(pattern.dropFirst(4)))  // e.g., "vendor"
        }
    }

    // --- Platform-Specific Watcher Implementation ---

    #if os(macOS) || os(Linux)
        // --- macOS / Linux Implementation (High-Level Polling) ---
        print(
            "👀 [Watcher] Starting high-level polling watcher for '\(settings.watchDirectoryName)'..."
        )

        if !dirsToSkip.isEmpty {
            print("👀 [Watcher] Excluding directories: \(dirsToSkip)")
        }
        if !suffixesToSkip.isEmpty {
            print("👀 [Watcher] Excluding file suffixes: \(suffixesToSkip)")
        }

        // We run this on a background thread (Task)
        fileMonitorTask = Task(priority: .background) {
            var isFirstRun = true

            while !Task.isCancelled {
                // 1. Get a new snapshot of the directory
                var newStates = [String: Date]()
                var hasChanges = false

                let enumerator = FileManager.default.enumerator(
                    at: realAssetsURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                )

                while let fileURL = enumerator?.nextObject() as? URL {
                    let name = fileURL.lastPathComponent

                    // --- Exclusion Logic ---
                    // Check if it's a directory we should skip
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                        isDir.boolValue
                    {
                        if dirsToSkip.contains(name) {
                            // print("ℹ️ [Watcher] Skipping directory: \(name)")
                            enumerator?.skipDescendants()
                            continue  // Don't add this directory to the state
                        }
                    }

                    // Check if it's a file with a suffix we should skip
                    if !suffixesToSkip.isEmpty {
                        if suffixesToSkip.contains(where: { name.hasSuffix($0) }) {
                            // print("ℹ️ [Watcher] Skipping file: \(name)")
                            continue  // Don't add this file to the state
                        }
                    }
                    // --- End Exclusion ---

                    do {
                        let attributes = try fileURL.resourceValues(forKeys: [
                            .contentModificationDateKey
                        ])
                        if let modDate = attributes.contentModificationDate {
                            newStates[fileURL.path] = modDate
                        }
                    } catch {
                        // Handle error, e.g., file was deleted mid-scan
                        print(
                            "⚠️ [Watcher] Error reading attributes for \(fileURL.path): \(error.localizedDescription)"
                        )
                    }
                }

                // 2. Compare snapshots
                if isFirstRun {
                    isFirstRun = false
                } else {
                    // Check for changes
                    if newStates.count != fileStates.count {
                        hasChanges = true  // File added or deleted
                    } else {
                        // Check for modified files
                        for (path, newDate) in newStates {
                            if let oldDate = fileStates[path] {
                                if newDate > oldDate {
                                    hasChanges = true  // File was modified
                                    break
                                }
                            } else {
                                hasChanges = true  // New file (should be caught by count check, but good to have)
                                break
                            }
                        }
                    }
                }

                // Update old snapshot
                fileStates = newStates

                // Trigger relaunch if needed
                if hasChanges {
                    print("🔥 [Watcher] Polling detected file changes!")
                    relaunchClient()
                }

                // Wait before polling again
                do {
                    // Poll every 1 second
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    // Task was cancelled
                    print("ℹ️ [Watcher] Polling task cancelled.")
                    return
                }
            }
        }

    #elseif os(Windows)
        // --- Windows Implementation (ReadDirectoryChangesW) ---
        print("👀 [Watcher] Starting Windows file watcher for '\(settings.watchDirectoryName)'...")

        if !dirsToSkip.isEmpty {
            print("👀 [Watcher] Excluding directories: \(dirsToSkip)")
        }
        if !suffixesToSkip.isEmpty {
            print("👀 [Watcher] Excluding file suffixes: \(suffixesToSkip)")
        }

        let assetsPath = realAssetsURL.path

        // Use withCString(encodedAs:) for correct LPCWSTR pointer
        // We must get the handle *inside* this closure, because the pointer
        // is only valid within this scope.
        assetsPath.withCString(encodedAs: UTF16.self) { assetsPathWide in
            dirHandle = CreateFileW(
                assetsPathWide,  // <-- This is now a valid LPCWSTR
                GENERIC_READ,
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_BACKUP_SEMANTICS),  // Required to get a handle to a directory
                nil
            )
        }

        if dirHandle == INVALID_HANDLE_VALUE {
            print(
                "❌ [Watcher] Failed to get directory handle. Error: \(GetLastError()). Hot-reload disabled."
            )
            return
        }

        // This avoids the @MainActor isolation error and Sendable error.
        let handleForThread = SendableHandle(handle: dirHandle)

        // Start a new background thread to block and wait for changes
        // --- MODIFIED: Capture exclusion rules for the new thread ---
        Thread.detachNewThread { [handleForThread, dirsToSkip, suffixesToSkip] in
            var buffer: [UInt8] = .init(repeating: 0, count: 4096)
            var bytesReturned: DWORD = 0

            while true {
                let success = ReadDirectoryChangesW(
                    handleForThread.handle,
                    &buffer,
                    DWORD(buffer.count),
                    true,  // Watch subtrees
                    DWORD(
                        FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_FILE_NAME
                            | FILE_NOTIFY_CHANGE_DIR_NAME),
                    &bytesReturned,
                    nil,
                    nil
                )

                if success && bytesReturned > 0 {
                    // --- Parse the buffer ---
                    var shouldRelaunch = false
                    var currentOffset: Int = 0

                    // Use withUnsafeBytes to get a raw pointer to the buffer
                    buffer.withUnsafeBytes { bufferPtr in
                        let baseAddress = bufferPtr.baseAddress!
                        guard baseAddress != nil else { return }

                        // Loop while our offset is inside the returned data
                        while currentOffset < bytesReturned {
                            // Bind the current position to the notification struct
                            let notifyInfoPtr = (baseAddress + currentOffset).bindMemory(
                                to: FILE_NOTIFY_INFORMATION.self, capacity: 1)
                            let notifyInfo = notifyInfoPtr.pointee
                            let fileNameLengthInBytes = Int(notifyInfo.FileNameLength)

                            // --- FIXED ---
                            // Get a pointer to the start of the file name.
                            // The FileName field is at a fixed offset from the start of the struct,
                            // immediately after the 3 DWORD fields.
                            let fileNameOffset = MemoryLayout<DWORD>.size * 3
                            let fileNamePtr = UnsafeRawPointer(notifyInfoPtr) + fileNameOffset
                            // --- END FIX ---

                            // Create a Data object from the raw UTF-16 bytes
                            let fileNameData = Data(
                                bytes: fileNamePtr, count: fileNameLengthInBytes)

                            // Convert the UTF-16 data to a Swift String
                            if let fileName = String(
                                data: fileNameData, encoding: .utf16LittleEndian)
                            {

                                // --- Apply Exclusion Logic ---
                                // Windows paths use '\'
                                let components = fileName.split(separator: "\\")
                                let nameOnly = String(components.last ?? "")
                                var isExcluded = false

                                // 1. Check file suffix
                                if !suffixesToSkip.isEmpty
                                    && suffixesToSkip.contains(where: { nameOnly.hasSuffix($0) })
                                {
                                    isExcluded = true
                                }

                                // 2. Check if any part of the path is an excluded directory
                                if !isExcluded && !dirsToSkip.isEmpty {
                                    for part in components {
                                        if dirsToSkip.contains(String(part)) {
                                            isExcluded = true
                                            break
                                        }
                                    }
                                }
                                // --- End Exclusion Logic ---

                                // 3. If *not* excluded, flag for relaunch and stop parsing this buffer
                                if !isExcluded {
                                    print("🔥 [Watcher] Windows event for: \(fileName)")
                                    shouldRelaunch = true
                                    break  // Exit the inner 'while currentOffset' loop
                                }

                            }  // end if let fileName

                            // If NextEntryOffset is 0, this is the last entry
                            if notifyInfo.NextEntryOffset == 0 {
                                break
                            }
                            // Move to the next entry in the buffer
                            currentOffset += Int(notifyInfo.NextEntryOffset)
                        }  // end while currentOffset
                    }  // end withUnsafeBytes

                    // --- Trigger relaunch if needed ---
                    if shouldRelaunch {
                        relaunchClient()
                    } else {
                        // All events in this buffer were excluded
                        print("ℹ️ [Watcher] Windows event(s) fired, but all files were excluded.")
                    }
                    // --- End ---

                } else {
                    // This will also fail if CloseHandle() is called from another thread
                    print(
                        "❌ [Watcher] Windows watch loop exiting. Error: \(GetLastError())."
                    )
                    break
                }
            }
            // Clean up the handle *just in case* it wasn't closed by Ctrl+C
            CloseHandle(handleForThread.handle)
        }

    #else
        // --- Unsupported OS ---
        print(
            "⚠️ [Watcher] Hot-reloading is not supported on this platform. File watcher disabled."
        )
    #endif
}

// --- Launch Processes ---

setupAssetWatcher()  // <-- This now calls our new cross-platform function

do {
    print("🚀 [Wrapper] Starting Game Engine (Server: \(settings.serverExecutableName))...")

    try serverProcess.run()
    print("[Wrapper] Server running with PID: \(serverProcess.processIdentifier)")

    // WARNING: This sleep is fragile.
    print("[Wrapper] ...Waiting 2 seconds for server to initialize IPC...")
    Thread.sleep(forTimeInterval: 2.0)

    print("🚀 [Wrapper] Starting Client (\(settings.clientInterpreterName))...")
    try clientProcess.run()
    print("[Wrapper] Client running with PID: \(clientProcess.processIdentifier)")

    print(
        "\n✅ [Wrapper] Both processes are running. Monitoring... (Press Ctrl+C to stop)"
    )

} catch {
    print("❌ [Wrapper] Error launching a process: \(error.localizedDescription)")
    if serverProcess.isRunning { serverProcess.terminate() }
    if clientProcess.isRunning { clientProcess.terminate() }
    exit(1)
}

// --- Keep Wrapper Alive ---
RunLoop.current.run()
