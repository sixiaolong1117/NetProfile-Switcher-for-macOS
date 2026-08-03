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
    @State private var currentNetworkInfo = NetworkInfoResult.empty
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
                        Label(appText("action.apply", languageSetting: appLanguage), systemImage: "checkmark")
                    }
                    .keyboardShortcut(.return)
                    .disabled(isSwitching)

                    Button {
                        editProfile(selectedProfile)
                    } label: {
                        Label(appText("action.edit", languageSetting: appLanguage), systemImage: "pencil")
                    }
                    .disabled(isSwitching)
                }

                Button {
                    addProfile()
                } label: {
                    Label(appText("configuration.add", languageSetting: appLanguage), systemImage: "plus")
                }

                Button {
                    refreshCurrentNetworkInfo()
                } label: {
                    Label(appText("status.refreshInfo", languageSetting: appLanguage), systemImage: "arrow.clockwise")
                }
                .disabled(isLoadingInfo)
            }

            ToolbarItem {
                networkServicePicker
            }
        }
        .frame(minWidth: 700, minHeight: 600)
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
                title: editingProfileID == nil ? appText("configuration.new", languageSetting: appLanguage) : appText("configuration.edit", languageSetting: appLanguage),
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
                appText("configuration.empty", languageSetting: appLanguage),
                systemImage: "list.bullet.rectangle",
                description: Text(appText("configuration.addHint", languageSetting: appLanguage))
            )
            .navigationTitle(appText("configuration.title", languageSetting: appLanguage))
            .contextMenu {
                Button(appText("configuration.add", languageSetting: appLanguage)) {
                    addProfile()
                }
            }
        } else {
            List(selection: $selectedProfileID) {
                ForEach(profiles) { profile in
                    profileRow(profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button(appText("action.switchConfiguration", languageSetting: appLanguage)) {
                                apply(profile: profile)
                            }
                            .disabled(isSwitching)

                            Button(appText("configuration.edit", languageSetting: appLanguage)) {
                                editProfile(profile)
                            }

                            Button(appText("configuration.duplicate", languageSetting: appLanguage)) {
                                duplicateProfile(profile)
                            }

                            Divider()

                            Button(appText("configuration.delete", languageSetting: appLanguage), role: .destructive) {
                                deleteProfile(profile)
                            }
                        }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(appText("configuration.title", languageSetting: appLanguage))
            .contextMenu {
                Button(appText("configuration.add", languageSetting: appLanguage)) {
                    addProfile()
                }
            }
        }
    }

    func profileRow(_ profile: NetworkProfile) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name.isEmpty ? appText("configuration.untitled", languageSetting: appLanguage) : profile.name)
                        .lineLimit(1)

                    Text(profile.ipAddress.isEmpty ? appText("configuration.noIP", languageSetting: appLanguage) : profile.ipAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } icon: {
                Image(systemName: "network")
            }

            Spacer(minLength: 8)

            if profile.id == currentProfile?.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel(appText("status.currentProfile", languageSetting: appLanguage))
            }
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
                appText("configuration.noneSelected", languageSetting: appLanguage),
                systemImage: "network",
                description: Text(appText("configuration.selectHint", languageSetting: appLanguage))
            )
        }
    }

    var networkServicePicker: some View {
        Picker(selection: $serviceName) {
            if visibleNetworkServices.isEmpty {
                Text(serviceName.isEmpty ? appText("network.noServices", languageSetting: appLanguage) : serviceName)
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
            Label(appText("network.label", languageSetting: appLanguage), systemImage: "network")
        }
        .frame(minWidth: 150, idealWidth: 180)
        .disabled(isLoadingServices || visibleNetworkServices.isEmpty)
    }

    func profileDetail(_ profile: NetworkProfile) -> some View {
        Form {
            Section(appText("configuration.static", languageSetting: appLanguage)) {
                readOnlyRow(appText("editor.ip", languageSetting: appLanguage), value: profile.ipAddress)
                readOnlyRow(appText("editor.subnet", languageSetting: appLanguage), value: profile.subnetMask)
                readOnlyRow(appText("editor.router", languageSetting: appLanguage), value: profile.router)
                readOnlyRow(appText("editor.dns", languageSetting: appLanguage), value: profile.dnsServers)
            }

            Section {
                if isLoadingInfo {
                    LabeledContent(appText("status.refreshInfo", languageSetting: appLanguage)) {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else if currentNetworkInfo.isEmpty {
                    Text(appText("status.noInfo", languageSetting: appLanguage))
                        .foregroundStyle(.secondary)
                } else {
                    readOnlyRow(appText("status.currentProfile", languageSetting: appLanguage), value: currentProfileLabel)
                    readOnlyRow(appText("status.currentIP", languageSetting: appLanguage), value: currentNetworkInfo.ipAddress)
                    readOnlyRow(appText("status.currentSubnet", languageSetting: appLanguage), value: currentNetworkInfo.subnetMask)
                    readOnlyRow(appText("status.currentRouter", languageSetting: appLanguage), value: currentNetworkInfo.router)
                    readOnlyRow(appText("status.currentDNS", languageSetting: appLanguage), value: currentNetworkInfo.dnsServersString)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text(appText("status.currentInfo", languageSetting: appLanguage))
                    Spacer()
                    Button {
                        switchToDHCP()
                    } label: {
                        Label(appText("action.dhcp", languageSetting: appLanguage), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.glass)
                    .disabled(isSwitching)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile.name.isEmpty ? appText("configuration.untitled", languageSetting: appLanguage) : profile.name)
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

    var currentProfile: NetworkProfile? {
        NetworkAutomation.matchingProfile(for: currentNetworkInfo, profiles: profiles)
    }

    var currentProfileLabel: String {
        NetworkAutomation.currentProfileLabel(for: currentNetworkInfo, profiles: profiles, languageSetting: appLanguage)
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
            ? appText("configuration.copyUntitled", languageSetting: appLanguage)
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
            statusMessage = appText("status.networkRequired", languageSetting: appLanguage)
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
        Task { @MainActor in
            let info = await NetworkAutomation.getCurrentNetworkInfoPolling(serviceName: service)
            currentNetworkInfo = info
            isLoadingInfo = false
        }
    }

    func apply(profile: NetworkProfile) {
        guard !isSwitching else { return }

        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? appText("status.defaultConfiguration", languageSetting: appLanguage) : name
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
                        statusMessage = error.isEmpty ? appText("status.loadServicesFailed", languageSetting: appLanguage) : error
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
            currentNetworkInfo = NetworkInfoResult.empty
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
                Section(appText("configuration.static", languageSetting: languageSetting)) {
                    TextField(appText("editor.name", languageSetting: languageSetting), text: $profile.name)
                    TextField(appText("editor.ip", languageSetting: languageSetting), text: $profile.ipAddress)
                    TextField(appText("editor.subnet", languageSetting: languageSetting), text: $profile.subnetMask)
                    TextField(appText("editor.router", languageSetting: languageSetting), text: $profile.router)
                    TextField(appText("editor.dns", languageSetting: languageSetting), text: $profile.dnsServers)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appText("action.cancel", languageSetting: languageSetting)) {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(appText("action.save", languageSetting: languageSetting)) {
                        onSave()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 460, height: 330)
    }
}

#Preview {
    ContentView()
}
