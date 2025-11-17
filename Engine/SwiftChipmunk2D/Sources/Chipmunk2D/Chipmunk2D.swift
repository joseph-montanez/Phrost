#if os(Linux) || os(Windows)
    @_exported import CChipmunk2D
#else
    @_exported import Chipmunk2D
#endif

// Swift equivalent of cpBody struct
public struct cpBody {
    // Function pointers for velocity and position update functions
    public var velocity_func: cpBodyVelocityFunc?
    public var position_func: cpBodyPositionFunc?

    // Physical properties of the body
    public var m: cpFloat  // Mass
    public var m_inv: cpFloat  // Mass inverse

    public var i: cpFloat  // Moment of inertia
    public var i_inv: cpFloat  // Moment of inertia inverse

    // Position and velocity of the center of gravity
    public var p: cpVect  // Position
    public var v: cpVect  // Velocity
    public var f: cpVect  // Force

    // Rotation, angular velocity, and torque
    public var a: cpFloat  // Rotation (angle)
    public var w: cpFloat  // Angular velocity
    public var t: cpFloat  // Torque

    // Cached unit-length vector representing the body's angle
    public var rot: cpVect

    // User-defined data pointer
    public var data: cpDataPointer?

    // Maximum velocity and angular velocity
    public var v_limit: cpFloat
    public var w_limit: cpFloat

    // Private Chipmunk2D fields (optional to expose)
    private var v_bias: cpVect
    private var w_bias: cpFloat

    private var space: UnsafeMutablePointer<cpSpace>?
    private var shapeList: UnsafeMutablePointer<cpShape>?
    private var arbiterList: UnsafeMutablePointer<cpArbiter>?
    private var constraintList: UnsafeMutablePointer<cpConstraint>?

    private var node: cpComponentNode
}

public struct cpComponentNode {
    public var root: UnsafeMutablePointer<cpBody>?
    public var next: UnsafeMutablePointer<cpBody>?
    public var idleTime: cpFloat
}

public struct cpSpace {
    public var iterations: Int
    public var gravity: cpVect
    public var damping: cpFloat
    public var idleSpeedThreshold: cpFloat
    public var sleepTimeThreshold: cpFloat
    public var collisionSlop: cpFloat
    public var collisionBias: cpFloat
    public var collisionPersistence: cpTimestamp
    public var enableContactGraph: cpBool
    public var data: cpDataPointer?
    public var staticBody: UnsafeMutablePointer<cpBody>?

    // Private Fields
    public var stamp: cpTimestamp
    public var curr_dt: cpFloat
    public var bodies: UnsafeMutablePointer<cpArray>?
    public var rousedBodies: UnsafeMutablePointer<cpArray>?
    public var sleepingComponents: UnsafeMutablePointer<cpArray>?
    public var staticShapes: UnsafeMutablePointer<cpSpatialIndex>?
    public var activeShapes: UnsafeMutablePointer<cpSpatialIndex>?
    public var arbiters: UnsafeMutablePointer<cpArray>?
    public var contactBuffersHead: UnsafeMutablePointer<cpContactBufferHeader>?
    public var cachedArbiters: UnsafeMutablePointer<cpHashSet>?
    public var pooledArbiters: UnsafeMutablePointer<cpArray>?
    public var constraints: UnsafeMutablePointer<cpArray>?
    public var allocatedBuffers: UnsafeMutablePointer<cpArray>?
    public var locked: Int
    public var collisionHandlers: UnsafeMutablePointer<cpHashSet>?
    public var defaultHandler: cpCollisionHandler
    public var skipPostStep: cpBool
    public var postStepCallbacks: UnsafeMutablePointer<cpArray>?
    public var _staticBody: cpBody
}

public struct cpShape {
    public var body: UnsafeMutablePointer<cpBody>?
    public var bb: cpBB
    public var sensor: cpBool
    public var e: cpFloat
    public var u: cpFloat
    public var surface_v: cpVect
    public var data: cpDataPointer?
    public var collision_type: cpCollisionType
    public var group: cpGroup
    public var layers: cpLayers

    // Private Fields
    public var klass: UnsafePointer<cpShapeClass>?
    public var space: UnsafeMutablePointer<cpSpace>?
    public var next: UnsafeMutablePointer<cpShape>?
    public var prev: UnsafeMutablePointer<cpShape>?
    public var hashid: cpHashValue
}

public struct cpArbiter {
    public var e: cpFloat
    public var u: cpFloat
    public var surface_vr: cpVect
    public var data: cpDataPointer?

    // Private Fields
    public var a: UnsafeMutablePointer<cpShape>?
    public var b: UnsafeMutablePointer<cpShape>?
    public var body_a: UnsafeMutablePointer<cpBody>?
    public var body_b: UnsafeMutablePointer<cpBody>?
    public var thread_a: cpArbiterThread
    public var thread_b: cpArbiterThread
    public var numContacts: Int
    public var contacts: UnsafeMutablePointer<cpContact>?
    public var stamp: cpTimestamp
    public var handler: UnsafeMutablePointer<cpCollisionHandler>?
    public var swappedColl: cpBool
    public var state: cpArbiterState
}

public struct cpConstraint {
    public var a: UnsafeMutablePointer<cpBody>?
    public var b: UnsafeMutablePointer<cpBody>?
    public var maxForce: cpFloat
    public var errorBias: cpFloat
    public var maxBias: cpFloat
    public var preSolve: cpConstraintPreSolveFunc?
    public var postSolve: cpConstraintPostSolveFunc?
    public var data: cpDataPointer?

