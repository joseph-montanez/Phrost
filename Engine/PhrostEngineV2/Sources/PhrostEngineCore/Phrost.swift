import CMiniaudio
import Foundation
import SwiftSDL
import SwiftSDL_ttf

extension Data {
    public mutating func append<T>(value: T) {
        Swift.withUnsafeBytes(of: value) {
            self.append(contentsOf: $0)
        }
    }
}

public struct FramePacker {
    private var data: Data

    public init<T>(for type: T.Type) {
        let capacity = MemoryLayout<T>.stride
        self.data = Data(count: capacity)
    }

    public mutating func pack<T>(struct value: T) {
        precondition(
            MemoryLayout<T>.stride == data.count,
            "The struct being packed does not match the buffer's capacity.")

        data.withUnsafeMutableBytes { destBufferPtr in
            Swift.withUnsafeBytes(of: value) { sourceBufferPtr in
                destBufferPtr.copyMemory(from: sourceBufferPtr)
            }
        }
    }

    public var finalizedData: Data {
        return data
    }
}

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

// A hashable ID for sprites to use as a dictionary key
public struct SpriteID: Hashable, Sendable {
    let id1: Int64
    let id2: Int64
}

// Represents a sprite's renderable state
// --- FIX: Made class public ---
public final class Sprite: @unchecked Sendable {
    public var id: SpriteID
    public var position: (Double, Double, Double)
    public var size: (Double, Double)
    public var color: (UInt8, UInt8, UInt8, UInt8)
    public var texture: UnsafeMutablePointer<SDL_Texture>? = nil
    public var rotate: (Double, Double, Double)
    public var speed: (Double, Double)
    public var scale: (Double, Double, Double)
    public var text: String?
    public var font: OpaquePointer?
    public var sourceRect: SDL_FRect? = nil

    init(
        id: SpriteID,
        position: (Double, Double, Double),
        scale: (Double, Double, Double),
        size: (Double, Double),
        rotate: (Double, Double, Double),
        color: (UInt8, UInt8, UInt8, UInt8),
        speed: (Double, Double),
        texture: UnsafeMutablePointer<SDL_Texture>? = nil,
        text: String? = nil,
        font: OpaquePointer? = nil,
        sourceRect: SDL_FRect? = nil
    ) {
        self.id = id
        self.position = position
        self.color = color
        self.size = size
        self.texture = texture
        self.rotate = rotate
        self.speed = speed
        self.scale = scale
        self.text = text
        self.font = font
        self.sourceRect = sourceRect
    }
}

// --- FIX: Made class public ---
public final class SpriteManager: @unchecked Sendable {
    private var sprites: [SpriteID: Sprite] = [:]
    private let lock = NSLock()
    private var isSortNeeded = false
    private var renderList: [Sprite] = []

    // --- FIX: Added public init ---
    public init() {}

