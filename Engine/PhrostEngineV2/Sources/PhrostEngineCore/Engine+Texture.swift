import Foundation
import SwiftSDL
import SwiftSDL_image

extension PhrostEngine {

    // Logic for .spriteTextureLoad extracted from processCommands
    internal func handleTextureLoadCommand(header: PackedTextureLoadHeaderEvent, filename: String) -> (Data, UInt32) {
        var textureID: UInt64 = 0
        var texture: UnsafeMutablePointer<SDL_Texture>? = nil

        if let existingID = loadedFilenames[filename] {
            textureID = existingID
            texture = textureCache[filename, default: nil] ?? nil
        } else {
            print("Texture '\(filename)' not in cache. Loading...")
            texture = filename.withCString { IMG_LoadTexture(renderer, $0) }

            if let loadedTexture = texture {
                print("Texture Loaded Successfully")
                textureID = nextTextureID
                nextTextureID &+= 1
                textureCache[filename] = loadedTexture
                loadedFilenames[filename] = textureID
            } else {
                let err = String(cString: SDL_GetError())
                print("... FAILED to load texture '\(filename)'. Error: \(err)")
                textureCache[filename] = nil
                loadedFilenames[filename] = 0
                textureID = 0
            }
        }

        spriteManager.setTexture(
            for: SpriteID(id1: header.id1, id2: header.id2),
            texture: texture
        )

        // Queue event back to PHP
        let eventData = makeSpriteTextureSetEvent(
            id1: header.id1,
            id2: header.id2,
            textureId: textureID
        )
        return (eventData, 1)
    }

    /// Creates a Data blob for a spriteTextureSet event.
    internal func makeSpriteTextureSetEvent(id1: Int64, id2: Int64, textureId: UInt64) -> Data {
        var eventData = Data()
        // Assuming PackedSpriteTextureSetEvent is in PhrostStructs.swift or accessible
        let setEvent = PackedSpriteTextureSetEvent(
            id1: id1,
            id2: id2,
            textureId: textureId
        )
        eventData.append(value: Events.spriteTextureSet.rawValue)
        eventData.append(value: SDL_GetTicks())
        eventData.append(value: setEvent)
        return eventData
    }
}
