// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let package = Package(
    name: "ellekit",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ellekit",
            targets: ["ellekit"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ellekitc",
            dependencies: [],
            path: "ellekitc"
        ),
        .target(
            name: "ellekit",
            dependencies: ["ellekitc"],
            path: "ellekit"
        )
    ]
)
