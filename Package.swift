// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Tidy",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "TidyApp", targets: ["TidyApp"]),
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
        .executableTarget(
            name: "TidyApp",
            dependencies: ["TidyCore", "TidyUI"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices")
            ]
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
