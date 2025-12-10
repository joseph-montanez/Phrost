import Foundation
import ImGui
import SwiftSDL

extension PhrostEngine {

    internal func renderImGuiDrawData() {
        guard let drawData = ImGuiGetDrawData(), drawData.pointee.CmdListsCount > 0 else {
            return
        }

        let width = Int(drawData.pointee.DisplaySize.x * drawData.pointee.FramebufferScale.x)
        let height = Int(drawData.pointee.DisplaySize.y * drawData.pointee.FramebufferScale.y)
        if width == 0 || height == 0 { return }

        let clipOff = drawData.pointee.DisplayPos
        let clipScale = drawData.pointee.FramebufferScale

        for n in 0..<Int(drawData.pointee.CmdListsCount) {
            guard let cmdList = drawData.pointee.CmdLists[n] else { continue }

            // 1. GET RAW BUFFER
            let vtxBufferRaw = UnsafeRawPointer(cmdList.pointee.VtxBuffer.Data!)
            let idxBufferRaw = UnsafeRawPointer(cmdList.pointee.IdxBuffer.Data!)
            let vtxCount = Int(cmdList.pointee.VtxBuffer.Size)

            // 2. COLOR CONVERSION
            var tempColorBuffer = [SDL_FColor](
                repeating: SDL_FColor(r: 1, g: 1, b: 1, a: 1), count: vtxCount)
            let stride = MemoryLayout<ImDrawVert>.stride  // 20 bytes

            for i in 0..<vtxCount {
                let colAddr = vtxBufferRaw.advanced(by: (i * stride) + 16)
                let colVal = colAddr.assumingMemoryBound(to: UInt32.self).pointee

                let r = Float((colVal >> 0) & 0xFF) / 255.0
                let g = Float((colVal >> 8) & 0xFF) / 255.0
                let b = Float((colVal >> 16) & 0xFF) / 255.0
                let a = Float((colVal >> 24) & 0xFF) / 255.0

                tempColorBuffer[i] = SDL_FColor(r: r, g: g, b: b, a: a)
            }

            for cmdIdx in 0..<Int(cmdList.pointee.CmdBuffer.Size) {
                let cmd = cmdList.pointee.CmdBuffer.Data[cmdIdx]

                if let userCallback = cmd.UserCallback {
                    userCallback(cmdList, &cmdList.pointee.CmdBuffer.Data[cmdIdx])
                } else {
                    let clipRect = SDL_Rect(
                        x: Int32((cmd.ClipRect.x - clipOff.x) * clipScale.x),
                        y: Int32((cmd.ClipRect.y - clipOff.y) * clipScale.y),
                        w: Int32((cmd.ClipRect.z - cmd.ClipRect.x) * clipScale.x),
                        h: Int32((cmd.ClipRect.w - cmd.ClipRect.y) * clipScale.y)
                    )
                    var finalClip = clipRect
                    SDL_SetRenderClipRect(renderer, &finalClip)

                    let texturePtr: UnsafeMutablePointer<SDL_Texture>? =
                        (cmd.TextureId != nil)
                        ? UnsafeMutablePointer<SDL_Texture>(OpaquePointer(cmd.TextureId))
                        : nil

                    // CALCULATE POINTERS FOR SDL
                    let vtxOffsetBytes = Int(cmd.VtxOffset) * stride
                    let basePosPtr = vtxBufferRaw.advanced(by: vtxOffsetBytes)
                    let uvPtr = basePosPtr.advanced(by: 8)
                    let colorOffset = Int(cmd.VtxOffset)

                    // Indices
                    let idxStride = MemoryLayout<ImDrawIdx>.stride
                    let idxByteOffset = Int(cmd.IdxOffset) * idxStride
                    let idxPtr = idxBufferRaw.advanced(by: idxByteOffset)

                    let totalVtx = Int(cmdList.pointee.VtxBuffer.Size)
                    let usedVtx = Int(cmd.VtxOffset)
                    let countAvailable = Int32(totalVtx - usedVtx)

                    tempColorBuffer.withUnsafeBufferPointer { colorBufferPtr in
                        guard
                            let baseColorPtr = colorBufferPtr.baseAddress?.advanced(by: colorOffset)
                        else { return }

                        SDL_RenderGeometryRaw(
                            renderer,
                            texturePtr,
                            basePosPtr.assumingMemoryBound(to: Float.self),
                            Int32(stride),
                            baseColorPtr,
                            Int32(MemoryLayout<SDL_FColor>.stride),
                            uvPtr.assumingMemoryBound(to: Float.self),
                            Int32(stride),
                            countAvailable,
                            idxPtr,
                            Int32(cmd.ElemCount),
                            Int32(MemoryLayout<ImDrawIdx>.size)
                        )
                    }
                }
            }
        }

        SDL_SetRenderClipRect(renderer, nil)
    }

