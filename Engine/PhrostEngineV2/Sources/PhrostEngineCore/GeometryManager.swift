import Foundation
import SwiftSDL

public final class GeometryManager: @unchecked Sendable {
    private var primitives: [SpriteID: RenderPrimitive] = [:]
    private var isSortNeeded = false
    private var renderList: [RenderPrimitive] = []

    public init() {}

    private func addPrimitive(_ primitive: RenderPrimitive) {
        primitives[primitive.id] = primitive
        renderList.append(primitive)
        isSortNeeded = true
    }

    public func removePrimitive(id: SpriteID) {
        if primitives.removeValue(forKey: id) != nil {
            renderList.removeAll(where: { $0.id == id })
            isSortNeeded = true
        }
    }

    public func setPrimitiveColor(id: SpriteID, color: (UInt8, UInt8, UInt8, UInt8)) {
        primitives[id]?.color = ColorRGBA(color.0, color.1, color.2, color.3)
    }

    public func addPoint(event: PackedGeomAddPointEvent) {
        let id = SpriteID(id1: event.id1, id2: event.id2)
        let color = (event.r, event.g, event.b, event.a)
        let primitive = RenderPrimitive(
            id: id, type: .point, z: event.z, color: color, isScreenSpace: event.isScreenSpace == 1)
        primitive.points = [SDL_FPoint(x: event.x, y: event.y)]
        addPrimitive(primitive)
    }

    public func addLine(event: PackedGeomAddLineEvent) {
        let id = SpriteID(id1: event.id1, id2: event.id2)
        let color = (event.r, event.g, event.b, event.a)
        let primitive = RenderPrimitive(
            id: id, type: .line, z: event.z, color: color, isScreenSpace: event.isScreenSpace == 1)
        primitive.points = [
            SDL_FPoint(x: event.x1, y: event.y1), SDL_FPoint(x: event.x2, y: event.y2),
        ]
        addPrimitive(primitive)
    }

    public func addRect(event: PackedGeomAddRectEvent, isFilled: Bool) {
        let id = SpriteID(id1: event.id1, id2: event.id2)
        let color = (event.r, event.g, event.b, event.a)
        let type: PrimitiveType = isFilled ? .fillRect : .rect
        let primitive = RenderPrimitive(
            id: id, type: type, z: event.z, color: color, isScreenSpace: event.isScreenSpace == 1)
        primitive.rects = [SDL_FRect(x: event.x, y: event.y, w: event.w, h: event.h)]
        addPrimitive(primitive)
    }

    public func addPacked(header: PackedGeomAddPackedHeaderEvent, data: Data) {
        guard let type = PrimitiveType(rawValue: header.primitiveType) else { return }
        let id = SpriteID(id1: header.id1, id2: header.id2)
        let color = (header.r, header.g, header.b, header.a)
        let primitive = RenderPrimitive(
            id: id, type: type, z: header.z, color: color, isScreenSpace: header.isScreenSpace == 1)

        switch type {
        case .points, .lines:
            primitive.points = data.withUnsafeBytes { Array($0.bindMemory(to: SDL_FPoint.self)) }
        case .rects, .fillRects:
            primitive.rects = data.withUnsafeBytes { Array($0.bindMemory(to: SDL_FRect.self)) }
        default: return
        }
        addPrimitive(primitive)
    }

    public func getPrimitivesForRendering() -> [RenderPrimitive] {
        if isSortNeeded {
            renderList.sort(by: { $0.z < $1.z })
            isSortNeeded = false
        }
        return renderList
    }

    /// Adds a polygon primitive from packed vertex data
    /// - Parameters:
    ///   - id1: First part of sprite ID
    ///   - id2: Second part of sprite ID
    ///   - z: Z-depth for sorting
    ///   - color: RGBA color tuple
    ///   - isScreenSpace: Whether coordinates are screen-space or world-space
    ///   - isFilled: Whether to render filled or outline only
    ///   - vertexData: Raw vertex data (Float pairs: x1,y1,x2,y2,...)
    ///   - vertexCount: Number of vertices
    public func addPolygon(
        id1: Int64,
        id2: Int64,
        z: Double,
        color: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        isScreenSpace: Bool,
        isFilled: Bool,
        vertexData: Data,
        vertexCount: Int
    ) {
        let id = SpriteID(id1: id1, id2: id2)
        let type: PrimitiveType = isFilled ? .polygon : .polygonOutline

        let primitive = RenderPrimitive(
            id: id,
            type: type,
            z: z,
            color: color,
            isScreenSpace: isScreenSpace
        )

        // Parse vertex data
        var rawPoints: [(Float, Float)] = []
        rawPoints.reserveCapacity(vertexCount)

        vertexData.withUnsafeBytes { buffer in
            guard buffer.count >= vertexCount * 8 else {
                print(
                    "Polygon Error: Vertex data too short. Expected \(vertexCount * 8), got \(buffer.count)"
                )
                return
            }

            for i in 0..<vertexCount {
                let x = buffer.load(fromByteOffset: i * 8, as: Float.self)
                let y = buffer.load(fromByteOffset: i * 8 + 4, as: Float.self)
                rawPoints.append((x, y))
            }
        }

        guard rawPoints.count == vertexCount else {
            print("Polygon Error: Failed to parse all vertices")
            return
        }

        if isFilled {
            // Create SDL_Vertex array for SDL_RenderGeometry
            let sdlColor = SDL_FColor(
                r: Float(color.r) / 255.0,
                g: Float(color.g) / 255.0,
                b: Float(color.b) / 255.0,
                a: Float(color.a) / 255.0
            )

            primitive.vertices = rawPoints.map { pt in
                SDL_Vertex(
                    position: SDL_FPoint(x: pt.0, y: pt.1),
                    color: sdlColor,
                    tex_coord: SDL_FPoint(x: 0, y: 0)
                )
            }

            // Triangulate the polygon
            // Use simple fan triangulation for convex, ear-clipping for complex
            if vertexCount <= 6 {
                // Small polygon, use fast fan triangulation (assumes convex)
                primitive.indices = triangulateConvexPolygon(vertexCount: vertexCount)
            } else {
                // Larger polygon, use ear-clipping for safety
                primitive.indices = triangulatePolygon(vertices: rawPoints)
            }
        } else {
            // For outline, store points for SDL_RenderLines
            primitive.points = rawPoints.map { SDL_FPoint(x: $0.0, y: $0.1) }

            // Close the polygon by appending the first point
            if let first = rawPoints.first {
                primitive.points.append(SDL_FPoint(x: first.0, y: first.1))
            }
        }

        addPrimitive(primitive)
    }
}
