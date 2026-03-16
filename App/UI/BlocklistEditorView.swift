import SwiftUI

struct BlocklistEditorView: View {
    @Binding var blocklist: [String]
    let isAllowlist: Bool
    let onSave: () -> Void

    @State private var newEntry = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAllowlist ? "Allowlist" : "Blocklist")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(blocklist.count) sites")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Done") {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Add field
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))

                TextField("facebook.com", text: $newEntry)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .focused($fieldFocused)
                    .onSubmit { addEntry() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List
            if blocklist.isEmpty {
                VStack(spacing: 6) {
                    Text("No sites yet")
                        .foregroundStyle(.secondary)
                    Text("Type a domain above and press Return")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(blocklist, id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 13, design: .monospaced))
                        }
                    .onDelete { indices in
                        blocklist.remove(atOffsets: indices)
                        onSave()
                    }
                }
            }

            // Footer
            if !blocklist.isEmpty {
                Divider()
                HStack {
                    Spacer()
                    Button("Remove All") {
                        blocklist.removeAll()
                        onSave()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 400, height: 380)
        .onAppear { fieldFocused = true }
    }

    private func addEntry() {
        let cleaned = newEntry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !blocklist.contains(cleaned) else { return }
        blocklist.append(cleaned)
        newEntry = ""
        onSave()
    }
}
