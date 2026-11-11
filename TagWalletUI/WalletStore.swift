import Foundation
import UIKit
import ImageIO

struct WalletFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
struct CardProgress: Codable {
    var completedAt: Date?
    var source: String?
    var switchTested = false
}
struct SavedBatch: Codable {
    var id = UUID().uuidString
    var name: String
    var cardIDs: [String] = []
    var currentID: String?
}
struct WalletProgress: Codable {
    var batch: [String] = []
    var cards: [String: CardProgress] = [:]
    var currentID: String?
    var savedBatches: [SavedBatch]?
    var activeBatchID: String?
}
struct LibrarySnapshot: Codable {
    var schemaVersion = 1
    var createdAt = Date()
    var wallet: TagWallet
    var images: [String: Data] = [:]
    var progress = WalletProgress()
}
struct CatalogEnvelope: Codable {
    var schemaVersion: Int?
    var tagProducts: [TagProduct]
    var staticKey: TagKey?
    var dataKey: TagKey?
    var images: [String: Data]?
}
final class WalletStore {
    static let changed = Notification.Name("WalletStoreChanged")
    private(set) var snapshot: LibrarySnapshot
    let directory: URL
    let bundled: TagWallet
    private let imageCache = NSCache<NSString, UIImage>()
    private var sortedProducts: [TagProduct]?
    var products: [TagProduct] {
        if let sortedProducts = sortedProducts { return sortedProducts }
        let order = ["Series 1", "Series 2", "Series 3", "Series 4", "Series 5", "Welcome Amiibo", "Sanrio", "Promos"]
        let ranked = snapshot.wallet.tagProducts.map { product in
            (product: product, rank: order.firstIndex(where: { product.productSeries.contains($0) }) ?? 99)
        }
        let result = ranked.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.product.name.localizedStandardCompare($1.product.name) == .orderedAscending
        }.map(\.product)
        sortedProducts = result
        return result
    }
    init(directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0], bundled: TagWallet) throws {
        self.directory = directory
        self.bundled = bundled
        snapshot = LibrarySnapshot(wallet: bundled)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let pointer = directory.appendingPathComponent("active-library")
        if fm.fileExists(atPath: pointer.path) {
            let name = try String(contentsOf: pointer, encoding: .utf8)
            guard UUID(uuidString: name) != nil else { throw WalletFailure("Invalid library pointer. Restore a backup or recover the previous generation.") }
            snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: directory.appendingPathComponent(name).appendingPathComponent("snapshot.json")))
            try Self.validate(snapshot)
            // New bundled cards are added, while user metadata and progress remain authoritative.
            snapshot.wallet.tagProducts = Self.merge(snapshot.wallet.tagProducts, bundled.tagProducts, replace: false)
        } else {
            let legacy = directory.appendingPathComponent("tagWallet.json")
            if fm.fileExists(atPath: legacy.path) {
                let raw = try Data(contentsOf: legacy)
                // Legacy installations may contain the original placeholder keys.
                // Ignore only invalid key fields; malformed products still produce a visible error.
                var object = try JSONSerialization.jsonObject(with: raw) as? [String: Any] ?? [:]
                for name in ["staticKey", "dataKey"] {
                    if let value = object[name], !(value is NSNull) {
                        let encoded = try JSONSerialization.data(withJSONObject: value)
                        if (try? JSONDecoder().decode(TagKey.self, from: encoded)) == nil { object.removeValue(forKey: name) }
                    }
                }
                let old = try JSONDecoder().decode(TagWallet.self, from: JSONSerialization.data(withJSONObject: object))
                try raw.write(to: directory.appendingPathComponent("tagWallet-before-migration.json"), options: .atomic)
                snapshot.wallet.tagProducts = Self.merge(old.tagProducts, bundled.tagProducts, replace: false)
                snapshot.wallet.staticKey = old.staticKey ?? bundled.staticKey
                snapshot.wallet.dataKey = old.dataKey ?? bundled.dataKey
            }
        }
        snapshot.wallet.staticKey = snapshot.wallet.staticKey ?? bundled.staticKey
        snapshot.wallet.dataKey = snapshot.wallet.dataKey ?? bundled.dataKey
        if snapshot.progress.savedBatches == nil {
            let first = SavedBatch(name: "My batch", cardIDs: snapshot.progress.batch, currentID: snapshot.progress.currentID)
            snapshot.progress.savedBatches = [first]; snapshot.progress.activeBatchID = first.id
        }
        try save(snapshot)
    }
    var batches: [SavedBatch] { snapshot.progress.savedBatches ?? [] }
    var activeBatchName: String { batches.first { $0.id == snapshot.progress.activeBatchID }?.name ?? "My batch" }
    func createBatch(name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WalletFailure("Enter a batch name.") }
        let batch = SavedBatch(name: name)
        try change {
            $0.progress.savedBatches = ($0.progress.savedBatches ?? []) + [batch]
            $0.progress.activeBatchID = batch.id; $0.progress.batch = []; $0.progress.currentID = nil
        }
    }
    func selectBatch(_ id: String) throws {
        guard let batch = batches.first(where: { $0.id == id }) else { throw WalletFailure("Batch no longer exists.") }
        try change {
            $0.progress.activeBatchID = batch.id
            $0.progress.batch = batch.cardIDs; $0.progress.currentID = batch.currentID
        }
    }
    static func merge(_ existing: [TagProduct], _ incoming: [TagProduct], replace: Bool) -> [TagProduct] {
        var result = existing
        for product in incoming {
            if let i = result.firstIndex(where: { $0.id == product.id }) {
                let old = result[i]
                var updated = replace ? product : old
                updated.dumps = old.dumps
                for dump in product.dumps where !updated.dumps.contains(dump) { updated.dumps.append(dump) }
                if updated.name.isEmpty { updated.name = product.name }
                if updated.character.isEmpty { updated.character = product.character }
                if updated.productSeries.isEmpty { updated.productSeries = product.productSeries }
                if updated.gameSeries.isEmpty { updated.gameSeries = product.gameSeries }
                if updated.imageURL.isEmpty { updated.imageURL = product.imageURL }
                if updated.imageAssetName == nil { updated.imageAssetName = product.imageAssetName }
                if updated.cardNumber == nil { updated.cardNumber = product.cardNumber }
                result[i] = updated
            } else { result.append(product) }
        }
        return result
    }
    static func validate(_ value: LibrarySnapshot) throws {
        try validate(value, previouslyValidatedImages: [:])
    }
    private static func validate(_ value: LibrarySnapshot, previouslyValidatedImages: [String: Data]) throws {
        guard value.schemaVersion == 1 else { throw WalletFailure("Unsupported backup version.") }
        var ids = Set<String>()
        for p in value.wallet.tagProducts {
            guard p.id.count == 16, p.id.allSatisfy({ $0.isHexDigit }), ids.insert(p.id).inserted else { throw WalletFailure("Invalid or duplicate card identifier.") }
            for dump in p.dumps {
                guard dump.headHex + dump.tailHex == p.id else { throw WalletFailure("Dump identifier does not match \(p.name).") }
            }
        }
        guard Set(value.progress.batch).count == value.progress.batch.count,
              value.progress.batch.allSatisfy({ ids.contains($0) }),
              value.progress.cards.keys.allSatisfy({ ids.contains($0) }) else { throw WalletFailure("Progress references invalid cards.") }
        if let batches = value.progress.savedBatches {
            guard !batches.isEmpty, Set(batches.map(\.id)).count == batches.count,
                  batches.contains(where: { $0.id == value.progress.activeBatchID }) else { throw WalletFailure("Invalid batch lists.") }
            for batch in batches {
                guard !batch.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      Set(batch.cardIDs).count == batch.cardIDs.count,
                      batch.cardIDs.allSatisfy({ ids.contains($0) }) else { throw WalletFailure("Invalid batch membership.") }
            }
        }
        for (id, data) in value.images {
            guard ids.contains(id) else { throw WalletFailure("Image references an unknown card.") }
            if previouslyValidatedImages[id] != data { _ = try normalizedImage(data) }
        }
    }
    func save(_ input: LibrarySnapshot) throws {
        var candidate = input
        // Older backups have a single projected batch; migrate them during restore too.
        if candidate.progress.savedBatches == nil {
            let first = SavedBatch(name: "My batch", cardIDs: candidate.progress.batch, currentID: candidate.progress.currentID)
            candidate.progress.savedBatches = [first]; candidate.progress.activeBatchID = first.id
        }
        if let index = candidate.progress.savedBatches?.firstIndex(where: { $0.id == candidate.progress.activeBatchID }) {
            candidate.progress.savedBatches?[index].cardIDs = candidate.progress.batch
            candidate.progress.savedBatches?[index].currentID = candidate.progress.currentID
        }
        // The current snapshot has already been validated; progress-only saves need no image decoding.
        try Self.validate(candidate, previouslyValidatedImages: snapshot.images)
        let fm = FileManager.default
        let name = UUID().uuidString
        let staging = directory.appendingPathComponent(name)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try JSONEncoder().encode(candidate).write(to: staging.appendingPathComponent("snapshot.json"), options: .atomic)
            let active = directory.appendingPathComponent("active-library")
            let previous = try? String(contentsOf: active, encoding: .utf8)
            if let previous = previous { try previous.write(to: directory.appendingPathComponent("previous-library"), atomically: true, encoding: .utf8) }
            try name.write(to: active, atomically: true, encoding: .utf8)
            let oldSnapshot = snapshot
            if oldSnapshot.wallet.tagProducts != candidate.wallet.tagProducts { sortedProducts = nil }
            snapshot = candidate
            let newIDs = Set(candidate.wallet.tagProducts.map(\.id))
            for product in oldSnapshot.wallet.tagProducts where !newIDs.contains(product.id) {
                imageCache.removeObject(forKey: product.id as NSString)
            }
            let oldAssets = Dictionary(uniqueKeysWithValues: oldSnapshot.wallet.tagProducts.map { ($0.id, $0.imageAssetName) })
            for product in candidate.wallet.tagProducts {
                if oldSnapshot.images[product.id] != candidate.images[product.id] ||
                    (oldAssets[product.id] ?? nil) != product.imageAssetName {
                    imageCache.removeObject(forKey: product.id as NSString)
                }
            }
            for url in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where UUID(uuidString: url.lastPathComponent) != nil && url.lastPathComponent != name && url.lastPathComponent != previous {
                try? fm.removeItem(at: url)
            }
            NotificationCenter.default.post(name: Self.changed, object: self)
        } catch { try? fm.removeItem(at: staging); throw error }
    }
    func change(_ edit: (inout LibrarySnapshot) -> Void) throws {
        var next = snapshot; edit(&next); try save(next)
    }
    func done(_ id: String) -> Bool { snapshot.progress.cards[id]?.completedAt != nil }
    func complete(_ id: String, source: String) throws {
        try change { $0.progress.cards[id] = CardProgress(completedAt: Date(), source: source, switchTested: false) }
    }
    var remaining: [String] { snapshot.progress.batch.filter { !done($0) } }
    func product(_ id: String) -> TagProduct? { snapshot.wallet.tagProducts.first { $0.id == id } }
    func importCatalog(_ envelope: CatalogEnvelope, replace: Bool, keys: Bool) throws {
        guard envelope.schemaVersion == nil || envelope.schemaVersion == 1 else { throw WalletFailure("Unsupported catalog version.") }
        let imported = TagWallet(tagProducts: envelope.tagProducts, staticKey: envelope.staticKey, dataKey: envelope.dataKey)
        try Self.validate(LibrarySnapshot(wallet: imported, images: envelope.images ?? [:]))
        var normalizedImages: [String: Data] = [:]
        for (id, data) in envelope.images ?? [:] { normalizedImages[id] = try Self.normalizedImage(data) }
        try change { next in
            next.wallet.tagProducts = Self.merge(next.wallet.tagProducts, imported.tagProducts, replace: replace)
            for (id, image) in normalizedImages where replace || next.images[id] == nil { next.images[id] = image }
            if keys {
                next.wallet.staticKey = imported.staticKey ?? next.wallet.staticKey
                next.wallet.dataKey = imported.dataKey ?? next.wallet.dataKey
            }
        }
    }
    func image(_ product: TagProduct) -> UIImage? {
        if let image = imageCache.object(forKey: product.id as NSString) { return image }
        if let data = snapshot.images[product.id], let image = UIImage(data: data) { imageCache.setObject(image, forKey: product.id as NSString); return image }
        if let name = product.imageAssetName, let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "CardImages"), let image = UIImage(contentsOfFile: url.path) { imageCache.setObject(image, forKey: product.id as NSString); return image }
        return nil
    }
    func backup() throws -> Data {
        var value = snapshot; value.createdAt = Date()
        for product in products where value.images[product.id] == nil {
            if let image = image(product), let data = image.pngData() { value.images[product.id] = data }
        }
        return try JSONEncoder().encode(value)
    }
    static func normalizedImage(_ data: Data) throws -> Data {
        guard data.count <= 10_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let format = CGImageSourceGetType(source) as String?, ["public.png", "public.jpeg"].contains(format),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, Double(width) * Double(height) <= 25_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: min(1600, max(width, height)), kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
              let encoded = UIImage(cgImage: image).pngData() else { throw WalletFailure("Choose a PNG or JPEG under 10 MB and 25 megapixels.") }
        return encoded
    }
}
