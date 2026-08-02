//
//  NetworkSelectorForMacOSApp.swift
//  NetworkSelectorForMacOS
//  应用入口
//

import AppKit
import SwiftUI

// 应用入口
@main
struct NetworkSelectorForMacOSApp: App {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    var body: some Scene {
        // 主窗口
        WindowGroup(id: "main") {
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

        // 菜单栏常驻入口
        MenuBarExtra {
            MenuBarMenuView()
        } label: {
            Label(appText("menu.title", languageSetting: appLanguage), systemImage: "network")
        }
        .menuBarExtraStyle(.menu)
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

// 菜单栏菜单：查看当前配置并一键切换配置 / DHCP
struct MenuBarMenuView: View {
    @AppStorage("networkServiceName") private var serviceName = "Wi-Fi"
    @AppStorage("networkProfiles") private var storedProfiles = "[]"
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @State private var profiles: [NetworkProfile] = []
    @State private var currentInfo = NetworkInfoResult.empty
    @State private var isSwitching = false

    var body: some View {
        Text("\(text("network.label")): \(serviceName.isEmpty ? text("network.noServices") : serviceName)")
            .disabled(true)
        Text("\(text("status.currentProfile")): \(currentProfileLabel)")
            .disabled(true)
        Text("\(text("status.currentIP")): \(displayValue(currentInfo.ipAddress))")
            .disabled(true)
        Text("\(text("status.currentSubnet")): \(displayValue(currentInfo.subnetMask))")
            .disabled(true)
        Text("\(text("status.currentRouter")): \(displayValue(currentInfo.router))")
            .disabled(true)
        Text("\(text("status.currentDNS")): \(displayValue(currentInfo.dnsServersString))")
            .disabled(true)

        Divider()

        if profiles.isEmpty {
            Text(text("configuration.empty"))
                .disabled(true)
        } else {
            ForEach(profiles) { profile in
                Button {
                    apply(profile: profile)
                } label: {
                    Text((profile.id == currentProfile?.id ? "✓ " : "") + (profile.name.isEmpty ? text("configuration.untitled") : profile.name))
                }
                .disabled(isSwitching)
            }
        }

        Button {
            switchToDHCP()
        } label: {
            Text(text("action.dhcp"))
        }
        .disabled(isSwitching)

        Divider()

        Button(text("status.refreshInfo")) {
            refresh()
        }
        .disabled(isSwitching)

        Button(text("menu.openMainWindow")) {
            openWindow(id: "main")
        }

        Button(text("menu.settings")) {
            openSettings()
        }

        Button(text("menu.quit")) {
            NSApplication.shared.terminate(nil)
        }
        .onAppear {
            profiles = NetworkAutomation.storedProfiles()
            refresh()
        }
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }

    func displayValue(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }

    var currentProfile: NetworkProfile? {
        NetworkAutomation.matchingProfile(for: currentInfo, profiles: profiles)
    }

    var currentProfileLabel: String {
        NetworkAutomation.currentProfileLabel(for: currentInfo, profiles: profiles, languageSetting: appLanguage)
    }

    func refresh() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.isEmpty else {
            currentInfo = NetworkInfoResult.empty
            return
        }
        currentInfo = NetworkAutomation.getCurrentNetworkInfo(serviceName: service)
    }

    func apply(profile: NetworkProfile) {
        guard !isSwitching else { return }
        isSwitching = true
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task.detached(priority: .userInitiated) {
            _ = await NetworkAutomation.apply(profile: profile, serviceName: service)
            let info = NetworkAutomation.getCurrentNetworkInfo(serviceName: service)
            await MainActor.run {
                isSwitching = false
                currentInfo = info
            }
        }
    }

    func switchToDHCP() {
        guard !isSwitching else { return }
        isSwitching = true
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task.detached(priority: .userInitiated) {
            _ = await NetworkAutomation.switchToDHCP(serviceName: service)
            let info = await NetworkAutomation.getCurrentNetworkInfoPolling(serviceName: service)
            await MainActor.run {
                isSwitching = false
                currentInfo = info
            }
        }
    }
}
