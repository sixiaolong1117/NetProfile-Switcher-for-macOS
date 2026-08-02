//
//  AppPages.swift
//  NetworkSelectorForMacOS
//

import AppKit
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
                Text(text("title"))
                    .font(.title2.weight(.semibold))

                Text(appText("about.version", languageSetting: appLanguage, appVersion))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section {
                    Text(text("about.description"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    LabeledContent(text("about.author")) {
                        Link(text("about.authorName"), destination: authorURL)
                    }
                }

                Section {
                    Link(text("about.repository"), destination: repositoryURL)
                    Link(text("about.license"), destination: licenseURL)
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

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("showDisabledNetworkServices") private var showDisabledNetworkServices = true
    @AppStorage("refreshNetworkServicesOnLaunch") private var refreshNetworkServicesOnLaunch = true
    @AppStorage("defaultSubnetMask") private var defaultSubnetMask = "255.255.0.0"

    @State private var sudoersStatus = ""
    @State private var isSudoersBusy = false

    var body: some View {
        Form {
            Section(text("settings.languageSection")) {
                Picker(text("settings.language"), selection: $appLanguage) {
                    Text(text("language.system")).tag(AppLanguage.system.rawValue)
                    Text(text("language.english")).tag(AppLanguage.english.rawValue)
                    Text(text("language.simplifiedChinese")).tag(AppLanguage.simplifiedChinese.rawValue)
                }
            }

            Section(text("settings.networkServices")) {
                Toggle(text("settings.showDisabled"), isOn: $showDisabledNetworkServices)
                Toggle(text("settings.refreshOnLaunch"), isOn: $refreshNetworkServicesOnLaunch)
            }

            Section(text("settings.newConfigurations")) {
                TextField(text("settings.defaultSubnet"), text: $defaultSubnetMask)
            }

            Section(text("settings.sudoersSection")) {
                LabeledContent(text("settings.sudoersStatus")) {
                    Text(sudoersStatus.isEmpty
                        ? (SudoersAccessManager.isInstalled ? text("settings.sudoersInstalled") : text("settings.sudoersNotInstalled"))
                        : sudoersStatus)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                }

                Button(SudoersAccessManager.isInstalled ? text("settings.sudoersRemove") : text("settings.sudoersInstall")) {
                    installOrRemoveSudoers()
                }
                .buttonStyle(.glass)
                .disabled(isSudoersBusy)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    func installOrRemoveSudoers() {
        let shouldInstall = !SudoersAccessManager.isInstalled
        isSudoersBusy = true
        sudoersStatus = shouldInstall ? text("settings.sudoersInstalling") : text("settings.sudoersRemoving")

        Task {
            let result = shouldInstall ? await SudoersAccessManager.install() : await SudoersAccessManager.remove()
            isSudoersBusy = false
            sudoersStatus = result.success ? "" : result.message
        }
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }
}
