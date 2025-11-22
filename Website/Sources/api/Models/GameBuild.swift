import Fluent
import Vapor

final class GameBuild: Model, Content, @unchecked Sendable {
    static let schema = "game_builds"

    @ID(key: .id)
    var id: UUID?

    // Link back to the specific game
    @Parent(key: "game_id")
    var game: Game

    // e.g., "1.0.2"
    @Field(key: "version_tag")
    var versionTag: String

    // Path to the raw source uploaded by the user
    @Field(key: "source_path")
    var sourcePath: String

    // Path to the final compiled zip (e.g., Windows-x64.zip)
    @Field(key: "artifact_path")
    var artifactPath: String?

    // "Queued", "Compiling", "Success", "Failed"
    @Field(key: "status")
    var status: String

    // Compiler logs (useful for debugging failed builds)
    @Field(key: "build_log")
    var buildLog: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "completed_at", on: .update)
    var completedAt: Date?

    init() {}

    init(id: UUID? = nil, gameID: Game.IDValue, versionTag: String, sourcePath: String) {
        self.id = id
        self.$game.id = gameID
        self.versionTag = versionTag
        self.sourcePath = sourcePath
        self.status = "Queued"
    }
}
