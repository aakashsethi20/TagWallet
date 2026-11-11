import UIKit
import UniformTypeIdentifiers

final class ImportController: UITableViewController, UIDocumentPickerDelegate {
    let store: WalletStore
    var mode = 0
    let scanner = ScanReader()
    let options = ["Import BIN files", "Import catalog", "Import unfixed-info.bin (data key)", "Import locked-secret.bin (static key)", "Export backup", "Restore backup", "Scan a tag"]
    init(store: WalletStore) { self.store = store; super.init(style: .insetGrouped); title = "Library & Backup"; tabBarItem.image = UIImage(systemName: "tray.and.arrow.down") }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        UserDefaults.standard.string(forKey: "lastBackupExport").map { "Last export: " + $0 }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.textLabel?.text = options[indexPath.row]; cell.textLabel?.numberOfLines = 0
        if indexPath.row == 2 { cell.detailTextLabel?.text = store.snapshot.wallet.dataKey == nil ? "Missing" : "Configured" }
        if indexPath.row == 3 { cell.detailTextLabel?.text = store.snapshot.wallet.staticKey == nil ? "Missing" : "Configured" }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true); mode = indexPath.row
        if mode == 6 {
            tabBarController?.tabBar.isUserInteractionEnabled = false; tableView.isUserInteractionEnabled = false
            scanner.start { result in
                self.tabBarController?.tabBar.isUserInteractionEnabled = true; self.tableView.isUserInteractionEnabled = true
                switch result {
                case .failure(let error): self.inform("Scan failed", error.localizedDescription)
                case .success(let dump):
                    let id = dump.headHex + dump.tailHex
                    var product = self.store.product(id) ?? TagProduct(productSeries: "Imported", character: "Scanned card", gameSeries: "Animal Crossing", imageURL: "", name: "Scanned card", type: "Card", head: dump.headHex, tail: dump.tailHex, dumps: [])
                    product.dumps = [dump]
                    self.reviewCatalog(CatalogEnvelope(schemaVersion: 1, tagProducts: [product], staticKey: nil, dataKey: nil, images: nil))
                }
            }
            return
        }
        if mode == 4 {
            let alert = UIAlertController(title: "Export private backup", message: "Includes keys, dumps, images and progress. Save to iCloud Drive or another location outside TagWallet so it survives uninstalling.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.addAction(UIAlertAction(title: "Export", style: .default) { _ in self.attempt {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("TagWallet-\(Int(Date().timeIntervalSince1970)).tagwalletbackup")
                try self.store.backup().write(to: url, options: .atomic)
                let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true); picker.delegate = self; self.present(picker, animated: true)
            } }); present(alert, animated: true); return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.allowsMultipleSelection = mode == 0; picker.delegate = self; present(picker, animated: true)
    }
    static func read(_ url: URL, limit: Int = 500_000_000) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(WalletFailure("Could not access file."))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { local in
            result = Result {
                let size = try local.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= limit else { throw WalletFailure("File exceeds the \(limit / 1_000_000) MB limit.") }
                return try Data(contentsOf: local)
            }
        }
        if let error = coordinationError { throw error }; return try result.get()
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if mode == 4 {
            UserDefaults.standard.set(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short), forKey: "lastBackupExport")
            viewWillAppear(false); return
        }
        guard let first = urls.first else { return }
        do {
            switch mode {
            case 0: reviewBins(urls)
            case 1:
                let envelope = try JSONDecoder().decode(CatalogEnvelope.self, from: Self.read(first))
                guard envelope.schemaVersion == nil || envelope.schemaVersion == 1 else { throw WalletFailure("Unsupported catalog version.") }
                try WalletStore.validate(LibrarySnapshot(wallet: TagWallet(tagProducts: envelope.tagProducts, staticKey: envelope.staticKey, dataKey: envelope.dataKey), images: envelope.images ?? [:]))
                reviewCatalog(envelope)
            case 2, 3:
                guard let key = TagKey(data: try Self.read(first, limit: 1000)) else { throw WalletFailure("Expected a valid 80-byte key file.") }
                let dataKey = mode == 2
                confirm("Replace \(dataKey ? "data" : "static") key?", "Library and progress will be preserved.") {
                    self.attempt { try self.store.change { if dataKey { $0.wallet.dataKey = key } else { $0.wallet.staticKey = key } }; self.tableView.reloadData() }
                }
            case 5:
                let backup = try JSONDecoder().decode(LibrarySnapshot.self, from: Self.read(first))
                try WalletStore.validate(backup)
                let completed = backup.progress.cards.values.filter { $0.completedAt != nil }.count
                confirm("Replace library and progress?", "Backup: \(backup.createdAt)\n\(backup.wallet.tagProducts.count) cards, \(backup.progress.batch.count) in batch, \(completed) done. A local pre-restore snapshot will be retained.") {
                    self.attempt {
                        try self.store.backup().write(to: self.store.directory.appendingPathComponent("before-restore.tagwalletbackup"), options: .atomic)
                        try self.store.save(backup); self.tableView.reloadData(); self.inform("Backup restored")
                    }
                }
            default: break
            }
        } catch { inform("Import failed", error.localizedDescription) }
    }
    func confirm(_ title: String, _ message: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in action() }); present(alert, animated: true)
    }
    func reviewBins(_ urls: [URL]) {
        var products: [TagProduct] = [], errors: [String] = []
        for url in urls {
            do {
                let data = try Self.read(url, limit: 1000)
                guard [532, 540].contains(data.count), let dump = TagDump(data: data) else { throw WalletFailure("Expected 532 or 540 bytes.") }
                let id = dump.headHex + dump.tailHex
                var product = store.product(id) ?? TagProduct(productSeries: "Imported", character: url.deletingPathExtension().lastPathComponent, gameSeries: "Animal Crossing", imageURL: "", name: url.deletingPathExtension().lastPathComponent, type: "Card", head: dump.headHex, tail: dump.tailHex, dumps: [])
                product.dumps = [dump]; products = WalletStore.merge(products, [product], replace: false)
            } catch { errors.append(url.lastPathComponent + ": " + error.localizedDescription) }
        }
        guard !products.isEmpty else { inform("No valid BIN files", errors.joined(separator: "\n")); return }
        let envelope = CatalogEnvelope(schemaVersion: 1, tagProducts: products, staticKey: nil, dataKey: nil, images: nil)
        let counts = summary(products)
        confirm("Import valid files?", counts + (errors.isEmpty ? "" : "\nRejected:\n" + errors.joined(separator: "\n"))) {
            self.attempt { try self.store.importCatalog(envelope, replace: false, keys: false); self.offerBatch(products.map(\.id)) }
        }
    }
    func summary(_ products: [TagProduct]) -> String {
        var added = 0, dumps = 0, duplicates = 0
        for p in products {
            if let old = store.product(p.id) {
                for dump in p.dumps { if old.dumps.contains(dump) { duplicates += 1 } else { dumps += 1 } }
            } else { added += 1 }
        }
        return "\(added) new cards, \(dumps) additional dumps, \(duplicates) duplicate dumps."
    }
    func reviewCatalog(_ envelope: CatalogEnvelope) {
        let review = CatalogReviewController(message: summary(envelope.tagProducts), hasKeys: envelope.dataKey != nil || envelope.staticKey != nil) { replace, keys in
            self.attempt { try self.store.importCatalog(envelope, replace: replace, keys: keys); self.offerBatch(envelope.tagProducts.map(\.id)) }
        }
        present(UINavigationController(rootViewController: review), animated: true)
    }
    func offerBatch(_ ids: [String]) {
        confirm("Import complete", "Add these \(ids.count) cards to \(store.activeBatchName)?") {
            self.attempt { try self.store.change { next in for id in ids where !next.progress.batch.contains(id) { next.progress.batch.append(id) } } }
        }
    }
}
final class CatalogReviewController: UITableViewController {
    let message: String
    let hasKeys: Bool
    let accept: (Bool, Bool) -> Void
    let replace = UISwitch(), keys = UISwitch()
    init(message: String, hasKeys: Bool, accept: @escaping (Bool, Bool) -> Void) { self.message = message; self.hasKeys = hasKeys; self.accept = accept; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Review catalog"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Import", style: .done, target: self, action: #selector(commit))
    }
    @objc func cancel() { dismiss(animated: true) }
    @objc func commit() { dismiss(animated: true) { self.accept(self.replace.isOn, self.keys.isOn) } }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { hasKeys ? 3 : 2 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil); cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = indexPath.row == 0 ? message + "\nCompletion history will be preserved." : indexPath.row == 1 ? "Replace matching metadata and images" : "Use included keys"
        if indexPath.row == 1 { cell.accessoryView = replace }; if indexPath.row == 2 { cell.accessoryView = keys }; return cell
    }
}

