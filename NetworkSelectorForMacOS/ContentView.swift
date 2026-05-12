//
//  ContentView.swift
//  NetworkSelectorForMacOS
//
//  Created by 司晓龙 on 2026/5/13.
//

import SwiftUI

struct NetworkProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServers: String

    static func blank(named name: String) -> NetworkProfile {
        NetworkProfile(
            name: name,
            ipAddress: "",
            subnetMask: "255.255.0.0",
            router: "",
            dnsServers: ""
        )
    }
}

struct NetworkService: Identifiable, Equatable {
    let name: String
    let isDisabled: Bool

    var id: String {
        name
    }

    var displayName: String {
        isDisabled ? "\(name) (Disabled)" : name
    }
}

struct ContentView: View {
    @AppStorage("networkServiceName") private var serviceName = "Wi-Fi"
    @AppStorage("networkProfiles") private var storedProfiles = "[]"
    @AppStorage("showDisabledNetworkServices") private var showDisabledNetworkServices = true
    @AppStorage("refreshNetworkServicesOnLaunch") private var refreshNetworkServicesOnLaunch = true
    @AppStorage("defaultSubnetMask") private var defaultSubnetMask = "255.255.0.0"
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    @State private var networkServices: [NetworkService] = []
    @State private var profiles: [NetworkProfile] = []
    @State private var selectedProfileID: NetworkProfile.ID?
    @State private var draftProfile = NetworkProfile.blank(named: "")
    @State private var editingProfileID: NetworkProfile.ID?
    @State private var isEditorPresented = false
    @State private var isLoadingServices = false
    @State private var statusMessage = ""
    @State private var isSwitching = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .backgroundExtensionEffect()

