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

extension PhrostEngine {

    // MARK: - Utility Functions

    /// Helper to unpack data from the command blob.
    func unpack<T>(data: Data, offset: inout Int, label: String, as type: T.Type) -> T? {
        let size = MemoryLayout<T>.stride
        let currentOffset = offset
        guard currentOffset + size <= data.count else {
            print(
                "Unpack Error (\(label)): Not enough data for \(T.self). Offset=\(currentOffset), Need=\(size), Have=\(data.count - currentOffset)"
            )
            return nil
        }
        let value = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: currentOffset, as: T.self)
        }
        offset = currentOffset + size
        return value
    }

    // MARK: - Core Command Processor

    /// Processes the command buffer received from the update callback.
    internal func processCommands(_ commandData: Data) -> (
        generatedEvents: Data, eventCount: UInt32
    ) {
        // --- FIX 1: PRE-ALLOCATION ---
        // Pre-allocate with a large capacity to prevent resizing
        var generatedEvents = Data(capacity: 10 * 1024 * 1024)
        var generatedEventCount: UInt32 = 0

        guard !commandData.isEmpty else {
            return (generatedEvents, 0)
        }

        var offset = 0

        // Local unpack helper that uses the instance method above
        func localUnpack<T>(label: String, as type: T.Type) -> T? {
            return unpack(data: commandData, offset: &offset, label: label, as: type)
        }

        guard let commandCount = localUnpack(label: "CommandCount", as: UInt32.self) else {
            print("PHP Command Error: Failed to read command count.")
            return (generatedEvents, 0)
        }

        // --- Command Loop ---
        for i in 0..<commandCount {
            let loopOffsetStart = offset
            guard let eventTypeRaw = localUnpack(label: "EventType", as: UInt32.self),
                let timestamp = localUnpack(label: "Timestamp", as: UInt64.self)
            else {
                print(
                    "Loop \(i)/\(commandCount): FAILED to read event header. Offset was: \(loopOffsetStart). Breaking loop."
                )
                break
            }

            guard let eventType = Events(rawValue: eventTypeRaw) else {
                print(
                    "Loop \(i)/\(commandCount): PHP command: Unknown event type \(eventTypeRaw), cannot continue parsing. Offset: \(offset). Breaking loop."
                )
                break
            }
            guard let payloadSize = eventPayloadSizes[eventType.rawValue] else {
                print(
                    "Loop \(i)/\(commandCount): Event type \(eventType) has NO registered size in map. Cannot continue parsing. Offset: \(offset). Breaking loop."
                )
                break
            }

            // --- Process Specific Event (Calls to helper extensions) ---
            switch eventType {

            // =========================================================================
            // SPRITE COMMANDS
            // =========================================================================
            case .spriteTextureLoad:
                // This one is complex and needs to stay partially here for the variable length logic
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }

                guard
                    let header: PackedTextureLoadHeaderEvent = localUnpack(
                        label: "TexLoadHeader", as: PackedTextureLoadHeaderEvent.self)
                else { break }

                let filenameLength = Int(header.filenameLength)
                let offsetAfterFixed = offset
                guard offsetAfterFixed + filenameLength <= commandData.count else { break }

                // subdata is OK here as it's for variable-length strings, not in the tightest loop
                let filenameData = commandData.subdata(
                    in: offsetAfterFixed..<(offsetAfterFixed + filenameLength))
                offset = offsetAfterFixed + filenameLength

                if let filename = String(data: filenameData, encoding: .utf8) {
                    // This call generates a *new* .spriteTextureSet event
                    let (events, count) = handleTextureLoadCommand(
                        header: header, filename: filename)
                    generatedEvents.append(events)
                    generatedEventCount &+= count
                } else {
                    print("Loop \(i)/\(commandCount): Failed to decode filename string.")
                }

            case .spriteAdd:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteAddEvent = localUnpack(
                        label: "SpriteAddPayload", as: PackedSpriteAddEvent.self)
                else { break }
                spriteManager.addSprite(event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteRemove:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteRemoveEvent = localUnpack(
                        label: "SpriteRemovePayload", as: PackedSpriteRemoveEvent.self)
                else { break }
                spriteManager.removeSprite(id: SpriteID(id1: event.id1, id2: event.id2))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteMove:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteMoveEvent = localUnpack(
                        label: "SpriteMovePayload", as: PackedSpriteMoveEvent.self)
                else { break }
                spriteManager.moveSprite(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.positionX, event.positionY, event.positionZ))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteScale:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteScaleEvent = localUnpack(
                        label: "SpriteScalePayload", as: PackedSpriteScaleEvent.self)
                else { break }
                spriteManager.scaleSprite(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.scaleX, event.scaleY, event.scaleZ))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteResize:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteResizeEvent = localUnpack(
                        label: "SpriteResizePayload", as: PackedSpriteResizeEvent.self)
                else { break }
                spriteManager.resizeSprite(
                    SpriteID(id1: event.id1, id2: event.id2), (event.sizeH, event.sizeW))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteRotate:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteRotateEvent = localUnpack(
                        label: "SpriteRotatePayload", as: PackedSpriteRotateEvent.self)
                else { break }
                spriteManager.rotateSprite(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.rotationX, event.rotationY, event.rotationZ))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteColor:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteColorEvent = localUnpack(
                        label: "SpriteColorPayload", as: PackedSpriteColorEvent.self)
                else { break }
                spriteManager.colorSprite(
                    SpriteID(id1: event.id1, id2: event.id2), (event.r, event.g, event.b, event.a))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteSpeed:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteSpeedEvent = localUnpack(
                        label: "SpriteSpeedPayload", as: PackedSpriteSpeedEvent.self)
                else { break }
                spriteManager.speedSprite(
                    SpriteID(id1: event.id1, id2: event.id2), (event.speedX, event.speedY))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteTextureSet:
                // This is both a command (if PHP sends it) and a feedback event (from .spriteTextureLoad)
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteTextureSetEvent = localUnpack(
                        label: "SpriteTextureSetPayload", as: PackedSpriteTextureSetEvent.self)
                else { break }

                // TODO: Add logic for spriteManager to set texture based on *textureId*
                // This requires a reverse lookup from textureId to the actual texture pointer.
                // spriteManager.setTexture(for: SpriteID(id1: event.id1, id2: event.id2), textureId: event.textureId)
                print(
                    "SpriteTextureSet: \(event.id1)/\(event.id2) to \(event.textureId) (Pass-through)"
                )

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .spriteSetSourceRect:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedSpriteSetSourceRectEvent = localUnpack(
                        label: "SpriteSetSourceRectPayload",
                        as: PackedSpriteSetSourceRectEvent.self)
                else { break }
                spriteManager.setSourceRect(
                    SpriteID(id1: event.id1, id2: event.id2),
                    (event.x, event.y, event.w, event.h)
                )

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // GEOMETRY COMMANDS (Logic delegated to GeometryManager)
            // =========================================================================
            case .geomAddPoint:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedGeomAddPointEvent = localUnpack(
                        label: "GeomAddPointPayload", as: PackedGeomAddPointEvent.self)
                else { break }
                geometryManager.addPoint(event: event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .geomAddLine:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedGeomAddLineEvent = localUnpack(
                        label: "GeomAddLinePayload", as: PackedGeomAddLineEvent.self)
                else { break }
                geometryManager.addLine(event: event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .geomAddRect:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedGeomAddRectEvent = localUnpack(
                        label: "GeomAddRectPayload", as: PackedGeomAddRectEvent.self)
                else { break }
                geometryManager.addRect(event: event, isFilled: false)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .geomAddFillRect:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedGeomAddRectEvent = localUnpack(
                        label: "GeomAddFillRectPayload", as: PackedGeomAddRectEvent.self)
                else { break }
                geometryManager.addRect(event: event, isFilled: true)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .geomAddPacked:
                // Variable-length packed geometry (Points, Lines, Rects)
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }
                guard
                    let header: PackedGeomAddPackedHeaderEvent = localUnpack(
                        label: "GeomAddPackedHeader", as: PackedGeomAddPackedHeaderEvent.self)
                else { break }

                guard let type = PrimitiveType(rawValue: header.primitiveType) else {
                    print(
                        "Loop \(i)/\(commandCount): Invalid primitive type \(header.primitiveType) for geomAddPacked."
                    )
                    break
                }

                let count = Int(header.count)
                let elementSize: Int
                switch type {
                case .points, .lines: elementSize = MemoryLayout<SDL_FPoint>.stride
                case .rects, .fillRects: elementSize = MemoryLayout<SDL_FRect>.stride
                default:
                    elementSize = 0
                    print(
                        "Loop \(i)/\(commandCount): Invalid type \(type) for geomAddPacked."
                    )
                    break
                }
                let totalDataSize = count * elementSize
                let offsetAfterFixed = offset

                guard offsetAfterFixed + totalDataSize <= commandData.count else { break }

                let geometryData = commandData.subdata(
                    in: offsetAfterFixed..<(offsetAfterFixed + totalDataSize))
                offset = offsetAfterFixed + totalDataSize

                geometryManager.addPacked(header: header, data: geometryData)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .geomRemove:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedGeomRemoveEvent = localUnpack(
                        label: "GeomRemovePayload", as: PackedGeomRemoveEvent.self)
                else { break }
                geometryManager.removePrimitive(id: SpriteID(id1: event.id1, id2: event.id2))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .geomSetColor:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedGeomSetColorEvent = localUnpack(
                        label: "GeomSetColorPayload", as: PackedGeomSetColorEvent.self)
                else { break }
                geometryManager.setPrimitiveColor(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    color: (event.r, event.g, event.b, event.a)
                )

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // WINDOW COMMANDS
            // =========================================================================
            case .windowTitle:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedWindowTitleEvent = localUnpack(
                        label: "WindowTitlePayload", as: PackedWindowTitleEvent.self)
                else { break }
                handleWindowTitleCommand(event: event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .windowResize:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedWindowResizeEvent = localUnpack(
                        label: "WindowResizePayload", as: PackedWindowResizeEvent.self)
                else { break }
                SDL_SetWindowSize(window, event.w, event.h)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .windowFlags:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedWindowFlagsEvent = localUnpack(
                        label: "WindowFlagsPayload", as: PackedWindowFlagsEvent.self)
                else { break }
                handleWindowFlagsCommand(event: event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // TEXT COMMANDS (Logic delegated to PhrostEngine+Text)
            // =========================================================================
            case .textAdd:
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }
                guard
                    let header: PackedTextAddEvent = localUnpack(
                        label: "TextAddHeader", as: PackedTextAddEvent.self)
                else { break }

                let fontPathLength = Int(header.fontPathLength)
                let textLength = Int(header.textLength)
                let totalVariableLength = fontPathLength + textLength
                let offsetAfterFixed = offset

                guard offsetAfterFixed + totalVariableLength <= commandData.count else { break }

                let fontPathData = commandData.subdata(
                    in: offsetAfterFixed..<(offsetAfterFixed + fontPathLength))
                let textData = commandData.subdata(
                    in: (offsetAfterFixed + fontPathLength)..<(offsetAfterFixed
                        + totalVariableLength)
                )
                offset = offsetAfterFixed + totalVariableLength

                if let fontPath = String(data: fontPathData, encoding: .utf8),
                    let textString = String(data: textData, encoding: .utf8)
                {
                    handleTextAddCommand(
                        header: header, fontPath: fontPath, textString: textString)
                } else {
                    print("Loop \(i)/\(commandCount): Failed to decode font path or text string.")
                }

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .textSetString:
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }
                guard
                    let header: PackedTextSetStringEvent = localUnpack(
                        label: "TextSetStringHeader", as: PackedTextSetStringEvent.self)
                else { break }

                let textLength = Int(header.textLength)
                let offsetAfterFixed = offset

                guard offsetAfterFixed + textLength <= commandData.count else { break }

                let textData = commandData.subdata(
                    in: offsetAfterFixed..<(offsetAfterFixed + textLength))
                offset = offsetAfterFixed + textLength

                if let newTextString = String(data: textData, encoding: .utf8) {
                    handleTextSetStringCommand(header: header, newTextString: newTextString)
                } else {
                    print("Loop \(i)/\(commandCount): Failed to decode new text string.")
                }

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // AUDIO COMMANDS (Logic delegated to PhrostEngine+Audio)
            // =========================================================================
            case .audioLoad:
                // This is a variable-length case, similar to textAdd/textureLoad
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }
                guard
                    let header: PackedAudioLoadEvent = localUnpack(
                        label: "AudioLoadHeader", as: PackedAudioLoadEvent.self)
                else { break }

                let pathLength = Int(header.pathLength)
                let offsetAfterFixed = offset

                guard offsetAfterFixed + pathLength <= commandData.count else { break }

                let pathData = commandData.subdata(
                    in: offsetAfterFixed..<(offsetAfterFixed + pathLength))
                offset = offsetAfterFixed + pathLength

                if let pathString = String(data: pathData, encoding: .utf8) {
                    let (audioId, success) = loadAudio(path: pathString)
                    // This generates a *new* .audioLoaded event
                    generatedEvents.append(makeAudioLoadedEvent(audioId: audioId))
                    generatedEventCount &+= 1
                } else {
                    print("Loop \(i)/\(commandCount): Failed to decode audio path string.")
                    generatedEvents.append(makeAudioLoadedEvent(audioId: 0))  // Signal failure
                    generatedEventCount &+= 1
                }

            case .audioPlay:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedAudioPlayEvent = localUnpack(
                        label: "AudioPlayPayload", as: PackedAudioPlayEvent.self)
                else { break }
                handleAudioPlayCommand(event: event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .audioStopAll:
                guard offset + payloadSize <= commandData.count else { break }

                ma_device_set_master_volume(self.maEngine.pDevice, 0)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .audioSetMasterVolume:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedAudioSetMasterVolumeEvent = localUnpack(
                        label: "AudioSetMasterVolumePayload",
                        as: PackedAudioSetMasterVolumeEvent.self)
                else { break }
                ma_engine_set_volume(&self.maEngine, event.volume)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .audioLoaded:
                // Feedback event, do not pass through.
                print("Audio loaded feedback event received.")
                // We *must* still consume the payload, however.
                guard offset + payloadSize <= commandData.count else { break }
                offset += payloadSize  // Manually skip payload

            case .audioPause:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedAudioPauseEvent = localUnpack(
                        label: "AudioPausePayload", as: PackedAudioPauseEvent.self)
                else { break }
                handleAudioPauseCommand(event: event)

                // --- Pass-through ---
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .audioStop:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedAudioStopEvent = localUnpack(
                        label: "AudioStopPayload", as: PackedAudioStopEvent.self)
                else { break }
                handleAudioStopCommand(event: event)

                // --- Pass-through ---
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .audioUnload:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedAudioUnloadEvent = localUnpack(
                        label: "AudioUnloadPayload", as: PackedAudioUnloadEvent.self)
                else { break }
                unloadAudio(audioId: event.audioId)

                // --- Pass-through ---
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .audioSetVolume:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedAudioSetVolumeEvent = localUnpack(
                        label: "AudioSetVolumePayload", as: PackedAudioSetVolumeEvent.self)
                else { break }
                handleAudioSetVolumeCommand(event: event)

                // --- Pass-through ---
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // PHYSICS COMMANDS (Logic delegated to PhysicsManager)
            // =========================================================================
            case .physicsAddBody:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsAddBodyEvent = localUnpack(
                        label: "PhysicsAddBodyPayload", as: PackedPhysicsAddBodyEvent.self)
                else { break }
                handlePhysicsAddBodyCommand(event: event)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsRemoveBody:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsRemoveBodyEvent = localUnpack(
                        label: "PhysicsRemoveBodyPayload", as: PackedPhysicsRemoveBodyEvent.self)
                else { break }
                physicsManager.removeBody(id: SpriteID(id1: event.id1, id2: event.id2))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsApplyForce:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsApplyForceEvent = localUnpack(
                        label: "PhysicsApplyForcePayload", as: PackedPhysicsApplyForceEvent.self)
                else { break }
                physicsManager.applyForce(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    force: cpVect(x: event.forceX, y: event.forceY))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsApplyImpulse:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsApplyImpulseEvent = localUnpack(
                        label: "PhysicsApplyImpulsePayload", as: PackedPhysicsApplyImpulseEvent.self
                    )
                else { break }
                physicsManager.applyImpulse(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    impulse: cpVect(x: event.impulseX, y: event.impulseY))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsSetVelocity:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsSetVelocityEvent = localUnpack(
                        label: "PhysicsSetVelocityPayload", as: PackedPhysicsSetVelocityEvent.self)
                else { break }
                physicsManager.setVelocity(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    velocity: cpVect(x: event.velocityX, y: event.velocityY))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsSetPosition:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsSetPositionEvent = localUnpack(
                        label: "PhysicsSetPositionPayload", as: PackedPhysicsSetPositionEvent.self)
                else { break }
                physicsManager.setPosition(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    position: cpVect(x: event.positionX, y: event.positionY))

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsSetRotation:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPhysicsSetRotationEvent = localUnpack(
                        label: "PhysicsSetRotationPayload", as: PackedPhysicsSetRotationEvent.self)
                else { break }
                physicsManager.setRotation(
                    id: SpriteID(id1: event.id1, id2: event.id2),
                    angleInRadians: event.angleInRadians)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .physicsCollisionBegin, .physicsCollisionSeparate, .physicsSyncTransform:
                // Feedback events, do not pass through.
                print(
                    "Loop \(i)/\(commandCount): WARNING - Received unexpected physics feedback event \(eventType) from PHP. Skipping \(payloadSize) bytes."
                )
                guard offset + payloadSize <= commandData.count else { break }
                offset += payloadSize

            // =========================================================================
            // PLUGIN COMMANDS (Logic delegated to PhrostEngine+Plugin)
            // =========================================================================
            case .pluginLoad:
                // This is a variable-length case.
                let caseOffsetStart = offset
                guard caseOffsetStart + payloadSize <= commandData.count else { break }
                guard
                    let header: PackedPluginLoadHeaderEvent = localUnpack(
                        label: "PluginLoadHeader", as: PackedPluginLoadHeaderEvent.self)
                else { break }

                let pathLength = Int(header.pathLength)
                let offsetAfterFixed = offset

                guard offsetAfterFixed + pathLength <= commandData.count else { break }

                let pathData = commandData.subdata(
                    in: offsetAfterFixed..<(offsetAfterFixed + pathLength))
                offset = offsetAfterFixed + pathLength

                let pathString: String?
                if let decodedString = String(data: pathData, encoding: .utf8) {
                    pathString = decodedString
                } else {
                    pathString = nil
                    print("Loop \(i)/\(commandCount): Failed to decode plugin path string.")
                }

                // This call generates a *new* .pluginSet event
                let (events, count) = self.loadPlugin(
                    channelNo: header.channelNo, path: pathString ?? "")
                generatedEvents.append(events)
                generatedEventCount &+= count

            case .pluginUnload:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPluginUnloadEvent = localUnpack(
                        label: "PluginUnloadPayload", as: PackedPluginUnloadEvent.self)
                else { break }
                self.unloadPlugin(id: event.pluginId)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .plugin:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPluginOnEvent = localUnpack(
                        label: "PluginPayload", as: PackedPluginOnEvent.self)
                else { break }
                self.pluginOn = (event.eventId == 1)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .pluginEventStacking:  // <-- NEW COMMAND HANDLER
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPluginEventStackingEvent = localUnpack(
                        label: "PluginEventStackingPayload", as: PackedPluginEventStackingEvent.self
                    )
                else { break }
                self.eventStackingOn = (event.eventId == 1)
                print("Engine State: Event Stacking is now \(self.eventStackingOn ? "ON" : "OFF").")

                // Pass-through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .pluginSubscribeEvent:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPluginSubscribeEvent = localUnpack(
                        label: "PluginSubscribePayload", as: PackedPluginSubscribeEvent.self)
                else { break }
                self.subscribePlugin(pluginId: event.pluginId, channelId: event.channelNo)

                // Pass-through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .pluginUnsubscribeEvent:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedPluginUnsubscribeEvent = localUnpack(
                        label: "PluginUnsubscribePayload", as: PackedPluginUnsubscribeEvent.self)
                else { break }
                self.unsubscribePlugin(pluginId: event.pluginId, channelId: event.channelNo)

                // Pass-through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .pluginSet:
                // Feedback event, but we'll pass it through for consistency.
                guard offset + payloadSize <= commandData.count,
                    localUnpack(label: "PluginSetPayload", as: PackedPluginSetEvent.self) != nil
                else { break }

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // CAMERA COMMANDS
            // =========================================================================
            case .cameraSetPosition:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedCameraSetPositionEvent = localUnpack(
                        label: "CameraSetPositionPayload", as: PackedCameraSetPositionEvent.self)
                else { break }
                self.cameraOffset = (x: event.positionX, y: event.positionY)

                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .cameraMove:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedCameraMoveEvent = localUnpack(
                        label: "CameraMovePayload", as: PackedCameraMoveEvent.self)
                else { break }
                self.cameraOffset.x += event.deltaX
                self.cameraOffset.y += event.deltaY

                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .cameraSetZoom:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedCameraSetZoomEvent = localUnpack(
                        label: "CameraSetZoomPayload", as: PackedCameraSetZoomEvent.self)
                else { break }
                self.cameraZoom = event.zoom

                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .cameraSetRotation:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedCameraSetRotationEvent = localUnpack(
                        label: "CameraSetRotationPayload", as: PackedCameraSetRotationEvent.self)
                else { break }
                self.cameraRotation = event.angleInRadians

                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .cameraFollowEntity:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedCameraFollowEntityEvent = localUnpack(
                        label: "CameraFollowEntityPayload", as: PackedCameraFollowEntityEvent.self)
                else { break }
                self.cameraFollowTarget = SpriteID(id1: event.id1, id2: event.id2)

                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .cameraStopFollowing:
                guard offset + payloadSize <= commandData.count else { break }
                // This event has no payload, so we just read the header
                // and advance the offset by its (zero) size.
                offset += payloadSize

                self.cameraFollowTarget = nil

                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // SCRIPT COMMANDS
            // =========================================================================
            case .scriptSubscribe:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedScriptSubscribeEvent = localUnpack(
                        label: "ScriptSubscribePayload", as: PackedScriptSubscribeEvent.self)
                else { break }

                print("PHP subscribed to channel \(event.channelNo)")
                self.phpSubscribedChannels.insert(event.channelNo)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            case .scriptUnsubscribe:
                guard offset + payloadSize <= commandData.count,
                    let event: PackedScriptUnsubscribeEvent = localUnpack(
                        label: "ScriptUnsubscribePayload", as: PackedScriptUnsubscribeEvent.self)
                else { break }

                print("PHP unsubscribed from channel \(event.channelNo)")
                self.phpSubscribedChannels.remove(event.channelNo)

                // Pass-Through
                let eventEndOffset = offset
                generatedEvents.append(commandData[loopOffsetStart..<eventEndOffset])
                generatedEventCount &+= 1

            // =========================================================================
            // INPUT COMMANDS (Skipped, as they are engine-to-plugin only)
            // =========================================================================
            case .inputKeyup, .inputKeydown, .inputMouseup, .inputMousedown, .inputMousemotion:
                print(
                    "Loop \(i)/\(commandCount): WARNING - Received unexpected input event \(eventType) from PHP. Skipping \(payloadSize) bytes."
                )
                guard offset + payloadSize <= commandData.count else { break }
                offset += payloadSize
            }
            // --- End switch eventType ---

            if offset > commandData.count {
                print(
                    "Loop \(i)/\(commandCount): !!! CRITICAL ERROR: Offset (\(offset)) exceeded data length (\(commandData.count)) after processing \(eventType). Breaking loop."
                )
                break
            }
        }
        return (generatedEvents, generatedEventCount)
    }
}
