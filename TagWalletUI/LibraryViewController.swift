import UIKit
import UniformTypeIdentifiers

extension UIViewController {
    func inform(_ title: String, _ message: String = "") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    func attempt(_ action: () throws -> Void) { do { try action() } catch { inform("Could not save", error.localizedDescription) } }
}
final class CardCell: UICollectionViewCell {
    let artwork = UIImageView(), name = UILabel(), badge = UIButton(type: .system)
    var action: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 14
        artwork.contentMode = .scaleAspectFit
        name.font = .preferredFont(forTextStyle: .headline); name.adjustsFontForContentSizeCategory = true; name.numberOfLines = 2
        badge.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        badge.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [artwork, name, badge]); stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10), stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10), stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10), stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10), artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor, multiplier: 1.25)])
    }
    required init?(coder: NSCoder) { fatalError("Programmatic cell") }
    @objc func tapped() { action?() }
    override var isSelected: Bool { didSet { contentView.layer.borderWidth = isSelected ? 3 : 0; contentView.layer.borderColor = UIColor.systemGreen.cgColor } }
    override func prepareForReuse() { super.prepareForReuse(); artwork.image = nil; action = nil; accessibilityIdentifier = nil }
}
final class LibraryViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UISearchResultsUpdating {
    let store: WalletStore
    let batch: Bool
    var visible: [TagProduct] = []
    var status = 0
    var series: String?
    var type: String? = "Card"
    let search = UISearchController(searchResultsController: nil)
    let summary = UILabel()
    var statusLabels: [String] { batch ? ["Remaining", "Done", "All statuses"] : ["All statuses", "Remaining", "Done"] }

