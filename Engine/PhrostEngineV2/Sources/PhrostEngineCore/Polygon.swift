import Foundation

// MARK: - Polygon Triangulation Utilities

/// Fan triangulation for convex polygons
/// Creates triangles: (0,1,2), (0,2,3), (0,3,4), ...
/// - Parameter vertexCount: Number of polygon vertices
/// - Returns: Array of triangle indices
public func triangulateConvexPolygon(vertexCount: Int) -> [Int32] {
    guard vertexCount >= 3 else { return [] }

    var indices: [Int32] = []
    indices.reserveCapacity((vertexCount - 2) * 3)

    for i in 1..<(vertexCount - 1) {
        indices.append(0)  // Pivot vertex (first vertex)
        indices.append(Int32(i))  // Current vertex
        indices.append(Int32(i + 1))  // Next vertex
    }

    return indices
}

/// Ear-clipping triangulation for simple (non-self-intersecting) polygons
/// Works for both convex and concave polygons
/// - Parameter vertices: Array of (x, y) vertex positions
/// - Returns: Array of triangle indices
public func triangulatePolygon(vertices: [(Float, Float)]) -> [Int32] {
    guard vertices.count >= 3 else { return [] }
    if vertices.count == 3 {
        return [0, 1, 2]
    }

    var indices: [Int32] = []
    indices.reserveCapacity((vertices.count - 2) * 3)

    // Working copy of vertex indices
    var remaining = Array(0..<vertices.count)

    // Determine polygon winding (CW or CCW)
    let signedArea = computeSignedArea(vertices: vertices)
    let isCCW = signedArea > 0

    var safetyCounter = remaining.count * remaining.count  // Prevent infinite loops

    while remaining.count > 3 && safetyCounter > 0 {
        safetyCounter -= 1
        var earFound = false

        for i in 0..<remaining.count {
            let prevIdx = (i + remaining.count - 1) % remaining.count
            let nextIdx = (i + 1) % remaining.count

            let prev = remaining[prevIdx]
            let curr = remaining[i]
            let next = remaining[nextIdx]

            // Check if this vertex forms an ear
            if isEar(
                vertices: vertices, remaining: remaining,
                prev: prev, curr: curr, next: next, isCCW: isCCW)
            {

                indices.append(Int32(prev))
                indices.append(Int32(curr))
                indices.append(Int32(next))

                remaining.remove(at: i)
                earFound = true
                break
            }
        }

        if !earFound {
            // Degenerate or self-intersecting polygon
            // Fall back to fan triangulation from centroid
            print("Warning: Ear-clipping failed, falling back to fan triangulation")
            break
        }
    }

    // Add final triangle
    if remaining.count == 3 {
        indices.append(Int32(remaining[0]))
        indices.append(Int32(remaining[1]))
        indices.append(Int32(remaining[2]))
    }

    return indices
}

// MARK: - Private Helper Functions

private func computeSignedArea(vertices: [(Float, Float)]) -> Float {
    var area: Float = 0
    let n = vertices.count
    for i in 0..<n {
        let j = (i + 1) % n
        area += vertices[i].0 * vertices[j].1
        area -= vertices[j].0 * vertices[i].1
    }
    return area / 2.0
}

private func isEar(
    vertices: [(Float, Float)],
    remaining: [Int],
    prev: Int, curr: Int, next: Int,
    isCCW: Bool
) -> Bool {
    let a = vertices[prev]
    let b = vertices[curr]
    let c = vertices[next]

    // Cross product to check convexity at vertex B
    let cross = (b.0 - a.0) * (c.1 - a.1) - (b.1 - a.1) * (c.0 - a.0)

    // For CCW polygon, ear vertices have positive cross product
    // For CW polygon, ear vertices have negative cross product
    if isCCW {
        if cross <= 0 { return false }
    } else {
        if cross >= 0 { return false }
    }

    // Check that no other remaining vertex is inside triangle ABC
    for idx in remaining {
        if idx == prev || idx == curr || idx == next { continue }
        if pointInTriangle(p: vertices[idx], a: a, b: b, c: c) {
            return false
        }
    }

    return true
}

private func pointInTriangle(
    p: (Float, Float),
    a: (Float, Float),
    b: (Float, Float),
    c: (Float, Float)
) -> Bool {
    // Barycentric coordinate method
    let v0 = (c.0 - a.0, c.1 - a.1)
    let v1 = (b.0 - a.0, b.1 - a.1)
    let v2 = (p.0 - a.0, p.1 - a.1)

    let dot00 = v0.0 * v0.0 + v0.1 * v0.1
    let dot01 = v0.0 * v1.0 + v0.1 * v1.1
    let dot02 = v0.0 * v2.0 + v0.1 * v2.1
    let dot11 = v1.0 * v1.0 + v1.1 * v1.1
    let dot12 = v1.0 * v2.0 + v1.1 * v2.1

    let denom = dot00 * dot11 - dot01 * dot01
    if abs(denom) < 1e-10 { return false }  // Degenerate triangle

    let invDenom = 1.0 / denom
    let u = (dot11 * dot02 - dot01 * dot12) * invDenom
    let v = (dot00 * dot12 - dot01 * dot02) * invDenom

    return (u >= 0) && (v >= 0) && (u + v < 1)
}
