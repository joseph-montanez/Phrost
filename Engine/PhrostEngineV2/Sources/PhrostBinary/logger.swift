import Foundation

// --- ADD THIS ACTOR ---
actor Logger {
    private let fileHandle: FileHandle
    private let logFileURL: URL

    init(logFileURL: URL) {
        self.logFileURL = logFileURL

        // Clear/create the log file on launch
        try? Data().write(to: logFileURL)

        do {
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
            self.fileHandle = try FileHandle(forWritingTo: logFileURL)
        } catch {
            // This is the one print we can't avoid.
            // In a GUI app, this error would be silent.
            print("--- FATAL: Failed to open log file at \(logFileURL.path) ---")
            fatalError("Failed to open log file: \(error.localizedDescription)")
        }
    }

    /// Logs a message to the file.
    func log(_ message: String) {
        // Ensure we're not logging empty strings or just newlines
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty,
            let data = trimmedMessage.data(using: .utf8),
            let newline = "\n".data(using: .utf8)
        else { return }

        do {
            // Append the message, then a newline
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
            try fileHandle.write(contentsOf: newline)
        } catch {
            // Can't do much here, as we can't print
        }
    }

    deinit {
        // Clean up the file handle when the logger is destroyed
        try? fileHandle.close()
    }
}

@Sendable
func setupClientLogging(for process: Process, logger: Logger) {
    let stdOutPipe = Pipe()
    let stdErrPipe = Pipe()
    process.standardOutput = stdOutPipe
    process.standardError = stdErrPipe

    // Handle STDOUT
    stdOutPipe.fileHandleForReading.readabilityHandler = { fileHandle in
        let data = fileHandle.availableData
        if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
            Task {
                // We add a [Client] prefix to distinguish it
                await logger.log("[Client] \(output)")
            }
        }
    }

    // Handle STDERR
    stdErrPipe.fileHandleForReading.readabilityHandler = { fileHandle in
        let data = fileHandle.availableData
        if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
            Task {
                // We add a [Client-ERR] prefix
                await logger.log("[Client-ERR] \(output)")
            }
        }
    }
}