    func addSprite(_ spriteEvent: PackedSpriteAddEvent) {
        lock.lock()
        defer { lock.unlock() }

        let spriteID = SpriteID(id1: spriteEvent.id1, id2: spriteEvent.id2)
        let newSprite = Sprite(
            id: spriteID,
            position: (spriteEvent.positionX, spriteEvent.positionY, spriteEvent.positionZ),
            scale: (spriteEvent.scaleX, spriteEvent.scaleY, spriteEvent.scaleZ),
            size: (spriteEvent.sizeW, spriteEvent.sizeH),
            rotate: (spriteEvent.rotationX, spriteEvent.rotationY, spriteEvent.rotationZ),
            color: (spriteEvent.r, spriteEvent.b, spriteEvent.g, spriteEvent.a),
            speed: (spriteEvent.speedX, spriteEvent.speedY),
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
        lock.lock()
        defer { lock.unlock() }

        // 1. Remove from the main map
        if sprites.removeValue(forKey: id) != nil {
            // 2. Remove from the rendering list
            renderList.removeAll(where: { $0.id == id })

            // NOTE: We don't destroy the texture here; the Engine manages texture caching.

            // We assume removal means deletion, so a Z-order sort may be needed.
            isSortNeeded = true

            // Send event to PhysicsManager if one exists on the engine, but since this is
            // SpriteManager, it should only manage sprites. PhysicsManager must listen/handle.
        } else {
            print(
                "SpriteManager Warning: Attempted to remove non-existent sprite ID (\(id.id1), \(id.id2))"
            )
        }
    }

    // func addRawSprite(_ sprite: Sprite) {
    //     print(1);
    //     lock.lock()
    //     defer { lock.unlock() }

    //     print(2);
    //     sprites[sprite.id] = sprite
    //     print(3);
    //     renderList.append(sprite)
    //     print(4);
    //     isSortNeeded = true
    //     print(5);
    // }

    func addRawSprite(_ sprite: Sprite) {
        print(1);
            lock.lock()
            defer { lock.unlock() }

                    print(2);

            // WORKAROUND: Windows ARM64 Alignment Crash
            // Instead of writing directly to the dictionary property, copy it to a local variable,
            // modify the local variable, and assign it back. This forces a clean memory re-layout.
            var tempSprites = self.sprites
            print(3);
            tempSprites[sprite.id] = sprite
            print(4);
            self.sprites = tempSprites
            print(6);

            renderList.append(sprite)
            print(7);
            isSortNeeded = true
            print(8);
        }

    func getSprite(for id: SpriteID) -> Sprite? {
        lock.lock()
        defer { lock.unlock() }
        return sprites[id]
    }

    func moveSprite(_ id: SpriteID, _ position: (Double, Double, Double)) {
        lock.lock()
        defer { lock.unlock() }

        if let sprite = sprites[id] {
            // Check if the Z position changed
            if sprite.position.2 != position.2 {
                isSortNeeded = true
            }

            // Set the new position
            sprite.position = position
        }
    }

    func scaleSprite(_ id: SpriteID, _ scale: (Double, Double, Double)) {
        lock.lock()
        defer { lock.unlock() }
        sprites[id]?.scale = scale
    }

    func resizeSprite(_ id: SpriteID, _ size: (Double, Double)) {
        lock.lock()
        defer { lock.unlock() }
        sprites[id]?.size = size
    }

    func colorSprite(_ id: SpriteID, _ color: (UInt8, UInt8, UInt8, UInt8)) {
        lock.lock()
        defer { lock.unlock() }
        sprites[id]?.color = color
    }

    func rotateSprite(_ id: SpriteID, _ rotate: (Double, Double, Double)) {
        lock.lock()
        defer { lock.unlock() }
        sprites[id]?.rotate = rotate
    }

    func speedSprite(_ id: SpriteID, _ speed: (Double, Double)) {
        // lock.lock()
        // defer { lock.unlock() }
        sprites[id]?.speed = speed
    }

    // This function provides a snapshot of the sprites for rendering.
    func getSpritesForRendering() -> [Sprite] {
        lock.lock()
        defer { lock.unlock() }

        // Check if the list needs sorting
        if isSortNeeded {
            // Sort the internal renderList in-place
            renderList.sort(by: { $0.position.2 < $1.position.2 })

            // Reset the flag
            isSortNeeded = false
        }

        // Return a copy of the (now-guaranteed-sorted) list
        // Returning a copy is important for thread-safety
        return renderList
    }

    func setTexture(for id: SpriteID, texture: UnsafeMutablePointer<SDL_Texture>?) {
        // This logic assumes your 'sprites' dictionary stores CLASSES
        lock.lock()
        defer { lock.unlock() }

        if let sprite = sprites[id] {
            sprite.texture = texture
        } else {
            print(
                "SpriteManager Error: Attempted to set texture for unknown sprite ID (\(id.id1), \(id.id2))"
            )
        }
    }

    func setSourceRect(_ id: SpriteID, _ rect: (Float, Float, Float, Float)) {
        lock.lock()
        defer { lock.unlock() }

        if let sprite = sprites[id] {
            // If width or height is 0 or less, treat it as "no source rect"
            if rect.2 <= 0 || rect.3 <= 0 {
                sprite.sourceRect = nil
            } else {
                sprite.sourceRect = SDL_FRect(x: rect.0, y: rect.1, w: rect.2, h: rect.3)
            }
        }
    }

    func plugin(for id: SpriteID, dt: Double) {
        lock.lock()
        defer { lock.unlock() }

        // --- FIX: Change 'var sprite' to 'let sprite' ---
        if let sprite = sprites[id] {
            sprite.position.0 += sprite.speed.0 * dt
            sprite.position.1 += sprite.speed.1 * dt

            let new_x = sprite.position.0 + 16
            let new_y = sprite.position.1 + 16

            if new_x > 800 - 12 || new_x < 12 {
                sprite.speed.0 *= -1
            }
            if new_y > 450 - 16 || new_y < 16 {
                sprite.speed.1 *= -1
            }

        }
    }
}

// =========================================================================
// MARK: - Geometry Manager
// =========================================================================

public enum PrimitiveType: UInt32 {
    case point = 0
    case line = 1
    case rect = 2
    case fillRect = 3
    case points = 4
    case lines = 5
    case rects = 6
    case fillRects = 7
}

/// Represents a renderable primitive object
public final class RenderPrimitive: @unchecked Sendable {
    public var id: SpriteID
    public var type: PrimitiveType
    public var z: Double
    public var color: (UInt8, UInt8, UInt8, UInt8)
    public var isScreenSpace: Bool  // <-- MODIFIED

    // Data payload. We use arrays for all types for consistency.
    public var points: [SDL_FPoint] = []
    public var rects: [SDL_FRect] = []

