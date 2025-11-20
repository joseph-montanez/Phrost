import Foundation
import SwiftSDL_ttf
import SwiftSDL

extension PhrostEngine {

    // MARK: - TTF/Font Management

    /// Gets a font from the cache or loads it if not found.
    internal func getOrCreateFont(path: String, size: Float) -> OpaquePointer? {
        // ... (Full body of getOrCreateFont) ...
        let cacheKey = "\(path):\(size)"

        if let cachedFont = fontCache[cacheKey] {
            return cachedFont
        }

        let newFont = TTF_OpenFont(path, size)

        if newFont == nil {
            print("TTF_OpenFont Error for '\(path)': \(String(cString: SDL_GetError()))")
            return nil
        }

        print("Loaded font '\(path)' at size \(size) into cache.")
        fontCache[cacheKey] = newFont
        return newFont
    }

    /// Renders a string of text to a new SDL_Texture.
    internal func renderTextToTexture(
        font: OpaquePointer?,
        text: String,
        color: SDL_Color
    ) -> (texture: UnsafeMutablePointer<SDL_Texture>?, size: (Double, Double)) {
        // ... (Full body of renderTextToTexture) ...
        guard !text.isEmpty else { return (nil, (0.0, 0.0)) }

        let surface = text.withCString { cstr in
            TTF_RenderText_Blended(font, cstr, 0, color)
        }

        guard let surface = surface else {
            print("TTF_RenderText_Blended Error: \(String(cString: SDL_GetError()))")
            return (nil, (0, 0))
        }

        let texture = SDL_CreateTextureFromSurface(renderer, surface)
        if texture == nil {
            print("SDL_CreateTextureFromSurface Error: \(String(cString: SDL_GetError()))")
        }

        let size = (Double(surface.pointee.w), Double(surface.pointee.h))
        SDL_DestroySurface(surface)

        return (texture, size)
    }

    // MARK: - Command Handlers

    /// Logic for .textAdd extracted from processCommands
    internal func handleTextAddCommand(header: PackedTextAddEvent, fontPath: String, textString: String) {
        guard let font = getOrCreateFont(path: fontPath, size: header.fontSize) else {
            print("Failed to load font '\(fontPath)'.")
            return
        }

        let color = SDL_Color(r: header.r, g: header.g, b: header.b, a: header.a)
        let (texture, (width, height)) = renderTextToTexture(
            font: font, text: textString, color: color)
        // let texture: UnsafeMutablePointer<SDL_Texture>? = nil
            // let width: Double = 100.0
            // let height: Double = 20.0
        let spriteID = SpriteID(id1: header.id1, id2: header.id2)
        // Assuming Sprite struct has text/font properties
        let newTextSprite = Sprite(
            id: spriteID,
            position: (header.positionX, header.positionY, header.positionZ),
            scale: (1.0, 1.0, 1.0),
            size: (width, height),
            rotate: (0.0, 0.0, 0.0),
            color: (header.r, header.g, header.b, header.a),
            speed: (0.0, 0.0),
            texture: texture,
            text: textString,
            font: font
        )
        spriteManager.addRawSprite(newTextSprite)
    }

    /// Logic for .textSetString extracted from processCommands
    internal func handleTextSetStringCommand(header: PackedTextSetStringEvent, newTextString: String) {
        let spriteID = SpriteID(id1: header.id1, id2: header.id2)
        guard let sprite = spriteManager.getSprite(for: spriteID) else {
            print("TextSetString: unknown sprite ID.")
            return
        }
        guard let font = sprite.font else {
            print("TextSetString: called on a non-text sprite.")
            return
        }

        let (r, g, b, a) = sprite.color
        let color = SDL_Color(r: r, g: g, b: b, a: a)
        let (newTexture, (newWidth, newHeight)) = renderTextToTexture(
            font: font, text: newTextString, color: color)

        if let oldTexture = sprite.texture {
            SDL_DestroyTexture(oldTexture)
        }

        sprite.texture = newTexture
        sprite.size = (newWidth, newHeight)
        sprite.text = newTextString
    }
}
