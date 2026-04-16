import SwiftUI

struct CreateCaptureView: View {
    @EnvironmentObject var store: CaptureStore
    @Environment(\.dismiss) var dismiss

    let destinationURL: URL

    @State private var title = ""
    @State private var bodyText = ""
    @State private var captureNote = ""
    @State private var isSaving = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("What is this?", text: $title)
                        .autocorrectionDisabled(false)
                }
                Section("Content") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 160)
                }
                Section {
                    TextEditor(text: $captureNote)
                        .frame(minHeight: 60)
                        .foregroundStyle(captureNote.isEmpty ? .secondary : .primary)
                        .overlay(alignment: .topLeading) {
                            if captureNote.isEmpty {
                                Text("Add a quick note...")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Note (optional)")
                } footer: {
                    Text("Context for this capture. Not part of the content.")
                        .font(.caption)
                }
            }
            .navigationTitle("New Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Could Not Save", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        do {
            try store.createCapture(
                title: title.trimmingCharacters(in: .whitespaces),
                body: bodyText,
                notebook: destinationURL,
                captureNote: captureNote.isEmpty ? nil : captureNote
            )
            dismiss()
        } catch let e {
            error = e
            isSaving = false
        }
    }
}
