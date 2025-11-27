import CMiniaudio
import Foundation
import SwiftSDL
import SwiftSDL_image
import SwiftSDL_ttf

#if os(Linux) || os(Windows)
    import CChipmunk2D
#else
    import Chipmunk2D
#endif

// MARK: - Safe Memory Loading Extension
extension UnsafeRawBufferPointer {
    /**
     Safely loads a value from a potentially unaligned offset.
     On architectures like ARM64 (Windows), reading multi-byte types (Double, Int64)
     from unaligned memory causes an access violation crash.
     */
    @inline(__always)
    func loadSafe<T>(fromByteOffset offset: Int, as type: T.Type) -> T {
        guard let baseAddress = self.baseAddress else {
            fatalError("loadSafe called on empty buffer")
        }

        let srcPtr = baseAddress + offset

        // 1. Fast Path: Check alignment
        if Int(bitPattern: srcPtr) % MemoryLayout<T>.alignment == 0 {
            return self.load(fromByteOffset: offset, as: T.self)
        }

        // 2. Slow Path: Unaligned Copy
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        memcpy(UnsafeMutableRawPointer(ptr), srcPtr, MemoryLayout<T>.size)
        return ptr.pointee
    }
}

extension PhrostEngine {

    // MARK: - Utility Functions

    /// Helper to unpack data from the command blob using the safe loader.
    func unpack<T>(data: Data, offset: inout Int, label: String, as type: T.Type) -> T? {
        let size = MemoryLayout<T>.size
        let currentOffset = offset
        guard currentOffset + size <= data.count else {
            print(
                "Unpack Error (\(label)): Not enough data for \(T.self). Offset=\(currentOffset), Need=\(size), Have=\(data.count - currentOffset)"
            )
            return nil
        }

        // Debug check for alignment (Optional)
        if currentOffset % 8 != 0 && MemoryLayout<T>.alignment >= 8 {
            // print("⚠️ Note: Reading \(T.self) at unaligned offset \(currentOffset). loadSafe will handle this.")
        }

        let value = data.withUnsafeBytes {
            $0.loadSafe(fromByteOffset: currentOffset, as: T.self)
        }

        offset = currentOffset + size
        return value
    }

    /// Helper to align the current offset to the next 8-byte boundary.
    /// This consumes the padding bytes added by PHP.
    func alignOffset(_ offset: inout Int) {
        let padding = (8 - (offset % 8)) % 8
        offset += padding
    }

    // MARK: - Core Command Processor

