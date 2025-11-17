import CMiniaudio
import Foundation
import ImGui
import SwiftSDL
import SwiftSDL_image
// import SwiftSDL_mixer
import SwiftSDL_ttf

extension PhrostEngine {

    // MARK: - Main Loop
    public func run(updateCallback: @escaping (Int, Double, Data) -> Data) {
        var frameCount: Int = 0
        var lastTick: UInt64 = SDL_GetTicks()
        let targetMs: Double = 1000.0 / 60.0

        // --- Main Loop ---
        while self.running {
            let frameStart: UInt64 = SDL_GetTicks()

            let now = SDL_GetTicks()
            let deltaMs = Double(now &- lastTick)
            let deltaSec = deltaMs / 1000.0

            // 1. Poll SDL Events
            let (sdlEventStream, sdlEventCount) = pollEvents()

            // 2. Prepare initial event payloads (SDL + Last Frame's Internal)
            var currentEventPayloads = Data()
            let initialEventCount = sdlEventCount + self.internalEventCount

            if initialEventCount > 0 {
                currentEventPayloads.append(sdlEventStream)
                currentEventPayloads.append(self.internalEventStream)
            }

            // 3. Clear the *next* frame's event stream.
            self.internalEventStream.removeAll()
            self.internalEventCount = 0

            // 4. Step and Get Physics Events
            self.physicsManager.step(dt: deltaSec)
            let (physicsEvents, physicsEventCount) = self.physicsManager.drainGeneratedEvents()

            // NEW: Accumulator for all C-Plugin outputs for THIS frame
            var allCPluginChannelOutputs: [UInt32: Data] = [:]

            // =========================================================================
            // 5. Call C-Plugin Update (Pass 1) - *** NEW CHANNEL LOGIC ***
            // =========================================================================

            // Base events (SDL, Internal, Physics) - all plugins get these
            var baseEvents = Data()
            let baseEventCount = initialEventCount + physicsEventCount
            if baseEventCount > 0 {
                baseEvents.append(currentEventPayloads)  // SDL + Internal
                baseEvents.append(physicsEvents)
            }

            // Collect all output from C-Plugins (for PHP)
            // DEPRECATED:
            // var allCPluginGeneratedEvents = Data()
            // var allCPluginGeneratedEventCount: UInt32 = 0

            let sortedPluginIDs = self.loadedPlugins.keys.sorted()

            // Get channel data from *last frame's* PHP run
            let channelsForPlugins = self.pluginChannelData
            // Clear the buffer for *this frame's* PHP run
            self.pluginChannelData.removeAll()

            for pluginID in sortedPluginIDs {
                guard let plugin = self.loadedPlugins[pluginID] else { continue }

                // --- 5a. Build this plugin's custom event blob ---
                var pluginInputStream = Data()
                var pluginInputEventCount = baseEventCount

                // Add base events
                pluginInputStream.append(baseEvents)

                // Add subscribed channels (if any)
                if let subscriptions = self.pluginSubscriptions[pluginID] {
                    for channelId in subscriptions {
                        // We filter for non-zero channels. Channel 0 is processed
                        // by the engine and C-Plugins subscribe to it by default
                        // via the baseEvents stream.
                        if channelId == 0 { continue }

                        if let channelData = channelsForPlugins[channelId] {
                            // channelData is a *flat blob* of [count][events...]
                            // We need to unpack it to get the count
                            var subOffset = 0
                            guard
                                let subCount = unpack(
                                    data: channelData, offset: &subOffset, label: "SubCount",
                                    as: UInt32.self)
                            else {
                                print("Plugin \(pluginID) channel \(channelId) blob was corrupt.")
                                continue
                            }
                            pluginInputEventCount &+= subCount
                            // Append only the events, not the count
                            pluginInputStream.append(
                                channelData.subdata(in: subOffset..<channelData.count))
                        }
                    }
                }

                // --- 5b. Finalize blob with total count ---
                var finalPluginBlob = Data()
                if pluginInputEventCount > 0 {
                    finalPluginBlob.append(value: pluginInputEventCount)
                    finalPluginBlob.append(pluginInputStream)
                }

                // --- 5c. Call plugin ---
                let updateFunc = plugin.updateFunc
                let freeFunc = plugin.freeFunc
                var cPluginCommandData = Data()

                let (eventsPtr, eventsLen) = finalPluginBlob.withUnsafeBytes {
                    buffer -> (UnsafeRawPointer?, Int32) in
                    let ptr = buffer.baseAddress
                    let len = Int32(buffer.count)
                    return (ptr, len)
                }

                var cResultLength: Int32 = 0
                let cResultDataPtr = updateFunc(
                    now,
                    deltaSec,
                    eventsPtr,
                    eventsLen,
                    &cResultLength
                )

                if let dataPtr = cResultDataPtr, cResultLength > 0 {
                    let boundPtr = dataPtr.assumingMemoryBound(to: UInt8.self)
                    cPluginCommandData = Data(bytes: boundPtr, count: Int(cResultLength))
                }
                freeFunc(cResultDataPtr)

                // --- 5d. Process plugin's *output* (NEW CHANNEL-AWARE) ---
                // We now assume cPluginCommandData is a channel-packed blob.
                var cOffset = 0
                guard !cPluginCommandData.isEmpty else { continue }  // No output

                // Local unpacker for C plugin data
                func cUnpack<T>(label: String, as type: T.Type) -> T? {
                    return unpack(
                        data: cPluginCommandData, offset: &cOffset, label: label, as: type)
                }

                guard let cChannelCount = cUnpack(label: "C_ChannelCount", as: UInt32.self)
                else {
                    print("Plugin \(pluginID) Error: Failed to read C-channel count.")
                    continue
                }

                var cChannelIndex: [(id: UInt32, size: UInt32)] = []
                for i in 0..<cChannelCount {
                    guard let id = cUnpack(label: "C_ChannelID", as: UInt32.self),
                        let size = cUnpack(label: "C_ChannelSize", as: UInt32.self)
                    else {
                        print("Plugin \(pluginID) Error: Failed to read C-channel index \(i).")
                        break
                    }
                    cChannelIndex.append((id: id, size: size))
                }

                // --- 5e. Extract & Accumulate Channel Data Blobs from C-Plugin ---
                for entry in cChannelIndex {
                    let cChannelEnd = cOffset + Int(entry.size)
                    guard cChannelEnd <= cPluginCommandData.count else {
                        print(
                            "Plugin \(pluginID) Error: Channel \(entry.id) size mismatch."
                        )
                        break
                    }
                    let cChannelBlob = cPluginCommandData.subdata(in: cOffset..<cChannelEnd)
                    cOffset = cChannelEnd

                    // We must MERGE blobs if multiple plugins output to the same channel.
                    // A "blob" is [count][events...].
                    if var existingBlob = allCPluginChannelOutputs[entry.id] {
                        // --- Merge ---
                        var subOffset = 0
                        guard
                            let subCount = unpack(
                                data: cChannelBlob, offset: &subOffset, label: "SubCount",
                                as: UInt32.self), subCount > 0
                        else { continue }
                        let subEvents = cChannelBlob.subdata(
                            in: subOffset..<cChannelBlob.count)

                        var existingOffset = 0
                        guard
                            let existingCount = unpack(
                                data: existingBlob, offset: &existingOffset,
                                label: "ExCount", as: UInt32.self)
                        else { continue }
                        let existingEvents = existingBlob.subdata(
                            in: existingOffset..<existingBlob.count)

                        let newTotalCount = existingCount &+ subCount
                        var newBlob = Data(
                            capacity: MemoryLayout<UInt32>.stride + existingEvents.count
                                + subEvents.count)
                        newBlob.append(value: newTotalCount)
                        newBlob.append(existingEvents)
                        newBlob.append(subEvents)
                        allCPluginChannelOutputs[entry.id] = newBlob
                    } else {
                        // --- New Entry ---
                        // Don't add empty blobs
                        var subOffset = 0
                        if let subCount = unpack(
                            data: cChannelBlob, offset: &subOffset, label: "SubCount",
                            as: UInt32.self), subCount > 0
                        {
                            allCPluginChannelOutputs[entry.id] = cChannelBlob
                        }
                    }
                }
            }  // --- End C-Plugin loop ---

            // =========================================================================
            // 6. Call User Update Logic (PHP) (Pass 2)
            // =========================================================================

            // Input to PHP is (Base Events) + (C-Plugin Output, filtered for PHP's channels)
            var eventsForPHP = Data()
            var phpInputStream = Data()
            var phpInputEventCount = baseEventCount

            // Add base events
            phpInputStream.append(baseEvents)

            // *** MODIFIED ***
            // Use the persistent, mutable property from the Engine class
            let phpSubscribedChannels = self.phpSubscribedChannels

            // Add filtered C-Plugin outputs
            for (channelId, channelBlob) in allCPluginChannelOutputs {
                if phpSubscribedChannels.contains(channelId) {
                    // This blob is [count][events...]. Unpack to add to total.
                    var subOffset = 0
                    guard
                        let subCount = unpack(
                            data: channelBlob, offset: &subOffset,
                            label: "PHP_SubCount", as: UInt32.self)
                    else {
                        print(
                            "PHP Input Error: Corrupt C-plugin blob for channel \(channelId)."
                        )
                        continue
                    }
                    if subCount > 0 {
                        phpInputEventCount &+= subCount
                        // Append *only the events*, not the count
                        phpInputStream.append(
                            channelBlob.subdata(in: subOffset..<channelBlob.count))
                    }
                }
            }

            if phpInputEventCount > 0 {
                eventsForPHP.append(value: phpInputEventCount)
                eventsForPHP.append(phpInputStream)
            }

            // Call PHP
            lastTick = now
            let phpCommandData = updateCallback(
                frameCount, deltaSec, eventsForPHP)

            // =========================================================================
            // 7. Process Channel-Packed Commands from PHP
            // =========================================================================

            var offset = 0
            guard !phpCommandData.isEmpty else {
                // ... (rest of loop: physics sync, render, etc.) ...
                self.physicsManager.syncPhysicsToSprites()
                render(deltaSec: deltaSec)
                // ... (frame limiting) ...
                let frameWorkEnd = SDL_GetTicks()
                let frameTime = Double(frameWorkEnd &- frameStart)
                let sleepMs = targetMs - frameTime
                if sleepMs > 0 { SDL_Delay(UInt32(sleepMs)) }
                frameCount &+= 1
                continue  // Skip to next loop
            }

            // Local unpack helper
            func phpUnpack<T>(label: String, as type: T.Type) -> T? {
                return unpack(data: phpCommandData, offset: &offset, label: label, as: type)
            }

            // --- 7a. Unpack Channel Header ---
            guard let channelCount = phpUnpack(label: "ChannelCount", as: UInt32.self) else {
                print("PHP Command Error: Failed to read channel count.")
                continue
            }

            var channelIndex: [(id: UInt32, size: UInt32)] = []

            // --- 7b. Unpack Index Table ---
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

            // --- 7c. Extract & Process Channel Data Blobs ---

            // 1. Clear and prep the plugin channel data for the *next* frame.
            // Start with all C-Plugin outputs. This ensures Channel 8 (etc.) persists.
            self.pluginChannelData = allCPluginChannelOutputs

            // 2. Process PHP's output, merging/overwriting plugin data
            for entry in channelIndex {
                let channelEnd = offset + Int(entry.size)
                guard channelEnd <= phpCommandData.count else {
                    print(
                        "PHP Command Error: Channel \(entry.id) size (\(entry.size)) exceeds data blob."
                    )
                    break
                }
                let phpChannelBlob = phpCommandData.subdata(in: offset..<channelEnd)
                offset = channelEnd

                // Store/Overwrite PHP's output into the map for the next frame.
                // PHP's output always takes precedence over C-plugin output.
                // We will use complex merge logic to be safe.
                if var existingBlob = self.pluginChannelData[entry.id] {
                    // --- Merge ---
                    var subOffset = 0
                    guard
                        let subCount = unpack(
                            data: phpChannelBlob, offset: &subOffset,
                            label: "PHP_SubCount", as: UInt32.self), subCount > 0
                    else { continue }
                    let subEvents = phpChannelBlob.subdata(
                        in: subOffset..<phpChannelBlob.count)

                    var existingOffset = 0
                    guard
                        let existingCount = unpack(
                            data: existingBlob, offset: &existingOffset,
                            label: "ExCount", as: UInt32.self)
                    else { continue }
                    let existingEvents = existingBlob.subdata(
                        in: existingOffset..<existingBlob.count)

                    let newTotalCount = existingCount &+ subCount
                    var newBlob = Data(
                        capacity: MemoryLayout<UInt32>.stride + existingEvents.count
                            + subEvents.count)
                    newBlob.append(value: newTotalCount)
                    newBlob.append(existingEvents)
                    newBlob.append(subEvents)
                    self.pluginChannelData[entry.id] = newBlob
                } else {
                    // --- New Entry ---
                    var subOffset = 0
                    if let subCount = unpack(
                        data: phpChannelBlob, offset: &subOffset,
                        label: "PHP_SubCount", as: UInt32.self), subCount > 0
                    {
                        self.pluginChannelData[entry.id] = phpChannelBlob
                    }
                }
            }

            // 3. NOW, process all ENGINE commands (0, 2) from the final merged map
            var phpGeneratedEvents = Data()  // Feedback events from processing
            var phpGeneratedEventCount: UInt32 = 0

            if let rendererBlob = self.pluginChannelData[0] {  // Channel 0
                let (events, count) = processCommands(rendererBlob)
                phpGeneratedEvents.append(events)
                phpGeneratedEventCount &+= count
            }
            if let physicsBlob = self.pluginChannelData[2] {  // Channel 2
                let (events, count) = processCommands(physicsBlob)
                phpGeneratedEvents.append(events)
                phpGeneratedEventCount &+= count
            }
            // NOTE: We don't process channel 6 here, as it's not an "engine" channel
            // We just let it get passed to C-plugins (if any subscribe)

            // 4. Remove engine channels from the "next frame" plugin data
            // so C-plugins don't get engine commands fed back to them.
            self.pluginChannelData.removeValue(forKey: 0)
            self.pluginChannelData.removeValue(forKey: 2)

            // =========================================================================
            // 8. Finalize Internal Event Stream for *Next* Frame
            // =========================================================================

            // "Event stacking" of commands is no more.
            // The *only* events that persist to the next frame are the
            // *feedback events* (e.g., textureLoaded, physicsCollision)
            // generated by processCommands (from Channels 0 & 2).

            self.internalEventStream.removeAll()  // Clear old
            self.internalEventCount = 0

            // ALWAYS append the *newly generated feedback* events.
            self.internalEventStream.append(phpGeneratedEvents)
            self.internalEventCount = phpGeneratedEventCount

            // 9. Sync Physics to Sprites
            self.physicsManager.syncPhysicsToSprites()

            // 10. Render
            render(deltaSec: deltaSec)

            // 11. Frame Limiting
            let frameWorkEnd = SDL_GetTicks()
            let frameTime = Double(frameWorkEnd &- frameStart)
            let sleepMs = targetMs - frameTime
            if sleepMs > 0 { SDL_Delay(UInt32(sleepMs)) }
            frameCount &+= 1

        }  // --- End Main Loop ---
    }

