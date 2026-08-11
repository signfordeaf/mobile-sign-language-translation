// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SignForDeaf",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SignForDeaf",
            targets: ["SignForDeaf"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // The logo is drawn as a vector (LogoView); the bundled idle-signer clips
        // are shipped as processed resources, loaded via `Bundle.module`.
        .target(
            name: "SignForDeaf",
            resources: [
                .process("Resources/videos"),
            ]),
        .testTarget(
            name: "SignForDeafTests",
            dependencies: ["SignForDeaf"]),
    ]
)
