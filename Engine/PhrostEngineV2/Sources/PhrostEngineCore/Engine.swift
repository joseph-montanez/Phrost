import CMiniaudio
import Foundation
import ImGui
import SwiftSDL
import SwiftSDL_image
import SwiftSDL_ttf

#if os(Linux) || os(Windows)
    import CChipmunk2D
#else
    import Chipmunk2D
#endif

// --- Platform-Specific Imports (Required for plugin loading in PhrostEngine+Plugin.swift) ---
#if os(Windows)
    import WinSDK
#elseif os(Linux)
    import Glibc
#else
    import Darwin
#endif
// --- End Platform-Specific Imports ---

// --- Core Engine ---
public final class PhrostEngine {
    // MARK: Core SDL Pointers
    internal let window: OpaquePointer
    internal let renderer: OpaquePointer
    internal let spriteManager: SpriteManager
    internal let physicsManager: PhysicsManager
    internal let geometryManager: GeometryManager  // <-- NEW
    // internal var mixer: OpaquePointer?
    internal var maEngine: ma_engine

    // MARK: Texture Caches
    internal var textureCache: [String: UnsafeMutablePointer<SDL_Texture>?] = [:]
    internal var loadedFilenames: [String: UInt64] = [:]
    internal var nextTextureID: UInt64 = 1

    // MARK: Font Cache
    internal var fontCache: [String: OpaquePointer?] = [:]

    // MARK: Audio Cache
    // internal var audioCache: [String: OpaquePointer?] = [:]
    internal var audioCache: [UInt64: UnsafeMutablePointer<ma_sound>] = [:]
    internal var loadedAudioFiles: [String: UInt64] = [:]
    internal var audioIdToPath: [UInt64: String] = [:]
    internal var nextAudioID: UInt64 = 1

    // MARK: Plugin Management (Definition moved here for structural completeness)
    internal struct LoadedPlugin {
        let id: UInt8
        let handle: UnsafeMutableRawPointer
        let wakeFunc: CPluginWakeFunc?
        let updateFunc: CPluginUpdateFunc
        let freeFunc: CPluginFreeFunc
        let sleepFunc: CPluginSleepFunc?
    }

    internal var loadedPlugins: [UInt8: LoadedPlugin] = [:]
    internal var nextPluginID: UInt8 = 1

    // MARK: UI Management
    internal let ctx: UnsafeMutablePointer<ImGuiContext>!
    internal let io: UnsafeMutablePointer<ImGuiIO>!

    /// Build font atlas
    internal var pixels: UnsafeMutablePointer<UInt8>?
    internal var width: Int32 = 0
    internal var height: Int32 = 0
    internal var bytesPerPixel: Int32 = 0
    internal var fontTexture: UnsafeMutablePointer<SDL_Texture>?

    // MARK: State
    internal var running = true
    internal var windowWidth: Int32 = 0
    internal var windowHeight: Int32 = 0
    internal var pixelWidth: Int32 = 0
    internal var pixelHeight: Int32 = 0
    internal var scaleX: Float = 0
    internal var scaleY: Float = 0
    internal var cameraOffset: (x: Double, y: Double) = (0.0, 0.0)
    internal var cameraZoom: Double = 1.0
    internal var cameraRotation: Double = 0.0
    internal var cameraFollowTarget: SpriteID? = nil
    internal var pluginOn = false
    internal var eventStackingOn = true
    internal var internalEventStream = Data()
    internal var internalEventCount: UInt32 = 0
    /// Stores [pluginId: [channelId, channelId...]]
    internal var pluginSubscriptions: [UInt8: Set<UInt32>] = [:]

    /// Stores [channelId: DataBlob] from PHP for one frame
    internal var pluginChannelData: [UInt32: Data] = [:]

    /// Stores PHP's dynamic subscriptions.
    internal var phpSubscribedChannels: Set<UInt32> = [0, 2, 6]