    public func stop() {
        self.running = false
    }

    // MARK: - Event Polling
    /// Polls for SDL events and packs them into a Data buffer.
    internal func pollEvents() -> (eventStream: Data, eventCount: UInt32) {
        var eventStream = Data()
        var eventCount: UInt32 = 0
        var e = SDL_Event()

        while SDL_PollEvent(&e) {
            let timestamp = e.common.timestamp

            let handledByImGui = processImGuiInput(event: &e)

            switch e.type {
            case UInt32(SDL_EVENT_QUIT.rawValue):
                self.running = false
                continue
            case UInt32(SDL_EVENT_WINDOW_RESIZED.rawValue):
                let resizeEvent = PackedWindowResizeEvent(w: e.window.data1, h: e.window.data2)
                eventStream.append(value: Events.windowResize.rawValue)
                eventStream.append(value: timestamp)
                eventStream.append(value: resizeEvent)
                eventCount += 1
            case UInt32(SDL_EVENT_KEY_DOWN.rawValue):
                let keyEvent = PackedKeyEvent(
                    scancode: Int32(e.key.scancode.rawValue), keycode: e.key.key, mod: e.key.mod,
                    isRepeat: e.key.repeat ? 1 : 0, _padding: 0)
                eventStream.append(value: Events.inputKeydown.rawValue)
                eventStream.append(value: timestamp)
                eventStream.append(value: keyEvent)
                eventCount += 1
            case UInt32(SDL_EVENT_KEY_UP.rawValue):
                let keyEvent = PackedKeyEvent(
                    scancode: Int32(e.key.scancode.rawValue), keycode: e.key.key, mod: e.key.mod,
                    isRepeat: 0, _padding: 0)
                eventStream.append(value: Events.inputKeyup.rawValue)
                eventStream.append(value: timestamp)
                eventStream.append(value: keyEvent)
                eventCount += 1
            case UInt32(SDL_EVENT_MOUSE_MOTION.rawValue):
                let motionEvent = PackedMouseMotionEvent(
                    x: e.motion.x, y: e.motion.y, xrel: e.motion.xrel, yrel: e.motion.yrel)
                eventStream.append(value: Events.inputMousemotion.rawValue)
                eventStream.append(value: timestamp)
                eventStream.append(value: motionEvent)
                eventCount += 1
            case UInt32(SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue):
                let buttonEvent = PackedMouseButtonEvent(
                    x: e.button.x, y: e.button.y, button: e.button.button, clicks: e.button.clicks,
                    _padding: 0)
                eventStream.append(value: Events.inputMousedown.rawValue)
                eventStream.append(value: timestamp)
                eventStream.append(value: buttonEvent)
                eventCount += 1
            case UInt32(SDL_EVENT_MOUSE_BUTTON_UP.rawValue):
                let buttonEvent = PackedMouseButtonEvent(
                    x: e.button.x, y: e.button.y, button: e.button.button, clicks: e.button.clicks,
                    _padding: 0)
                eventStream.append(value: Events.inputMouseup.rawValue)
                eventStream.append(value: timestamp)
                eventStream.append(value: buttonEvent)
                eventCount += 1
            default: continue
            }
        }
        return (eventStream, eventCount)
    }