    // Private Fields
    public var klass: UnsafePointer<cpConstraintClass>?
    public var space: UnsafeMutablePointer<cpSpace>?
    public var next_a: UnsafeMutablePointer<cpConstraint>?
    public var next_b: UnsafeMutablePointer<cpConstraint>?
}

public struct cpArray {
    public var num: Int  // Number of elements in the array
    public var max: Int  // Maximum number of elements
    public var arr: UnsafeMutablePointer<UnsafeMutableRawPointer>?
}

public struct cpHashSet {
    public var entries: Int
    public var size: Int
    public var table: UnsafeMutablePointer<UnsafeMutablePointer<cpHashSetBin>>?
    public var pooledBins: UnsafeMutablePointer<cpHashSetBin>?
    public var defaultValue: UnsafeMutableRawPointer?
}

public struct cpContact {
    public var r1: cpVect
    public var r2: cpVect
    public var nMass: cpFloat
    public var tMass: cpFloat
    public var bounce: cpFloat
    public var bias: cpFloat
    public var jnAcc: cpFloat
    public var jtAcc: cpFloat
    public var jBias: cpFloat
    public var dist: cpFloat
}

public struct cpArbiterThread {
    public var prev: UnsafeMutablePointer<cpArbiter>?
    public var next: UnsafeMutablePointer<cpArbiter>?
}

public enum cpArbiterState: Int32 {
    case firstColl = 0
    case normal
    case ignore
    case cached
}

public struct cpContactBufferHeader {
    public var stamp: cpTimestamp
    public var next: UnsafeMutablePointer<cpContactBufferHeader>?
    public var numContacts: Int
}

public typealias cpLayers = UInt

public struct cpHashSetBin {
    public var hash: cpHashValue
    public var key: UnsafeMutableRawPointer?
    public var value: UnsafeMutableRawPointer?
    public var next: UnsafeMutablePointer<cpHashSetBin>?
}

public struct cpShapeClass {
    public var type: cpShapeType

    public var cacheData: cpShapeCacheDataImpl
    public var destroy: cpShapeDestroyImpl
    public var nearestPointQuery: cpShapeNearestPointQueryImpl
    public var segmentQuery: cpShapeSegmentQueryImpl
}

public struct cpConstraintClass {
    public var preStep: cpConstraintPreStepImpl
    public var applyCachedImpulse: cpConstraintApplyCachedImpulseImpl
    public var applyImpulse: cpConstraintApplyImpulseImpl
    public var getImpulse: cpConstraintGetImpulseImpl
}

public struct cpTransform {
    public var a: cpFloat
    public var b: cpFloat
    public var c: cpFloat
    public var d: cpFloat
    public var tx: cpFloat
    public var ty: cpFloat
}

public struct cpBB {
    public var l: cpFloat
    public var b: cpFloat
    public var r: cpFloat
    public var t: cpFloat
}

// public struct cpVect {
//     public var x: cpFloat
//     public var y: cpFloat

//     public init(x: cpFloat, y: cpFloat) {
//         self.x = x
//         self.y = y
//     }
// }

#if os(Linux) || os(Windows)
    extension CChipmunk2D.cpVect {
        init(from vect: CChipmunk2D.cpVect) {
            self.init(x: vect.x, y: vect.y)
        }
    }
#else
    extension Chipmunk2D.cpVect {
        init(from vect: Chipmunk2D.cpVect) {
            self.init(x: vect.x, y: vect.y)
        }
    }
#endif

public struct cpPointQueryInfo {
    public var shape: UnsafeMutablePointer<cpShape>?
    public var point: cpVect
    public var distance: cpFloat
    public var gradient: cpVect
}

public typealias cpShapeType = Int32  // Assuming it's an enum or integral type

// Function pointer types for cpShapeClass
public typealias cpShapeCacheDataImpl = (UnsafeMutablePointer<cpShape>, UnsafePointer<cpTransform>)
    -> cpBB
public typealias cpShapeDestroyImpl = (UnsafeMutablePointer<cpShape>) -> Void
public typealias cpShapeNearestPointQueryImpl = (
    UnsafeMutablePointer<cpShape>, cpVect, UnsafeMutablePointer<cpPointQueryInfo>
) -> Void
public typealias cpShapeSegmentQueryImpl = (
    UnsafeMutablePointer<cpShape>, cpVect, cpVect, cpFloat, UnsafeMutablePointer<cpSegmentQueryInfo>
) -> cpBool

// Function pointer types for cpConstraintClass
public typealias cpConstraintPreStepImpl = (UnsafeMutablePointer<cpConstraint>, cpFloat) -> Void
public typealias cpConstraintApplyCachedImpulseImpl = (UnsafeMutablePointer<cpConstraint>, cpFloat)
    -> Void
public typealias cpConstraintApplyImpulseImpl = (UnsafeMutablePointer<cpConstraint>, cpFloat) ->
    Void
public typealias cpConstraintGetImpulseImpl = (UnsafeMutablePointer<cpConstraint>) -> cpFloat

// @_cdecl("cpSpaceAddPostStepCallback")
// public func cpSpaceAddPostStepCallback(
//     _ space: UnsafeMutablePointer<cpSpace>,
//     _ callback: @convention(c) (UnsafeMutablePointer<cpSpace>, UnsafeRawPointer, UnsafeMutableRawPointer) -> Void,  // Match cpPostStepFunc
//     _ key: UnsafeRawPointer,
//     _ data: UnsafeMutableRawPointer
// ) -> UInt8  // cpBool return type
