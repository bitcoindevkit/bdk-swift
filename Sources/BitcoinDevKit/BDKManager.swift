//  Created by Daniel Nordh on 2/17/22.
//
//  The following repos have been useful in the creation of this code:
//  - BDKSwiftSample by FuturePaul, https://github.com/futurepaul/BdkSwiftSample, which in turn was inspired by
//  - BDK Android Demo Wallet by Thunderbiscuit, https://github.com/thunderbiscuit/bitcoindevkit-android-sample-app

import Foundation

public class BDKManager: ObservableObject {
    // Public variables
    @Published public var wallet: Wallet?
    @Published public var balance: UInt64 = 0
    @Published public var transactions: [BitcoinDevKit.Transaction] = []
    @Published public var walletState = WalletState.empty {
        didSet {
            switch walletState {
            case .empty:
                print("Wallet is not initialized")
            case .loading:
                print("Wallet is initializing")
            case .loaded(let wallet):
                print("Wallet is initialized")
                self.wallet = wallet
            case .failed(let error):
                print("Error initializing wallet:" + error.localizedDescription)
            }
        }
    }
    @Published public var syncState = SyncState.empty {
        didSet {
            switch syncState {
            case .empty:
                print("Node is not initialized")
            case .syncing:
                print("Node is syncing")
            case .synced:
                print("Node is synced")
                self.getBalance()
                self.getTransactions()
            case .failed(let error):
                print("Error, node syncing failed: " + error.localizedDescription)
            }
        }
    }
    
    // Private variables
    private var network: Network
    private var syncSource: SyncSource
    private var database: Database
    private let bdkQueue = DispatchQueue (label: "bdkQueue", qos: .userInitiated)
    private var syncTimer: Timer?
    
    // Public functions
    // Generate an extended key
    public func generateExtendedKey(wordCount: WordCount?, password: String?) throws -> ExtendedKeyInfo {
        do {
            return try BitcoinDevKit.generateExtendedKey(network: self.network, wordCount: wordCount != nil ? wordCount! : WordCount.words12, password: password)
        } catch let error {
            throw error
        }
    }
    
    // Recover ExtendedKeyInfo from a recovery phrase
    public func restoreFromMnemonic(mnemonic: String, password: String?) throws -> ExtendedKeyInfo {
        do {
            let extendedKeyInfo = try restoreExtendedKey(network: self.network, mnemonic: mnemonic, password: password)
            return extendedKeyInfo
        } catch let error {
            throw error
        }
    }
    
    // Create a descriptor from an extended key, .singleKey_wpkh84 is the only type currently defined
    public func createDescriptorFromXprv(descriptorType: DescriptorType, xprv: String) -> String {
        switch descriptorType {
        case .singleKey_wpkh84:
            return ("wpkh(" + xprv + "/84'/1'/0'/0/*)")
        }
    }
    
    // Initialize a BDKManager instance
    public init(network: Network, syncSource: SyncSource, database: Database) {
        self.network = network
        self.syncSource = syncSource
        self.database = database
    }
    
    // Load a wallet from a descriptor
    public func loadWallet(descriptor: String) {
        self.walletState = WalletState.loading
        let databaseConfig = databaseConfig(database: self.database)
        let blockchainConfig = blockchainConfig(network: network, syncSource: syncSource)
        initializeWallet(descriptor: descriptor, changeDescriptor: nil, network: self.network, databaseConfig: databaseConfig, blockchainConfig: blockchainConfig)
    }
    
    // Sync the loaded wallet once
    public func sync() {
        switch self.walletState {
        case .loaded(let wallet):
            self.syncState = SyncState.syncing
            bdkQueue.async {
                do {
                    let blockchainConfig = self.blockchainConfig(network: self.network, syncSource: self.syncSource)
                    let blockchain = try Blockchain(config: blockchainConfig)
                    try wallet.sync(blockchain: blockchain, progress: nil)
                    DispatchQueue.main.async {
                        self.syncState = SyncState.synced
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.syncState = SyncState.failed(error)
                    }
                }
            }
        default:
            print("Could not sync, wallet not initialized")
        }
    }
    
