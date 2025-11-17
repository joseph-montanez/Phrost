import Foundation
import SwiftSDL

// --- Platform-Specific Imports ---
// Import the correct C libraries for dynamic loading
#if os(Windows)
    import WinSDK
#elseif os(Linux)
    import Glibc
#else
    import Darwin
#endif
// --- End Platform-Specific Imports ---

// --- C-Plugin ABI Struct (Can be moved to PhrostStructs.swift) ---
@frozen public struct CPhrostCommandBlob {
    let data: UnsafeMutableRawPointer?
    let length: Int32
}

// MARK: - ABI Function Signatures
internal typealias CPluginWakeFunc =
    @convention(c) (
        UnsafeMutablePointer<Int32>
    ) -> UnsafeMutableRawPointer?

internal typealias CPluginUpdateFunc =
    @convention(c) (
        UInt64,
        Double,
        UnsafeRawPointer?,
        Int32,
        UnsafeMutablePointer<Int32>
    ) -> UnsafeMutableRawPointer?

internal typealias CPluginFreeFunc =
    @convention(c) (
        UnsafeMutableRawPointer?
    ) -> Void

internal typealias CPluginSleepFunc =
    @convention(c) () -> Void

extension PhrostEngine {

    // MARK: - Plugin Loading (Platform-Agnostic)
    internal func loadPlugin(channelNo: UInt32, path: String) -> (
        generatedEvents: Data, eventCount: UInt32
    ) {
        // --- Handle empty path failure ---
        if path.isEmpty {
            print("... FAILED to load plugin: Empty path provided.")
            return (makePluginSetEvent(pluginId: 0), 1)
        }

        // --- Find an available plugin ID ---
        guard self.loadedPlugins.count < 255 else {
            print("... FAILED to load plugin: Plugin limit (255) reached.")
            return (makePluginSetEvent(pluginId: 0), 1)
        }

        var newID = self.nextPluginID
        // Find the next available ID slot, skipping 0
        while self.loadedPlugins[newID] != nil || newID == 0 {
            newID &+= 1
        }

        // We found a free slot. Prepare 'nextPluginID' for the *next* time.
        self.nextPluginID = newID &+ 1
        if self.nextPluginID == 0 { self.nextPluginID = 1 }

        let updateSymbolName = "Phrost_Update"
        let freeSymbolName = "Phrost_Free"
        let wakeSymbolName = "Phrost_Wake"
        let sleepSymbolName = "Phrost_Sleep"

        print("Attempting to load plugin from: \(path)")

        var platformHandle: UnsafeMutableRawPointer? = nil
        var updateSymbol: UnsafeMutableRawPointer? = nil
        var freeSymbol: UnsafeMutableRawPointer? = nil
        var wakeSymbol: UnsafeMutableRawPointer? = nil
        var sleepSymbol: UnsafeMutableRawPointer? = nil

        // 2. Load the new library (Platform-Specific)
        #if os(Windows)
            var winHandle: HMODULE? = nil
            winHandle = path.withCString { LoadLibraryA($0) }

            guard winHandle != nil else {
                let err = getWindowsErrorString()
                print("... FAILED to load plugin. Error: \(err)")
                return (makePluginSetEvent(pluginId: 0), 1)
            }

            // 3. Find the 'Phrost_Update' function
            let procAddress = updateSymbolName.withCString { GetProcAddress(winHandle, $0) }
            updateSymbol = unsafeBitCast(procAddress, to: UnsafeMutableRawPointer?.self)

            guard updateSymbol != nil else {
                let err = getWindowsErrorString()
                print("... FAILED to find symbol '\(updateSymbolName)'. Error: \(err)")
                FreeLibrary(winHandle)
                return (makePluginSetEvent(pluginId: 0), 1)
            }

            // 4. Find the 'Phrost_Free' function (for memory blobs)
            let freeProcAddress = freeSymbolName.withCString { GetProcAddress(winHandle, $0) }
            freeSymbol = unsafeBitCast(freeProcAddress, to: UnsafeMutableRawPointer?.self)

            guard freeSymbol != nil else {
                let err = getWindowsErrorString()
                print("... FAILED to find symbol '\(freeSymbolName)'. Error: \(err)")
                FreeLibrary(winHandle)
                return (makePluginSetEvent(pluginId: 0), 1)
            }

            // --- NEW: Find Wake Symbol (Optional) ---
            let wakeProcAddress = wakeSymbolName.withCString { GetProcAddress(winHandle, $0) }
            wakeSymbol = unsafeBitCast(wakeProcAddress, to: UnsafeMutableRawPointer?.self)
            if wakeSymbol == nil {
                print("... Optional symbol '\(wakeSymbolName)' not found. This is OK.")
            }
            // --- END NEW ---

            // --- NEW: Find Sleep Symbol (Optional, for unload) ---
            let sleepProcAddress = sleepSymbolName.withCString { GetProcAddress(winHandle, $0) }
            sleepSymbol = unsafeBitCast(sleepProcAddress, to: UnsafeMutableRawPointer?.self)
            if sleepSymbol == nil {
                print("... Optional symbol '\(sleepSymbolName)' not found. This is OK.")
            }
            // --- END NEW ---

            // 5. Store the handle
            platformHandle = UnsafeMutableRawPointer(winHandle)

        #else  // macOS, Linux, etc.
            var handle: UnsafeMutableRawPointer? = nil
            handle = dlopen(path, RTLD_LAZY)

            guard handle != nil else {
                let err = String(cString: dlerror())
                print("... FAILED to load plugin. Error: \(err)")
                return (makePluginSetEvent(pluginId: 0), 1)
            }

            // 3. Find the 'Phrost_Update' function
            updateSymbol = dlsym(handle, updateSymbolName)

            guard updateSymbol != nil else {
                let err = String(cString: dlerror())
                print("... FAILED to find symbol '\(updateSymbolName)'. Error: \(err)")
                dlclose(handle!)
                return (makePluginSetEvent(pluginId: 0), 1)
            }

            // 4. Find the 'Phrost_Free' function (for memory blobs)
            freeSymbol = dlsym(handle, freeSymbolName)

            guard freeSymbol != nil else {
                let err = String(cString: dlerror())
                print("... FAILED to find symbol '\(freeSymbolName)'. Error: \(err)")
                dlclose(handle!)
                return (makePluginSetEvent(pluginId: 0), 1)
            }

            // --- NEW: Find Wake Symbol (Optional) ---
            wakeSymbol = dlsym(handle, wakeSymbolName)
            if wakeSymbol == nil {
                print("... Optional symbol '\(wakeSymbolName)' not found. This is OK.")
            }
            // --- END NEW ---

            // --- NEW: Find Sleep Symbol (Optional, for unload) ---
            sleepSymbol = dlsym(handle, sleepSymbolName)
            if sleepSymbol == nil {
                print("... Optional symbol '\(sleepSymbolName)' not found. This is OK.")
            }
            // --- END NEW ---

            // 5. Store the handle
            platformHandle = handle
        #endif

        // --- NEW: Cast wake function if it exists ---
        let wakeFuncPtr: CPluginWakeFunc?
        if let wakeSymbol = wakeSymbol {
            wakeFuncPtr = unsafeBitCast(wakeSymbol, to: CPluginWakeFunc.self)
        } else {
            wakeFuncPtr = nil
        }

        // --- NEW: Cast sleep function if it exists ---
        let sleepFuncPtr: CPluginSleepFunc?
        if let sleepSymbol = sleepSymbol {
            sleepFuncPtr = unsafeBitCast(sleepSymbol, to: CPluginSleepFunc.self)
        } else {
            sleepFuncPtr = nil
        }

        // 6. Store the new plugin in our dictionary
        let newPlugin = LoadedPlugin(
            id: newID,
            handle: platformHandle!,
            wakeFunc: wakeFuncPtr,
            updateFunc: unsafeBitCast(updateSymbol, to: CPluginUpdateFunc.self),
            freeFunc: unsafeBitCast(freeSymbol, to: CPluginFreeFunc.self),
            sleepFunc: sleepFuncPtr
        )

        self.loadedPlugins[newID] = newPlugin

        print(
            "... Plugin loaded successfully with ID \(newID). '\(updateSymbolName)' and '\(freeSymbolName)' functions found."
        )

        // --- NEW: Call Wake function and process its commands ---
        var eventsToReturn = makePluginSetEvent(pluginId: newID)
        var eventCount: UInt32 = 1

        if let wakeFunc = newPlugin.wakeFunc {
            print("... Calling Phrost_Wake() for plugin ID \(newID)...")
            var cResultLength: Int32 = 0
            let cResultDataPtr = wakeFunc(&cResultLength)

            var wakeCommandData = Data()
            if let dataPtr = cResultDataPtr, cResultLength > 0 {
                let boundPtr = dataPtr.assumingMemoryBound(to: UInt8.self)
                wakeCommandData = Data(bytes: boundPtr, count: Int(cResultLength))
            }
            newPlugin.freeFunc(cResultDataPtr)

            // Process commands from wake
            if !wakeCommandData.isEmpty {
                print(
                    "... Processing \(wakeCommandData.count) bytes of commands from Phrost_Wake()..."
                )

                // This calls the general processCommands (defined in PhrostEngine+Commands)
                let (wakeGeneratedEvents, wakeGeneratedEventCount) = processCommands(
                    wakeCommandData)

                if wakeGeneratedEventCount > 0 {
                    eventsToReturn.append(wakeGeneratedEvents)
                    eventCount &+= wakeGeneratedEventCount
                }
            }
        }

        self.subscribePlugin(pluginId: newID, channelId: 0)

        return (eventsToReturn, eventCount)
    }