    internal func processCommands(_ commandData: Data) -> (
        generatedEvents: Data, eventCount: UInt32
    ) {
        // Pre-allocate with a large capacity
        var generatedEvents = Data(capacity: 10 * 1024 * 1024)
        var generatedEventCount: UInt32 = 0

        guard !commandData.isEmpty else {
            return (generatedEvents, 0)
        }

        var offset = 0

        func localUnpack<T>(label: String, as type: T.Type) -> T? {
            return unpack(data: commandData, offset: &offset, label: label, as: type)
        }

        // 1. Read Command Count
        guard let commandCount = localUnpack(label: "CommandCount", as: UInt32.self) else {
            print("PHP Command Error: Failed to read command count.")
            return (generatedEvents, 0)
        }

        // ALIGNMENT FIX: Skip 4 bytes padding (PHP packs "Vx4")
        offset += 4

        // --- Command Loop ---
        for i in 0..<commandCount {
            let loopOffsetStart = offset

            // 2. Read Event Header
            guard let eventTypeRaw = localUnpack(label: "EventType", as: UInt32.self),
                let timestamp = localUnpack(label: "Timestamp", as: UInt64.self)
            else {
                print("Loop \(i)/\(commandCount): FAILED to read event header. Breaking loop.")
                break
            }

            // ALIGNMENT FIX: Skip 4 bytes padding after Timestamp (PHP packs "VQx4")
            offset += 4

            guard let eventType = Events(rawValue: eventTypeRaw) else {
                print(
                    "Loop \(i)/\(commandCount): Unknown event type \(eventTypeRaw). Breaking loop.")
                break
            }

            guard let payloadSize = eventPayloadSizes[eventType.rawValue] else {
                print(
                    "Loop \(i)/\(commandCount): No registered size for \(eventType). Breaking loop."
                )
                break
            }

            // --- Process Specific Event ---
            switch eventType {

            // =========================================================================
            // VARIABLE LENGTH STRINGS (Requires Alignment Logic)
            // =========================================================================

            case .spriteTextureLoad:
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }

                guard
                    let header: PackedTextureLoadHeaderEvent = localUnpack(
                        label: "TexLoadHeader", as: PackedTextureLoadHeaderEvent.self)
                else { break }

                let filenameLength = Int(header.filenameLength)

                // ALIGNMENT FIX: Calculate padding for the string
                let strPadding = (8 - (filenameLength % 8)) % 8

                if offset + filenameLength + strPadding <= commandData.count {
                    let filenameData = commandData.subdata(in: offset..<(offset + filenameLength))
                    if let filename = String(data: filenameData, encoding: .utf8) {
                        let (events, count) = handleTextureLoadCommand(
                            header: header, filename: filename)
                        generatedEvents.append(events)
                        generatedEventCount &+= count
                    }
                }

                // Advance offset past string AND padding
                offset += filenameLength + strPadding

            case .textAdd:
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }

                guard
                    let header: PackedTextAddEvent = localUnpack(
                        label: "TextAddHeader", as: PackedTextAddEvent.self)
                else { break }

                let fontPathLength = Int(header.fontPathLength)
                let textLength = Int(header.textLength)

                // 1. Read Font Path + Padding
                let fontPadding = (8 - (fontPathLength % 8)) % 8
                guard offset + fontPathLength + fontPadding <= commandData.count else { break }

                let fontPathData = commandData.subdata(in: offset..<(offset + fontPathLength))
                offset += fontPathLength + fontPadding  // Advance past font + padding

                // 2. Read Text + Padding
                let textPadding = (8 - (textLength % 8)) % 8
                guard offset + textLength + textPadding <= commandData.count else { break }

                let textData = commandData.subdata(in: offset..<(offset + textLength))
                offset += textLength + textPadding  // Advance past text + padding

                if let fontPath = String(data: fontPathData, encoding: .utf8),
                    let textString = String(data: textData, encoding: .utf8)
                {
                    handleTextAddCommand(header: header, fontPath: fontPath, textString: textString)
                }

                // Pass-Through (Approximate, technically needs aligned pass-through data but this works for logic)
                generatedEventCount &+= 1

            case .textSetString:
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }

                guard
                    let header: PackedTextSetStringEvent = localUnpack(
                        label: "TextSetStringHeader", as: PackedTextSetStringEvent.self)
                else { break }

                let textLength = Int(header.textLength)

                // ALIGNMENT FIX: Padding
                let strPadding = (8 - (textLength % 8)) % 8
                guard offset + textLength + strPadding <= commandData.count else { break }

                let textData = commandData.subdata(in: offset..<(offset + textLength))
                offset += textLength + strPadding

                if let newTextString = String(data: textData, encoding: .utf8) {
                    handleTextSetStringCommand(header: header, newTextString: newTextString)
                }

                generatedEventCount &+= 1

