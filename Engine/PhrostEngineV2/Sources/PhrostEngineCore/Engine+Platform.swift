import Foundation
import SwiftSDL

#if os(Windows)
    import WinSDK
#endif

extension PhrostEngine {

    // MARK: - Windows-Specific Error Helper

    #if os(Windows)
        /// Gets the last Windows API error as a string.
        internal func getWindowsErrorString() -> String {
            // ... (Full body of getWindowsErrorString() from your original code) ...
            let errorCode = GetLastError()
            if errorCode == 0 { return "No error." }

            var lpMsgBuf: LPSTR? = nil
            let dwFlags: DWORD = DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER) | DWORD(FORMAT_MESSAGE_FROM_SYSTEM) | DWORD(FORMAT_MESSAGE_IGNORE_INSERTS)
            let dwLangID: DWORD = (DWORD(WORD(SUBLANG_DEFAULT)) << 10) | DWORD(WORD(LANG_NEUTRAL))

            let msgLen = withUnsafeMutablePointer(to: &lpMsgBuf) { ptrToLpMsgBuf in
                return ptrToLpMsgBuf.withMemoryRebound(to: CChar.self, capacity: 1) {
                    cCharPointer in
                    return FormatMessageA(
                        dwFlags, nil, errorCode, dwLangID,
                        cCharPointer, 0, nil
                    )
                }
            }

            guard msgLen > 0, let msgPtr = lpMsgBuf else {
                return "Unknown Windows Error (code \(errorCode)). FormatMessage failed."
            }

            let errorString = String(cString: msgPtr)
            LocalFree(UnsafeMutableRawPointer(msgPtr))

            return errorString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    #endif

    // MARK: - Command Handlers (Minimal window logic for simple setters)

    internal func handleWindowTitleCommand(event: PackedWindowTitleEvent) {
        let newTitle = withUnsafePointer(to: event.title) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
        SDL_SetWindowTitle(window, newTitle)
    }

    internal func handleWindowFlagsCommand(event: PackedWindowFlagsEvent) {
        let flags = event.flags
        SDL_SetWindowFullscreen(window, (flags & 0x01) != 0)
        SDL_SetWindowBordered(window, (flags & 0x10) == 0)
        SDL_SetWindowResizable(window, (flags & 0x20) != 0)
        SDL_SetWindowAlwaysOnTop(window, (flags & 0x10000) != 0)
    }
}
