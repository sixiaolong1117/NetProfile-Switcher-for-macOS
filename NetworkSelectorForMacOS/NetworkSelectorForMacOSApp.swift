//
//  NetworkSelectorForMacOSApp.swift
//  NetworkSelectorForMacOS
//  应用入口
//

import SwiftUI

// 应用入口
@main
struct NetworkSelectorForMacOSApp: App {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    var body: some Scene {
        // 主窗口
        WindowGroup {
            ContentView()
        }
        .commands {
            AppCommands()
        }

        // 关于窗口 独立的窗口
        Window(appText("about.title", languageSetting: appLanguage), id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)   // 根据内容自动调整窗口大小

        // 设置窗口 系统提供的固定入口
        Settings {
            SettingsView()
        }
    }
}

// 自定义菜单命令
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
