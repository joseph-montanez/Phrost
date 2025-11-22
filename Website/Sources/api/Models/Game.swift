import Fluent
import Vapor

enum GameStatus: String, Codable, @unchecked Sendable {
    case draft, processing, live, failed
}

final class Game: Model, Content, @unchecked Sendable {
    static let schema = "games"

    @ID(key: .id)
    var id: UUID?

    // From publish.html: "Game Name"
    @Field(key: "title")
    var title: String

    // From publish.html: "Executable Name (.exe)"
    @Field(key: "executable_name")
    var executableName: String

    // From publish.html: "Namespace / Package ID"
    @Field(key: "package_id")
    var packageId: String

    // From publish.html: "Description"
    @Field(key: "description")
    var description: String

    // From publish.html: "Target Platforms"
    @Field(key: "supports_windows")
    var supportsWindows: Bool

    @Field(key: "supports_mac")
    var supportsMac: Bool

    @Field(key: "supports_linux")
    var supportsLinux: Bool

    // From dashboard.html: "v0.9.4"
    @Field(key: "version")
    var version: String

    // From dashboard.html: "Live", "Processing"
    @Enum(key: "status")
    var status: GameStatus

    // Path to the icon uploaded in publish.html
    @Field(key: "icon_url")
    var iconUrl: String?

    // JSON array of screenshot URLs
    @Field(key: "screenshot_urls")
    var screenshotUrls: [String]?

    // Stats from dashboard.html
    @Field(key: "download_count")
    var downloadCount: Int

    // Relation to the developer
    @Parent(key: "user_id")
    var user: User

    // History of builds/tasks for this game
    @Children(for: \.$game)
    var builds: [GameBuild]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil, title: String, executableName: String, packageId: String,
        description: String, userID: User.IDValue
    ) {
        self.id = id
        self.title = title
        self.executableName = executableName
        self.packageId = packageId
        self.description = description
        self.supportsWindows = true  // Defaults
        self.supportsMac = false
        self.supportsLinux = false
        self.version = "0.0.1"
        self.status = .draft
        self.downloadCount = 0
        self.$user.id = userID
    }
}