    internal let eventPayloadSizes: [UInt32: Int] = [
        // --- SPRITE ---
        Events.spriteAdd.rawValue: MemoryLayout<PackedSpriteAddEvent>.size,
        Events.spriteRemove.rawValue: MemoryLayout<PackedSpriteRemoveEvent>.size,
        Events.spriteMove.rawValue: MemoryLayout<PackedSpriteMoveEvent>.size,
        Events.spriteScale.rawValue: MemoryLayout<PackedSpriteScaleEvent>.size,
        Events.spriteResize.rawValue: MemoryLayout<PackedSpriteResizeEvent>.size,
        Events.spriteRotate.rawValue: MemoryLayout<PackedSpriteRotateEvent>.size,
        Events.spriteColor.rawValue: MemoryLayout<PackedSpriteColorEvent>.size,
        Events.spriteSpeed.rawValue: MemoryLayout<PackedSpriteSpeedEvent>.size,
        Events.spriteTextureLoad.rawValue: MemoryLayout<PackedTextureLoadHeaderEvent>.size,
        Events.spriteTextureSet.rawValue: MemoryLayout<PackedSpriteTextureSetEvent>.size,
        Events.spriteSetSourceRect.rawValue: MemoryLayout<PackedSpriteSetSourceRectEvent>.size,
        // --- GEOMETRY ---
        Events.geomAddPoint.rawValue: MemoryLayout<PackedGeomAddPointEvent>.size,
        Events.geomAddLine.rawValue: MemoryLayout<PackedGeomAddLineEvent>.size,
        Events.geomAddRect.rawValue: MemoryLayout<PackedGeomAddRectEvent>.size,
        Events.geomAddFillRect.rawValue: MemoryLayout<PackedGeomAddRectEvent>.size,
        Events.geomAddPacked.rawValue: MemoryLayout<PackedGeomAddPackedHeaderEvent>.size,
        Events.geomRemove.rawValue: MemoryLayout<PackedGeomRemoveEvent>.size,
        Events.geomSetColor.rawValue: MemoryLayout<PackedGeomSetColorEvent>.size,
        // --- INPUT ---
        Events.inputKeyup.rawValue: MemoryLayout<PackedKeyEvent>.size,
        Events.inputKeydown.rawValue: MemoryLayout<PackedKeyEvent>.size,
        Events.inputMouseup.rawValue: MemoryLayout<PackedMouseButtonEvent>.size,
        Events.inputMousedown.rawValue: MemoryLayout<PackedMouseButtonEvent>.size,
        Events.inputMousemotion.rawValue: MemoryLayout<PackedMouseMotionEvent>.size,
        // --- WINDOW ---
        Events.windowTitle.rawValue: MemoryLayout<PackedWindowTitleEvent>.size,
        Events.windowResize.rawValue: MemoryLayout<PackedWindowResizeEvent>.size,
        Events.windowFlags.rawValue: MemoryLayout<PackedWindowFlagsEvent>.size,
        // --- TEXT ---
        Events.textAdd.rawValue: MemoryLayout<PackedTextAddEvent>.size,
        Events.textSetString.rawValue: MemoryLayout<PackedTextSetStringEvent>.size,
        // --- AUDIO ---
        Events.audioLoad.rawValue: MemoryLayout<PackedAudioLoadEvent>.size,
        Events.audioLoaded.rawValue: MemoryLayout<PackedAudioLoadedEvent>.size,
        Events.audioPlay.rawValue: MemoryLayout<PackedAudioPlayEvent>.size,
        Events.audioStopAll.rawValue: MemoryLayout<PackedAudioStopAllEvent>.size,
        Events.audioSetMasterVolume.rawValue: MemoryLayout<PackedAudioSetMasterVolumeEvent>.size,
        Events.audioPause.rawValue: MemoryLayout<PackedAudioPauseEvent>.size,
        Events.audioStop.rawValue: MemoryLayout<PackedAudioStopEvent>.size,
        Events.audioUnload.rawValue: MemoryLayout<PackedAudioUnloadEvent>.size,
        Events.audioSetVolume.rawValue: MemoryLayout<PackedAudioSetVolumeEvent>.size,
        // --- PHYSICS ---
        Events.physicsAddBody.rawValue: MemoryLayout<PackedPhysicsAddBodyEvent>.size,
        Events.physicsRemoveBody.rawValue: MemoryLayout<PackedPhysicsRemoveBodyEvent>.size,
        Events.physicsApplyForce.rawValue: MemoryLayout<PackedPhysicsApplyForceEvent>.size,
        Events.physicsApplyImpulse.rawValue: MemoryLayout<PackedPhysicsApplyImpulseEvent>.size,
        Events.physicsSetVelocity.rawValue: MemoryLayout<PackedPhysicsSetVelocityEvent>.size,
        Events.physicsSetPosition.rawValue: MemoryLayout<PackedPhysicsSetPositionEvent>.size,
        Events.physicsSetRotation.rawValue: MemoryLayout<PackedPhysicsSetRotationEvent>.size,
        Events.physicsCollisionBegin.rawValue: MemoryLayout<PackedPhysicsCollisionEvent>.size,
        Events.physicsCollisionSeparate.rawValue: MemoryLayout<PackedPhysicsCollisionEvent>.size,
        Events.physicsSyncTransform.rawValue: MemoryLayout<PackedPhysicsSyncTransformEvent>.size,
        Events.physicsSetDebugMode.rawValue: MemoryLayout<PackedPhysicsSetDebugModeEvent>.size,
        // --- PLUGIN ---
        Events.plugin.rawValue: MemoryLayout<PackedPluginOnEvent>.size,
        Events.pluginLoad.rawValue: MemoryLayout<PackedPluginLoadHeaderEvent>.size,
        Events.pluginUnload.rawValue: MemoryLayout<PackedPluginUnloadEvent>.size,
        Events.pluginSet.rawValue: MemoryLayout<PackedPluginSetEvent>.size,
        Events.pluginEventStacking.rawValue: MemoryLayout<PackedPluginEventStackingEvent>.size,
        Events.pluginSubscribeEvent.rawValue: MemoryLayout<PackedPluginSubscribeEvent>.size,
        Events.pluginUnsubscribeEvent.rawValue: MemoryLayout<PackedPluginUnsubscribeEvent>.size,
        // --- CAMERA ---
        Events.cameraSetPosition.rawValue: MemoryLayout<PackedCameraSetPositionEvent>.size,
        Events.cameraMove.rawValue: MemoryLayout<PackedCameraMoveEvent>.size,
        Events.cameraSetZoom.rawValue: MemoryLayout<PackedCameraSetZoomEvent>.size,
        Events.cameraSetRotation.rawValue: MemoryLayout<PackedCameraSetRotationEvent>.size,
        Events.cameraFollowEntity.rawValue: MemoryLayout<PackedCameraFollowEntityEvent>.size,
        Events.cameraStopFollowing.rawValue: MemoryLayout<PackedCameraStopFollowingEvent>.size,
        // --- SCRIPT ---
        Events.scriptSubscribe.rawValue: MemoryLayout<PackedScriptSubscribeEvent>.size,
        Events.scriptUnsubscribe.rawValue: MemoryLayout<PackedScriptUnsubscribeEvent>.size,
    ]

