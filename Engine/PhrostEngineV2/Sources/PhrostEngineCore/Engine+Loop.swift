import CMiniaudio
import Foundation
import ImGui
import SwiftSDL
import SwiftSDL_image
import SwiftSDL_ttf

extension PhrostEngine {

    // MARK: - Debug Helper
    internal func debugWalkRendererBlob(_ data: Data) {
        print("\n--- [Swift Debug Walk] Start (\(data.count) bytes) ---")
        var offset = 0

        func peek<T>(as type: T.Type) -> T? {
            if offset + MemoryLayout<T>.size > data.count { return nil }
            return data.withUnsafeBytes { $0.loadSafe(fromByteOffset: offset, as: T.self) }
        }

        guard let commandCount = peek(as: UInt32.self) else { return }
        offset += 8

        print("Commands: \(commandCount)")

        for i in 0..<commandCount {
            let startOffset = offset
            guard let eventID = peek(as: UInt32.self) else { break }
            offset += 4
            guard let timestamp = peek(as: UInt64.self) else { break }
            offset += 12

            guard let event = Events(rawValue: eventID) else {
                print("  [\(i)] Unknown Event ID: \(eventID) at offset \(startOffset)")
                break
            }

            let payloadSize = eventPayloadSizes[event.rawValue] ?? 0
            print(
                "  [\(i)] Event: \(event) (ID=\(eventID)) at offset \(startOffset), payloadSize=\(payloadSize)"
            )

            if event == .textAdd {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(fromByteOffset: startOffset + 16, as: PackedTextAddEvent.self)
                }
                let fpLen = Int(header.fontPathLength)
                let txtLen = Int(header.textLength)
                let fpPad = (8 - (fpLen % 8)) % 8
                let txtPad = (8 - (txtLen % 8)) % 8
                offset += fpLen + fpPad + txtLen + txtPad
            } else if event == .textSetString {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(fromByteOffset: startOffset + 16, as: PackedTextSetStringEvent.self)
                }
                let txtLen = Int(header.textLength)
                let txtPad = (8 - (txtLen % 8)) % 8
                offset += txtLen + txtPad
            } else if event == .spriteTextureLoad {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(
                        fromByteOffset: startOffset + 16, as: PackedTextureLoadHeaderEvent.self)
                }
                let fnLen = Int(header.filenameLength)
                let fnPad = (8 - (fnLen % 8)) % 8
                offset += fnLen + fnPad
            } else if event == .audioLoad {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(fromByteOffset: startOffset + 16, as: PackedAudioLoadEvent.self)
                }
                let pLen = Int(header.pathLength)
                let pPad = (8 - (pLen % 8)) % 8
                offset += pLen + pPad
            } else if event == .pluginLoad {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(
                        fromByteOffset: startOffset + 16, as: PackedPluginLoadHeaderEvent.self)
                }
                let pLen = Int(header.pathLength)
                let pPad = (8 - (pLen % 8)) % 8
                offset += pLen + pPad
            } else if event == .uiBeginWindow {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(
                        fromByteOffset: startOffset + 16, as: PackedUIBeginWindowHeaderEvent.self)
                }
                let titleLen = Int(header.titleLength)
                let titlePad = (8 - (titleLen % 8)) % 8
                print(
                    "    -> uiBeginWindow: id=\(header.id), flags=\(header.flags), titleLen=\(titleLen)"
                )
                offset += titleLen + titlePad
            } else if event == .uiText {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(fromByteOffset: startOffset + 16, as: PackedUITextHeaderEvent.self)
                }
                let textLen = Int(header.textLength)
                let textPad = (8 - (textLen % 8)) % 8
                print("    -> uiText: textLen=\(textLen)")
                offset += textLen + textPad
            } else if event == .uiButton {
                offset += payloadSize
                let header = data.withUnsafeBytes {
                    $0.loadSafe(
                        fromByteOffset: startOffset + 16, as: PackedUIButtonHeaderEvent.self)
                }
                let labelLen = Int(header.labelLength)
                let labelPad = (8 - (labelLen % 8)) % 8
                print(
                    "    -> uiButton: id=\(header.id), w=\(header.w), h=\(header.h), labelLen=\(labelLen)"
                )
                offset += labelLen + labelPad
            } else {
                offset += payloadSize
            }

            let pad = (8 - (offset % 8)) % 8
            offset += pad
        }
        print("--- [Swift Debug Walk] End ---\n")
    }

    // MARK: - Main Loop
    public func run(updateCallback: @escaping (Int, Double, Data) -> Data) {
        var frameCount: Int = 0
        var lastTick: UInt64 = SDL_GetTicks()
        let targetMs: Double = 1000.0 / 60.0

        while self.running {
            let frameStart: UInt64 = SDL_GetTicks()
            let now = SDL_GetTicks()
            let deltaMs = Double(now &- lastTick)
            let deltaSec = deltaMs / 1000.0

            let (sdlEventStream, sdlEventCount) = pollEvents()

            self.beginFrame(deltaSec: deltaSec)

            var currentEventPayloads = Data()
            let initialEventCount = sdlEventCount + self.internalEventCount

            if initialEventCount > 0 {
                currentEventPayloads.append(sdlEventStream)
                currentEventPayloads.append(self.internalEventStream)
            }

            self.internalEventStream.removeAll()
            self.internalEventCount = 0

            self.physicsManager.step(dt: deltaSec)
            let (physicsEvents, physicsEventCount) = self.physicsManager.drainGeneratedEvents()

            var allCPluginChannelOutputs: [UInt32: Data] = [:]

            var baseEvents = Data()
            let baseEventCount = initialEventCount + physicsEventCount

            if baseEventCount > 0 {
                let count = UInt32(baseEventCount)
                baseEvents.append(value: count)
                baseEvents.append(Data(count: 4))
                baseEvents.append(currentEventPayloads)
                baseEvents.append(physicsEvents)
            } else {
                baseEvents.append(Data(count: 8))
            }

            // --- Plugin Loop ---
            let sortedPluginIDs = self.loadedPlugins.keys.sorted()
            self.pluginChannelData.removeAll()

            for pluginID in sortedPluginIDs {
                guard let plugin = self.loadedPlugins[pluginID] else { continue }
                var pluginInputStream = Data()
                pluginInputStream.append(baseEvents)

                let updateFunc = plugin.updateFunc
                let freeFunc = plugin.freeFunc
                var cPluginCommandData = Data()

                let (eventsPtr, eventsLen) = pluginInputStream.withUnsafeBytes {
                    buffer -> (UnsafeRawPointer?, Int32) in
                    return (buffer.baseAddress, Int32(buffer.count))
                }

                var cResultLength: Int32 = 0
                let cResultDataPtr = updateFunc(now, deltaSec, eventsPtr, eventsLen, &cResultLength)

                if let dataPtr = cResultDataPtr, cResultLength > 0 {
                    let boundPtr = dataPtr.assumingMemoryBound(to: UInt8.self)
                    cPluginCommandData = Data(bytes: boundPtr, count: Int(cResultLength))
                }
                freeFunc(cResultDataPtr)

                var cOffset = 0
                guard !cPluginCommandData.isEmpty else { continue }

                func cUnpack<T>(label: String, as type: T.Type) -> T? {
                    return unpack(
                        data: cPluginCommandData, offset: &cOffset, label: label, as: type)
                }

                guard let cChannelCount = cUnpack(label: "C_ChannelCount", as: UInt32.self) else {
                    continue
                }
                cOffset += 4

                var cChannelIndex: [(id: UInt32, size: UInt32)] = []
                for _ in 0..<cChannelCount {
                    guard let id = cUnpack(label: "C_ChannelID", as: UInt32.self),
                        let size = cUnpack(label: "C_ChannelSize", as: UInt32.self)
                    else { break }
                    cChannelIndex.append((id: id, size: size))
                }

                for entry in cChannelIndex {
                    let cChannelEnd = cOffset + Int(entry.size)
                    guard cChannelEnd <= cPluginCommandData.count else { break }
                    let cChannelBlob = cPluginCommandData.subdata(in: cOffset..<cChannelEnd)
                    cOffset = cChannelEnd
                    if !cChannelBlob.isEmpty {
                        allCPluginChannelOutputs[entry.id] = cChannelBlob
                    }
                }
            }

            // --- PHP Update ---
            var eventsForPHP = Data()
            eventsForPHP.append(baseEvents)

            lastTick = now
            let phpCommandData = updateCallback(frameCount, deltaSec, eventsForPHP)

            var offset = 0
            guard !phpCommandData.isEmpty else {
                self.physicsManager.syncPhysicsToSprites()
                render(deltaSec: deltaSec)

                let frameWorkEnd = SDL_GetTicks()
                let frameTime = Double(frameWorkEnd &- frameStart)
                let sleepMs = targetMs - frameTime
                if sleepMs > 0 { SDL_Delay(UInt32(sleepMs)) }
                frameCount &+= 1
                continue
            }

            func phpUnpack<T>(label: String, as type: T.Type) -> T? {
                return unpack(data: phpCommandData, offset: &offset, label: label, as: type)
            }

            guard let channelCount = phpUnpack(label: "ChannelCount", as: UInt32.self) else {
                print("PHP Command Error: Failed to read channel count.")
                continue
            }
            offset += 4

            var channelIndex: [(id: UInt32, size: UInt32)] = []
            for i in 0..<channelCount {
                guard
                    let id = phpUnpack(label: "ChannelID", as: UInt32.self),
                    let size = phpUnpack(label: "ChannelSize", as: UInt32.self)
                else {
                    print("PHP Command Error: Failed to read channel index table entry \(i).")
                    break
                }
                channelIndex.append((id: id, size: size))
            }

            self.pluginChannelData = allCPluginChannelOutputs

            for entry in channelIndex {
                let channelEnd = offset + Int(entry.size)
                guard channelEnd <= phpCommandData.count else {
                    print("PHP Command Error: Channel \(entry.id) size exceeds data.")
                    break
                }
                let phpChannelBlob = phpCommandData.subdata(in: offset..<channelEnd)
                offset = channelEnd

                if let existingBlob = self.pluginChannelData[entry.id] {
                    var subOffset = 0
                    if !phpChannelBlob.isEmpty,
                        let subCount = unpack(
                            data: phpChannelBlob, offset: &subOffset, label: "PHP_SubCount",
                            as: UInt32.self)
                    {

                        subOffset += 4

                        if subCount > 0 {
                            let subEvents = phpChannelBlob.subdata(
                                in: subOffset..<phpChannelBlob.count)
                            var existingOffset = 0
                            if let existingCount = unpack(
                                data: existingBlob, offset: &existingOffset, label: "ExCount",
                                as: UInt32.self)
                            {
                                existingOffset += 4
                                let existingEvents = existingBlob.subdata(
                                    in: existingOffset..<existingBlob.count)
                                let newTotalCount = existingCount &+ subCount
                                var newBlob = Data()
                                let newCount = newTotalCount
                                newBlob.append(value: newCount)
                                newBlob.append(Data(count: 4))
                                newBlob.append(existingEvents)
                                newBlob.append(subEvents)
                                self.pluginChannelData[entry.id] = newBlob
                            }
                        }
                    }
                } else {
                    if !phpChannelBlob.isEmpty {
                        self.pluginChannelData[entry.id] = phpChannelBlob
                    }
                }
            }

            var phpGeneratedEvents = Data()
            var phpGeneratedEventCount: UInt32 = 0

            if let rendererBlob = self.pluginChannelData[0] {
                // debugWalkRendererBlob(rendererBlob)  // Disabled - data confirmed correct
                let (events, count) = processCommands(rendererBlob)
                phpGeneratedEvents.append(events)
                phpGeneratedEventCount &+= count
            }
            if let physicsBlob = self.pluginChannelData[2] {
                let (events, count) = processCommands(physicsBlob)
                phpGeneratedEvents.append(events)
                phpGeneratedEventCount &+= count
            }

            self.pluginChannelData.removeValue(forKey: 0)
            self.pluginChannelData.removeValue(forKey: 2)

            self.internalEventStream.removeAll()
            self.internalEventCount = 0

            self.internalEventStream.append(phpGeneratedEvents)
            self.internalEventCount = phpGeneratedEventCount

            self.physicsManager.syncPhysicsToSprites()
            render(deltaSec: deltaSec)

            let frameWorkEnd = SDL_GetTicks()
            let frameTime = Double(frameWorkEnd &- frameStart)
            let sleepMs = targetMs - frameTime
            if sleepMs > 0 { SDL_Delay(UInt32(sleepMs)) }
            frameCount &+= 1
        }
    }

    public func stop() {
        self.running = false
    }

    internal func pollEvents() -> (eventStream: Data, eventCount: UInt32) {
        var eventStream = Data()
        var eventCount: UInt32 = 0
        var e = SDL_Event()

        while SDL_PollEvent(&e) {
            let timestamp = e.common.timestamp
            let _ = processImGuiInput(event: &e)

            switch e.type {
            case UInt32(SDL_EVENT_QUIT.rawValue):
                self.running = false
                continue
            case UInt32(SDL_EVENT_WINDOW_RESIZED.rawValue):
                let resizeEvent = PackedWindowResizeEvent(w: e.window.data1, h: e.window.data2)
                let evt = Events.windowResize.rawValue

                eventStream.append(value: evt)
                eventStream.append(value: timestamp)
                eventStream.append(Data(count: 4))
                eventStream.append(value: resizeEvent)

                let size = MemoryLayout<PackedWindowResizeEvent>.size
                let pad = (8 - (size % 8)) % 8
                if pad > 0 { eventStream.append(Data(count: pad)) }
                eventCount += 1

            case UInt32(SDL_EVENT_KEY_DOWN.rawValue):
                let keyEvent = PackedKeyEvent(
                    scancode: Int32(e.key.scancode.rawValue), keycode: e.key.key, mod: e.key.mod,
                    isRepeat: e.key.repeat ? 1 : 0, _padding: 0)
                let evt = Events.inputKeydown.rawValue

                eventStream.append(value: evt)
                eventStream.append(value: timestamp)
                eventStream.append(Data(count: 4))
                eventStream.append(value: keyEvent)

                let size = MemoryLayout<PackedKeyEvent>.size
                let pad = (8 - (size % 8)) % 8
                if pad > 0 { eventStream.append(Data(count: pad)) }
                eventCount += 1

            case UInt32(SDL_EVENT_KEY_UP.rawValue):
                let keyEvent = PackedKeyEvent(
                    scancode: Int32(e.key.scancode.rawValue), keycode: e.key.key, mod: e.key.mod,
                    isRepeat: 0, _padding: 0)
                let evt = Events.inputKeyup.rawValue

                eventStream.append(value: evt)
                eventStream.append(value: timestamp)
                eventStream.append(Data(count: 4))
                eventStream.append(value: keyEvent)

                let size = MemoryLayout<PackedKeyEvent>.size
                let pad = (8 - (size % 8)) % 8
                if pad > 0 { eventStream.append(Data(count: pad)) }
                eventCount += 1

            case UInt32(SDL_EVENT_MOUSE_MOTION.rawValue):
                let motionEvent = PackedMouseMotionEvent(
                    x: e.motion.x, y: e.motion.y, xrel: e.motion.xrel, yrel: e.motion.yrel)
                let evt = Events.inputMousemotion.rawValue

                eventStream.append(value: evt)
                eventStream.append(value: timestamp)
                eventStream.append(Data(count: 4))
                eventStream.append(value: motionEvent)

                let size = MemoryLayout<PackedMouseMotionEvent>.size
                let pad = (8 - (size % 8)) % 8
                if pad > 0 { eventStream.append(Data(count: pad)) }
                eventCount += 1

            case UInt32(SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue):
                let buttonEvent = PackedMouseButtonEvent(
                    x: e.button.x, y: e.button.y, button: e.button.button, clicks: e.button.clicks,
                    _padding: 0)
                let evt = Events.inputMousedown.rawValue

                eventStream.append(value: evt)
                eventStream.append(value: timestamp)
                eventStream.append(Data(count: 4))
                eventStream.append(value: buttonEvent)

                let size = MemoryLayout<PackedMouseButtonEvent>.size
                let pad = (8 - (size % 8)) % 8
                if pad > 0 { eventStream.append(Data(count: pad)) }
                eventCount += 1

            case UInt32(SDL_EVENT_MOUSE_BUTTON_UP.rawValue):
                let buttonEvent = PackedMouseButtonEvent(
                    x: e.button.x, y: e.button.y, button: e.button.button, clicks: e.button.clicks,
                    _padding: 0)
                let evt = Events.inputMouseup.rawValue

                eventStream.append(value: evt)
                eventStream.append(value: timestamp)
                eventStream.append(Data(count: 4))
                eventStream.append(value: buttonEvent)

                let size = MemoryLayout<PackedMouseButtonEvent>.size
                let pad = (8 - (size % 8)) % 8
                if pad > 0 { eventStream.append(Data(count: pad)) }
                eventCount += 1
            default: continue
            }
        }
        return (eventStream, eventCount)
    }

    // MARK: - Rendering
    internal func render(deltaSec: Double) {
        SDL_GetWindowSize(window, &windowWidth, &windowHeight)
        SDL_GetWindowSizeInPixels(window, &pixelWidth, &pixelHeight)
        scaleX = (windowWidth > 0) ? Float(pixelWidth) / Float(windowWidth) : 1.0
        scaleY = (windowHeight > 0) ? Float(pixelHeight) / Float(windowHeight) : 1.0

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
        SDL_RenderClear(renderer)

        let spritesToRender = spriteManager.getSpritesForRendering()
        let primitivesToRender = geometryManager.getPrimitivesForRendering()

        var sIdx = 0
        var pIdx = 0

        let transform = CameraTransform(
            camX: self.cameraOffset.x,
            camY: self.cameraOffset.y,
            camZoom: self.cameraZoom,
            camSin: sin(-self.cameraRotation),
            camCos: cos(-self.cameraRotation),
            screenCenterX: Double(self.windowWidth) / 2.0,
            screenCenterY: Double(self.windowHeight) / 2.0
        )

        while sIdx < spritesToRender.count || pIdx < primitivesToRender.count {
            let spriteZ =
                (sIdx < spritesToRender.count) ? spritesToRender[sIdx].position.z : Double.infinity
            let primitiveZ =
                (pIdx < primitivesToRender.count) ? primitivesToRender[pIdx].z : Double.infinity

            if spriteZ <= primitiveZ {
                renderSprite(spritesToRender[sIdx], deltaSec: deltaSec, cam: transform)
                sIdx += 1
            } else {
                renderPrimitive(primitivesToRender[pIdx], cam: transform)
                pIdx += 1
            }
        }

        self.physicsManager.debugDraw(
            renderer: renderer,
            camX: self.cameraOffset.x,
            camY: self.cameraOffset.y,
            camZoom: self.cameraZoom,
            screenW: Double(self.windowWidth),
            screenH: Double(self.windowHeight)
        )

        // Finalize the ImGui frame. This compiles all the ImGuiButton/Window calls
        // that happened during processCommands() into draw lists.
        ImGuiRender()

        // Actually draw the lists to the SDL renderer
        renderImGuiDrawData()

        SDL_RenderPresent(renderer)
    }

    private func renderPrimitive(_ primitive: RenderPrimitive, cam: CameraTransform) {
        SDL_SetRenderDrawColor(
            renderer, primitive.color.r, primitive.color.g, primitive.color.b, primitive.color.a)

        let color = SDL_FColor(
            r: Float(primitive.color.r) / 255.0,
            g: Float(primitive.color.g) / 255.0,
            b: Float(primitive.color.b) / 255.0,
            a: Float(primitive.color.a) / 255.0)
        let tex_coord = SDL_FPoint(x: 0, y: 0)

        func renderTransformedRect(_ r: SDL_FRect, isFilled: Bool) {
            let x1 = Double(r.x)
            let y1 = Double(r.y)
            let x2 = Double(r.x + r.w)
            let y2 = Double(r.y + r.h)

            let s1 = transformWorldToScreen(worldX: x1, worldY: y1, cam: cam)
            let s2 = transformWorldToScreen(worldX: x2, worldY: y1, cam: cam)
            let s3 = transformWorldToScreen(worldX: x2, worldY: y2, cam: cam)
            let s4 = transformWorldToScreen(worldX: x1, worldY: y2, cam: cam)

            var vertices = [
                SDL_Vertex(position: s1, color: color, tex_coord: tex_coord),
                SDL_Vertex(position: s2, color: color, tex_coord: tex_coord),
                SDL_Vertex(position: s3, color: color, tex_coord: tex_coord),
                SDL_Vertex(position: s4, color: color, tex_coord: tex_coord),
            ]

            if isFilled {
                var indices: [CInt] = [0, 1, 2, 0, 2, 3]
                SDL_RenderGeometry(renderer, nil, &vertices, 4, &indices, 6)
            } else {
                var linePoints = [s1, s2, s3, s4, s1]
                SDL_RenderLines(renderer, &linePoints, 5)
            }
        }

        func renderScreenRect(_ r: SDL_FRect, isFilled: Bool) {
            var rect = r
            if isFilled {
                SDL_RenderFillRect(renderer, &rect)
            } else {
                SDL_RenderRect(renderer, &rect)
            }
        }

        switch primitive.type {
        case .point:
            if let p = primitive.points.first {
                let sp: SDL_FPoint
                if primitive.isScreenSpace {
                    sp = p
                } else {
                    sp = transformWorldToScreen(
                        worldX: Double(p.x), worldY: Double(p.y), cam: cam)
                }
                SDL_RenderPoint(renderer, sp.x, sp.y)
            }
        case .line:
            if primitive.points.count >= 2 {
                let p1 = primitive.points[0]
                let p2 = primitive.points[1]
                let sp1: SDL_FPoint
                let sp2: SDL_FPoint
                if primitive.isScreenSpace {
                    sp1 = p1
                    sp2 = p2
                } else {
                    sp1 = transformWorldToScreen(
                        worldX: Double(p1.x), worldY: Double(p1.y), cam: cam)
                    sp2 = transformWorldToScreen(
                        worldX: Double(p2.x), worldY: Double(p2.y), cam: cam)
                }
                SDL_RenderLine(renderer, sp1.x, sp1.y, sp2.x, sp2.y)
            }

        case .rect:
            if let r = primitive.rects.first {
                if primitive.isScreenSpace {
                    renderScreenRect(r, isFilled: false)
                } else {
                    renderTransformedRect(r, isFilled: false)
                }
            }
        case .fillRect:
            if let r = primitive.rects.first {
                if primitive.isScreenSpace {
                    renderScreenRect(r, isFilled: true)
                } else {
                    renderTransformedRect(r, isFilled: true)
                }
            }

        case .points:
            var offsetPoints: [SDL_FPoint]
            if primitive.isScreenSpace {
                offsetPoints = primitive.points
            } else {
                offsetPoints = primitive.points.map {
                    transformWorldToScreen(
                        worldX: Double($0.x), worldY: Double($0.y), cam: cam)
                }
            }
            if !offsetPoints.isEmpty {
                SDL_RenderPoints(renderer, &offsetPoints, Int32(offsetPoints.count))
            }

        case .lines:
            var offsetPoints: [SDL_FPoint]
            if primitive.isScreenSpace {
                offsetPoints = primitive.points
            } else {
                offsetPoints = primitive.points.map {
                    transformWorldToScreen(
                        worldX: Double($0.x), worldY: Double($0.y), cam: cam)
                }
            }
            if !offsetPoints.isEmpty {
                SDL_RenderLines(renderer, &offsetPoints, Int32(offsetPoints.count))
            }

        case .rects:
            if !primitive.rects.isEmpty {
                if primitive.isScreenSpace {
                    for r in primitive.rects { renderScreenRect(r, isFilled: false) }
                } else {
                    for r in primitive.rects { renderTransformedRect(r, isFilled: false) }
                }
            }

        case .fillRects:
            if !primitive.rects.isEmpty {
                if primitive.isScreenSpace {
                    for r in primitive.rects { renderScreenRect(r, isFilled: true) }
                } else {
                    for r in primitive.rects { renderTransformedRect(r, isFilled: true) }
                }
            }

        case .polygon:
            // Filled polygon using SDL_RenderGeometry
            if !primitive.vertices.isEmpty && !primitive.indices.isEmpty {
                var vertices = primitive.vertices
                var indices = primitive.indices

                // Transform vertices if not screen-space
                if !primitive.isScreenSpace {
                    vertices = primitive.vertices.map { vtx in
                        let screenPos = transformWorldToScreen(
                            worldX: Double(vtx.position.x),
                            worldY: Double(vtx.position.y),
                            cam: cam
                        )
                        return SDL_Vertex(
                            position: screenPos,
                            color: vtx.color,
                            tex_coord: vtx.tex_coord
                        )
                    }
                }

                SDL_RenderGeometry(
                    renderer,
                    nil,  // No texture
                    &vertices,
                    Int32(vertices.count),
                    &indices,
                    Int32(indices.count)
                )
            }

        case .polygonOutline:
            // Polygon outline using SDL_RenderLines
            SDL_SetRenderDrawColor(
                renderer,
                primitive.color.r,
                primitive.color.g,
                primitive.color.b,
                primitive.color.a
            )

            var offsetPoints: [SDL_FPoint]
            if primitive.isScreenSpace {
                offsetPoints = primitive.points
            } else {
                offsetPoints = primitive.points.map {
                    transformWorldToScreen(
                        worldX: Double($0.x),
                        worldY: Double($0.y),
                        cam: cam
                    )
                }
            }

            if !offsetPoints.isEmpty {
                SDL_RenderLines(renderer, &offsetPoints, Int32(offsetPoints.count))
            }
        }
    }

    private func renderSprite(_ sprite: Sprite, deltaSec: Double, cam: CameraTransform) {
        if pluginOn { spriteManager.plugin(for: sprite.id, dt: deltaSec) }

        let totalAngle = sprite.rotate.z + (-self.cameraRotation * 180.0 / .pi)
        let isScaled = (sprite.scale.x != 1.0 || sprite.scale.y != 1.0)
        let isRotated = (totalAngle != 0.0)

        // 1. Calculate Screen Coordinates of the Center (Physics Body Position)
        let screenPos = transformWorldToScreen(
            worldX: sprite.position.x, worldY: sprite.position.y, cam: cam)

        let scaledW = sprite.size.x * sprite.scale.x * cam.camZoom
        let scaledH = sprite.size.y * sprite.scale.y * cam.camZoom

        // 2. Adjust Drawing Coordinates to Top-Left
        // SDL draws from Top-Left, but our sprite.position is now the Center.
        // We calculate the top-left offset here.
        let destX = screenPos.x - Float(scaledW / 2.0)
        let destY = screenPos.y - Float(scaledH / 2.0)

        if !isScaled && !isRotated {
            // Use adjusted destX/destY
            var rect = SDL_FRect(
                x: destX, y: destY, w: Float(scaledW), h: Float(scaledH))

            if let texture = sprite.texture {
                SDL_SetTextureColorMod(texture, sprite.color.r, sprite.color.g, sprite.color.b)
                if var srcRect = sprite.sourceRect {
                    SDL_RenderTexture(renderer, texture, &srcRect, &rect)
                } else {
                    SDL_RenderTexture(renderer, texture, nil, &rect)
                }
            } else {
                SDL_SetRenderDrawColor(
                    renderer, sprite.color.r, sprite.color.g, sprite.color.b, sprite.color.a)
                SDL_RenderFillRect(renderer, &rect)
            }
        } else {
            if let texture = sprite.texture {
                // Use adjusted destX/destY
                var rect = SDL_FRect(
                    x: destX, y: destY, w: Float(scaledW), h: Float(scaledH))

                // The center point for rotation is relative to the rect's x,y.
                // Since x,y is Top-Left, the center of rotation is exactly half w/h.
                var center = SDL_FPoint(x: Float(scaledW / 2.0), y: Float(scaledH / 2.0))

                SDL_SetTextureColorMod(texture, sprite.color.r, sprite.color.g, sprite.color.b)
                if var srcRect = sprite.sourceRect {
                    SDL_RenderTextureRotated(
                        renderer, texture, &srcRect, &rect, totalAngle, &center, SDL_FLIP_NONE)
                } else {
                    SDL_RenderTextureRotated(
                        renderer, texture, nil, &rect, totalAngle, &center, SDL_FLIP_NONE)
                }
            } else {
                // Manual geometry rendering (Vertex Fan)
                // This logic needs to assume sprite.position is CENTER.
                let w = sprite.size.x * sprite.scale.x
                let h = sprite.size.y * sprite.scale.y
                let angleRad = sprite.rotate.z * .pi / 180.0
                let s = sin(angleRad)
                let c = cos(angleRad)
                let half_w = w / 2.0
                let half_h = h / 2.0

                // FIX: pivotX/Y is now just the position, because position IS the center.
                // (Previous code added half_w because it assumed position was top-left)
                let pivotX = sprite.position.x
                let pivotY = sprite.position.y

                // Calculate corners relative to center pivot
                let p1x = pivotX + (-half_w * c - -half_h * s)
                let p1y = pivotY + (-half_w * s + -half_h * c)
                let p2x = pivotX + (half_w * c - -half_h * s)
                let p2y = pivotY + (half_w * s + -half_h * c)
                let p3x = pivotX + (half_w * c - half_h * s)
                let p3y = pivotY + (half_w * s + half_h * c)
                let p4x = pivotX + (-half_w * c - half_h * s)
                let p4y = pivotY + (-half_w * s + half_h * c)

                let s1 = transformWorldToScreen(worldX: Double(p1x), worldY: Double(p1y), cam: cam)
                let s2 = transformWorldToScreen(worldX: Double(p2x), worldY: Double(p2y), cam: cam)
                let s3 = transformWorldToScreen(worldX: Double(p3x), worldY: Double(p3y), cam: cam)
                let s4 = transformWorldToScreen(worldX: Double(p4x), worldY: Double(p4y), cam: cam)

                let color = SDL_FColor(
                    r: Float(sprite.color.r) / 255.0, g: Float(sprite.color.g) / 255.0,
                    b: Float(sprite.color.b) / 255.0, a: Float(sprite.color.a) / 255.0
                )
                let tex_coord = SDL_FPoint(x: 0.0, y: 0.0)
                var vertices = [
                    SDL_Vertex(position: s1, color: color, tex_coord: tex_coord),
                    SDL_Vertex(position: s2, color: color, tex_coord: tex_coord),
                    SDL_Vertex(position: s3, color: color, tex_coord: tex_coord),
                    SDL_Vertex(position: s4, color: color, tex_coord: tex_coord),
                ]
                var indices: [CInt] = [0, 1, 2, 2, 3, 0]
                SDL_RenderGeometry(renderer, nil, &vertices, 4, &indices, 6)
            }
        }
    }

    private struct CameraTransform {
        let camX: Double
        let camY: Double
        let camZoom: Double
        let camSin: Double
        let camCos: Double
        let screenCenterX: Double
        let screenCenterY: Double
    }

    private func transformWorldToScreen(worldX: Double, worldY: Double, cam: CameraTransform)
        -> SDL_FPoint
    {
        let relX = worldX - cam.camX
        let relY = worldY - cam.camY
        let rotX = (relX * cam.camCos) - (relY * cam.camSin)
        let rotY = (relX * cam.camSin) + (relY * cam.camCos)
        let zoomX = rotX * cam.camZoom
        let zoomY = rotY * cam.camZoom
        return SDL_FPoint(x: Float(zoomX + cam.screenCenterX), y: Float(zoomY + cam.screenCenterY))
    }

    internal func renderFilledPolygon(
        _ primitive: RenderPrimitive,
        cam: (
            camX: Double, camY: Double, camZoom: Double, camSin: Double, camCos: Double,
            screenCenterX: Double, screenCenterY: Double
        )
    ) {
        guard !primitive.vertices.isEmpty && !primitive.indices.isEmpty else { return }

        var vertices: [SDL_Vertex]

        if primitive.isScreenSpace {
            vertices = primitive.vertices
        } else {
            // Transform world coordinates to screen coordinates
            vertices = primitive.vertices.map { vtx in
                let worldX = Double(vtx.position.x)
                let worldY = Double(vtx.position.y)

                // Apply camera transform
                let relX = worldX - cam.camX
                let relY = worldY - cam.camY
                let rotX = (relX * cam.camCos) - (relY * cam.camSin)
                let rotY = (relX * cam.camSin) + (relY * cam.camCos)
                let zoomX = rotX * cam.camZoom
                let zoomY = rotY * cam.camZoom

                let screenPos = SDL_FPoint(
                    x: Float(zoomX + cam.screenCenterX),
                    y: Float(zoomY + cam.screenCenterY)
                )

                return SDL_Vertex(
                    position: screenPos,
                    color: vtx.color,
                    tex_coord: vtx.tex_coord
                )
            }
        }

        var indices = primitive.indices

        SDL_RenderGeometry(
            renderer,
            nil,  // No texture for solid color
            &vertices,
            Int32(vertices.count),
            &indices,
            Int32(indices.count)
        )
    }

    /// Renders a polygon outline using SDL_RenderLines
    internal func renderPolygonOutline(
        _ primitive: RenderPrimitive,
        cam: (
            camX: Double, camY: Double, camZoom: Double, camSin: Double, camCos: Double,
            screenCenterX: Double, screenCenterY: Double
        )
    ) {
        guard !primitive.points.isEmpty else { return }

        SDL_SetRenderDrawColor(
            renderer,
            primitive.color.r,
            primitive.color.g,
            primitive.color.b,
            primitive.color.a
        )

        var screenPoints: [SDL_FPoint]

        if primitive.isScreenSpace {
            screenPoints = primitive.points
        } else {
            screenPoints = primitive.points.map { pt in
                let worldX = Double(pt.x)
                let worldY = Double(pt.y)

                let relX = worldX - cam.camX
                let relY = worldY - cam.camY
                let rotX = (relX * cam.camCos) - (relY * cam.camSin)
                let rotY = (relX * cam.camSin) + (relY * cam.camCos)
                let zoomX = rotX * cam.camZoom
                let zoomY = rotY * cam.camZoom

                return SDL_FPoint(
                    x: Float(zoomX + cam.screenCenterX),
                    y: Float(zoomY + cam.screenCenterY)
                )
            }
        }

        SDL_RenderLines(renderer, &screenPoints, Int32(screenPoints.count))
    }
}
