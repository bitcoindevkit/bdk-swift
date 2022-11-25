# bdk-swift

This project is only used to publish a [Swift] package manager package called `bdk-swift` with language bindings and corresponding bdkFFI.xcframework for the 
`BitcoinDevKit` framework created by the [bdk-ffi] project. The Swift language bindings files are created by the [bdk-ffi] `./bdk-ffi` sub-project which are copied into, committed and tagged in this `bdk-swift` repo by the `publish-spm` github actions workflow.

Any changes to the `bdk-swift` Swift package must be made via the [bdk-ffi] repo.

## How to Use

To use the Swift language bindings for `BitcoinDevKit` in your [Xcode] iOS or MacOS project:

1. Add the "bdk-swift" package from the repo https://github.com/bitcoindevkit/bdk-swift and select one of the latest minor versions.
2. Add the `BitcoinDevKit` framework in your Target config.
3. Import and use the `BitcoinDevKit` library in your Swift code. For example:
   ```swift
   import BitcoinDevKit
   
   ...
   ```

[Swift]: https://developer.apple.com/swift/
[Xcode]: https://developer.apple.com/documentation/Xcode
[bdk-ffi]: https://github.com/notmandatory/bdk-ffi
