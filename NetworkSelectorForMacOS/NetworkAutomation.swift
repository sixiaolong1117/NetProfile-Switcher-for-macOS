//
//  NetworkAutomation.swift
//  NetworkSelectorForMacOS
//
//  Created by 司晓龙 on 2026/5/13.
//

import AppIntents
import Foundation

enum NetworkAutomation {
    static let defaultServiceName = "Wi-Fi"

    static func storedProfiles() -> [NetworkProfile] {
        let storedProfiles = UserDefaults.standard.string(forKey: "networkProfiles") ?? "[]"

        guard let data = storedProfiles.data(using: .utf8),
              let decodedProfiles = try? JSONDecoder().decode([NetworkProfile].self, from: data) else {
            return []
        }

        return decodedProfiles
    }

    static func storedServiceName() -> String {
        UserDefaults.standard.string(forKey: "networkServiceName") ?? defaultServiceName
    }

    static func apply(profile: NetworkProfile, serviceName: String) async -> NetworkAutomationResult {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ipAddress = profile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let subnetMask = profile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
        let router = profile.router.trimmingCharacters(in: .whitespacesAndNewlines)
        let dnsServers = profile.dnsServers
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map(String.init)

        guard !service.isEmpty else {
            return NetworkAutomationResult(success: false, message: text("status.networkRequired"))
        }

        guard !ipAddress.isEmpty, !subnetMask.isEmpty, !router.isEmpty else {
            return NetworkAutomationResult(success: false, message: text("status.staticFieldsRequired"))
        }

        let quotedService = shellQuoted(service)
        let dnsArguments = dnsServers.isEmpty
            ? "Empty"
            : dnsServers.map(shellQuoted).joined(separator: " ")
        let command = """
        /usr/sbin/networksetup -setmanual \(quotedService) \(shellQuoted(ipAddress)) \(shellQuoted(subnetMask)) \(shellQuoted(router)) && /usr/sbin/networksetup -setdnsservers \(quotedService) \(dnsArguments)
        """

        return await runAuthorized(command: command)
    }

    static func switchToDHCP(serviceName: String) async -> NetworkAutomationResult {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !service.isEmpty else {
            return NetworkAutomationResult(success: false, message: text("status.networkRequired"))
        }

        let quotedService = shellQuoted(service)
        let command = """
        /usr/sbin/networksetup -setdhcp \(quotedService) && /usr/sbin/networksetup -setdnsservers \(quotedService) Empty
        """

        return await runAuthorized(command: command)
    }

    /// 获取当前网络服务的 IP、子网掩码、网关信息
    static func getCurrentNetworkInfo(serviceName: String) -> NetworkInfoResult {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.isEmpty else {
            return NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: [], rawOutput: "")
        }

        let quotedService = shellQuoted(service)

        // 获取 IP/子网掩码/网关
        let infoCommand = "/usr/sbin/networksetup -getinfo \(quotedService)"
        let infoOutput = runCommand(command: infoCommand)

        // 获取 DNS
        let dnsCommand = "/usr/sbin/networksetup -getdnsservers \(quotedService)"
        let dnsOutput = runCommand(command: dnsCommand)

