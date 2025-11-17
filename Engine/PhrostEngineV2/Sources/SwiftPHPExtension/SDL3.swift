// import SwiftSDL_image
// import SwiftSDL_ttf
// import Chipmunk2D
import Foundation
import PHPCore
import PhrostEngineCore
import SwiftSDL
import SwiftSDL_image

// --- Helper Extensions & Functions (PHP-Specific) ---
extension StaticString {
    func asZendTuple() -> (str: UnsafePointer<CChar>, len: Int) {
        let rawPtr = UnsafeRawPointer(self.utf8Start)
        let cString = rawPtr.assumingMemoryBound(to: CChar.self)
        return (cString, self.utf8CodeUnitCount)
    }
}

func phpValue(from z: UnsafeMutablePointer<zval>!) -> Any? {
    let t = Z_TYPE_P(z)
    switch t {
    case IS_LONG: return Int(Z_LVAL_P(z))
    case IS_DOUBLE: return Double(Z_DVAL_P(z))
    case IS_TRUE: return true
    case IS_FALSE: return false
    case IS_STRING:
        let s = Z_STRVAL_P(z)
        return String(cString: s)
    case IS_NULL, IS_UNDEF: return nil
    case IS_ARRAY: return phpArrayToSwift(Z_ARRVAL_P(z))
    default: return nil
    }
}

func phpArrayToSwift(_ ht: UnsafeMutablePointer<HashTable>!) -> [Any] {
    var result = [Any]()
    ht.forEach { _, valuePtr in
        if let v = phpValue(from: valuePtr) {
            result.append(v)
        } else {
            result.append(NSNull())
        }
    }
    return result
}

@inline(__always)
func call_php_function(
    _ name: String, _ args: inout [zval], _ retvalOut: UnsafeMutablePointer<zval>?
) -> Bool {
    var zfname = zval()
    name.withCString { c in ZVAL_STRING(&zfname, c) }
    defer { zval_ptr_dtor(&zfname) }
    var fci = zend_fcall_info()
    var fcc = zend_fcall_info_cache()
    guard zend_fcall_info_init(&zfname, 0, &fci, &fcc, nil, nil) == SUCCESS else { return false }
    return args.withUnsafeMutableBufferPointer { buf -> Bool in
        var localRet = zval()
        ZVAL_UNDEF(&localRet)
        defer { zval_ptr_dtor(&localRet) }
        fci.params = buf.baseAddress
        fci.param_count = UInt32(buf.count)
        fci.retval = withUnsafeMutablePointer(to: &localRet) { $0 }
        let ok = zend_call_function(&fci, &fcc) == SUCCESS
        if ok, let out = retvalOut { ZVAL_COPY(out, &localRet) }
        return ok
    }
}
// --- End PHP Helper Functions ---

// --- PHP Function Definition ---
@MainActor
public let arginfo_phrost_run: [zend_internal_arg_info] = [
    ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(
        name: "Phrost_Run", return_reference: false, required_num_args: 0, type: UInt32(IS_STRING),
        allow_null: false),
    ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(
        pass_by_ref: false, name: "initial_commands", type_hint: UInt32(IS_STRING),
        allow_null: true, default_value: "nil"),
]

