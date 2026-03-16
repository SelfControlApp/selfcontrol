import SwiftUI

struct BlocklistEditorView: View {
    @Binding var blocklist: [String]
    let isAllowlist: Bool
    let onSave: () -> Void

    @State private var newEntry = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isAllowlist ? "Allowlist" : "Blocklist")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Add entry field
            HStack {
                TextField("Add domain (e.g. facebook.com)", text: $newEntry)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addEntry() }

                Button("Add") { addEntry() }
                    .disabled(newEntry.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Domain list
            List {
                ForEach(blocklist, id: \.self) { entry in
                    Text(entry)
                        .font(.system(.body, design: .monospaced))
                }
                .onDelete { indices in
                    blocklist.remove(atOffsets: indices)
                    onSave()
                }
            }

            // Footer
            HStack {
                Text("\(blocklist.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Remove All") {
                    blocklist.removeAll()
                    onSave()
                }
                .disabled(blocklist.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    private func addEntry() {
        let cleaned = newEntry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !blocklist.contains(cleaned) else { return }
        blocklist.append(cleaned)
        newEntry = ""
        onSave()
    }
}
