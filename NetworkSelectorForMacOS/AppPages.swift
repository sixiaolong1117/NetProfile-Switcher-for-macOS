//
//  AppPages.swift
//  NetworkSelectorForMacOS
//
//  Created by 司晓龙 on 2026/5/13.
//

import SwiftUI

struct AboutView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    private let authorAvatarURL = URL(string: "https://avatars.githubusercontent.com/u/59590732")
    private let repositoryURL = URL(string: "https://github.com/sixiaolong1117/NetworkSelectorForMacOS")!
    private let licenseURL = URL(string: "https://github.com/sixiaolong1117/NetworkSelectorForMacOS/blob/main/LICENSE")!

    var body: some View {
        VStack(spacing: 18) {
            authorAvatar

            VStack(spacing: 6) {
                Text(text("title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(appText("about.version", languageSetting: appLanguage, appVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(text("about.author"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("司晓龙")
                    .font(.headline)

                socialLinks
                    .padding(.top, 4)
            }

            Text(text("about.description"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            projectLinks
        }
        .padding(28)
        .frame(width: 360)
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var authorAvatar: some View {
        AsyncImage(url: authorAvatarURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .controlSize(.small)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(8)
            @unknown default:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    var socialLinks: some View {
        HStack(spacing: 10) {
            Link(destination: URL(string: "https://github.com/sixiaolong1117")!) {
                Text("GitHub")
                    .font(.caption)
                    .foregroundStyle(.link)
            }
            .buttonStyle(.plain)
            .help("GitHub")
            .accessibilityLabel("GitHub")
        }
    }

    var projectLinks: some View {
        HStack(spacing: 12) {
            Link(text("about.repository"), destination: repositoryURL)
            Link(text("about.license"), destination: licenseURL)
        }
        .font(.caption)
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("showDisabledNetworkServices") private var showDisabledNetworkServices = true
    @AppStorage("refreshNetworkServicesOnLaunch") private var refreshNetworkServicesOnLaunch = true
    @AppStorage("defaultSubnetMask") private var defaultSubnetMask = "255.255.255.0"

    var body: some View {
        Form {
            Section(text("settings.languageSection")) {
                Picker(text("settings.language"), selection: $appLanguage) {
                    Text(text("language.system")).tag(AppLanguage.system.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese.rawValue)
                }
            }

            Section(text("settings.networkServices")) {
                Toggle(text("settings.showDisabled"), isOn: $showDisabledNetworkServices)
                Toggle(text("settings.refreshOnLaunch"), isOn: $refreshNetworkServicesOnLaunch)
            }

            Section(text("settings.newConfigurations")) {
                TextField(text("settings.defaultSubnet"), text: $defaultSubnetMask)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 440)
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }
}