    init(store: WalletStore, batch: Bool) {
        self.store = store; self.batch = batch
        let layout = UICollectionViewFlowLayout(); layout.minimumInteritemSpacing = 12; layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        super.init(collectionViewLayout: layout)
        title = batch ? "Batch" : "Catalog"
        tabBarItem.image = UIImage(systemName: batch ? "gift" : "square.grid.2x2")
    }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.allowsSelectionDuringEditing = true
        collectionView.allowsMultipleSelectionDuringEditing = true
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(CardCell.self, forCellWithReuseIdentifier: "card")
        definesPresentationContext = true
        summary.font = .preferredFont(forTextStyle: .footnote)
        summary.adjustsFontForContentSizeCategory = true
        summary.textColor = .secondaryLabel; summary.textAlignment = .center
        summary.numberOfLines = 0
        summary.frame.size.height = 40
        collectionView.addSubview(summary)
        collectionView.contentInset.top = 40
        search.searchResultsUpdater = self; search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Character or card number"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItems = [editButtonItem, UIBarButtonItem(title: "Lists", style: .plain, target: self, action: #selector(batchLists))]
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Filters", style: .plain, target: self, action: #selector(filters))
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: WalletStore.changed, object: store)
        refresh()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
    func updateSearchResults(for searchController: UISearchController) { refresh() }
    @objc func refresh() {
        let query = search.searchBar.text ?? ""
        let source = batch ? store.snapshot.progress.batch.compactMap(store.product) : store.products
        let oldIDs = visible.map(\.id)
        visible = source.filter { p in
            let done = store.done(p.id)
            let allowed = batch ? (status == 0 ? !done : status == 1 ? done : true) : (status == 0 ? true : status == 1 ? !done : done)
            return allowed && (type == nil || p.type == type) && (series == nil || p.productSeries == series) && (query.isEmpty || (p.name + " " + p.character + " " + (p.cardNumber ?? "")).localizedStandardContains(query))
        }
        summary.text = batch ? "\(store.activeBatchName): \(store.snapshot.progress.batch.count - store.remaining.count) of \(store.snapshot.progress.batch.count) done · \(statusLabels[status])" : "\(visible.count) cards · Add to \(store.activeBatchName)"
        let toolbar = batch && !isEditing ? [UIBarButtonItem(title: "Start / Resume writing", style: .done, target: self, action: #selector(resume))] : isEditing ? [UIBarButtonItem(title: "Add selected", style: .plain, target: self, action: #selector(addSelected)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "Remove selected", style: .plain, target: self, action: #selector(removeSelected))] : []
        toolbarItems = toolbar; navigationController?.setToolbarHidden(toolbar.isEmpty, animated: false)
        if oldIDs == visible.map(\.id) {
            // Keep existing cells and selection for membership/progress-only changes.
            UIView.performWithoutAnimation {
                for index in collectionView.indexPathsForVisibleItems {
                    if let cell = collectionView.cellForItem(at: index) as? CardCell {
                        configure(cell, product: visible[index.item])
                    }
                }
            }
        } else {
            collectionView.reloadData()
        }
        let label = UILabel(); label.textAlignment = .center; label.numberOfLines = 0
        label.text = batch && store.snapshot.progress.batch.isEmpty ? "Add cards from Catalog to start your batch." : "No cards match this filter."
        collectionView.backgroundView = visible.isEmpty ? label : nil
    }
    override func setEditing(_ editing: Bool, animated: Bool) { super.setEditing(editing, animated: animated); collectionView.allowsMultipleSelection = editing; refresh() }
    func resetFilters() {
        status = batch ? 2 : 0; series = nil; type = nil
        search.searchBar.text = ""; refresh()
    }
    @objc func filters() {
        // End search presentation before presenting a separate modal.
        let controller = LibraryFiltersController(status: status, series: series, type: type,
            statusLabels: statusLabels, seriesNames: Set(store.products.map(\.productSeries)).sorted()) { [weak self] status, series, type, reset in
                guard let self = self else { return }
                if reset { self.resetFilters() }
                else { self.status = status; self.series = series; self.type = type; self.refresh() }
        }
        presentLibrarySheet(controller)
    }
    func presentLibrarySheet(_ controller: UIViewController) {
        let show = { self.present(UINavigationController(rootViewController: controller), animated: true) }
        if search.isActive { search.dismiss(animated: false) { self.search.isActive = false; show() } }
        else { show() }
    }
    @objc func batchLists() { presentLibrarySheet(BatchListsController(store: store)) }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        summary.frame = CGRect(x: 16, y: -40, width: max(0, collectionView.bounds.width - 32), height: 40)
    }
    @objc func addSelected() { updateSelected(remove: false) }
    @objc func removeSelected() { updateSelected(remove: true) }
    func updateSelected(remove: Bool) {
        let ids = (collectionView.indexPathsForSelectedItems ?? []).sorted().map { visible[$0.item].id }
        attempt { try store.change { next in
            if remove { next.progress.batch.removeAll { ids.contains($0) } }
            else { for id in ids where !next.progress.batch.contains(id) { next.progress.batch.append(id) } }
        }; setEditing(false, animated: true) }
    }
    @objc func resume() {
        let saved = store.snapshot.progress.currentID
        guard let id = saved.flatMap({ store.remaining.contains($0) ? $0 : nil }) ?? store.remaining.first else { inform("Batch complete", "Add more cards from Catalog, or use the Done filter."); return }
        navigationController?.pushViewController(CardDetailController(store: store, id: id, sequential: true), animated: true)
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { visible.count }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "card", for: indexPath) as! CardCell
        configure(cell, product: visible[indexPath.item])
        return cell
    }
    func configure(_ cell: CardCell, product p: TagProduct) {
        let needsArtwork = cell.accessibilityIdentifier != p.id || cell.artwork.image == nil
        cell.accessibilityIdentifier = p.id
        cell.name.text = p.name
        let localImage = store.image(p)
        if needsArtwork || (localImage != nil && localImage !== cell.artwork.image) {
            cell.artwork.image = localImage ?? UIImage(systemName: "rectangle.portrait")
        }
        if localImage == nil && needsArtwork && !p.imageURL.isEmpty { p.getImage { [weak cell] image in if cell?.accessibilityIdentifier == p.id { cell?.artwork.image = image } } }
        let state = store.done(p.id) ? "✓ Done" : store.snapshot.progress.batch.contains(p.id) ? "Queued · Remove" : "+ Add"
        if cell.badge.title(for: .normal) != state {
            UIView.performWithoutAnimation { cell.badge.setTitle(state, for: .normal); cell.badge.layoutIfNeeded() }
        }
        cell.badge.accessibilityLabel = state + " " + p.name
        cell.badge.isEnabled = !isEditing
        cell.action = { [weak self] in guard let self = self else { return }; self.attempt { try self.store.change { next in
            if next.progress.batch.contains(p.id) { next.progress.batch.removeAll { $0 == p.id } } else { next.progress.batch.append(p.id) }
        } } }
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isEditing else { return }
        collectionView.deselectItem(at: indexPath, animated: false)
        navigationController?.pushViewController(CardDetailController(store: store, id: visible[indexPath.item].id, sequential: batch), animated: true)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : collectionView.bounds.width > 600 ? 4 : 2
        let width = (collectionView.bounds.width - 32 - (columns - 1) * 12) / columns
        return CGSize(width: width, height: (width - 20) * 1.25 + 120)
    }
}

