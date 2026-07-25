// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TVTrackWatch",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TVTrackWatch",
            targets: ["TVTrackWatch"]
        )
    ],
    targets: [
        .target(
            name: "TVTrackWatch",
            path: "TVTrackWatch"
        ),
        .testTarget(
            name: "TVTrackWatchTests",
            dependencies: ["TVTrackWatch"],
            path: "Tests/TVTrackWatchTests"
        )
    ]
)
