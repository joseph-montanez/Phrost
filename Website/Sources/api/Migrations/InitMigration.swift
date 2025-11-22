import Fluent

// Migration for Users
struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .id()
            .field("username", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("user_type", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
            .unique(on: "username")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
    }
}

// Migration for Games
struct CreateGame: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // Create the Enum for Status first
        let statusSchema = try await database.enum("game_status")
            .case("draft")
            .case("processing")
            .case("live")
            .case("failed")
            .create()

        try await database.schema("games")
            .id()
            .field("title", .string, .required)
            .field("executable_name", .string, .required)
            .field("package_id", .string, .required)
            .field("description", .string, .required)
            // Platform flags
            .field("supports_windows", .bool, .required)
            .field("supports_mac", .bool, .required)
            .field("supports_linux", .bool, .required)
            .field("version", .string, .required)
            // Use the enum
            .field("status", statusSchema, .required)
            .field("icon_url", .string)
            .field("screenshot_urls", .array(of: .string))
            .field("download_count", .int, .required)
            // Foreign Key
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "package_id")  // Package IDs usually must be unique
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("games").delete()
        try await database.enum("game_status").delete()
    }
}

// Migration for Builds
struct CreateGameBuild: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("game_builds")
            .id()
            .field("game_id", .uuid, .required, .references("games", "id", onDelete: .cascade))
            .field("version_tag", .string, .required)
            .field("source_path", .string, .required)
            .field("artifact_path", .string)
            .field("status", .string, .required)
            .field("build_log", .string)  // .sql(.text) if using SQL for large logs
            .field("created_at", .datetime)
            .field("completed_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("game_builds").delete()
    }
}