        return parseNetworkInfo(infoOutput: infoOutput, dnsOutput: dnsOutput)
    }

    private static func runCommand(command: String) -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            return readText(from: outputPipe)
        } catch {
            return ""
        }
    }

    private static func parseNetworkInfo(infoOutput: String, dnsOutput: String) -> NetworkInfoResult {
        var ipAddress = ""
        var subnetMask = ""
        var router = ""

        // 解析 getinfo 输出
        let lines = infoOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("IP address:") {
                ipAddress = String(trimmed.dropFirst("IP address:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Subnet mask:") {
                subnetMask = String(trimmed.dropFirst("Subnet mask:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Router:") {
                router = String(trimmed.dropFirst("Router:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 解析 DNS 输出
        var dnsServers: [String] = []
        let dnsLines = dnsOutput.components(separatedBy: .newlines)
        for line in dnsLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("There aren't any DNS Servers set on") {
                dnsServers.append(trimmed)
            }
        }

        return NetworkInfoResult(
            ipAddress: ipAddress,
            subnetMask: subnetMask,
            router: router,
            dnsServers: dnsServers,
            rawOutput: infoOutput
        )
    }

    static func runAuthorized(command: String) async -> NetworkAutomationResult {
        await withCheckedContinuation { continuation in
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

                    continuation.resume(returning: NetworkAutomationResult(
                        success: process.terminationStatus == 0,
                        message: message.isEmpty
                            ? appText("status.commandExited", languageSetting: AppLanguage.system.rawValue, process.terminationStatus)
                            : message
                    ))
                } catch {
                    continuation.resume(returning: NetworkAutomationResult(
                        success: false,
                        message: error.localizedDescription
                    ))
                }
            }
        }
    }

    static func readText(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func text(_ key: String) -> String {
        appText(key, languageSetting: AppLanguage.system.rawValue)
    }
}

struct NetworkInfoResult {
    let ipAddress: String
    let subnetMask: String
    let router: String
    let dnsServers: [String]
    let rawOutput: String

    var dnsServersString: String {
        dnsServers.joined(separator: ", ")
    }

    var isEmpty: Bool {
        ipAddress.isEmpty && subnetMask.isEmpty && router.isEmpty && dnsServers.isEmpty
    }
}

struct NetworkAutomationResult {
    let success: Bool
    let message: String
}

struct NetworkProfileEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Network Configuration")
    static let defaultQuery = NetworkProfileEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name.isEmpty ? NetworkAutomation.text("configuration.untitled") : name)")
    }
}

struct NetworkProfileEntityQuery: EntityQuery {
    func entities(for identifiers: [NetworkProfileEntity.ID]) async throws -> [NetworkProfileEntity] {
        NetworkAutomation.storedProfiles()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { NetworkProfileEntity(profile: $0) }
    }

    func suggestedEntities() async throws -> [NetworkProfileEntity] {
        NetworkAutomation.storedProfiles().map { NetworkProfileEntity(profile: $0) }
    }

    func defaultResult() async -> NetworkProfileEntity? {
        NetworkAutomation.storedProfiles().first.map { NetworkProfileEntity(profile: $0) }
    }
}

extension NetworkProfileEntity {
    init(profile: NetworkProfile) {
        id = profile.id.uuidString
        name = profile.name
    }
}

struct ApplyNetworkConfigurationIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Network Configuration"
    static let description = IntentDescription("Switches a network service to one of the saved static IP configurations.")
    static let openAppWhenRun = false

    @Parameter(title: "Configuration")
    var configuration: NetworkProfileEntity

    @Parameter(title: "Network Service", default: "Wi-Fi")
    var serviceName: String

    init() {}

    init(configuration: NetworkProfileEntity, serviceName: String) {
        self.configuration = configuration
        self.serviceName = serviceName
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let profile = NetworkAutomation.storedProfiles().first(where: { $0.id.uuidString == configuration.id }) else {
            return .result(dialog: "\(NetworkAutomation.text("intent.dialog.chooseConfiguration"))")
        }

        let result = await NetworkAutomation.apply(profile: profile, serviceName: serviceName)

        if result.success {
            let displayName = profile.name.isEmpty ? NetworkAutomation.text("status.defaultConfiguration") : profile.name
            return .result(dialog: "\(appText("intent.dialog.appliedToService", languageSetting: AppLanguage.system.rawValue, displayName, serviceName))")
        } else {
            return .result(dialog: "\(appText("status.applyFailed", languageSetting: AppLanguage.system.rawValue, result.message))")
        }
    }
}

struct SwitchNetworkServiceToDHCPIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Network Service to DHCP"
    static let description = IntentDescription("Switches a network service to DHCP and clears custom DNS servers.")
    static let openAppWhenRun = false

    @Parameter(title: "Network Service", default: "Wi-Fi")
    var serviceName: String

    init() {}

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await NetworkAutomation.switchToDHCP(serviceName: serviceName)

        if result.success {
            return .result(dialog: "\(appText("status.dhcpComplete", languageSetting: AppLanguage.system.rawValue, serviceName))")
        } else {
            return .result(dialog: "\(appText("status.applyFailed", languageSetting: AppLanguage.system.rawValue, result.message))")
        }
    }
}

struct NetworkSelectorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApplyNetworkConfigurationIntent(),
            phrases: [
                "Apply network configuration with \(.applicationName)",
                "Switch network profile with \(.applicationName)"
            ],
            shortTitle: "Apply Configuration",
            systemImageName: "network"
        )

        AppShortcut(
            intent: SwitchNetworkServiceToDHCPIntent(),
            phrases: [
                "Switch to DHCP with \(.applicationName)",
                "Reset network service with \(.applicationName)"
            ],
            shortTitle: "Switch to DHCP",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