    // MARK: - Rendering
    /// Renders all geometry and sprites in a single, Z-sorted pass.
    internal func render(deltaSec: Double) {
        SDL_GetWindowSize(window, &windowWidth, &windowHeight)
        SDL_GetWindowSizeInPixels(window, &pixelWidth, &pixelHeight)
        scaleX = (windowWidth > 0) ? Float(pixelWidth) / Float(windowWidth) : 1.0
        scaleY = (windowHeight > 0) ? Float(pixelHeight) / Float(windowHeight) : 1.0

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
        SDL_RenderClear(renderer)

        // --- Z-SORTED RENDER ---
        // Get the sorted lists from each manager
        let spritesToRender = spriteManager.getSpritesForRendering()
        let primitivesToRender = geometryManager.getPrimitivesForRendering()

        // Perform a Z-sorted merge-render
        var sIdx = 0  // Sprite Index
        var pIdx = 0  // Primitive Index

        // Pre-calculate all camera transform values once per frame
        let transform = CameraTransform(
            camX: self.cameraOffset.x,
            camY: self.cameraOffset.y,
            camZoom: self.cameraZoom,
            camSin: sin(-self.cameraRotation),  // Use negative rotation
            camCos: cos(-self.cameraRotation),
            screenCenterX: Double(self.windowWidth) / 2.0,
            screenCenterY: Double(self.windowHeight) / 2.0
        )

        while sIdx < spritesToRender.count || pIdx < primitivesToRender.count {
            // Get Z for sprite, or infinity if no sprites are left
            let spriteZ =
                (sIdx < spritesToRender.count)
                ? spritesToRender[sIdx].position.2 : Double.infinity

            // Get Z for primitive, or infinity if no primitives are left
            let primitiveZ =
                (pIdx < primitivesToRender.count) ? primitivesToRender[pIdx].z : Double.infinity

            if spriteZ <= primitiveZ {
                // Render the sprite
                renderSprite(spritesToRender[sIdx], deltaSec: deltaSec, cam: transform)
                sIdx += 1
            } else {
                // Render the primitive
                renderPrimitive(primitivesToRender[pIdx], cam: transform)
                pIdx += 1
            }
        }

        io.pointee.DisplaySize = ImVec2(x: Float(windowWidth), y: Float(windowHeight))
        io.pointee.DisplayFramebufferScale = ImVec2(x: scaleX, y: scaleY)
        io.pointee.DeltaTime = Float(deltaSec)
        io.pointee.FontGlobalScale = scaleX

        ImGuiNewFrame()
        var f: Float = 0.0
        ImGuiTextV("Hello, world!")
        ImGuiSliderFloat("float", &f, 0.0, 1.0, nil, 1)
        ImGuiTextV(
            "Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.pointee.Framerate,
            io.pointee.Framerate)
        ImGuiShowDemoWindow(nil)
        ImGuiRender()

        // renderImGuiDrawData()

        SDL_RenderPresent(renderer)
    }

