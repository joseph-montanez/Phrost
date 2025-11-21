import Foundation
import SwiftSDL
import SwiftSDL_ttf

public struct TextRenderResult {
    var texture: UnsafeMutablePointer<SDL_Texture>?
    var size: Vec2
}

extension PhrostEngine {

    // MARK: - TTF/Font Management
    internal func getOrCreateFont(path: String, size: Float) -> OpaquePointer? {
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

    internal func renderTextToTexture(
        font: OpaquePointer?,
        text: String,
        color: SDL_Color
    ) -> TextRenderResult {
        
        guard !text.isEmpty else { 
            return TextRenderResult(texture: nil, size: Vec2(0, 0)) 
        }

        let surface = text.withCString { cstr in
            TTF_RenderText_Blended(font, cstr, 0, color)
        }

        guard let surface = surface else {
            print("TTF_RenderText_Blended Error: \(String(cString: SDL_GetError()))")
            return TextRenderResult(texture: nil, size: Vec2(0, 0))
        }

        let texture = SDL_CreateTextureFromSurface(renderer, surface)
        let w = Double(surface.pointee.w)
        let h = Double(surface.pointee.h)
        
        SDL_DestroySurface(surface)

        return TextRenderResult(texture: texture, size: Vec2(w, h))
    }

    // MARK: - Command Handlers
    internal func handleTextAddCommand(header: PackedTextAddEvent, fontPath: String, textString: String) {
        guard let font = getOrCreateFont(path: fontPath, size: header.fontSize) else { return }

        let color = SDL_Color(r: header.r, g: header.g, b: header.b, a: header.a)
        
        // --- FIX: Use Struct Result ---
        let result = renderTextToTexture(font: font, text: textString, color: color)
        
        let newTextSprite = Sprite(
            id: SpriteID(id1: header.id1, id2: header.id2),
            position: Vec3(header.positionX, header.positionY, header.positionZ),
            scale: Vec3(1.0, 1.0, 1.0),
            size: result.size, // <-- Access .size struct
            rotate: Vec3(0.0, 0.0, 0.0),
            color: ColorRGBA(header.r, header.g, header.b, header.a),
            speed: Vec2(0.0, 0.0),
            texture: result.texture, // <-- Access .texture property
            text: textString,
            font: font
        )
        
        spriteManager.addRawSprite(newTextSprite)
    }

    internal func handleTextSetStringCommand(
        header: PackedTextSetStringEvent, newTextString: String
    ) {
        let spriteID = SpriteID(id1: header.id1, id2: header.id2)
        guard let sprite = spriteManager.getSprite(for: spriteID) else {
            print("TextSetString: unknown sprite ID.")
            return
        }
        guard let font = sprite.font else {
            print("TextSetString: called on a non-text sprite.")
            return
        }

        // FIXED: Access color components via struct properties
        let r = sprite.color.r
        let g = sprite.color.g
        let b = sprite.color.b
        let a = sprite.color.a

        let color = SDL_Color(r: r, g: g, b: b, a: a)
        let result = renderTextToTexture(font: font, text: newTextString, color: color)
        
        if let oldTexture = sprite.texture {
            SDL_DestroyTexture(oldTexture)
        }

        sprite.texture = result.texture
        sprite.size = result.size
        sprite.text = newTextString
    }
}
