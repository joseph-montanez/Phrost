#if os(macOS) || os(iOS)
import SwiftSDL
import SwiftSDL_image
#elseif os(Linux) || os(Windows)
import CSDL3
import CSDL3_image
#endif

import ArgumentParser
import Foundation

@main
struct SDL: ParsableCommand {
    static let configuration = CommandConfiguration(
        groupedSubcommands: [
            .init(name: "test", subcommands: [Test.self])
        ]
    )
}

extension SDL {
    struct Test: ParsableCommand {
        typealias Options = GameOptions
        
        static let configuration = CommandConfiguration(
            abstract: "Run a variety of SDL tests reimplemented using SwiftSDL.",
            subcommands: [
                // All tests are registered here.
                // Assuming your Geometry test still exists and is defined elsewhere in this namespace.
                // Geometry.self,
                ImageSupport.self
            ]
        )
    }
}

// --- Test Implementations ---
// The ImageSupport class is now defined here, inside an extension of SDL.Test.

extension SDL.Test {
    final class ImageSupport: Game {

        // MARK: - Command Line Configuration
        
        static let configuration = CommandConfiguration(
            abstract: "Loads and displays various image formats using SDL_image."
        )
        
        static let name: String = "SDL_image Test: Image Support"
        
        @OptionGroup var options: Options
        
        @Argument(help: "The path to the image file to load (e.g., icon.png).")
        var filePath: String = "icon.png"

        // MARK: - Properties (Runtime State)

        private var renderer: (any Renderer)!
        private var imageTexture: (any Texture)!

        // MARK: - Initializers
        
        // This empty initializer is required by the ParsableArguments protocol.
        init() {}

        // This initializer is still needed for Decodable conformance.
        enum CodingKeys: String, CodingKey {
            case options
            case filePath
        }
        
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.options = try container.decode(GameOptions.self, forKey: .options)
            self.filePath = try container.decode(String.self, forKey: .filePath)
        }

        // MARK: - Game Lifecycle

        func onReady(window: any SwiftSDL.Window) throws(SwiftSDL.SDL_Error) {
            // Use the Swift wrapper's static method to initialize
            // try IMG.initialize(with: .png)
            // print("SDL_image initialized for PNG support.")

            renderer = try window.createRenderer()
            
            print("Attempting to load texture from '\(filePath)'...")
            // Use the Swift wrapper's extension on the Renderer protocol.
            imageTexture = Texture(IMG_LoadTexture(renderer.pointer, filePath))
            // imageTexture = try renderer.loadTexture(from: filePath)
            print("Texture loaded successfully!")
        }
        
        func onUpdate(window: any Window) throws(SwiftSDL.SDL_Error) {
            try renderer.clear(color: .init(r: 0xD0, g: 0xD0, b: 0xD0, a: 0xFF))
            
            // Render the texture using the direct-call pattern from your Geometry test.
            // This is the Swift wrapper for SDL_RenderTexture(renderer, texture, nil, nil).
            try renderer(SDL_RenderTexture, imageTexture.pointer, nil, nil)
            
            try renderer.present()
        }
        
        func onShutdown(window: (any SwiftSDL.Window)?) throws(SwiftSDL.SDL_Error) {
            imageTexture = nil
            renderer = nil
            // Use the Swift wrapper's static method to quit.
            // IMG.quit()
            print("SDL_image subsystem shut down.")
        }
        
        func onEvent(window: any Window, _ event: SDL_Event) throws(SDL_Error) {}
    }
}


// --- Helper Functions ---

func Load(bitmap: String) throws(SDL_Error) -> some Surface {
    try SDL_Load(
        bitmap: bitmap,
        searchingBundles: Bundle.resourceBundles(matching: {
            $0.lastPathComponent.contains("SwiftSDL-TestBench")
        })
    )
}

func Load(
    shader file: String,
    device gpuDevice: any GPUDevice,
    samplerCount: UInt32 = 0,
    uniformBufferCount: UInt32 = 0,
    storageBufferCount: UInt32 = 0,
    storageTextureCount: UInt32 = 0,
    propertyID: SDL_PropertiesID = 0
) throws(SDL_Error) -> some GPUShader {
    try SDL_Load(
        shader: file,
        device: gpuDevice,
        samplerCount: samplerCount,
        uniformBufferCount: uniformBufferCount,
        storageBufferCount: storageBufferCount,
        storageTextureCount: storageTextureCount,
        propertyID: propertyID,
        searchingBundles: Bundle.resourceBundles(matching: {
            $0.lastPathComponent.contains("SwiftSDL-TestBench")
        })
    )
}

