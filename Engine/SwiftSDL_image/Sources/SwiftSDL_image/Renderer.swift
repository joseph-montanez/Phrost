#if os(macOS) || os(iOS)
import SwiftSDL
#elseif os(Linux) || os(Windows)
import CSDL3
#endif


// Extend the existing Renderer protocol to add new image-loading capabilities.
// public extension Renderer {
//     /// Loads an image from a file path directly into a hardware-accelerated texture.
//     ///
//     /// This method uses the `SDL_image` library to support various formats like PNG, JPG, etc.
//     /// - Parameter from: The file path of the image to load.
//     /// - Returns: A new `Texture` object containing the image data.
//     /// - Throws: An `SDL_Error` if the image file cannot be found or loaded.
//     func loadTexture(from file: String) throws -> some Texture {
//         // Call the underlying C function from SDL_image.
//         guard let texturePointer = IMG_LoadTexture(self.pointer, file) else {
//             throw SDL_Error.error
//         }
        
//         // Wrap the raw C pointer in your existing SwiftSDL object wrapper.
//         // This ensures its memory is managed correctly.
//         return SDLObject(texturePointer, tag: "texture", destroy: SDL_DestroyTexture)
//     }
// }
