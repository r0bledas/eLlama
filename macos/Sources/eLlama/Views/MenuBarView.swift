import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var models: [ModelInfo] = []

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

            Divider()

            Button("Quit eLlama") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
    }
}
