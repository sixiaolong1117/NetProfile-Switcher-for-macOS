//
//  NetworkSelectorForMacOSApp.swift
//  NetworkSelectorForMacOS
//
//  Created by 司晓龙 on 2026/5/13.
//

import SwiftUI

@main
struct NetworkSelectorForMacOSApp: App {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Window(appText("about.title", languageSetting: appLanguage), id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
        .commands {
            AppCommands()
        }
    }
}

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(appText("about.title", languageSetting: appLanguage)) {
                openWindow(id: "about")
            }
        }
    }
}
