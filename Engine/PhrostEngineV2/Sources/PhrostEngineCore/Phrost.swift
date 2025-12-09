import CMiniaudio
import Foundation
import SwiftSDL
import SwiftSDL_ttf

public struct PhrostAddSpriteEvent: Sendable {
    public var id: (Int64, Int64)
    public var position: (Double, Double, Double)
    public var scale: (Double, Double, Double)
    public var size: (Double, Double)
    public var rotation: (Double, Double, Double)
    public var color: (UInt8, UInt8, UInt8, UInt8)
    public var speed: (Double, Double)
}

public struct PhrostMoveSpriteEvent: Sendable {
    public var id: (Int64, Int64)
    public var position: (Double, Double, Double)
}

public struct PhrostSpriteRender {
    public var textureId: Int
    public var position: (Double, Double, Double)
    public var scale: (Double, Double, Double)
    public var size: (Double, Double)
    public var rotation: (Double, Double, Double)
    public var color: (Int64, Int64, Int64, Int64)
}

// Event struct to define the type of event to pass between task

public enum PhrostLogicEvent: Sendable {
    case addSprite(sprite: PhrostAddSpriteEvent)
    case removeSprite(spriteId: Int64)
    case moveSprite(sprite: PhrostMoveSpriteEvent)
    case genericMessage(message: String)
}
public enum PhrostPhpEvent: Sendable {
    case reloadScript
}

// Define an event emitter using AsyncStream
// Define a generic event emitter using AsyncStream
public class EventEmitter<EventType: Sendable>: @unchecked Sendable {
    private var continuation: AsyncStream<EventType>.Continuation?

    func emit(event: EventType) {
        continuation?.yield(event)
    }

    func eventStream() -> AsyncStream<EventType> {
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }
}

// MARK: - Core ID
public struct SpriteID: Hashable, Sendable {
    let id1: Int64
    let id2: Int64
}

// MARK: - Math Structs (Safe for Windows ARM64)
public struct Vec2: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Vec3: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct ColorRGBA: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8
    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

// MARK: - Sprite Class
public final class Sprite: @unchecked Sendable {
    public var id: SpriteID
    public var position: Vec3
    public var size: Vec2
    public var color: ColorRGBA
    public var texture: UnsafeMutablePointer<SDL_Texture>? = nil
    public var rotate: Vec3
    public var speed: Vec2
    public var scale: Vec3
    public var text: String?
    public var font: OpaquePointer?
    public var sourceRect: SDL_FRect? = nil

    init(
        id: SpriteID,
        position: Vec3,
        scale: Vec3,
        size: Vec2,
        rotate: Vec3,
        color: ColorRGBA,
        speed: Vec2,
        texture: UnsafeMutablePointer<SDL_Texture>? = nil,
        text: String? = nil,
        font: OpaquePointer? = nil,
        sourceRect: SDL_FRect? = nil
    ) {
        self.id = id
        self.position = position
        self.scale = scale
        self.size = size
        self.rotate = rotate
        self.color = color
        self.speed = speed
        self.texture = texture
        self.text = text
        self.font = font
        self.sourceRect = sourceRect
    }
}

// MARK: - Sprite Manager
public final class SpriteManager: @unchecked Sendable {
    // Dictionary is safe now that we use Structs and /MD runtime
    private var sprites: [SpriteID: Sprite] = [:]
    private var isSortNeeded = false
    private var renderList: [Sprite] = []

    public init() {}

    func addSprite(_ spriteEvent: PackedSpriteAddEvent) {
        let spriteID = SpriteID(id1: spriteEvent.id1, id2: spriteEvent.id2)

        // --- Prevent Duplicates in RenderList ---
        if sprites[spriteID] != nil {
            // If the sprite ID already exists, remove the OLD instance from the render list
            // so we don't draw it twice.
            renderList.removeAll(where: { $0.id == spriteID })
        }

        let newSprite = Sprite(
            id: spriteID,
            position: Vec3(spriteEvent.positionX, spriteEvent.positionY, spriteEvent.positionZ),
            scale: Vec3(spriteEvent.scaleX, spriteEvent.scaleY, spriteEvent.scaleZ),
            size: Vec2(spriteEvent.sizeW, spriteEvent.sizeH),
            rotate: Vec3(spriteEvent.rotationX, spriteEvent.rotationY, spriteEvent.rotationZ),
            color: ColorRGBA(spriteEvent.r, spriteEvent.g, spriteEvent.b, spriteEvent.a),
            speed: Vec2(spriteEvent.speedX, spriteEvent.speedY),
            texture: nil,
            text: nil,
            font: nil,
            sourceRect: nil
        )

        sprites[spriteID] = newSprite
        renderList.append(newSprite)
        isSortNeeded = true
    }