final class RecoveryController: UIViewController, UIDocumentPickerDelegate {
    let failure: Error
    let recovered: () -> Void
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    init(error: Error, recovered: @escaping () -> Void) { self.failure = error; self.recovered = recovered; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        let label = UILabel(); label.numberOfLines = 0; label.text = "Your library could not be loaded. Original files are preserved.\n\n" + failure.localizedDescription
        let previous = UIButton(type: .system); previous.setTitle("Recover previous saved generation", for: .normal); previous.addTarget(self, action: #selector(recoverPrevious), for: .touchUpInside)
        let restore = UIButton(type: .system); restore.setTitle("Restore external backup", for: .normal); restore.addTarget(self, action: #selector(chooseBackup), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, previous, restore]); stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack); NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24), stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    }
    @objc func chooseBackup() { let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true); picker.delegate = self; present(picker, animated: true) }
    @objc func recoverPrevious() {
        attempt {
            let previous = try String(contentsOf: directory.appendingPathComponent("previous-library"), encoding: .utf8)
            guard UUID(uuidString: previous) != nil else { throw WalletFailure("No valid previous generation.") }
            let data = try Data(contentsOf: directory.appendingPathComponent(previous).appendingPathComponent("snapshot.json"))
            try review(data)
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { guard let url = urls.first else { return }; attempt { try review(ImportController.read(url)) } }
    func review(_ data: Data) throws {
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: data); try WalletStore.validate(snapshot)
        let alert = UIAlertController(title: "Recover this library?", message: "\(snapshot.wallet.tagProducts.count) cards, \(snapshot.progress.batch.count) in batch. Existing files will be preserved.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.addAction(UIAlertAction(title: "Recover", style: .default) { _ in self.attempt {
            let name = UUID().uuidString; let folder = self.directory.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent("snapshot.json"), options: .atomic)
            // Leave all existing generations untouched until the next successful store load.
            try name.write(to: self.directory.appendingPathComponent("active-library"), atomically: true, encoding: .utf8)
            self.recovered()
        } }); present(alert, animated: true)
    }
}