    /// Helper function to render a single primitive.
    private func renderPrimitive(_ primitive: RenderPrimitive, cam: CameraTransform) {
        SDL_SetRenderDrawColor(
            renderer, primitive.color.0, primitive.color.1, primitive.color.2,
            primitive.color.3)

        // Helper color for geometry
        let color = SDL_FColor(
            r: Float(primitive.color.0) / 255.0,
            g: Float(primitive.color.1) / 255.0,
            b: Float(primitive.color.2) / 255.0,
            a: Float(primitive.color.3) / 255.0)
        let tex_coord = SDL_FPoint(x: 0, y: 0)

        // --- RENDER HELPER: WORLD-SPACE (Transformed) ---
        func renderTransformedRect(_ r: SDL_FRect, isFilled: Bool) {
            // Get world-space corners
            let x1 = Double(r.x)
            let y1 = Double(r.y)
            let x2 = Double(r.x + r.w)
            let y2 = Double(r.y + r.h)

            // Transform corners
            let s1 = transformWorldToScreen(worldX: x1, worldY: y1, cam: cam)  // Top-left
            let s2 = transformWorldToScreen(worldX: x2, worldY: y1, cam: cam)  // Top-right
            let s3 = transformWorldToScreen(worldX: x2, worldY: y2, cam: cam)  // Bottom-right
            let s4 = transformWorldToScreen(worldX: x1, worldY: y2, cam: cam)  // Bottom-left

            // Define vertices
            var vertices = [
                SDL_Vertex(position: s1, color: color, tex_coord: tex_coord),
                SDL_Vertex(position: s2, color: color, tex_coord: tex_coord),
                SDL_Vertex(position: s3, color: color, tex_coord: tex_coord),
                SDL_Vertex(position: s4, color: color, tex_coord: tex_coord),
            ]

            if isFilled {
                // Draw as two triangles
                var indices: [CInt] = [0, 1, 2, 0, 2, 3]  // 0-1-2 and 0-2-3
                SDL_RenderGeometry(renderer, nil, &vertices, 4, &indices, 6)
            } else {
                // Draw as 4 connected lines.
                var linePoints = [s1, s2, s3, s4, s1]  // 5 points to make 4 closed lines
                SDL_RenderLines(renderer, &linePoints, 5)
            }
        }

        // --- RENDER HELPER: SCREEN-SPACE (Static UI) ---
        func renderScreenRect(_ r: SDL_FRect, isFilled: Bool) {
            var rect = r  // Make mutable copy
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
                    sp = p  // Use point as-is
                } else {
                    sp = transformWorldToScreen(worldX: Double(p.x), worldY: Double(p.y), cam: cam)
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
                    sp1 = p1  // Use points as-is
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
                    transformWorldToScreen(worldX: Double($0.x), worldY: Double($0.y), cam: cam)
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
                    transformWorldToScreen(worldX: Double($0.x), worldY: Double($0.y), cam: cam)
                }
            }
            if !offsetPoints.isEmpty {
                SDL_RenderLines(renderer, &offsetPoints, Int32(offsetPoints.count))
            }