@_cdecl("zif_phrost_run")
public func zif_phrost_run(
    _ execute_data: UnsafeMutablePointer<zend_execute_data>?,
    _ return_value: UnsafeMutablePointer<zval>?
) {
    guard let return_value else { return }
    var commands_ptr: UnsafeMutablePointer<CChar>? = nil
    var commands_len: Int = 0
    do {  // Parse PHP arguments
        guard
            var state: ParseState = ZEND_PARSE_PARAMETERS_START(
                min: 0, max: 1, execute_data: execute_data)
        else { return }
        Z_PARAM_OPTIONAL(state: &state)
        try Z_PARAM_STRING_OR_NULL(state: &state, dest: &commands_ptr, destLen: &commands_len)
        try ZEND_PARSE_PARAMETERS_END(state: state)
    } catch {
        print("Parameter parsing failed for Phrost_Run")
        return
    }

    // Default window settings
    var windowTitle = "Phrost Engine"
    var windowWidth: Int32 = 640
    var windowHeight: Int32 = 480
    var windowFlags: UInt64 = 0

    // --- Initial Command Processing ---
    // This logic stays here, as it's part of the PHP function's setup
    if let commands_ptr = commands_ptr, commands_len > 0 {
        let initialCommandData = Data(bytes: commands_ptr, count: commands_len)
        var initialOffset = 0

        func initialUnpack<T>(as type: T.Type) -> T? {
            let size = MemoryLayout<T>.size
            guard initialOffset + size <= initialCommandData.count else {
                print("Initial Unpack Error: Not enough data for \(T.self).")
                return nil
            }
            let value = initialCommandData.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: initialOffset, as: T.self)
            }
            initialOffset += size
            return value
        }

        guard let initialCommandCount = initialUnpack(as: UInt32.self) else {
            print("Initial Setup Error: Failed to read command count.")
            RETURN_STR(ZSTR_EMPTY_ALLOC(), return_value)
            return
        }

        // Define known fixed sizes for skipping during initial setup
        let initialSkipSizes: [UInt32: Int] = [
            Events.spriteAdd.rawValue: MemoryLayout<PackedSpriteAddEvent>.size,
            Events.spriteRemove.rawValue: MemoryLayout<PackedSpriteRemoveEvent>.size,
            Events.spriteMove.rawValue: MemoryLayout<PackedSpriteMoveEvent>.size,
            Events.spriteScale.rawValue: MemoryLayout<PackedSpriteScaleEvent>.size,
            Events.spriteResize.rawValue: MemoryLayout<PackedSpriteResizeEvent>.size,
            Events.spriteRotate.rawValue: MemoryLayout<PackedSpriteRotateEvent>.size,
            Events.spriteColor.rawValue: MemoryLayout<PackedSpriteColorEvent>.size,
            Events.spriteSpeed.rawValue: MemoryLayout<PackedSpriteSpeedEvent>.size,
            Events.spriteTextureSet.rawValue: MemoryLayout<PackedSpriteTextureSetEvent>.size,
            Events.windowTitle.rawValue: MemoryLayout<PackedWindowTitleEvent>.size,
            Events.windowResize.rawValue: MemoryLayout<PackedWindowResizeEvent>.size,
            Events.windowFlags.rawValue: MemoryLayout<PackedWindowFlagsEvent>.size,
            Events.plugin.rawValue: MemoryLayout<PackedPluginOnEvent>.size,
            // DO NOT include spriteTextureLoad here as its total size is variable
        ]

        for i in 0..<initialCommandCount {
            guard let typeRaw = initialUnpack(as: UInt32.self),
                initialUnpack(as: UInt64.self) != nil
            else {  // Read type & discard TS
                print(
                    "Initial Setup Loop \(i)/\(initialCommandCount): Failed to read header. Offset=\(initialOffset). Breaking."
                )
                break
            }
            guard let type = Events(rawValue: typeRaw) else {
                print(
                    "Initial Setup Loop \(i)/\(initialCommandCount): Unknown Type \(typeRaw). Offset=\(initialOffset). Breaking."
                )
                break  // Unknown type - abort initial setup
            }

            switch type {
            case .windowTitle:
                guard let event = initialUnpack(as: PackedWindowTitleEvent.self) else {
                    print(
                        "Initial Setup Loop \(i)/\(initialCommandCount): Failed to unpack WindowTitle payload. Offset=\(initialOffset). Breaking."
                    )
                    break
                }
                windowTitle = withUnsafePointer(to: event.title) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                }
            case .windowResize:
                guard let event = initialUnpack(as: PackedWindowResizeEvent.self) else {
                    print(
                        "Initial Setup Loop \(i)/\(initialCommandCount): Failed to unpack WindowResize payload. Offset=\(initialOffset). Breaking."
                    )
                    break
                }
                windowWidth = event.w
                windowHeight = event.h
            case .windowFlags:
                guard let event = initialUnpack(as: PackedWindowFlagsEvent.self) else {
                    print(
                        "Initial Setup Loop \(i)/\(initialCommandCount): Failed to unpack WindowFlags payload. Offset=\(initialOffset). Breaking."
                    )
                    break
                }
                windowFlags = event.flags
            default:  // Skip other known fixed-size types, error on variable or unknown
                if let sizeToSkip = initialSkipSizes[type.rawValue] {  // Check if it's a known fixed size we can skip
                    guard initialOffset + sizeToSkip <= initialCommandData.count else {
                        print(
                            "Initial Setup Loop \(i)/\(initialCommandCount): Cannot skip \(sizeToSkip) bytes for \(type), not enough data. Offset=\(initialOffset). Breaking."
                        )
                        break
                    }
                    initialOffset += sizeToSkip
                } else {
                    print(
                        "Initial Setup Loop \(i)/\(initialCommandCount): ERROR - Cannot skip event \(type) during initial setup (size unknown or variable)! Offset=\(initialOffset). Breaking."
                    )
                    break  // Cannot safely continue
                }
            }
            if initialOffset > initialCommandData.count {  // Sanity check
                print(
                    "Initial Setup Loop \(i)/\(initialCommandCount): CRITICAL ERROR - Offset exceeded data length after processing \(type). Offset=\(initialOffset). Breaking."
                )
                break
            }
        }  // End initial command loop
    }
    // --- End Initial Command Processing ---

    // --- Engine Initialization ---
    // Initialize the decoupled engine
    guard
        let engine = PhrostEngine(
            title: windowTitle, width: windowWidth, height: windowHeight, flags: windowFlags
        )
    else {
        // Engine init failed (SDL error)
        let err = String(cString: SDL_GetError())
        print("PhrostEngine init Error: \(err)")
        RETURN_STR(
            err.withCString { zend_string_init_fast($0, err.utf8.count) } ?? ZSTR_EMPTY_ALLOC(),
            return_value)
        return
    }

    // --- Define the PHP Update Callback ---
    // This closure is the "glue" that connects the engine back to PHP
    let phpUpdateCallback = { (frameCount: Int, deltaSec: Double, eventData: Data) -> Data in
        var zTick = zval()
        ZVAL_LONG(&zTick, zend_long(frameCount))
        var zDelta = zval()
        ZVAL_DOUBLE(&zDelta, deltaSec)
        var zEventsString = zval()

        if eventData.isEmpty {
            ZVAL_EMPTY_STRING(&zEventsString)
        } else {
            eventData.withUnsafeBytes { rawPointer in
                if let baseAddress = rawPointer.baseAddress {
                    if let zstr = zend_string_init_fast(
                        baseAddress.assumingMemoryBound(to: CChar.self), eventData.count)
                    {
                        ZVAL_STR(&zEventsString, zstr)
                    } else {
                        ZVAL_EMPTY_STRING(&zEventsString)
                    }
                } else {
                    ZVAL_EMPTY_STRING(&zEventsString)
                }
            }
        }

        var params: [zval] = [zTick, zDelta, zEventsString]
        var phpRet = zval()
        ZVAL_UNDEF(&phpRet)

        let called = call_php_function("Phrost_Update", &params, &phpRet)

        // Dtor params
        zval_ptr_dtor(&zTick)
        zval_ptr_dtor(&zDelta)
        zval_ptr_dtor(&zEventsString)

        var commandData = Data()
        if called && Z_TYPE_P(&phpRet) == IS_STRING {
            let len = Z_STRLEN_P(&phpRet)
            if len > 0 {
                let str = Z_STRVAL_P(&phpRet)
                commandData = Data(bytes: str, count: len)
            }
        } else if called {
            print(
                "PHP Update call succeeded but did not return a string (returned type \(Z_TYPE_P(&phpRet))). No commands processed."
            )
        } else {
            print("PHP Update call failed. No commands processed.")
        }

        zval_ptr_dtor(&phpRet)  // Dtor return value
        return commandData
    }

    // --- Run the Engine ---
    // This blocks until the engine.running is false (e.g., window closed)
    engine.run(updateCallback: phpUpdateCallback)

    // --- Cleanup & Return ---
    // Engine.deinit will be called automatically, cleaning up SDL.
    let msg = "SDL3 window shown successfully"
    guard let z = msg.withCString({ zend_string_init($0, msg.utf8.count, false) }) else {
        RETURN_STR(ZSTR_EMPTY_ALLOC(), return_value)
        return
    }
    RETURN_STR(z, return_value)
}  // --- End zif_phrost_run ---

