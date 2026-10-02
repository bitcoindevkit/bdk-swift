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
            url: "https://github.com/bitcoindevkit/bdk-swift/releases/download/3.1.1/bdkFFI.xcframework.zip",
            checksum: "5e7f8ac46306f9de7ec2cc1c6486d9db5141c793d33cc13071ea7d1e3dae817f"),
        .target(
            name: "BitcoinDevKit",
            dependencies: ["bdkFFI"]),
    ]
)
