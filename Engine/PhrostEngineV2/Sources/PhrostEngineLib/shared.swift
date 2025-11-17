import Foundation
import PhrostEngineCore  // Assuming your core engine logic is here
import SwiftSDL

// 1. Define the C Callback signature
public typealias CUpdateCallback =
    @convention(c) (
        Int32,  // frameCount
        Double,  // deltaSec
        UnsafePointer<CChar>?,  // eventData (incoming)
        Int32,  // eventDataLen
        UnsafeMutablePointer<Int32>?  // outCommandLen (pointer to write return length)
    ) -> UnsafePointer<CChar>?  // returns commandData

// 2. The Exported Functions

@_cdecl("phrost_create_instance")
public func phrost_create_instance(title: UnsafePointer<CChar>, width: Int32, height: Int32)
    -> UnsafeMutableRawPointer?
{
    let titleStr = String(cString: title)

    // Initialize your engine
    guard
        let engine = PhrostEngine(
            title: titleStr,
            width: Int32(width),
            height: Int32(height),
            flags: 0  // Default flags
        )
    else {
        return nil
    }

    // Retain the engine instance manually and return an opaque pointer
    return Unmanaged.passRetained(engine).toOpaque()
}

@_cdecl("phrost_destroy_instance")
public func phrost_destroy_instance(_ enginePtr: UnsafeMutableRawPointer) {
    // Take ownership back to Swift so ARC can destroy it
    let _ = Unmanaged<PhrostEngine>.fromOpaque(enginePtr).takeRetainedValue()
}

@_cdecl("phrost_run_loop")
public func phrost_run_loop(_ enginePtr: UnsafeMutableRawPointer, callback: CUpdateCallback) {
    // Get a reference to the engine without consuming the retain count
    let engine = Unmanaged<PhrostEngine>.fromOpaque(enginePtr).takeUnretainedValue()

    // Create the Swift closure that wraps the C callback
    let swiftCallback: (Int, Double, Data) -> Data = { frame, delta, eventData in

        // 1. Prepare data to send to C
        var cCommandLen: Int32 = 0

        let resultPtr = eventData.withUnsafeBytes {
            (ptr: UnsafeRawBufferPointer) -> UnsafePointer<CChar>? in
            let cCharStart = ptr.baseAddress?.assumingMemoryBound(to: CChar.self)
            return callback(
                Int32(frame),
                delta,
                cCharStart,
                Int32(eventData.count),
                &cCommandLen
            )
        }

        // 2. Handle data returned from C
        if let resultPtr = resultPtr, cCommandLen > 0 {
            let data = Data(bytes: resultPtr, count: Int(cCommandLen))
            return data
        }

        return Data()
    }

    // Run the engine
    engine.run(updateCallback: swiftCallback)
}
