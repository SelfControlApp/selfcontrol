import SwiftUI

/// Searchable, multi-select list of installed apps.
struct AppPickerSheet: View {
    let title: String
    let excluded: Set<String>
    let onAdd: ([AppRef]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var catalog = AppCatalog.shared
    @State private var query = ""
    @State private var selected: [String: AppRef] = [:]
    @State private var extra: [AppRef] = []

    private var apps: [AppRef] {
        let all = extra + catalog.apps.filter { app in !extra.contains { $0.bundleID == app.bundleID } }
        let available = all.filter { !excluded.contains($0.bundleID) }
        guard !query.isEmpty else { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.title3.weight(.semibold))
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search apps", text: $query).textFieldStyle(.plain)
                }
                .padding(8)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)

            Divider()

            if !catalog.isLoaded {
                ProgressView("Finding apps…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(apps) { app in
                    Button { toggle(app) } label: {
                        HStack(spacing: 10) {
                            AppIconView(app: app, size: 26)
                            Text(app.name)
                            Spacer()
                            Image(systemName: selected[app.bundleID] != nil ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected[app.bundleID] != nil ? Color.accentColor : Color.secondary.opacity(0.5))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Button("Choose Other App…") {
                    if let app = AppCatalog.chooseAppWithOpenPanel(), !excluded.contains(app.bundleID) {
                        if !extra.contains(app) { extra.insert(app, at: 0) }
                        selected[app.bundleID] = app
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(selected.count > 1 ? "Add \(selected.count) Apps" : "Add") {
                    onAdd(selected.values.sorted { $0.name < $1.name })
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 440, height: 540)
        .onAppear { catalog.loadIfNeeded() }
    }

    private func toggle(_ app: AppRef) {
        if selected[app.bundleID] != nil { selected[app.bundleID] = nil } else { selected[app.bundleID] = app }
    }
}

/// A list of apps with remove buttons and an "Add" row, used for allow/block lists.
struct AppListEditor: View {
    @Binding var apps: [AppRef]
    let addTitle: String
    var locked = false
    @State private var showingPicker = false

    var body: some View {
        ForEach(apps) { app in
            HStack(spacing: 10) {
                AppIconView(app: app, size: 24)
                Text(app.name)
                Spacer()
                Button {
                    withAnimation { apps.removeAll { $0.bundleID == app.bundleID } }
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .help("Remove")
            }
        }
        Button {
            showingPicker = true
        } label: {
            Label(addTitle, systemImage: "plus.circle.fill")
        }
        .buttonStyle(.borderless)
        .disabled(locked)
        .sheet(isPresented: $showingPicker) {
            AppPickerSheet(title: addTitle, excluded: Set(apps.map(\.bundleID))) { added in
                withAnimation { apps.append(contentsOf: added) }
            }
        }
    }
}
