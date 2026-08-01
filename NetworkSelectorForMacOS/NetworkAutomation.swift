//
//  NetworkAutomation.swift
//  NetworkSelectorForMacOS
//  处理网络配置的自动化逻辑，包括执行系统命令和提供快捷指令支持
//
//  Created by 司晓龙 on 2026/5/13.
//

import AppIntents
import Foundation

enum NetworkAutomation {

    // 从 UserDefaults 中获取保存的网络配置文件列表
    static func storedProfiles() -> [NetworkProfile] {
        let storedProfiles = UserDefaults.standard.string(forKey: "networkProfiles") ?? "[]"

        guard let data = storedProfiles.data(using: .utf8),
              let decodedProfiles = try? JSONDecoder().decode([NetworkProfile].self, from: data) else {
            return []
        }

        return decodedProfiles
    }

    // 将指定的网络配置应用到指定的网络服务上，执行系统命令进行配置
    static func apply(profile: NetworkProfile, serviceName: String) async -> NetworkAutomationResult {
        // 清理输入，去除多余的空白字符
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ipAddress = profile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let subnetMask = profile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
        let router = profile.router.trimmingCharacters(in: .whitespacesAndNewlines)
        // 将 DNS 服务器列表拆分成单个地址，支持逗号、空格、换行和制表符分隔
        let dnsServers = profile.dnsServers
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map(String.init)

        // 验证输入，确保网络服务名称和必要的静态 IP 配置字段不为空
        guard !service.isEmpty else {
            return NetworkAutomationResult(success: false, message: text("status.networkRequired"))
        }

        // 对于静态 IP 配置，IP 地址、子网掩码和网关都是必填项
        guard !ipAddress.isEmpty, !subnetMask.isEmpty, !router.isEmpty else {
            return NetworkAutomationResult(success: false, message: text("status.staticFieldsRequired"))
        }

        // 构建系统命令，使用 networksetup 工具设置静态 IP 和 DNS 服务器
        let quotedService = shellQuoted(service)
        let dnsArguments = dnsServers.isEmpty
            ? "Empty"
            : dnsServers.map(shellQuoted).joined(separator: " ")
        let command = """
        /usr/sbin/networksetup -setmanual \(quotedService) \(shellQuoted(ipAddress)) \(shellQuoted(subnetMask)) \(shellQuoted(router)) && /usr/sbin/networksetup -setdnsservers \(quotedService) \(dnsArguments)
        """

        // 执行命令并返回结果，使用管理员权限运行以确保有足够的权限修改网络设置
        return await runAuthorized(command: command)
    }

    // 将指定的网络服务切换到 DHCP 模式，并清除自定义 DNS 服务器设置
    static func switchToDHCP(serviceName: String) async -> NetworkAutomationResult {
        // 清理输入，去除多余的空白字符
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证输入，确保网络服务名称不为空
        guard !service.isEmpty else {
            return NetworkAutomationResult(success: false, message: text("status.networkRequired"))
        }

        // 构建系统命令，使用 networksetup 工具切换到 DHCP 模式并清除 DNS 服务器设置
        let quotedService = shellQuoted(service)
        let command = """
        /usr/sbin/networksetup -setdhcp \(quotedService) && /usr/sbin/networksetup -setdnsservers \(quotedService) Empty
        """

        // 执行命令并返回结果，使用管理员权限运行以确保有足够的权限修改网络设置
        return await runAuthorized(command: command)
    }

    /// 获取当前网络服务的 IP、子网掩码、网关信息
    static func getCurrentNetworkInfo(serviceName: String) -> NetworkInfoResult {
        // 清理输入，去除多余的空白字符
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证输入，确保网络服务名称不为空
        guard !service.isEmpty else {
            return NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: [])
        }

        // 构建系统命令，使用 networksetup 工具获取网络服务的配置信息
        let quotedService = shellQuoted(service)

        // 获取 IP/子网掩码/网关
        let infoCommand = "/usr/sbin/networksetup -getinfo \(quotedService)"
        let infoOutput = runCommand(command: infoCommand)

        // 获取 DNS
        let dnsCommand = "/usr/sbin/networksetup -getdnsservers \(quotedService)"
        let dnsOutput = runCommand(command: dnsCommand)

        // 解析命令输出并返回结构化的网络信息结果
        return parseNetworkInfo(infoOutput: infoOutput, dnsOutput: dnsOutput)
    }

    // 执行系统命令并返回输出结果
    private static func runCommand(command: String) -> String {
        // 构建并运行系统命令，捕获标准输出和错误输出
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        // 使用 zsh 作为执行环境，以支持更复杂的命令语法和环境变量
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 执行命令并返回输出结果，如果执行失败则返回错误信息
        do {
            try process.run()
            process.waitUntilExit()
            return readText(from: outputPipe)
        } catch {
            return ""
        }
    }

    // 解析 networksetup 命令的输出，提取 IP 地址、子网掩码、网关和 DNS 服务器信息
    private static func parseNetworkInfo(infoOutput: String, dnsOutput: String) -> NetworkInfoResult {
        // 初始化变量来存储解析结果
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

        // 返回解析结果
        return NetworkInfoResult(
            ipAddress: ipAddress,
            subnetMask: subnetMask,
            router: router,
            dnsServers: dnsServers
        )
    }

    // 使用管理员权限执行系统命令
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

                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")  // 使用 osascript
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

