// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RedditMedia",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "RedditMedia", targets: ["RedditMedia"]),
    ],
    targets: [
        .target(name: "RedditMedia"),
        .testTarget(
            name: "RedditMediaTests",
            dependencies: ["RedditMedia"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
