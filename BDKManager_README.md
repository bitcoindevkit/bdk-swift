# BDK Manager for iOS / Swift

This class makes it easier to work with [bdk-swift](https://github.com/bitcoindevkit/bdk-swift) on iOS by providing good defaults, simple setup and modern SwiftUI compatible convenience functions and variables.

It is still a work in progress and not ready for production.

## Installation

Add this github repository https://github.com/bdgwallet/bdk-swift as a dependency in your Xcode project.
It is a fork of [bdk-swift](https://github.com/bitcoindevkit/bdk-swift) with the `BDKManager` class added.
Import `BitcoinDevKit` in your Swift code.

```swift
import BitcoinDevKit
```

## Setup

To initalise a BDKManager you need to tell it what bitcoin `Network` it should use, what `SyncSource` the wallet is going to connect to for blockchain data, and where the `Database` should store information. The two supported sync source types by BDK on iOS at the moment is Esplora and Electrum API servers. You can specify a custom URL to a private server, or if none is supplied it will default to the public [Blockstream APIs](https://github.com/Blockstream/esplora/blob/master/API.md).

```swift
let network = Network.testnet // .bitcoin, .testnet, .signet or .regtest
let syncSource = SyncSource(type: SyncSourceType.esplora, customUrl: nil) // .esplora or .electrum, optional customUrl
let database = Database(type: DatabaseType.memory, path: nil, treeName: nil) // .memory or .disk, optional path and tree parameters
        
bdkManager = BDKManager.init(network: network, syncSource: syncSource, database: database)
```

## Load wallet

To create a new extended private key, descriptor and load the wallet:

```swift
do {
    let extendedKeyInfo = try bdkManager.generateExtendedKey(wordCount: nil, password: nil) // optional password and wordCount (defaults to 12)
    let descriptorType = DescriptorType.singleKey_wpkh84 // .singleKey_wpkh84 is the only type defined so far
    let descriptor = bdkManager.createDescriptorFromXprv(descriptorType: DescriptorType.singleKey_wpkh84, xprv: extendedKeyInfo.xprv)
    bdkManager.loadWallet(descriptor: descriptor)
} catch let error {
    print(error)
}
```

To load a wallet from an existing descriptor:

```swift
let descriptor = "wpkh(tprv8ZgxMBicQKsPeSitUfdxhsVaf4BXAASVAbHypn2jnPcjmQZvqZYkeqx7EHQTWvdubTSDa5ben7zHC7sUsx4d8tbTvWdUtHzR8uhHg2CW7MT/*)"
bdkManager.loadWallet(descriptor: descriptor)
```

## Sync

The wallet can be synced manually by calling `sync()`, or at regular intervals by using `startSyncRegularly` and `stopSyncRegularly`.
On every sync, the @Published parameters `.balance` and `.transactions` are updated, which means they automatically trigger updates in SwiftUI.

```swift
bdkManager.sync() // Will sync once

bdkManager.startSyncRegularly(interval: 120) // Will sync every 120 seconds
bdkManager.stopSyncRegularly() // Will stop the regular sync
```

## Example

A working SwiftUI example app is included in the repo. It has very basic functionality of showing the balance for a descriptor address. In this case the bdkManager is an @ObservedObject, which enables the WalletView to automatically update depending on bdkManager.syncState. The two files required:

**WalletApp.swift**
```swift
import SwiftUI
import BitcoinDevKit

@main
struct WalletApp: App {
    @ObservedObject var bdkManager: BDKManager
    
    init() {
        // Define BDKManager init options
        let network = Network.testnet // set bitcoin, testnet, signet or regtest
        let syncSource = SyncSource(type: SyncSourceType.esplora, customUrl: nil) // set esplora or electrum, can take customUrl
        let database = Database(type: DatabaseType.memory, path: nil, treeName: nil) // set memory or disk, optional path and tree parameters
        
        // Initialize a BDKManager instance
        bdkManager = BDKManager.init(network: network, syncSource: syncSource, database: database)
        
        // Load a singlekey wallet from a newly generated private key
        do {
            let extendedKeyInfo = try bdkManager.generateExtendedKey(wordCount: nil, password: nil)
            let descriptor = bdkManager.createDescriptorFromXprv(descriptorType: DescriptorType.singleKey_wpkh84, xprv: extendedKeyInfo.xprv)
            bdkManager.loadWallet(descriptor: descriptor)
        } catch let error {
            print(error)
        }
        
        // Or load a wallet from an existing descriptor
        //let descriptor = "wpkh(tprv8ZgxMBicQKsPeSitUfdxhsVaf4BXAASVAbHypn2jnPcjmQZvqZYkeqx7EHQTWvdubTSDa5ben7zHC7sUsx4d8tbTvWdUtHzR8uhHg2CW7MT/*)"
        //bdkManager.loadWallet(descriptor: descriptor)
    }
    
    var body: some Scene {
        WindowGroup {
            WalletView()
                .environmentObject(bdkManager)
        }
    }
}
```

**WalletView.swift**
```swift
import SwiftUI
import BitcoinDevKit

struct WalletView: View {
    @EnvironmentObject var bdkManager: BDKManager
    
    var body: some View {
        VStack (spacing: 50){
            Text("Hello, wallet!")
            switch bdkManager.syncState {
            case .synced:
                Text("Balance: \(bdkManager.balance)")
            case .syncing:
                Text("Balance: Syncing")
            default:
                Text("Balance: Not synced")
            }
            Text(bdkManager.wallet?.getNewAddress() ?? "-")
        }.onAppear {
            bdkManager.sync() // to sync once
            //bdkManager.startSyncRegularly(interval: 120) // to sync every 120 seconds
        }.onDisappear {
            //bdkManager.stopSyncRegularly() // if startSyncRegularly was used
        }
    }
}
```

## Public variables

BDK Manager has the following `@Published` public variables, meaning they can be observed and lead to updates in SwiftUI:
```swift
.wallet: Wallet?
.balance: UInt64
.transactions: [BitcoinDevKit.Transaction]
.walletState // .empty, .loading, .loaded, .failed
.syncState // .empty, .syncing, .synced, .failed
```

## Public functions

BDK Manager has the following public functions:
```swift
init(network: Network, syncSource: SyncSource, database: Database)
loadWallet(descriptor: String)

sync()
startSyncRegularly(interval: TimeInterval)
stopSyncRegularly()

sendBitcoin(recipient: String, amount: UInt64, feeRate: Float) -> Bool

generateExtendedKey(wordCount: WordCount?, password: String?) throws -> ExtendedKeyInfo // Remove
createDescriptorFromXprv(descriptorType: DescriptorType, xprv: String) -> String
```

Since the wallet is a BDK `Wallet`, the corresponding functions are also available on .wallet:
```swift
getNewAddress()  -> String
getLastUnusedAddress()  -> String
sign(psbt: PartiallySignedBitcoinTransaction ) throws
```
