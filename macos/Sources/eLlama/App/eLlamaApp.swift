import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disable macOS automatic window tabbing before any window is created.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        for window in NSApp.windows {
            window.tabbingMode = .disallowed
        }

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = image
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        OpenFileHandler.shared.handle(urls: urls)
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
        // A single, fixed window. Using `Window` (not `WindowGroup`) removes the
        // "New Window" command / Cmd+N so no extra windows or tabs can be opened.
        Window("eLlama", id: "main") {
            ContentView()
                .frame(minWidth: 740, minHeight: 480)
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

            // Remove File > New Window (Cmd+N) entirely.
            CommandGroup(replacing: .newItem) {}
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