// --- PHP Module Registration ---
@MainActor
public func sdl3_add_entries(builder: inout FunctionListBuilder) {
    builder.add(name: "Phrost_Run", handler: zif_phrost_run, arg_info: arginfo_phrost_run)
}

// --- Other PHP Helpers (unused in this file but part of original) ---
func getId(_ value: UnsafeMutablePointer<zval>, _ id: inout (Int64, Int64)) {
    if Z_TYPE_P(value) == IS_ARRAY {
        let value1 = zend_hash_index_find(Z_ARRVAL_P(value), 0)
        let value2 = zend_hash_index_find(Z_ARRVAL_P(value), 1)
        if let value1 = value1, Z_TYPE_P(value1) == IS_LONG { id.0 = Int64(Z_LVAL_P(value1)) }
        if let value2 = value2, Z_TYPE_P(value2) == IS_LONG { id.1 = Int64(Z_LVAL_P(value2)) }
    }
}
func getLong4(_ value: UnsafeMutablePointer<zval>, _ tuple: inout (Int64, Int64, Int64, Int64)) {
    if Z_TYPE_P(value) == IS_ARRAY {
        let valueR = zend_hash_str_find(Z_ARRVAL_P(value), "r", strlen("r"))
        let valueG = zend_hash_str_find(Z_ARRVAL_P(value), "g", strlen("g"))
        let valueB = zend_hash_str_find(Z_ARRVAL_P(value), "b", strlen("b"))
        let valueA = zend_hash_str_find(Z_ARRVAL_P(value), "a", strlen("a"))
        if let valueR = valueR, Z_TYPE_P(valueR) == IS_LONG { tuple.0 = Int64(Z_LVAL_P(valueR)) }
        if let valueG = valueG, Z_TYPE_P(valueG) == IS_LONG { tuple.1 = Int64(Z_LVAL_P(valueG)) }
        if let valueB = valueB, Z_TYPE_P(valueB) == IS_LONG { tuple.2 = Int64(Z_LVAL_P(valueB)) }
        if let valueA = valueA, Z_TYPE_P(valueA) == IS_LONG { tuple.3 = Int64(Z_LVAL_P(valueA)) }
    }
}
func getShort4(_ value: UnsafeMutablePointer<zval>, _ tuple: inout (UInt8, UInt8, UInt8, UInt8)) {
    if Z_TYPE_P(value) == IS_ARRAY {
        let valueR = zend_hash_str_find(Z_ARRVAL_P(value), "r", strlen("r"))
        let valueG = zend_hash_str_find(Z_ARRVAL_P(value), "g", strlen("g"))
        let valueB = zend_hash_str_find(Z_ARRVAL_P(value), "b", strlen("b"))
        let valueA = zend_hash_str_find(Z_ARRVAL_P(value), "a", strlen("a"))
        if let valueR = valueR, Z_TYPE_P(valueR) == IS_LONG { tuple.0 = UInt8(Z_LVAL_P(valueR)) }
        if let valueG = valueG, Z_TYPE_P(valueG) == IS_LONG { tuple.1 = UInt8(Z_LVAL_P(valueG)) }
        if let valueB = valueB, Z_TYPE_P(valueB) == IS_LONG { tuple.2 = UInt8(Z_LVAL_P(valueB)) }
        if let valueA = valueA, Z_TYPE_P(valueA) == IS_LONG { tuple.3 = UInt8(Z_LVAL_P(valueA)) }
    }
}
func getDouble3(_ value: UnsafeMutablePointer<zval>, _ tuple: inout (Double, Double, Double)) {
    if Z_TYPE_P(value) == IS_ARRAY {
        let valueX = zend_hash_str_find(Z_ARRVAL_P(value), "x", strlen("x"))
        let valueY = zend_hash_str_find(Z_ARRVAL_P(value), "y", strlen("y"))
        let valueZ = zend_hash_str_find(Z_ARRVAL_P(value), "z", strlen("z"))
        if let valueX = valueX, Z_TYPE_P(valueX) == IS_DOUBLE { tuple.0 = Z_DVAL_P(valueX) }
        if let valueY = valueY, Z_TYPE_P(valueY) == IS_DOUBLE { tuple.1 = Z_DVAL_P(valueY) }
        if let valueZ = valueZ, Z_TYPE_P(valueZ) == IS_DOUBLE { tuple.2 = Z_DVAL_P(valueZ) }
    }
}
func getDouble2(_ value: UnsafeMutablePointer<zval>, _ tuple: inout (Double, Double)) {
    if Z_TYPE_P(value) == IS_ARRAY {
        let valueX = zend_hash_str_find(Z_ARRVAL_P(value), "width", strlen("width"))
        let valueY = zend_hash_str_find(Z_ARRVAL_P(value), "height", strlen("height"))
        if let valueX = valueX, Z_TYPE_P(valueX) == IS_DOUBLE { tuple.0 = Z_DVAL_P(valueX) }
        if let valueY = valueY, Z_TYPE_P(valueY) == IS_DOUBLE { tuple.1 = Z_DVAL_P(valueY) }
    }
}
final class ConcurrentQueue<T>: @unchecked Sendable {
    private var queue = [T]()
    private let lock = NSLock()
    func enqueue(_ element: T) {
        lock.lock()
        queue.append(element)
        lock.unlock()
    }
    func dequeue() -> T? {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty ? nil : queue.removeFirst()
    }
    func isEmpty() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty
    }
}
