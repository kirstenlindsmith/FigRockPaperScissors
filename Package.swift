// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BattleEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BattleEngine", targets: ["BattleEngine"]),
        .library(name: "BattleApp", targets: ["BattleApp"]),
        .executable(name: "battle-client", targets: ["BattleClient"]),
        .executable(name: "battle-measure", targets: ["BattleMeasure"]),
    ],
    targets: [
        .target(
            name: "BattleEngine",
            linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux]))]
        ),
        .target(name: "BattleApp", dependencies: ["BattleEngine"]),
        .executableTarget(name: "BattleClient", dependencies: ["BattleEngine"]),
        .target(name: "BattleFixtures", dependencies: ["BattleEngine"]),
        .executableTarget(name: "BattleMeasure", dependencies: ["BattleEngine", "BattleFixtures"]),
        .testTarget(name: "BattleEngineTests", dependencies: ["BattleEngine", "BattleFixtures"]),
        .testTarget(
            name: "BattleAppTests",
            dependencies: ["BattleApp", "BattleEngine", "BattleFixtures"]
        ),
    ]
)
