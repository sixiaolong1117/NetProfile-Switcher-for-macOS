//
//  ContentView.swift
//  NetworkSelectorForMacOS
//

import AppKit
import SwiftUI

struct NetworkProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServers: String

    static func blank(named name: String) -> NetworkProfile {
        NetworkProfile(name: name, ipAddress: "", subnetMask: "255.255.0.0", router: "", dnsServers: "")
    }
}

struct NetworkService: Identifiable, Equatable {
    let name: String
    let isDisabled: Bool

    var id: String { name }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .visible
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
    @State private var currentNetworkInfo = NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: [])
    @State private var isLoadingInfo = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        } detail: {
            detail
        }
        .background {
            MainWindowAccessor()
                .frame(width: 0, height: 0)
        }
        .toolbar {
            ToolbarItemGroup {
                if let selectedProfile {
                    Button {
                        apply(profile: selectedProfile)
                    } label: {
                        Label(text("action.apply"), systemImage: "checkmark")
                    }
                    .keyboardShortcut(.return)
                    .disabled(isSwitching)

                    Button {
                        editProfile(selectedProfile)
                    } label: {
                        Label(text("action.edit"), systemImage: "pencil")
                    }
                    .disabled(isSwitching)
                }

                Button {
                    addProfile()
                } label: {
                    Label(text("configuration.add"), systemImage: "plus")
                }

                Button {
                    refreshCurrentNetworkInfo()
                } label: {
                    Label(text("status.refreshInfo"), systemImage: "arrow.clockwise")
                }
                .disabled(isLoadingInfo)
            }

            ToolbarItem {
                networkServicePicker
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear {
            loadProfiles()
            if refreshNetworkServicesOnLaunch {
                loadNetworkServices()
            }
            refreshCurrentNetworkInfo()
        }
        .onChange(of: serviceName) { _, _ in
            refreshCurrentNetworkInfo()
        }
        .onChange(of: showDisabledNetworkServices) {
            if !visibleNetworkServices.contains(where: { $0.name == serviceName }) {
                serviceName = visibleNetworkServices.first?.name ?? serviceName
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            NetworkProfileEditor(
                title: editingProfileID == nil ? text("configuration.new") : text("configuration.edit"),
                profile: $draftProfile,
                languageSetting: appLanguage,
                onCancel: { isEditorPresented = false },
                onSave: { saveDraftProfile() }
            )
        }
    }

    @ViewBuilder
    var sidebar: some View {
        if profiles.isEmpty {
            ContentUnavailableView(
                text("configuration.empty"),
                systemImage: "list.bullet.rectangle",
                description: Text(text("configuration.addHint"))
            )
            .navigationTitle(text("configuration.title"))
            .contextMenu {
                Button(text("configuration.add")) {
                    addProfile()
                }
            }
        } else {
            List(selection: $selectedProfileID) {
                ForEach(profiles) { profile in
                    profileRow(profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button(text("action.switchConfiguration")) {
                                apply(profile: profile)
                            }
                            .disabled(isSwitching)

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
            .listStyle(.sidebar)
            .navigationTitle(text("configuration.title"))
            .contextMenu {
                Button(text("configuration.add")) {
                    addProfile()
                }
            }
        }
    }

    func profileRow(_ profile: NetworkProfile) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? text("configuration.untitled") : profile.name)
                    .lineLimit(1)

                Text(profile.ipAddress.isEmpty ? text("configuration.noIP") : profile.ipAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: "network")
        }
        .contentShape(Rectangle())
        .disabled(isSwitching)
    }

    @ViewBuilder
    var detail: some View {
        if let selectedProfile {
            profileDetail(selectedProfile)
        } else {
            ContentUnavailableView(
                text("configuration.noneSelected"),
                systemImage: "network",
                description: Text(text("configuration.selectHint"))
            )
        }
    }

    var networkServicePicker: some View {
        Picker(selection: $serviceName) {
            if visibleNetworkServices.isEmpty {
                Text(serviceName.isEmpty ? text("network.noServices") : serviceName)
                    .tag(serviceName)
            } else {
                ForEach(visibleNetworkServices) { service in
                    Text(service.isDisabled
                        ? appText("network.disabledService", languageSetting: appLanguage, service.name)
                        : service.name)
                        .tag(service.name)
                }
            }
        } label: {
            Label(text("network.label"), systemImage: "network")
        }
        .frame(minWidth: 150, idealWidth: 180)
        .disabled(isLoadingServices || visibleNetworkServices.isEmpty)
    }

    func profileDetail(_ profile: NetworkProfile) -> some View {
        Form {
            Section(text("configuration.static")) {
                readOnlyRow(text("editor.ip"), value: profile.ipAddress)
                readOnlyRow(text("editor.subnet"), value: profile.subnetMask)
                readOnlyRow(text("editor.router"), value: profile.router)
                readOnlyRow(text("editor.dns"), value: profile.dnsServers)
            }

            Section(text("status.currentInfo")) {
                if isLoadingInfo {
                    LabeledContent(text("status.refreshInfo")) {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else if currentNetworkInfo.isEmpty {
                    Text(text("status.noInfo"))
                        .foregroundStyle(.secondary)
                } else {
                    readOnlyRow(text("status.currentIP"), value: currentNetworkInfo.ipAddress)
                    readOnlyRow(text("status.currentSubnet"), value: currentNetworkInfo.subnetMask)
                    readOnlyRow(text("status.currentRouter"), value: currentNetworkInfo.router)
                    readOnlyRow(text("status.currentDNS"), value: currentNetworkInfo.dnsServersString)
                }
            }

            Section {
                Button {
                    switchToDHCP()
                } label: {
                    Label(text("action.dhcp"), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.glass)
                .disabled(isSwitching)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile.name.isEmpty ? text("configuration.untitled") : profile.name)
    }

    func readOnlyRow(_ title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(verbatim: value.isEmpty ? "—" : value)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    var selectedProfile: NetworkProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first { $0.id == selectedProfileID }
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }

    var visibleNetworkServices: [NetworkService] {
        showDisabledNetworkServices ? networkServices : networkServices.filter { !$0.isDisabled }
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
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }

        profiles.remove(at: index)
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.indices.contains(index) ? profiles[index].id : profiles.last?.id
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

        Task { @MainActor in
            let result = await NetworkAutomation.switchToDHCP(serviceName: service)
            isSwitching = false
            statusMessage = result.success
                ? appText("status.dhcpComplete", languageSetting: appLanguage, service)
                : appText("status.applyFailed", languageSetting: appLanguage, result.message)
            if result.success {
                refreshCurrentNetworkInfoPolling()
            }
        }
    }

    func refreshCurrentNetworkInfoPolling() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.isEmpty else {
            refreshCurrentNetworkInfo()
            return
        }

        isLoadingInfo = true
        DispatchQueue.global(qos: .userInitiated).async {
            var info = NetworkAutomation.getCurrentNetworkInfo(serviceName: service)
            var attempts = 0
            while info.isEmpty && attempts < 10 {
                Thread.sleep(forTimeInterval: 0.5)
                info = NetworkAutomation.getCurrentNetworkInfo(serviceName: service)
                attempts += 1
            }

            DispatchQueue.main.async {
                currentNetworkInfo = info
                isLoadingInfo = false
            }
        }
    }

    func apply(profile: NetworkProfile) {
        guard !isSwitching else { return }

        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? text("status.defaultConfiguration") : name
        isSwitching = true
        statusMessage = appText("status.applying", languageSetting: appLanguage, displayName)

        Task { @MainActor in
            let result = await NetworkAutomation.apply(profile: profile, serviceName: serviceName)
            isSwitching = false
            statusMessage = result.success
                ? appText("status.applied", languageSetting: appLanguage, displayName)
                : appText("status.applyFailed", languageSetting: appLanguage, result.message)
            if result.success {
                refreshCurrentNetworkInfo()
            }
        }
    }

    func loadProfiles() {
        profiles = NetworkAutomation.storedProfiles()
        if !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = profiles.first?.id
        }
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

                let output = NetworkAutomation.readText(from: outputPipe)
                let error = NetworkAutomation.readText(from: errorPipe)
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
            .filter { !$0.isEmpty && !$0.hasPrefix("An asterisk") }
            .map { line in
                let isDisabled = line.hasPrefix("*")
                let name = isDisabled ? String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) : line
                return NetworkService(name: name, isDisabled: isDisabled)
            }
            .filter { !$0.name.isEmpty }
    }

    func nextProfileName() -> String {
        appText("configuration.nextName", languageSetting: appLanguage, profiles.count + 1)
    }

    func refreshCurrentNetworkInfo() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.isEmpty else {
            currentNetworkInfo = NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: [])
            return
        }

        isLoadingInfo = true
        DispatchQueue.global(qos: .userInitiated).async {
            let info = NetworkAutomation.getCurrentNetworkInfo(serviceName: service)
            DispatchQueue.main.async {
                currentNetworkInfo = info
                isLoadingInfo = false
            }
        }
    }
}

struct NetworkProfileEditor: View {
    let title: String
    @Binding var profile: NetworkProfile
    let languageSetting: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(text("configuration.static")) {
                    TextField(text("editor.name"), text: $profile.name)
                    TextField(text("editor.ip"), text: $profile.ipAddress)
                    TextField(text("editor.subnet"), text: $profile.subnetMask)
                    TextField(text("editor.router"), text: $profile.router)
                    TextField(text("editor.dns"), text: $profile.dnsServers)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(text("action.cancel")) {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(text("action.save")) {
                        onSave()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 460, height: 330)
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: languageSetting)
    }
}

#Preview {
    ContentView()
}
