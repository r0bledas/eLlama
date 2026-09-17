import SwiftUI
import AppKit

@main
struct eLlamaApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 850, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About eLlama") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "eLlama",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "v\(UpdateManager.currentELlamaVersion)",
                            NSApplication.AboutPanelOptionKey.version: "1.2.0"
                        ]
                    )
                }
            }
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra("eLlama", systemImage: "cube.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