        case .rects:
            if !primitive.rects.isEmpty {
                if primitive.isScreenSpace {
                    for r in primitive.rects {
                        renderScreenRect(r, isFilled: false)
                    }
                } else {
                    for r in primitive.rects {
                        renderTransformedRect(r, isFilled: false)
                    }
                }
            }

        case .fillRects:
            if !primitive.rects.isEmpty {
                if primitive.isScreenSpace {
                    for r in primitive.rects {
                        renderScreenRect(r, isFilled: true)
                    }
                } else {
                    for r in primitive.rects {
                        renderTransformedRect(r, isFilled: true)
                    }
                }
            }
        }
    }

    /// Helper function to render a single sprite.
    private func renderSprite(_ sprite: Sprite, deltaSec: Double, cam: CameraTransform) {
        if pluginOn {
            spriteManager.plugin(for: sprite.id, dt: deltaSec)
        }

        // Combine sprite rotation with the (negative) camera rotation
        // We convert camera's radians back to degrees for SDL's function
        let totalAngle = sprite.rotate.2 + (-self.cameraRotation * 180.0 / .pi)

        let isScaled = (sprite.scale.0 != 1.0 || sprite.scale.1 != 1.0)

        // The "Fast Path" is only valid if *both* the sprite AND camera are not rotated.
        let isRotated = (totalAngle != 0.0)

        // GET SCREEN POSITION
        // This is the sprite's (x,y) top-left corner, transformed by the camera
        let screenPos = transformWorldToScreen(
            worldX: sprite.position.0,
            worldY: sprite.position.1,
            cam: cam
        )

        // GET ZOOMED SIZE
        // Apply camera zoom to the sprite's final size
        let scaledW = sprite.size.0 * sprite.scale.0 * cam.camZoom
        let scaledH = sprite.size.1 * sprite.scale.1 * cam.camZoom

        if !isScaled && !isRotated {
            // --- FAST PATH (No rotation on sprite OR camera) ---
            var rect = SDL_FRect(
                x: screenPos.x,
                y: screenPos.y,
                w: Float(scaledW),  // Apply zoom
                h: Float(scaledH)  // Apply zoom
            )

            if let texture = sprite.texture {
                SDL_SetTextureColorMod(texture, sprite.color.0, sprite.color.1, sprite.color.2)

                if var srcRect = sprite.sourceRect {
                    SDL_RenderTexture(renderer, texture, &srcRect, &rect)
                } else {
                    SDL_RenderTexture(renderer, texture, nil, &rect)
                }

            } else {
                SDL_SetRenderDrawColor(
                    renderer, sprite.color.0, sprite.color.1, sprite.color.2, sprite.color.3)
                SDL_RenderFillRect(renderer, &rect)
            }
        } else {
            // --- SLOW PATH (Sprite or Camera is rotated/scaled) ---
            if let texture = sprite.texture {
                var rect = SDL_FRect(
                    x: screenPos.x,
                    y: screenPos.y,
                    w: Float(scaledW),  // Apply zoom
                    h: Float(scaledH)  // Apply zoom
                )
                // The center of rotation is relative to the *zoomed* size
                var center = SDL_FPoint(x: Float(scaledW / 2.0), y: Float(scaledH / 2.0))
                SDL_SetTextureColorMod(texture, sprite.color.0, sprite.color.1, sprite.color.2)

                if var srcRect = sprite.sourceRect {
                    SDL_RenderTextureRotated(
                        renderer, texture, &srcRect, &rect,
                        totalAngle,  // Use combined angle
                        &center, SDL_FLIP_NONE
                    )
                } else {
                    SDL_RenderTextureRotated(
                        renderer, texture, nil, &rect,
                        totalAngle,  // Use combined angle
                        &center, SDL_FLIP_NONE
                    )
                }

            } else {
                // --- SLOW PATH (Vertices for untextured, rotated/scaled rect) ---
                let w = sprite.size.0 * sprite.scale.0  // Base scaled size (no zoom)
                let h = sprite.size.1 * sprite.scale.1  // Base scaled size (no zoom)

                // Use *sprite's* angle only (in radians) for vertex calculation
                let angleRad = sprite.rotate.2 * .pi / 180.0
                let s = sin(angleRad)
                let c = cos(angleRad)
                let half_w = w / 2.0
                let half_h = h / 2.0

                // Pivot is in world space
                let pivotX = sprite.position.0 + half_w
                let pivotY = sprite.position.1 + half_h

                // Calculate vertices in *world space*
                let p1x = pivotX + (-half_w * c - -half_h * s)
                let p1y = pivotY + (-half_w * s + -half_h * c)
                let p2x = pivotX + (half_w * c - -half_h * s)
                let p2y = pivotY + (half_w * s + -half_h * c)
                let p3x = pivotX + (half_w * c - half_h * s)
                let p3y = pivotY + (half_w * s + half_h * c)
                let p4x = pivotX + (-half_w * c - half_h * s)
                let p4y = pivotY + (-half_w * s + half_h * c)

                // APPLY FULL TRANSFORM to each world vertex
                let s1 = transformWorldToScreen(worldX: Double(p1x), worldY: Double(p1y), cam: cam)
                let s2 = transformWorldToScreen(worldX: Double(p2x), worldY: Double(p2y), cam: cam)
                let s3 = transformWorldToScreen(worldX: Double(p3x), worldY: Double(p3y), cam: cam)
                let s4 = transformWorldToScreen(worldX: Double(p4x), worldY: Double(p4y), cam: cam)

                let color = SDL_FColor(
                    r: Float(sprite.color.0) / 255.0, g: Float(sprite.color.1) / 255.0,
                    b: Float(sprite.color.2) / 255.0, a: Float(sprite.color.3) / 255.0
                )
                let tex_coord = SDL_FPoint(x: 0.0, y: 0.0)

                var vertices = [
                    SDL_Vertex(position: s1, color: color, tex_coord: tex_coord),
                    SDL_Vertex(position: s2, color: color, tex_coord: tex_coord),
                    SDL_Vertex(position: s3, color: color, tex_coord: tex_coord),
                    SDL_Vertex(position: s4, color: color, tex_coord: tex_coord),
                ]
                var indices: [CInt] = [0, 1, 2, 2, 3, 0]  // Draw as 2 triangles
                SDL_RenderGeometry(renderer, nil, &vertices, 4, &indices, 6)
            }
        }
    }

    /// A struct to hold all pre-calculated camera values for a single render frame.
    private struct CameraTransform {
        let camX: Double
        let camY: Double
        let camZoom: Double
        let camSin: Double  // Pre-calculated sin(-rotation)
        let camCos: Double  // Pre-calculated cos(-rotation)
        let screenCenterX: Double
        let screenCenterY: Double
    }

    /**
     * Transforms a point from World Space to Screen Space.
     * This is the core of the new camera logic.
     *
     * 1. Translates the world point to be relative to the camera's world position.
     * 2. Rotates this relative point around the origin (0,0) by the camera's angle.
     * 3. Scales the rotated point by the camera's zoom.
     * 4. Translates the final point from the origin (0,0) to the screen's center.
     */
    private func transformWorldToScreen(worldX: Double, worldY: Double, cam: CameraTransform)
        -> SDL_FPoint
    {
        // 1. Translate to camera
        let relX = worldX - cam.camX
        let relY = worldY - cam.camY

        // 2. Rotate
        let rotX = (relX * cam.camCos) - (relY * cam.camSin)
        let rotY = (relX * cam.camSin) + (relY * cam.camCos)

        // 3. Zoom
        let zoomX = rotX * cam.camZoom
        let zoomY = rotY * cam.camZoom

        // 4. Translate to screen center
        let screenX = zoomX + cam.screenCenterX
        let screenY = zoomY + cam.screenCenterY

        return SDL_FPoint(x: Float(screenX), y: Float(screenY))
    }
}