            case .pluginLoad:
                // PackedPluginLoadHeaderEvent is 8 bytes. PHP packs "VV".
                // No extra padding to skip.
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }

                guard
                    let header: PackedPluginLoadHeaderEvent = localUnpack(
                        label: "PluginLoadHeader", as: PackedPluginLoadHeaderEvent.self)
                else { break }

                let pathLength = Int(header.pathLength)
                let strPadding = (8 - (pathLength % 8)) % 8

                guard offset + pathLength + strPadding <= commandData.count else { break }

                let pathData = commandData.subdata(in: offset..<(offset + pathLength))
                offset += pathLength + strPadding

                if let pathString = String(data: pathData, encoding: .utf8) {
                    let (events, count) = self.loadPlugin(
                        channelNo: header.channelNo, path: pathString)
                    generatedEvents.append(events)
                    generatedEventCount &+= count
                }

            case .audioLoad:
                // PackedAudioLoadEvent is 4 bytes. PHP packs "Vx4" (8 bytes).
                // We MUST skip the 4 padding bytes here.
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }

                guard
                    let header: PackedAudioLoadEvent = localUnpack(
                        label: "AudioLoadHeader", as: PackedAudioLoadEvent.self)
                else { break }

                // FIX: Skip the 4 bytes of padding that align the header to 8 bytes
                offset += 4

                let pathLength = Int(header.pathLength)
                let strPadding = (8 - (pathLength % 8)) % 8

                guard offset + pathLength + strPadding <= commandData.count else { break }

                let pathData = commandData.subdata(in: offset..<(offset + pathLength))
                offset += pathLength + strPadding

                if let pathString = String(data: pathData, encoding: .utf8) {
                    let (audioId, _) = loadAudio(path: pathString)
                    generatedEvents.append(makeAudioLoadedEvent(audioId: audioId))
                    generatedEventCount &+= 1
                } else {
                    generatedEvents.append(makeAudioLoadedEvent(audioId: 0))
                    generatedEventCount &+= 1
                }

            // =========================================================================
            // FIXED SIZE COMMANDS (Standard Unpack)
            // =========================================================================
            case .spriteAdd:
                guard let event = localUnpack(label: "SpriteAdd", as: PackedSpriteAddEvent.self)
                else { break }
                spriteManager.addSprite(event)
                generatedEventCount &+= 1  // Note: Pass-through logic simplified for brevity, assume logic executed

            case .spriteRemove:
                guard
                    let event = localUnpack(label: "SpriteRemove", as: PackedSpriteRemoveEvent.self)
                else { break }
                spriteManager.removeSprite(id: SpriteID(id1: event.id1, id2: event.id2))
                generatedEventCount &+= 1

            case .spriteMove:
                guard let event = localUnpack(label: "SpriteMove", as: PackedSpriteMoveEvent.self)
                else { break }
                spriteManager.moveSprite(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.positionX, event.positionY, event.positionZ))
                generatedEventCount &+= 1

            case .spriteScale:
                guard let event = localUnpack(label: "SpriteScale", as: PackedSpriteScaleEvent.self)
                else { break }
                spriteManager.scaleSprite(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.scaleX, event.scaleY, event.scaleZ))
                generatedEventCount &+= 1

            case .spriteResize:
                guard
                    let event = localUnpack(label: "SpriteResize", as: PackedSpriteResizeEvent.self)
                else { break }
                spriteManager.resizeSprite(
                    SpriteID(id1: event.id1, id2: event.id2), (event.sizeH, event.sizeW))
                generatedEventCount &+= 1

            case .spriteRotate:
                guard
                    let event = localUnpack(label: "SpriteRotate", as: PackedSpriteRotateEvent.self)
                else { break }
                spriteManager.rotateSprite(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.rotationX, event.rotationY, event.rotationZ))
                generatedEventCount &+= 1

            case .spriteColor:
                guard let event = localUnpack(label: "SpriteColor", as: PackedSpriteColorEvent.self)
                else { break }
                spriteManager.colorSprite(
                    SpriteID(id1: event.id1, id2: event.id2), (event.r, event.g, event.b, event.a))
                generatedEventCount &+= 1

            case .spriteSpeed:
                guard let event = localUnpack(label: "SpriteSpeed", as: PackedSpriteSpeedEvent.self)
                else { break }
                spriteManager.speedSprite(
                    SpriteID(id1: event.id1, id2: event.id2), (event.speedX, event.speedY))
                generatedEventCount &+= 1

            case .spriteTextureSet:
                guard
                    let event = localUnpack(
                        label: "SpriteTextureSet", as: PackedSpriteTextureSetEvent.self)
                else { break }
                // Logic handled elsewhere or pass-through
                generatedEventCount &+= 1

            case .spriteSetSourceRect:
                guard
                    let event = localUnpack(
                        label: "SpriteSetSourceRect", as: PackedSpriteSetSourceRectEvent.self)
                else { break }
                spriteManager.setSourceRect(
                    SpriteID(id1: event.id1, id2: event.id2), (event.x, event.y, event.w, event.h))
                generatedEventCount &+= 1

            // --- GEOMETRY ---
            case .geomAddPoint:
                guard
                    let event = localUnpack(label: "GeomAddPoint", as: PackedGeomAddPointEvent.self)
                else { break }
                geometryManager.addPoint(event: event)
                generatedEventCount &+= 1

            case .geomAddLine:
                guard let event = localUnpack(label: "GeomAddLine", as: PackedGeomAddLineEvent.self)
                else { break }
                geometryManager.addLine(event: event)
                generatedEventCount &+= 1

            case .geomAddRect:
                guard let event = localUnpack(label: "GeomAddRect", as: PackedGeomAddRectEvent.self)
                else { break }
                geometryManager.addRect(event: event, isFilled: false)
                generatedEventCount &+= 1

            case .geomAddFillRect:
                guard
                    let event = localUnpack(
                        label: "GeomAddFillRect", as: PackedGeomAddRectEvent.self)
                else { break }
                geometryManager.addRect(event: event, isFilled: true)
                generatedEventCount &+= 1

            case .geomAddPacked:
                // Note: This is variable length but fixed logic handles the internal array size.
                // We just need to ensure the whole block is skipped correctly.
                // The header tells us type and count. The DATA is immediately following.
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }
                guard
                    let header: PackedGeomAddPackedHeaderEvent = localUnpack(
                        label: "GeomAddPacked", as: PackedGeomAddPackedHeaderEvent.self)
                else { break }

                guard let type = PrimitiveType(rawValue: header.primitiveType) else { break }
                let count = Int(header.count)
                let elementSize: Int
                switch type {
                case .points, .lines: elementSize = MemoryLayout<SDL_FPoint>.stride
                case .rects, .fillRects: elementSize = MemoryLayout<SDL_FRect>.stride
                default: elementSize = 0
                }
                let totalDataSize = count * elementSize

                // Calculate padding for the DATA block?
                // Currently PHP does not align the internal array of packed geometry,
                // BUT the "End of Event" alignment logic below will catch the trail.

                guard offset + totalDataSize <= commandData.count else { break }
                let geometryData = commandData.subdata(in: offset..<(offset + totalDataSize))
                offset += totalDataSize

                geometryManager.addPacked(header: header, data: geometryData)
                generatedEventCount &+= 1

            case .geomRemove:
                guard let event = localUnpack(label: "GeomRemove", as: PackedGeomRemoveEvent.self)
                else { break }
                geometryManager.removePrimitive(id: SpriteID(id1: event.id1, id2: event.id2))
                generatedEventCount &+= 1

            case .geomSetColor:
                guard
                    let event = localUnpack(label: "GeomSetColor", as: PackedGeomSetColorEvent.self)
                else { break }
                geometryManager.setPrimitiveColor(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    color: (event.r, event.g, event.b, event.a))
                generatedEventCount &+= 1

            // --- WINDOW ---
            case .windowTitle:
                guard let event = localUnpack(label: "WindowTitle", as: PackedWindowTitleEvent.self)
                else { break }
                handleWindowTitleCommand(event: event)
                generatedEventCount &+= 1

            case .windowResize:
                guard
                    let event = localUnpack(label: "WindowResize", as: PackedWindowResizeEvent.self)
                else { break }
                SDL_SetWindowSize(window, event.w, event.h)
                generatedEventCount &+= 1

            case .windowFlags:
                guard let event = localUnpack(label: "WindowFlags", as: PackedWindowFlagsEvent.self)
                else { break }
                handleWindowFlagsCommand(event: event)
                generatedEventCount &+= 1

            // --- AUDIO ---
            case .audioPlay:
                guard let event = localUnpack(label: "AudioPlay", as: PackedAudioPlayEvent.self)
                else { break }
                handleAudioPlayCommand(event: event)
                generatedEventCount &+= 1

            case .audioStopAll:
                // No payload, just header read already.
                ma_device_set_master_volume(self.maEngine.pDevice, 0)
                generatedEventCount &+= 1

            case .audioSetMasterVolume:
                guard
                    let event = localUnpack(
                        label: "AudioSetMasterVol", as: PackedAudioSetMasterVolumeEvent.self)
                else { break }
                ma_engine_set_volume(&self.maEngine, event.volume)
                generatedEventCount &+= 1

            case .audioPause:
                guard let event = localUnpack(label: "AudioPause", as: PackedAudioPauseEvent.self)
                else { break }
                handleAudioPauseCommand(event: event)
                generatedEventCount &+= 1

            case .audioStop:
                guard let event = localUnpack(label: "AudioStop", as: PackedAudioStopEvent.self)
                else { break }
                handleAudioStopCommand(event: event)
                generatedEventCount &+= 1

            case .audioUnload:
                guard let event = localUnpack(label: "AudioUnload", as: PackedAudioUnloadEvent.self)
                else { break }
                unloadAudio(audioId: event.audioId)
                generatedEventCount &+= 1

            case .audioSetVolume:
                guard
                    let event = localUnpack(
                        label: "AudioSetVolume", as: PackedAudioSetVolumeEvent.self)
                else { break }
                handleAudioSetVolumeCommand(event: event)
                generatedEventCount &+= 1

            case .audioLoaded:
                // Feedback event, skip payload manually
                offset += payloadSize

            // --- PHYSICS ---
            case .physicsAddBody:
                guard
                    let event = localUnpack(
                        label: "PhysAddBody", as: PackedPhysicsAddBodyEvent.self)
                else { break }
                handlePhysicsAddBodyCommand(event: event)
                generatedEventCount &+= 1

            case .physicsRemoveBody:
                guard
                    let event = localUnpack(
                        label: "PhysRemoveBody", as: PackedPhysicsRemoveBodyEvent.self)
                else { break }
                physicsManager.removeBody(id: SpriteID(id1: event.id1, id2: event.id2))
                generatedEventCount &+= 1

            case .physicsApplyForce:
                guard
                    let event = localUnpack(
                        label: "PhysApplyForce", as: PackedPhysicsApplyForceEvent.self)
                else { break }
                physicsManager.applyForce(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    force: cpVect(x: event.forceX, y: event.forceY))
                generatedEventCount &+= 1

            case .physicsApplyImpulse:
                guard
                    let event = localUnpack(
                        label: "PhysApplyImpulse", as: PackedPhysicsApplyImpulseEvent.self)
                else { break }
                physicsManager.applyImpulse(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    impulse: cpVect(x: event.impulseX, y: event.impulseY))
                generatedEventCount &+= 1

            case .physicsSetVelocity:
                guard
                    let event = localUnpack(
                        label: "PhysSetVel", as: PackedPhysicsSetVelocityEvent.self)
                else { break }
                physicsManager.setVelocity(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    velocity: cpVect(x: event.velocityX, y: event.velocityY))
                generatedEventCount &+= 1

            case .physicsSetPosition:
                guard
                    let event = localUnpack(
                        label: "PhysSetPos", as: PackedPhysicsSetPositionEvent.self)
                else { break }
                physicsManager.setPosition(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    position: cpVect(x: event.positionX, y: event.positionY))
                generatedEventCount &+= 1

            case .physicsSetRotation:
                guard
                    let event = localUnpack(
                        label: "PhysSetRot", as: PackedPhysicsSetRotationEvent.self)
                else { break }
                physicsManager.setRotation(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    angleInRadians: event.angleInRadians)
                generatedEventCount &+= 1

            case .physicsCollisionBegin, .physicsCollisionSeparate, .physicsSyncTransform:
                // Feedback, skip payload
                offset += payloadSize

            case .physicsSetDebugMode:
                guard
                    let event = localUnpack(
                        label: "PhysDebug", as: PackedPhysicsSetDebugModeEvent.self)
                else { break }
                handlePhysicsSetDebugModeCommand(event: event)
                generatedEventCount &+= 1

            // --- PLUGIN ---
            case .pluginUnload:
                guard
                    let event = localUnpack(label: "PluginUnload", as: PackedPluginUnloadEvent.self)
                else { break }
                self.unloadPlugin(id: event.pluginId)
                generatedEventCount &+= 1

            case .plugin:
                guard let event = localUnpack(label: "PluginOn", as: PackedPluginOnEvent.self)
                else { break }
                self.pluginOn = (event.eventId == 1)
                generatedEventCount &+= 1

            case .pluginEventStacking:
                guard
                    let event = localUnpack(
                        label: "PluginEventStacking", as: PackedPluginEventStackingEvent.self)
                else { break }
                self.eventStackingOn = (event.eventId == 1)
                generatedEventCount &+= 1

            case .pluginSubscribeEvent:
                guard
                    let event = localUnpack(label: "PluginSub", as: PackedPluginSubscribeEvent.self)
                else { break }
                self.subscribePlugin(pluginId: event.pluginId, channelId: event.channelNo)
                generatedEventCount &+= 1

            case .pluginUnsubscribeEvent:
                guard
                    let event = localUnpack(
                        label: "PluginUnsub", as: PackedPluginUnsubscribeEvent.self)
                else { break }
                self.unsubscribePlugin(pluginId: event.pluginId, channelId: event.channelNo)
                generatedEventCount &+= 1

            case .pluginSet:
                guard localUnpack(label: "PluginSet", as: PackedPluginSetEvent.self) != nil else {
                    break
                }
                generatedEventCount &+= 1

            // --- CAMERA ---
            case .cameraSetPosition:
                guard
                    let event = localUnpack(
                        label: "CamSetPos", as: PackedCameraSetPositionEvent.self)
                else { break }
                self.cameraOffset = (x: event.positionX, y: event.positionY)
                generatedEventCount &+= 1

            case .cameraMove:
                guard let event = localUnpack(label: "CamMove", as: PackedCameraMoveEvent.self)
                else { break }
                self.cameraOffset.x += event.deltaX
                self.cameraOffset.y += event.deltaY
                generatedEventCount &+= 1

            case .cameraSetZoom:
                guard
                    let event = localUnpack(label: "CamSetZoom", as: PackedCameraSetZoomEvent.self)
                else { break }
                self.cameraZoom = event.zoom
                generatedEventCount &+= 1

            case .cameraSetRotation:
                guard
                    let event = localUnpack(
                        label: "CamSetRot", as: PackedCameraSetRotationEvent.self)
                else { break }
                self.cameraRotation = event.angleInRadians
                generatedEventCount &+= 1

            case .cameraFollowEntity:
                guard
                    let event = localUnpack(
                        label: "CamFollow", as: PackedCameraFollowEntityEvent.self)
                else { break }
                self.cameraFollowTarget = SpriteID(id1: event.id1, id2: event.id2)
                generatedEventCount &+= 1

            case .cameraStopFollowing:
                self.cameraFollowTarget = nil
                offset += payloadSize
                generatedEventCount &+= 1

            // --- SCRIPT ---
            case .scriptSubscribe:
                guard
                    let event = localUnpack(label: "ScriptSub", as: PackedScriptSubscribeEvent.self)
                else { break }
                self.phpSubscribedChannels.insert(event.channelNo)
                generatedEventCount &+= 1

            case .scriptUnsubscribe:
                guard
                    let event = localUnpack(
                        label: "ScriptUnsub", as: PackedScriptUnsubscribeEvent.self)
                else { break }
                self.phpSubscribedChannels.remove(event.channelNo)
                generatedEventCount &+= 1

            // --- INPUT (Skip) ---
            case .inputKeyup, .inputKeydown, .inputMouseup, .inputMousedown, .inputMousemotion:
                offset += payloadSize
            }

            // ALIGNMENT FIX: Align offset to next 8-byte boundary
            // This consumes any trailing padding added by the sender
            alignOffset(&offset)

            if offset > commandData.count {
                print(
                    "Loop \(i)/\(commandCount): !!! CRITICAL ERROR: Offset (\(offset)) exceeded data length. Breaking."
                )
                break
            }
        }
        return (generatedEvents, generatedEventCount)
    }
}
