import Vapor

func routes(_ app: Application) throws {
    app.get { req -> EventLoopFuture<View> in
        return req.view.render("index", ["name": "Leaf"])
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
}
