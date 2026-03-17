import SwiftUI

struct MainView: View {
    @ObservedObject var appController: AppController

    @AppStorage("BlockDuration") private var blockDuration = 60
    @AppStorage("MaxBlockLength") private var maxBlockLength = 1440
    @AppStorage("BlockAsWhitelist") private var blockAsWhitelist = false

    @State private var showingBlocklist = false
    @State private var showingSchedules = false
    @State private var blocklist: [String] = []

    var body: some View {
        if appController.blockIsOn {
            TimerView(appController: appController)
        } else {
            setupView
        }
    }

    private var setupView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 2) {
                Text(formattedDuration)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("block duration")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }

            Spacer().frame(height: 24)

            Slider(value: durationBinding, in: 1...Double(max(maxBlockLength, 1)), step: 1)
                .frame(maxWidth: 280)

            Spacer().frame(height: 32)

            HStack(spacing: 16) {
                Picker("", selection: $blockAsWhitelist) {
                    Text("Block").tag(false)
                    Text("Allow").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Text("\(blocklist.count) sites")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer().frame(height: 24)

            HStack(spacing: 10) {
                Button(action: { showingBlocklist = true }) {
                    Label("Sites", systemImage: "list.bullet")
                        .font(.system(size: 12))
                }

                Button(action: { showingSchedules = true }) {
                    Label("Schedules", systemImage: "clock")
                        .font(.system(size: 12))
                }
            }

            Spacer().frame(height: 20)

            Button(action: { appController.startBlock() }) {
                Text("Start Block")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: 200)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled((blocklist.isEmpty && !blockAsWhitelist) || appController.addingBlock)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadBlocklist() }
        .sheet(isPresented: $showingBlocklist) {
            BlocklistEditorView(blocklist: $blocklist, isAllowlist: blockAsWhitelist) {
                saveBlocklist()
            }
        }
        .sheet(isPresented: $showingSchedules) {
            ScheduleEditorView()
        }
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

    private func loadBlocklist() {
        blocklist = UserDefaults.standard.stringArray(forKey: "Blocklist") ?? []
    }

    private func saveBlocklist() {
        UserDefaults.standard.set(blocklist, forKey: "Blocklist")
    }
}
