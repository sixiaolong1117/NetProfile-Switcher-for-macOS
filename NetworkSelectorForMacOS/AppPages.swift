//
//  AppPages.swift
//  NetworkSelectorForMacOS
//

import AppKit
import ServiceManagement
import SwiftUI

struct AboutView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    private let repositoryURL = URL(string: "https://github.com/sixiaolong1117/NetProfile-Switcher-for-macOS")!
    private let licenseURL = URL(string: "https://github.com/sixiaolong1117/NetProfile-Switcher-for-macOS/blob/main/LICENSE")!
    private let authorURL = URL(string: "https://github.com/sixiaolong1117")!

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 4) {
                Text(appText("title", languageSetting: appLanguage))
                    .font(.title2.weight(.semibold))

                Text(appText("about.version", languageSetting: appLanguage, appVersion))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section {
                    Text(appText("about.description", languageSetting: appLanguage))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    LabeledContent(appText("about.author", languageSetting: appLanguage)) {
                        Link(appText("about.authorName", languageSetting: appLanguage), destination: authorURL)
                    }
                }

                Section {
                    Link(appText("about.repository", languageSetting: appLanguage), destination: repositoryURL)
                    Link(appText("about.license", languageSetting: appLanguage), destination: licenseURL)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.top, 28)
        .frame(width: 420)
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("showDisabledNetworkServices") private var showDisabledNetworkServices = true
    @AppStorage("refreshNetworkServicesOnLaunch") private var refreshNetworkServicesOnLaunch = true
    @AppStorage("defaultSubnetMask") private var defaultSubnetMask = "255.255.0.0"

    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled
    @State private var launchAtLoginError = ""
    @State private var isSyncingLaunchAtLogin = false
    @State private var sudoersStatus = ""
    @State private var isSudoersBusy = false

    var body: some View {
        Form {
            Section(appText("settings.generalSection", languageSetting: appLanguage)) {
                Toggle(appText("settings.launchAtLogin", languageSetting: appLanguage), isOn: $launchAtLogin)
                if !launchAtLoginError.isEmpty {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if LaunchAtLoginManager.status == .requiresApproval {
                    Text(appText("settings.launchAtLoginRequiresApproval", languageSetting: appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(appText("settings.launchAtLoginHint", languageSetting: appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(appText("settings.languageSection", languageSetting: appLanguage)) {
                Picker(appText("settings.language", languageSetting: appLanguage), selection: $appLanguage) {
                    Text(appText("language.system", languageSetting: appLanguage)).tag(AppLanguage.system.rawValue)
                    Text(appText("language.english", languageSetting: appLanguage)).tag(AppLanguage.english.rawValue)
                    Text(appText("language.simplifiedChinese", languageSetting: appLanguage)).tag(AppLanguage.simplifiedChinese.rawValue)
                }
            }

            Section(appText("settings.networkServices", languageSetting: appLanguage)) {
                Toggle(appText("settings.showDisabled", languageSetting: appLanguage), isOn: $showDisabledNetworkServices)
                Toggle(appText("settings.refreshOnLaunch", languageSetting: appLanguage), isOn: $refreshNetworkServicesOnLaunch)
            }

            Section(appText("settings.newConfigurations", languageSetting: appLanguage)) {
                TextField(appText("settings.defaultSubnet", languageSetting: appLanguage), text: $defaultSubnetMask)
            }

            Section(appText("settings.sudoersSection", languageSetting: appLanguage)) {
                LabeledContent(appText("settings.sudoersStatus", languageSetting: appLanguage)) {
                    Text(sudoersStatus.isEmpty
                        ? (SudoersAccessManager.isInstalled ? appText("settings.sudoersInstalled", languageSetting: appLanguage) : appText("settings.sudoersNotInstalled", languageSetting: appLanguage))
                        : sudoersStatus)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                }

                Button(SudoersAccessManager.isInstalled ? appText("settings.sudoersRemove", languageSetting: appLanguage) : appText("settings.sudoersInstall", languageSetting: appLanguage)) {
                    installOrRemoveSudoers()
                }
                .buttonStyle(.glass)
                .disabled(isSudoersBusy)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            refreshLaunchAtLoginState()
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard !isSyncingLaunchAtLogin else { return }
            setLaunchAtLogin(enabled: newValue)
        }
    }

    func refreshLaunchAtLoginState() {
        isSyncingLaunchAtLogin = true
        defer { isSyncingLaunchAtLogin = false }
        if LaunchAtLoginManager.status == .requiresApproval {
            launchAtLogin = true
        } else {
            launchAtLogin = LaunchAtLoginManager.isEnabled
        }
        launchAtLoginError = ""
    }

    func setLaunchAtLogin(enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLoginError = ""
        } catch {
            launchAtLoginError = appText("settings.launchAtLoginFailed", languageSetting: appLanguage, error.localizedDescription)
        }
        // 同步真实状态，避免 onChange 递归
        isSyncingLaunchAtLogin = true
        defer { isSyncingLaunchAtLogin = false }
        if LaunchAtLoginManager.status == .requiresApproval {
            launchAtLogin = true
        } else {
            launchAtLogin = LaunchAtLoginManager.isEnabled
        }
    }

    func installOrRemoveSudoers() {
        let shouldInstall = !SudoersAccessManager.isInstalled
        isSudoersBusy = true
        sudoersStatus = shouldInstall ? appText("settings.sudoersInstalling", languageSetting: appLanguage) : appText("settings.sudoersRemoving", languageSetting: appLanguage)

        Task {
            let result = shouldInstall ? await SudoersAccessManager.install() : await SudoersAccessManager.remove()
            isSudoersBusy = false
            sudoersStatus = result.success ? "" : result.message
        }
    }
}
