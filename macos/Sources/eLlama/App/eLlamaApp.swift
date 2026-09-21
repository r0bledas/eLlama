import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = image
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }
}

@main
struct eLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                            NSApplication.AboutPanelOptionKey.version: "2.0.0"
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
