// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "bdk-swift",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BitcoinDevKit",
            targets: ["bdkFFI", "BitcoinDevKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .binaryTarget(
            name: "bdkFFI",
            url: "https://github.com/bitcoindevkit/bdk-swift/releases/download/1.0.0-beta.2/bdkFFI.xcframework.zip",
            checksum: "255639a47a8b076163700a242f0d152911c2b689c2f18c9346764cb7645dc8b7"),
        .target(
            name: "BitcoinDevKit",
            dependencies: ["bdkFFI"]),
        .testTarget(
            name: "BitcoinDevKitTests",
            dependencies: ["BitcoinDevKit"]),
    ]
)
