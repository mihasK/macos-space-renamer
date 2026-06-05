// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacOSSpacesRenamer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SpacesRenamer", targets: ["SpacesRenamerApp"]),
        .library(name: "SpacesRenamerCore", targets: ["SpacesRenamerCore"])
    ],
    targets: [
        .target(name: "SpacesRenamerCore"),
        .executableTarget(
            name: "SpacesRenamerApp",
            dependencies: ["SpacesRenamerCore"]
        ),
        .testTarget(
            name: "SpacesRenamerCoreTests",
            dependencies: ["SpacesRenamerCore"]
        )
    ]
)
