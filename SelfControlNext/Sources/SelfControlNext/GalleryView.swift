import SwiftUI

// MARK: - Appearance helpers

enum ListStyle {
    static let colors: [(name: String, color: Color)] = [
        ("blue", .blue), ("purple", .purple), ("pink", .pink), ("red", .red), ("orange", .orange),
        ("yellow", .yellow), ("green", .green), ("teal", .teal), ("indigo", .indigo), ("gray", .gray),
    ]
    static let symbols = [
        "book.fill", "graduationcap.fill", "briefcase.fill", "brain.head.profile", "laptopcomputer",
        "pencil", "paintbrush.fill", "music.note", "leaf.fill", "moon.stars.fill", "figure.run", "sparkles",
    ]
    static func color(_ name: String) -> Color { colors.first { $0.name == name }?.color ?? .blue }
}

// MARK: - Templates

enum FocusListTemplates {
    private static let socialSites = ["instagram.com", "x.com", "twitter.com", "tiktok.com", "reddit.com", "facebook.com"]
    private static let discord = AppRef(bundleID: "com.hnc.Discord", name: "Discord", path: "/Applications/Discord.app")
    private static let messages = AppRef(bundleID: "com.apple.MobileSMS", name: "Messages", path: "/System/Applications/Messages.app")

    static let all: [FocusList] = [
        FocusList(name: "Study", symbol: "graduationcap.fill", color: "blue", mode: .exempt,
                  blockedApps: [discord, messages], blockedWebsites: socialSites,
                  allowedApps: [AppRef(bundleID: "com.apple.iBooksX", name: "Books", path: "/System/Applications/Books.app"),
                                AppRef(bundleID: "com.apple.Notes", name: "Notes", path: "/System/Applications/Notes.app"),
                                AppRef(bundleID: "com.apple.Preview", name: "Preview", path: "/System/Applications/Preview.app")],
                  allowedWebsites: ["khanacademy.org", "youtube.com", "wikipedia.org"]),
        FocusList(name: "Deep Work", symbol: "briefcase.fill", color: "indigo", mode: .exempt,
                  blockedApps: [discord, messages], blockedWebsites: socialSites + ["youtube.com", "netflix.com"]),
        FocusList(name: "Social Media Detox", symbol: "leaf.fill", color: "green", mode: .exempt,
                  blockedWebsites: socialSites + ["snapchat.com", "threads.net"]),
    ]
}

// MARK: - Gallery

struct GalleryView: View {
    @Environment(Store.self) private var store
    let select: (SidebarItem) -> Void
    @State private var editing: FocusList?
    @State private var creating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Lists").font(.title2.weight(.semibold))
                    Text("Saved sets of apps and websites to block or allow. Start one as a Focus Session whenever you need it.")
                        .foregroundStyle(.secondary)
                }

                if let focus = store.activeFocus {
                    Label("A Focus Session\(focus.listName.map { " (\($0))" } ?? "") is running until \(focus.end.formatted(date: .omitted, time: .shortened)).",
                          systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 16, alignment: .top)], spacing: 16) {
                    ForEach(store.config.focusLists) { list in
                        FocusListCard(list: list, edit: { editing = list }, select: select)
                    }
                    NewListCard(
                        create: { creating = true },
                        addTemplate: { template in
                            var copy = template
                            copy.id = UUID()
                            store.config.focusLists.append(copy)
                        }
                    )
                }
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem {
                Button { creating = true } label: { Label("New List", systemImage: "plus") }
                    .help("Create a Focus List")
            }
        }
        .sheet(item: $editing) { list in
            FocusListEditor(original: list)
        }
        .sheet(isPresented: $creating) {
            FocusListEditor(original: nil)
        }
    }
}

private struct FocusListCard: View {
    @Environment(Store.self) private var store
    let list: FocusList
    let edit: () -> Void
    let select: (SidebarItem) -> Void
    @State private var starting = false

    var body: some View {
        let tint = ListStyle.color(list.color)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SymbolBadge(symbol: list.symbol, tint: tint, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name).font(.headline)
                    Text(list.mode.shortTitle)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(tint.opacity(0.18)))
                        .foregroundStyle(tint)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                summaryRow(symbol: "nosign", tint: .red, label: "Blocks",
                           items: list.blockedApps.map(\.name) + list.blockedWebsites,
                           empty: list.mode == .allowlist ? "Everything not allowed" : "Nothing")
                summaryRow(symbol: "checkmark.circle", tint: .green, label: "Allows",
                           items: list.allowedApps.map(\.name) + list.allowedWebsites, empty: "Nothing")
            }

            HStack {
                Button("Edit", action: edit)
                Spacer()
                Button {
                    starting = true
                } label: {
                    Label("Start…", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .disabled(store.activeFocus != nil)
                .popover(isPresented: $starting, arrowEdge: .bottom) {
                    StartListPopover(list: list, done: { started in
                        starting = false
                        if started { select(.focus) }
                    })
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator.opacity(0.5)))
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: edit)
    }

    private func summaryRow(symbol: String, tint: Color, label: String, items: [String], empty: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 14)
            Text(label).foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
            Text(items.isEmpty ? empty : summary(items)).lineLimit(2)
        }
        .font(.callout)
    }

    private func summary(_ items: [String]) -> String {
        items.count <= 3 ? items.joined(separator: ", ")
            : items.prefix(3).joined(separator: ", ") + " +\(items.count - 3) more"
    }
}

