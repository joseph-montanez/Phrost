import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor

// 1. Define the custom DatabaseID extension here so it is visible
extension DatabaseID {
    static var main: DatabaseID { .init(string: "main") }
}

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    if app.environment == .development {
    // This is default behavior in dev, but you can force it:
    // app.leaf.cache.isEnabled = false 
}

    app.views.use(.leaf)

    // 2. Use the .main ID we defined above
    app.databases.use(.sqlite(.file("db.sqlite")), as: .main)

    // Migrations
    app.migrations.add(CreateUser(), to: .main)
    app.migrations.add(CreateGame(), to: .main)
    app.migrations.add(CreateGameBuild(), to: .main)

    // register routes
    try routes(app)
}
