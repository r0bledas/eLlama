import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var models: [ModelInfo] = []
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("eLlama")
                    .font(.headline)
                Spacer()
                Text("v\(UpdateManager.currentELlamaVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            Button("Open eLlama") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if !models.isEmpty {
                Divider()

                Text("Quick Launch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)

                ForEach(models.prefix(5)) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.modelName)
                                .font(.caption)
                                .lineLimit(1)
                            Text("\(model.quant) - \(model.formattedSize)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Run") {
                            try? TerminalLauncher.shared.launch(model: model, settings: settings)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)

                        Button("Serve") {
                            try? TerminalLauncher.shared.launchServer(model: model, settings: settings)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }
            }

            Divider()

            Button("Quit eLlama") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
        .onAppear {
            loadModels()
        }
    }

    private func loadModels() {
        Task {
            let scanned = await ModelScanner.shared.scan(directory: settings.resolvedModelsDirectory)
            await MainActor.run {
                self.models = scanned.filter { !$0.isProjector }
            }
        }
    }
}