private struct NewListCard: View {
    let create: () -> Void
    let addTemplate: (FocusList) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: create) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("New List").font(.headline)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu("Add from Templates") {
                ForEach(FocusListTemplates.all) { template in
                    Button(template.name) { addTemplate(template) }
                }
            }
            .fixedSize()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(.separator))
    }
}

private struct StartListPopover: View {
    @Environment(Store.self) private var store
    let list: FocusList
    let done: (Bool) -> Void
    @State private var minutes = 60
    @State private var confirming = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Start \(list.name)").font(.headline)
            Text(formatDuration(TimeInterval(minutes * 60)))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: minutes)
            Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }), in: 15...(24 * 60), step: 15)
            HStack {
                ForEach([25, 60, 120, 240], id: \.self) { m in
                    Button(formatDuration(TimeInterval(m * 60))) { minutes = m }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Button {
                confirming = true
            } label: {
                Label("Start Focus Session", systemImage: "lock.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ListStyle.color(list.color))
            .controlSize(.large)
        }
        .padding(18)
        .frame(width: 300)
        .onAppear { minutes = store.config.focusMinutes }
        .confirmationDialog("Start \(list.name) for \(formatDuration(TimeInterval(minutes * 60)))?", isPresented: $confirming) {
            Button("Start Session", role: .destructive) {
                Task {
                    do {
                        try await store.startFocus(minutes: minutes, list: list)
                        done(true)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmMessage: String {
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60)).formatted(date: .omitted, time: .shortened)
        switch list.mode {
        case .exempt:
            return "The list's blocked apps and websites will be blocked until \(until). You won't be able to end the session early."
        case .allowlist:
            return "Everything except the list's allowed apps and websites will be blocked until \(until), including network access for other apps. You won't be able to end the session early."
        }
    }
}

// MARK: - Editor

struct FocusListEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: FocusList?
    @State private var draft: FocusList
    @State private var confirmDelete = false

    init(original: FocusList?) {
        self.original = original
        _draft = State(initialValue: original ?? FocusList(name: ""))
    }

    var body: some View {
        let tint = ListStyle.color(draft.color)
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                SymbolBadge(symbol: draft.symbol, tint: tint, size: 52)
                TextField("List Name", text: $draft.name, prompt: Text("Name, e.g. Study"))
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
            }
            .padding(20)

            Form {
                Section("Appearance") {
                    HStack(spacing: 8) {
                        ForEach(ListStyle.colors, id: \.name) { option in
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.white, lineWidth: draft.color == option.name ? 2.5 : 0))
                                .onTapGesture { draft.color = option.name }
                                .help(option.name.capitalized)
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(ListStyle.symbols, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .frame(width: 28, height: 28)
                                .background(RoundedRectangle(cornerRadius: 7)
                                    .fill(draft.symbol == symbol ? tint.opacity(0.25) : .clear))
                                .foregroundStyle(draft.symbol == symbol ? tint : .secondary)
                                .onTapGesture { draft.symbol = symbol }
                        }
                    }
                }

                Section {
                    Picker("During a session", selection: $draft.mode) {
                        ForEach(FocusMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                } header: {
                    Text("Mode")
                } footer: {
                    Text(draft.mode == .exempt
                         ? "Blocked items are blocked. Allowed items stay usable even past their app or website limits. Everything else follows your usual rules."
                         : "Only allowed apps and websites work. Every other app is blocked, and network access is cut for everything except the allowed sites (and what they need to load).")
                        .foregroundStyle(.secondary)
                }

                Section {
                    AppListEditor(apps: $draft.blockedApps, addTitle: "Add App to Block…")
                    WebsiteListEditor(websites: $draft.blockedWebsites)
                } header: {
                    Label("Block", systemImage: "nosign")
                } footer: {
                    if draft.mode == .allowlist {
                        Text("Everything not allowed is already blocked. Items here stay blocked even if they're also allowed below.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    AppListEditor(apps: $draft.allowedApps, addTitle: "Add App to Allow…")
                    WebsiteListEditor(websites: $draft.allowedWebsites)
                } header: {
                    Label("Allow", systemImage: "checkmark.circle")
                } footer: {
                    if draft.mode == .allowlist {
                        Text("Apps that need the internet (e.g. Discord) also need their websites allowed here.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                if original != nil {
                    Button("Delete List", role: .destructive) { confirmDelete = true }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 600, height: 620)
        .confirmationDialog("Delete \(draft.name)?", isPresented: $confirmDelete) {
            Button("Delete List", role: .destructive) {
                store.config.focusLists.removeAll { $0.id == original?.id }
                dismiss()
            }
        }
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        if let i = store.config.focusLists.firstIndex(where: { $0.id == draft.id }) {
            store.config.focusLists[i] = draft
        } else {
            store.config.focusLists.append(draft)
        }
        dismiss()
    }
}