final class BatchListsController: UITableViewController {
    let store: WalletStore
    init(store: WalletStore) { self.store = store; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Batch lists"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "New batch", style: .done, target: self, action: #selector(create))
    }
    @objc func close() { dismiss(animated: true) }
    @objc func create() {
        let alert = UIAlertController(title: "New batch", message: "Add will use this list. Completion history is shared across lists.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Batch name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            self.attempt { try self.store.createBatch(name: alert.textFields?.first?.text ?? ""); self.tableView.reloadData() }
        })
        present(alert, animated: true)
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { store.batches.count }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Add uses the selected list until you switch lists. Completion and Switch-tested history are shared."
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let list = store.batches[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = list.name; cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = "\(list.cardIDs.count) cards"
        cell.accessoryType = list.id == store.snapshot.progress.activeBatchID ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        attempt { try store.selectBatch(store.batches[indexPath.row].id); dismiss(animated: true) }
    }
}

/// Edits a local draft. Swiping/Cancel discards it; Apply commits after dismissal.
final class LibraryFiltersController: UITableViewController {
    var status: Int
    var series: String?
    var type: String?
    let statusLabels: [String]
    let seriesNames: [String]
    let apply: (Int, String?, String?, Bool) -> Void
    init(status: Int, series: String?, type: String?, statusLabels: [String], seriesNames: [String], apply: @escaping (Int, String?, String?, Bool) -> Void) {
        self.status = status; self.series = series; self.type = type
        self.statusLabels = statusLabels; self.seriesNames = seriesNames; self.apply = apply
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Filters"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Apply", style: .done, target: self, action: #selector(commit))
    }
    @objc func cancel() { dismiss(animated: true) }
    @objc func commit() { dismiss(animated: true) { self.apply(self.status, self.series, self.type, false) } }
    override func numberOfSections(in tableView: UITableView) -> Int { 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [1, statusLabels.count, 3, seriesNames.count + 1][section]
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Reset", "Completion status", "Product type", "Series"][section]
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let row = indexPath.row
        var selected = false
        switch indexPath.section {
        case 0: cell.textLabel?.text = "Show all cards (clear filters and search)"
        case 1: cell.textLabel?.text = statusLabels[row]; selected = status == row
        case 2: cell.textLabel?.text = ["All types", "Card", "Figure"][row]; selected = type == [nil, "Card", "Figure"][row]
        default: cell.textLabel?.text = row == 0 ? "All series" : seriesNames[row - 1]; selected = series == (row == 0 ? nil : seriesNames[row - 1])
        }
        cell.textLabel?.numberOfLines = 0; cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.accessoryType = selected ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        switch indexPath.section {
        case 0: dismiss(animated: true) { self.apply(self.status, nil, nil, true) }; return
        case 1: status = row
        case 2: type = [nil, "Card", "Figure"][row]
        default: series = row == 0 ? nil : seriesNames[row - 1]
        }
        tableView.reloadData()
    }
}