    // Sync the loaded wallet immediately, and then at the specified regular interval
    public func startSyncRegularly(interval: TimeInterval) {
        self.sync()
        self.syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true){ tempTimer in
            self.sync()
        }
    }
    
    // Stop regular sync of the loaded wallet
    public func stopSyncRegularly() {
        self.syncTimer?.invalidate()
    }
    
    // Send an amount of bitcoin (in sats) to a recipient, optional feeRate
    public func sendBitcoin(recipient: String, amount: UInt64, feeRate: Float) -> Bool {
        if self.wallet != nil {
            do {
                let psbt = try TxBuilder().addRecipient(address: recipient, amount: amount).feeRate(satPerVbyte: feeRate).finish(wallet: self.wallet!)
                try self.wallet!.sign(psbt: psbt)
                let blockchainConfig = self.blockchainConfig(network: self.network, syncSource: self.syncSource)
                let blockchain = try Blockchain(config: blockchainConfig)
                try blockchain.broadcast(psbt: psbt)
                return true
                } catch let error {
                    print(error)
                    return false
            }
        } else {
            return false
        }
    }
    
    // Private functions
    // Create a BDK BlockchainConfig based on a SyncSource (.esplora or .electrum)
    private func blockchainConfig(network: Network, syncSource: SyncSource) -> BlockchainConfig {
        var blockchainConfig: BlockchainConfig
        switch syncSource.type {
        case .esplora:
            let defaultUrl = network == Network.bitcoin ? ESPLORA_URL_BITCOIN : ESPLORA_URL_TESTNET
            let url = syncSource.customUrl != nil ? syncSource.customUrl : defaultUrl
            let esploraConfig = EsploraConfig.init(baseUrl: url!, proxy: nil, concurrency: nil, stopGap: ESPLORA_STOPGAP, timeout: ESPLORA_TIMEOUT)
            blockchainConfig = BlockchainConfig.esplora(config: esploraConfig)
        case .electrum:
            let defaultUrl = network == Network.bitcoin ? ELECTRUM_URL_BITCOIN : ELECTRUM_URL_TESTNET
            let url = syncSource.customUrl != nil ? syncSource.customUrl : defaultUrl
            let electrumConfig = ElectrumConfig(url: url!, socks5: nil, retry: ELECTRUM_RETRY, timeout: nil, stopGap: ELECTRUM_STOPGAP)
            blockchainConfig = BlockchainConfig.electrum(config: electrumConfig)
        }
        return blockchainConfig
    }
    
    // Create a BDK DatabaseConfig based on a Database (.memory or .disk)
    private func databaseConfig(database: Database) -> DatabaseConfig {
        var databaseConfig: DatabaseConfig
        switch database.type {
        case .memory:
            databaseConfig = DatabaseConfig.memory
        case .disk:
            let path = database.path != nil ? database.path : ""
            let treeName = database.treeName != nil ? database.treeName : ""
            let sledDbConfig = SledDbConfiguration(path: path!, treeName: treeName!)
            databaseConfig = DatabaseConfig.sled(config: sledDbConfig)
        }
        return databaseConfig
    }
    
    // Initialize a BDK Wallet based on Descriptor, Network, DatabaseConfig and BlockchainConfig
    private func initializeWallet(descriptor: String, changeDescriptor: String?, network: Network, databaseConfig: DatabaseConfig, blockchainConfig: BlockchainConfig) {
        do {
            let wallet = try Wallet.init(descriptor: descriptor, changeDescriptor: changeDescriptor, network: network, databaseConfig: databaseConfig)
            self.walletState = WalletState.loaded(wallet)
        } catch let error {
            self.walletState = WalletState.failed(error)
        }
    }
    
    // Update .balance
    private func getBalance() {
        do {
            self.balance = try self.wallet!.getBalance()
            print("Balance is: " + self.balance.description)
        } catch let error {
            print("Error getting wallet balance: " + error.localizedDescription)
        }
    }
    
    // Update .transactions
    private func getTransactions() {
        do {
            let transactions = try self.wallet!.getTransactions()
            self.transactions = transactions.sorted(by: {
                switch $0 {
                case .confirmed(_, let confirmation_a):
                    switch $1 {
                    case .confirmed(_, let confirmation_b): return confirmation_a.timestamp > confirmation_b.timestamp
                    default: return false
                    }
                default:
                    switch $1 {
                    case .unconfirmed(_):
                        return true
                    default: return false
                    }
                }
            })
            print("Transaction count: " + self.transactions.count.description)
        } catch let error {
            print("Error getting transactions: " + error.localizedDescription)
        }
    }
}

// Helpers

public enum DescriptorType {
    case singleKey_wpkh84
}

public struct SyncSource {
    public let type: SyncSourceType
    public let customUrl: String?
    
    public init(type: SyncSourceType, customUrl: String?) {
        self.type = type
        self.customUrl = customUrl
    }
}

public enum SyncSourceType {
    case esplora
    case electrum
}

public struct Database {
    public let type: DatabaseType
    public let path: String?
    public let treeName: String?
    
    public init(type: DatabaseType, path: String?, treeName: String?) {
        self.type = type
        self.path = path
        self.treeName = treeName
    }
}

public enum DatabaseType {
    case memory
    case disk
}

public enum SyncState {
    case empty
    case syncing
    case synced
    case failed(Error)
}

public enum WalletState {
    case empty
    case loading
    case loaded(Wallet)
    case failed(Error)
}

// Public API URLs
let ESPLORA_URL_BITCOIN = "https://blockstream.info/api/"
let ESPLORA_URL_TESTNET = "https://blockstream.info/testnet/api"

let ELECTRUM_URL_BITCOIN = "ssl://electrum.blockstream.info:60001"
let ELECTRUM_URL_TESTNET = "ssl://electrum.blockstream.info:60002"

// Defaults
let ESPLORA_TIMEOUT = UInt64(1000)
let ESPLORA_STOPGAP = UInt64(20)

let ELECTRUM_RETRY = UInt8(5)
let ELECTRUM_STOPGAP = UInt64(10)
