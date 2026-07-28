// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Tidy",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "TidyCore", targets: ["TidyCore"]),
        .library(name: "TidyUI", targets: ["TidyUI"]),
    ],
    targets: [
        .target(
            name: "TidyCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .unsafeFlags(["-framework", "Carbon"])
            ]
        ),
        .target(
            name: "TidyUI",
            dependencies: ["TidyCore"]
        ),
        .testTarget(
            name: "TidyCoreTests",
            dependencies: ["TidyCore"]
        ),
        .testTarget(
            name: "TidyUITests",
            dependencies: ["TidyUI"]
        ),
    ]
)
