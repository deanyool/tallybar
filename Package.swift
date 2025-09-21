// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "tallybar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TallyCore"),
        .executableTarget(name: "TallyBar", dependencies: ["TallyCore"])
    ]
)