    // MARK: Initialization
    public init?(title: String, width: Int32, height: Int32, flags: UInt64) {
        SDL_SetMainReady()
        if !SDL_Init(SDL_INIT_VIDEO) {
            print("SDL_Init Error: \(String(cString: SDL_GetError()))")
            return nil
        }

        if !TTF_Init() {
            print("TTF_Init Error: \(String(cString: SDL_GetError()))")
            SDL_Quit()
            return nil
        }

        guard let window = SDL_CreateWindow(title, width, height, flags) else {
            print("SDL_CreateWindow Error: \(String(cString: SDL_GetError()))")
            SDL_Quit()
            return nil
        }

        guard let renderer = SDL_CreateRenderer(window, nil) else {
            print("SDL_CreateRenderer Error: \(String(cString: SDL_GetError()))")
            SDL_DestroyWindow(window)
            SDL_Quit()
            return nil
        }

        // Audio
        self.maEngine = ma_engine()
        var engineConfig = ma_engine_config_init()
        let result = ma_engine_init(&engineConfig, &self.maEngine)
        if result != MA_SUCCESS {
            print("Failed to initialize miniaudio engine: \(result)")
            SDL_DestroyRenderer(renderer)
            SDL_DestroyWindow(window)
            TTF_Quit()
            SDL_Quit()
            return nil
        }

        // GUI
        IMGUI_CHECKVERSION()
        self.ctx = ImGuiCreateContext(nil)
        self.io = ImGuiGetIO()!
        ImFontAtlas_GetTexDataAsRGBA32(
            io.pointee.Fonts, &self.pixels, &self.width, &self.height, &self.bytesPerPixel)
        self.fontTexture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_RGBA32,
            SDL_TEXTUREACCESS_STATIC,
            self.width,
            self.height
        )
        if self.fontTexture == nil {
            print("Failed to create ImGui Font Texture: \(String(cString: SDL_GetError()))")
        }
        SDL_UpdateTexture(self.fontTexture, nil, self.pixels, self.width * 4)
        SDL_SetTextureBlendMode(self.fontTexture, SDL_BLENDMODE_BLEND)
        SDL_SetTextureScaleMode(self.fontTexture, SDL_SCALEMODE_LINEAR)
        io.pointee.Fonts.pointee.TexID = ImTextureID(OpaquePointer(self.fontTexture))
        // End GUI

        self.window = window
        self.renderer = renderer
        self.spriteManager = SpriteManager()
        self.geometryManager = GeometryManager()  // <-- NEW
        self.physicsManager = PhysicsManager(spriteManager: self.spriteManager)
        print("PhrostEngine Initialized Successfully")

        // NOTE: All the debug 'print' statements about memory layouts should be moved
        // out of the main initializer, perhaps into a separate debug utility or just removed
        // once ABI stability is confirmed. They are removed here for brevity.
    }

    // MARK: Deinitialization
    deinit {
        print("Cleaning up PhrostEngine...")
        self.unloadAllPlugins()  // Calls the method in PhrostEngine+Plugin.swift

        // Destroy all cached textures
        for texture in textureCache.values {
            if let texture = texture { SDL_DestroyTexture(texture) }
        }
        // Clean up Font Cache
        for font in fontCache.values { TTF_CloseFont(font) }
        fontCache.removeAll()

        for soundPtr in audioCache.values {
            ma_sound_uninit(soundPtr)
            soundPtr.deallocate()
        }
        audioCache.removeAll()
        loadedAudioFiles.removeAll()

        ma_engine_uninit(&self.maEngine)

        ImGuiDestroyContext(self.ctx)

        SDL_DestroyRenderer(renderer)
        SDL_DestroyWindow(window)

        TTF_Quit()
        SDL_Quit()
        print("PhrostEngine Cleaned up.")
    }
}
