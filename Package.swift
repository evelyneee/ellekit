// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ElleKit",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ElleKit",
            targets: ["ElleKit"]),
    ],
    dependencies: [
        .package(path: URL(fileURLWithPath: #file).deletingLastPathComponent().absoluteString+"/ellekitc"),
    ],
    targets: [
        .target(
            name: "ElleKit",
            dependencies: [],
            path: "ellekit"
        )
    ]
)