// 网络信息结构体
struct NetworkInfoResult {
    let ipAddress: String
    let subnetMask: String
    let router: String
    let dnsServers: [String]

    var dnsServersString: String {
        dnsServers.joined(separator: ", ")
    }

    var isEmpty: Bool {
        ipAddress.isEmpty && subnetMask.isEmpty && router.isEmpty && dnsServers.isEmpty
    }
}

// 网络自动化结果结构体
struct NetworkAutomationResult {
    let success: Bool
    let message: String
}

// 网络配置实体
struct NetworkProfileEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Network Configuration")
    static let defaultQuery = NetworkProfileEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name.isEmpty ? NetworkAutomation.text("configuration.untitled") : name)")
    }
}

// 网络配置实体查询，提供快捷指令中网络配置的查询和建议功能
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

// 关于页面，展示应用信息和作者信息
extension NetworkProfileEntity {
    init(profile: NetworkProfile) {
        id = profile.id.uuidString
        name = profile.name
    }
}

// 快捷指令：应用网络配置到指定网络服务
struct ApplyNetworkConfigurationIntent: AppIntent {
    // 快捷指令标题和描述，定义在快捷指令库中显示的名称和说明
    static let title: LocalizedStringResource = "Apply Network Configuration"
    static let description = IntentDescription("Switches a network service to one of the saved static IP configurations.")
    static let openAppWhenRun = false

    // 快捷指令参数，用户在快捷指令中选择要应用的网络配置和目标网络服务
    @Parameter(title: "Configuration")
    var configuration: NetworkProfileEntity

    // 快捷指令参数，用户选择要应用配置的网络服务，默认为 "Wi-Fi"
    @Parameter(title: "Network Service", default: "Wi-Fi")
    var serviceName: String

    init() {}

    init(configuration: NetworkProfileEntity, serviceName: String) {
        self.configuration = configuration
        self.serviceName = serviceName
    }

    // 快捷指令执行逻辑
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 从存储的网络配置文件中查找与用户选择的配置 ID 匹配的配置文件
        guard let profile = NetworkAutomation.storedProfiles().first(where: { $0.id.uuidString == configuration.id }) else {
            return .result(dialog: "\(NetworkAutomation.text("intent.dialog.chooseConfiguration"))")
        }

        // 将选中的网络配置应用到指定的网络服务上，并根据结果返回相应的对话框提示用户操作结果
        let result = await NetworkAutomation.apply(profile: profile, serviceName: serviceName)

        // 根据执行结果返回不同的对话框提示，成功时显示应用成功的消息，失败时显示错误信息
        if result.success {
            let displayName = profile.name.isEmpty ? NetworkAutomation.text("status.defaultConfiguration") : profile.name
            return .result(dialog: "\(appText("intent.dialog.appliedToService", languageSetting: AppLanguage.system.rawValue, displayName, serviceName))")
        } else {
            return .result(dialog: "\(appText("status.applyFailed", languageSetting: AppLanguage.system.rawValue, result.message))")
        }
    }
}

// 快捷指令：将指定网络服务切换到 DHCP 模式，并清除自定义 DNS 服务器设置
struct SwitchNetworkServiceToDHCPIntent: AppIntent {
    // 快捷指令标题和描述，定义在快捷指令库中显示的名称和说明
    static let title: LocalizedStringResource = "Switch Network Service to DHCP"
    static let description = IntentDescription("Switches a network service to DHCP and clears custom DNS servers.")
    static let openAppWhenRun = false

    // 快捷指令参数，用户选择要切换的网络服务，默认为 "Wi-Fi"
    @Parameter(title: "Network Service", default: "Wi-Fi")
    var serviceName: String

    init() {}

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    // 快捷指令执行逻辑
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await NetworkAutomation.switchToDHCP(serviceName: serviceName)

        // 根据执行结果返回不同的对话框提示，成功时显示切换成功的消息，失败时显示错误信息
        if result.success {
            return .result(dialog: "\(appText("status.dhcpComplete", languageSetting: AppLanguage.system.rawValue, serviceName))")
        } else {
            return .result(dialog: "\(appText("status.applyFailed", languageSetting: AppLanguage.system.rawValue, result.message))")
        }
    }
}

// 快捷指令提供者，注册应用支持的快捷指令
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
