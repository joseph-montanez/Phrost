import Foundation
import SwiftChipmunk2D  // Or CChipmunk2D

extension PhrostEngine {

    // Logic for .physicsAddBody extracted from processCommands
    internal func handlePhysicsAddBodyCommand(event: PackedPhysicsAddBodyEvent) {
        let spriteID = SpriteID(id1: event.id1, id2: event.id2)
        let sprite = spriteManager.getSprite(for: spriteID)

        if event.bodyType == 0 && sprite == nil {
            print(
                "Physics Add Body Error: Dynamic body for Sprite requires a sprite, but sprite does not exist."
            )
            return
        }

        self.physicsManager.addBody(
            id: spriteID,
            sprite: sprite,
            position: (event.positionX, event.positionY),
            bodyType: event.bodyType,
            shapeType: event.shapeType,
            mass: event.mass,
            friction: event.friction,
            elasticity: event.elasticity,
            width: event.width,
            height: event.height,
            lockRotation: event.lockRotation
        )
    }

    internal func handlePhysicsSetDebugModeCommand(event: PackedPhysicsSetDebugModeEvent) {
        self.physicsManager.setDebugMode(event.enabled > 0)
    }
}
