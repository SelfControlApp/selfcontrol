import Foundation

// A store that persists [BlockedURL] in UserDefaults using JSON encoding.
@MainActor
final class BlockedURLStore: ObservableObject {
    @Published private(set) var items: [BlockedURL] = []
    
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // If you need an app group, pass: UserDefaults(suiteName: "group.your.identifier")!
    init(
        key: String = "BlockedURLItems",
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaults = defaults
        load()
    }
    
    func load() {
        guard let data = defaults.data(forKey: key) else {
            items = []
            return
        }
        do {
            items = try decoder.decode([BlockedURL].self, from: data)
        } catch {
            #if DEBUG
            print("Failed to decode [BlockedURL]: \(error)")
            #endif
            items = []
        }
    }
    
    func save() {
        do {
            let data = try encoder.encode(items)
            defaults.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("Failed to encode [BlockedURL]: \(error)")
            #endif
        }
    }
    
    // Replace entire array
    func set(_ newItems: [BlockedURL]) {
        items = newItems
        save()
    }
    
    // Append a new entry
    func append(_ item: BlockedURL) {
        items.append(item)
        save()
    }
    
    // Insert or update by id
    func upsert(_ item: BlockedURL) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        save()
    }
    
    // Remove by id
    func remove(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: idx)
            save()
        }
    }
    
    // Remove via IndexSet (useful for List.onDelete)
    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }
    
    // Toggle enable/disable for a specific id
    func setEnabled(_ isEnabled: Bool, for id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isEnabled = isEnabled
        save()
    }
    
    // Convenience: check if a given URL string matches any enabled blocked entry.
    // This compares against the computed urls strings of enabled items.
    func isBlocked(urlString: String) -> Bool {
        let normalized = Self.normalize(urlString: urlString)
        for item in items where item.isEnabled {
            guard let itemURLs = item.urls else { continue }
            if itemURLs.contains(where: { Self.normalize(urlString: $0) == normalized }) {
                return true
            }
        }
        return false
    }
    
    // Optional normalization helper for consistent comparisons.
    private static func normalize(urlString: String) -> String {
        // If it's a full URL, normalize via URLComponents; otherwise, lowercased trim.
        if let url = URL(string: urlString),
           var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {

            // Clear fragment and query
            comps.fragment = nil
            comps.query = nil

            // Remove trailing slash from path unless it's just "/"
            var path = comps.path
            if path.count > 1, path.hasSuffix("/") {
                path.removeLast()
                comps.path = path
            }

            // Default scheme if missing
            if comps.scheme == nil {
                comps.scheme = "http"
            }

            // Continue with your logic using `comps`...
        }
        return urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
