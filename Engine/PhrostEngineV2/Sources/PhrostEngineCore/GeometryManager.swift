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

    /// Adds raw geometry primitive from vertex/index data
    /// - Parameters:
    ///   - header: The parsed header event
    ///   - vertexData: Raw vertex data containing positions, colors, and UVs
    ///   - indexData: Raw index data
    ///   - texture: Optional SDL texture pointer
    public func addRawGeometry(
        header: PackedGeomAddRawHeaderEvent,
        positionData: Data,  // float[vtxCount * 2] - x,y pairs
        colorData: Data,  // float[vtxCount * 4] - r,g,b,a (0-1 range)
        uvData: Data,  // float[vtxCount * 2] - u,v pairs
        indexData: Data,
        texture: UnsafeMutablePointer<SDL_Texture>?
    ) {
        let id = SpriteID(id1: header.id1, id2: header.id2)
        let vtxCount = Int(header.vertexCount)
        let idxCount = Int(header.indexCount)
        let idxSize = Int(header.indexSize)

        let primitive = RenderPrimitive(
            id: id,
            type: .rawGeometry,
            z: header.z,
            color: (255, 255, 255, 255),  // Colors are per-vertex
            isScreenSpace: header.isScreenSpace == 1
        )

        // Set clip rect (clipX < 0 means no clipping)
        if header.clipX >= 0 {
            primitive.clipRect = SDL_Rect(
                x: header.clipX,
                y: header.clipY,
                w: header.clipW,
                h: header.clipH
            )
        }

        primitive.texture = texture

        // Parse vertex data into SDL_Vertex array
        primitive.vertices.reserveCapacity(vtxCount)

        positionData.withUnsafeBytes { posBuffer in
            colorData.withUnsafeBytes { colBuffer in
                uvData.withUnsafeBytes { uvBuffer in
                    for i in 0..<vtxCount {
                        let px = posBuffer.load(fromByteOffset: i * 8, as: Float.self)
                        let py = posBuffer.load(fromByteOffset: i * 8 + 4, as: Float.self)

                        let cr = colBuffer.load(fromByteOffset: i * 16, as: Float.self)
                        let cg = colBuffer.load(fromByteOffset: i * 16 + 4, as: Float.self)
                        let cb = colBuffer.load(fromByteOffset: i * 16 + 8, as: Float.self)
                        let ca = colBuffer.load(fromByteOffset: i * 16 + 12, as: Float.self)

                        let tu = uvBuffer.load(fromByteOffset: i * 8, as: Float.self)
                        let tv = uvBuffer.load(fromByteOffset: i * 8 + 4, as: Float.self)

                        let vertex = SDL_Vertex(
                            position: SDL_FPoint(x: px, y: py),
                            color: SDL_FColor(r: cr, g: cg, b: cb, a: ca),
                            tex_coord: SDL_FPoint(x: tu, y: tv)
                        )
                        primitive.vertices.append(vertex)
                    }
                }
            }
        }

        // Parse indices
        primitive.indices.reserveCapacity(idxCount)
        indexData.withUnsafeBytes { idxBuffer in
            for i in 0..<idxCount {
                let idx: Int32
                if idxSize == 2 {
                    idx = Int32(idxBuffer.load(fromByteOffset: i * 2, as: UInt16.self))
                } else {
                    idx = Int32(idxBuffer.load(fromByteOffset: i * 4, as: UInt32.self))
                }
                primitive.indices.append(idx)
            }
        }

        addPrimitive(primitive)
    }
}
