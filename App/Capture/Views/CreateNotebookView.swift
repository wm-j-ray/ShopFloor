import SwiftUI

struct CreateNotebookView: View {
    @EnvironmentObject var store: CaptureStore
    @Environment(\.dismiss) var dismiss

    let parentURL: URL?

    @State private var name = ""
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Notebook name", text: $name)
                        .autocorrectionDisabled(true)
                }
            }
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Could Not Create", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
        }
    }

    private func create() {
        do {
            try store.createNotebook(name: name.trimmingCharacters(in: .whitespaces), parent: parentURL)
            dismiss()
        } catch let e {
            error = e
        }
    }
}