    init(
        id: SpriteID, type: PrimitiveType, z: Double,
        color: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        isScreenSpace: Bool  // <-- MODIFIED
    ) {
        self.id = id
        self.type = type
        self.z = z
        self.color = color
        self.isScreenSpace = isScreenSpace  // <-- MODIFIED
    }
}

/// Manages all non-sprite renderable geometry
public final class GeometryManager: @unchecked Sendable {
    private var primitives: [SpriteID: RenderPrimitive] = [:]
    private let lock = NSLock()
    private var isSortNeeded = false
    private var renderList: [RenderPrimitive] = []

    public init() {}

    private func addPrimitive(_ primitive: RenderPrimitive) {
        // lock.lock()
        // defer { lock.unlock() }
        primitives[primitive.id] = primitive
        renderList.append(primitive)
        isSortNeeded = true
    }

    public func removePrimitive(id: SpriteID) {
        // lock.lock()
        // defer { lock.unlock() }
        if primitives.removeValue(forKey: id) != nil {
            renderList.removeAll(where: { $0.id == id })
            isSortNeeded = true
        }
    }

    public func setPrimitiveColor(id: SpriteID, color: (UInt8, UInt8, UInt8, UInt8)) {
        // lock.lock()
        // defer { lock.unlock() }
        primitives[id]?.color = color
    }

    public func addPoint(event: PackedGeomAddPointEvent) {
        let id = SpriteID(id1: event.id1, id2: event.id2)
        let color = (event.r, event.g, event.b, event.a)
        let primitive = RenderPrimitive(
            id: id, type: .point, z: event.z, color: color,
            isScreenSpace: event.isScreenSpace == 1  // <-- MODIFIED
        )
        primitive.points = [SDL_FPoint(x: event.x, y: event.y)]
        addPrimitive(primitive)
    }

    public func addLine(event: PackedGeomAddLineEvent) {
        let id = SpriteID(id1: event.id1, id2: event.id2)
        let color = (event.r, event.g, event.b, event.a)
        let primitive = RenderPrimitive(
            id: id, type: .line, z: event.z, color: color,
            isScreenSpace: event.isScreenSpace == 1  // <-- MODIFIED
        )
        primitive.points = [
            SDL_FPoint(x: event.x1, y: event.y1),
            SDL_FPoint(x: event.x2, y: event.y2),
        ]
        addPrimitive(primitive)
    }

    public func addRect(event: PackedGeomAddRectEvent, isFilled: Bool) {
        let id = SpriteID(id1: event.id1, id2: event.id2)
        let color = (event.r, event.g, event.b, event.a)
        let type: PrimitiveType = isFilled ? .fillRect : .rect
        let primitive = RenderPrimitive(
            id: id, type: type, z: event.z, color: color,
            isScreenSpace: event.isScreenSpace == 1  // <-- MODIFIED
        )
        primitive.rects = [SDL_FRect(x: event.x, y: event.y, w: event.w, h: event.h)]
        addPrimitive(primitive)
    }

    public func addPacked(header: PackedGeomAddPackedHeaderEvent, data: Data) {
        guard let type = PrimitiveType(rawValue: header.primitiveType) else {
            print("GeometryManager Error: Unknown primitive type \(header.primitiveType)")
            return
        }
        let id = SpriteID(id1: header.id1, id2: header.id2)
        let color = (header.r, header.g, header.b, header.a)
        let primitive = RenderPrimitive(
            id: id, type: type, z: header.z, color: color,
            isScreenSpace: header.isScreenSpace == 1  // <-- MODIFIED
        )

        switch type {
        case .points, .lines:
            let elementSize = MemoryLayout<SDL_FPoint>.stride
            let expectedCount = Int(header.count)
            guard data.count == expectedCount * elementSize else {
                print(
                    "GeometryManager Error: Data size mismatch for points. Expected \(expectedCount * elementSize), got \(data.count)"
                )
                return
            }
            primitive.points = data.withUnsafeBytes {
                Array($0.bindMemory(to: SDL_FPoint.self))
            }
        case .rects, .fillRects:
            let elementSize = MemoryLayout<SDL_FRect>.stride
            let expectedCount = Int(header.count)
            guard data.count == expectedCount * elementSize else {
                print(
                    "GeometryManager Error: Data size mismatch for rects. Expected \(expectedCount * elementSize), got \(data.count)"
                )
                return
            }
            primitive.rects = data.withUnsafeBytes {
                Array($0.bindMemory(to: SDL_FRect.self))
            }
        default:
            print("GeometryManager Error: addPacked called with non-packed type \(type)")
            return
        }

        addPrimitive(primitive)
    }

    public func getPrimitivesForRendering() -> [RenderPrimitive] {
        // lock.lock()
        // defer { lock.unlock() }
        if isSortNeeded {
            renderList.sort(by: { $0.z < $1.z })
            isSortNeeded = false
        }
        return renderList
    }
}
