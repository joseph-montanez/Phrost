import Foundation
import SwiftChipmunk2D
import SwiftSDL

// Helper class to store in Chipmunk's 'userData' pointer
private class PhysicsDataLink: @unchecked Sendable {
    let id: SpriteID
    init(id: SpriteID) { self.id = id }
}

public final class PhysicsManager: @unchecked Sendable {

    private let space: UnsafeMutablePointer<cpSpace>
    private let spriteManager: SpriteManager
    public var isDebugDrawEnabled: Bool = false

    private var physicsLinks:
        [SpriteID: (
            body: UnsafeMutablePointer<cpBody>,
            shape: UnsafeMutablePointer<cpShape>,
            link: PhysicsDataLink
        )] = [:]

    private let eventsLock = NSLock()
    private var generatedEventData = Data()
    private var generatedEventCount: UInt32 = 0

    public init(spriteManager: SpriteManager) {
        self.spriteManager = spriteManager

        self.space = UnsafeMutableRawPointer(cpSpaceNew()!).bindMemory(
            to: cpSpace.self, capacity: 1)

        cpSpaceSetGravity(OpaquePointer(self.space), cpVect(x: 0, y: 980))  // Example gravity

        setupCollisionHandlers()
        print("PhysicsManager Initialized Successfully")
    }

    deinit {
        print("Cleaning up PhysicsManager...")
        for id in physicsLinks.keys {
            removeBody(id: id)
        }
        cpSpaceFree(OpaquePointer(space))
        print("PhysicsManager Cleaned up.")
    }

    public func setDebugMode(_ enabled: Bool) {
        self.isDebugDrawEnabled = enabled
        print("Physics Debug Mode set to: \(enabled)")
    }

    public func debugDraw(
        renderer: OpaquePointer,
        camX: Double,
        camY: Double,
        camZoom: Double,
        screenW: Double,
        screenH: Double
    ) {
        guard isDebugDrawEnabled else { return }

        // Set Draw Color to Bright Green for visibility
        SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255)

        let halfScreenX = screenW / 2.0
        let halfScreenY = screenH / 2.0

        // Helper to transform World -> Screen
        func toScreen(x: Double, y: Double) -> (Float, Float) {
            let relX = (x - camX) * camZoom
            let relY = (y - camY) * camZoom
            return (Float(relX + halfScreenX), Float(relY + halfScreenY))
        }

