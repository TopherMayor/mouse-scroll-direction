// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MouseScrollDirection",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MouseScrollDirectionCore", targets: ["MouseScrollDirectionCore"]),
        .executable(name: "MouseScrollDirection", targets: ["MouseScrollDirection"]),
        .executable(name: "ScrollPolicyValidation", targets: ["ScrollPolicyValidation"])
    ],
    targets: [
        .target(
            name: "MouseScrollDirectionCore",
            path: "Sources/MouseScrollDirectionCore"
        ),
        .executableTarget(
            name: "MouseScrollDirection",
            dependencies: ["MouseScrollDirectionCore"],
            path: "Sources/MouseScrollDirectionApp"
        ),
        .executableTarget(
            name: "ScrollPolicyValidation",
            dependencies: ["MouseScrollDirectionCore"],
            path: "Tests/ScrollPolicyValidation"
        )
    ]
)