            VStack(spacing: 12) {
                header

                HStack(spacing: 12) {
                    profileList
                        .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

                    profileDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .padding(12)
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            loadProfiles()
            if refreshNetworkServicesOnLaunch {
                loadNetworkServices()
            }
        }
        .onChange(of: showDisabledNetworkServices) {
            if !visibleNetworkServices.contains(where: { $0.name == serviceName }) {
                serviceName = visibleNetworkServices.first?.name ?? serviceName
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            NetworkProfileEditor(
                title: editingProfileID == nil
                    ? text("configuration.new")
                    : text("configuration.edit"),
                profile: $draftProfile,
                languageSetting: appLanguage,
                onCancel: {
                    isEditorPresented = false
                },
                onSave: {
                    saveDraftProfile()
                }
            )
        }
    }

    var header: some View {
        HStack {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(text("title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(text("subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(text("network.label"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(text("network.label"), selection: $serviceName) {
                if visibleNetworkServices.isEmpty {
                    Text(serviceName.isEmpty ? text("network.noServices") : serviceName)
                        .tag(serviceName)
                } else {
                    ForEach(visibleNetworkServices) { service in
                        Text(service.displayName)
                            .tag(service.name)
                    }
                }
            }
            .labelsHidden()
            .frame(minWidth: 150, idealWidth: 180)
            .disabled(isLoadingServices || visibleNetworkServices.isEmpty)

            Button {
                loadNetworkServices()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .disabled(isLoadingServices)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 20)
    }

    var profileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(text("configuration.title"))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    addProfile()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if profiles.isEmpty {
                emptyList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contextMenu {
                        Button(text("configuration.add")) {
                            addProfile()
                        }
                    }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(profiles) { profile in
                            profileRow(profile)
                                .contextMenu {
                                    Button(text("configuration.edit")) {
                                        editProfile(profile)
                                    }

                                    Button(text("configuration.duplicate")) {
                                        duplicateProfile(profile)
                                    }

                                    Divider()

                                    Button(text("configuration.delete"), role: .destructive) {
                                        deleteProfile(profile)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .contextMenu {
                    Button(text("configuration.add")) {
                        addProfile()
                    }
                }
            }
        }
        .glassPanel(cornerRadius: 20)
    }

    var emptyList: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text(text("configuration.empty"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    func profileRow(_ profile: NetworkProfile) -> some View {
        Button {
            selectedProfileID = profile.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(profile.id == selectedProfileID ? .white : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name.isEmpty ? text("configuration.untitled") : profile.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(profile.ipAddress.isEmpty ? text("configuration.noIP") : profile.ipAddress)
                        .font(.caption)
                        .foregroundStyle(profile.id == selectedProfileID ? .white.opacity(0.75) : .secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .background {
                if profile.id == selectedProfileID {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.tint)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.clear)
                }
            }
        }
        .buttonStyle(.plain)
    }

    var profileDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedProfile {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedProfile.name.isEmpty ? text("configuration.untitled") : selectedProfile.name)
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(text("configuration.static"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack {
                        Button {
                            applySelectedProfile()
                        } label: {
                            Label(text("action.apply"), systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.return)
                        .disabled(isSwitching)

                        Button {
                            editProfile(selectedProfile)
                        } label: {
                            Label(text("action.edit"), systemImage: "pencil")
                        }
                        .buttonStyle(.glass)
                        .disabled(isSwitching)
                    }
                }

                LazyVGrid(columns: detailColumns, spacing: 12) {
                    detailTile(text("editor.ip"), selectedProfile.ipAddress, "number")
                    detailTile(text("editor.subnet"), selectedProfile.subnetMask, "rectangle.3.group")
                    detailTile(text("editor.router"), selectedProfile.router, "point.3.connected.trianglepath.dotted")
                    detailTile(text("editor.dns"), selectedProfile.dnsServers, "server.rack")
                }

                Spacer()
            } else {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)

                    Text(text("configuration.noneSelected"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 22)
    }

    var detailColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)
        ]
    }

    func detailTile(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value.isEmpty ? "-" : value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(minHeight: 78, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    var footer: some View {
        HStack(spacing: 12) {
            Button {
                switchToDHCP()
            } label: {
                Label(text("action.dhcp"), systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.glass)
            .disabled(isSwitching)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 18)
    }

    var selectedProfile: NetworkProfile? {
        guard let selectedProfileID else {
            return nil
        }

        return profiles.first { $0.id == selectedProfileID }
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }

    var visibleNetworkServices: [NetworkService] {
        showDisabledNetworkServices
            ? networkServices
            : networkServices.filter { !$0.isDisabled }
    }

    func addProfile() {
        draftProfile = NetworkProfile.blank(named: nextProfileName())
        draftProfile.subnetMask = defaultSubnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
        editingProfileID = nil
        isEditorPresented = true
    }

    func editProfile(_ profile: NetworkProfile) {
        draftProfile = profile
        editingProfileID = profile.id
        isEditorPresented = true
    }

    func saveDraftProfile() {
        let normalizedProfile = NetworkProfile(
            id: draftProfile.id,
            name: draftProfile.name.trimmingCharacters(in: .whitespacesAndNewlines),
            ipAddress: draftProfile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            subnetMask: draftProfile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines),
            router: draftProfile.router.trimmingCharacters(in: .whitespacesAndNewlines),
            dnsServers: draftProfile.dnsServers.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let editingProfileID,
           let index = profiles.firstIndex(where: { $0.id == editingProfileID }) {
            profiles[index] = normalizedProfile
        } else {
            profiles.append(normalizedProfile)
        }

        selectedProfileID = normalizedProfile.id
        saveProfiles()
        isEditorPresented = false
    }

    func duplicateProfile(_ profile: NetworkProfile) {
        var copy = profile
        copy.id = UUID()
        copy.name = profile.name.isEmpty
            ? text("configuration.copyUntitled")
            : appText("configuration.copyName", languageSetting: appLanguage, profile.name)
        profiles.append(copy)
        selectedProfileID = copy.id
        saveProfiles()
    }

    func deleteProfile(_ profile: NetworkProfile) {
        profiles.removeAll { $0.id == profile.id }

        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }

        saveProfiles()
    }

    func switchToDHCP() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !service.isEmpty else {
            statusMessage = text("status.networkRequired")
            return
        }

        isSwitching = true
        statusMessage = appText("status.dhcpSwitching", languageSetting: appLanguage, service)

        let quotedService = shellQuoted(service)
        let command = """
        /usr/sbin/networksetup -setdhcp \(quotedService) && /usr/sbin/networksetup -setdnsservers \(quotedService) Empty
        """

        runAuthorized(command: command) { result in
            isSwitching = false
            statusMessage = result.success
                ? appText("status.dhcpComplete", languageSetting: appLanguage, service)
                : appText("status.applyFailed", languageSetting: appLanguage, result.message)
        }
    }

    func applySelectedProfile() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let profile = selectedProfile else {
            statusMessage = text("status.profileRequired")
            return
        }

        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ipAddress = profile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let subnetMask = profile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
        let router = profile.router.trimmingCharacters(in: .whitespacesAndNewlines)
        let dnsServers = profile.dnsServers
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map(String.init)

        guard !service.isEmpty else {
            statusMessage = text("status.networkRequired")
            return
        }

        guard !ipAddress.isEmpty, !subnetMask.isEmpty, !router.isEmpty else {
            statusMessage = text("status.staticFieldsRequired")
            return
        }

        isSwitching = true
        let displayName = name.isEmpty ? text("status.defaultConfiguration") : name
        statusMessage = appText("status.applying", languageSetting: appLanguage, displayName)

        let quotedService = shellQuoted(service)
        let dnsArguments = dnsServers.isEmpty
            ? "Empty"
            : dnsServers.map(shellQuoted).joined(separator: " ")
        let command = """
        /usr/sbin/networksetup -setmanual \(quotedService) \(shellQuoted(ipAddress)) \(shellQuoted(subnetMask)) \(shellQuoted(router)) && /usr/sbin/networksetup -setdnsservers \(quotedService) \(dnsArguments)
        """

        runAuthorized(command: command) { result in
            isSwitching = false
            statusMessage = result.success
                ? appText("status.applied", languageSetting: appLanguage, displayName)
                : appText("status.applyFailed", languageSetting: appLanguage, result.message)
        }
    }

    func loadProfiles() {
        guard let data = storedProfiles.data(using: .utf8),
              let decodedProfiles = try? JSONDecoder().decode([NetworkProfile].self, from: data) else {
            profiles = []
            selectedProfileID = nil
            return
        }

        profiles = decodedProfiles
        selectedProfileID = profiles.first?.id
    }

    func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles),
              let encodedProfiles = String(data: data, encoding: .utf8) else {
            return
        }

        storedProfiles = encodedProfiles
    }

    func loadNetworkServices() {
        isLoadingServices = true

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            process.arguments = ["-listallnetworkservices"]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let output = readText(from: outputPipe)
                let error = readText(from: errorPipe)
                let services = parseNetworkServices(output)

                DispatchQueue.main.async {
                    networkServices = services
                    isLoadingServices = false

                    if !visibleNetworkServices.contains(where: { $0.name == serviceName }) {
                        serviceName = visibleNetworkServices.first?.name ?? serviceName
                    }

                    if process.terminationStatus != 0 {
                        statusMessage = error.isEmpty ? text("status.loadServicesFailed") : error
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadingServices = false
                    statusMessage = appText("status.loadServicesFailedDetail", languageSetting: appLanguage, error.localizedDescription)
                }
            }
        }
    }

    func parseNetworkServices(_ output: String) -> [NetworkService] {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty && !line.hasPrefix("An asterisk")
            }
            .map { line in
                let isDisabled = line.hasPrefix("*")
                let name = isDisabled
                    ? String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                    : line

                return NetworkService(name: name, isDisabled: isDisabled)
            }
            .filter { !$0.name.isEmpty }
    }

    func runAuthorized(command: String, completion: @escaping ((success: Bool, message: String)) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            on run argv
                do shell script (item 1 of argv) with administrator privileges
            end run
            """

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script, command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let output = readText(from: outputPipe)
                let error = readText(from: errorPipe)
                let message = error.isEmpty ? output : error

                DispatchQueue.main.async {
                    completion((
                        success: process.terminationStatus == 0,
                        message: message.isEmpty
                            ? appText("status.commandExited", languageSetting: appLanguage, process.terminationStatus)
                            : message
                    ))
                }
            } catch {
                DispatchQueue.main.async {
                    completion((success: false, message: error.localizedDescription))
                }
            }
        }
    }

    func readText(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    func nextProfileName() -> String {
        appText("configuration.nextName", languageSetting: appLanguage, profiles.count + 1)
    }
}

struct NetworkProfileEditor: View {
    let title: String
    @Binding var profile: NetworkProfile
    let languageSetting: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(20)

            Divider()

            Form {
                TextField(text("editor.name"), text: $profile.name)
                TextField(text("editor.ip"), text: $profile.ipAddress)
                TextField(text("editor.subnet"), text: $profile.subnetMask)
                TextField(text("editor.router"), text: $profile.router)
                TextField(text("editor.dns"), text: $profile.dnsServers)
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HStack {
                Spacer()

                Button(text("action.cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(text("action.save")) {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460)
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: languageSetting)
    }
}

private extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    ContentView()
}
