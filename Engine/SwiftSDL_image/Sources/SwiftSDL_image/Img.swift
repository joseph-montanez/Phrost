import SwiftSDL

/// Provides a namespace for managing the SDL_image library lifecycle.
public enum IMG {
    /// A set of flags used to initialize the SDL_image library.
    // public static func load(_ path: String) throws -> SDL_Surface {
    //     try IMG_Load(path)
    // }

    // public struct InitFlags: OptionSet, Sendable {
    //     public let rawValue: Int32

    //     public init(rawValue: Int32) {
    //         self.rawValue = rawValue
    //     }

    //     public static let jpg = InitFlags(rawValue: IMG_INIT_JPG.rawValue)
    //     public static let png = InitFlags(rawValue: IMG_INIT_PNG.rawValue)
    //     public static let tif = InitFlags(rawValue: IMG_INIT_TIF.rawValue)
    //     public static let webp = InitFlags(rawValue: IMG_INIT_WEBP.rawValue)
    // }

    // /// Initializes the SDL_image library for loading specific image formats.
    // /// - Parameter flags: The image format support to initialize.
    // /// - Throws: An `SDL_Error` if initialization fails.
    // public static func initialize(with flags: InitFlags) throws {
    //     // The return value of IMG_Init is a bitmask of the successfully initialized loaders.
    //     // We check if all the flags we requested are present in the result.
    //     guard IMG.InitFlags(rawValue: flags.rawValue).rawValue & flags.rawValue == flags.rawValue else {
    //         throw SDL_Error.error
    //     }
    // }

    // /// Shuts down the SDL_image library and frees its resources.
    // public static func quit() {
    //     IMG.quit()
    // }
}