        // Iterate over all tracked bodies
        for (_, tuple) in physicsLinks {
            let body = tuple.body
            let shape = tuple.shape

            // 1. Draw Bounding Box (AABB)
            let bb = cpShapeGetBB(OpaquePointer(shape))

            let (tlX, tlY) = toScreen(x: bb.l, y: bb.t)  // Top-Left
            let (brX, brY) = toScreen(x: bb.r, y: bb.b)  // Bottom-Right

            // Calculate width/height based on screen coordinates
            let w = brX - tlX
            let h = brY - tlY

            var rect = SDL_FRect(x: tlX, y: tlY, w: w, h: h)
            SDL_RenderRect(renderer, &rect)

            // 2. Draw Rotation Vector (Line from center to show angle)
            let pos = cpBodyGetPosition(OpaquePointer(body))
            let angle = cpBodyGetAngle(OpaquePointer(body))

            // Calculate a point 20 units away in the direction of rotation
            let lineLen: Double = 20.0
            let endX = pos.x + cos(angle) * lineLen
            let endY = pos.y + sin(angle) * lineLen

            let (startX, startY) = toScreen(x: pos.x, y: pos.y)
            let (screenEndX, screenEndY) = toScreen(x: endX, y: endY)

            SDL_RenderLine(renderer, startX, startY, screenEndX, screenEndY)
        }
    }

    /// Called from Engine.swift's run loop
    public func step(dt: Double) {
        cpSpaceStep(OpaquePointer(space), dt)
    }

    /// Called from Engine.swift's run loop *after* step()
    public func syncPhysicsToSprites() {
        for (id, link) in physicsLinks {
            guard cpBodyGetType(OpaquePointer(link.body)) == CP_BODY_TYPE_DYNAMIC else { continue }

            if let sprite = spriteManager.getSprite(for: id) {
                let pos = cpBodyGetPosition(OpaquePointer(link.body))
                let vel = cpBodyGetVelocity(OpaquePointer(link.body))
                let angle = cpBodyGetAngle(OpaquePointer(link.body))
                let angularVel = cpBodyGetAngularVelocity(OpaquePointer(link.body))
                let sleeping = cpBodyIsSleeping(OpaquePointer(link.body))

                // Update the sprite object directly using new Vec3 structs
                sprite.position = Vec3(pos.x, pos.y, sprite.position.z)
                sprite.rotate = Vec3(sprite.rotate.x, sprite.rotate.y, angle * 180.0 / .pi)

                // Trigger
                queueSyncEvent(
                    id: id,
                    pos: pos,
                    vel: vel,
                    angle: angle,
                    angularVelocity: angularVel,
                    isSleeping: sleeping
                )
            }
        }
    }

    /// Called from Engine.swift's run loop to get collision events
    public func drainGeneratedEvents() -> (Data, UInt32) {
        eventsLock.lock()
        defer { eventsLock.unlock() }

        let data = generatedEventData
        let count = generatedEventCount

        if count > 0 {
            generatedEventData.removeAll(keepingCapacity: true)
            generatedEventCount = 0
        }

        return (data, count)
    }

    public func addBody(
        id: SpriteID,
        sprite: Sprite?,
        position: (Double, Double),
        bodyType: UInt8,
        shapeType: UInt8,
        mass: Double,
        friction: Double,
        elasticity: Double,
        width: Double,
        height: Double,
        lockRotation: UInt8
    ) {
        guard physicsLinks[id] == nil else {
            print("Physics Warning: Body for sprite \(id) already exists.")
            return
        }

        let cpBodyType = (bodyType == 1) ? CP_BODY_TYPE_STATIC : CP_BODY_TYPE_DYNAMIC

        let body: UnsafeMutablePointer<cpBody>
        if cpBodyType == CP_BODY_TYPE_DYNAMIC {
            let moment: Double
            if lockRotation == 1 {
                moment = Double.infinity
            } else {
                moment =
                    (shapeType == 0)
                    ? cpMomentForBox(mass, width, height)
                    : cpMomentForCircle(mass, 0, width, cpVect(x: 0, y: 0))
            }
            body = UnsafeMutableRawPointer(cpBodyNew(mass, moment)!).bindMemory(
                to: cpBody.self, capacity: 1)
        } else {
            body = UnsafeMutableRawPointer(cpBodyNewStatic()!).bindMemory(
                to: cpBody.self, capacity: 1)
        }

        cpBodySetPosition(OpaquePointer(body), cpVect(x: position.0, y: position.1))

        cpSpaceAddBody(OpaquePointer(space), OpaquePointer(body))

        let shape: UnsafeMutablePointer<cpShape>
        if shapeType == 0 {  // Box
            shape = UnsafeMutableRawPointer(cpBoxShapeNew(OpaquePointer(body), width, height, 0.0)!)
                .bindMemory(to: cpShape.self, capacity: 1)
        } else {  // Circle
            shape = UnsafeMutableRawPointer(
                cpCircleShapeNew(OpaquePointer(body), width, cpVect(x: 0, y: 0))!
            ).bindMemory(to: cpShape.self, capacity: 1)
        }

        cpShapeSetFriction(OpaquePointer(shape), friction)
        cpShapeSetElasticity(OpaquePointer(shape), elasticity)

        let link = PhysicsDataLink(id: id)
        let pointer = Unmanaged.passUnretained(link).toOpaque()
        cpShapeSetUserData(OpaquePointer(shape), pointer)  // Store our link in the shape

        cpSpaceAddShape(OpaquePointer(space), OpaquePointer(shape))

        physicsLinks[id] = (body, shape, link)
    }

    public func removeBody(id: SpriteID) {
        guard let link = physicsLinks.removeValue(forKey: id) else { return }

        cpSpaceRemoveShape(OpaquePointer(space), OpaquePointer(link.shape))
        cpSpaceRemoveBody(OpaquePointer(space), OpaquePointer(link.body))

        cpShapeFree(OpaquePointer(link.shape))
        cpBodyFree(OpaquePointer(link.body))

    }

    public func applyForce(id: SpriteID, force: cpVect) {
        guard let link = physicsLinks[id] else { return }
        cpBodyApplyForceAtLocalPoint(OpaquePointer(link.body), force, cpVect(x: 0, y: 0))
    }

    public func applyImpulse(id: SpriteID, impulse: cpVect) {
        guard let link = physicsLinks[id] else { return }
        cpBodyApplyImpulseAtLocalPoint(OpaquePointer(link.body), impulse, cpVect(x: 0, y: 0))
    }

    public func setVelocity(id: SpriteID, velocity: cpVect) {
        guard let link = physicsLinks[id] else { return }
        cpBodySetVelocity(OpaquePointer(link.body), velocity)
    }

    public func setPosition(id: SpriteID, position: cpVect) {
        guard let link = physicsLinks[id] else { return }
        cpBodySetPosition(OpaquePointer(link.body), position)
        cpSpaceReindexShapesForBody(OpaquePointer(space), OpaquePointer(link.body))
    }

    public func setRotation(id: SpriteID, angleInRadians: Double) {
        guard let link = physicsLinks[id] else { return }
        cpBodySetAngle(OpaquePointer(link.body), angleInRadians)
    }

    private func setupCollisionHandlers() {
        guard let handlerOpaque = cpSpaceAddDefaultCollisionHandler(OpaquePointer(space)) else {
            print("Physics Error: Failed to add default collision handler.")
            return
        }
        let handler = UnsafeMutableRawPointer(handlerOpaque).bindMemory(
            to: cpCollisionHandler.self, capacity: 1)

        handler.pointee.userData = Unmanaged.passUnretained(self).toOpaque()

        handler.pointee.beginFunc = {
            (
                arbiterOpaque: OpaquePointer?,
                spaceOpaque: OpaquePointer?,
                userData: UnsafeMutableRawPointer?
            ) -> cpBool in
            // Reconstruct self
            guard
                let manager = userData.map({
                    Unmanaged<PhysicsManager>.fromOpaque($0).takeUnretainedValue()
                })
            else { return 1 }

            // --- Use temporary OpaquePointers for inout args ---
            var opaqueShapeA: OpaquePointer? = nil
            var opaqueShapeB: OpaquePointer? = nil
            cpArbiterGetShapes(arbiterOpaque, &opaqueShapeA, &opaqueShapeB)

            let shapeA = opaqueShapeA.map {
                UnsafeMutableRawPointer($0).bindMemory(to: cpShape.self, capacity: 1)
            }
            let shapeB = opaqueShapeB.map {
                UnsafeMutableRawPointer($0).bindMemory(to: cpShape.self, capacity: 1)
            }

            // Get our 'PhysicsDataLink' from the shapes
            guard
                let linkA = shapeA.flatMap({ cpShapeGetUserData(OpaquePointer($0)) }).map({
                    Unmanaged<PhysicsDataLink>.fromOpaque($0).takeUnretainedValue()
                }),
                let linkB = shapeB.flatMap({ cpShapeGetUserData(OpaquePointer($0)) }).map({
                    Unmanaged<PhysicsDataLink>.fromOpaque($0).takeUnretainedValue()
                })
            else { return 1 }

            // Queue the event
            manager.queueCollisionEvent(idA: linkA.id, idB: linkB.id, type: .physicsCollisionBegin)

            return 1  // true, process the collision
        }

        handler.pointee.separateFunc = {
            (
                arbiterOpaque: OpaquePointer?,
                spaceOpaque: OpaquePointer?,
                userData: UnsafeMutableRawPointer?
            ) in
            // Reconstruct self
            guard
                let manager = userData.map({
                    Unmanaged<PhysicsManager>.fromOpaque($0).takeUnretainedValue()
                })
            else { return }

            var opaqueShapeA: OpaquePointer? = nil
            var opaqueShapeB: OpaquePointer? = nil
            cpArbiterGetShapes(arbiterOpaque, &opaqueShapeA, &opaqueShapeB)

            let shapeA = opaqueShapeA.map {
                UnsafeMutableRawPointer($0).bindMemory(to: cpShape.self, capacity: 1)
            }
            let shapeB = opaqueShapeB.map {
                UnsafeMutableRawPointer($0).bindMemory(to: cpShape.self, capacity: 1)
            }

            guard
                let linkA = shapeA.flatMap({ cpShapeGetUserData(OpaquePointer($0)) }).map({
                    Unmanaged<PhysicsDataLink>.fromOpaque($0).takeUnretainedValue()
                }),
                let linkB = shapeB.flatMap({ cpShapeGetUserData(OpaquePointer($0)) }).map({
                    Unmanaged<PhysicsDataLink>.fromOpaque($0).takeUnretainedValue()
                })
            else { return }

            // Queue the event
            manager.queueCollisionEvent(
                idA: linkA.id, idB: linkB.id, type: .physicsCollisionSeparate)
        }
    }

    private func queueCollisionEvent(idA: SpriteID, idB: SpriteID, type: Events) {
        let event = PackedPhysicsCollisionEvent(
            id1_A: idA.id1, id2_A: idA.id2,
            id1_B: idB.id1, id2_B: idB.id2
        )

        let uptimeNanos = DispatchTime.now().uptimeNanoseconds
        let timestamp = UInt64(truncatingIfNeeded: uptimeNanos / 1_000_000)

        eventsLock.lock()
        // HEADER (16 bytes): ID(4) + Time(8) + Pad(4)
        generatedEventData.append(value: type.rawValue)
        generatedEventData.append(value: timestamp)
        generatedEventData.append(Data(count: 4))  // ALIGNMENT FIX: Padding

        // PAYLOAD (32 bytes): Aligned
        generatedEventData.append(value: event)

        generatedEventCount &+= 1
        eventsLock.unlock()
    }

    private func queueSyncEvent(
        id: SpriteID,
        pos: cpVect,
        vel: cpVect,
        angle: Double,
        angularVelocity: Double,
        isSleeping: cpBool
    ) {
        let event = PackedPhysicsSyncTransformEvent(
            id1: id.id1, id2: id.id2,
            positionX: pos.x,
            positionY: pos.y,
            angle: angle,
            velocityX: vel.x,
            velocityY: vel.y,
            angularVelocity: angularVelocity,
            isSleeping: isSleeping,
            _padding: (0, 0, 0, 0, 0, 0, 0)
        )

        let uptimeNanos = DispatchTime.now().uptimeNanoseconds
        let timestamp = UInt64(truncatingIfNeeded: uptimeNanos / 1_000_000)

        eventsLock.lock()
        // HEADER (16 bytes): ID(4) + Time(8) + Pad(4)
        generatedEventData.append(value: Events.physicsSyncTransform.rawValue)
        generatedEventData.append(value: timestamp)
        generatedEventData.append(Data(count: 4))  // ALIGNMENT FIX: Padding

        // PAYLOAD (64 bytes): Aligned
        generatedEventData.append(value: event)

        generatedEventCount &+= 1
        eventsLock.unlock()
    }
}