final class CardDetailController: UITableViewController, UIDocumentPickerDelegate {
    let store: WalletStore
    var id: String
    let sequential: Bool
    let writer: CardWriting
    var writing = false
    var unsavedWrite = false
    var dumpIndex = 0
    init(store: WalletStore, id: String, sequential: Bool, writer: CardWriting = BatchWriter()) {
        self.store = store; self.id = id; self.sequential = sequential; self.writer = writer
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    var product: TagProduct { store.product(id)! }
    override func viewDidLoad() { super.viewDidLoad(); refresh() }
    func refresh() {
        title = product.name
        let image = UIImageView(image: store.image(product) ?? UIImage(systemName: "rectangle.portrait"))
        image.contentMode = .scaleAspectFit; image.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 260)
        tableView.tableHeaderView = image; tableView.reloadData()
    }
    var actions: [String] {
        [unsavedWrite ? "Retry saving completion (tag already written)" : "Write card", store.snapshot.progress.batch.contains(id) ? "Remove from batch" : "Add to batch", store.done(id) ? "Undo done" : "Mark done manually", "Switch tested: \(store.snapshot.progress.cards[id]?.switchTested == true ? "Yes" : "No")", "Edit character details", "Choose image", "Dump \(dumpIndex + 1) of \(product.dumps.count)"] + (sequential ? ["Write next", "Skip for now"] : [])
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { actions.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = actions[indexPath.row]; cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = indexPath.row == 0 ? .systemBlue : .label
        if indexPath.row == 3 && !store.done(id) { cell.textLabel?.textColor = .secondaryLabel }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !writing else { return }
        switch indexPath.row {
        case 0: unsavedWrite ? persistSuccess() : confirmWrite()
        case 1: attempt { try store.change { next in if next.progress.batch.contains(id) { next.progress.batch.removeAll { $0 == id } } else { next.progress.batch.append(id) } }; refresh() }
        case 2: attempt { if store.done(id) { try store.change { $0.progress.cards[id] = nil } } else { try store.complete(id, source: "manual") }; refresh() }
        case 3: guard store.done(id) else { return }; attempt { try store.change { $0.progress.cards[id]?.switchTested.toggle() }; refresh() }
        case 4: editDetails()
        case 5:
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.png, .jpeg], asCopy: true); picker.delegate = self; present(picker, animated: true)
        case 6:
            guard product.dumps.count > 1 else { return }
            dumpIndex = (dumpIndex + 1) % product.dumps.count; refresh()
        case 7: next(start: true)
        case 8:
            guard store.remaining.count > 1 else { inform("Only one card remains"); return }
            attempt { try store.change { $0.progress.batch.removeAll { $0 == id }; $0.progress.batch.append(id) }; next(start: false) }
        default: break
        }
    }
    func editDetails() {
        let alert = UIAlertController(title: "Character details", message: nil, preferredStyle: .alert)
        for value in [product.character, product.cardNumber ?? "", product.productSeries] { alert.addTextField { $0.text = value } }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in self.attempt {
            try self.store.change { next in
                guard let i = next.wallet.tagProducts.firstIndex(where: { $0.id == self.id }) else { return }
                next.wallet.tagProducts[i].character = alert.textFields?[0].text ?? ""
                next.wallet.tagProducts[i].cardNumber = alert.textFields?[1].text
                next.wallet.tagProducts[i].productSeries = alert.textFields?[2].text ?? "Imported"
                next.wallet.tagProducts[i].name = [next.wallet.tagProducts[i].cardNumber ?? "", next.wallet.tagProducts[i].character].filter { !$0.isEmpty }.joined(separator: " - ")
            }; self.refresh()
        } }); present(alert, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        attempt {
            let data = try WalletStore.normalizedImage(ImportController.read(url, limit: 10_000_000))
            let preview = ImageReviewController(data: data) {
                self.attempt { try self.store.change { $0.images[self.id] = data }; self.refresh() }
            }
            present(UINavigationController(rootViewController: preview), animated: true)
        }
    }
    func confirmWrite() {
        if store.done(id) {
            let alert = UIAlertController(title: "Write another copy?", message: "This card is already marked done.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.addAction(UIAlertAction(title: "Write", style: .default) { _ in self.startWrite() }); present(alert, animated: true)
        } else { startWrite() }
    }
    func startWrite() {
        guard !writing, !unsavedWrite, product.dumps.indices.contains(dumpIndex), let staticKey = store.snapshot.wallet.staticKey, let dataKey = store.snapshot.wallet.dataKey else { inform("Cannot write", "Import both keys and a valid dump first."); return }
        do { try store.change { $0.progress.currentID = id } } catch { inform("Could not save position", error.localizedDescription); return }
        let capturedID = id
        writing = true; navigationItem.hidesBackButton = true; tabBarController?.tabBar.isUserInteractionEnabled = false; tableView.isUserInteractionEnabled = false
        writer.write(product.dumps[dumpIndex], staticKey: staticKey, dataKey: dataKey) { result in
            self.writing = false; self.navigationItem.hidesBackButton = false; self.tabBarController?.tabBar.isUserInteractionEnabled = true; self.tableView.isUserInteractionEnabled = true
            guard self.id == capturedID else { return }
            switch result {
            case .success: self.unsavedWrite = true; self.navigationItem.hidesBackButton = true; self.tabBarController?.tabBar.isUserInteractionEnabled = false; self.persistSuccess()
            case .failure(let error): self.inform("Not completed", error.localizedDescription)
            }
        }
    }
    func persistSuccess() {
        do {
            try store.complete(id, source: "nfc"); unsavedWrite = false; navigationItem.hidesBackButton = false; tabBarController?.tabBar.isUserInteractionEnabled = true; refresh()
            let alert = UIAlertController(title: "Written: \(product.name)", message: nil, preferredStyle: .alert)
            if sequential && !store.remaining.isEmpty { alert.addAction(UIAlertAction(title: "Write next", style: .default) { _ in self.next(start: true) }) }
            alert.addAction(UIAlertAction(title: "Close", style: .cancel)); present(alert, animated: true)
        } catch { refresh(); inform("Tag written; progress not saved", "Use Retry saving completion. Do not rewrite this tag.\n" + error.localizedDescription) }
    }
    func next(start: Bool) {
        guard !unsavedWrite else { inform("Save completion first"); return }
        guard let nextID = store.remaining.first(where: { $0 != id }) ?? (store.done(id) ? nil : store.remaining.first) else { inform("Batch complete"); return }
        do { try store.change { $0.progress.currentID = nextID } }
        catch { inform("Could not save position", error.localizedDescription); return }
        id = nextID; dumpIndex = 0; refresh()
        if start { startWrite() }
    }
}


final class ImageReviewController: UIViewController {
    let data: Data
    let saveImage: () -> Void
    init(data: Data, save: @escaping () -> Void) { self.data = data; self.saveImage = save; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Programmatic controller") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Preview image"; view.backgroundColor = .systemBackground
        let image = UIImageView(image: UIImage(data: data)); image.contentMode = .scaleAspectFit; image.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(image); NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), image.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), image.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), image.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)])
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save image", style: .done, target: self, action: #selector(save))
    }
    @objc func cancel() { dismiss(animated: true) }
    @objc func save() { dismiss(animated: true, completion: saveImage) }
}
