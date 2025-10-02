// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "skip-fuse-revenuecat",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkipFuseRevenueCat", type: .dynamic, targets: ["SkipFuseRevenueCat"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.6.27"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "4.43.0")
    ],
    targets: [
        .target(name: "SkipFuseRevenueCat", dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "RevenueCat", package: "purchases-ios", condition: .when(platforms: [.iOS, .macOS]))
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipFuseRevenueCatTests", dependencies: [
            "SkipFuseRevenueCat",
            .product(name: "SkipTest", package: "skip")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