    internal func processImGuiInput(event: inout SDL_Event) -> Bool {
        guard let io = ImGuiGetIO() else {
            return false
        }

        switch event.type {

        // --- MOUSE MOVEMENT ---
        case UInt32(SDL_EVENT_MOUSE_MOTION.rawValue):
            ImGuiIO_AddMousePosEvent(io, event.motion.x, event.motion.y)
            return io.pointee.WantCaptureMouse

        // --- MOUSE CLICKS ---
        case UInt32(SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue),
            UInt32(SDL_EVENT_MOUSE_BUTTON_UP.rawValue):

            let isDown = (event.type == UInt32(SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue))
            var imGuiButton: Int32 = 0

            // Map SDL Buttons (1-based) to ImGui Buttons (0-based)
            // SDL: 1=Left, 2=Middle, 3=Right
            // ImGui: 0=Left, 1=Right, 2=Middle
            switch Int32(event.button.button) {
            case SDL_BUTTON_LEFT: imGuiButton = 0
            case SDL_BUTTON_RIGHT: imGuiButton = 1
            case SDL_BUTTON_MIDDLE: imGuiButton = 2
            default: return false  // Ignore extra buttons for now
            }

            ImGuiIO_AddMouseButtonEvent(io, imGuiButton, isDown)
            return io.pointee.WantCaptureMouse

        // --- MOUSE WHEEL ---
        case UInt32(SDL_EVENT_MOUSE_WHEEL.rawValue):
            // SDL3: positive y is scroll up (away from user)
            // ImGui: positive y is scroll up
            var wheelX = event.wheel.x
            var wheelY = event.wheel.y

            // Handle "flipped" scrolling direction if needed (macOS natural scrolling usually handled by OS)
            if event.wheel.direction.rawValue == SDL_MouseWheelDirection.flipped.rawValue {
                wheelX *= -1
                wheelY *= -1
            }

            ImGuiIO_AddMouseWheelEvent(io, wheelX, wheelY)
            return io.pointee.WantCaptureMouse

        // --- TEXT INPUT (Required for typing in text boxes) ---
        case UInt32(SDL_EVENT_TEXT_INPUT.rawValue):
            // SDL_Event.text.text is a tuple or C-array. We need to extract the String.
            withUnsafePointer(to: &event.text.text) { ptr in
                // Cast to raw C string
                let cString = UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                ImGuiIO_AddInputCharactersUTF8(io, cString)
            }
            return io.pointee.WantCaptureKeyboard

        // --- KEYBOARD (Basic) ---
        // Note: Full keyboard mapping (Arrows, Esc, Enter) requires a large switch statement
        // mapping SDL_SCANCODE_* to ImGuiKey_*.
        // This is a minimal implementation for modifiers.
        case UInt32(SDL_EVENT_KEY_DOWN.rawValue),
            UInt32(SDL_EVENT_KEY_UP.rawValue):

            let isDown = (event.type == UInt32(SDL_EVENT_KEY_DOWN.rawValue))

            // Map Modifier keys so you can Ctrl+Click or Shift+Select
            if event.key.scancode == SDL_SCANCODE_LCTRL || event.key.scancode == SDL_SCANCODE_RCTRL
            {
                ImGuiIO_AddKeyEvent(io, ImGuiMod_Ctrl, isDown)
            }
            if event.key.scancode == SDL_SCANCODE_LSHIFT
                || event.key.scancode == SDL_SCANCODE_RSHIFT
            {
                ImGuiIO_AddKeyEvent(io, ImGuiMod_Shift, isDown)
            }
            if event.key.scancode == SDL_SCANCODE_LALT || event.key.scancode == SDL_SCANCODE_RALT {
                ImGuiIO_AddKeyEvent(io, ImGuiMod_Alt, isDown)
            }

            return io.pointee.WantCaptureKeyboard

        default:
            return false
        }
    }

    internal func beginFrame(deltaSec: Double) {
        // Update Display Size (Handle resizing dynamically)
        SDL_GetWindowSize(window, &windowWidth, &windowHeight)
        SDL_GetWindowSizeInPixels(window, &pixelWidth, &pixelHeight)

        // Calculate scale (Retina/High-DPI support)
        scaleX = (windowWidth > 0) ? Float(pixelWidth) / Float(windowWidth) : 1.0
        scaleY = (windowHeight > 0) ? Float(pixelHeight) / Float(windowHeight) : 1.0

        io.pointee.DisplaySize = ImVec2(x: Float(windowWidth), y: Float(windowHeight))
        io.pointee.DisplayFramebufferScale = ImVec2(x: scaleX, y: scaleY)
        io.pointee.DeltaTime = Float(deltaSec)

        // FIX: FontGlobalScale should be 1.0, NOT scaleX
        // DisplayFramebufferScale already handles DPI/Retina scaling for rendering.
        // Setting FontGlobalScale to scaleX causes double-scaling on HiDPI displays
        // or tiny fonts if scale < 1.0
        io.pointee.FontGlobalScale = 1.0

        // Start the ImGui Frame
        ImGuiNewFrame()
    }
}
