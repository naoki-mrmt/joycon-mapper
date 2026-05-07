// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JoyconCore",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "JoyconMapping", targets: ["JoyconMapping"]),
        .library(name: "JoyconHID", targets: ["JoyconHID"]),
        .library(name: "MacInput", targets: ["MacInput"])
    ],
    targets: [
        .target(name: "JoyconMapping"),
        .target(
            name: "JoyconHID",
            dependencies: ["JoyconMapping"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .target(
            name: "MacInput",
            dependencies: ["JoyconMapping"],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
