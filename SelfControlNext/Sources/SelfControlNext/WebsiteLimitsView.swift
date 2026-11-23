import SwiftUI

struct WebsiteLimitsView: View {
    @Environment(Store.self) private var store
    let select: (SidebarItem) -> Void

    var body: some View {
        @Bindable var store = store
        let limit = store.config.websites.limitSeconds
        Form {
            Section {
                HStack(spacing: 14) {
                    SymbolBadge(symbol: "globe", tint: .teal, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Website Limits").font(.title3.weight(.semibold))
                        Text("SelfControl keeps track of the sites you use. Any site that goes over its daily limit asks whether it's a good time, then gets blocked in every browser until midnight.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("Website limits", isOn: $store.config.websites.enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.vertical, 4)

                LabeledContent("Limit for each website") {
                    DurationPicker(minutes: $store.config.websites.minutesPerSite)
                }
                .disabled(!store.config.websites.enabled)

                StrictModeRow()
                HelperRequiredRow(reason: "Without the helper, SelfControl can only close a blocked site's tab. Install the helper to block sites in every browser and app.")
            }

            browserSection

            Section {
                let sites = store.topSites()
                if sites.isEmpty {
                    Text("No websites tracked yet today.").foregroundStyle(.secondary)
                }
                ForEach(sites, id: \.domain) { site in
                    SiteRow(domain: site.domain, seconds: site.seconds, limit: limit,
                            blockedUntil: store.helper.status?.websiteBlocks[site.domain],
                            whitelisted: store.config.websites.isWhitelisted(host: site.domain))
                }
            } header: {
                Text("Today")
            } footer: {
                Text("Time counts while a site is the active tab of the browser in front, even if you're just watching. Whitelisted sites aren't counted.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var browserSection: some View {
        let browser = store.browser
        if !browser.deniedBrowsers.isEmpty || !browser.unsupportedInUse.isEmpty || browser.workingBrowsers.isEmpty {
            Section("Browsers") {
                ForEach(Array(browser.deniedBrowsers).sorted(), id: \.self) { id in
                    HStack {
                        Label("SelfControl isn't allowed to read \(BrowserTracker.supported[id]?.name ?? id)'s tabs.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open Settings…") { BrowserTracker.openAutomationSettings() }
                    }
                }
                ForEach(Array(browser.unsupportedInUse).sorted(), id: \.self) { id in
                    Label("\(BrowserTracker.unsupported[id] ?? id) doesn't let other apps read its tabs, so time there isn't tracked.",
                          systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                if browser.workingBrowsers.isEmpty && browser.deniedBrowsers.isEmpty {
                    Label("Works with Safari, Chrome, Edge, Brave, Arc, Vivaldi and Opera. The first time you use one, macOS asks whether SelfControl may read its tabs. Choose Allow.",
                          systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SiteRow: View {
    @Environment(Store.self) private var store
    let domain: String
    let seconds: TimeInterval
    let limit: TimeInterval?
    let blockedUntil: Date?
    let whitelisted: Bool

    var body: some View {
        HStack(spacing: 12) {
            TargetIcon(target: .website(domain), size: 28)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(domain).font(.body.weight(.medium))
                    if blockedUntil != nil {
                        Text("Blocked").font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(.red.opacity(0.2)))
                            .foregroundStyle(.red)
                    } else if whitelisted {
                        Text("Whitelisted").font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(.green.opacity(0.2)))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text(limit.map { "\(formatDuration(seconds)) of \(formatDuration($0))" } ?? formatDuration(seconds))
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
                if !whitelisted { UsageBar(used: seconds, limit: limit) }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Add to Whitelist") {
                if !store.config.websites.whitelist.contains(domain) { store.config.websites.whitelist.append(domain) }
            }
            .disabled(whitelisted)
        }
    }
}

struct WebsiteWhitelistView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                HStack(spacing: 14) {
                    SymbolBadge(symbol: "checkmark.shield.fill", tint: .green, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Website Whitelist").font(.title3.weight(.semibold))
                        Text("Sites here never count toward website limits and are never blocked by them. Subdomains are included: whitelisting github.com also covers gist.github.com.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                StrictModeRow()
            }

            Section {
                if store.config.websites.whitelist.isEmpty {
                    Text("No whitelisted sites yet.").foregroundStyle(.secondary)
                }
                WebsiteListEditor(websites: $store.config.websites.whitelist)
            } header: {
                Text("Always allowed")
            } footer: {
                Text("The whitelist only affects website limits. Focus Sessions and Downtime can still block these sites.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
