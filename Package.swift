// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tallybar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TallyCore", targets: ["TallyCore"]),
        .executable(name: "TallyBar", targets: ["TallyBar"]),
    ],
    targets: [
        .target(name: "TallyCore"),
        .target(name: "TallyUI", dependencies: ["TallyCore"]),
        .executableTarget(name: "TallyBar", dependencies: ["TallyCore", "TallyUI"]),
        .testTarget(name: "TallyCoreTests", dependencies: ["TallyCore"]),
    ]
)