    public func removeSprite(id: SpriteID) {
        if sprites.removeValue(forKey: id) != nil {
            renderList.removeAll(where: { $0.id == id })
            isSortNeeded = true
        } else {
            print(
                "SpriteManager Warning: Attempted to remove non-existent sprite ID (\(id.id1), \(id.id2))"
            )
        }
    }

    func addRawSprite(_ sprite: Sprite) {
        // --- Prevent Duplicates in RenderList ---
        if sprites[sprite.id] != nil {
            renderList.removeAll(where: { $0.id == sprite.id })
        }

        sprites[sprite.id] = sprite
        renderList.append(sprite)
        isSortNeeded = true
    }

    func getSprite(for id: SpriteID) -> Sprite? {
        return sprites[id]
    }

    func moveSprite(_ id: SpriteID, _ position: (Double, Double, Double)) {
        if let sprite = sprites[id] {
            if sprite.position.z != position.2 {
                isSortNeeded = true
            }
            sprite.position = Vec3(position.0, position.1, position.2)
        }
    }

    func scaleSprite(_ id: SpriteID, _ scale: (Double, Double, Double)) {
        sprites[id]?.scale = Vec3(scale.0, scale.1, scale.2)
    }

    func resizeSprite(_ id: SpriteID, _ size: (Double, Double)) {
        sprites[id]?.size = Vec2(size.0, size.1)
    }

    func colorSprite(_ id: SpriteID, _ color: (UInt8, UInt8, UInt8, UInt8)) {
        sprites[id]?.color = ColorRGBA(color.0, color.1, color.2, color.3)
    }

    func rotateSprite(_ id: SpriteID, _ rotate: (Double, Double, Double)) {
        sprites[id]?.rotate = Vec3(rotate.0, rotate.1, rotate.2)
    }

    func speedSprite(_ id: SpriteID, _ speed: (Double, Double)) {
        sprites[id]?.speed = Vec2(speed.0, speed.1)
    }

    func getSpritesForRendering() -> [Sprite] {
        if isSortNeeded {
            renderList.sort(by: { $0.position.z < $1.position.z })
            isSortNeeded = false
        }
        return renderList
    }

    func setTexture(for id: SpriteID, texture: UnsafeMutablePointer<SDL_Texture>?) {
        if let sprite = sprites[id] {
            sprite.texture = texture
        } else {
            print(
                "SpriteManager Error: Attempted to set texture for unknown sprite ID (\(id.id1), \(id.id2))"
            )
        }
    }

    func setSourceRect(_ id: SpriteID, _ rect: (Float, Float, Float, Float)) {
        if let sprite = sprites[id] {
            if rect.2 <= 0 || rect.3 <= 0 {
                sprite.sourceRect = nil
            } else {
                sprite.sourceRect = SDL_FRect(x: rect.0, y: rect.1, w: rect.2, h: rect.3)
            }
        }
    }

    func plugin(for id: SpriteID, dt: Double) {
        if let sprite = sprites[id] {
            sprite.position.x += sprite.speed.x * dt
            sprite.position.y += sprite.speed.y * dt

            let new_x = sprite.position.x + 16
            let new_y = sprite.position.y + 16

            if new_x > 800 - 12 || new_x < 12 {
                sprite.speed.x *= -1
            }
            if new_y > 450 - 16 || new_y < 16 {
                sprite.speed.y *= -1
            }
        }
    }
}
// MARK: - Geometry Manager (Primitive Rendering)
public enum PrimitiveType: UInt32 {
    case point = 0
    case line = 1
    case rect = 2
    case fillRect = 3
    case points = 4
    case lines = 5
    case rects = 6
    case fillRects = 7
    case polygon = 8
    case polygonOutline = 9
}

public final class RenderPrimitive: @unchecked Sendable {
    public var id: SpriteID
    public var type: PrimitiveType
    public var z: Double
    public var color: ColorRGBA
    public var isScreenSpace: Bool

    public var points: [SDL_FPoint] = []
    public var rects: [SDL_FRect] = []

    public var vertices: [SDL_Vertex] = []
    public var indices: [Int32] = []

    init(
        id: SpriteID, type: PrimitiveType, z: Double,
        color: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        isScreenSpace: Bool
    ) {
        self.id = id
        self.type = type
        self.z = z
        self.color = ColorRGBA(color.0, color.1, color.2, color.3)
        self.isScreenSpace = isScreenSpace
    }
}

// MARK: - Helpers / Extensions
extension Data {
    public mutating func append<T>(value: T) {
        Swift.withUnsafeBytes(of: value) { self.append(contentsOf: $0) }
    }
}