    // MARK: - Unloading
    internal func unloadPlugin(id: UInt8) {
        self.pluginSubscriptions.removeValue(forKey: id)

        guard let plugin = self.loadedPlugins.removeValue(forKey: id) else {
            print("Attempted to unload non-existent plugin ID \(id)")
            return
        }

        print("Unloading plugin ID \(id)...")

        if let sleepFunc = plugin.sleepFunc {
            print("... Calling Phrost_Sleep() for plugin ID \(id)...")
            sleepFunc()
        }

        #if os(Windows)
            FreeLibrary(HMODULE(OpaquePointer(plugin.handle)))
        #else
            dlclose(plugin.handle)
        #endif
    }

    internal func unloadAllPlugins() {
        if self.loadedPlugins.isEmpty { return }
        print("Unloading all \(self.loadedPlugins.count) plugins...")

        // Iterate over a copy of the keys to avoid mutation issues
        for id in self.loadedPlugins.keys.sorted() {
            self.unloadPlugin(id: id)
        }
    }

    // MARK: - Channel Subscription Management

    /// Subscribes a loaded plugin to a specific event channel.
    internal func subscribePlugin(pluginId: UInt8, channelId: UInt32) {
        // Ensure the plugin is actually loaded
        guard self.loadedPlugins[pluginId] != nil else {
            print("Subscription Error: Plugin ID \(pluginId) is not loaded.")
            return
        }

        if self.pluginSubscriptions[pluginId] == nil {
            self.pluginSubscriptions[pluginId] = []
        }

        self.pluginSubscriptions[pluginId]?.insert(channelId)
        print("Plugin \(pluginId) SUBSCRIBED to channel \(channelId)")
    }

    /// Unsubscribes a loaded plugin from a specific event channel.
    internal func unsubscribePlugin(pluginId: UInt8, channelId: UInt32) {
        self.pluginSubscriptions[pluginId]?.remove(channelId)
        print("Plugin \(pluginId) UNSUBSCRIBED from channel \(channelId)")
    }

    // MARK: - Event Creation Helpers

    /// Creates a Data blob for a pluginSet event (feedback after load/unload).
    internal func makePluginSetEvent(pluginId: UInt8) -> Data {
        var eventData = Data()
        // Assuming PackedPluginSetEvent is in PhrostStructs.swift or accessible
        let setEvent = PackedPluginSetEvent(pluginId: pluginId)
        eventData.append(value: Events.pluginSet.rawValue)
        eventData.append(value: SDL_GetTicks())
        eventData.append(value: setEvent)
        return eventData
    }
}
