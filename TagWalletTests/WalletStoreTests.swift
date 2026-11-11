import XCTest
@testable import TagWallet

final class WalletStoreTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    func card(_ number: UInt8 = 1) -> TagProduct {
        var bytes = Data(repeating: 0, count: 540); bytes[84] = number
        let dump = TagDump(data: bytes)!
        return TagProduct(productSeries: "Series 1", character: "Étoile", gameSeries: "Animal Crossing", imageURL: "", name: "001 - Étoile", type: "Card", head: dump.headHex, tail: dump.tailHex, dumps: [dump])
    }
    func wallet(_ cards: [TagProduct]) -> TagWallet { TagWallet(tagProducts: cards, staticKey: TagKey(data: Data(repeating: 0, count: 80)), dataKey: TagKey(data: Data(repeating: 0, count: 80))) }
    func testDumpNormalizationAndMalformedDecode() throws {
        let raw = Data(repeating: 0, count: 540)
        let encoded = try JSONSerialization.data(withJSONObject: ["data": raw.base64EncodedString()])
        XCTAssertEqual(try JSONDecoder().decode(TagDump.self, from: encoded).data.count, 532)
        let short = try JSONSerialization.data(withJSONObject: ["data": Data(repeating: 0, count: 10).base64EncodedString()])
        XCTAssertThrowsError(try JSONDecoder().decode(TagDump.self, from: short))
        XCTAssertThrowsError(try JSONDecoder().decode(TagKey.self, from: short))
    }
    func testMigrationAndRepeatedLaunchPreserveCustomProducts() throws {
        try JSONEncoder().encode(wallet([card()])).write(to: root.appendingPathComponent("tagWallet.json"))
        let store = try WalletStore(directory: root, bundled: wallet([card(2)]))
        XCTAssertEqual(store.products.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("tagWallet-before-migration.json").path))
        try store.complete(card().id, source: "manual")
        let reopened = try WalletStore(directory: root, bundled: wallet([card(2), card(3)]))
        XCTAssertEqual(reopened.products.count, 3); XCTAssertTrue(reopened.done(card().id))
    }
    func testMigrationPreservesMatchingCustomMetadata() throws {
        var custom = card(); custom.name = "My custom name"; custom.character = "Custom"
        try JSONEncoder().encode(wallet([custom])).write(to: root.appendingPathComponent("tagWallet.json"))
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        XCTAssertEqual(store.product(custom.id)?.name, custom.name)
        XCTAssertEqual(store.product(custom.id)?.character, custom.character)
    }
    func testNextSaveFailureKeepsCurrentCardAndDoesNotWrite() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card(), card(2)]))
        try store.change { $0.progress.batch = [self.card().id, self.card(2).id] }
        let fake = FakeWriter()
        let controller = CardDetailController(store: store, id: card().id, sequential: true, writer: fake)
        controller.loadViewIfNeeded()
        let pointer = root.appendingPathComponent("active-library")
        try FileManager.default.removeItem(at: pointer)
        try FileManager.default.createDirectory(at: pointer, withIntermediateDirectories: true)
        controller.next(start: true)
        XCTAssertEqual(controller.id, card().id)
        XCTAssertEqual(fake.calls, 0)
        XCTAssertNil(store.snapshot.progress.currentID)
    }
    func testImportDeduplicatesAndKeepsProgress() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        try store.complete(card().id, source: "nfc")
        var changed = card(); changed.name = "Edited"
        let catalog = CatalogEnvelope(schemaVersion: 1, tagProducts: [changed], staticKey: nil, dataKey: nil, images: nil)
        try store.importCatalog(catalog, replace: false, keys: false)
        XCTAssertEqual(store.products[0].dumps.count, 1); XCTAssertNotEqual(store.products[0].name, "Edited")
        try store.importCatalog(catalog, replace: true, keys: false)
        XCTAssertEqual(store.products[0].name, "Edited"); XCTAssertTrue(store.done(card().id))
    }
    func testDistinctDumpAndIdentityValidation() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        var second = card(); var raw = second.dumps[0].data; raw[20] = 1; second.dumps = [TagDump(data: raw)!]
        try store.importCatalog(CatalogEnvelope(schemaVersion: 1, tagProducts: [second], staticKey: nil, dataKey: nil, images: nil), replace: false, keys: false)
        XCTAssertEqual(store.products[0].dumps.count, 2)
        second.head = "ffffffff"
        XCTAssertThrowsError(try store.importCatalog(CatalogEnvelope(schemaVersion: 1, tagProducts: [second], staticKey: nil, dataKey: nil, images: nil), replace: false, keys: false))
        XCTAssertEqual(store.products.count, 1)
    }
    func testProgressSaveRetainsImageCacheAndRejectsChangedInvalidImage() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).pngData { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        try store.change { $0.images[self.card().id] = image }
        let cached = try XCTUnwrap(store.image(card()))
        try store.complete(card().id, source: "manual")
        XCTAssertTrue(cached === store.image(card()))
        XCTAssertThrowsError(try store.change { $0.images[self.card().id] = Data("invalid".utf8) })
        XCTAssertEqual(store.snapshot.images[card().id], image)
    }
    func testBackupRoundTrip() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.pngData { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 10, height: 10)) }
        try store.change { $0.progress.batch = [self.card().id]; $0.progress.currentID = self.card().id; $0.images[self.card().id] = image }
        try store.complete(card().id, source: "nfc")
        try store.change { $0.progress.cards[self.card().id]?.switchTested = true }
        let backup = try JSONDecoder().decode(LibrarySnapshot.self, from: store.backup())
        let restored = try WalletStore(directory: root.appendingPathComponent("restored"), bundled: wallet([]))
        try restored.save(backup)
        XCTAssertEqual(restored.snapshot.progress.batch, [card().id]); XCTAssertTrue(restored.done(card().id))
        XCTAssertTrue(restored.snapshot.progress.cards[card().id]!.switchTested)
        XCTAssertEqual(restored.snapshot.images[card().id], image); XCTAssertNotNil(restored.snapshot.wallet.staticKey)
    }
    func testInvalidRestoreDoesNotMutateState() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        var bad = store.snapshot; bad.schemaVersion = 99
        XCTAssertThrowsError(try store.save(bad)); XCTAssertEqual(store.products.count, 1)
        bad = store.snapshot; bad.progress.batch = ["missing"]
        XCTAssertThrowsError(try store.save(bad)); XCTAssertTrue(store.snapshot.progress.batch.isEmpty)
    }
    func testRemoveReaddAndUndo() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        try store.change { $0.progress.batch = [self.card().id] }
        try store.complete(card().id, source: "manual")
        try store.change { $0.progress.batch = [] }; try store.change { $0.progress.batch = [self.card().id] }
        XCTAssertTrue(store.remaining.isEmpty)
        try store.change { $0.progress.cards[self.card().id] = nil }
        XCTAssertEqual(store.remaining, [card().id])
    }
    func testCorruptActiveDataIsPreserved() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        let pointer = try String(contentsOf: root.appendingPathComponent("active-library"))
        let file = root.appendingPathComponent(pointer).appendingPathComponent("snapshot.json")
        try Data("broken".utf8).write(to: file)
        XCTAssertThrowsError(try WalletStore(directory: root, bundled: wallet([card()])))
        XCTAssertEqual(try String(contentsOf: file), "broken")
        XCTAssertEqual(store.products.count, 1)
    }
    final class FakeWriter: CardWriting {
        var callback: ((Result<Void, Error>) -> Void)?
        var calls = 0
        func write(_ dump: TagDump, staticKey: TagKey, dataKey: TagKey, completion: @escaping (Result<Void, Error>) -> Void) { calls += 1; callback = completion }
        func cancel() { callback?(.failure(WalletFailure("Cancelled"))) }
    }
    func testWriterSuccessAndFailureOnlyAffectCapturedCard() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card(), card(2)]))
        let fake = FakeWriter()
        let controller = CardDetailController(store: store, id: card().id, sequential: false, writer: fake)
        controller.loadViewIfNeeded(); controller.startWrite()
        fake.callback?(.failure(WalletFailure("Cancelled")))
        XCTAssertFalse(store.done(card().id))
        controller.startWrite(); fake.callback?(.success(()))
        XCTAssertTrue(store.done(card().id)); XCTAssertFalse(store.done(card(2).id))
        XCTAssertEqual(fake.calls, 2)
    }
    func testCompletionSaveRetryDoesNotRewrite() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        let fake = FakeWriter()
        let controller = CardDetailController(store: store, id: card().id, sequential: false, writer: fake)
        controller.loadViewIfNeeded(); controller.startWrite()
        let pointer = root.appendingPathComponent("active-library")
        try FileManager.default.removeItem(at: pointer)
        try FileManager.default.createDirectory(at: pointer, withIntermediateDirectories: true)
        fake.callback?(.success(()))
        XCTAssertTrue(controller.unsavedWrite); XCTAssertFalse(store.done(card().id))
        try FileManager.default.removeItem(at: pointer)
        controller.persistSuccess()
        XCTAssertFalse(controller.unsavedWrite); XCTAssertTrue(store.done(card().id)); XCTAssertEqual(fake.calls, 1)
    }
    func testLegacyInvalidKeyFallsBackToBundle() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(wallet([card()]))) as! [String: Any]
        object["dataKey"] = ["data": "placeholder"]
        try JSONSerialization.data(withJSONObject: object).write(to: root.appendingPathComponent("tagWallet.json"))
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        XCTAssertNotNil(store.snapshot.wallet.dataKey)
    }
    func testImageValidationAndProgressRestoreRejection() throws {
        XCTAssertThrowsError(try WalletStore.normalizedImage(Data("not image".utf8)))
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        var bad = store.snapshot; bad.progress.batch = [card().id, card().id]
        XCTAssertThrowsError(try store.save(bad))
    }

    func testCatalogAndBatchFilters() throws {
        var second = card(2); second.character = "Other"; second.name = "002 - Other"; second.productSeries = "Series 2"
        let store = try WalletStore(directory: root, bundled: wallet([card(), second]))
        try store.change { $0.progress.batch = [self.card().id, second.id] }
        try store.complete(second.id, source: "manual")
        let catalog = LibraryViewController(store: store, batch: false); catalog.loadViewIfNeeded()
        catalog.search.searchBar.text = "etoile"; catalog.refresh(); XCTAssertEqual(catalog.visible.count, 1)
        catalog.search.searchBar.text = ""; catalog.status = 2; catalog.series = "Series 2"; catalog.refresh()
        XCTAssertEqual(catalog.visible.map(\.id), [second.id])
        let batch = LibraryViewController(store: store, batch: true); batch.loadViewIfNeeded(); batch.refresh()
        XCTAssertEqual(batch.visible.map(\.id), [card().id])
    }
    func testMultipleListsRememberMembershipResumeAndDefaultAcrossLaunch() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card(), card(2)]))
        let first = try XCTUnwrap(store.snapshot.progress.activeBatchID)
        try store.change { $0.progress.batch = [self.card().id]; $0.progress.currentID = self.card().id }
        try store.createBatch(name: "Gifts")
        let second = try XCTUnwrap(store.snapshot.progress.activeBatchID)
        XCTAssertNotEqual(first, second); XCTAssertTrue(store.remaining.isEmpty)
        try store.change { $0.progress.batch.append(self.card(2).id) }
        try store.selectBatch(first)
        XCTAssertEqual(store.remaining, [card().id]); XCTAssertEqual(store.snapshot.progress.currentID, card().id)
        try store.complete(card().id, source: "manual")
        try store.selectBatch(second)
        let reopened = try WalletStore(directory: root, bundled: wallet([card(), card(2)]))
        XCTAssertEqual(reopened.activeBatchName, "Gifts")
        XCTAssertEqual(reopened.snapshot.progress.batch, [card(2).id])
        XCTAssertEqual(reopened.batches.count, 2); XCTAssertTrue(reopened.done(card().id))
        let backup = try JSONDecoder().decode(LibrarySnapshot.self, from: reopened.backup())
        XCTAssertEqual(backup.progress.savedBatches?.count, 2)
        XCTAssertThrowsError(try reopened.createBatch(name: "  "))
    }
    func testLegacyBackupMigratesSingleListAndRejectsInvalidSavedMembership() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card()]))
        var legacy = LibrarySnapshot(wallet: wallet([card()]))
        legacy.progress.batch = [card().id]
        try store.save(legacy)
        XCTAssertEqual(store.batches.count, 1)
        XCTAssertEqual(store.batches[0].cardIDs, [card().id])
        var invalid = store.snapshot
        invalid.progress.savedBatches?.append(SavedBatch(name: "Bad", cardIDs: ["missing"]))
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(store.batches.count, 1)
    }
    func testFilterDraftDoesNotMutateCatalogAndResetClearsEveryRestriction() throws {
        var figure = card(2); figure.type = "Figure"; figure.productSeries = "Series 2"
        let store = try WalletStore(directory: root, bundled: wallet([card(), figure]))
        let catalog = LibraryViewController(store: store, batch: false); catalog.loadViewIfNeeded()
        catalog.series = "Series 1"; catalog.search.searchBar.text = "etoile"; catalog.refresh()
        let draft = LibraryFiltersController(status: catalog.status, series: catalog.series, type: catalog.type,
            statusLabels: catalog.statusLabels, seriesNames: ["Series 1", "Series 2"]) { _, _, _, _ in XCTFail("Draft should not commit") }
        draft.loadViewIfNeeded()
        draft.tableView(draft.tableView, didSelectRowAt: IndexPath(row: 2, section: 3))
        XCTAssertEqual(draft.series, "Series 2"); XCTAssertEqual(catalog.series, "Series 1")
        catalog.resetFilters()
        XCTAssertNil(catalog.series); XCTAssertNil(catalog.type); XCTAssertEqual(catalog.search.searchBar.text, "")
        XCTAssertEqual(catalog.visible.count, 2)
        XCTAssertNil(catalog.navigationItem.prompt)
    }
    func testMembershipRefreshPreservesVisibleCellsAndSelection() throws {
        let store = try WalletStore(directory: root, bundled: wallet([card(), card(2)]))
        let controller = LibraryViewController(store: store, batch: false)
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.collectionView.layoutIfNeeded()
        let index = IndexPath(item: 0, section: 0)
        let cell = try XCTUnwrap(controller.collectionView.cellForItem(at: index) as? CardCell)
        controller.setEditing(true, animated: false)
        controller.collectionView.selectItem(at: index, animated: false, scrollPosition: [])
        try store.change { $0.progress.batch = [self.card().id] }
        XCTAssertTrue(controller.collectionView.cellForItem(at: index) === cell)
        XCTAssertEqual(controller.collectionView.indexPathsForSelectedItems, [index])
        XCTAssertEqual(cell.badge.title(for: .normal), "Queued · Remove")
        try store.change { $0.progress.batch.append(self.card(2).id) }
        XCTAssertTrue(controller.collectionView.cellForItem(at: index) === cell)
        XCTAssertEqual(cell.badge.title(for: .normal), "Queued · Remove")
    }
    func testFullCatalogRepeatedFilteringTiming() throws {
        let catalog = try JSONDecoder().decode(TagWallet.self, from: Data(contentsOf: Bundle(for: CardDetailController.self).url(forResource: "initialTagWallet.example", withExtension: "json")!))
        let store = try WalletStore(directory: root, bundled: catalog)
        let controller = LibraryViewController(store: store, batch: false); controller.loadViewIfNeeded()
        let series = try XCTUnwrap(store.products.first?.productSeries)
        let started = Date()
        for _ in 0..<20 {
            controller.series = series; controller.refresh(); XCTAssertEqual(controller.visible.count, 100)
            controller.resetFilters(); XCTAssertEqual(controller.visible.count, 509)
        }
        print("UX timing: 40 cached filter refreshes, seconds: \(Date().timeIntervalSince(started))")
        var edited = store.products[0]; edited.name = "Updated metadata"
        try store.importCatalog(CatalogEnvelope(schemaVersion: 1, tagProducts: [edited], staticKey: nil, dataKey: nil, images: nil), replace: true, keys: false)
        XCTAssertEqual(store.products.first(where: { $0.id == edited.id })?.name, edited.name)
    }
    func testBundledCatalogBackupContainsAllArtwork() throws {
        let bundle = Bundle(for: CardDetailController.self)
        let catalog = try JSONDecoder().decode(TagWallet.self, from: Data(contentsOf: bundle.url(forResource: "initialTagWallet.example", withExtension: "json")!))
        let store = try WalletStore(directory: root, bundled: catalog)
        XCTAssertEqual(store.products.count, 509)
        let backup = try JSONDecoder().decode(LibrarySnapshot.self, from: store.backup())
        XCTAssertEqual(backup.images.count, 509)
    }

}
