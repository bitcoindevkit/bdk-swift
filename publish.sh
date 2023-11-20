# This script builds the artifacts and publishes them to the bitcoindevkit/bdk-swift repository

cd build/bdk-swift/

rustup install 1.73.0
rustup component add rust-src
rustup target add aarch64-apple-ios x86_64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add aarch64-apple-darwin x86_64-apple-darwin

cd ../bdk-ffi/
cargo run --bin uniffi-bindgen generate src/bdk.udl --language swift --out-dir ../bdk-swift/Sources/BitcoinDevKit --no-format

cargo build --package bdk-ffi --profile release-smaller --target x86_64-apple-darwin
cargo build --package bdk-ffi --profile release-smaller --target aarch64-apple-darwin
cargo build --package bdk-ffi --profile release-smaller --target x86_64-apple-ios
cargo build --package bdk-ffi --profile release-smaller --target aarch64-apple-ios
cargo build --package bdk-ffi --profile release-smaller --target aarch64-apple-ios-sim

cd ../
mkdir -p target/lipo-ios-sim/release-smaller
lipo target/aarch64-apple-ios-sim/release-smaller/libbdkffi.a target/x86_64-apple-ios/release-smaller/libbdkffi.a -create -output target/lipo-ios-sim/release-smaller/libbdkffi.a
mkdir -p target/lipo-macos/release-smaller
lipo target/aarch64-apple-darwin/release-smaller/libbdkffi.a target/x86_64-apple-darwin/release-smaller/libbdkffi.a -create -output target/lipo-macos/release-smaller/libbdkffi.a

cd build/bdk-swift/

mv Sources/BitcoinDevKit/bdk.swift Sources/BitcoinDevKit/BitcoinDevKit.swift
cp Sources/BitcoinDevKit/bdkFFI.h bdkFFI.xcframework/ios-arm64/bdkFFI.framework/Headers
cp Sources/BitcoinDevKit/bdkFFI.h bdkFFI.xcframework/ios-arm64_x86_64-simulator/bdkFFI.framework/Headers
cp Sources/BitcoinDevKit/bdkFFI.h bdkFFI.xcframework/macos-arm64_x86_64/bdkFFI.framework/Headers
cp ../target/aarch64-apple-ios/release-smaller/libbdkffi.a bdkFFI.xcframework/ios-arm64/bdkFFI.framework/bdkFFI
cp ../target/lipo-ios-sim/release-smaller/libbdkffi.a bdkFFI.xcframework/ios-arm64_x86_64-simulator/bdkFFI.framework/bdkFFI
cp ../target/lipo-macos/release-smaller/libbdkffi.a bdkFFI.xcframework/macos-arm64_x86_64/bdkFFI.framework/bdkFFI
rm Sources/BitcoinDevKit/bdkFFI.h
rm Sources/BitcoinDevkit/bdkFFI.modulemap
rm bdkFFI.xcframework.zip || true
zip -9 -r bdkFFI.xcframework.zip bdkFFI.xcframework
echo "BDKFFICHECKSUM=`swift package compute-checksum bdkFFI.xcframework.zip`" >> $GITHUB_ENV
echo "BDKFFIURL=https\:\/\/github\.com\/${{ github.repository_owner }}\/bdk\-swift\/releases\/download\/${{ inputs.version }}\/bdkFFI\.xcframework\.zip" >> $GITHUB_ENV

echo checksum = ${{ env.BDKFFICHECKSUM }}
echo url = ${{ env.BDKFFIURL }}
sed "s/BDKFFICHECKSUM/${BDKFFICHECKSUM}/;s/BDKFFIURL/${BDKFFIURL}/" Package.swift.txt > ../../dist/Package.swift
cp Sources/BitcoinDevKit/BitcoinDevKit.swift ../../dist/Sources/BitcoinDevKit/BitcoinDevKit.swift
cd ../../dist
git add Sources/BitcoinDevKit/BitcoinDevKit.swift
git add Package.swift
git commit -m "Update BitcoinDevKit.swift and Package.swift for release ${{ inputs.version }}"
git push
git tag ${{ inputs.version }} -m "Release ${{ inputs.version }}"
git push --tags

