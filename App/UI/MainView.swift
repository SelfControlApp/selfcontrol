import SwiftUI

struct MainView: View {
    @AppStorage("BlockDuration") private var blockDuration = 60
    @AppStorage("MaxBlockLength") private var maxBlockLength = 1440
    @AppStorage("BlockAsWhitelist") private var blockAsWhitelist = false
    @AppStorage("Blocklist") private var blocklistData = Data()

    private var blocklist: [String] {
        (try? JSONDecoder().decode([String].self, from: blocklistData)) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stone")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDuration)
                    .font(.headline)
                Slider(value: durationBinding, in: 1...Double(maxBlockLength), step: 1)
            }

            Picker("Mode", selection: $blockAsWhitelist) {
                Text("Blocklist").tag(false)
                Text("Allowlist").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Text("\(blocklist.count) entries in \(blockAsWhitelist ? "allowlist" : "blocklist")")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Start Block") {
                    // TODO: Wire to AppController.startBlock()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(blocklist.isEmpty && !blockAsWhitelist)

                Button("Edit \(blockAsWhitelist ? "Allowlist" : "Blocklist")...") {
                    // TODO: Open domain list
                }

                Button("Schedules...") {
                    // TODO: Open schedules
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { Double(blockDuration) },
            set: { blockDuration = Int($0) }
        )
    }

    private var formattedDuration: String {
        let h = blockDuration / 60
        let m = blockDuration % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
