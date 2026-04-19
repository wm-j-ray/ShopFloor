import UIKit

/// Level-by-level notebook tree browser presented inside the share extension.
///
/// At the root level a pre-filled title field is shown above the folder list so Karen
/// can rename the capture before saving. Child levels (pushed via navigation) do not
/// repeat the field — the title is captured by a closure in ShareViewController.
///
/// Root:    "Save to Inbox" nav-bar button (default fast path) + folder list.
/// Sub-level: "Save Here" nav-bar button + folder list.
/// Tapping a leaf folder saves there immediately; a folder with children pushes deeper.
final class FolderPickerViewController: UITableViewController {

    // MARK: - Init

    private let folderURL: URL
    private let isRoot: Bool
    private let onSave: (URL) -> Void
    private let onCancel: () -> Void

    /// Pre-filled title shown in the header text field (root only).
    private let candidateTitle: String
    /// Called every time the user edits the title field (root only).
    private let onTitleChanged: ((String) -> Void)?

    private var inboxURL: URL { folderURL.appendingPathComponent("Inbox", isDirectory: true) }

    init(folderURL: URL,
         isRoot: Bool,
         candidateTitle: String = "",
         onTitleChanged: ((String) -> Void)? = nil,
         onSave: @escaping (URL) -> Void,
         onCancel: @escaping () -> Void) {
        self.folderURL      = folderURL
        self.isRoot         = isRoot
        self.candidateTitle = candidateTitle
        self.onTitleChanged = onTitleChanged
        self.onSave         = onSave
        self.onCancel       = onCancel
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
        tableView.keyboardDismissMode = .onDrag

        if isRoot {
            tableView.tableHeaderView = makeTitleHeaderView()
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

    // MARK: - Title header (root only)

    private func makeTitleHeaderView() -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Title"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        let field = UITextField()
        field.text = candidateTitle
        field.placeholder = "Title"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .done
        field.autocorrectionType = .default
        field.translatesAutoresizingMaskIntoConstraints = false
        field.addTarget(self, action: #selector(titleFieldChanged(_:)), for: .editingChanged)
        field.delegate = self

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(field)
        container.addSubview(divider)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            divider.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Size the header to fit its content.
        container.frame = CGRect(x: 0, y: 0, width: 0, height: 80)
        return container
    }

    @objc private func titleFieldChanged(_ field: UITextField) {
        onTitleChanged?(field.text ?? "")
    }

    // MARK: - Data

    private func loadRows() {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        rows = entries
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && url.lastPathComponent != "Inbox"
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

// MARK: - UITextFieldDelegate

extension FolderPickerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
