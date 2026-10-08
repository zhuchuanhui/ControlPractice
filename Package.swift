// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ControlPractice",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ControlPractice", targets: ["ControlPractice"])],
    targets: [.executableTarget(name: "ControlPractice")]
)
