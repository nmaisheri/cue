// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Cue", platforms: [.macOS(.v14)], products: [.executable(name: "Cue", targets: ["Cue"])], targets: [
    .target(name: "CueCore"),
    .executableTarget(name: "Cue", dependencies: ["CueCore"]),
    .executableTarget(name: "CueChecks", dependencies: ["CueCore"], path: "Tests/CueCoreTests", exclude: ["Fixtures"])
])
