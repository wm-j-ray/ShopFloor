import UIKit

/// Level-by-level notebook tree browser presented inside the share extension.
/// Root level pre-selects Inbox ("Save to Inbox" in nav bar). Every sub-level
/// shows "Save Here". Tapping a leaf folder saves there immediately; tapping a
/// folder that has children navigates into it.
final class FolderPickerViewController: UITableViewController {

    // MARK: - Init

    private let folderURL: URL
    private let isRoot: Bool
    private let onSave: (URL) -> Void
    private let onCancel: () -> Void

    /// Only meaningful at root — the Inbox URL (created on first capture if absent).
    private var inboxURL: URL { folderURL.appendingPathComponent("Inbox", isDirectory: true) }

    init(folderURL: URL,
         isRoot: Bool,
         onSave: @escaping (URL) -> Void,
         onCancel: @escaping () -> Void) {
        self.folderURL = folderURL
        self.isRoot    = isRoot
        self.onSave    = onSave
        self.onCancel  = onCancel
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Data

    private struct FolderRow {
        let url: URL
        let hasChildren: Bool
    }
    private var rows: [FolderRow] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = isRoot ? "Save to Capture" : folderURL.lastPathComponent
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableFooterView = UIView()

        if isRoot {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self, action: #selector(cancelTapped)
            )
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Save to Inbox",
                style: .done,
                target: self, action: #selector(saveToInboxTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Save Here",
                style: .done,
                target: self, action: #selector(saveHereTapped)
            )
        }

        loadRows()
    }

    private func loadRows() {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        rows = entries
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && url.lastPathComponent != "Inbox" // Inbox shown separately at root
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                let hasChildren = children.contains {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }
                return FolderRow(url: url, hasChildren: hasChildren)
            }
        tableView.reloadData()
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        (isRoot ? 1 : 0) + rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if isRoot && indexPath.row == 0 {
            config.text = "Inbox"
            config.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
            config.image = UIImage(systemName: "tray.fill")
            config.imageProperties.tintColor = .systemBlue
            cell.accessoryType = .none
        } else {
            let row = rows[indexPath.row - (isRoot ? 1 : 0)]
            config.text = row.url.lastPathComponent
            config.image = UIImage(systemName: row.hasChildren ? "folder.fill" : "folder")
            config.imageProperties.tintColor = .systemBlue
            cell.accessoryType = row.hasChildren ? .disclosureIndicator : .none
        }

        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if isRoot && indexPath.row == 0 {
            onSave(inboxURL)
            return
        }

        let row = rows[indexPath.row - (isRoot ? 1 : 0)]
        if row.hasChildren {
            let childVC = FolderPickerViewController(
                folderURL: row.url,
                isRoot: false,
                onSave: onSave,
                onCancel: onCancel
            )
            navigationController?.pushViewController(childVC, animated: true)
        } else {
            onSave(row.url)
        }
    }

    // MARK: - Actions

    @objc private func saveToInboxTapped() { onSave(inboxURL) }
    @objc private func saveHereTapped()    { onSave(folderURL) }
    @objc private func cancelTapped()      { onCancel() }
}
