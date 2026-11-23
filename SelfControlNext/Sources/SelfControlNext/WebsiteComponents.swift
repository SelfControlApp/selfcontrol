import SwiftUI

/// Editable list of blocked websites, used in Focus Session and Downtime.
struct WebsiteListEditor: View {
    @Binding var websites: [String]
    var locked = false
    @State private var entry = ""
    @State private var invalid = false

    var body: some View {
        ForEach(websites, id: \.self) { site in
            HStack(spacing: 10) {
                Image(systemName: Domains.isIPv4(site) || Domains.isIPRange(site) ? "network" : "globe")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(site)
                Spacer()
                Button {
                    withAnimation { websites.removeAll { $0 == site } }
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .help("Remove")
            }
        }
        HStack {
            TextField("Website", text: $entry, prompt: Text("Add a website, like youtube.com"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
                .onChange(of: entry) { invalid = false }
            Button("Add", action: add)
                .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .disabled(locked)
        if invalid {
            Text("That doesn't look like a website address.").font(.caption).foregroundStyle(.red)
        }
    }

    private func add() {
        // Accept several entries separated by commas, spaces or newlines.
        let parts = entry.split(whereSeparator: { ",; \n".contains($0) }).map(String.init)
        let normalized = parts.compactMap(Domains.normalize)
        guard !normalized.isEmpty, normalized.count == parts.count else { invalid = true; return }
        withAnimation {
            for site in normalized where !websites.contains(site) { websites.append(site) }
        }
        entry = ""
    }
}

/// Inline prompt shown where a feature needs the root helper.
struct HelperRequiredRow: View {
    @Environment(Store.self) private var store
    let reason: String
    @State private var error: String?

    var body: some View {
        if !store.helper.isAvailable {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill").font(.title2).foregroundStyle(.orange)
                    Text(reason).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    InstallHelperButton(error: $error)
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .padding(.vertical, 4)
        }
    }
}

struct InstallHelperButton: View {
    @Environment(Store.self) private var store
    @Binding var error: String?

    var body: some View {
        Button(store.helper.health == .outdated ? "Update Helper…" : "Install Helper…") {
            Task {
                do {
                    try await store.helper.install()
                    error = nil
                    await store.syncRules()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
        .disabled(store.helper.isBusy)
    }
}

/// Transient message, e.g. when Strict Mode rejects an edit.
struct NoticeBanner: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let notice = store.notice {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                Text(notice).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button { store.notice = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
            }
            .font(.callout)
            .padding(12)
            .foregroundStyle(.white)
            .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Banner explaining Strict Mode on pages whose rules it locks.
struct StrictModeRow: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.isStrict {
            Label {
                Text("Strict Mode is on. You can make these rules stricter, but changes that loosen them are blocked.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.fill").foregroundStyle(.orange)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
