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
            subnetMask: "255.255.255.0",
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
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                profileList

                Divider()

                profileDetail
            }
            .frame(minHeight: 320)

            Divider()

            footer
        }
        .frame(width: 760, height: 470)
        .onAppear {
            loadProfiles()
            loadNetworkServices()
        }
        .sheet(isPresented: $isEditorPresented) {
            NetworkProfileEditor(
                title: editingProfileID == nil ? "New Configuration" : "Edit Configuration",
                profile: $draftProfile,
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
                .font(.title2)
                .foregroundStyle(.tint)

            Text("Network Switcher")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Picker("Network", selection: $serviceName) {
                if networkServices.isEmpty {
                    Text(serviceName.isEmpty ? "No Services" : serviceName)
                        .tag(serviceName)
                } else {
                    ForEach(networkServices) { service in
                        Text(service.displayName)
                            .tag(service.name)
                    }
                }
            }
            .labelsHidden()
            .frame(width: 210)
            .disabled(isLoadingServices || networkServices.isEmpty)

            Button {
                loadNetworkServices()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(isLoadingServices)
        }
        .padding(18)
    }

    var profileList: some View {
        ZStack {
            List(profiles, selection: $selectedProfileID) { profile in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name.isEmpty ? "Untitled" : profile.name)
                            .lineLimit(1)

                        Text(profile.ipAddress.isEmpty ? "No IP address" : profile.ipAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .tag(profile.id)
                .contextMenu {
                    Button("Edit Configuration") {
                        editProfile(profile)
                    }

                    Button("Duplicate Configuration") {
                        duplicateProfile(profile)
                    }

                    Divider()

                    Button("Delete Configuration", role: .destructive) {
                        deleteProfile(profile)
                    }
                }
            }
            .listStyle(.sidebar)
            .contextMenu {
                Button("Add Configuration") {
                    addProfile()
                }
            }

            if profiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.tertiary)

                    Text("No Configurations")
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: 260)
    }

    var profileDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let selectedProfile {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedProfile.name.isEmpty ? "Untitled" : selectedProfile.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Static IP configuration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    detailRow("IP Address", selectedProfile.ipAddress)
                    detailRow("Subnet Mask", selectedProfile.subnetMask)
                    detailRow("Router", selectedProfile.router)
                    detailRow("DNS Servers", selectedProfile.dnsServers)
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary)
                )

                HStack {
                    Button {
                        applySelectedProfile()
                    } label: {
                        Label("Apply", systemImage: "checkmark.circle")
                    }
                    .keyboardShortcut(.return)
                    .disabled(isSwitching)

                    Button {
                        editProfile(selectedProfile)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(isSwitching)

                    Spacer()
                }
            } else {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "rectangle.dashed")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)

                    Text("No Configuration Selected")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }

            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var footer: some View {
        HStack(spacing: 12) {
            Button {
                switchToDHCP()
            } label: {
                Label("DHCP", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSwitching)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    var selectedProfile: NetworkProfile? {
        guard let selectedProfileID else {
            return nil
        }

        return profiles.first { $0.id == selectedProfileID }
    }

    func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    func addProfile() {
        draftProfile = NetworkProfile.blank(named: nextProfileName())
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
        copy.name = profile.name.isEmpty ? "Untitled Copy" : "\(profile.name) Copy"
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
            statusMessage = "Network service name is required."
            return
        }

        isSwitching = true
        statusMessage = "Switching \(service) to DHCP..."

        let quotedService = shellQuoted(service)
        let command = """
        /usr/sbin/networksetup -setdhcp \(quotedService) && /usr/sbin/networksetup -setdnsservers \(quotedService) Empty
        """

        runAuthorized(command: command) { result in
            isSwitching = false
            statusMessage = result.success
                ? "\(service) is now using DHCP."
                : "Failed: \(result.message)"
        }
    }

    func applySelectedProfile() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let profile = selectedProfile else {
            statusMessage = "Select a configuration first."
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
            statusMessage = "Network service name is required."
            return
        }

        guard !ipAddress.isEmpty, !subnetMask.isEmpty, !router.isEmpty else {
            statusMessage = "IP address, subnet mask, and router are required."
            return
        }

        isSwitching = true
        statusMessage = "Applying \(name.isEmpty ? "selected configuration" : name)..."

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
                ? "Applied \(name.isEmpty ? "selected configuration" : name)."
                : "Failed: \(result.message)"
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

                    if !services.contains(where: { $0.name == serviceName }) {
                        serviceName = services.first?.name ?? serviceName
                    }

                    if process.terminationStatus != 0 {
                        statusMessage = error.isEmpty ? "Failed to load network services." : error
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadingServices = false
                    statusMessage = "Failed to load network services: \(error.localizedDescription)"
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
                        message: message.isEmpty ? "Command exited with code \(process.terminationStatus)." : message
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
        "Configuration \(profiles.count + 1)"
    }
}

struct NetworkProfileEditor: View {
    let title: String
    @Binding var profile: NetworkProfile
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
                TextField("Name", text: $profile.name)
                TextField("IP Address", text: $profile.ipAddress)
                TextField("Subnet Mask", text: $profile.subnetMask)
                TextField("Router", text: $profile.router)
                TextField("DNS Servers", text: $profile.dnsServers)
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460)
    }
}

#Preview {
    ContentView()
}
